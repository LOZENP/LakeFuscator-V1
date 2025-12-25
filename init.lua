-- LakeFuscator V1
-- by  (R0DGIE)

local parser = require("parser")
local transformer = require("transformer") 
local generator = require("generator")

local lf = {}
lf.version = "1.0.0"

function lf.obfuscate(src, opts)
    opts = opts or {}
    
    local ast, err = parser.parse(src)
    if not ast then
        return nil, "parse failed: " .. tostring(err)
    end
    
    ast = transformer.transform(ast, opts)
    
    local output = generator.generate(ast, opts)
    
    return output
end

function lf.obfuscateFile(inpath, outpath, opts)
    local f = io.open(inpath, "r")
    if not f then 
        return nil, "cant open " .. inpath 
    end
    
    local src = f:read("*all")
    f:close()
    
    local result, err = lf.obfuscate(src, opts)
    if not result then 
        return nil, err 
    end
    
    local out = io.open(outpath, "w")
    if not out then 
        return nil, "cant write to " .. outpath 
    end
    
    out:write(result)
    out:close()
    
    return true
end

return lf
