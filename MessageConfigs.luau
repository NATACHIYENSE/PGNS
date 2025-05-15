--!strict

--[[
	This ModuleScript defines all of the visual parameters of PGNS.
	It also defines the types used by the API.
]]

local tws = game:GetService('TweenService')
local cpr = game:GetService('ContentProvider')

local imgEx = script:WaitForChild('ImageLabel')
local txtEx = script:WaitForChild('TextLabel')
local msgEx = script:WaitForChild('Message')

export type Object = typeof(msgEx)
export type TextObject = typeof(txtEx)
export type ImageObject = typeof(imgEx)

--[[
	This is the struct used to define message types at the bottom of this script.
]]
export type MessageType = {
	Name: string,
	DefaultDuration: number,
	DefaultPriority: number,
	Sound: Sound?,
	Init: (Object) -> number, --runs when the message is born
	End: (Object) -> number, --runs when the message needs to die
	Changed: (Object) -> (), --runs when the message is updated
}

--[[
	Given a notification message element, preloads the UI instances by yielding.
]]
local function preloadMessageObjectAsync(obj: Object)
	local visual = obj:WaitForChild('Visual')
	visual:WaitForChild('UIPadding')
	local container = visual:WaitForChild('Container')
	container:WaitForChild('UIListLayout')
	container:WaitForChild('UICorner')
	container:WaitForChild('UIPadding')
	container:WaitForChild('UIStroke')
end

local A = { --for caching purposes; use this however you like with no standards
	sizeOff = UDim2.new(0, 10, 0, -1),
	sizeOn = UDim2.new(0, 10, 0, 28),
	twiGeneric = TweenInfo.new(.25, Enum.EasingStyle.Circular, Enum.EasingDirection.InOut),
	twiExpo = TweenInfo.new(.25, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),
	twiFlicker = TweenInfo.new(.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 4, true),
	twiFlickerRapid = TweenInfo.new(.05, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 7, true),
	twiFlickerSoft = TweenInfo.new(.25, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 1, true),
	twiSpring = TweenInfo.new(1, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out)
}

local S: {Sound} = {
	script:WaitForChild('sound/default'),
	script:WaitForChild('sound/warning'),
	script:WaitForChild('sound/error'),
	script:WaitForChild('sound/success')
}

