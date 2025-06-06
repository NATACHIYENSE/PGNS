--!strict

--[[
	This localscript's main purpose is to bridge between the server and client APIs.
	
	For testing purposes, it also includes stuff with chat commands that you should
	remove before putting this in your game.
]]

local res = game:GetService('ReplicatedStorage')
local http = game:GetService('HttpService')
local tcs = game:GetService('TextChatService')
local lp = game:GetService('Players').LocalPlayer

local main = res:WaitForChild('PGNS')
local api = require(main:WaitForChild('ClientMessageAPI'))
local f = require(main:WaitForChild('MessageFunctions'))
local broadcast = main:WaitForChild('Broadcast')
local broadcastUnreliable = main:WaitForChild('BroadcastUnreliable')

--listen to new notifications broadcasted by the server
local function onEvent(msg: f.Serialized)
	api.Do(f.Deserialize(msg))
end
broadcast.OnClientEvent:Connect(onEvent)
broadcastUnreliable.OnClientEvent:Connect(onEvent)

--below are for hooking up chat commands.
--these commands will be automatically placed in TextChatService by the server.

--[[
	This command allows the player to send a notification to everyone in
	the server IF they have the permissions to do so.
]]
local broadcastCommand = tcs:WaitForChild('NotifierCommand')
broadcastCommand.Triggered:Connect(function(source: TextSource, text: string)
	if not f.PermissionToBroadcast(lp) then
		api.new{t='Error', ':x:', 'PGNS: Access denied (lacking permission)'}
		return
	end
	
	text = string.sub(text, #broadcastCommand.PrimaryAlias+2)
	if string.sub(text, 1, 1) == '{' and string.sub(text, -1, -1) == '}' then
		local s1: boolean, json: f.Serialized? = pcall(http.JSONDecode, http, text)
		if s1 and json then
			if pcall(f.Deserialize, json) then
				broadcast:FireServer(json)
				return
			end
			api.new{t='Error', ':x:', 'Bad arguments; did not broadcast'}
			return
		end
		api.new{t='Error', ':x:', 'Malformed JSON; did not broadcast'}
		return
	end
	broadcast:FireServer(f.Serialize{text})
end)
