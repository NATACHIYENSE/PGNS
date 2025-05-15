--!strict

--[[
	This is the heart of PGNS. It is responsible for all of the UI stuff.
]]

local main = script.Parent
local sui = main:WaitForChild('Notifier')
local msgContainer = sui:WaitForChild('Main')
local cfg = require(main:WaitForChild('MessageConfigs'))
local f = require(main:WaitForChild('MessageFunctions'))
local emojis = require(script:WaitForChild('EmojiList'))
local rus = game:GetService('RunService')

sui.Parent = game:GetService('Players').LocalPlayer.PlayerGui

type Struct = {
	Object: cfg.Object, --reference to the UI object itself
	State: f.State, --look in MessageFunctions to see the available types
	Type: cfg.MessageType, --the preset of the message
	Duration: number, --max life before message disappears; set to -1 for infinite duration (must be deleted manually)
	Life: number, --internal countdown that marches towards the set duration
	ID: string, --unique identifier for each message; automatically generated if one isn't provided
	Priority: number, --higher priority will display closer to the center of the screen.
	CreationTime: number, --measured via os.clock().
	
	__creationNumber: number, --used internally for sorting/prioritizing notifications
	__cache: {cfg.TextObject | cfg.ImageObject}, --used internally for optimizing :SetDisplay() method calls
}
type Impl = {

	--[[
		set the displayed message of a Message object. Can call via OOP, or using the designated ID of the object.
		renew will reset the life of the message, making it last longer.
		silentChange will suppress any animations with changing text.
		silently errors if the object cannot be found by ID and returns false.	
	]]
	SetDisplay: (self: Message|string, msg: f.Elements, renew: boolean?, silentChange: boolean?) -> boolean,
	
	--[[
		manually delete a message, instant mode skips animations. Can call via OOP, or using the designated ID of the object.
		silently errors if the object cannot be found by ID and returns false.			
	]]
	End: (self: Message|string, instant: boolean?) -> boolean,
}
export type Message = Struct & Impl

type class = Impl & {
	__index: class,
	__idCounter: number,
	__creationCounter: number,
	__newID: () -> string, --generates a new Message ID.
	__sortOrderFunction: (a: Message, b: Message) -> boolean, --used to order messages by priority.
	
	MaxMessages: number, --maximum number of messages allowed on the screen at once.
	Registry: {[string]: Message}, --stores all active messages in {ID=Message} format.
	
	--[[
		create and display a new message. Optional customization parameters.
		will create a new ID for the message if it is not provided.
		if provided ID is already in use, it will generate a new one.	
	]]
	new: (f.Constructor) -> Message,
	
	--[[
		updates the entire module. Should be called on every frame.
		Returns the amount of active messages in registry.
	]]
	Step: (dt: number) -> number,
	
	--[[
		removes all messages on screen.
	]]
	ClearAll: (instant: true?) -> (),
	
	--[[
		reevaluates the displayed message and updates their positioning.
		Also removes messages that surpassed the limit.	
	]]
	UpdateOrdering: () -> (),
	
	--[[
		attempts to convert inputted string into its emoji equivalent.
		Returns the unchanged string if it fails to find a relevant emoji.
	]]
	EvaluateEmoji: (string) -> string,
}

