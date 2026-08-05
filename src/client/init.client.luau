local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AudioController = require(script.Audio.AudioController)
local GameplayCamera = require(script.Camera.GameplayCamera)
local InputManager = require(script.Input.InputManager)
local HUDController = require(script.UI.HUDController)
local SettingsController = require(script.UI.SettingsController)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MovementEngine = require(Shared.Movement.MovementEngine)

InputManager:Init()
GameplayCamera:Init()
MovementEngine:Init(InputManager, GameplayCamera)
AudioController:Init()
HUDController:Init()
SettingsController:Init(InputManager, GameplayCamera)
