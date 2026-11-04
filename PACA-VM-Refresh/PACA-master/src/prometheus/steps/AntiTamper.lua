 --  PACA V14.7 Anti-Tamper

local Step = require("prometheus.step")
local Parser = require("prometheus.parser")
local Enums = require("prometheus.enums")
local logger = require("logger")

local AntiTamper = Step:extend()
AntiTamper.Description = "Legacy environment fingerprint checks. Not included in supported presets; may reject valid runtimes."
AntiTamper.Name = "PACA Anti Tamper"
AntiTamper.SettingsDescriptor = {}

local PACA_CODE = [==[
-- PACA V14.7 Anti-Tamper | 
		
do
    local function detected(reason)
        error("PACA Anti-Tamper check failed: " .. tostring(reason), 0)
    end

    local function check(value, reason)
        if not value then
            detected(reason)
        end
    end

    local function normalizeError(value)
        if type(value) ~= "string" then
            return value
        end

        return (string.gsub(value, " to '[^']+'", ""))
    end

    local function checkError(ok, actual, expected, reason)
        check(ok == false, reason .. ":status")
        check(
            normalizeError(actual) == normalizeError(expected),
            reason .. ":error"
        )
    end

    local function checkErrorSuffix(
        ok, actual, expected, reason
    )
        check(ok == false, reason .. ":status")
        local actualText = normalizeError(actual)
        local expectedText = normalizeError(expected)
        check(type(actualText) == "string" and
            string.sub(actualText, -#expectedText) ==
                expectedText, reason .. ":error")
    end

    local function runChecks()
        local refs = {
            assert = assert,
            error = error,
            getmetatable = getmetatable,
            next = next,
            pairs = pairs,
            pcall = pcall,
            rawequal = rawequal,
            rawget = rawget,
            rawset = rawset,
            select = select,
            setmetatable = setmetatable,
            tonumber = tonumber,
            tostring = tostring,
            type = type,
            xpcall = xpcall,
            stringByte = string.byte,
            stringChar = string.char,
            stringSub = string.sub,
            tableInsert = table.insert,
            tableRemove = table.remove,
            mathFloor = math.floor,
            coroutineResume = coroutine.resume,
            debugInfo = debug.info,
            taskSpawn = task.spawn,
            loadstring = loadstring,
            instanceNew = Instance.new,
            typeof = typeof,
            buffer = buffer,
            b1 = buffer.create,
            b2 = buffer.fromstring,
            b3 = buffer.tostring,
            b4 = buffer.len,
            b5 = buffer.readi8,
            b6 = buffer.readu8,
            b7 = buffer.readi16,
            b8 = buffer.readu16,
            b9 = buffer.readi32,
            b10 = buffer.readu32,
            b11 = buffer.readf32,
            b12 = buffer.readf64,
            b13 = buffer.readstring,
            b14 = buffer.writei8,
            b15 = buffer.writeu8,
            b16 = buffer.writei16,
            b17 = buffer.writeu16,
            b18 = buffer.writei32,
            b19 = buffer.writeu32,
            b20 = buffer.writef32,
            b21 = buffer.writef64,
            b22 = buffer.writestring,
            b23 = buffer.copy,
            b24 = buffer.fill,
            b25 = buffer.readbits,
            b26 = buffer.writebits,
        }

        if type(getfenv) == "function" then
            local function v1()
                return v
            end
            local ok, env = pcall(getfenv, v1)
            check(ok and type(env) == "table",
                1)
            if type(setfenv) == "function" then
                local v2 = {}
                local t15 = setmetatable({ v = v2 }, {
                    __index = env,
                })
                local ok2, v21 = pcall(
                    setfenv, v1, t15
                )
                check(ok2 and v21 == v1,
                    2)
                check(v1() == v2,
                    3)
                check(pcall(
                    setfenv, v1, env
                ), 4)
            end
        end

        local s1 = "test"
        local ok1, s2 = pcall(function()
            error(s1, 0)
        end)
        check(not ok1 and type(s2) == "string" and
            string.find(s2, s1, 1, true) ~= nil,
            5)
        local handled, s4 = xpcall(function()
            error(s1, 0)
        end, function(message)
            return "handled:" .. tostring(message)
        end)
        check(not handled and type(s4) == "string" and
            string.find(s4, "handled:", 1, true) == 1 and
            string.find(s4, s1, 1, true) ~= nil,
            6)

        local function f1(...)
            return select("#", ...), ...
        end
        local count, first, second, third = f1("head", nil, "tail")
        check(count == 3 and first == "head" and second == nil and
            third == "tail", 7)
        local function f2()
            return 17, nil, 29
        end
        local returnCount = select("#", f2())
        local returnFirst, returnSecond, returnThird = f2()
        check(returnCount == 3 and returnFirst == 17 and
            returnSecond == nil and returnThird == 29,
            8)

        local closures = {}
        for index = 1, 3 do
            local captured = index
            closures[index] = function(increment)
                captured = captured + increment
                return captured
            end
        end
        check(closures[1](4) == 5 and closures[1](2) == 7 and
            closures[2](3) == 5 and closures[3](1) == 4,
            9)

        local writes = {}
        local metatable = {
            __index = function(_, key)
                return "index:" .. tostring(key)
            end,
            __newindex = function(_, key, value)
                writes[key] = value
            end,
            __add = function(left, right)
                return rawget(left, "value") + rawget(right, "value")
            end,
            __tostring = function()
                return "object"
            end,
        }
        local left = setmetatable({ value = 13 }, metatable)
        local right = setmetatable({ value = 7 }, metatable)
        check(left.missing == "index:missing",
            10)
        left.recorded = 41
        check(writes.recorded == 41,
            11)
        check(left + right == 20,
            12)
        check(tostring(left) == "object" and
            getmetatable(left) == metatable,
            13)
        rawset(left, "raw", 53)
        check(rawget(left, "raw") == 53 and
            rawequal(left, left) and not rawequal(left, right),
            14)

        local values = { 4, 1, 3 }
        table.insert(values, 2, 2)
        check(table.concat(values, ",") == "4,2,1,3",
            15)
        check(table.remove(values, 1) == 4,
            16)
        table.sort(values)
        check(table.concat(values, ",") == "1,2,3",
            17)
        local pairCount = 0
        for key, value in pairs({ alpha = 1, beta = 2 }) do
            check((key == "alpha" and value == 1) or
                (key == "beta" and value == 2),
                18)
            pairCount = pairCount + 1
        end
        check(pairCount == 2,
            19)
        local arrayCount = 0
        for index, value in ipairs({ 3, 5, 7 }) do
            check(value == index * 2 + 1,
                20)
            arrayCount = arrayCount + 1
        end
        check(arrayCount == 3,
            21)

        local binary = "A\0z"
        check(string.byte(binary, 1) == 65 and
            string.byte(binary, 2) == 0 and string.byte(binary, 3) == 122,
            22)
        check(string.char(65, 0, 122) == binary,
            23)
        check(string.sub("abcdef", 2, -2) == "bcde",
            24)
        check(string.reverse("abc\0") == "\0cba",
            25)
        check(string.rep("xy", 3) == "xyxyxy" and
            #"a\0b" == 3 and string.format("%02x:%s", 15, "ok") == "0f:ok",
            26)

        check(tonumber("ff", 16) == 255 and
            math.floor(-1.25) == -2 and math.abs(-17) == 17 and
            math.min(9, 3, 7) == 3 and math.max(9, 3, 7) == 9,
            27)
        local nan = 0 / 0
        check(math.huge > 1e308 and nan ~= nan and
            (-17 % 5) == 3, 28)

        check(type(bit32) == "table",
            29)
        check(bit32.bxor(0x55AA55AA, 0x0F0F0F0F) == 0x5AA55AA5 and
            bit32.band(0x12345678, 0x00FF00FF) == 0x00340078 and
            bit32.bor(0x12003478, 0x00345600) == 0x12347678 and
            bit32.lrotate(0x12345678, 8) == 0x34567812 and
            bit32.rshift(0x80000000, 31) == 1,
            30)

        local t16 = {
            { "create", refs.b1 }, { "fromstring", refs.b2 },
            { "tostring", refs.b3 }, { "len", refs.b4 },
            { "readi8", refs.b5 }, { "readu8", refs.b6 },
            { "readi16", refs.b7 }, { "readu16", refs.b8 },
            { "readi32", refs.b9 }, { "readu32", refs.b10 },
            { "readf32", refs.b11 }, { "readf64", refs.b12 },
            { "readstring", refs.b13 }, { "writei8", refs.b14 },
            { "writeu8", refs.b15 }, { "writei16", refs.b16 },
            { "writeu16", refs.b17 }, { "writei32", refs.b18 },
            { "writeu32", refs.b19 }, { "writef32", refs.b20 },
            { "writef64", refs.b21 }, { "writestring", refs.b22 },
            { "copy", refs.b23 }, { "fill", refs.b24 },
            { "readbits", refs.b25 }, { "writebits", refs.b26 },
        }
        for i, t in ipairs(t16) do
            local fn = t[2]
            local source, line, name, parameters, variadic, v23 =
                debug.info(fn, "slnaf")
            check(type(fn) == "function" and source == "[C]" and
                line == -1 and name == t[1] and parameters == 0 and
                variadic == true and v23 == fn and
                iscclosure(fn) == true and islclosure(fn) == false,
                49 + i)
        end

        local s5 = string.char(0, 1, 127, 128, 255, 65, 0, 90)
        local v24 = refs.b2(s5)
        check(type(v24) == "buffer" and typeof(v24) == "buffer" and
            refs.b4(v24) == #s5 and refs.b3(v24) == s5, 76)

        local v25 = refs.b1(48)
        check(type(v25) == "buffer" and refs.b4(v25) == 48 and
            refs.b3(v25) == string.rep("\0", 48), 77)
        refs.b14(v25, 0, -128)
        refs.b15(v25, 1, 255)
        refs.b16(v25, 2, -12345)
        refs.b17(v25, 4, 0xFEDC)
        refs.b18(v25, 6, -123456789)
        refs.b19(v25, 10, 0xDEADBEEF)
        refs.b20(v25, 14, 1.25)
        refs.b21(v25, 18, -1234.5)
        refs.b22(v25, 26, "A\0z")
        check(refs.b5(v25, 0) == -128 and refs.b6(v25, 1) == 255 and
            refs.b7(v25, 2) == -12345 and refs.b8(v25, 4) == 0xFEDC and
            refs.b9(v25, 6) == -123456789 and
            refs.b10(v25, 10) == 0xDEADBEEF and
            refs.b11(v25, 14) == 1.25 and refs.b12(v25, 18) == -1234.5 and
            refs.b13(v25, 26, 3) == "A\0z", 78)

        local v26 = refs.b1(6)
        refs.b17(v26, 0, 0x1234)
        refs.b19(v26, 2, 0x89ABCDEF)
        check(refs.b3(v26) == string.char(0x34, 0x12, 0xEF, 0xCD, 0xAB, 0x89),
            79)

        local v27 = refs.b1(8)
        refs.b24(v27, 0, 0x2E)
        refs.b23(v27, 1, refs.b2("abcdef"), 2, 3)
        check(refs.b3(v27) == ".cde....", 80)

        local v28 = refs.b1(4)
        refs.b26(v28, 3, 5, 0x15)
        check(refs.b25(v28, 3, 5) == 0x15, 81)

        local ok5, err5 = pcall(refs.b10, v25, 45)
        local ok6, err6 = pcall(refs.b15, v25, -1, 0)
        local ok7, err7 = pcall(refs.b13, v25, 47, 2)
        check(not ok5 and type(err5) == "string" and
            not ok6 and type(err6) == "string" and
            not ok7 and type(err7) == "string", 82)

        local thread = coroutine.create(function(value)
            local resumed = coroutine.yield(value + 1)
            return resumed + 2
        end)
        check(coroutine.status(thread) == "suspended",
            31)
        local resumed, yielded = coroutine.resume(thread, 9)
        check(resumed and yielded == 10 and
            coroutine.status(thread) == "suspended",
            32)
        local completed, result = coroutine.resume(thread, 11)
        check(completed and result == 13 and
            coroutine.status(thread) == "dead",
            33)

        local compiledOk, compiled = pcall(
            loadstring, "return 19, nil, 23", "PACA"
        )
        check(compiledOk and type(compiled) == "function",
            34)
        local compiledFirst, compiledSecond, compiledThird = compiled()
        check(compiledFirst == 19 and compiledSecond == nil and
            compiledThird == 23,
            35)
        local ok3, v8, err3 = pcall(
            loadstring, "local =", "PACA2"
        )
        check(ok3 and v8 == nil and
            type(err3) == "string",
            36)

        local trace = debug.traceback("trace")
        check(type(trace) == "string" and
            string.find(trace, "trace", 1, true) ~= nil,
            37)
        local function f3()
            return true
        end
        check(debug.info(f3, "f") == f3 and
            type(debug.info(f3, "s")) == "string",
            38)

        local env2 = getfenv(0)
        local f4 = function(value)
            return value
        end
        local f5 = rawget(env2, "islclosure")
        local f6 = rawget(env2, "iscclosure")
        local f7 = rawget(env2, "newcclosure")
        local f8 = rawget(env2, "clonefunction")
        local f9 = rawget(env2, "isfunctionhooked")
        local f10 = rawget(env2, "checkcaller")
        if type(f5) == "function" then
            check(f5(f4) == true,
                39)
        end
        if type(f6) == "function" then
            check(f6(f4) == false,
                40)
        end
        if type(f7) == "function" then
            local wrapped = f7(f4)
            check(type(wrapped) == "function" and wrapped(31) == 31,
                41)
            if type(f6) == "function" then
                check(f6(wrapped) == true,
                    42)
            end
        end
        if type(f8) == "function" then
            local cloned = f8(pcall)
            local cloneOk, cloneValue = cloned(function()
                return 37
            end)
            check(type(cloned) == "function" and cloneOk and
                cloneValue == 37,
                43)
        end
        if type(f9) == "function" then
            for _, fn in ipairs({
                refs.assert, refs.error, refs.pcall,
                refs.stringByte, refs.tableInsert,
            }) do
                check(f9(fn) == false,
                    44)
            end
        end
        if type(f10) == "function" then
            check(type(f10()) == "boolean",
                45)
        end

        check(type(game) == "userdata" and
            typeof(game) == "Instance" and game.ClassName == "DataModel",
            46)
        local service = game:GetService("RunService")
        check(typeof(service) == "Instance" and
            service.ClassName == "RunService",
            47)

        check(assert == refs.assert and error == refs.error and
            getmetatable == refs.getmetatable and next == refs.next and
            pairs == refs.pairs and pcall == refs.pcall and
            rawequal == refs.rawequal and rawget == refs.rawget and
            rawset == refs.rawset and select == refs.select and
            setmetatable == refs.setmetatable and tonumber == refs.tonumber and
            tostring == refs.tostring and type == refs.type and
            xpcall == refs.xpcall and string.byte == refs.stringByte and
            string.char == refs.stringChar and string.sub == refs.stringSub and
            table.insert == refs.tableInsert and table.remove == refs.tableRemove and
            math.floor == refs.mathFloor and
            coroutine.resume == refs.coroutineResume and
            debug.info == refs.debugInfo and task.spawn == refs.taskSpawn and
            loadstring == refs.loadstring and Instance.new == refs.instanceNew and
            typeof == refs.typeof and buffer == refs.buffer and
            buffer.create == refs.b1 and buffer.fromstring == refs.b2 and
            buffer.tostring == refs.b3 and buffer.len == refs.b4 and
            buffer.readi8 == refs.b5 and buffer.readu8 == refs.b6 and
            buffer.readi16 == refs.b7 and buffer.readu16 == refs.b8 and
            buffer.readi32 == refs.b9 and buffer.readu32 == refs.b10 and
            buffer.readf32 == refs.b11 and buffer.readf64 == refs.b12 and
            buffer.readstring == refs.b13 and buffer.writei8 == refs.b14 and
            buffer.writeu8 == refs.b15 and buffer.writei16 == refs.b16 and
            buffer.writeu16 == refs.b17 and buffer.writei32 == refs.b18 and
            buffer.writeu32 == refs.b19 and buffer.writef32 == refs.b20 and
            buffer.writef64 == refs.b21 and buffer.writestring == refs.b22 and
            buffer.copy == refs.b23 and buffer.fill == refs.b24 and
            buffer.readbits == refs.b25 and buffer.writebits == refs.b26,
            48)
    end

    local t1 = {
        { name = "utf8", keys = { "offset", "codepoint", "nfdnormalize", "char", "codes", "len", "graphemes", "nfcnormalize", "charpattern" } },
        { name = "math", keys = { "log", "e", "ldexp", "deg", "cosh", "round", "random", "frexp", "tanh", "floor", "max", "sqrt", "modf", "huge", "sqrt2", "pow", "isnan", "acos", "phi", "tau", "exp", "pi", "isfinite", "tan", "cos", "isinf", "atan", "map", "sign", "ceil", "clamp", "noise", "abs", "nan", "sinh", "asin", "min", "randomseed", "fmod", "rad", "atan2", "log10", "sin", "lerp" } },
        { name = "debug", keys = { "dumpheap", "getconstants", "getproto", "setmemorycategory", "profilebegin", "loadmodule", "traceback", "getstack", "getregistry", "setmetatable", "getupvalues", "getupvalue", "getmemorycategory", "resetmemorycategory", "setupvalue", "validlevel", "isvalidlevel", "dumpcodesize", "setstack", "getconstant", "profileend", "info", "getinfo", "getprotos", "setconstant", "getmetatable", "dumprefs" } },
        { name = "task", keys = { "defer", "cancel", "wait", "desynchronize", "synchronize", "delay", "spawn" } },
        { name = "script", keys = { "script" } },
    }
    local t2 = {
        utf8 = utf8,
        math = math,
        debug = debug,
        task = task,
        script = { script = script },
    }
    local t3 = {
        nfdnormalize = true, graphemes = true,
        nfcnormalize = true, isnan = true,
        isfinite = true, isinf = true,
        setmemorycategory = true, profilebegin = true,
        getmemorycategory = true,
        resetmemorycategory = true, profileend = true,
        desynchronize = true, synchronize = true,
    }
    for _, scan in ipairs(t1) do
        local source = t2[scan.name]
        local previous = nil
        for i, keyName in ipairs(scan.keys) do
            local key, value = next(source, previous)
            check(key ~= nil,
                "library-status:" .. scan.name .. ":" .. i)
            if t3[keyName] then
                check(key == keyName,
                    "library-key:" .. keyName)
            end

            check(value ~= nil,
                "library-value:" .. scan.name .. ":" .. i)
            previous = key
        end
    end

    local readonly = table.freeze({})
    for i = 1, 5 do
        local ok, err = pcall(function()
            readonly[i] = i
        end)
        checkErrorSuffix(ok, err,
            "attempt to modify a readonly table",
            "readonly:" .. i)
    end
    local nilCallable = nil
    local nilOk, nilDiagnostic = pcall(function(...)
        return nilCallable(...)
    end)
    checkErrorSuffix(nilOk, nilDiagnostic,
        "attempt to call a nil value", "nil-call")

    local dataModel = game
    local workspaceObject = workspace
    local httpService = game:GetService("HttpService")
    local runService = game:GetService("RunService")
    local folderParent = Instance.new("Folder")
    local folderChild = Instance.new("Folder", folderParent)
    local objects = {
        { value = dataModel, class = "DataModel" },
        { value = workspaceObject, class = "Workspace" },
        { value = folderParent, class = "Folder" },
        { value = folderChild, class = "Folder" },
        { value = httpService, class = "HttpService" },
        { value = runService, class = "RunService" },
    }
    local signals = {}
    local connections = {}
    for i, record in ipairs(objects) do
        local object = record.value
        local firstName = object.Name
        check(type(object) == "userdata",
            "Instance:type:" .. record.class)
        check(typeof(object) == "Instance",
            "Instance:typeof:" .. record.class)
        check(type(firstName) == "string",
            "Instance:Name-type:" .. record.class)
        check(object.Name == firstName,
            "Instance:Name-relation:" .. record.class)
        check(object.ClassName == record.class,
            "Instance:ClassName:" .. record.class)
        check(
            getmetatable(object) == "The metatable is locked",
            "Instance:metatable:" .. record.class
        )
        local attributeChanged = object.AttributeChanged
        local childRemoved = object.ChildRemoved
        check(attributeChanged ~= nil,
            "Instance:AttributeChanged:" .. record.class)
        check(childRemoved ~= nil,
            "Instance:ChildRemoved:" .. record.class)
        signals[#signals + 1] = attributeChanged
        signals[#signals + 1] = childRemoved
        local connection = childRemoved:Connect(function() end)
        check(connection.Connected == true,
            "Connection:Connected:" .. i)
        connections[#connections + 1] = connection
    end

    local enumType = Enum.HumanoidRigType
    local enumItem = enumType.R6
    local rng = Random.new(51018400)

    local t4 = { "getmetatable", "setmetatable", "tonumber", "tostring", "rawset", "rawget", "select", "xpcall", "assert", "error", "pcall", "type", "next", "getfenv", "setfenv", "typeof", "gmatch", "format", "match", "find", "char", "byte", "gsub", "sub", "rep", "unpack", "pack", "concat", "insert", "isyieldable", "running", "create", "status", "yield", "close", "resume", "wrap", "cancel", "spawn", "defer", "delay", "wait", "unpack", "info", "traceback", "loadstring", "new", "new", "new", "new", "new", "new", "Connect", "Connect", "Disconnect", "Connect", "Connect", "Disconnect", "Connect", "Connect", "Disconnect", "Connect", "Connect", "Disconnect", "WaitForChild", "Connect", "Connect", "Disconnect", "Connect", "Connect", "Disconnect", "IsStudio", "IsClient", "IsServer", "IsA", "FromName", "FromValue", "new", "NextUnitVector", "NextInteger", "NextNumber", "Shuffle", "Clone" }
    local t5 = {
        assert = assert, byte = string.byte,
        cancel = task.cancel, char = string.char,
        close = coroutine.close, concat = table.concat,
        create = coroutine.create, defer = task.defer,
        delay = task.delay, error = error,
        find = string.find, format = string.format,
        getfenv = getfenv, getmetatable = getmetatable,
        gmatch = string.gmatch, gsub = string.gsub,
        info = debug.info, insert = table.insert,
        isyieldable = coroutine.isyieldable,
        loadstring = loadstring, match = string.match,
        next = next, pack = string.pack, pcall = pcall,
        rawget = rawget, rawset = rawset,
        rep = string.rep, resume = coroutine.resume,
        running = coroutine.running, select = select,
        setfenv = setfenv, setmetatable = setmetatable,
        spawn = task.spawn, status = coroutine.status,
        sub = string.sub, tonumber = tonumber,
        tostring = tostring, traceback = debug.traceback,
        type = type, typeof = typeof,
        wait = task.wait, wrap = coroutine.wrap,
        xpcall = xpcall, yield = coroutine.yield,
    }
    local t6 = {
        Instance.new, UDim2.new, Path2DControlPoint.new,
        Vector2.new, UDim.new, Rect.new, Random.new,
    }
    local t7 = {}
    local t8 = {}
    for i, name in ipairs(t4) do
        local n = (t7[name] or 0) + 1
        t7[name] = n
        local fn
        if name == "Connect" then
            fn = signals[(n - 1) % #signals + 1].Connect
        elseif name == "Disconnect" then
            fn = connections[n].Disconnect
        elseif name == "FromName" then
            fn = enumType.FromName
        elseif name == "FromValue" then
            fn = enumType.FromValue
        elseif name == "IsA" then
            fn = enumItem.IsA
        elseif name == "IsClient" then
            fn = runService.IsClient
        elseif name == "IsServer" then
            fn = runService.IsServer
        elseif name == "IsStudio" then
            fn = runService.IsStudio
        elseif name == "NextInteger" then
            fn = rng.NextInteger
        elseif name == "NextNumber" then
            fn = rng.NextNumber
        elseif name == "NextUnitVector" then
            fn = rng.NextUnitVector
        elseif name == "Shuffle" then
            fn = rng.Shuffle
        elseif name == "Clone" then
            fn = rng.Clone
        elseif name == "WaitForChild" then
            fn = folderParent.WaitForChild
        elseif name == "new" then
            fn = t6[n]
        elseif name == "unpack" then
            fn = n == 1 and
                string.unpack or table.unpack
        else
            fn = t5[name]
        end
        check(type(fn) == "function",
            "n0:" .. i .. ":" .. name)
        t8[i] = fn
        local source, line, fnName, parameters,
            variadic, v22 = debug.info(fn, "slnaf")
        check(source == "[C]",
            "n1:" .. i)
        check(line == -1,
            "n2:" .. i)
        check(fnName == name,
            "n3:" .. i)
        check(parameters == 0,
            "n4:" .. i)
        check(variadic == true,
            "n5:" .. i)
        check(v22 == fn,
            "n6:" .. i)
        check(iscclosure(fn) == true,
            "n7:" .. i)
        check(islclosure(fn) == false,
            "n8:" .. i)
    end

    local t9 = {
        { name = "getfenv", expected = "invalid argument #1 to 'getfenv' (level must be non-negative)" },
        { name = "setfenv", expected = "missing argument #2 to 'setfenv' (table expected)" },
        { name = "getmetatable", expected = "missing argument #1" },
        { name = "setmetatable", expected = "missing argument #1 to 'setmetatable' (table expected)" },
        { name = "tonumber", expected = "missing argument #1" },
        { name = "tostring", expected = "missing argument #1" },
        { name = "rawset", expected = "missing argument #1 to 'rawset' (table expected)" },
        { name = "rawget", expected = "missing argument #1 to 'rawget' (table expected)" },
        { name = "assert", expected = "missing argument #1" },
        { name = "type", expected = "missing argument #1" },
        { name = "next", expected = "missing argument #1 to 'next' (table expected)" },
        { name = "typeof", expected = "missing argument #1" },
        { name = "gmatch", expected = "missing argument #1 to 'gmatch' (string expected)" },
        { name = "format", expected = "missing argument #1 to 'format' (string expected)" },
        { name = "match", expected = "missing argument #1 to 'match' (string expected)" },
        { name = "find", expected = "missing argument #1 to 'find' (string expected)" },
        { name = "byte", expected = "missing argument #1 to 'byte' (string expected)" },
        { name = "gsub", expected = "missing argument #1 to 'gsub' (string expected)" },
        { name = "gsub", expected = "missing argument #1 to 'gsub' (string expected)" },
        { name = "rep", expected = "missing argument #1 to 'rep' (string expected)" },
        { name = "char", expected = "invalid argument #1 to 'char' (number expected, got nil)" },
        { name = "unpack", expected = "missing argument #1 to 'unpack' (string expected)" },
        { name = "pack", expected = "missing argument #1 to 'pack' (string expected)" },
        { name = "concat", expected = "missing argument #1 to 'concat' (table expected)" },
        { name = "insert", expected = "missing argument #1 to 'insert' (table expected)" },
        { name = "create", expected = "missing argument #1 to 'create' (function expected)" },
        { name = "status", expected = "missing argument #1 to 'status' (thread expected)" },
        { name = "close", expected = "missing argument #1 to 'close' (thread expected)" },
        { name = "resume", expected = "missing argument #1 to 'resume' (thread expected)" },
        { name = "wrap", expected = "missing argument #1 to 'wrap' (function expected)" },
        { name = "cancel", expected = "missing argument #1 to 'cancel' (thread expected)" },
        { name = "spawn", expected = "invalid argument #1 to 'spawn' (function or thread expected)" },
        { name = "defer", expected = "invalid argument #1 to 'defer' (function or thread expected)" },
        { name = "delay", expected = "invalid argument #2 to 'delay' (function or thread expected)" },
        { name = "wait", expected = "invalid argument #1 to 'wait' (number expected, got table)" },
        { name = "unpack", expected = "missing argument #1 to 'unpack' (table expected)" },
        { name = "info", expected = "invalid argument #1 to 'info' (function or level expected)" },
        { name = "loadstring", expected = "missing argument #1 to 'loadstring' (string expected)" },
        { name = "new", expected = "invalid argument #1 to 'new' (string expected, got nil)" },
        { name = "new", expected = "invalid argument #1 to 'new' (UDim2 expected, got nil)", relaxedTypePrefix = true },
        { name = "Disconnect", expected = "invalid argument #1 to 'Disconnect' (RBXScriptConnection expected, got nil)" },
        { name = "Disconnect", expected = "invalid argument #1 to 'Disconnect' (RBXScriptConnection expected, got nil)" },
        { name = "Disconnect", expected = "invalid argument #1 to 'Disconnect' (RBXScriptConnection expected, got nil)" },
        { name = "Disconnect", expected = "invalid argument #1 to 'Disconnect' (RBXScriptConnection expected, got nil)" },
        { name = "WaitForChild", expected = "Expected ':' not '.' calling member function WaitForChild" },
        { name = "Disconnect", expected = "invalid argument #1 to 'Disconnect' (RBXScriptConnection expected, got nil)" },
        { name = "Disconnect", expected = "invalid argument #1 to 'Disconnect' (RBXScriptConnection expected, got nil)" },
        { name = "IsStudio", expected = "Expected ':' not '.' calling member function IsStudio" },
        { name = "IsClient", expected = "Expected ':' not '.' calling member function IsClient" },
        { name = "IsServer", expected = "Expected ':' not '.' calling member function IsServer" },
        { name = "IsA", expected = "missing argument #1 to 'IsA' (EnumItem expected)" },
        { name = "FromName", expected = "missing argument #1 to 'FromName' (Enum expected)" },
        { name = "FromValue", expected = "missing argument #1 to 'FromValue' (Enum expected)" },
        { name = "new", expected = "invalid argument #1 to 'new' (number expected, got table)" },
    }
    local t10 = {}
    local t11 = {
        getfenv = getfenv, setfenv = setfenv,
        getmetatable = getmetatable,
        setmetatable = setmetatable, tonumber = tonumber,
        tostring = tostring, rawset = rawset,
        rawget = rawget, assert = assert, type = type,
        next = next, typeof = typeof,
        gmatch = string.gmatch, format = string.format,
        match = string.match, find = string.find,
        byte = string.byte, gsub = string.gsub,
        rep = string.rep, char = string.char,
        concat = table.concat, insert = table.insert,
        create = coroutine.create,
        status = coroutine.status, close = coroutine.close,
        resume = coroutine.resume, wrap = coroutine.wrap,
        cancel = task.cancel, spawn = task.spawn,
        defer = task.defer, delay = task.delay,
        wait = task.wait, info = debug.info,
        loadstring = loadstring,
    }
    local t12 = {
        Instance.new, Path2DControlPoint.new, Random.new,
    }
    local n2 = 0

    local function f11(callback)
        local function layer4()
            local a, b = callback()
            return a, b
        end
        local function layer3()
            local a, b = layer4()
            return a, b
        end
        local function layer2()
            local a, b = layer3()
            return a, b
        end
        local function layer1()
            local a, b = layer2()
            return a, b
        end
        return layer1()
    end

    local function callInvalid(name, n, fn)
        if name == "getfenv" then
            return fn(-1)
        elseif name == "setfenv" then
            return fn(0)
        elseif name == "char" then
            return fn(nil)
        elseif name == "wait" then
            return fn({})
        elseif name == "new" then
            if n < 3 then
                return fn(nil)
            end
            return fn({})
        elseif name == "Disconnect" then
            return fn(nil)
        end
        return fn()
    end

    for i, entry in ipairs(t9) do
        local n =
            (t10[entry.name] or 0) + 1
        t10[entry.name] = n
        local fn
        if entry.name == "unpack" then
            fn = n == 1 and
                string.unpack or table.unpack
        elseif entry.name == "pack" then
            fn = string.pack
        elseif entry.name == "new" then
            fn = t12[n]
        elseif entry.name == "Disconnect" then
            n2 = n2 + 1
            fn = connections[n2].Disconnect
        elseif entry.name == "WaitForChild" then
            fn = folderParent.WaitForChild
        elseif entry.name == "IsStudio" then
            fn = runService.IsStudio
        elseif entry.name == "IsClient" then
            fn = runService.IsClient
        elseif entry.name == "IsServer" then
            fn = runService.IsServer
        elseif entry.name == "IsA" then
            fn = enumItem.IsA
        elseif entry.name == "FromName" then
            fn = enumType.FromName
        elseif entry.name == "FromValue" then
            fn = enumType.FromValue
        else
            fn = t11[entry.name]
        end
        local t13 = {}
        local ok, err = f11(function()
            return xpcall(function()
                return callInvalid(
                    entry.name, n, fn
                )
            end, function(err2)
                for _, level in ipairs({ 5, 6, 7, 8, 10, 11 }) do
                    t13[level] = debug.info(level, "f")
                end
                return err2
            end)
        end)
        for _, level in ipairs({ 5, 6, 7, 8, 10, 11 }) do
            check(t13[level] ~= nil,
                "stack-level:" .. i .. ":" .. level)
        end
        if entry.relaxedTypePrefix then
            check(ok == false,
                "n9:" .. i .. ":" .. entry.name .. ":status")
            check(type(err) == "string" and
                string.find(err, "UDim2 expected, got nil", 1, true) ~= nil,
                "n9:" .. i .. ":" .. entry.name .. ":error")
        else
            checkErrorSuffix(ok, err, entry.expected,
                "n9:" .. i .. ":" .. entry.name)
        end
    end

    for i, connection in ipairs(connections) do
        check(connection.Connected == true,
            "connection-before-disconnect:" .. i)
        local ok, err = pcall(connection.Disconnect, nil)
        checkError(ok, err,
            "invalid argument #1 to 'Disconnect' " ..
            "(RBXScriptConnection expected, got nil)",
            "Disconnect:nil:" .. i)
        connection:Disconnect()
        check(connection.Connected == false,
            "connection-after-disconnect:" .. i)
    end


    local childrenOk, childrenDiagnostic =
        pcall(dataModel.GetChildren, nil)
    checkError(childrenOk, childrenDiagnostic,
        "Expected ':' not '.' calling member function GetChildren",
        "DataModel:GetChildren-dot")
    for _, method in ipairs({
        runService.IsStudio, runService.IsClient,
        runService.IsServer,
    }) do
        local ok = pcall(method, nil)
        check(ok == false, "RunService:dot-call")
    end
    check(type(runService:IsServer()) == "boolean",
        "RunService:IsServer-result")

    check(#folderParent:GetChildren() == 1,
        "Folder:GetChildren")
    folderChild.Name = "847283502"
    check(
        folderParent:WaitForChild("847283502") == folderChild,
        "f:id"
    )
    local waitOk, waitDiagnostic =
        pcall(folderParent.WaitForChild, nil)
    checkError(waitOk, waitDiagnostic,
        "Expected ':' not '.' calling member function WaitForChild",
        "Folder:WaitForChild-dot")
    folderParent:Destroy()
    folderChild:Destroy()
    local parentOk, parentDiagnostic = pcall(function()
        folderChild.Parent = folderParent
    end)
    check(parentOk == false,
        "Folder:destroyed-parent-status")
    check(string.find(parentDiagnostic,
        "The Parent property of 847283502 is locked",
        1, true) ~= nil, "Folder:destroyed-parent-error")

    check(type(Enum) == "userdata", "Enum:type")
    check(typeof(Enum) == "Enums", "Enum:typeof")
    check(getmetatable(Enum) ==
        "The metatable is locked", "Enum:metatable")
    local byName1 = enumType:FromName("R6")
    local byName2 = enumType:FromName("R6")
    local byValue1 = enumType:FromValue(0)
    local byValue2 = enumType:FromValue(0)
    local byValue3 = enumType:FromValue(0)
    check(byName1 == byName2, "Enum:FromName")
    check(byName1 == byValue1, "e:id")
    check(byValue1 == byValue2 and
        byValue2 == byValue3, "Enum:FromValue")
    check(enumType.R6 == byName1, "Enum:R6")
    check(byName1.Name == "R6", "EnumItem:Name")
    check(byName1.Value == 0, "EnumItem:Value")
    check(byName1.EnumType == enumType,
        "EnumItem:EnumType")
    check(type(byName1) == "userdata" and
        typeof(byName1) == "EnumItem", "EnumItem:classification")
    check(type(enumType) == "userdata" and
        typeof(enumType) == "Enum", "EnumType:classification")
    check(getmetatable(byName1) ==
        "The metatable is locked", "EnumItem:metatable")
    check(getmetatable(enumType) ==
        "The metatable is locked", "EnumType:metatable")

    for _, method in ipairs({
        "NextUnitVector", "NextInteger", "NextNumber",
        "Shuffle", "Clone",
    }) do
        check(type(rng[method]) == "function",
            "Random:method:" .. method)
    end
    local t14 = { original = Random.new(177465824) }
    local v1 = t14["original"]:NextNumber()
    check(v1 == 0.9598971928030796,
        "Random:NextNumber:1")
    local v2 = t14["original"]:NextInteger(189, 1164)
    check(v2 == 889,
        "Random:NextInteger:2")
    local v3 = t14["original"]:NextNumber()
    check(v3 == 0.027539190730015265,
        "Random:NextNumber:3")
    local v4 = t14["original"]:NextNumber()
    check(v4 == 0.3377740061710911,
        "Random:NextNumber:4")
    local v5 = t14["original"]:NextInteger(75, 497)
    check(v5 == 340,
        "Random:NextInteger:5")
    local v6 = t14["original"]:Clone()
    check(v6 ~= nil,
        "Random:Clone:6")
    t14["clone1"] = v6
    local v7 = t14["original"]:NextInteger(979, 1379)
    check(v7 == 1338,
        "Random:NextInteger:7")
    local v8 = t14["clone1"]:NextNumber()
    check(v8 == 0.010722157288309652,
        "Random:NextNumber:8")
    local v9 = t14["original"]:Clone()
    check(v9 ~= nil,
        "Random:Clone:9")
    t14["clone2"] = v9
    local v10 = t14["clone2"]:NextNumber()
    check(v10 == 0.9163096810250362,
        "Random:NextNumber:10")
    local v11 = t14["clone2"]:NextNumber()
    check(v11 == 0.7297156848095374,
        "Random:NextNumber:11")
    local v12 = t14["clone2"]:Clone()
    check(v12 ~= nil,
        "Random:Clone:12")
    t14["clone3"] = v12
    local v13 = t14["clone3"]:NextNumber()
    check(v13 == 0.17877278448733477,
        "Random:NextNumber:13")
    local v14 = t14["clone3"]:NextInteger(35, 888)
    check(v14 == 665,
        "Random:NextInteger:14")
    local v15 = t14["clone2"]:NextNumber()
    check(v15 == 0.17877278448733477,
        "Random:NextNumber:15")
    local v16 = t14["clone2"]:NextInteger(721, 807)
    check(v16 == 785,
        "Random:NextInteger:16")
    local v17 = t14["clone3"]:NextInteger(353, 1335)
    check(v17 == 826,
        "Random:NextInteger:17")

    local function fromHex(hex)
        local value = string.gsub(hex, "..", function(byte)
            return string.char(tonumber(byte, 16))
        end)
        return value
    end
    local function toHex(value)
        local hex = string.gsub(value, ".", function(byte)
            return string.format("%02x", string.byte(byte))
        end)
        return hex
    end
    local nfc = utf8.nfcnormalize(fromHex(
        "e1848fe185a9e186ade18492e185a2e186a9" ..
        "e18486e185a8e18481e185a2e186ba" ..
        "e18492e185a4e186b5"
    ))
    local nfd = utf8.nfdnormalize(fromHex(
        "eabf94ebbdb0eb9ebaeb91b3ebb9a3eb9a89"
    ))
    check(#nfc == 15 and toHex(nfc) ==
        "ecbd9aed95b6ebaa8ceab9bbed96ba", "Unicode:NFC")
    check(#nfd == 51 and toHex(nfd) ==
        "e18481e185afe18488e185aae186bbe18485e185a3e186ad" ..
        "e18483e185afe186aee18488e185a1e186aae18484e185ad" ..
        "e186b0", "Unicode:NFD")

    local function nearlyEqual(actual, expected)
        return math.abs(actual - expected) <= 0.000001
    end
    local function checkUDim2(value, expected, label)
        check(nearlyEqual(value.X.Scale, expected[1]), label .. ":XS")
        check(nearlyEqual(value.X.Offset, expected[2]), label .. ":XO")
        check(nearlyEqual(value.Y.Scale, expected[3]), label .. ":YS")
        check(nearlyEqual(value.Y.Offset, expected[4]), label .. ":YO")
    end
    local function checkVector2(value, expected, label)
        check(nearlyEqual(value.X, expected[1]), label .. ":X")
        check(nearlyEqual(value.Y, expected[2]), label .. ":Y")
    end
    local screenGui = Instance.new("ScreenGui")
    local frame = Instance.new("Frame")
    frame.Parent = screenGui
    frame.Position = UDim2.new(0, 0, 0, 0)
    frame.Size = UDim2.new(0, 130, 0, 231)
    local path = Instance.new("Path2D")
    path.Parent = frame
    path:SetControlPoints({
        Path2DControlPoint.new(UDim2.new(0, 3, 0, 8),
            UDim2.new(0, 0, 0, 0), UDim2.new(0, 0, 0, 0)),
        Path2DControlPoint.new(UDim2.new(0.5, 0, 0.125, -9),
            UDim2.new(0, 2, 0.0625, 7),
            UDim2.new(0, 6, 0, -5)),
        Path2DControlPoint.new(UDim2.new(0.3125, -6, 0, -4),
            UDim2.new(-0.125, -4, 0, 6),
            UDim2.new(0, 0, 0, 0)),
    })
    check(nearlyEqual(path:GetLength(), 119.61338806152344),
        "Path2D:length")
    checkUDim2(path:GetPositionOnCurve(0.857142866),
        { 0.2526211142539978, 0, 0.01074677798897028, 0 },
        "Path2D:p1")
    checkUDim2(path:GetPositionOnCurve(0.600000024),
        { 0.47846919298171997, 0, 0.06947184354066849, 0 },
        "Path2D:p2")
    checkUDim2(path:GetPositionOnCurve(0.3125),
        { 0.44014424085617065, 0, 0.12231127917766571, 0 },
        "Path2D:p3")
    checkVector2(path:GetTangentOnCurve(0.888888896),
        { -21.083309173583984, -24.98147964477539 },
        "Path2D:t1")
    checkVector2(path:GetTangentOnCurve(0.800000012),
        { -56.790000915527344, -27.420000076293945 },
        "Path2D:t2")
    checkVector2(path:GetTangentOnCurve(0.13333334),
        { 92.80000305175781, 37.42499923706055 },
        "Path2D:t3")
    checkVector2(path:GetTangentOnCurve(0.571428597),
        { -27.137767791748047, -20.846940994262695 },
        "Path2D:t4")
    checkUDim2(path:GetPositionOnCurveArcLength(0.5),
        { 0.4516785144805908, 0, 0.12175357341766357, 0 },
        "Path2D:ap1")
    checkUDim2(path:GetPositionOnCurveArcLength(0.200000003),
        { 0.1884470134973526, 0, 0.0800270289182663, 0 },
        "Path2D:ap2")
    checkVector2(path:GetTangentOnCurveArcLength(0.5),
        { 40.919342041015625, -5.61236572265625 },
        "Path2D:at1")
    checkVector2(path:GetTangentOnCurveArcLength(0.800000012),
        { -65.67493438720703, -27.52351188659668 },
        "Path2D:at2")
    screenGui:Destroy()

    local co0 = coroutine.create(function()
        for i = 1, 106 do
            coroutine.yield(true, i)
        end
    end)
    for i = 1, 106 do
        local ok, status, value = coroutine.resume(co0)
        check(ok and status == true and value == i,
            "yield:iterator:" .. i)
    end
    check(coroutine.resume(co0) == true,
        "yield:iterator-return")
    coroutine.close(co0)
    for i = 1, 3 do
        local co2 = coroutine.create(function()
            coroutine.yield(i)
        end)
        local ok, value = coroutine.resume(co2)
        check(ok and value == i,
            "yield:w:" .. i)
        coroutine.close(co2)
    end
    local co1 = coroutine.running()
    check(type(co1) == "thread",
        "coroutine:running")
    local co3 = task.spawn(function()
        coroutine.yield()
    end)
    check(type(co3) == "thread",
        "task:spawn-result")
    coroutine.close(co3)
    local co4 = task.delay(86400, function() end)
    check(type(co4) == "thread",
        "task:delay-result")
    task.cancel(co4)
    local v19 = task.spawn(function() end)
    check(type(v19) == "thread",
        "task:final-spawn-result")

    local s3 =
        "return setfenv(function(...) return UGiZrsFzK(...) end, " ..
        "setmetatable({ UGiZrsFzK = ... }, { __index = getfenv((...)) }))"
    local ok4, v20 =
        pcall(loadstring, s3, "PACA", nil)
    check(ok4, "compile:status")
    check(type(v20) == "function",
        "compile:result")

    runChecks()
    

end

]==]

function AntiTamper:init(settings) end

function AntiTamper:apply(ast, pipeline)
    if pipeline and pipeline.PrettyPrint then
        logger:warn(string.format('"%s" cannot be used with PrettyPrint, ignoring "%s"', self.Name, self.Name))
        return ast
    end

    local parsed = Parser:new({ LuaVersion = Enums.LuaVersion.Lua51 }):parse(PACA_CODE)
    local first = parsed.body.statements[1]
    if not first then
        error("PACA Anti-Tamper generated no statements")
    end

    first.body.scope:setParent(ast.body.scope)
    table.insert(ast.body.statements, 1, first)
    return ast
end

return AntiTamper
