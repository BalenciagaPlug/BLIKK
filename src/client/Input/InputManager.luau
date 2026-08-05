local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ActionBuffer = require(Shared.Input.ActionBuffer)

local InputManager = {}

InputManager.ActionBegan = Instance.new("BindableEvent")
InputManager.GameplayEnabledChanged = Instance.new("BindableEvent")

local isInitialised = false
local isGameplayEnabled = true

local keyboardActions = {
	[Enum.KeyCode.W] = "Forward",
	[Enum.KeyCode.A] = "Left",
	[Enum.KeyCode.S] = "Backward",
	[Enum.KeyCode.D] = "Right",

	[Enum.KeyCode.Space] = "Jump",
	[Enum.KeyCode.Q] = "Weapon1",
	[Enum.KeyCode.E] = "Weapon2",
	[Enum.KeyCode.R] = "Reload",
}

local mouseActions = {
	[Enum.UserInputType.MouseButton1] = "Primary",
	[Enum.UserInputType.MouseButton2] = "Secondary",
	[Enum.UserInputType.MouseButton3] = "MiddleMouse",
}

local function getAction(input)
	return keyboardActions[input.KeyCode] or mouseActions[input.UserInputType]
end

function InputManager:Init()
	if isInitialised then
		return
	end

	isInitialised = true

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed or not isGameplayEnabled then
			return
		end

		local action = getAction(input)

		if not action then
			return
		end

		ActionBuffer:Push(action)
		self.ActionBegan:Fire(action, os.clock())
	end)
end

function InputManager:SetGameplayEnabled(isEnabled)
	if isGameplayEnabled == isEnabled then
		return
	end

	isGameplayEnabled = isEnabled

	if not isEnabled then
		ActionBuffer:Clear()
	end

	self.GameplayEnabledChanged:Fire(isEnabled)
end

return InputManager
