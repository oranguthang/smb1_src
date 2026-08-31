-- Enter an authored SMB1 area directly and place Mario at the editor cursor.

local function setting(name, minimum, maximum)
    local value = tonumber(os.getenv(name) or "")
    if value == nil or value < minimum or value > maximum then
        error(name .. " must be in range " .. minimum .. ".." .. maximum)
    end
    return value
end

local function toggle(name, default)
    local value = os.getenv(name)
    if value == nil or value == "" then
        return default
    end
    if value == "1" then
        return true
    end
    if value == "0" then
        return false
    end
    error(name .. " must be 0 or 1")
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
local timer_display = setting("SMB1_PLAYTEST_TIMER", 0, 65533)
local infinite_time = toggle("SMB1_PLAYTEST_INFINITE_TIME", true)
local invincible = toggle("SMB1_PLAYTEST_INVINCIBLE", true)
local wrap_pits = toggle("SMB1_PLAYTEST_WRAP_PITS", true)
local probe_trainer = toggle("SMB1_PLAYTEST_PROBE_TRAINER", false)
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
    player_state = 0x001d,
    player_x_speed = 0x0057,
    player_y_speed = 0x009f,
    player_y_speed_fraction = 0x0433,
    injury_timer = 0x079e,
    timer_control = 0x0747,
    game_timer_expired_flag = 0x0759,
    scroll_lock = 0x0723,
    death_music_loaded = 0x0712,
    event_music_queue = 0x00fc,
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
local trainer_probe_status = "off"

local function apply_infinite_time()
    if not infinite_time then
        return
    end
    memory.writebyte(timer_display, 9)
    memory.writebyte(timer_display + 1, 9)
    memory.writebyte(timer_display + 2, 9)
    memory.writebyte(ram.game_timer_expired_flag, 0)
end

local function clear_death_state()
    memory.writebyte(ram.timer_control, 0)
    memory.writebyte(ram.game_timer_expired_flag, 0)
    memory.writebyte(ram.death_music_loaded, 0)
    memory.writebyte(ram.event_music_queue, 0)
end

local function rescue_damage(previous_status, previous_size, previous_x_speed)
    if not invincible then
        return
    end
    local engine = memory.readbyte(ram.game_engine_subroutine)
    if engine ~= 0x0a and engine ~= 0x0b then
        return
    end
    memory.writebyte(ram.game_engine_subroutine, 0x08)
    memory.writebyte(ram.player_state, 0x01)
    memory.writebyte(ram.player_status, previous_status)
    memory.writebyte(ram.player_size, previous_size)
    memory.writebyte(ram.player_x_speed, previous_x_speed)
    memory.writebyte(ram.player_y_speed, 0)
    memory.writebyte(ram.player_y_speed_fraction, 0)
    memory.writebyte(ram.injury_timer, 0x20)
    clear_death_state()
end

local function wrap_player_from_pit()
    if not wrap_pits or memory.readbyte(ram.player_y_high) < 2 then
        return
    end
    memory.writebyte(ram.player_y_high, 1)
    memory.writebyte(ram.player_y, 0x30)
    memory.writebyte(ram.player_state, 0x01)
    memory.writebyte(ram.player_y_speed, 0)
    memory.writebyte(ram.player_y_speed_fraction, 0)
    memory.writebyte(ram.scroll_lock, 0)
    memory.writebyte(ram.game_engine_subroutine, 0x08)
    clear_death_state()
end

local function run_trainer_probe()
    if not probe_trainer then
        return
    end
    if not infinite_time or not invincible or not wrap_pits then
        error("SMB1 trainer probe requires every trainer feature")
    end
    memory.writebyte(timer_display, 0)
    memory.writebyte(timer_display + 1, 0)
    memory.writebyte(timer_display + 2, 0)
    apply_infinite_time()
    local previous_status = memory.readbyte(ram.player_status)
    local previous_size = memory.readbyte(ram.player_size)
    local previous_x_speed = memory.readbyte(ram.player_x_speed)
    memory.writebyte(ram.game_engine_subroutine, 0x0b)
    rescue_damage(previous_status, previous_size, previous_x_speed)
    memory.writebyte(ram.player_y_high, 2)
    wrap_player_from_pit()
    if memory.readbyte(timer_display) ~= 9
            or memory.readbyte(timer_display + 1) ~= 9
            or memory.readbyte(timer_display + 2) ~= 9
            or memory.readbyte(ram.game_engine_subroutine) ~= 0x08
            or memory.readbyte(ram.player_y_high) ~= 1
            or memory.readbyte(ram.player_y) ~= 0x30 then
        error("SMB1 trainer probe did not restore the expected gameplay state")
    end
    trainer_probe_status = "ok"
end

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
        "status=%s loader=%s overlay=%02x area=%02x world=%d level=%d page=%d x=%d y=%d mode=%d task=%d engine=%d screen=%d sprite0=%d disable=%d vram=%d ppu1=%02x ppu2=%02x frame=%d background=%02x pc=%04x timer=%d%d%d trainer=%d/%d/%d probe=%s\n",
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
        memory.getregister("pc"),
        memory.readbyte(timer_display),
        memory.readbyte(timer_display + 1),
        memory.readbyte(timer_display + 2),
        infinite_time and 1 or 0,
        invincible and 1 or 0,
        wrap_pits and 1 or 0,
        trainer_probe_status
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
    apply_infinite_time()
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
apply_infinite_time()

memory.readbyte(0x2002)
memory.writebyte(0x2006, 0x3f)
memory.writebyte(0x2006, 0x00)
memory.writebyte(0x2007, theme == "day" and day_color or night_color)

run_trainer_probe()
write_result("ready")

if os.getenv("SMB1_PLAYTEST_EXIT") == "1" then
    emu.exit()
    return
end

while true do
    local previous_status = memory.readbyte(ram.player_status)
    local previous_size = memory.readbyte(ram.player_size)
    local previous_x_speed = memory.readbyte(ram.player_x_speed)
    apply_infinite_time()
    emu.frameadvance()
    apply_infinite_time()
    rescue_damage(previous_status, previous_size, previous_x_speed)
    wrap_player_from_pit()
end
