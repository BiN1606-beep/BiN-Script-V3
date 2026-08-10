--[[
    This is Moonav    

    Directly from ChatGPT.
    A translation from my luau RoNav into normal lua.
    Meant for LuaJIT 5.1
]]



local console = {}
console.__index = console

local unpack = unpack

-- ============================================================================
-- Utilities
-- ============================================================================

local function t_concat(t, ssep)
    local s = ""
    local sep = ssep or " "

    for i, v in ipairs(t) do
        if i < #t then
            s = s .. tostring(v) .. sep
        else
            s = s .. tostring(v)
        end
    end

    return s
end

local function t_sub(t, min, max)
    local r = {}
    local rp = 1

    if max then
        for i = min, max do
            r[rp] = t[i]
            rp = rp + 1
        end
    else
        for i = min, #t do
            r[rp] = t[i]
            rp = rp + 1
        end
    end

    return r
end

local function t_splice(t, i, j, u)
    for k = j, i, -1 do
        table.remove(t, k)
    end

    for k = 1, #u do
        table.insert(t, i + k - 1, u[k])
    end
end

local function removeStackTrace(str)
    str = tostring(str)

    local msg = string.match(str, "^.-:%d+: (.+)$")

    return msg or str
end

local function t_true (t)
    local r = {}
    for _, v in ipairs(t) do
        r[v] = true
    end
    return r
end



-- ============================================================================
-- Moonav tokenizer
-- ============================================================================

function console.tokenize(line)
    local last = 1
    local i = 1
    local out = {}

    local s = (line or "") .. " "

    while i < #s do
        repeat
            i = i + 1
        until s:sub(i, i) == " "

        table.insert(out, s:sub(last, i - 1))

        i = i + 1
        last = i
    end

    return out
end


-- ============================================================================
-- Directory handling
-- ============================================================================

function console:changeDir(t)
    table.insert(self.dirStack, self.currentDir)

    self.currentDir = t

    self.io:writeln("directory changed")
end


-- ============================================================================
-- Token evaluation
-- ============================================================================

