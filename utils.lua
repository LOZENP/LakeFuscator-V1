-- utils for lakefuscator
-- random helper stuff

local utils = {}

-- generate those confusing variable names yeah...
function utils.generateName(idx, style)
    style = style or "mixed"
    
    if style == "mixed" then
        local name = ""
        local len = 40 + (idx % 60)
        for i = 1, len do
            name = name .. (math.random(0, 1) == 0 and "i" or "I")
        end
        return name
    elseif style == "zero" then
        local name = "O"
        for i = 1, 10 + (idx % 20) do
            name = name .. (math.random(0, 1) == 0 and "0" or "O")
        end
        return name
    elseif style == "underscore" then
        local name = "_"
        for i = 1, 8 + (idx % 12) do
            name = name .. (math.random(0, 1) == 0 and "_" or "__")
        end
        return name
    end
    
    return "var" .. idx
end

-- encode string to char codes
function utils.encodeString(str)
    if #str == 0 then return '""' end
    
    local method = math.random(1, 3)
    
    if method == 1 then
        -- string.char method
        local codes = {}
        for i = 1, #str do
            codes[i] = tostring(string.byte(str, i))
        end
        return "string.char(" .. table.concat(codes, ",") .. ")"
    elseif method == 2 then
        -- concatenation
        local parts = {}
        for i = 1, #str do
            local c = str:sub(i, i)
            if c == '"' then
                parts[i] = '"\\"' 
            elseif c == "\n" then
                parts[i] = '"\\n"'
            elseif c == "\\" then
                parts[i] = '"\\\\"'
            else
                parts[i] = '"' .. c .. '"'
            end
        end
        return table.concat(parts, "..")
    else
        -- mixed
        local result = "("
        local i = 1
        while i <= #str do
            local chunk_size = math.random(2, 5)
            local chunk = str:sub(i, i + chunk_size - 1)
            local codes = {}
            for j = 1, #chunk do
                codes[j] = tostring(string.byte(chunk, j))
            end
            if i > 1 then result = result .. ".." end
            result = result .. "string.char(" .. table.concat(codes, ",") .. ")"
            i = i + chunk_size
        end
        return result .. ")"
    end
end

-- encode number as expression
function utils.encodeNumber(num)
    local method = math.random(1, 4)
    
    if method == 1 then
        local a = math.random(1, 20)
        local b = num - a
        return string.format("(%d+%d)", a, b)
    elseif method == 2 then
        if num ~= 0 then
            local mult = math.random(2, 7)
            return string.format("((%d*%d)/%d)", num, mult, mult)
        end
        return "0"
    elseif method == 3 then
        local a = math.random(10, 50)
        return string.format("(%d-%d)", num + a, a)
    else
        return tostring(num)
    end
end

-- check if identifier is a lua keyword
function utils.isKeyword(name)
    local kw = {
        ["and"] = true, ["break"] = true, ["do"] = true, ["else"] = true,
        ["elseif"] = true, ["end"] = true, ["false"] = true, ["for"] = true,
        ["function"] = true, ["if"] = true, ["in"] = true, ["local"] = true,
        ["nil"] = true, ["not"] = true, ["or"] = true, ["repeat"] = true,
        ["return"] = true, ["then"] = true, ["true"] = true, ["until"] = true,
        ["while"] = true,
    }
    return kw[name] == true
end

-- deep copy table
function utils.deepCopy(tbl)
    if type(tbl) ~= "table" then return tbl end
    local copy = {}
    for k, v in pairs(tbl) do
        copy[k] = utils.deepCopy(v)
    end
    return copy
end

return utils
