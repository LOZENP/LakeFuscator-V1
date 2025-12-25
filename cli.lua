#!/usr/bin/env lua
-- cli tool for lakefuscator
-- usage: lua cli.lua input.lua output.lua [options]

local lf = require("init")

local function printHelp()
    print([[
LakeFuscator V1 - Lua Obfuscator

Usage: lua cli.lua <input> <output> [options]

Options:
  --no-rename         dont rename variables
  --encode-strings    encode string literals
  --encode-numbers    encode number literals  
  --no-wrap          dont wrap in function
  --style=<style>     variable naming style (mixed/zero/underscore)
  --help             show this help

Examples:
  lua cli.lua script.lua obf.lua
  lua cli.lua input.lua output.lua --encode-strings --encode-numbers
  lua cli.lua test.lua out.lua --style=zero --no-wrap
]])
end

local args = {...}

if #args == 0 or args[1] == "--help" or args[1] == "-h" then
    printHelp()
    os.exit(0)
end

if #args < 2 then
    print("error: need input and output files")
    print("try: lua cli.lua --help")
    os.exit(1)
end

local input = args[1]
local output = args[2]

local opts = {
    renameVars = true,
    encodeStrings = false,
    encodeNumbers = false,
    wrapInFunc = true,
    nameStyle = "mixed",
}

for i = 3, #args do
    local arg = args[i]
    if arg == "--no-rename" then
        opts.renameVars = false
    elseif arg == "--encode-strings" then
        opts.encodeStrings = true
    elseif arg == "--encode-numbers" then
        opts.encodeNumbers = true
    elseif arg == "--no-wrap" then
        opts.wrapInFunc = false
    elseif arg:match("^--style=") then
        opts.nameStyle = arg:match("^--style=(.+)$")
    end
end

print("lakefuscator v" .. lf.version)
print("input: " .. input)
print("output: " .. output)
print("")

local result, err = lf.obfuscateFile(input, output, opts)

if not result then
    print("error: " .. err)
    os.exit(1)
end

print("done!")
print("")
print("options used:")
print("  rename vars: " .. (opts.renameVars and "yes" or "no"))
print("  encode strings: " .. (opts.encodeStrings and "yes" or "no"))
print("  encode numbers: " .. (opts.encodeNumbers and "yes" or "no"))
print("  wrap in func: " .. (opts.wrapInFunc and "yes" or "no"))
print("  name style: " .. opts.nameStyle)

-- don't mind this HAHA
