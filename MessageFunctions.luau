--!strict

--[[
	This ModuleScript is for internal use by both the server and client APIs.
]]

export type State = 'New' | 'In' | 'Active' | 'Out' | 'Dead'
export type Elements = {[number]: string | number}

export type Constructor = {
	[number]: number | string, --message
		
	Type: string?,
	NoClick: boolean?,
	Duration: number?,
	Priority: number?,
	ID: string?,
	Renew: true?,
}

export type Serialized = {
	Message: Elements,
	Type: string?,
	NoClick: boolean?,
	Duration: number?,
	Priority: number?,
	ID: string?,	
	Renew: true?,
}

--[[
	Because the Constructor struct used for creating messages is a mixed table,
	it cannot be sent across remotes due to datatype restrictions.
	
	The serialization process decomposes the mixed table into a dictionary.
]]
local function serializeMessage(msg: Constructor): Serialized
	local elements: {number | string} = table.create(#msg)
	for k, v in ipairs(msg) do --ipairs() is necessary
		elements[k] = v
	end
	local data: Serialized = {
		Message = elements,
		Type = msg.Type,
		NoClick = msg.NoClick,
		Duration = msg.Duration,
		Priority = msg.Priority,
		ID = msg.ID,
		Renew = msg.Renew,
	}
	return data
end

--[[
	Deserialization undos the process and turns the dictionary back into a mixed table.
]]
local function deserializeMessage(msg: Serialized): Constructor
	local data: Constructor = {
		Type = msg.Type,
		NoClick = msg.NoClick,
		Duration = msg.Duration,
		Priority = msg.Priority,
		ID = msg.ID,
		Renew = msg.Renew,
	}
	for k, v in msg.Message do
		data[k] = v
	end
	return data
end

--[[
	Edit this when you use it in your game!
	
	This function is to allow specific players to broadcast server-wide messages
	by checking their group rank.
]]
local function permissionToBroadcast(pl: Player): boolean
	return pl:GetRankInGroup(32774622) >= 254
end

local module = {
	Serialize = serializeMessage,
	Deserialize = deserializeMessage,
	PermissionToBroadcast = permissionToBroadcast,
}

return module
