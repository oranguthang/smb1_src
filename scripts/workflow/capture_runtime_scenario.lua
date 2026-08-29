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
    game_timer_ctrl = symbol("ram_game_timer_ctrl_timer"),
    game_timer = symbol("ram_game_timer_display"),
    game_timer_expired = symbol("ram_game_timer_expired_flag"),
    block_slot = symbol("ram_block_object_slot"),
    block_oam = symbol("ram_alt_spr_data_offset"),
    square2_queue = symbol("ram_square2_sound_queue"),
    square2_buffer = symbol("ram_square2_sound_buffer"),
    square2_length = symbol("ram_squ2_sfx_len_counter"),
    music_offset_square2 = symbol("ram_music_offset_square2"),
}

local function byte(address)
    return memory.readbyte(address)
end

local seen = {}
local controlled_patch_applied = false
local time_up_transition_seen = false
local sfx_probe_active = false
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
    {"sub_get_misc_bound_box", "misc_bound_box"},
    {"sub_process_hammer_object", "hammer_object"},
}

for _, hook in ipairs(hooks) do
    local routine = hook[1]
    local event = hook[2]
    memory.registerexecute(symbol(routine), function()
        emit_once(event, routine)
    end)
end

memory.registerexecute(symbol("handler_display_time_up_screen"), function()
    if byte(ram.game_timer_expired) ~= 0 then
        time_up_transition_seen = true
        emit_once("time_up_screen", "handler_display_time_up_screen")
    end
end)

memory.registerexecute(symbol("sub_player_head_collision"), function()
    local slot = byte(ram.block_slot)
    emit_once("block_slot_select", string.format("slot=%d:oam=%02X", slot, byte(ram.block_oam + slot)))
end)

memory.registerexecute(symbol("loc_toggle_block_object_slot"), function()
    local slot = byte(ram.block_slot)
    emit_once("block_slot_toggle", string.format("%d>%d", slot, slot == 0 and 1 or 0))
end)

memory.registerexecute(symbol("bra_use_alternate_score_oam_offset"), function()
    local slot = byte(ram.block_slot)
    emit_once("alternate_oam_select", string.format("slot=%d:oam=%02X", slot, byte(ram.block_oam + slot)))
end)

memory.registerexecute(symbol("loc_continue_coin_or_timer_sound"), function()
    if sfx_probe_active then
        local counter = byte(ram.square2_length)
        emit_once("coin_or_timer_continue", string.format("counter=%02X", counter))
        if counter == 0x30 then
            emit_once("coin_second_tone", "counter=30")
        end
    end
end)

memory.registerexecute(symbol("loc_clear_square_2_sound_buffer"), function()
    if sfx_probe_active then
        emit_once("square2_sfx_end", "counter=00")
    end
end)

local square2_start_writes = {}
memory.registerwrite(0x4004, 4, function(address, size, value)
    if sfx_probe_active and not seen["square2_start_registers"] then
        square2_start_writes[address] = value
        if square2_start_writes[0x4004] ~= nil
            and square2_start_writes[0x4005] ~= nil
            and square2_start_writes[0x4006] ~= nil
            and square2_start_writes[0x4007] ~= nil then
            emit_once("square2_start_registers", string.format(
                "4004=%02X;4005=%02X;4006=%02X;4007=%02X",
                square2_start_writes[0x4004], square2_start_writes[0x4005],
                square2_start_writes[0x4006], square2_start_writes[0x4007]))
        end
    end
end)

local music_residual_write_expected = false
local music_offset_pending = false
memory.registerexecute(symbol("bra_find_area_music_header"), function()
    music_residual_write_expected = true
end)
memory.registerwrite(ram.music_offset_square2, function(address, size, value)
    if music_residual_write_expected and value == 0x08 then
        music_residual_write_expected = false
        music_offset_pending = true
        emit_once("music_offset_residual_write", "08")
    elseif music_offset_pending and value == 0x00 then
        emit_once("music_offset_immediate_reset", "08>00")
        music_offset_pending = false
    end
end)
memory.registerread(ram.music_offset_square2, function()
    if music_offset_pending then
        emit_once("music_offset_early_read", "value_observed_before_reset")
    end
end)

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

local time_up_clear_packet = symbol("off_world_lives_display_packet") + 0x16
memory.registerread(time_up_clear_packet, 4, function()
    if time_up_transition_seen then
        emit_once("time_up_clear_packet_read", "off_time_up_clear_packet")
    end
end)

local ppu_address_high = nil
local ppu_address = nil
local time_up_clear_tiles = {}
memory.registerread(0x2002, function()
    ppu_address_high = nil
end)
memory.registerwrite(0x2006, function(address, size, value)
    if ppu_address_high == nil then
        ppu_address_high = value
    else
        ppu_address = ppu_address_high * 0x100 + value
        ppu_address_high = nil
    end
end)
memory.registerwrite(0x2007, function(address, size, value)
    if ppu_address ~= nil and time_up_transition_seen then
        if ppu_address >= 0x220c and ppu_address <= 0x2212 then
            time_up_clear_tiles[ppu_address - 0x220c + 1] = value
            if #time_up_clear_tiles == 7 then
                local all_blank = true
                for _, tile in ipairs(time_up_clear_tiles) do
                    all_blank = all_blank and tile == 0x24
                end
                if all_blank then
                    emit_once("time_up_clear_vram", "220C-2212:24")
                end
            end
        end
        ppu_address = (ppu_address + 1) % 0x4000
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
        elseif scenario == "time-up-clear" then
            patch(ram.game_timer, 0x00, "expire_game_timer_hundreds")
            patch(ram.game_timer + 1, 0x00, "expire_game_timer_tens")
            patch(ram.game_timer + 2, 0x00, "expire_game_timer_ones")
            patch(ram.game_timer_ctrl, 0x00, "allow_game_timer_tick")
            controlled_patch_applied = true
        elseif scenario == "timer-tick-sfx" then
            patch(ram.square2_buffer, 0x00, "clear_square2_sfx_buffer")
            patch(ram.square2_length, 0x00, "clear_square2_sfx_length")
            patch(ram.square2_queue, 0x10, "queue_timer_tick")
            sfx_probe_active = true
            controlled_patch_applied = true
        elseif scenario == "coin-sfx" then
            patch(ram.square2_buffer, 0x00, "clear_square2_sfx_buffer")
            patch(ram.square2_length, 0x00, "clear_square2_sfx_length")
            patch(ram.square2_queue, 0x01, "queue_coin")
            sfx_probe_active = true
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
