-- Enter an authored SMB1 area directly and place Mario at the editor cursor.

local function setting(name, minimum, maximum)
    local value = tonumber(os.getenv(name) or "")
    if value == nil or value < minimum or value > maximum then
        error(name .. " must be in range " .. minimum .. ".." .. maximum)
    end
    return value
end

local area_pointer = setting("SMB1_PLAYTEST_AREA", 0, 127)
local world = setting("SMB1_PLAYTEST_WORLD", 0, 8)
local level = setting("SMB1_PLAYTEST_LEVEL", 0, 7)
local page = setting("SMB1_PLAYTEST_PAGE", 0, 31)
local player_x = setting("SMB1_PLAYTEST_X", 0, 255)
local player_y = setting("SMB1_PLAYTEST_Y", 32, 239)
local boot_task = setting("SMB1_PLAYTEST_BOOT_TASK", 0, 255)
local game_mode = setting("SMB1_PLAYTEST_GAME_MODE", 0, 255)
local ready_task = setting("SMB1_PLAYTEST_READY_TASK", 0, 255)
local boot_frames = setting("SMB1_PLAYTEST_BOOT_FRAMES", 1, 3600)
local ready_frames = setting("SMB1_PLAYTEST_READY_FRAMES", 1, 3600)
local theme = os.getenv("SMB1_PLAYTEST_THEME") or "day"
if theme ~= "day" and theme ~= "night" then
    error("SMB1_PLAYTEST_THEME must be day or night")
end
local day_color = setting("SMB1_PLAYTEST_DAY_COLOR", 0, 63)
local night_color = setting("SMB1_PLAYTEST_NIGHT_COLOR", 0, 63)
local loader = os.getenv("SMB1_PLAYTEST_LOADER") or "direct"
if loader ~= "direct"
        and loader ~= "ann_extended"
        and loader ~= "smb2_normal"
        and loader ~= "smb2_hard" then
    error("SMB1_PLAYTEST_LOADER is not supported")
end

local ram = {
    frame_counter = 0x0009,
    game_engine_subroutine = 0x000e,
    player_page = 0x006d,
    player_x = 0x0086,
    player_y_high = 0x00b5,
    player_y = 0x00ce,
    screen_left_page = 0x071a,
    screen_left_x = 0x071c,
    halfway_page = 0x075b,
    level = 0x075c,
    world = 0x075f,
    area_number = 0x0760,
    area_pointer = 0x0750,
    entrance_page = 0x0751,
    alternate_entrance = 0x0752,
    player_size = 0x0754,
    player_status = 0x0756,
    screen_routine_task = 0x073c,
    sprite0_hit_detect_flag = 0x0722,
    operating_mode = 0x0770,
    operating_mode_task = 0x0772,
    vram_buffer_addr_ctrl = 0x0773,
    disable_screen_flag = 0x0774,
    mirror_ppu_ctrl_reg1 = 0x0778,
    mirror_ppu_ctrl_reg2 = 0x0779,
    ann_hard_mode = 0x07fb,
    fds_disk_loader_task = 0x07fc,
    ann_disk_file_id = 0x07fd,
    smb2_file_list = 0x07f7,
}

local transitions = {}

