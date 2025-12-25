-- generator
-- turns ast back into lua code

local generator = {}

local function genExpr(expr, opts)
    if not expr then return "" end
    
    if expr.node == "var" then
        return expr.name
    end
    
    if expr.node == "number" then
        if expr.encoded and opts.encodeNumbers then
            return expr.encoded
        end
        return tostring(expr.value)
    end
    
    if expr.node == "string" then
        if expr.encoded and opts.encodeStrings then
            return expr.encoded
        end
        return '"' .. expr.value:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n') .. '"'
    end
    
    if expr.node == "boolean" then
        return expr.value and "true" or "false"
    end
    
    if expr.node == "nil" then
        return "nil"
    end
    
    if expr.node == "binop" then
        local left = genExpr(expr.left, opts)
        local right = genExpr(expr.right, opts)
        return "(" .. left .. expr.op .. right .. ")"
    end
    
    if expr.node == "unop" then
        local e = genExpr(expr.expr, opts)
        if expr.op == "not" then
            return "(not " .. e .. ")"
        end
        return "(" .. expr.op .. e .. ")"
    end
    
    if expr.node == "call" then
        local func = type(expr.func) == "table" and genExpr(expr.func, opts) or expr.func
        local args = {}
        for i = 1, #expr.args do
            args[i] = genExpr(expr.args[i], opts)
        end
        return func .. "(" .. table.concat(args, ",") .. ")"
    end
    
    if expr.node == "index" then
        local obj = type(expr.obj) == "table" and genExpr(expr.obj, opts) or expr.obj
        if expr.dot then
            return obj .. "." .. expr.key
        else
            local key = type(expr.key) == "table" and genExpr(expr.key, opts) or expr.key
            return obj .. "[" .. key .. "]"
        end
    end
    
    if expr.node == "function" then
        local params = table.concat(expr.params, ",")
        local body = genBlock(expr.body, opts, "")
        return "function(" .. params .. ")" .. body .. "end"
    end
    
    if expr.node == "table" then
        local items = {}
        for i = 1, #expr.items do
            local item = expr.items[i]
            if item.key then
                local k = genExpr(item.key, opts)
                local v = genExpr(item.val, opts)
                items[i] = "[" .. k .. "]=" .. v
            else
                items[i] = genExpr(item.val, opts)
            end
        end
        return "{" .. table.concat(items, ",") .. "}"
    end
    
    return ""
end

function genBlock(stmts, opts, indent)
    local result = {}
    indent = indent or ""
    
    for i = 1, #stmts do
        local line = genStmt(stmts[i], opts, indent)
        if line and line ~= "" then
            table.insert(result, line)
        end
    end
    
    return table.concat(result, "")
end

function genStmt(stmt, opts, indent)
    if not stmt then return "" end
    indent = indent or ""
    
    if stmt.node == "local" then
        local names = table.concat(stmt.names, ",")
        if stmt.init then
            local vals = {}
            for i = 1, #stmt.init do
                vals[i] = genExpr(stmt.init[i], opts)
            end
            return indent .. "local " .. names .. "=" .. table.concat(vals, ",") .. ";"
        end
        return indent .. "local " .. names .. ";"
    end
    
    if stmt.node == "localfunc" then
        local params = table.concat(stmt.params, ",")
        local body = genBlock(stmt.body, opts, indent)
        return indent .. "local function " .. stmt.name .. "(" .. params .. ")" .. body .. indent .. "end;"
    end
    
    if stmt.node == "func" then
        local params = table.concat(stmt.params, ",")
        local body = genBlock(stmt.body, opts, indent)
        return indent .. "function " .. stmt.name .. "(" .. params .. ")" .. body .. indent .. "end;"
    end
    
    if stmt.node == "assign" then
        local targets = {}
        for i = 1, #stmt.targets do
            targets[i] = genExpr(stmt.targets[i], opts)
        end
        local vals = {}
        for i = 1, #stmt.vals do
            vals[i] = genExpr(stmt.vals[i], opts)
        end
        return indent .. table.concat(targets, ",") .. "=" .. table.concat(vals, ",") .. ";"
    end
    
    if stmt.node == "if" then
        local cond = genExpr(stmt.cond, opts)
        local tbody = genBlock(stmt.tbody, opts, indent)
        if stmt.ebody then
            local ebody = genBlock(stmt.ebody, opts, indent)
            return indent .. "if " .. cond .. " then " .. tbody .. indent .. "else " .. ebody .. indent .. "end;"
        end
        return indent .. "if " .. cond .. " then " .. tbody .. indent .. "end;"
    end
    
    if stmt.node == "while" then
        local cond = genExpr(stmt.cond, opts)
        local body = genBlock(stmt.body, opts, indent)
        return indent .. "while " .. cond .. " do " .. body .. indent .. "end;"
    end
    
    if stmt.node == "fornum" then
        local start = genExpr(stmt.start, opts)
        local finish = genExpr(stmt.finish, opts)
        local step = stmt.step and ("," .. genExpr(stmt.step, opts)) or ""
        local body = genBlock(stmt.body, opts, indent)
        return indent .. "for " .. stmt.var .. "=" .. start .. "," .. finish .. step .. " do " .. body .. indent .. "end;"
    end
    
    if stmt.node == "return" then
        if #stmt.vals == 0 then
            return indent .. "return;"
        end
        local vals = {}
        for i = 1, #stmt.vals do
            vals[i] = genExpr(stmt.vals[i], opts)
        end
        return indent .. "return " .. table.concat(vals, ",") .. ";"
    end
    
    if stmt.node == "break" then
        return indent .. "break;"
    end
    
    if stmt.node == "exprstmt" then
        return indent .. genExpr(stmt.expr, opts) .. ";"
    end
    
    return ""
end

function generator.generate(ast, opts)
    opts = opts or {}
    
    if not ast or ast.node ~= "chunk" then
        return ""
    end
    
    local code = genBlock(ast.body, opts, "")
    
    -- wrap in function like the example
    if opts.wrapInFunc ~= false then
        local wrapVar = "..."
        code = "return(function(" .. wrapVar .. ")" .. code .. "end)(...);"
    end
    
    return code
end

return generator
