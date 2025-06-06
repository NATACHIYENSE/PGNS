--!strict

--[[
	This ModuleScript is for internal use by both the server and client APIs.
]]

export type State = 
	| 'New' --the message was just created and isn't doing anything yet.
	| 'In' --the message runs its Init() function that finalizes its appearance.
	| 'Active' --the message is on standby and is being seen on screen.
	| 'Out' --the message runs its End() function and prepares to leave.
	| 'Dead' --the message is disabled and will be promptly deleted.

export type Elements = {[number]: string | number}

export type Constructor = {
	[number]: number | string, --message in the form of an array
	
	ID: string?, id: string?,
	Type: string?, t: string?,
	NoClick: boolean?, nc: boolean?, --message cannot be manually dismissed by the player
	Duration: number?, d: number?,
	Priority: number?, p: number?, --higher priority messages are organized first on the line
	Silent: boolean?, s: boolean? --defaults to true
}

export type Serialized = {
	m: Elements,
	t: string?,
	nc: boolean?,
	d: number?,
	p: number?,
	id: string?,
	s: boolean?,
}

--[[
	Because the Constructor struct used for creating messages is a mixed table,
	it cannot be sent across remotes due to datatype restrictions.
	
	The serialization process decomposes the mixed table into a dictionary.
]]
@native local function serializeMessage(msg: Constructor): Serialized
	local elements: {number | string} = table.create(#msg)
	for k, v in ipairs(msg) do --ipairs() is necessary
		elements[k] = v
	end
	local data: Serialized = {
		m = elements,
		t = msg.Type or msg.t,
		nc = msg.NoClick or msg.nc,
		d = msg.Duration or msg.d,
		p = msg.Priority or msg.p,
		id = msg.ID or msg.id,
		s = msg.Silent or msg.s,
	}
	return data
end

--[[
	Deserialization undos the process and turns the dictionary back into a mixed table.
]]
@native local function deserializeMessage(msg: Serialized): Constructor
	local data: Constructor = {
		t = msg.t,
		nc = msg.nc,
		d = msg.d,
		p = msg.p,
		id = msg.id,
		s = msg.s,
	}
	for k, v in msg.m do
		data[k] = v
	end
	return data
end

--[[
	TODO: Edit this when you use it in your game!
	
	This function is to allow specific players to broadcast server-wide messages
	by checking their group rank.
]]
local isStudio: boolean = game:GetService('RunService'):IsStudio()
local function permissionToBroadcast(pl: Player): boolean
	return isStudio or pl:GetRankInGroup(32774622) >= 254
end

local module = {
	Serialize = serializeMessage,
	Deserialize = deserializeMessage,
	PermissionToBroadcast = permissionToBroadcast,
}

return module
