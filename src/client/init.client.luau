local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InputManager = require(script.Input.InputManager)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MovementEngine = require(Shared.Movement.MovementEngine)

InputManager:Init()
MovementEngine:Init(InputManager)

print("[BLIKK] Client started")