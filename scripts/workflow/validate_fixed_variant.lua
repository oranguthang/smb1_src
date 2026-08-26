-- Validate the observable RAM effect of a fixed-layout variant

local hook_address = assert(tonumber(os.getenv("SMB_VARIANT_HOOK"), 16))
local ram_address = assert(tonumber(os.getenv("SMB_VARIANT_RAM"), 16))
local expected = assert(tonumber(os.getenv("SMB_VARIANT_EXPECTED"), 16))
local result_path = assert(os.getenv("SMB_VARIANT_RESULT"))

memory.registerexecute(hook_address, function()
    local output = assert(io.open(result_path, "w"))
    if memory.readbyte(ram_address) == expected then
        output:write("PASS\n")
    else
        output:write(string.format("FAIL:%02X\n", memory.readbyte(ram_address)))
    end
    output:close()
    emu.exit()
end)