function console:evalTokens(toks)
    -- Multiline command
    if type(toks[#toks]) == "string"
        and toks[#toks]:sub(-1) == "{"
    then
        local prog = {}
        local indent = 1

        while indent > 0 do
            self.io:write("... ")

            local line = self.io:read()

            table.insert(prog, line)

            if line:sub(1, 1) == "}" then
                indent = indent - 1

            elseif line:sub(-1) == "{" then
                indent = indent + 1
            end
        end

        local last = table.remove(prog):sub(3)

        toks[#toks] = function()
            local r = {}

            for _, v in ipairs(prog) do
                r = {
                    self:runString(v)
                }
            end

            return unpack(r)
        end

        local evaluated = self:evalTokens(
            console.tokenize(last)
        )

        for _, v in ipairs(evaluated) do
            table.insert(toks, v)
        end
    end

    local index = 1

    while index <= #toks do

        -- Prefix command:
        --
        -- [ ... ]
        -- ![ ... ]
        -- '[ ... ]
        -- etc.
        --
        if type(toks[index]) == "string"
            and toks[index]:sub(2, 2) == "["
        then
            local indent = 0
            local i = index

            repeat
                local s = toks[index]

                local _, a = string.gsub(s, "%[", "")
                local _, b = string.gsub(s, "%]", "")

                local c
                local d

                toks[index], c =
                    string.gsub(s, "\\%[", "[")

                toks[index], d =
                    string.gsub(toks[index], "\\%]", "]")

                indent = indent + (a - c) - (b - d)

                index = index + 1

            until indent < 1 or index > #toks

            local s = t_concat(
                t_sub(toks, i, index - 1),
                " "
            ):sub(3, -2)

            local prefix =
                tostring(toks[i]):sub(1, 1)

            local p = self.prefixCommands[prefix]

            if not p then
                error("invalid prefix: " .. prefix)

            elseif indent < 1 then
                local r = {
                    p(s)
                }

                t_splice(
                    toks,
                    i,
                    index - 1,
                    r
                )
            else
                error("unclosed bracket")
            end

            index = index - 1

        -- Function block:
        --
        -- { ... }
        --
        elseif type(toks[index]) == "string"
            and toks[index]:sub(1, 1) == "{"
        then
            local indent = 0
            local i = index

            repeat
                local s = toks[index]

                local _, open =
                    string.gsub(s, "{", "")

                local _, close =
                    string.gsub(s, "}", "")

                local escOpen
                local escClose

                toks[index], escOpen =
                    string.gsub(s, "\\{", "{")

                toks[index], escClose =
                    string.gsub(
                        toks[index],
                        "\\}",
                        "}"
                    )

                indent =
                    indent
                    + (open - escOpen)
                    - (close - escClose)

                index = index + 1

            until indent < 1 or index > #toks

            if indent >= 1 then
                error("unclosed brace")
            end

            local contents = t_concat(
                t_sub(toks, i, index - 1),
                " "
            ):sub(2, -2)

            local fn = function(...)
                return self:runString(contents)
            end

            t_splice(
                toks,
                i,
                index - 1,
                { fn }
            )

            index = index - 2
        end

        index = index + 1
    end

    return toks
end


-- ============================================================================
-- Command execution
-- ============================================================================

function console:runCommand(toks)
    if toks[1] == nil then
        return
    end

    local p = 1

    local function f(v)
        local c = toks[p]

        -- No more path components:
        -- open the directory.
        if not c then
            self:changeDir(v)
            return
        end

        local t = v[c]

        -- Assignment
        if toks[p + 1] == "=" then
            if v == self.globalDir then
                error("cannot modify globalDir")
            end

            v[c] = toks[p + 2]

            return t

        -- Command separator
        elseif toks[p] == ";" then
            local first =
                t_sub(toks, 1, p - 1)

            local after =
                t_sub(toks, p + 1, #toks)

            self:runCommand(first)

            return self:runCommand(after)
        end

        -- Directory traversal
        if type(t) == "table" then
            p = p + 1

            return f(t)

        -- Function call
        elseif type(t) == "function" then
            local args =
                t_sub(toks, p + 1)

            local deferred

            for i, value in ipairs(args) do
                if value == ";" then
                    local torun =
                        t_sub(args, i + 1, #args)

                    deferred = function()
                        return self:runCommand(torun)
                    end

                    args =
                        t_sub(args, 1, i - 1)

                    break
                end
            end

            local r = {
                t(unpack(args))
            }

            if deferred then
                return deferred()
            end

            return unpack(r)

        else
            -- Simple value lookup
            return t
        end
    end

    -- Global directory
    if toks[1] == "_" then
        p = 2

        return f(self.globalDir)

    -- Global variables
    elseif toks[1] == "$" then
        p = 2

        return f(self.gvars)

    -- Explicit table
    elseif type(toks[1]) == "table" then
        p = 2

        return f(toks[1])

    -- Direct function
    elseif type(toks[1]) == "function" then
        return toks[1](
            unpack(t_sub(toks, 2))
        )

    -- Current directory
    else
        return f(self.currentDir)
    end
end


-- ============================================================================
-- Running commands
-- ============================================================================

function console:runString(inp)
    local toks = console.tokenize(inp)

    local eval = self:evalTokens(toks)

    local results = {
        self:runCommand(eval)
    }

    return unpack(results)
end


function console:runOnce()
    self.io:write(self.username .. " ")

    local inp = self.io:read()

    local toks =
        console.tokenize(inp)

    local eval =
        self:evalTokens(toks)

    local results = {
        self:runCommand(eval)
    }

    for _, v in ipairs(results) do
        self.io:writeln(tostring(v))
    end

    return unpack(results)
end


function console:run()
    self.running = true

    while self.running do
        self:runOnce()
    end

    return unpack(self.RESULT)
end


function console:runSafe()
    self.running = true

    while self.running do
        local success, err = xpcall(
            function()
                return self:runOnce()
            end,
            removeStackTrace
        )

        if not success then
            self.io:writeln(
                "Error: " .. tostring(err)
            )
        end
    end

    return unpack(self.RESULT)
end


-- ============================================================================
-- Constructor
-- ============================================================================

function console.new(io)
    local me =
        setmetatable({}, console)

    me.RESULT = {}

    me.io = io

    me.startDir = {}

    me.globalDir = {
        dstart = me.startDir
    }

    me.currentDir = me.startDir

    me.dirStack = {
        me.currentDir
    }

    me.gvars = {}

    -- ========================================================================
    -- Prefix commands
    -- ========================================================================

    me.prefixCommands = {

        -- ![command]
        --
        -- Do not evaluate.
        ["!"] = function(s)
            return unpack(
                console.tokenize(s)
            )
        end,

        -- -[command]
        --
        -- Return as a string, do not evaluate.
        ["-"] = function(s)
            return s
        end,

        -- '[command]
        --
        -- Evaluate, then concatenate into a string.
        ["'"] = function(s)
            return t_concat(
                me:evalTokens(
                    console.tokenize(s)
                ),
                " "
            )
        end,

        -- %[command]
        --
        -- Run another Moonav command.
        ["%"] = function(s)
            return me:runString(s)
        end,

        -- $[path]
        --
        -- Look up a global variable.
        ["$"] = function(s)
            local t =
                me:evalTokens(
                    console.tokenize(s)
                )

            local v = me.gvars

            for _, w in ipairs(t) do
                v = v[w]
            end

            return v
        end,

        -- t[...]
        --
        -- Make a table.
        ["t"] = function(s)
            return me:evalTokens(
                console.tokenize(s)
            )
        end,

        -- p[...]
        --
        -- Protected evaluation.
        ["p"] = function(s)
            return pcall(function()
                return me:evalTokens(
                    console.tokenize(s)
                )
            end)
        end,

        -- e[...]
        --
        -- Reserved for future use.
        ["e"] = function(s)
            local toks =
                me:evalTokens(
                    console.tokenize(s)
                )

            error("not yet implemented")
        end,

        -- b[...]
        --
        -- Boolean
        ["b"] = function (s)
            local trues = t_true{
                "true",
                "yes",
                "1",
                "on"
            }
            local falses = t_true{
                "false",
                "no",
                "0",
                "off"
            }

            s = string.lower(s)

            return trues[s] or (falses[s] and false)

        end,

        -- n[...]
        --
        -- Number

        ["n"] = tonumber,

        -- v[...]
        --
        -- Value lookup.
        ["v"] = function(s)
            local toks =
                me:evalTokens(
                    console.tokenize(s)
                )

            if toks[1] == nil then
                return
            end

            local p = 1

            local function f(v)
                local c = toks[p]

                if not c then
                    return v
                end

                local t = v[c]

                if toks[p + 1] == "=" then
                    if v == me.globalDir then
                        error(
                            "cannot modify globalDir"
                        )
                    end

                    v[c] = toks[p + 2]

                    return t
                end

                if type(t) == "table" then
                    p = p + 1

                    return f(t)
                else
                    return t
                end
            end

            if toks[1] == "_" then
                p = 2

                return f(me.globalDir)

            elseif toks[1] == "$" then
                p = 2

                return f(me.gvars)

            elseif type(toks[1]) == "table" then
                p = 2

                return f(toks[1])

            elseif type(toks[1]) == "function" then
                return toks[1](
                    unpack(t_sub(toks, 2))
                )

            else
                return f(me.currentDir)
            end
        end
    }


    -- ========================================================================
    -- User
    -- ========================================================================

    me.username = "User>"


    -- ========================================================================
    -- Built-in commands
    -- ========================================================================

    me.globalDir["do"] = function(f, u, c)
        local r = {}

        if u == "until" then
            repeat
                r = {
                    f()
                }
            until c()
        else
            r = {
                f()
            }
        end

        return unpack(r)
    end


    me.globalDir["if"] =
        function(c, a, e, b)
            if c() then
                return a()

            elseif e == "else" then
                return b()
            end
        end


    me.globalDir["while"] =
        function(c, body)
            local r = {}

            while c() do
                r = {
                    body()
                }
            end

            return unpack(r)
        end


    me.globalDir.ls = function(t)
        local r = {}

        for i, v in pairs(t or me.currentDir) do
            table.insert(
                r,
                tostring(i) .. "\t" .. type(v)
            )
        end

        return unpack(r)
    end


    me.globalDir.echo = function(...)
        for _, s in ipairs({...}) do
            me.io:writeln(
                tostring(s)
            )
        end
    end


    me.globalDir.writeln =
        function(str)
            return me.io:writeln(str)
        end


    me.globalDir.write =
        function(str)
            return me.io:write(
                tostring(str)
            )
        end


    me.globalDir.read = function()
        return me.io:read()
    end


    me.globalDir.dback =
        function(i)
            local t =
                table.remove(me.dirStack)

            if type(t) == "table" then
                me.currentDir = t

                me.io:writeln("went back")
            else
                me.io:writeln(
                    "can't go back any further"
                )

                return
            end

            local n = tonumber(i)

            if n and n > 1 then
                me.globalDir.dback(i - 1)
            end
        end


    me.globalDir.open =
        function(t)
            if type(t) == "table" then
                me:changeDir(t)
            else
                error("not a table")
            end
        end


    me.globalDir.dcurrent =
        function()
            return me.currentDir
        end


    me.globalDir.quit =
        function(...)
            me.RESULT = {
                ...
            }

            me.running = false

            return ...
        end


    -- ========================================================================
    -- Manual directory
    -- ========================================================================

    local man = {
        ["intro"] = [[
welcome to moonav, a simple scripting language by BiN.

it works like a shell on top of luau, so everything is one of these types:

- number
- string
- function
- table (AKA directory)
- boolean
- nil
- plus some niche types

every command can be one of four types:

- a function call (eg. _ ls)
- opening a directory (eg. _)
- reading a value (eg. _ man intro)
- assigning a value (eg. $ x = hello)

to see a list of all manuals, use this command:

_ ls v[_ man]

to read one of those manuals, use:

_ man <name>

recommended: run this command:

_ man syntax
]],

        ["syntax"] = [[
everything you do is relative to the current directory you are in.

there are two directories that are available from anywhere:

- globalDir, accessed using underscore (_), contains essential things.
- vars, accessed using the dollar sign ($), is empty by default.

there are two main concepts of moonav:

paths and prefixes

by default, everything in your command is a string, unless prefixes are used.

prefixes cause special evaluation.

by default, you are navigating the currentDir,
unless you use "_" or "$" at the start of your command.

the first word in your command is a key to a value in your working directory.

if that value is followed by an equals sign,
then that value will be assigned to something else.

examples:

x = 42
$ my_var = hello

if that value is entered by its own,
what will happen depends on its type.

for tables:
you will open that table as your working directory.

for functions:
you will call that function with no arguments.

for anything else:
that value will simply be returned from your command.

if more words follow after your value:

for functions:
the function will be called with the following words as arguments.

for tables:
the following words will be used as keys into that table.

that way you can traverse paths like this:

root dir sub_dir sub_sub_dir func

which is roughly equivalent to:

root.dir.sub_dir.sub_sub_dir.func()
]],

        ["prefixes"] = [[
prefixes change how Moonav interprets text.

![]  = tokenize without evaluation
-[]  = return raw text
'[]  = evaluate and concatenate as text
%[]  = execute as a Moonav command
$[]  = global variable lookup
t[]  = create a table
p[]  = protected evaluation
v[]  = value lookup
b[]  = convert to bool
n[]  = convert to number
]]
    }


    -- The original implementation used a __newindex
    -- metamethod which spawned a Roblox task.
    --
    -- LuaJIT has no task.spawn, so this version performs
    -- the confirmation synchronously.
    --
    -- We put the metatable on the manual table separately.
    me.globalDir["man"] =
        setmetatable(man, {
            __newindex = function(self, k, v)
                while true do
                    me.io:writeln(
                        'are you sure you want to edit the "man" directory? (y/n)'
                    )

                    local inp =
                        string.lower(
                            tostring(me.io:read())
                        )

                    if inp == "y" then
                        rawset(self, k, v)
                        break

                    elseif inp == "n" then
                        me.io:writeln(
                            "action aborted"
                        )

                        break
                    end
                end
            end
        })


    return me
end


return console
