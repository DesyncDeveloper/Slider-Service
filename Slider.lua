-----------------------------------------------------------------------------------------
----------------------------- Slider Module -----------------------------
-- [Author]: Krypt
-- [Description]: Creates a slider based on a start, end and incremental value. Allows ...
-- ... sliders to be moved, tracked/untracked, reset, and have specific properties such ...
-- ... as their current value and increment to be overriden.

-- [Version]: 2.0.1
-- [Created]: 22/12/2021
-- [Updated]: 15/08/2022
-- [Dev Forum Link]: https://devforum.roblox.com/t/1597785/
-----------------------------------------------------------------------------------------

--!nonstrict
local Slider = {Sliders = {}}

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

assert(RunService:IsClient(), "Slider module can only be used on the Client!")

local Clamp = math.clamp
local Floor = math.floor
local Min = math.min
local Max = math.max
local Round = math.round
local Abs = math.abs

local Lower = string.lower
local Upper = string.upper
local Sub = string.sub
local Format = string.format

local Signal = loadstring(game:HttpGet(('https://raw.githubusercontent.com/DesyncDeveloper/Slider-Service/main/Signal.lua')))()
local Switch = loadstring(game:HttpGet(('https://raw.githubusercontent.com/DesyncDeveloper/Slider-Service/main/Switch.lua')))()
local VectorFuncs = loadstring(game:HttpGet(('https://raw.githubusercontent.com/DesyncDeveloper/Slider-Service/main/VectorFuncs.lua')))()
local SliderFuncs = loadstring(game:HttpGet(('https://raw.githubusercontent.com/DesyncDeveloper/Slider-Service/main/SliderFuncs.lua')))()

Slider.__index = function(object, indexed)
	local deprecated = {
		{".OnChange", ".Changed", rawget(object, "Changed")}
	}

	for _, tbl in ipairs(deprecated) do
		local deprecatedStr = Sub(tbl[1], 2)

		if deprecatedStr == indexed then
			warn(Format("%s is deprecated, please use %s instead", tbl[1], tbl[2]))
			return tbl[3]	
		end
	end

	return Slider[indexed]
end

export type configDictionary = {
	SliderData: {Start: number, End: number, Increment: number, DefaultValue: number | nil},
	MoveType: "Tween" | "Instant" | nil,
	MoveInfo: TweenInfo | nil,
	Axis: string | nil,
	Padding: number | nil
}

function Slider.new(holder: GuiBase2d, config: configDictionary)
	assert(pcall(function()
		return holder.AbsoluteSize, holder.AbsolutePosition
	end), "Holder argument does not have an AbsoluteSize/AbsolutePosition")
	
	local duplicate = false
	for _, slider in ipairs(Slider.Sliders) do
		if slider._holder == holder then
			duplicate = true
			break
		end
	end
	
	assert(not duplicate, "Cannot set two sliders with same frame!")
	assert(config.SliderData.Increment ~= nil, "Failed to find Increment in SliderData table")
	assert(config.SliderData.Start ~= nil, "Failed to find Start in SliderData table")
	assert(config.SliderData.End ~= nil, "Failed to find End in SliderData table")
	assert(config.SliderData.Increment > 0, "SliderData.Increment must be greater than 0")
	assert(config.SliderData.End > config.SliderData.Start, Format("Slider end value must be greater than its start value! (%.1f <= %.1f)", config.SliderData.End, config.SliderData.Start))
	
	local self = setmetatable({}, Slider)
	self._holder = holder
	self._data = {
		Button = nil,
		HolderButton = nil,
		
		UiType = nil,
		HolderPart = nil,
		SurfaceGui = nil,
		
		CLICK_OVERRIDE = false,
		_mainConnection = nil,
		_miscConnections = {},
		_inputPos = nil,
		
		_percent = 0,
		_value = 0,
		_scaleIncrement = 0,
		_currentTween = nil
	}
	
	self._config = config
	self._config.Axis = Upper(config.Axis or "X")
	self._config.Padding = config.Padding or 5
	self._config.MoveInfo = config.MoveInfo or TweenInfo.new(0.2)
	self._config.MoveType = config.MoveType or "Tween"
	self.IsHeld = false
	
	local sliderBtn = holder:FindFirstChild("Slider")
	assert(sliderBtn ~= nil, "Failed to find slider button.")
	assert(sliderBtn:IsA("GuiButton"), "Slider is not a GuiButton")
	
	self._data.Button = sliderBtn
	
	-- Holder button --
	local holderClickButton = Instance.new("TextButton")
	holderClickButton.BackgroundTransparency = 1
	holderClickButton.Text = ""
	holderClickButton.Name = "HolderClickButton"
	holderClickButton.Size = UDim2.fromScale(1, 1)
	holderClickButton.ZIndex = -1
	holderClickButton.Parent = self._holder
	
	self._data.HolderButton = holderClickButton
	
	-- Finalise --
	
	self._data.UiType = if 
		holder:FindFirstAncestorOfClass("ScreenGui") then "ScreenGui" 
		elseif holder:FindFirstAncestorOfClass("SurfaceGui") then "SurfaceGui"
		else nil

	self._data.HolderPart = Switch(self._data.UiType) {
		["SurfaceGui"] = holder:FindFirstAncestorWhichIsA("BasePart"),
		["ScreenGui"] = nil
	}
	self._data.SurfaceGui = Switch(self._data.UiType) {
		["SurfaceGui"] = holder:FindFirstAncestorWhichIsA("SurfaceGui"),
		["ScreenGui"] = nil
	}
	
	self._data._percent = 0
	if config.SliderData.DefaultValue then
		config.SliderData.DefaultValue = Clamp(config.SliderData.DefaultValue, config.SliderData.Start, config.SliderData.End)
		self._data._percent = SliderFuncs.getAlphaBetween(config.SliderData.Start, config.SliderData.End, config.SliderData.DefaultValue) 
	end
	
	self._data._percent = Clamp(self._data._percent, 0, 1)

	self._data._value = SliderFuncs.getNewValue(self)
	self._data._scaleIncrement = SliderFuncs.getScaleIncrement(self)
	
	self.Changed = Signal.new()
	self.Dragged = Signal.new()
	self.Released = Signal.new()
	
	self:Move()
	table.insert(Slider.Sliders, self)
	
	return self
