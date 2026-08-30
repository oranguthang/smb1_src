-- Verify one reconstructed SMB2 program overlay through the game's FDS loader

local name = assert(os.getenv("SMB2_OVERLAY_NAME"))
local boot_frame = assert(tonumber(os.getenv("SMB2_OVERLAY_BOOT_FRAME")))
local mode = assert(tonumber(os.getenv("SMB2_OVERLAY_MODE")))
local mode_task = assert(tonumber(os.getenv("SMB2_OVERLAY_MODE_TASK")))
local disk_task = assert(tonumber(os.getenv("SMB2_OVERLAY_DISK_TASK")))
local file_list = assert(tonumber(os.getenv("SMB2_OVERLAY_FILE_LIST")))
local world = assert(tonumber(os.getenv("SMB2_OVERLAY_WORLD")))
local hard_world = assert(tonumber(os.getenv("SMB2_OVERLAY_HARD_WORLD")))
local expected_disk_task = assert(tonumber(os.getenv("SMB2_OVERLAY_EXPECTED_DISK_TASK")))
local timeout = assert(tonumber(os.getenv("SMB2_OVERLAY_TIMEOUT")))
local load_address = assert(tonumber(os.getenv("SMB2_OVERLAY_LOAD_ADDRESS")))
local signature_hex = assert(os.getenv("SMB2_OVERLAY_SIGNATURE"))
local result_path = assert(os.getenv("SMB2_OVERLAY_RESULT"))
local forbidden_hit = nil

local ram = {
    world = 0x075f,
    operating_mode = 0x0770,
    operating_mode_task = 0x0772,
    file_list = 0x07f7,
    hard_world = 0x07fb,
    disk_task = 0x07fc,
}

local signature = {}
for byte in string.gmatch(signature_hex, "%x%x") do
    table.insert(signature, tonumber(byte, 16))
end

local forbidden_execute = os.getenv("SMB_RUNTIME_FORBID_EXECUTE")
if forbidden_execute ~= nil and forbidden_execute ~= "" then
    for token in string.gmatch(forbidden_execute, "[^,]+") do
        local probe_address = assert(tonumber(string.gsub(token, "^0x", ""), 16))
        memory.registerexecute(probe_address, function()
            forbidden_hit = probe_address
        end)
    end
end

local function signature_matches()
    for index, value in ipairs(signature) do
        if memory.readbyte(load_address + index - 1) ~= value then
            return false
        end
    end
    return true
end

local function current_prefix()
    local values = {}
    for index = 0, #signature - 1 do
        table.insert(values, string.format("%02X", memory.readbyte(load_address + index)))
    end
    return table.concat(values)
end

local function write_result(result)
    local output = assert(io.open(result_path, "w"))
    output:write(result .. "\n")
    output:close()
end

while emu.framecount() < boot_frame do
    emu.frameadvance()
    if forbidden_hit ~= nil then
        write_result(string.format("FAIL:EXECUTE:%04X", forbidden_hit))
        emu.exit()
        return
    end
end

if signature_matches() then
    write_result("FAIL:PRELOADED:" .. name)
    emu.exit()
    return
end

memory.writebyte(ram.world, world)
memory.writebyte(ram.hard_world, hard_world)
memory.writebyte(ram.file_list, file_list)
memory.writebyte(ram.disk_task, disk_task)
memory.writebyte(ram.operating_mode_task, mode_task)
memory.writebyte(ram.operating_mode, mode)

for frame = 1, timeout do
    emu.frameadvance()
    if forbidden_hit ~= nil then
        write_result(string.format("FAIL:EXECUTE:%04X", forbidden_hit))
        emu.exit()
        return
    end
    if signature_matches()
            and memory.readbyte(ram.disk_task) == expected_disk_task then
        write_result(string.format("PASS:%s:%d", name, frame))
        emu.exit()
        return
    end
end

write_result(string.format(
    "FAIL:TIMEOUT:%s:mode=%02X:task=%02X:disk=%02X:list=%02X:prefix=%s",
    name,
    memory.readbyte(ram.operating_mode),
    memory.readbyte(ram.operating_mode_task),
    memory.readbyte(ram.disk_task),
    memory.readbyte(ram.file_list),
    current_prefix()
))
emu.exit()
