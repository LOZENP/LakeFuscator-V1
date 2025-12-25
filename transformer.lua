-- transformer
-- walks ast and renames vars, encodes strings etc

local utils = require("utils")

local transformer = {}

local function newContext()
    return {
        varMap = {},
        counter = 0,
        scopes = {{}},
    }
end

local function pushScope(ctx)
    table.insert(ctx.scopes, {})
end

local function popScope(ctx)
    table.remove(ctx.scopes)
end

local function defineVar(ctx, name, opts)
    if utils.isKeyword(name) then return end
    
    local style = opts.nameStyle or "mixed"
    local newName = utils.generateName(ctx.counter, style)
    ctx.counter = ctx.counter + 1
    
    ctx.varMap[name] = newName
    ctx.scopes[#ctx.scopes][name] = true
end

local function renameVar(ctx, name)
    if utils.isKeyword(name) then return name end
    return ctx.varMap[name] or name
end

local function walkExpr(expr, ctx, opts)
    if not expr then return expr end
    
    if expr.node == "var" then
        expr.name = renameVar(ctx, expr.name)
        return expr
    end
    
    if expr.node == "string" then
        if opts.encodeStrings then
            expr.encoded = utils.encodeString(expr.value)
        end
        return expr
    end
    
    if expr.node == "number" then
        if opts.encodeNumbers then
            expr.encoded = utils.encodeNumber(expr.value)
        end
        return expr
    end
    
    if expr.node == "binop" then
        expr.left = walkExpr(expr.left, ctx, opts)
        expr.right = walkExpr(expr.right, ctx, opts)
        return expr
    end
    
    if expr.node == "unop" then
        expr.expr = walkExpr(expr.expr, ctx, opts)
        return expr
    end
    
    if expr.node == "call" then
        if type(expr.func) == "table" then
            expr.func = walkExpr(expr.func, ctx, opts)
        else
            expr.func = renameVar(ctx, expr.func)
        end
        for i = 1, #expr.args do
            expr.args[i] = walkExpr(expr.args[i], ctx, opts)
        end
        return expr
    end
    
    if expr.node == "index" then
        if type(expr.obj) == "table" then
            expr.obj = walkExpr(expr.obj, ctx, opts)
        else
            expr.obj = renameVar(ctx, expr.obj)
        end
        if not expr.dot and type(expr.key) == "table" then
            expr.key = walkExpr(expr.key, ctx, opts)
        end
        return expr
    end
    
    if expr.node == "function" then
        pushScope(ctx)
        for _, param in ipairs(expr.params) do
            defineVar(ctx, param, opts)
        end
        expr.params = {}
        for i, param in ipairs(expr.params or {}) do
            expr.params[i] = renameVar(ctx, param)
        end
        expr.body = walkBlock(expr.body, ctx, opts)
        popScope(ctx)
        return expr
    end
    
    if expr.node == "table" then
        for i = 1, #expr.items do
            local item = expr.items[i]
            if item.key then
                item.key = walkExpr(item.key, ctx, opts)
            end
            item.val = walkExpr(item.val, ctx, opts)
        end
        return expr
    end
    
    return expr
end

function walkBlock(stmts, ctx, opts)
    for i = 1, #stmts do
        stmts[i] = walkStmt(stmts[i], ctx, opts)
    end
    return stmts
end

function walkStmt(stmt, ctx, opts)
    if not stmt then return stmt end
    
    if stmt.node == "local" then
        local init = stmt.init
        if init then
            for i = 1, #init do
                init[i] = walkExpr(init[i], ctx, opts)
            end
        end
        for _, name in ipairs(stmt.names) do
            defineVar(ctx, name, opts)
        end
        local newNames = {}
        for i, name in ipairs(stmt.names) do
            newNames[i] = renameVar(ctx, name)
        end
        stmt.names = newNames
        return stmt
    end
    
    if stmt.node == "localfunc" then
        defineVar(ctx, stmt.name, opts)
        stmt.name = renameVar(ctx, stmt.name)
        
        pushScope(ctx)
        for _, param in ipairs(stmt.params) do
            defineVar(ctx, param, opts)
        end
        local newParams = {}
        for i, param in ipairs(stmt.params) do
            newParams[i] = renameVar(ctx, param)
        end
        stmt.params = newParams
        stmt.body = walkBlock(stmt.body, ctx, opts)
        popScope(ctx)
        return stmt
    end
    
    if stmt.node == "func" then
        defineVar(ctx, stmt.name, opts)
        stmt.name = renameVar(ctx, stmt.name)
        
        pushScope(ctx)
        for _, param in ipairs(stmt.params) do
            defineVar(ctx, param, opts)
        end
        local newParams = {}
        for i, param in ipairs(stmt.params) do
            newParams[i] = renameVar(ctx, param)
        end
        stmt.params = newParams
        stmt.body = walkBlock(stmt.body, ctx, opts)
        popScope(ctx)
        return stmt
    end
    
    if stmt.node == "assign" then
        for i = 1, #stmt.vals do
            stmt.vals[i] = walkExpr(stmt.vals[i], ctx, opts)
        end
        for i = 1, #stmt.targets do
            stmt.targets[i] = walkExpr(stmt.targets[i], ctx, opts)
        end
        return stmt
    end
    
    if stmt.node == "if" then
        stmt.cond = walkExpr(stmt.cond, ctx, opts)
        stmt.tbody = walkBlock(stmt.tbody, ctx, opts)
        if stmt.ebody then
            stmt.ebody = walkBlock(stmt.ebody, ctx, opts)
        end
        return stmt
    end
    
    if stmt.node == "while" then
        stmt.cond = walkExpr(stmt.cond, ctx, opts)
        stmt.body = walkBlock(stmt.body, ctx, opts)
        return stmt
    end
    
    if stmt.node == "fornum" then
        pushScope(ctx)
        stmt.start = walkExpr(stmt.start, ctx, opts)
        stmt.finish = walkExpr(stmt.finish, ctx, opts)
        if stmt.step then
            stmt.step = walkExpr(stmt.step, ctx, opts)
        end
        defineVar(ctx, stmt.var, opts)
        stmt.var = renameVar(ctx, stmt.var)
        stmt.body = walkBlock(stmt.body, ctx, opts)
        popScope(ctx)
        return stmt
    end
    
    if stmt.node == "return" then
        for i = 1, #stmt.vals do
            stmt.vals[i] = walkExpr(stmt.vals[i], ctx, opts)
        end
        return stmt
    end
    
    if stmt.node == "exprstmt" then
        stmt.expr = walkExpr(stmt.expr, ctx, opts)
        return stmt
    end
    
    return stmt
end

function transformer.transform(ast, opts)
    opts = opts or {}
    local ctx = newContext()
    
    if ast.node == "chunk" then
        ast.body = walkBlock(ast.body, ctx, opts)
    end
    
    return ast
end

return transformer
