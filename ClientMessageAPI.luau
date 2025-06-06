--!strict

--[[
	This is the heart of PGNS. It is responsible for all of the UI stuff.
]]

local main = script.Parent
local sui = main:WaitForChild('PGNSUI')
local msgContainer = sui:WaitForChild('Main')
local cfg = require(main:WaitForChild('MessageConfigs'))
local f = require(main:WaitForChild('MessageFunctions'))
local emojis = require(script:WaitForChild('EmojiList'))
local rus = game:GetService('RunService')

sui.Parent = game:GetService('Players').LocalPlayer.PlayerGui

type Message = {
	Object: cfg.Object, --reference to the UI object itself
	State: f.State, --look in MessageFunctions to see the available types
	Type: cfg.MessageType, --the preset of the message
	Hidden: boolean?, --whether or not the message is currently visible on screen.
	Duration: number, --max life before message disappears; set to -1 for infinite duration (must be deleted manually)
	Life: number, --internal countdown that marches towards the set duration
	ID: string, --unique identifier for each message; automatically generated if one isn't provided
	Priority: number, --higher priority will display closer to the center of the screen.
	CreationTime: number, --measured via os.clock().
	LastUpdated: number, --measured via os.clock().
	
	__creationNumber: number, --used internally for sorting/prioritizing notifications
	__cache: {cfg.TextObject | cfg.ImageObject}, --used internally for optimizing :SetDisplay() method calls
}

type class = {
	__index: class,
	__idCounter: number,
	__creationCounter: number,
	__newID: () -> string, --generates a new Message ID.
	__sortOrderFunction: (a: Message, b: Message) -> boolean, --used to order messages by priority.
	
	MaxMessages: number, --maximum number of messages to be tracked.
	Registry: {[string]: Message}, --stores all active messages in {ID=Message} format.
	
	--[[
		Create and display a new message. Optional customization parameters.
		Will create a new ID for the message if it is not provided.
		If provided ID is already in use, it will generate a new one.
		
		Returns the ID of the message.
	]]
	new: (f.Constructor) -> string,
	
	--[[
		Updates the entire module. Should be called on every frame.
		
		Returns the amount of active messages in registry.
	]]
	Step: (dt: number) -> number,
	
	--[[
		Set the displayed message of a Message object. Called when using new().
		This function is mostly meant for internal use, but it's exposed in case you needed it.
		
		renew will reset the life of the message, making it last longer.
		silentChange will suppress any animations with changing text.
		
		Silently errors if the object cannot be found by ID and returns false.
	]]
	SetDisplay: (self: string, msg: f.Elements, renew: boolean?, silentChange: boolean?) -> boolean,
	
	--[[
		The default and recommended way of displaying a notification message.
		**Unlike new(), Do() will guarantee the existence of ONE message if provided an ID.
		Can pass a new duration in the constructor and update the message with it.
		This is essentially a combination of new() and SetDisplay().
		
		Returns the ID of the message.
	]]
	Do: (f.Constructor) -> string,
	
	--[[
		Schedule a message to be deleted on the next Step() call.
		
		Silently errors if the object cannot be found by ID and returns false.
	]]
	End: (self: string, instant: boolean?) -> boolean,
	
	--[[
		Removes all messages on screen.
	]]
	ClearAll: (instant: true?) -> (),
	
	--[[
		Reevaluates the displayed message and updates their positioning.
		Also hides messages that are outside of the MaxMessage limit.
		This should be called whenever a message is added or removed.
	]]
	UpdateOrdering: () -> (),
	
	--[[
		Attempts to convert inputted string into its emoji equivalent.
		
		Returns the unchanged string if the format is incorrect.
		Returns an empty string if the specified emoji is not found.
	]]
	EvaluateEmoji: (string) -> string,
}

