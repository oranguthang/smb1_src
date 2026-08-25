-- Prove that FCEUX loaded generated semantic symbols and can break on one.

local output_path = assert(os.getenv("SMB_DEBUG_SYMBOL_RESULT"))
local expected_text = assert(os.getenv("SMB_DEBUG_EXPECTED"))
local output = assert(io.open(output_path, "w"))

local expected = {}
for name, address in string.gmatch(expected_text, "([%w_]+)=([0-9A-Fa-f]+)") do
    expected[name] = tonumber(address, 16)
end

local lookup_count = 0
for name, expected_address in pairs(expected) do
    local actual_address = debugger.getsymboloffset(name)
    output:write(string.format(
        "symbol,%s,%04X,%04X\n", name, actual_address or -1, expected_address))
    lookup_count = lookup_count + 1
    if actual_address ~= expected_address then
        output:write("FAIL,symbol_lookup\n")
        output:close()
        emu.exit()
        return
    end
end

local nmi_address = debugger.getsymboloffset("vec_nmi_handler")
local nmi_hit = false
memory.registerexecute(nmi_address, function()
    nmi_hit = true
end)

for _ = 1, 180 do
    if nmi_hit then
        break
    end
    emu.frameadvance()
end

if not nmi_hit then
    output:write("FAIL,semantic_breakpoint\n")
else
    output:write(string.format(
        "break,vec_nmi_handler,%04X,%d\n", nmi_address, emu.framecount()))
    output:write(string.format("lookups,%d\n", lookup_count))
    output:write("OK\n")
end
output:close()
emu.exit()