--[[
	Here you define the different types of notification a player can receive.
	Each of them can have their own unique visuals and design.
	I've predefined 4 types: Default, Warning, Error, and Success.
]]
local messageTypes: {[string]: MessageType} = {
	Default = {
		Name = 'Default',
		DefaultDuration = 5,
		DefaultPriority = 0,
		Sound = S[1],
		Init = function(o: Object)
			o.Size = A.sizeOff
			--o.Visual.Size = A.sizeOff
			o.Visual.GroupTransparency = 1
			local stroke = o.Visual.Container.UIStroke
			stroke.Thickness = 0
			tws:Create(o, A.twiGeneric, {Size = A.sizeOn}):Play()
			tws:Create(o.Visual, A.twiGeneric, {Size = A.sizeOn, GroupTransparency = 0}):Play()
			tws:Create(stroke, A.twiGeneric, {Thickness = 2}):Play()
			return -A.twiGeneric.Time
		end,
		End = function(o: Object)
			tws:Create(o, A.twiGeneric, {Size = A.sizeOff}):Play()
			tws:Create(o.Visual, A.twiGeneric, {Size = A.sizeOff, GroupTransparency = 1}):Play()
			tws:Create(o.Visual.Container.UIStroke, A.twiGeneric, {Thickness = 0}):Play()
			return -A.twiGeneric.Time
		end,
		Changed = function(o: Object)
			local stroke = o.Visual.Container.UIStroke
			stroke.Thickness = 0
			tws:Create(o.Visual.Container.UIStroke, A.twiExpo, {Thickness = 2}):Play()
		end,
	},
	Warning = {
		Name = 'Warning',
		DefaultDuration = 5,
		DefaultPriority = 100,
		Sound = S[2],
		Init = function(o: Object)
			o.Size = A.sizeOff
			--o.Visual.Size = A.sizeOff
			o.Visual.GroupTransparency = 1
			local stroke = o.Visual.Container.UIStroke
			stroke.Thickness = 0
			stroke.Color = Color3.new(1, 1, 0)
			o.Visual.Position = UDim2.new(.5, 0, -5, 0)
			tws:Create(o, A.twiGeneric, {Size = A.sizeOn}):Play()
			tws:Create(o.Visual, A.twiGeneric, {Size = A.sizeOn, GroupTransparency = 0}):Play()
			tws:Create(stroke, A.twiGeneric, {Thickness = 2}):Play()
			tws:Create(stroke, A.twiFlicker, {Color = Color3.new(1, 1, 1), Transparency = 0}):Play()
			tws:Create(o.Visual.Container, A.twiFlicker, {BackgroundColor3 = Color3.new(1, 1, 1)}):Play()
			tws:Create(o.Visual, A.twiSpring, {Position = UDim2.fromScale(.5, .5)}):Play()
			return -A.twiGeneric.Time
		end,
		End = function(o: Object)
			tws:Create(o, A.twiGeneric, {Size = A.sizeOff}):Play()
			tws:Create(o.Visual, A.twiGeneric, {Size = A.sizeOff, GroupTransparency = 1}):Play()
			tws:Create(o.Visual.Container.UIStroke, A.twiGeneric, {Thickness = 0}):Play()
			return -A.twiGeneric.Time
		end,
		Changed = function(o: Object)
			local stroke = o.Visual.Container.UIStroke
			stroke.Thickness = 0
			tws:Create(o.Visual.Container.UIStroke, A.twiExpo, {Thickness = 2}):Play()
		end,
	},
	Error = {
		Name = 'Error',
		DefaultDuration = 10,
		DefaultPriority = 200,
		Sound = S[3],
		Init = function(o: Object)
			o.Size = A.sizeOff
			--o.Visual.Size = A.sizeOff
			o.Visual.GroupTransparency = 1
			local stroke = o.Visual.Container.UIStroke
			stroke.Thickness = 0
			stroke.Color = Color3.new(1, 0, 0)
			o.Visual.Position = UDim2.new(10, 0, .5, 0)
			tws:Create(o, A.twiGeneric, {Size = A.sizeOn}):Play()
			tws:Create(o.Visual, A.twiGeneric, {Size = A.sizeOn, GroupTransparency = 0}):Play()
			tws:Create(stroke, A.twiGeneric, {Thickness = 2}):Play()
			tws:Create(stroke, A.twiFlickerRapid, {Color = Color3.new(1, 1, 1), Transparency = 0}):Play()
			tws:Create(o.Visual, A.twiSpring, {Position = UDim2.fromScale(.5, .5)}):Play()
			return -A.twiGeneric.Time
		end,
		End = function(o: Object)
			tws:Create(o, A.twiGeneric, {Size = A.sizeOff}):Play()
			tws:Create(o.Visual, A.twiGeneric, {Size = A.sizeOff, GroupTransparency = 1}):Play()
			tws:Create(o.Visual.Container.UIStroke, A.twiGeneric, {Thickness = 0}):Play()
			return -A.twiGeneric.Time
		end,
		Changed = function(o: Object)
			local stroke = o.Visual.Container.UIStroke
			stroke.Thickness = 0
			tws:Create(o.Visual.Container.UIStroke, A.twiExpo, {Thickness = 2}):Play()
		end,
	},
	Success = {
		Name = 'Success',
		DefaultDuration = 5,
		DefaultPriority = 150,
		Sound = S[4],
		Init = function(o: Object)
			o.Size = A.sizeOff
			--o.Visual.Size = A.sizeOff
			o.Visual.GroupTransparency = 1
			local stroke = o.Visual.Container.UIStroke
			stroke.Thickness = 0
			stroke.Color = Color3.new(0, 1, 0)
			o.Visual.Position = UDim2.new(.5, 0, -5, 0)
			tws:Create(o, A.twiGeneric, {Size = A.sizeOn}):Play()
			tws:Create(o.Visual, A.twiGeneric, {Size = A.sizeOn, GroupTransparency = 0}):Play()
			tws:Create(stroke, A.twiGeneric, {Thickness = 2}):Play()
			tws:Create(stroke, A.twiFlickerSoft, {Color = Color3.new(1, 1, 1), Transparency = 0}):Play()
			tws:Create(o.Visual.Container, A.twiFlickerSoft, {BackgroundColor3 = Color3.new(0, 1, 0)}):Play()
			tws:Create(o.Visual, A.twiSpring, {Position = UDim2.fromScale(.5, .5)}):Play()
			return -A.twiGeneric.Time
		end,
		End = function(o: Object)
			tws:Create(o, A.twiGeneric, {Size = A.sizeOff}):Play()
			tws:Create(o.Visual, A.twiGeneric, {Size = A.sizeOff, GroupTransparency = 1}):Play()
			tws:Create(o.Visual.Container.UIStroke, A.twiGeneric, {Thickness = 0}):Play()
			return -A.twiGeneric.Time
		end,
		Changed = function(o: Object)
			local stroke = o.Visual.Container.UIStroke
			stroke.Thickness = 0
			tws:Create(o.Visual.Container.UIStroke, A.twiExpo, {Thickness = 2}):Play()
		end,
	},
}
for name, entry in messageTypes do --runtime sanity check
	assert(name==entry.Name, `mismatched message type name; index is {name} but entry is {entry.Name}`)
end

local module = {
	PreloadMessageObjectAsync = preloadMessageObjectAsync,
	Types = messageTypes,
	msgEx = msgEx,
	txtEx = txtEx,
	imgEx = imgEx,
}

cpr:PreloadAsync(S)
return module
