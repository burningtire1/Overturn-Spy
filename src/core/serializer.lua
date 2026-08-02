--[[
    @module  Serialiser
    @file    src/core/serializer.lua
    @desc    Converts any Roblox / Lua value into its constructor string.
             Used to build the "Copy as Script" output and argument previews.

    Public:
        _ser(value, depth?)  → string
        argsStr(args)        → comma-separated string of serialised args
        pathOf(instance)     → "game.Service.Parent.Child" path string
        toScript(entry)      → executable Lua line for the log entry
]]

local _ser  -- forward declaration for recursive table serialisation

local _fns = {
    ["nil"]   = function()  return "nil" end,
    boolean   = function(v) return tostring(v) end,
    number    = function(v)
        if v ~= v          then return "0/0 --[[NaN]]" end
        if v ==  math.huge then return  "math.huge"    end
        if v == -math.huge then return "-math.huge"    end
        if v % 1 == 0 and math.abs(v) < 1e15 then
            return tostring(math.floor(v))
        end
        return string.format("%.6g", v)
    end,
    string = function(v)
        local s = v
            :gsub("\\", "\\\\"):gsub('"',  '\\"')
            :gsub("\n", "\\n") :gsub("\r", "\\r")
            :gsub("\t", "\\t")
            :gsub("[%c]", function(c) return ("\\%d"):format(c:byte()) end)
        if #s > 96 then s = s:sub(1, 93) .. "…" end
        return '"' .. s .. '"'
    end,
    table = function(v, d)
        if d >= 3 then return "{…}" end
        local parts, n = {}, 0
        for k, val in pairs(v) do
            n += 1
            if n > 20 then parts[#parts + 1] = "…"; break end
            local key = (type(k) == "string" and k:match("^[%a_][%w_]*$"))
                and k or ("[" .. _ser(k, d + 1) .. "]")
            parts[#parts + 1] = key .. " = " .. _ser(val, d + 1)
        end
        return n == 0 and "{}" or ("{ " .. table.concat(parts, ", ") .. " }")
    end,
    Instance = function(v)
        local parts, cur, lim = {}, v, 28
        while cur and cur ~= game and lim > 0 do
            table.insert(parts, 1, cur.Name)
            cur, lim = cur.Parent, lim - 1
        end
        return cur ~= game and tostring(v) or ("game." .. table.concat(parts, "."))
    end,
    Vector3      = function(v) return ("Vector3.new(%g, %g, %g)"):format(v.X, v.Y, v.Z) end,
    Vector2      = function(v) return ("Vector2.new(%g, %g)"):format(v.X, v.Y) end,
    Vector3int16 = function(v) return ("Vector3int16.new(%d, %d, %d)"):format(v.X, v.Y, v.Z) end,
    Vector2int16 = function(v) return ("Vector2int16.new(%d, %d)"):format(v.X, v.Y) end,
    CFrame = function(v)
        local x, y, z   = v.X, v.Y, v.Z
        local rx, ry, rz = v:ToEulerAnglesXYZ()
        if rx == 0 and ry == 0 and rz == 0 then
            return ("CFrame.new(%g, %g, %g)"):format(x, y, z)
        end
        return ("CFrame.new(%g, %g, %g) * CFrame.Angles(%g, %g, %g)"):format(
            x, y, z, rx, ry, rz)
    end,
    Color3 = function(v)
        return ("Color3.fromRGB(%d, %d, %d)"):format(
            math.round(v.R * 255), math.round(v.G * 255), math.round(v.B * 255))
    end,
    UDim2 = function(v)
        return ("UDim2.new(%g, %d, %g, %d)"):format(
            v.X.Scale, v.X.Offset, v.Y.Scale, v.Y.Offset)
    end,
    UDim              = function(v) return ("UDim.new(%g, %d)"):format(v.Scale, v.Offset) end,
    BrickColor        = function(v) return ('BrickColor.new("%s")'):format(v.Name) end,
    EnumItem          = tostring,
    Enum              = tostring,
    NumberRange       = function(v) return ("NumberRange.new(%g, %g)"):format(v.Min, v.Max) end,
    NumberSequence    = function()  return "NumberSequence.new({--[[…]]})" end,
    ColorSequence     = function()  return "ColorSequence.new({--[[…]]})" end,
    RBXScriptSignal   = function()  return "--[[RBXScriptSignal]]" end,
    RBXScriptConnection = function() return "--[[RBXScriptConnection]]" end,
    Ray = function(v)
        local o, d = v.Origin, v.Direction
        return ("Ray.new(Vector3.new(%g,%g,%g), Vector3.new(%g,%g,%g))"):format(
            o.X, o.Y, o.Z, d.X, d.Y, d.Z)
    end,
    TweenInfo = function(v)
        return ("TweenInfo.new(%g, %s, %s, %d, %s, %g)"):format(
            v.Time, tostring(v.EasingStyle), tostring(v.EasingDirection),
            v.RepeatCount, tostring(v.Reverses), v.DelayTime)
    end,
    PhysicalProperties = function(v)
        return ("PhysicalProperties.new(%g, %g, %g)"):format(
            v.Density, v.Friction, v.Elasticity)
    end,
}

_ser = function(v, depth)
    depth = depth or 0
    local fn = _fns[typeof(v)]
    if not fn then return ("--[[%s]]"):format(typeof(v)) end
    local ok, out = pcall(fn, v, depth)
    return ok and out or ("--[[err:%s]]"):format(typeof(v))
end

local function argsStr(args)
    if #args == 0 then return "" end
    local p = table.create(#args)
    for i = 1, #args do p[i] = _ser(args[i]) end
    return table.concat(p, ", ")
end

local function pathOf(inst)
    if not inst then return "nil" end
    local parts, cur, lim = {}, inst, 28
    while cur and cur ~= game and lim > 0 do
        table.insert(parts, 1, cur.Name)
        cur, lim = cur.Parent, lim - 1
    end
    if cur ~= game then return tostring(inst) end
    return "game." .. table.concat(parts, ".")
end

local function toScript(e)
    if not e.remote or not e.remote.Parent then
        return "-- remote was garbage collected"
    end
    local p    = pathOf(e.remote)
    local args = argsStr(e.args)
    if   e.type == "RemoteEvent" or e.type == "UnreliableRemoteEvent" then
        return ("%s:FireServer(%s)"):format(p, args)
    elseif e.type == "RemoteFunction" then
        return ("local result = %s:InvokeServer(%s)"):format(p, args)
    elseif e.type == "ReturnValue" then
        return ("-- Returned: %s"):format(args ~= "" and args or "nil")
    end
    return "-- unknown type: " .. tostring(e.type)
end

return { ser = _ser, argsStr = argsStr, pathOf = pathOf, toScript = toScript }
