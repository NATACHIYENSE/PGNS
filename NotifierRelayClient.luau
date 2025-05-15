--!strict

--[[
	This localscript's only purpose is to use the ClientMessageAPI.
	
	For testing purposes, it also includes stuff with chat commands that you should
	remove before putting this in your game.
]]

local res = game:GetService('ReplicatedStorage')
local tcs = game:GetService('TextChatService')
local lp = game:GetService('Players').LocalPlayer

local main = res:WaitForChild('PGNS')
local api = require(main:WaitForChild('ClientMessageAPI'))
local f = require(main:WaitForChild('MessageFunctions'))
local broadcast = main:WaitForChild('Broadcast')

--listen to new notifications broadcasted by the server
broadcast.OnClientEvent:Connect(function(msg: f.Serialized)
	local data: f.Constructor = f.Deserialize(msg)
	if data.ID and api.Registry[data.ID] then
		api.SetDisplay(data.ID, data, data.Renew)
	else
		api.new(data)
	end
end)

--below are for hooking up chat commands.
--these commands will be automatically placed in TextChatService by the server.

--[[
	This command allows the player to send a notification to everyone in
	the server IF they have the permissions to do so.
]]
local broadcastCommand = tcs:WaitForChild('NotifierCommand')
broadcastCommand.Triggered:Connect(function(source: TextSource, text: string)
	if not f.PermissionToBroadcast(lp) then
		api.new{Type='Error', 'You do not have permissions to run this command.'}
		return
	end
	
	text = string.sub(text, #broadcastCommand.PrimaryAlias+2)
	
	broadcast:FireServer(f.Serialize{text})
end)

--[[
	This command is to test printing out errors. It causes an error.
	Use "/ntest force_error" to get multiple error messages.
]]
local ntestCommand = tcs:WaitForChild('NotifierTesterCommand')
ntestCommand.Triggered:Connect(function(source: TextSource, text: string)
	text = string.sub(text, #ntestCommand.PrimaryAlias+2)
	
	if text == 'force_error' then
		local _, err = pcall(function()
			return workspace[nil]
		end)
		api.new{Type='Error', ':x:', err}
		local _, err = pcall(function()
			return (nil::any)[nil]
		end)
		api.new{Type='Error', ':x:', err}
		local _, err = pcall(function()
			return workspace.FindFirstChild()
		end)
		api.new{Type='Error', ':x:', err}
		local _, err = pcall(nil::any)
		api.new{Type='Error', ':x:', err}
	else
		api.new{Type='Error', ':x:', `test "{text}" not found`}
	end
end)