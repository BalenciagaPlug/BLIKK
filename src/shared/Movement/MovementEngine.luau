local Players = game:GetService("Players")

local MovementConfig = require(script.Parent.MovementConfig)

local MovementEngine = {}

local isInitialised = false
local lastDirectionPress = {}
local lastDashTime = 0

local directionVectors = {
    Forward = Vector3.new(0, 0, -1),
    Backward = Vector3.new(0, 0, 1),
    Left = Vector3.new(-1, 0, 0),
    Right = Vector3.new(1, 0, 0),
}

local function getCharacterParts()
    local player = Players.LocalPlayer
    local character = player.Character or player.CharacterAdded:Wait()

    local humanoid = character:WaitForChild("Humanoid")
    local rootPart = character:WaitForChild("HumanoidRootPart")

    return humanoid, rootPart
end

local function getWorldDirection(rootPart, action)
    local localDirection = directionVectors[action]

    if not localDirection then
        return nil
    end

    local worldDirection = rootPart.CFrame:VectorToWorldSpace(localDirection)
    return Vector3.new(worldDirection.X, 0, worldDirection.Z).Unit
end

function MovementEngine:Dash(action)
    local now = os.clock()

    if now - lastDashTime < MovementConfig.Dash.Cooldown then
        return
    end

    local humanoid, rootPart = getCharacterParts()

    if humanoid.Health <= 0 then
        return
    end

    local direction = getWorldDirection(rootPart, action)

    if not direction then
        return
    end

    lastDashTime = now

    rootPart.AssemblyLinearVelocity = Vector3.new(
        direction.X * MovementConfig.Dash.Speed,
        rootPart.AssemblyLinearVelocity.Y,
        direction.Z * MovementConfig.Dash.Speed
    )

    print("[BLIKK] Dash:", action)
end

function MovementEngine:HandleAction(action)
    local now = os.clock()

    if not directionVectors[action] then
        return
    end

    local previousPress = lastDirectionPress[action]
    lastDirectionPress[action] = now

    if previousPress and now - previousPress <= MovementConfig.Dash.DoubleTapWindow then
        self:Dash(action)
    end
end

function MovementEngine:Init(inputManager)
    if isInitialised then
        return
    end

    isInitialised = true

    inputManager.ActionBegan.Event:Connect(function(action)
        self:HandleAction(action)
    end)

    print("[BLIKK] Movement Engine Initialised")
end

return MovementEngine