--!strict

--[[
	This ModuleScript is really the only thing you need to care about.
	This API allows other serverscripts to use the PGNS.
]]

local mss = game:GetService('MessagingService')
local res = game:GetService('ReplicatedStorage')
local main = res:WaitForChild('PGNS')
local f = require(main:WaitForChild('MessageFunctions'))
local broadcast = main:WaitForChild('Broadcast')
local broadcastUnreliable = main:WaitForChild('BroadcastUnreliable')

--[[
	Send a notification to the specified player.
	Consider using ephemeralToPlayer() if the notification or notification change is not important.
]]
local function broadcastToPlayer(p: Player, msg: f.Constructor)
	broadcast:FireClient(p, f.Serialize(msg))
end

--[[
	Send a notification to the specified player via UnreliableRemoteEvent.
	Using this instead of broadcastToPlayer() is recommended if it's a notification that changes often.
]]
local function ephemeralToPlayer(p: Player, msg: f.Constructor)
	broadcastUnreliable:FireClient(p, f.Serialize(msg))
end

--[[
	Send a notification to all players in the server.
	Consider using ephemeralServer() if the notification or notification change is not important.
]]
local function broadcastServer(msg: f.Constructor)
	broadcast:FireAllClients(f.Serialize(msg))
end

--[[
	Send a notification to all players in the server via UnreliableRemoteEvent.
	Using this instead of broadcastServer() is recommended if it's a notification that changes often.
]]
local function ephemeralServer(msg: f.Constructor)
	broadcastUnreliable:FireAllClients(f.Serialize(msg))
end

--[[
	Send a notification to all active servers in your game.
	This is a dangerous permission to grant; only intended for operators.
]]
local function broadcastGlobal(msg: f.Constructor)
	mss:PublishAsync('PGNS_Notification', f.Serialize(msg))
end

--[[
	For convinence, the APIs have been added to the global table which allows it
	to be used from the developer console for game developers.
	
	I've also added some decorations that makes it clear who is sending the message.
]]
_G.tell = broadcastToPlayer
_G.say = broadcastServer
_G.saydev = function(msg: f.Constructor)
	table.insert(msg, 1, '<font color="#F00"><b>[Developer]</b></font>')
	msg.Type = msg.Type or msg.t or 'Warning'
	msg.Priority = 1e6 + (msg.Priority or msg.p or 0)
	broadcastServer(msg)	
end
_G.psa = function(msg: f.Constructor)
	table.insert(msg, 1, '<font color="#FF0"><b>[PSA]</b></font>')
	msg.Type = msg.Type or msg.t or 'Warning'
	msg.Priority = 1e6 + (msg.Priority or msg.p or 0)
	broadcastServer(msg)
end
_G.sayglobal = broadcastGlobal
_G.psaglobal = function(msg: f.Constructor)
	table.insert(msg, 1, '<font color="#FF0"><b>[PSA]</b></font>')
	msg.Type = msg.Type or msg.t or 'Warning'
	msg.Priority = 1e6 + (msg.Priority or msg.p or 0)
	broadcastGlobal(msg)	
end

task.spawn(mss.SubscribeAsync, mss, 'PGNS_Notification', function(msg: {Data: f.Serialized, Sent: number})
	broadcast:FireAllClients(msg.Data)
end)

local module = {
	BroadcastPlayer = broadcastToPlayer,
	EphemeralPlayer = ephemeralToPlayer,
	BroadcastAll = broadcastServer,
	EphemeralAll = ephemeralServer,
	
	broadcastGlobal = broadcastGlobal,
}

return module