end

function Slider:Track()
	for _, connection in ipairs(self._data._miscConnections) do
		connection:Disconnect()
	end

	table.insert(self._data._miscConnections, self._data.Button.MouseButton1Down:Connect(function()
		self.IsHeld = true
	end))

	table.insert(self._data._miscConnections, self._data.Button.MouseButton1Up:Connect(function()
		if self.IsHeld then
			self.Released:Fire(self._data._value)
		end
		self.IsHeld = false
	end))

	table.insert(self._data._miscConnections, self._data.HolderButton.Activated:Connect(function(inputObject: InputObject)
		if inputObject.UserInputType == Enum.UserInputType.MouseButton1 or inputObject.UserInputType == Enum.UserInputType.Touch then
			self._data._inputPos = inputObject.Position
			self._data.CLICK_OVERRIDE = true
			self:Update()
			self._data.CLICK_OVERRIDE = false
		end
	end))

	if self.Changed then
		self.Changed:Fire(self._data._value)
	end

	if self._data._mainConnection then
		self._data._mainConnection:Disconnect()
	end

	self._data._mainConnection = UserInputService.InputChanged:Connect(function(inputObject, gameProcessed)
		if inputObject.UserInputType == Enum.UserInputType.MouseMovement or inputObject.UserInputType == Enum.UserInputType.Touch then
			self._data._inputPos = inputObject.Position
			self:Update()
		end
	end)
end

function Slider:Update()
	if (self.IsHeld and not self._data.CLICK_OVERRIDE) and self._data._inputPos then
		local mousePos = Switch(self._data.UiType) {
			["ScreenGui"] = self._data._inputPos[self._config.Axis],

			["SurfaceGui"] = function()
				local rayParams = RaycastParams.new()
				rayParams.FilterType = Enum.RaycastFilterType.Whitelist
				rayParams.FilterDescendantsInstances = {self._data.HolderPart}

				local unitRay = workspace.CurrentCamera:ScreenPointToRay(self._data._inputPos.X, self._data._inputPos.Y)
				local hitResult = workspace:Raycast(unitRay.Origin, unitRay.Direction * 500, rayParams)

				if hitResult then
					local hitPart = hitResult.Instance
					local hitPos = hitResult.Position
					local hitNormal = hitResult.Normal

					if VectorFuncs.normalVectorToFace(hitPart, hitNormal) ~= self._data.SurfaceGui.Face then
						return
					end

					local hitCF = CFrame.new(hitPos, hitPos + hitNormal)

					local topLeftCorners = VectorFuncs.getTopLeftCorners(hitPart)
					local topLeftCFrame = topLeftCorners[self._data.SurfaceGui.Face]

					local hitOffset = topLeftCFrame:ToObjectSpace(hitCF)
					local mappedOffset = VectorFuncs.mapOffsetToFace(hitOffset, self._config.Axis, self._data.SurfaceGui.Face)

					local relativePos = Vector2.new(
						Abs(mappedOffset.X) * self._data.SurfaceGui.PixelsPerStud, 
						Abs(mappedOffset.Y) * self._data.SurfaceGui.PixelsPerStud
					)

					return relativePos[self._config.Axis]
				end
			end
		}

		if mousePos then
			local sliderSize = self._holder.AbsoluteSize[self._config.Axis]
			local sliderPos = self._holder.AbsolutePosition[self._config.Axis]
			local newPos = SliderFuncs.snapToScale((mousePos - sliderPos) / sliderSize, self._data._scaleIncrement)

			local percent = Clamp(newPos, 0, 1)

			self._data._percent = percent
			self.Dragged:Fire(self._data._value)
			self:Move()
		end
	end