local class: class = {}::any do
	class.__index = class
	class.__idCounter = 0
	class.__creationCounter = 0
	class.MaxMessages = 5
	class.Registry = {}
	
	--[[
		creates a new ID used to track notification messages.	
	]]
	class.__newID = function(): string
		class.__idCounter += 1
		return 'ID#'..class.__idCounter
	end	
	
	--[[
		used internally to sort notifications by their priority.
		If two messages have identical priorities, they will be sorted by date.
	]]
	class.__sortOrderFunction = function(a: Message, b: Message): boolean
		return a.Priority>b.Priority
			or (a.Priority==b.Priority and a.__creationNumber>b.__creationNumber)
	end
	
	--[[
		reevaluates the displayed message and updates their positioning.
		Also removes messages that surpassed the limit.	
	]]
	class.UpdateOrdering = function()
		local temp: {Message} = table.create(class.MaxMessages)
		for ID, obj in class.Registry do
			table.insert(temp, obj)
		end
		table.sort(temp, class.__sortOrderFunction)
		for i, obj in temp do
			if i > class.MaxMessages then
				obj:End()
			end
			obj.Object.LayoutOrder = i
		end
	end
	
	--[[
		create and display a new message. Optional customization parameters.
		will create a new ID for the message if it is not provided.
		if the provided ID is already in use, it will generate a new one.	
	]]
	class.new = function(c: f.Constructor): Message
		local ID: string = c.ID or class.__newID()
		if class.Registry[ID] then
			warn('Message ID already used, regenerating ID')
			repeat ID = class.__newID()
			until not class.Registry[ID]
		end
		
		class.__creationCounter += 1
		
		local msgType: cfg.MessageType = cfg.Types[c.Type or 'Default']
		local obj = cfg.msgEx:Clone()
		cfg.PreloadMessageObjectAsync(obj)
		
		local priority: number = c.Priority or msgType.DefaultPriority
		obj.Parent = msgContainer
		
		local self: Struct = {
			Object = obj,
			State = 'New',
			Type = msgType,
			Duration = c.Duration or msgType.DefaultDuration,
			Life = 0,
			ID = ID,
			Priority = priority,
			CreationTime = os.clock(),
			__creationNumber = class.__creationCounter,
			__cache = {},
		}
		
		local self: Message = setmetatable(self, class)::any
		class.Registry[self.ID] = self
		
		if not c.NoClick then
			obj.Visual.Container.MouseButton1Click:Once(function() self:End() end)
		end
		self:SetDisplay(c, nil, true)
		class.UpdateOrdering()
		if msgType.Sound then
			msgType.Sound:Play()
		end
			
		return self
	end
	
	--[[
		set the displayed message of a Message object. Can call via OOP, or using the designated ID of the object.
		renew will reset the life of the message, making it last longer.
		silentChange will suppress any animations with changing text.
		silently errors if the object cannot be found by ID and returns false.	
	]]
	class.SetDisplay = function(self: Message|string, msg: f.Elements, renew: boolean?, silentChange: boolean?): boolean
		local self: Message? = if type(self) == 'string' then class.Registry[self] else self
		if not self or self.State == 'Dead' then
			return false
		end
		
		if renew and self.Duration ~= -1 then
			self.Life = 0
		end
		
		if not silentChange then
			self.Type.Changed(self.Object)
		end
		
		local container = self.Object.Visual.Container
		
		--check if the preexisting UI elements would work with the new message.
		--enables optimization by reusing the UI elements if yes, otherwise it resets everything.
		local usedOptimization: boolean = true
		local cacheReused: {true} = table.create(#self.__cache)
		for i, element in ipairs(msg) do
			local exists: (cfg.TextObject | cfg.ImageObject)? = self.__cache[i]
			if not exists then
				usedOptimization = false
				break
			end
			
			if type(element) == 'number' and exists:IsA('ImageLabel') then
				exists.Image = 'rbxassetid://'..element
				cacheReused[i] = true
			elseif type(element) == 'string' and exists:IsA('TextLabel') then
				element = class.EvaluateEmoji(element)
				exists.Text = element	
				cacheReused[i] = true
			else
				usedOptimization = false
				break
			end
		end
		
		if usedOptimization then
			--there might be an excess of UI elements not reused; those need to be deleted
			for i, uiElement in self.__cache do
				if cacheReused[i] then continue end
				uiElement:Destroy()
				self.__cache[i] = nil
			end
		else
			--print('cannot use optimization')
			
			table.clear(self.__cache)			
			for _, v in container:GetChildren() do
				if v:HasTag('MsgElement') then
					v:Destroy()
				end
			end
			
			--must use ipairs() to iterate only the array portion; can't use GI lol
			for i, element in ipairs(msg) do 
				if type(element) == 'string' then
					element = class.EvaluateEmoji(element)
					
					local new = cfg.txtEx:Clone()
					new.LayoutOrder = i
					new.Text = element
					new.Parent = container
					self.__cache[i] = new
				elseif type(element) == 'number' then
					local new = cfg.imgEx:Clone()
					new.LayoutOrder = i
					new.Image = 'rbxassetid://'..element
					new.Parent = container
					self.__cache[i] = new
				end
			end
		end
		
		return true
	end
	
	--[[
		manually delete a message, instant mode skips animations.
		Can call via OOP, or using the designated ID of the object.
		Silently errors if the object cannot be found by ID and returns false.
	]]
	class.End = function(self: Message|string, instant: boolean?): boolean
		local self: Message? = if type(self) == 'string' then class.Registry[self] else self
		if not self then
			return false
		end
		
		if instant then
			self.State = 'Dead'
		elseif self.State ~= 'Dead' then
			self.Life = self.Duration
		end
		
		return true
	end
	
	--[[
		updates the entire module. Should be called on every frame.
		Returns the amount of active messages in registry.
	]]
	class.Step = function(dt: number): number
		local count: number = 0
		for ID, obj in class.Registry do
			local mType: cfg.MessageType = obj.Type
			
			if obj.State == 'Dead' then
				table.clear(obj.__cache)
				obj.Object:Destroy()
				class.Registry[ID] = nil
				continue
			end
			
			count += 1
			obj.Life += dt
			
			if obj.Duration ~= -1 and obj.Life >= obj.Duration then
				if obj.State == 'Active' then
					obj.Life += mType.End(obj.Object)
					obj.State = 'Out'
				elseif obj.State == 'Out' then
					obj.State = 'Dead'
				end
			end
			
			if obj.State == 'New' then
				obj.Life += mType.Init(obj.Object)
				obj.State = 'In'
			end
			
			if obj.State == 'In' and obj.Life > 0 then
				obj.State = 'Active'
			end
		end
		return count
	end
	
	--[[
		removes all messages on screen.
	]]
	class.ClearAll = function(instant: true?)
		for ID, obj in class.Registry do
			obj:End(instant)
		end
		class.Step(0)
	end
	
	--[[
		attempts to convert inputted string into its emoji equivalent.
		Returns the unchanged string if it fails to find a relevant emoji.
	]]
	class.EvaluateEmoji = function(element: string): string
		local emojiString: string? = string.match(element, '^:(.*):$')
		if emojiString then --does it have colons on either side?
			element = emojis[emojiString]
			if not element then
				warn(`Failed to parse emoji ":{emojiString}:"`)
				element = ''
			end
		end
		return element
	end
end

rus.RenderStepped:Connect(class.Step)
return class