local class: class = {}::any do
	
	--hard limit on number of visible messages.
	--this does NOT limit the amount stored in registry; there can be much more stored than visible.
	class.MaxMessages = 12
	
	class.__index = class
	class.__idCounter = 0
	class.__creationCounter = 0
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
		Reevaluates the displayed messages and updates their positioning.
		Also hides messages that are outside of the MaxMessage limit.
		This should be called whenever a message is added or removed.
	]]
	local sortingTemp: {Message} = table.create(class.MaxMessages)
	class.UpdateOrdering = @native function()
		for ID, obj in class.Registry do
			table.insert(sortingTemp, obj)
		end
		table.sort(sortingTemp, class.__sortOrderFunction)
		for i, obj in sortingTemp do
			if i > class.MaxMessages and not obj.Hidden then
				obj.Hidden = true
				obj.Object.Visible = false
			elseif i <= class.MaxMessages and obj.Hidden then
				obj.Hidden = false
				obj.Object.Visible = true
			end
			--[[
			if i > class.MaxMessages then
				class.End(obj.ID)
			end
			--]]
			obj.Object.LayoutOrder = i
		end
		table.clear(sortingTemp)
	end
	
	--[[
		Create and display a new message. Optional customization parameters.
		**Unlike Do(), new() will guarantee making a NEW message and never override.
		Will create a new ID for the message if it is not provided.
		If provided ID is already in use, it will generate a new one.
		
		Returns the ID of the message.
	]]
	class.new = function(c: f.Constructor): string
		local ID: string = c.ID or c.id or class.__newID()
		if class.Registry[ID] then
			warn('Message ID already used, regenerating ID')
			repeat ID = class.__newID()
			until not class.Registry[ID]
		end
		
		local now: number = os.clock()
		class.__creationCounter += 1
		
		local msgType: cfg.MessageType = cfg.Types[c.Type or c.t or 'Default'] or cfg.Types.Default
		local obj = cfg.msgEx:Clone()
		cfg.PreloadMessageObjectAsync(obj)
		
		local priority: number = c.Priority or c.p or msgType.DefaultPriority
		obj.Parent = msgContainer
		
		local self: Message = {
			Object = obj,
			State = 'New',
			Type = msgType,
			Duration = c.Duration or c.d or msgType.DefaultDuration,
			Life = 0,
			ID = ID,
			Priority = priority,
			CreationTime = now,
			LastUpdated = now,
			
			__creationNumber = class.__creationCounter,
			__cache = {},
		}
		
		class.Registry[self.ID] = self
		
		if not (c.NoClick or c.nc) then
			obj.Visual.InputBegan:Connect(function(i: InputObject)
				if i.UserInputType == Enum.UserInputType.MouseButton1 then
					class.End(self.ID)
				end
			end)
		end
		class.SetDisplay(self.ID, c, nil, true)
		class.UpdateOrdering()
		if msgType.Sound then
			msgType.Sound:Play()
		end
			
		return self.ID
	end
	
	--[[
		Set the displayed message of a Message object. Called when using new().
		This function is mostly meant for internal use, but it's exposed in case you needed it.
		
		renew will reset the life of the message, making it last longer.
		silentChange will suppress any animations with changing text.
		
		Silently errors if the object cannot be found by ID and returns false.
	]]
	class.SetDisplay = function(self: string, msg: f.Elements, renew: boolean?, silentChange: boolean?): boolean
		local self: Message? = class.Registry[self]
		if not self or self.State == 'Dead' then
			return false
		end
		
		if renew and self.Duration ~= -1 then
			self.Life = 0
		end
		
		if self.State == 'Active' and not (silentChange or self.Hidden) then
			self.Type.Changed(self.Object)
		end
		
		local container = self.Object.Visual
		
		--this section below checks if the preexisting UI elements would work with the new message.
		--enables optimization by reusing the UI elements if yes, otherwise it regenerates everything.
		
		local usedOptimization: boolean = #self.__cache == #msg --preemptive check on number of elements
		local cacheReused: {true} = table.create(#self.__cache)
		
		if usedOptimization then
			for i, element in ipairs(msg) do --ipairs() is necessary to iterate only the array portion of the table
				local exists: (cfg.TextObject | cfg.ImageObject)? = self.__cache[i]
				if not exists then
					usedOptimization = false
					break
				end
				
				if type(element) == 'number' then
								
					if element<0 or 1/element==1/-0 and exists:IsA('TextLabel') then
						--recycle the loading bar element
						exists.Text = cfg.GenerateLoadingBarText(-element)
						cacheReused[i] = true
						
					elseif exists:IsA('ImageLabel') then
						--recycle the image decal element
						exists.Image = 'rbxassetid://'..element
						cacheReused[i] = true
					end
					
				elseif type(element) == 'string' and exists:IsA('TextLabel') then
					--recycle the text element
					element = class.EvaluateEmoji(element)
					exists.Text = element	
					cacheReused[i] = true
				else
					usedOptimization = false
					break
				end
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
			--if optimization cannot be used, it will regenerate the message elements
			table.clear(self.__cache)			
			for _, v in container:GetChildren() do
				if v:HasTag('MsgElement') then
					v:Destroy()
				end
			end
			
			--must use ipairs() to iterate only the array portion; can't use GI
			for i, element in ipairs(msg) do 
				
				if type(element) == 'string' then --a regular text element
					element = class.EvaluateEmoji(element)
					
					local new = cfg.txtEx:Clone()
					new.LayoutOrder = i
					new.Text = element
					new.Parent = container
					self.__cache[i] = new
					
				elseif type(element) == 'number' then
					
					if element<0 or 1/element==1/-0 then --a loading bar element
						local new = cfg.txtEx:Clone()
						new.LayoutOrder = i
						new.Text = cfg.GenerateLoadingBarText(-element)
						new.Parent = container		
						self.__cache[i] = new
						
					else --an image decal element
						local new = cfg.imgEx:Clone()
						new.LayoutOrder = i
						new.Image = 'rbxassetid://'..element
						new.Parent = container
						self.__cache[i] = new
					end
				end
			end
		end
		
		self.LastUpdated = os.clock()
		
		return true
	end
	
	--[[
		The default and recommended way of displaying a notification message.
		**Unlike new(), Do() will guarantee the existence of ONE message if provided an ID.
		Can pass a new duration in the constructor and update the message with it.
		This is essentially a combination of new() and SetDisplay().
		
		Returns the ID of the message.
	]]
	class.Do = function(c: f.Constructor): string
		local id: string? = c.ID or c.id
		if id then
			local self: Message? = class.Registry[id]
			if self then				
				if self.State == 'New' or self.State == 'In' or self.State == 'Active' then
					self.Duration = c.Duration or c.d or self.Duration
					local silent: boolean? = c.Silent or c.s
					class.SetDisplay(id, c, true, if silent == nil then true else silent)
					return id
				end
				class.End(self.ID, true)
				class.Step(0)
			end
		end
		return class.new(c)
	end
	
	--[[
		Schedule a message to be deleted on the next Step() call.
		
		Silently errors if the object cannot be found by ID and returns false.
	]]
	class.End = function(self: string, instant: boolean?): boolean
		local self: Message? = class.Registry[self]
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
		Updates the entire module. Should be called on every frame.
		
		Returns the amount of active messages in registry.
	]]
	class.Step = function(dt: number): number
		local count: number = 0
		local needReorder: boolean = false
		for ID, obj in class.Registry do
			local mType: cfg.MessageType = obj.Type
			
			if obj.State == 'Dead' then
				table.clear(obj.__cache)
				obj.Object:Destroy()
				class.Registry[ID] = nil
				needReorder = true
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
		
		if needReorder then
			class.UpdateOrdering()
		end
		
		return count
	end
	
	--[[
		removes all messages on screen.
	]]
	class.ClearAll = function(instant: true?)
		for ID, obj in class.Registry do
			class.End(obj.ID, instant)
		end
		class.Step(0)
	end
	
	--[[
		Attempts to convert inputted string into its emoji equivalent.
		
		Returns the unchanged string if the format is incorrect.
		Returns an empty string if the specified emoji is not found.
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
