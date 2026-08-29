-- Validate canonical gameplay startup in the expanded mapper profile

local target_frame = assert(tonumber(os.getenv("SMB_EXPANDED_FRAME")))
local expected_json = assert(os.getenv("SMB_EXPANDED_EXPECTED"))
local result_path = assert(os.getenv("SMB_EXPANDED_RESULT"))

local expected = {}
for address, value in string.gmatch(expected_json, '"(0x%x+)":"(0x%x+)"') do
    expected[tonumber(address)] = tonumber(value)
end

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

while emu.framecount() < target_frame do
    emu.frameadvance()
end

local result = "PASS"
if forbidden_hit ~= nil then
    result = string.format("FAIL:EXECUTE:%04X", forbidden_hit)
end
for address, value in pairs(expected) do
    if result ~= "PASS" then
        break
    end
    local actual = memory.readbyte(address)
    if actual ~= value then
        result = string.format("FAIL:%04X:%02X:%02X", address, actual, value)
        break
    end
end

local output = assert(io.open(result_path, "w"))
output:write(result .. "\n")
output:close()
emu.exit()
