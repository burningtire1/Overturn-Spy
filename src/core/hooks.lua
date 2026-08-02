--[[
    @module  Hooks
    @file    src/core/hooks.lua
    @desc    Intercepts NameCall metamethod on the game DataModel to capture
             :FireServer, :InvokeServer, :FireUnreliableServer calls.

             Hook is installed once on Start() and torn down on Stop().
             Uses hookmetamethod + newcclosure (executor APIs).

    Compatibility requirements:
        hookmetamethod(object, "__namecall", fn)
        getrawmetatable(object)
        getnamecallmethod()
        newcclosure(fn)

    Public:
        Hooks.install()   — Install the metamethod hook
        Hooks.remove()    — Restore the original metamethod
        Hooks._orig       — Stored original __namecall (nil before install)
]]

local Hooks = { _orig = nil }

local METHODS = {
    FireServer           = "RemoteEvent",
    InvokeServer         = "RemoteFunction",
    FireUnreliableServer = "UnreliableRemoteEvent",
}

local function handleCall(remote, method, args)
    if S.paused then return end
    local rtype = METHODS[method]
    if not rtype then return end

    local ok, cls = pcall(function() return remote.ClassName end)
    if not ok then return end

    local expected = rtype == "UnreliableRemoteEvent" and "UnreliableRemoteEvent"
        or (rtype == "RemoteFunction" and "RemoteFunction" or "RemoteEvent")
    if cls ~= expected then return end

    local path   = pathOf(remote)
    local drop   = spamCheck(path, args)
    local isSpam = Spam._records[path] and Spam._records[path].flagged or false

    if drop then
        S.spamCount += 1
        return
    end

    local entry = pushEntry({
        remote    = remote,
        path      = path,
        type      = rtype,
        args      = args,
        timestamp = os.clock(),
        spam      = isSpam,
        blocked   = S.blocked[path] == true,
    })

    S.dirty = true
    -- Deferred so plugin callbacks never run inside the hooked metamethod
    task.defer(function()
        Ev.onLog:Fire(entry)
    end)

    -- For RemoteFunction, we also want to capture the return value.
    -- This is handled separately in the hook body below via pcall.
end

function Hooks.install()
    if Hooks._orig then return end   -- already hooked

    Hooks._orig = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        local method = getnamecallmethod()
        local args   = { ... }

        -- Fire our handler before passing through
        pcall(handleCall, self, method, args)

        -- Pass through to original (must use original for RemoteFunction to work)
        if method == "InvokeServer" then
            local rets = table.pack(Hooks._orig(self, ...))
            -- Emit return-value entry
            if not S.paused then
                local path = pathOf(self)
                local ok, cls = pcall(function() return self.ClassName end)
                if ok and cls == "RemoteFunction" then
                    local retArgs = {}
                    for i = 1, rets.n do retArgs[i] = rets[i] end
                    local entry = pushEntry({
                        remote    = self,
                        path      = path,
                        type      = "ReturnValue",
                        args      = retArgs,
                        timestamp = os.clock(),
                        spam      = false,
                        blocked   = S.blocked[path] == true,
                    })
                    S.dirty = true
                    task.defer(function() Ev.onLog:Fire(entry) end)
                end
            end
            return table.unpack(rets, 1, rets.n)
        end

        return Hooks._orig(self, ...)
    end))

    S.active = true
end

function Hooks.remove()
    if not Hooks._orig then return end
    hookmetamethod(game, "__namecall", Hooks._orig)
    Hooks._orig = nil
    S.active    = false
end

return Hooks