end

function Slider:Untrack()
	for _, connection in ipairs(self._data._miscConnections) do
		connection:Disconnect()
	end
	if self._data._mainConnection then
		self._data._mainConnection:Disconnect()
	end
	self.IsHeld = false
end

function Slider:Reset()
	for _, connection in ipairs(self._data._miscConnections) do
		connection:Disconnect()
	end
	if self._data._mainConnection then
		self._data._mainConnection:Disconnect()
	end

	self.IsHeld = false

	self._data._percent = 0
	if self._config.SliderData.DefaultValue then 
		self._data._percent = SliderFuncs.getAlphaBetween(self._config.SliderData.Start, self._config.SliderData.End, self._config.SliderData.DefaultValue)
	end
	self._data._percent = Clamp(self._data._percent, 0, 1)
	self:Move()
end

function Slider:OverrideValue(newValue: number)
	self.IsHeld = false
	self._data._percent = SliderFuncs.getAlphaBetween(self._config.SliderData.Start, self._config.SliderData.End, newValue)
	self._data._percent = Clamp(self._data._percent, 0, 1)
	self._data._percent = SliderFuncs.snapToScale(self._data._percent, self._data._scaleIncrement)
	self:Move()
end

function Slider:Move()
	self._data._value = SliderFuncs.getNewValue(self)

	Switch(self._config.MoveType) {
		[{"Tween", nil}] = function()
			if self._data._currentTween then
				self._data._currentTween:Cancel()
			end
			self._data._currentTween = TweenService:Create(self._data.Button, self._config.MoveInfo, {
				Position = SliderFuncs.getNewPosition(self)
			})
			self._data._currentTween:Play()
		end,
		
		["Instant"] = function()
			self._data.Button.Position = SliderFuncs.getNewPosition(self)
		end,
		
		["Default"] = function()
			print("Uh")
		end,
	}
	self.Changed:Fire(self._data._value)
end

function Slider:OverrideIncrement(newIncrement: number)
	self._config.SliderData.Increment = newIncrement
	self._data._scaleIncrement = SliderFuncs.getScaleIncrement(self)
	self._data._percent = Clamp(self._data._percent, 0, 1)
	self._data._percent = SliderFuncs.snapToScale(self._data._percent, self._data._scaleIncrement)
	self:Move()
end

function Slider:GetValue()
	return self._data._value
end

function Slider:GetIncrement()
	return self._data._increment
end

function Slider:Destroy()
	for _, connection in ipairs(self._data._miscConnections) do
		connection:Disconnect()
	end

	if self._data._mainConnection then
		self._data._mainConnection:Disconnect()
	end

	self.Changed:Destroy()
	self.Dragged:Destroy()
	self.Released:Destroy()

	for index = 1, #Slider.Sliders do
		if Slider.Sliders[index] == self then
			table.remove(Slider.Sliders, index)
		end
	end

	setmetatable(self, nil)
	self = nil
end

UserInputService.InputEnded:Connect(function(inputObject: InputObject, internallyProcessed: boolean)
	if inputObject.UserInputType == Enum.UserInputType.MouseButton1 or inputObject.UserInputType == Enum.UserInputType.Touch then
		for _, slider in ipairs(Slider.Sliders) do
			if slider.IsHeld then
				slider.Released:Fire(slider._data._value)
			end
			slider.IsHeld = false
		end
	end 
end)
	
return Slider
-----------------------------------------------------------------------------------------
