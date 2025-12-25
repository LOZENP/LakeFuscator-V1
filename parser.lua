-- parser module
-- tokenizes and builds ast from lua source

local parser = {}
local utils = require("utils")

local TK = {
    EOF = "eof",
    NAME = "name",
    NUMBER = "number", 
    STRING = "string",
    KEYWORD = "keyword",
    OP = "op",
}

local function lex(src)
    local tokens = {}
    local pos = 1
    local line = 1
    
    local function peek(offset)
        offset = offset or 0
        return src:sub(pos + offset, pos + offset)
    end
    
    local function advance()
        local c = peek()
        pos = pos + 1
        if c == '\n' then line = line + 1 end
        return c
    end
    
    local function skipWs()
        while true do
            local c = peek()
            if c == ' ' or c == '\t' or c == '\r' or c == '\n' then
                advance()
            elseif c == '-' and peek(1) == '-' then
                advance()
                advance()
                if peek() == '[' and peek(1) == '[' then
                    advance()
                    advance()
                    while not (peek() == ']' and peek(1) == ']') do
                        if peek() == '' then break end
                        advance()
                    end
                    if peek() ~= '' then advance() end
                    if peek() ~= '' then advance() end
                else
                    while peek() ~= '\n' and peek() ~= '' do
                        advance()
                    end
                end
            else
                break
            end
        end
    end
    
    local function readStr(quote)
        local s = ""
        advance()
        while true do
            local c = peek()
            if c == '' or c == quote then
                if c == quote then advance() end
                break
            end
            if c == '\\' then
                advance()
                local n = advance()
                if n == 'n' then s = s .. '\n'
                elseif n == 't' then s = s .. '\t'
                elseif n == '\\' then s = s .. '\\'
                elseif n == quote then s = s .. quote
                else s = s .. n end
            else
                s = s .. c
                advance()
            end
        end
        return s
    end
    
    local function readNum()
        local n = ""
        while peek():match("[0-9.]") or peek():lower() == "e" or 
              (peek() == "-" and n:match("e$")) do
            n = n .. advance()
        end
        return tonumber(n)
    end
    
    local function readName()
        local n = ""
        while peek():match("[%w_]") do
            n = n .. advance()
        end
        return n
    end
    
    while pos <= #src do
        skipWs()
        if pos > #src then break end
        
        local c = peek()
        
        if c == '"' or c == "'" then
            table.insert(tokens, {type = TK.STRING, value = readStr(c), line = line})
        elseif c:match("[0-9]") then
            table.insert(tokens, {type = TK.NUMBER, value = readNum(), line = line})
        elseif c:match("[%a_]") then
            local name = readName()
            if utils.isKeyword(name) then
                table.insert(tokens, {type = TK.KEYWORD, value = name, line = line})
            else
                table.insert(tokens, {type = TK.NAME, value = name, line = line})
            end
        else
            local ops = {
                "==", "~=", "<=", ">=", "..", 
                "=", "<", ">", "+", "-", "*", "/", "%", "^", "#",
                "(", ")", "{", "}", "[", "]", ";", ":", ",", ".", "..."
            }
            local found = false
            for _, op in ipairs(ops) do
                if src:sub(pos, pos + #op - 1) == op then
                    for i = 1, #op do advance() end
                    table.insert(tokens, {type = TK.OP, value = op, line = line})
                    found = true
                    break
                end
            end
            if not found then advance() end
        end
    end
    
    table.insert(tokens, {type = TK.EOF, line = line})
    return tokens
end

local function parse(tokens)
    local pos = 1
    
    local function curr()
        return tokens[pos] or {type = TK.EOF}
    end
    
    local function next()
        pos = pos + 1
        return tokens[pos - 1]
    end
    
    local function expect(typ, val)
        local tok = curr()
        if tok.type ~= typ then return nil end
        if val and tok.value ~= val then return nil end
        return next()
    end
    
    local parseExpr, parseStmt
    
    local function parsePrimary()
        local tok = curr()
        
        if tok.type == TK.NUMBER then
            next()
            return {node = "number", value = tok.value}
        end
        
        if tok.type == TK.STRING then
            next()
            return {node = "string", value = tok.value}
        end
        
        if tok.type == TK.KEYWORD then
            if tok.value == "nil" then
                next()
                return {node = "nil"}
            end
            if tok.value == "true" or tok.value == "false" then
                next()
                return {node = "boolean", value = tok.value == "true"}
            end
            if tok.value == "function" then
                next()
                expect(TK.OP, "(")
                local params = {}
                while curr().value ~= ")" do
                    if curr().type == TK.NAME then
                        table.insert(params, next().value)
                    end
                    if curr().value == "," then next() end
                end
                expect(TK.OP, ")")
                local body = {}
                while curr().value ~= "end" do
                    local stmt = parseStmt()
                    if stmt then table.insert(body, stmt) end
                end
                expect(TK.KEYWORD, "end")
                return {node = "function", params = params, body = body}
            end
        end
        
        if tok.type == TK.NAME then
            local name = next().value
            
            while true do
                if curr().value == "(" then
                    next()
                    local args = {}
                    while curr().value ~= ")" do
                        table.insert(args, parseExpr())
                        if curr().value == "," then next() end
                    end
                    expect(TK.OP, ")")
                    name = {node = "call", func = name, args = args}
                elseif curr().value == "." then
                    next()
                    local prop = expect(TK.NAME)
                    name = {node = "index", obj = name, key = prop.value, dot = true}
                elseif curr().value == "[" then
                    next()
                    local idx = parseExpr()
                    expect(TK.OP, "]")
                    name = {node = "index", obj = name, key = idx}
                else
                    break
                end
            end
            
            if type(name) == "string" then
                return {node = "var", name = name}
            end
            return name
        end
        
        if tok.value == "(" then
            next()
            local e = parseExpr()
            expect(TK.OP, ")")
            return e
        end
        
        if tok.value == "{" then
            next()
            local items = {}
            while curr().value ~= "}" do
                if curr().value == "[" then
                    next()
                    local k = parseExpr()
                    expect(TK.OP, "]")
                    expect(TK.OP, "=")
                    local v = parseExpr()
                    table.insert(items, {key = k, val = v})
                else
                    local first = parseExpr()
                    if curr().value == "=" then
                        next()
                        local v = parseExpr()
                        table.insert(items, {key = first, val = v})
                    else
                        table.insert(items, {val = first})
                    end
                end
                if curr().value == "," or curr().value == ";" then next() end
            end
            expect(TK.OP, "}")
            return {node = "table", items = items}
        end
        
        if tok.value == "not" or tok.value == "-" or tok.value == "#" then
            local op = next().value
            return {node = "unop", op = op, expr = parsePrimary()}
        end
        
        return {node = "unknown"}
    end
    
    local prec = {
        ["or"] = 1, ["and"] = 2,
        ["<"] = 3, [">"] = 3, ["<="] = 3, [">="] = 3, ["~="] = 3, ["=="] = 3,
        [".."] = 4,
        ["+"] = 5, ["-"] = 5,
        ["*"] = 6, ["/"] = 6, ["%"] = 6,
        ["^"] = 7,
    }
    
    local function parseBinop(minPrec)
        local left = parsePrimary()
        
        while true do
            local tok = curr()
            local op = tok.value
            local p = prec[op]
            
            if not p or p < minPrec then break end
            
            next()
            local right = parseBinop(p + 1)
            left = {node = "binop", op = op, left = left, right = right}
        end
        
        return left
    end
    
    parseExpr = function()
        return parseBinop(0)
    end
    
    parseStmt = function()
        local tok = curr()
        
        if tok.type == TK.KEYWORD then
            if tok.value == "local" then
                next()
                if curr().type == TK.KEYWORD and curr().value == "function" then
                    next()
                    local name = expect(TK.NAME).value
                    expect(TK.OP, "(")
                    local params = {}
                    while curr().value ~= ")" do
                        if curr().type == TK.NAME then
                            table.insert(params, next().value)
                        end
                        if curr().value == "," then next() end
                    end
                    expect(TK.OP, ")")
                    local body = {}
                    while curr().value ~= "end" do
                        local s = parseStmt()
                        if s then table.insert(body, s) end
                    end
                    expect(TK.KEYWORD, "end")
                    return {node = "localfunc", name = name, params = params, body = body}
                else
                    local names = {}
                    while curr().type == TK.NAME do
                        table.insert(names, next().value)
                        if curr().value ~= "," then break end
                        next()
                    end
                    local init = nil
                    if curr().value == "=" then
                        next()
                        init = {}
                        while true do
                            table.insert(init, parseExpr())
                            if curr().value ~= "," then break end
                            next()
                        end
                    end
                    return {node = "local", names = names, init = init}
                end
            elseif tok.value == "function" then
                next()
                local name = expect(TK.NAME).value
                expect(TK.OP, "(")
                local params = {}
                while curr().value ~= ")" do
                    if curr().type == TK.NAME then
                        table.insert(params, next().value)
                    end
                    if curr().value == "," then next() end
                end
                expect(TK.OP, ")")
                local body = {}
                while curr().value ~= "end" do
                    local s = parseStmt()
                    if s then table.insert(body, s) end
                end
                expect(TK.KEYWORD, "end")
                return {node = "func", name = name, params = params, body = body}
            elseif tok.value == "if" then
                next()
                local cond = parseExpr()
                expect(TK.KEYWORD, "then")
                local tbody = {}
                while curr().value ~= "end" and curr().value ~= "else" and curr().value ~= "elseif" do
                    local s = parseStmt()
                    if s then table.insert(tbody, s) end
                end
                local ebody = nil
                if curr().value == "else" then
                    next()
                    ebody = {}
                    while curr().value ~= "end" do
                        local s = parseStmt()
                        if s then table.insert(ebody, s) end
                    end
                end
                expect(TK.KEYWORD, "end")
                return {node = "if", cond = cond, tbody = tbody, ebody = ebody}
            elseif tok.value == "while" then
                next()
                local cond = parseExpr()
                expect(TK.KEYWORD, "do")
                local body = {}
                while curr().value ~= "end" do
                    local s = parseStmt()
                    if s then table.insert(body, s) end
                end
                expect(TK.KEYWORD, "end")
                return {node = "while", cond = cond, body = body}
            elseif tok.value == "for" then
                next()
                local var = expect(TK.NAME).value
                if curr().value == "=" then
                    next()
                    local start = parseExpr()
                    expect(TK.OP, ",")
                    local finish = parseExpr()
                    local step = nil
                    if curr().value == "," then
                        next()
                        step = parseExpr()
                    end
                    expect(TK.KEYWORD, "do")
                    local body = {}
                    while curr().value ~= "end" do
                        local s = parseStmt()
                        if s then table.insert(body, s) end
                    end
                    expect(TK.KEYWORD, "end")
                    return {node = "fornum", var = var, start = start, finish = finish, step = step, body = body}
                end
            elseif tok.value == "return" then
                next()
                local vals = {}
                if curr().type ~= TK.KEYWORD or (curr().value ~= "end" and curr().value ~= "else") then
                    while true do
                        table.insert(vals, parseExpr())
                        if curr().value ~= "," then break end
                        next()
                    end
                end
                return {node = "return", vals = vals}
            elseif tok.value == "break" then
                next()
                return {node = "break"}
            end
        end
        
        local expr = parseExpr()
        if curr().value == "=" or curr().value == "," then
            local targets = {expr}
            while curr().value == "," do
                next()
                table.insert(targets, parseExpr())
            end
            if curr().value == "=" then
                next()
                local vals = {}
                while true do
                    table.insert(vals, parseExpr())
                    if curr().value ~= "," then break end
                    next()
                end
                return {node = "assign", targets = targets, vals = vals}
            end
        end
        
        return {node = "exprstmt", expr = expr}
    end
    
    local stmts = {}
    while curr().type ~= TK.EOF do
        local stmt = parseStmt()
        if stmt then 
            table.insert(stmts, stmt)
        else
            break
        end
    end
    
    return {node = "chunk", body = stmts}
end

function parser.parse(src)
    local ok, tokens = pcall(lex, src)
    if not ok then
        return nil, tokens
    end
    
    local ok2, ast = pcall(parse, tokens)
    if not ok2 then
        return nil, ast
    end
    
    return ast
end

return parser
