--!strict

--[[
	This serverscript's only practical purpose is to activate the ServerMessageAPI.
	
	For testing purposes, it will automatically greet players who join the game.
]]

local pls = game:GetService('Players')
local res = game:GetService('ReplicatedStorage')

local main = res:WaitForChild('PGNS')
local api = require(main:WaitForChild('ServerMessageAPI'))
local f = require(main:WaitForChild('MessageFunctions'))
local broadcast = main:WaitForChild('Broadcast')

--add text commands for testing
local tcs = game:GetService('TextChatService')
script.NotifierCommand.Parent = tcs
script.NotifierTesterCommand.Parent = tcs

--just as an example, we'll send two messages to players when they join, 4 seconds apart.
local function greet(pl: Player)
	api.BroadcastPlayer(pl, {11818627057, `Welcome, <b>{pl.Name}</b>`, ID='Greet', Type='Warning'})
	task.wait(4)
	api.BroadcastPlayer(pl, {':wave:', `Welcome, <b>{pl.Name}</b>`, ID='Greet', Type='Warning', Renew=true})
end
pls.PlayerAdded:Connect(greet)
for _, v in pls:GetPlayers() do
	task.spawn(greet, v)
end

--[[
	A player requests to broadcast a message to the server.
	Checks if they have permissions to do so first.
]]
broadcast.OnServerEvent:Connect(function(pl: Player, msg: f.Serialized)
	if f.PermissionToBroadcast(pl) then
		api.BroadcastAll(f.Deserialize(msg))
	else
		warn(`PGNS: player {pl.Name} lacks permission to broadcast`)
	end
end)