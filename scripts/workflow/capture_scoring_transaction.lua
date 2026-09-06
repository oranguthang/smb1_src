-- Capture exact score, coin, HUD, and top-score transactions from SMB1.

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
    display = symbol("ram_display_digits"),
    score = symbol("ram_player_score_display"),
    top_score = symbol("ram_display_digits"),
    vram_offset = symbol("ram_vram_buffer1_offset"),
    vram = symbol("ram_vram_buffer1"),
    flagpole_score = symbol("ram_flagpole_score"),
    enemy_id = symbol("ram_enemy_id"),
    stomp_chain = symbol("ram_stomp_chain_counter"),
    stomp_timer = symbol("ram_stomp_timer"),
}

local function byte(address)
    return memory.readbyte(address)
end

local function digits(address, count)
    local result = {}
    for offset = 0, count - 1 do
        result[#result + 1] = string.format("%X", byte(address + offset))
    end
    return table.concat(result)
end

local function hex_bytes(address, count)
    local result = {}
    for offset = 0, count - 1 do
        result[#result + 1] = string.format("%02X", byte(address + offset))
    end
    return table.concat(result)
end

local function snapshot()
    return {
        score = digits(ram.score, 6),
        top_score = digits(ram.top_score, 6),
        coins = byte(ram.coins),
        lives = byte(ram.lives),
        coin_display = digits(ram.display + 0x16, 2),
    }
end

local function emit(event, detail)
    output:write(string.format(
        "%d,%s,%s,%02X,%02X,%02X,%02X,%02X,%02X,%02X,%02X,%02X,%02X,%02X,%02X,%02X\n",
        emu.framecount(), event, detail or "", byte(ram.mode), byte(ram.task),
        byte(ram.state), byte(ram.status), byte(ram.page), byte(ram.x), byte(ram.y),
        byte(ram.x_speed), byte(ram.y_speed), byte(ram.coins), byte(ram.lives),
        byte(ram.world), byte(ram.area)))
    output:flush()
end

local function patch(address, value, reason)
    local previous = byte(address)
    memory.writebyte(address, value)
    emit("controlled_patch", string.format(
        "%04X:%02X>%02X:%s", address, previous, value, reason))
end

local function accepts(kind)
    if string.sub(scenario, 1, 4) == "coin" or scenario == "decimal-score-carry" then
        return kind == "coin"
    elseif scenario == "enemy-stomp-award" or scenario == "stomp-chain-award" then
        return kind == "floating"
    elseif scenario == "flagpole-award" then
        return kind == "flagpole"
    end
    return false
end

local pending = nil
local pending_hud = nil
local pending_top = nil
local transaction_emitted = false

local function begin_transaction(kind, source)
    if transaction_emitted or pending ~= nil or not accepts(kind) then
        return
    end
    pending = {source = source, before = snapshot()}
end

memory.registerexecute(symbol("sub_give_one_coin"), function()
    begin_transaction("coin", "coin")
end)

memory.registerexecute(symbol("bra_award_floating_score"), function()
    local control = memory.getregister("y")
    begin_transaction("floating", string.format("floating:%02X", control))
end)

memory.registerexecute(symbol("bra_award_flagpole_score"), function()
    begin_transaction("flagpole", string.format("flagpole:%02X", byte(ram.flagpole_score)))
end)

memory.registerexecute(symbol("sub_get_status_bar_nibbles"), function()
    if pending == nil then
        return
    end
    local after = snapshot()
    emit("score_transaction", string.format(
        "source=%s;score=%s>%s;coins=%02X>%02X;lives=%02X>%02X;coin_display=%s>%s",
        pending.source, pending.before.score, after.score,
        pending.before.coins, after.coins, pending.before.lives, after.lives,
        pending.before.coin_display, after.coin_display))
    pending_hud = {source = pending.source, score = after.score}
    pending_top = {source = pending.source, before = pending.before.top_score}
    pending = nil
    transaction_emitted = true
end)

memory.registerexecute(symbol("bra_finish_score_zero_suppression"), function()
    if pending_hud == nil then
        return
    end
    local offset = byte(ram.vram_offset)
    emit("score_hud_packet", string.format(
        "source=%s;score=%s;tiles=%s",
        pending_hud.source, pending_hud.score, hex_bytes(ram.vram + offset - 6, 6)))
    pending_hud = nil
end)

memory.registerwrite(ram.top_score, 6, function(address, size, value)
    if pending_top == nil or address ~= ram.top_score + 5 then
        return
    end
    local updated = digits(ram.top_score, 5) .. string.format("%X", value)
    emit("top_score_update", string.format(
        "source=%s;top=%s>%s", pending_top.source, pending_top.before, updated))
    pending_top = nil
end)

local stomp_patch_applied = false
memory.registerexecute(symbol("loc_enemy_stomped"), function()
    if scenario ~= "stomp-chain-award" or stomp_patch_applied then
        return
    end
    local enemy_slot = memory.getregister("x")
    patch(ram.enemy_id + enemy_slot, 0x09, "select_stomped_shell")
    patch(ram.stomp_chain, 0x02, "set_stomp_chain")
    patch(ram.stomp_timer, 0x01, "set_stomp_timer")
    emit("stomp_chain_selected", string.format("slot=%d;chain=02;timer=01", enemy_slot))
    stomp_patch_applied = true
end)

output:write("frame,event,detail,mode,task,player_state,player_status,page,x,y,x_speed,y_speed,coins,lives,world,area\n")
emit("trace_start", scenario)

local initial_patch_applied = false
while emu.framecount() < max_frames do
    emu.frameadvance()
    if not initial_patch_applied and emu.framecount() >= 250 then
        if scenario == "coin-extra-life" then
            patch(ram.coins, 0x63, "set_99_coin_tally")
            patch(ram.display + 0x16, 0x09, "set_99_coin_tens")
            patch(ram.display + 0x17, 0x09, "set_99_coin_ones")
        elseif scenario == "decimal-score-carry" then
            local score = {0x00, 0x00, 0x09, 0x09, 0x09, 0x00}
            for index = 0, 5 do
                patch(ram.score + index, score[index + 1], "set_score_digit_" .. index)
            end
        end
        initial_patch_applied = true
    end
end

emit("trace_end", scenario)
output:close()
emu.exit()
