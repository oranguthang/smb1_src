-- Enter an authored SMB1 area directly and place Mario at the editor cursor.

local function setting(name, minimum, maximum)
    local value = tonumber(os.getenv(name) or "")
    if value == nil or value < minimum or value > maximum then
        error(name .. " must be in range " .. minimum .. ".." .. maximum)
    end
    return value
end

local area_pointer = setting("SMB1_PLAYTEST_AREA", 0, 127)
local world = setting("SMB1_PLAYTEST_WORLD", 0, 7)
local level = setting("SMB1_PLAYTEST_LEVEL", 0, 3)
local page = setting("SMB1_PLAYTEST_PAGE", 0, 31)
local player_x = setting("SMB1_PLAYTEST_X", 0, 255)
local player_y = setting("SMB1_PLAYTEST_Y", 32, 239)
local theme = os.getenv("SMB1_PLAYTEST_THEME") or "day"
if theme ~= "day" and theme ~= "night" then
    error("SMB1_PLAYTEST_THEME must be day or night")
end

local ram = {
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
    operating_mode = 0x0770,
    operating_mode_task = 0x0772,
}

local function write_result(status)
    local result_path = os.getenv("SMB1_PLAYTEST_RESULT")
    if result_path == nil or result_path == "" then
        return
    end
    local result = assert(io.open(result_path, "w"))
    result:write(string.format(
        "status=%s area=%02x world=%d level=%d page=%d x=%d y=%d mode=%d task=%d engine=%d background=%02x\n",
        status,
        memory.readbyte(ram.area_pointer),
        memory.readbyte(ram.world),
        memory.readbyte(ram.level),
        memory.readbyte(ram.player_page),
        memory.readbyte(ram.player_x),
        memory.readbyte(ram.player_y),
        memory.readbyte(ram.operating_mode),
        memory.readbyte(ram.operating_mode_task),
        memory.readbyte(ram.game_engine_subroutine),
        ppu.readbyte(0x3f00)
    ))
    result:close()
end

local boot_ready = false
for _frame = 1, 600 do
    emu.frameadvance()
    if memory.readbyte(ram.operating_mode) == 0
            and memory.readbyte(ram.operating_mode_task) == 3 then
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
memory.writebyte(ram.area_number, 0)
memory.writebyte(ram.area_pointer, area_pointer)
memory.writebyte(ram.halfway_page, 0)
memory.writebyte(ram.entrance_page, page)
memory.writebyte(ram.alternate_entrance, 1)
memory.writebyte(ram.player_size, 1)
memory.writebyte(ram.player_status, 0)
memory.writebyte(ram.operating_mode_task, 0)
memory.writebyte(ram.operating_mode, 1)

local ready = false
for _frame = 1, 600 do
    emu.frameadvance()
    if memory.readbyte(ram.operating_mode) == 1
            and memory.readbyte(ram.operating_mode_task) == 3
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

memory.writebyte(ram.screen_left_page, page)
memory.writebyte(ram.screen_left_x, 0)
memory.writebyte(ram.player_page, page)
memory.writebyte(ram.player_x, player_x)
memory.writebyte(ram.player_y_high, 1)
memory.writebyte(ram.player_y, player_y)

memory.readbyte(0x2002)
memory.writebyte(0x2006, 0x3f)
memory.writebyte(0x2006, 0x00)
memory.writebyte(0x2007, theme == "day" and 0x22 or 0x0f)

write_result("ready")

if os.getenv("SMB1_PLAYTEST_EXIT") == "1" then
    emu.exit()
end
