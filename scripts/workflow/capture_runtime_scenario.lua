-- Capture compact semantic SMB1 events from a deterministic FM2 playback.

local output_path = assert(os.getenv("SMB_RUNTIME_TRACE"))
local scenario = assert(os.getenv("SMB_RUNTIME_SCENARIO"))
local max_frames = assert(tonumber(os.getenv("SMB_RUNTIME_MAX_FRAMES")))
local output = assert(io.open(output_path, "w"))

local function symbol(name)
    local address = debugger.getsymboloffset(name)
    assert(address ~= nil and address >= 0, "missing debugger symbol: " .. name)
    return address
end

local ram = {
    mode = symbol("ram_oper_mode"),
    task = symbol("ram_oper_mode_task"),
    state = symbol("ram_player_state"),
    status = symbol("ram_player_status"),
    page = symbol("ram_player_page_loc"),
    x = symbol("ram_player_x_position"),
    y = symbol("ram_player_y_position"),
    x_speed = symbol("ram_player_x_speed"),
    y_speed = symbol("ram_player_y_speed"),
    coins = symbol("ram_coin_tally"),
    lives = symbol("ram_numberof_lives"),
    world = symbol("ram_world_number"),
    area = symbol("ram_area_number"),
    game_routine = symbol("ram_game_engine_subroutine"),
    enemy_id = symbol("ram_enemy_id"),
    enemy_flag = symbol("ram_enemy_flag"),
    enemy_state = symbol("ram_enemy_state"),
    enemy_page = symbol("ram_enemy_page_loc"),
    enemy_x = symbol("ram_enemy_x_position"),
    enemy_y = symbol("ram_enemy_y_position"),
    enemy_y_high = symbol("ram_enemy_y_high_pos"),
    enemy_bbox = symbol("ram_enemy_bound_box_ctrl"),
    enemy_offscreen = symbol("ram_enemy_offscr_bits_masked"),
    player_y_high = symbol("ram_player_y_high_pos"),
    power_type = symbol("ram_power_up_type"),
    timer_control = symbol("ram_timer_control"),
    event_music = symbol("ram_event_music_buffer"),
}

local function byte(address)
    return memory.readbyte(address)
end

local seen = {}
local function emit(event, detail)
    output:write(string.format(
        "%d,%s,%s,%02X,%02X,%02X,%02X,%02X,%02X,%02X,%02X,%02X,%02X,%02X,%02X,%02X\n",
        emu.framecount(), event, detail or "", byte(ram.mode), byte(ram.task),
        byte(ram.state), byte(ram.status), byte(ram.page), byte(ram.x), byte(ram.y),
        byte(ram.x_speed), byte(ram.y_speed), byte(ram.coins), byte(ram.lives),
        byte(ram.world), byte(ram.area)))
    output:flush()
end

local function emit_once(event, detail)
    if seen[event] then
        return
    end
    seen[event] = true
    emit(event, detail)
end

local function patch(address, value, reason)
    local previous = byte(address)
    memory.writebyte(address, value)
    emit("controlled_patch", string.format(
        "%04X:%02X>%02X:%s", address, previous, value, reason))
end

local hooks = {
    {"vec_nmi_handler", "title_boot"},
    {"handler_player_jumping_or_swimming", "jump"},
    {"sub_bump_block", "block_impact"},
    {"sub_give_one_coin", "coin_collection"},
    {"loc_handle_power_up_collision", "power_up_collection"},
    {"loc_enemy_stomped", "enemy_stomp"},
    {"handler_vertical_pipe_entry", "pipe_entry"},
    {"handler_side_exit_pipe_entry", "pipe_exit"},
    {"handler_player_death", "death"},
    {"handler_player_lose_life", "life_lost"},
}

for _, hook in ipairs(hooks) do
    local routine = hook[1]
    local event = hook[2]
    memory.registerexecute(symbol(routine), function()
        emit_once(event, routine)
    end)
end

memory.registerexecute(symbol("sub_game_core_routine"), function()
    if byte(ram.mode) == 1 and byte(ram.task) == 3
        and byte(ram.world) == 0 and byte(ram.area) == 0 then
        emit_once("world_1_1_start", "sub_game_core_routine")
    end
end)

memory.registerexecute(symbol("handler_player_entrance"), function()
    if byte(ram.mode) == 1 then
        emit_once("area_entrance", "handler_player_entrance")
        if seen["life_lost"] then
            emit_once("respawn", "handler_player_entrance")
        end
    end
end)

memory.registerexecute(symbol("sub_flagpole_routine"), function()
    if byte(ram.game_routine) == 4 and byte(ram.enemy_id + 5) == 0x30 then
        emit_once("flagpole", "sub_flagpole_routine")
    end
end)

output:write("frame,event,detail,mode,task,player_state,player_status,page,x,y,x_speed,y_speed,coins,lives,world,area\n")
emit("trace_start", scenario)

local forbidden_execute = os.getenv("SMB_RUNTIME_FORBID_EXECUTE")
if forbidden_execute ~= nil and forbidden_execute ~= "" then
    for token in string.gmatch(forbidden_execute, "[^,]+") do
        local probe_address = assert(tonumber(string.gsub(token, "^0x", ""), 16))
        memory.registerexecute(probe_address, function()
            emit("forbidden_execute", string.format("%04X", probe_address))
        end)
    end
end

local previous_x = byte(ram.x)
local previous_page = byte(ram.page)
local controlled_patch_applied = false
while emu.framecount() < max_frames do
    emu.frameadvance()
    if not controlled_patch_applied and emu.framecount() >= 250 then
        if scenario == "power-up-collection" then
            patch(ram.enemy_flag + 5, 0x01, "activate_power_up_slot")
            patch(ram.enemy_id + 5, 0x2E, "select_power_up_object")
            patch(ram.enemy_state + 5, 0x80, "select_active_power_up_state")
            patch(ram.enemy_bbox + 5, 0x03, "select_power_up_bounds")
            patch(ram.enemy_page + 5, byte(ram.page), "overlap_player_page")
            patch(ram.enemy_x + 5, byte(ram.x), "overlap_player_x")
            patch(ram.enemy_y_high + 5, byte(ram.player_y_high), "overlap_player_y_page")
            patch(ram.enemy_y + 5, byte(ram.y), "overlap_player_y")
            patch(ram.enemy_offscreen + 5, 0x00, "mark_power_up_onscreen")
            patch(ram.power_type, 0x00, "select_super_mushroom")
            controlled_patch_applied = true
        elseif scenario == "death-respawn" then
            patch(ram.game_routine, 0x0B, "enter_death_handler")
            patch(ram.timer_control, 0x00, "allow_death_motion")
            patch(ram.player_y_high, 0x06, "cross_death_boundary")
            patch(ram.event_music, 0x00, "complete_death_music_gate")
            controlled_patch_applied = true
        end
    end
    local current_x = byte(ram.x)
    local current_page = byte(ram.page)
    if byte(ram.mode) == 1 and byte(ram.state) == 0
        and (current_x ~= previous_x or current_page ~= previous_page)
        and byte(ram.x_speed) ~= 0 then
        emit_once("walking", "grounded horizontal displacement")
    end
    if emu.framecount() % 600 == 0 then
        emit("checkpoint", "periodic state sample")
    end
    previous_x = current_x
    previous_page = current_page
end

emit("trace_end", scenario)
output:close()
emu.exit()
