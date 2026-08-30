-- Run a deterministic SMB2 World 1-1 gameplay slice

local boot_frame = assert(tonumber(os.getenv("SMB2_GAMEPLAY_BOOT_FRAME")))
local boot_task = assert(tonumber(os.getenv("SMB2_GAMEPLAY_BOOT_TASK")))
local ready_mode = assert(tonumber(os.getenv("SMB2_GAMEPLAY_READY_MODE")))
local ready_task = assert(tonumber(os.getenv("SMB2_GAMEPLAY_READY_TASK")))
local ready_engine = assert(tonumber(os.getenv("SMB2_GAMEPLAY_READY_ENGINE")))
local ready_timeout = assert(tonumber(os.getenv("SMB2_GAMEPLAY_READY_TIMEOUT")))
local run_frames = assert(tonumber(os.getenv("SMB2_GAMEPLAY_RUN_FRAMES")))
local minimum_active = assert(tonumber(os.getenv("SMB2_GAMEPLAY_MINIMUM_ACTIVE")))
local minimum_progress = assert(tonumber(os.getenv("SMB2_GAMEPLAY_MINIMUM_PROGRESS")))
local result_path = assert(os.getenv("SMB2_GAMEPLAY_RESULT"))

local ram = {
    engine = 0x000e,
    player_state = 0x001d,
    player_page = 0x006d,
    player_x = 0x0086,
    player_y = 0x00ce,
    screen_left_page = 0x071a,
    screen_left_x = 0x071c,
    screen_task = 0x073c,
    world = 0x075f,
    level = 0x075c,
    operating_mode = 0x0770,
    operating_task = 0x0772,
    disk_task = 0x07fc,
}

local forbidden_hit = nil
local forbidden_execute = os.getenv("SMB_RUNTIME_FORBID_EXECUTE")
if forbidden_execute ~= nil and forbidden_execute ~= "" then
    for token in string.gmatch(forbidden_execute, "[^,]+") do
        local probe_address = assert(tonumber(string.gsub(token, "^0x", ""), 16))
        memory.registerexecute(probe_address, function()
            forbidden_hit = probe_address
        end)
    end
end

local function write_result(result)
    local output = assert(io.open(result_path, "w"))
    output:write(result .. "\n")
    output:close()
end

local function fail(reason)
    write_result("FAIL:" .. reason)
    emu.exit()
end

local function position()
    return memory.readbyte(ram.player_page) * 256 + memory.readbyte(ram.player_x)
end

while emu.framecount() < boot_frame do
    emu.frameadvance()
    if forbidden_hit ~= nil then
        fail(string.format("EXECUTE:%04X", forbidden_hit))
        return
    end
end

if memory.readbyte(ram.operating_mode) ~= 0
        or memory.readbyte(ram.operating_task) ~= boot_task then
    fail("BOOT_STATE")
    return
end

joypad.set(1, {start = true})
emu.frameadvance()
joypad.set(1, {})

local ready = false
for _frame = 1, ready_timeout do
    emu.frameadvance()
    if forbidden_hit ~= nil then
        fail(string.format("EXECUTE:%04X", forbidden_hit))
        return
    end
    if memory.readbyte(ram.operating_mode) == ready_mode
            and memory.readbyte(ram.operating_task) == ready_task
            and memory.readbyte(ram.engine) >= ready_engine then
        ready = true
        break
    end
end
if not ready then
    fail(string.format(
        "READY_TIMEOUT:%02X:%02X:%02X",
        memory.readbyte(ram.operating_mode),
        memory.readbyte(ram.operating_task),
        memory.readbyte(ram.engine)
    ))
    return
end

local initial_position = position()
local maximum_position = initial_position
local active_frames = 0
for frame = 1, run_frames do
    local jump = (frame >= 120 and frame <= 132)
        or (frame >= 250 and frame <= 262)
    joypad.set(1, {right = true, B = true, A = jump})
    emu.frameadvance()
    if forbidden_hit ~= nil then
        fail(string.format("EXECUTE:%04X", forbidden_hit))
        return
    end
    if memory.readbyte(ram.operating_mode) == ready_mode
            and memory.readbyte(ram.operating_task) == ready_task then
        active_frames = active_frames + 1
    end
    maximum_position = math.max(maximum_position, position())
end
joypad.set(1, {})

local progress = maximum_position - initial_position
if active_frames < minimum_active then
    fail(string.format("ACTIVE:%d", active_frames))
    return
end
if progress < minimum_progress then
    fail(string.format("PROGRESS:%d", progress))
    return
end

write_result(string.format(
    "PASS:active=%d:progress=%d:mode=%02X:task=%02X:engine=%02X:screen=%02X:world=%02X:level=%02X:page=%02X:x=%02X:y=%02X:state=%02X:left=%02X%02X:disk=%02X",
    active_frames,
    progress,
    memory.readbyte(ram.operating_mode),
    memory.readbyte(ram.operating_task),
    memory.readbyte(ram.engine),
    memory.readbyte(ram.screen_task),
    memory.readbyte(ram.world),
    memory.readbyte(ram.level),
    memory.readbyte(ram.player_page),
    memory.readbyte(ram.player_x),
    memory.readbyte(ram.player_y),
    memory.readbyte(ram.player_state),
    memory.readbyte(ram.screen_left_page),
    memory.readbyte(ram.screen_left_x),
    memory.readbyte(ram.disk_task)
))
emu.exit()
