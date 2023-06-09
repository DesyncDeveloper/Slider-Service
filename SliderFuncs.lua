local SliderFuncs = {}

local Switch = loadstring(game:HttpGet(('https://raw.githubusercontent.com/DesyncDeveloper/Slider-Service/main/Switch.lua')))()

local Clamp = math.clamp
local Floor = math.floor
local Min = math.min
local Max = math.max
local Round = math.round
local Abs = math.abs

function SliderFuncs.snapToScale(val: number, step: number): number
	return Clamp(Round(val / step) * step, 0, 1)
end

function lerp(start: number, finish: number, percent: number): number
	return (1 - percent) * start + percent * finish
end

function map(value: number, start: number, stop: number, newStart: number, newEnd: number, constrain: boolean): number
	local newVal = lerp(newStart, newEnd, SliderFuncs.getAlphaBetween(start, stop, value))
	if not constrain then
		return newVal
	end

	if newStart < newEnd then
		newStart, newEnd = newEnd, newStart
	end

	return Max(Min(newVal, newStart), newEnd)
end

function SliderFuncs.getNewPosition(self): UDim2
	local absoluteSize = self._data.Button.AbsoluteSize[self._config.Axis]
	local holderSize = self._holder.AbsoluteSize[self._config.Axis]

	local anchorPoint = self._data.Button.AnchorPoint[self._config.Axis]

	local paddingScale = (self._config.Padding / holderSize)

	local minScale = (
		(anchorPoint * absoluteSize) / holderSize +
			paddingScale
	)

	local decrement = ((2 * absoluteSize) * anchorPoint) - absoluteSize
	local maxScale = (1 - minScale) + (decrement / holderSize)

	local newPercent = map(self._data._percent, 0, 1, minScale, maxScale, true)

	return Switch(self._config.Axis) {
		["X"] = UDim2.fromScale(newPercent, self._data.Button.Position.Y.Scale),
		["Y"] = UDim2.fromScale(self._data.Button.Position.X.Scale, newPercent)
	}
end

function SliderFuncs.getScaleIncrement(self)
	return 1 / ((self._config.SliderData.End - self._config.SliderData.Start) / self._config.SliderData.Increment)
end

function SliderFuncs.getAlphaBetween(a: number, b: number, c: number): number
	return (c - a) / (b - a)
end

function SliderFuncs.getNewValue(self)
	local newValue = lerp(self._config.SliderData.Start, self._config.SliderData.End, self._data._percent)
	local incrementScale = (1 / self._config.SliderData.Increment)

	newValue = Floor(newValue * incrementScale) / incrementScale
	return newValue
end

return SliderFuncs
