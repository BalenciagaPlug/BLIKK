local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MultiplayerConfig = require(ReplicatedStorage.Shared.Multiplayer.MultiplayerConfig)

local Coordinator = {}
local player = Players.LocalPlayer
local generation = 0
local boundCharacter = nil
local isInitialised = false
local readinessConnections = {}

local REQUIRED = {
	"BLIKK_ClientMeleeReady",
	"BLIKK_ClientPrimary1Ready",
	"BLIKK_ClientPrimary2Ready",
}

local function clearReadinessConnections()
	for _, connection in readinessConnections do connection:Disconnect() end
	table.clear(readinessConnections)
end

local function bindCharacter(character)
	generation += 1
	local bindGeneration = generation
	clearReadinessConnections()
	boundCharacter = character
	character:SetAttribute("BLIKK_ClientWeaponReady", nil)
	local function tryReady()
		if bindGeneration ~= generation or player.Character ~= character then return end
		for _, attribute in REQUIRED do
			if character:GetAttribute(attribute) ~= true then return end
		end
		character:SetAttribute("BLIKK_ClientWeaponReady", true)
		clearReadinessConnections()
	end
	for _, attribute in REQUIRED do
		table.insert(
			readinessConnections,
			character:GetAttributeChangedSignal(attribute):Connect(tryReady)
		)
	end
	tryReady()
	task.delay(math.max(
		1,
		MultiplayerConfig.RequiredClientReadinessTimeoutSeconds - 2
	), function()
		if bindGeneration == generation and player.Character == character then
			if character:GetAttribute("BLIKK_ClientWeaponReady") == true then return end
			local missing = {}
			for _, attribute in REQUIRED do
				if character:GetAttribute(attribute) ~= true then table.insert(missing, attribute) end
			end
			warn("[BLIKK WEAPONS] Presentation dependencies remain incomplete; continuing to observe.\nMissing: "
				.. table.concat(missing, ", "))
		end
	end)
end

function Coordinator:Init()
	if isInitialised then return end
	isInitialised = true
	player.CharacterAdded:Connect(bindCharacter)
	player.CharacterRemoving:Connect(function(character)
		if character ~= boundCharacter then return end
		generation += 1
		clearReadinessConnections()
		boundCharacter = nil
	end)
	if player.Character then bindCharacter(player.Character) end
end

return Coordinator
