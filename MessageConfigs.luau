--!strict

--[[
	This ModuleScript defines all of the visual parameters of PGNS.
	It also defines the types used by both APIs.
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
	local vis = obj:WaitForChild('Visual')
	vis:WaitForChild('UICorner')
	vis:WaitForChild('UIListLayout')
	vis:WaitForChild('UIPadding')
	vis:WaitForChild('UIStroke')
end

--[[
	Generates the ASCII-style visual of a loading bar used in the notification messages.
	uses native codegen to preserve performance.
]]
@native local function generateLoadingBarText(percent: number): string
	local index: number = percent//4
	return string.sub('IIIIIIIIIIIIIIIIIIIIIIIII', 1, index)
		..'<font color="#888">'
		..string.sub('IIIIIIIIIIIIIIIIIIIIIIIII', index+1)
		..'</font>'
end

local A = { --for caching purposes; use this however you like with no standards
	clr_white = Color3.new(1, 1, 1),
	clr_black = Color3.new(0, 0, 0),
	clr_r = Color3.new(1, 0, 0),
	clr_g = Color3.new(0, 1, 0),
	clr_y = Color3.new(1, 1, 0),
	
	sizeOff = UDim2.new(0, 10, 0, 0),
	sizeOnAbs = msgEx.Size,
	sizeOnScale = UDim2.new(0, 10, 1, 0),
	
	twiLong = TweenInfo.new(.5, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut),
	twiLongDelayed = TweenInfo.new(.25, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut, 0, false, .25),
	
	twiGeneric = TweenInfo.new(.25, Enum.EasingStyle.Circular, Enum.EasingDirection.InOut),
	twiGenericFast = TweenInfo.new(.1, Enum.EasingStyle.Circular, Enum.EasingDirection.InOut),
	twiGenericDelayed = TweenInfo.new(.15, Enum.EasingStyle.Circular, Enum.EasingDirection.InOut, 0, false, 0.1),
	twiExpo = TweenInfo.new(.25, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),
	twiSpring = TweenInfo.new(0.6, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out),
	
	twiFlicker = TweenInfo.new(.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 2, true),
	twiFlickerRapid = TweenInfo.new(.05, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 4, true),
	twiFlickerSoft = TweenInfo.new(.25, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 1, true),
}

local S: {Sound} = {
	[0] = script:WaitForChild('sound/changed'),
	script:WaitForChild('sound/default'),
	script:WaitForChild('sound/warning'),
	script:WaitForChild('sound/error'),
	script:WaitForChild('sound/success')
}

local generics = {
	End = function(o: Object)
		tws:Create(o, A.twiLong, {Size = A.sizeOff}):Play()
		tws:Create(o.Visual, A.twiGeneric, {GroupTransparency = 1}):Play()
		tws:Create(o.Visual.UIStroke, A.twiGenericFast, {Transparency = 1}):Play()
		o.Visual.GroupColor3 = A.clr_black
		return -A.twiLong.Time
	end,
	Changed = function(o: Object)
		S[0]:Play()
		
		local vis = o.Visual
		vis.GroupColor3 = A.clr_black
		tws:Create(vis, A.twiGenericFast, {GroupColor3 = A.clr_white}):Play()
		
		local stroke = o.Visual.UIStroke
		if not stroke.Enabled then return end
		stroke.Transparency = 0
		tws:Create(stroke, A.twiExpo, {Transparency = 0.5}):Play()
	end,
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
			local vis = o.Visual
			local stroke = vis.UIStroke
			
			o.Size = A.sizeOff
			--o.Visual.Size = A.sizeOff
			vis.GroupTransparency = 1	
			stroke.Thickness = 0
			tws:Create(o, A.twiGenericFast, {Size = A.sizeOnAbs}):Play()
			tws:Create(vis, A.twiGeneric, {Size = A.sizeOnScale, GroupTransparency = 0}):Play()
			tws:Create(stroke, A.twiGenericDelayed, {Thickness = 2}):Play()
			return -A.twiGeneric.Time
		end,
		End = generics.End,
		Changed = generics.Changed,
	},
	Hint = {
		Name = 'Hint',
		DefaultDuration = 5,
		DefaultPriority = 50,
		Init = function(o: Object)
			local vis = o.Visual
			
			o.Size = A.sizeOff
			o.UIPadding.PaddingTop = UDim.new(0, 2)
			o.UIPadding.PaddingBottom = UDim.new(0, 2)
			vis.UIStroke.Enabled = false
			vis.GroupTransparency = 1
			vis.GroupColor3 = A.clr_black
			vis.BackgroundTransparency = 1
			tws:Create(o, A.twiGeneric, {Size = A.sizeOnAbs}):Play()
			tws:Create(vis, A.twiGeneric, {GroupTransparency = 0, BackgroundTransparency = .5}):Play()
			tws:Create(vis, A.twiGenericDelayed, {GroupColor3 = A.clr_white}):Play()
			return -A.twiGeneric.Time
		end,
		End = generics.End,
		Changed = generics.Changed,
	},
	Warning = {
		Name = 'Warning',
		DefaultDuration = 5,
		DefaultPriority = 100,
		Sound = S[2],
		Init = function(o: Object)
			local vis = o.Visual
			local stroke = vis.UIStroke
			
			o.Size = A.sizeOff
			--o.Visual.Size = A.sizeOff
			vis.GroupTransparency = 1		
			stroke.Thickness = 2
			stroke.Transparency = 0.5
			stroke.Color = A.clr_y
			vis.Position = UDim2.new(.5, 0, -5, 0)
			tws:Create(o, A.twiGeneric, {Size = A.sizeOnAbs}):Play()
			tws:Create(vis, A.twiGeneric, {Size = A.sizeOnScale, GroupTransparency = 0}):Play()
			--tws:Create(stroke, A.twiGenericDelayed, {Thickness = 2, Transparency = 0.5}):Play()
			tws:Create(stroke, A.twiFlicker, {Color = A.clr_white, Thickness = 8, Transparency = 0.75}):Play()
			tws:Create(vis, A.twiFlicker, {GroupColor3 = A.clr_black}):Play()
			tws:Create(vis, A.twiSpring, {Position = UDim2.fromScale(.5, .5)}):Play()
			return -A.twiGeneric.Time
		end,
		End = generics.End,
		Changed = generics.Changed,
	},
	Error = {
		Name = 'Error',
		DefaultDuration = 10,
		DefaultPriority = 200,
		Sound = S[3],
		Init = function(o: Object)
			local vis = o.Visual
			local stroke = vis.UIStroke
			
			o.Size = A.sizeOff
			--o.Visual.Size = A.sizeOff
			vis.GroupTransparency = 1
			stroke.Thickness = 0
			stroke.Color = A.clr_r
			vis.Position = UDim2.new(10, 0, .5, 0)
			tws:Create(o, A.twiGeneric, {Size = A.sizeOnAbs}):Play()
			tws:Create(vis, A.twiGeneric, {Size = A.sizeOnScale, GroupTransparency = 0}):Play()
			tws:Create(stroke, A.twiGenericDelayed, {Thickness = 2}):Play()
			tws:Create(stroke, A.twiFlickerRapid, {Color = A.clr_white, Transparency = 0}):Play()
			tws:Create(vis, A.twiFlickerRapid, {GroupColor3 = A.clr_r}):Play()
			tws:Create(vis, A.twiSpring, {Position = UDim2.fromScale(.5, .5)}):Play()
			return -A.twiGeneric.Time
		end,
		End = generics.End,
		Changed = generics.Changed,
	},
	Success = {
		Name = 'Success',
		DefaultDuration = 5,
		DefaultPriority = 150,
		Sound = S[4],
		Init = function(o: Object)
			local vis = o.Visual
			local stroke = vis.UIStroke
			
			o.Size = A.sizeOff
			--o.Visual.Size = A.sizeOff
			vis.GroupTransparency = 1
			stroke.Thickness = 0
			stroke.Color = A.clr_g
			vis.Position = UDim2.new(.5, 0, -5, 0)
			tws:Create(o, A.twiGeneric, {Size = A.sizeOnAbs}):Play()
			tws:Create(vis, A.twiGeneric, {Size = A.sizeOnScale, GroupTransparency = 0}):Play()
			tws:Create(stroke, A.twiGenericDelayed, {Thickness = 2}):Play()
			tws:Create(stroke, A.twiFlickerSoft, {Color = A.clr_g, Transparency = 1}):Play()
			tws:Create(vis, A.twiFlickerSoft, {BackgroundColor3 = A.clr_g}):Play()
			tws:Create(vis, A.twiSpring, {Position = UDim2.fromScale(.5, .5)}):Play()
			return -A.twiGeneric.Time
		end,
		End = generics.End,
		Changed = generics.Changed,
	},
}
for name, entry in messageTypes do --runtime sanity check
	assert(name==entry.Name, `mismatched message type name; index is {name} but entry is {entry.Name}`)
end

local module = {
	PreloadMessageObjectAsync = preloadMessageObjectAsync,
	Types = messageTypes,
	GenerateLoadingBarText = generateLoadingBarText,
	msgEx = msgEx,
	txtEx = txtEx,
	imgEx = imgEx,
}

cpr:PreloadAsync(S)
return module
