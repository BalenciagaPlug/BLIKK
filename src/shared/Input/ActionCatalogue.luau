local ActionCatalogue = {}

ActionCatalogue.Ordered = {
	{ Id = "Forward", Name = "Move Forward", Group = "Movement", Primary = "KeyCode.W" },
	{ Id = "Backward", Name = "Move Backward", Group = "Movement", Primary = "KeyCode.S" },
	{ Id = "Left", Name = "Move Left", Group = "Movement", Primary = "KeyCode.A" },
	{ Id = "Right", Name = "Move Right", Group = "Movement", Primary = "KeyCode.D" },
	{ Id = "Jump", Name = "Jump", Group = "Movement", Primary = "KeyCode.Space" },
	{ Id = "Dash", Name = "Dash", Group = "Movement" },
	{ Id = "Primary", Name = "Primary Fire", Group = "Combat", Primary = "MouseButton1" },
	{ Id = "Secondary", Name = "Alternate Fire", Group = "Combat", Primary = "MouseButton2" },
	{ Id = "Slash", Name = "Slash / Melee Attack", Group = "Combat", Primary = "MouseButton3" },
	{ Id = "Block", Name = "Block", Group = "Combat", Primary = "KeyCode.LeftShift" },
	{ Id = "Reload", Name = "Reload", Group = "Combat", Primary = "KeyCode.R" },
	{ Id = "EquipMelee", Name = "Equip Melee", Group = "Equipment", Primary = "KeyCode.One" },
	{ Id = "EquipWeapon1", Name = "Equip Weapon 1", Group = "Equipment", Primary = "KeyCode.Q" },
	{ Id = "EquipWeapon2", Name = "Equip Weapon 2", Group = "Equipment", Primary = "KeyCode.E" },
	{ Id = "EquipTactical1", Name = "Equip Vital Patch", Group = "Equipment", Primary = "KeyCode.Four" },
	{ Id = "EquipTactical2", Name = "Equip Aegis Patch", Group = "Equipment", Primary = "KeyCode.Five" },
	{ Id = "UseRecovery3", Name = "Equip Vital Amp", Group = "Equipment", Primary = "KeyCode.Six" },
	{ Id = "UseRecovery4", Name = "Equip Aegis Amp", Group = "Equipment", Primary = "KeyCode.Seven" },
	{ Id = "NextWeapon", Name = "Next Weapon", Group = "Equipment", Primary = "MouseWheelUp" },
	{ Id = "PreviousWeapon", Name = "Previous Weapon", Group = "Equipment", Primary = "MouseWheelDown" },
	{
		Id = "DeveloperFreeLook",
		Name = "Developer Free-Look",
		Group = "Interface",
		Primary = "KeyCode.LeftControl",
		Secondary = "KeyCode.RightControl",
		Protected = true,
	},
	{ Id = "Settings", Name = "Settings", Group = "Interface", Primary = "KeyCode.M", Protected = true },
	{ Id = "Scoreboard", Name = "Scoreboard", Group = "Interface", Primary = "KeyCode.Tab", Protected = true },
	{ Id = "ReleaseCursor", Name = "Release Cursor", Group = "Interface", Primary = "KeyCode.LeftAlt", Protected = true },
	{ Id = "Chat", Name = "Chat", Group = "Interface", Protected = true },
}

ActionCatalogue.ById = {}

for _, action in ActionCatalogue.Ordered do
	ActionCatalogue.ById[action.Id] = action
end

local displayOverrides = {
	MouseButton1 = "LMB",
	MouseButton2 = "RMB",
	MouseButton3 = "MMB",
	MouseWheelUp = "WHEEL UP",
	MouseWheelDown = "WHEEL DOWN",
}

function ActionCatalogue.GetDisplayName(token)
	if not token then
		return "UNBOUND"
	end

	if displayOverrides[token] then
		return displayOverrides[token]
	end

	return token:gsub("^KeyCode%.", ""):gsub("Button", "PAD "):upper()
end

function ActionCatalogue.TokenFromInput(input)
	if input.KeyCode == Enum.KeyCode.Escape then
		return nil
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		return "MouseButton1"
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
		return "MouseButton2"
	elseif input.UserInputType == Enum.UserInputType.MouseButton3 then
		return "MouseButton3"
	elseif input.KeyCode ~= Enum.KeyCode.Unknown then
		return "KeyCode." .. input.KeyCode.Name
	end

	return nil
end

return ActionCatalogue