local function record_transition(frame)
    local state = string.format(
        "%d:%d/%d/%d/%d/%d/%d",
        frame,
        memory.readbyte(ram.operating_mode),
        memory.readbyte(ram.operating_mode_task),
        memory.readbyte(ram.game_engine_subroutine),
        memory.readbyte(ram.screen_routine_task),
        memory.readbyte(ram.sprite0_hit_detect_flag),
        memory.readbyte(ram.disable_screen_flag)
    )
    local previous = transitions[#transitions]
    if previous == nil or string.match(previous, ":(.+)$") ~= string.match(state, ":(.+)$") then
        transitions[#transitions + 1] = state
    end
end

local function write_result(status)
    local result_path = os.getenv("SMB1_PLAYTEST_RESULT")
    if result_path == nil or result_path == "" then
        return
    end
    local result = assert(io.open(result_path, "w"))
    result:write(string.format(
        "status=%s loader=%s overlay=%02x area=%02x world=%d level=%d page=%d x=%d y=%d mode=%d task=%d engine=%d screen=%d sprite0=%d disable=%d vram=%d ppu1=%02x ppu2=%02x frame=%d background=%02x pc=%04x\n",
        status,
        loader,
        memory.readbyte(0xc33d),
        memory.readbyte(ram.area_pointer),
        memory.readbyte(ram.world),
        memory.readbyte(ram.level),
        memory.readbyte(ram.player_page),
        memory.readbyte(ram.player_x),
        memory.readbyte(ram.player_y),
        memory.readbyte(ram.operating_mode),
        memory.readbyte(ram.operating_mode_task),
        memory.readbyte(ram.game_engine_subroutine),
        memory.readbyte(ram.screen_routine_task),
        memory.readbyte(ram.sprite0_hit_detect_flag),
        memory.readbyte(ram.disable_screen_flag),
        memory.readbyte(ram.vram_buffer_addr_ctrl),
        memory.readbyte(ram.mirror_ppu_ctrl_reg1),
        memory.readbyte(ram.mirror_ppu_ctrl_reg2),
        memory.readbyte(ram.frame_counter),
        ppu.readbyte(0x3f00),
        memory.getregister("pc")
    ))
    result:write("trace=frame:mode/task/engine/screen/sprite0/disable ")
    result:write(table.concat(transitions, ","))
    result:write("\n")
    result:close()
end

local boot_ready = false
for _frame = 1, boot_frames do
    emu.frameadvance()
    record_transition(_frame)
    if memory.readbyte(ram.operating_mode) == 0
            and memory.readbyte(ram.operating_mode_task) == boot_task then
        boot_ready = true
        break
    end
end


if not boot_ready then
    write_result("boot-timeout")
    if os.getenv("SMB1_PLAYTEST_EXIT") == "1" then
        emu.exit()
    end
    error("SMB1 title initialization did not become ready")
end

memory.writebyte(ram.world, world)
memory.writebyte(ram.level, level)
memory.writebyte(
    ram.area_number,
    (loader == "ann_extended" or loader == "smb2_hard") and level or 0
)
memory.writebyte(ram.area_pointer, area_pointer)
memory.writebyte(ram.halfway_page, 0)
memory.writebyte(ram.entrance_page, page)
memory.writebyte(ram.alternate_entrance, 1)
memory.writebyte(ram.player_size, 1)
memory.writebyte(ram.player_status, 0)

if loader == "ann_extended" then
    memory.writebyte(ram.ann_hard_mode, 1)
    memory.writebyte(ram.ann_disk_file_id, 0)
    memory.writebyte(ram.fds_disk_loader_task, 1)
    memory.writebyte(ram.operating_mode_task, 6)
    memory.writebyte(ram.operating_mode, 0)
    local loader_ready = false
    for frame = 1, ready_frames do
        emu.frameadvance()
        record_transition(boot_frames + frame)
        if memory.readbyte(ram.operating_mode) == game_mode then
            loader_ready = true
            break
        end
    end
    if not loader_ready or memory.readbyte(0xc33d) ~= 0 then
        write_result("loader-timeout")
        if os.getenv("SMB1_PLAYTEST_EXIT") == "1" then
            emu.exit()
        end
        error("ANN extended-course payload did not become ready")
    end
    memory.writebyte(ram.area_pointer, area_pointer)
    memory.writebyte(ram.operating_mode_task, 0)
elseif loader == "smb2_hard" or (loader == "smb2_normal" and world >= 4) then
    local target_world = world
    memory.writebyte(ram.smb2_file_list, 0)
    memory.writebyte(ram.fds_disk_loader_task, 1)
    if loader == "smb2_hard" then
        memory.writebyte(ram.ann_hard_mode, 1)
        memory.writebyte(ram.operating_mode_task, 5)
        memory.writebyte(ram.operating_mode, 0)
    elseif world == 8 then
        memory.writebyte(ram.world, 7)
        memory.writebyte(ram.ann_hard_mode, 0)
        memory.writebyte(ram.operating_mode_task, 5)
        memory.writebyte(ram.operating_mode, 2)
    else
        memory.writebyte(ram.ann_hard_mode, 0)
        memory.writebyte(ram.operating_mode_task, 0)
        memory.writebyte(ram.operating_mode, 1)
    end
    local loader_ready = false
    for frame = 1, ready_frames do
        emu.frameadvance()
        record_transition(boot_frames + frame)
        if memory.readbyte(ram.fds_disk_loader_task) == 0 then
            loader_ready = true
            break
        end
    end
    if not loader_ready then
        write_result("loader-timeout")
        if os.getenv("SMB1_PLAYTEST_EXIT") == "1" then
            emu.exit()
        end
        error("SMB2 course payload did not become ready")
    end
    memory.writebyte(ram.world, target_world)
    memory.writebyte(ram.level, level)
    memory.writebyte(
        ram.area_number,
        loader == "smb2_hard" and level or 0
    )
    memory.writebyte(ram.area_pointer, area_pointer)
    memory.writebyte(ram.operating_mode_task, 0)
    memory.writebyte(ram.operating_mode, game_mode)
else
    memory.writebyte(ram.operating_mode_task, 0)
    memory.writebyte(ram.operating_mode, game_mode)
end

local ready = false
for _frame = 1, ready_frames do
    emu.frameadvance()
    record_transition(_frame)
    if memory.readbyte(ram.operating_mode) == game_mode
            and memory.readbyte(ram.operating_mode_task) == ready_task
            and memory.readbyte(ram.game_engine_subroutine) >= 7 then
        ready = true
        break
    end
end

if not ready then
    write_result("timeout")
    if os.getenv("SMB1_PLAYTEST_EXIT") == "1" then
        emu.exit()
    end
    error("SMB1 gameplay did not become ready for point playtest")
end

emu.speedmode("normal")
memory.writebyte(ram.screen_left_page, page)
memory.writebyte(ram.screen_left_x, 0)
memory.writebyte(ram.player_page, page)
memory.writebyte(ram.player_x, player_x)
memory.writebyte(ram.player_y_high, 1)
memory.writebyte(ram.player_y, player_y)

memory.readbyte(0x2002)
memory.writebyte(0x2006, 0x3f)
memory.writebyte(0x2006, 0x00)
memory.writebyte(0x2007, theme == "day" and day_color or night_color)

write_result("ready")

if os.getenv("SMB1_PLAYTEST_EXIT") == "1" then
    emu.exit()
end
