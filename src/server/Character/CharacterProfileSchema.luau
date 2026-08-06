local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProfileConfig = require(ReplicatedStorage.Shared.Character.ProfileConfig)
local BindingConfig = require(ReplicatedStorage.Shared.Input.BindingConfig)
local PlayerPreferencesConfig = require(ReplicatedStorage.Shared.Settings.PlayerPreferencesConfig)
local PersistenceConfig = require(script.Parent.CharacterPersistenceConfig)

local Schema = {}

local function newNormalizationDiagnostics(schemaVersion)
	return {
		MigratedFromSchemaVersion = if schemaVersion ~= PersistenceConfig.SchemaVersion
			then schemaVersion else nil,
		AddedDefaultSettingsDuringMigration = false,
		RemovedCharacterCount = 0,
		RemovedDuplicateIdCount = 0,
		RemovedDuplicateNameCount = 0,
		SelectionWasCleared = false,
		DefaultedBindingCount = 0,
		RemovedBindingCount = 0,
		AddedMissingPreferenceDefaultCount = 0,
		ReplacedInvalidPreferenceCount = 0,
		RemovedUnknownPreferenceCount = 0,
		MetadataWasNormalized = false,
	}
end

local appearanceFields = {
	Face = ProfileConfig.Faces,
	Hair = ProfileConfig.StarterHair,
	TopArmour = ProfileConfig.StarterTopArmour,
	Pants = ProfileConfig.StarterPants,
	Boots = ProfileConfig.StarterBoots,
}

local function contains(options, value)
	return type(value) == "string" and table.find(options, value) ~= nil
end

local function trim(value)
	return if type(value) == "string" then value:match("^%s*(.-)%s*$") else nil
end

local function validInteger(value, minimum, maximum)
	return type(value) == "number"
		and value == value
		and value > -math.huge
		and value < math.huge
		and value % 1 == 0
		and value >= minimum
		and (maximum == nil or value <= maximum)
end

local function validateName(value)
	local name = trim(value)
	if not name or name == "" then return nil, "ENTER A CHARACTER NAME" end
	if #name > ProfileConfig.MaximumNameLength then
		return nil, string.format("NAME MUST BE %d CHARACTERS OR FEWER", ProfileConfig.MaximumNameLength)
	end
	if not name:match(ProfileConfig.NamePattern) then
		return nil, "USE LETTERS, NUMBERS, SPACES, - OR _ ONLY"
	end
	return name
end

local function validateAppearance(source)
	if type(source) ~= "table" then return nil, "INVALID APPEARANCE" end
	local appearance = {}
	for field, options in appearanceFields do
		if not contains(options, source[field]) then
			return nil, "INVALID " .. field:upper()
		end
		appearance[field] = source[field]
	end
	return appearance
end

function Schema.NewAccount(now)
	return {
		SchemaVersion = PersistenceConfig.SchemaVersion,
		Characters = {},
		SelectedCharacterId = nil,
		Settings = {
			Bindings = BindingConfig.DefaultBindings(),
			Preferences = PlayerPreferencesConfig.DefaultPreferences(),
		},
		Metadata = {
			CreatedAtUnix = now,
			UpdatedAtUnix = now,
		},
	}
end

function Schema.ValidateDraft(source)
	if type(source) ~= "table" then return nil, "INVALID PROFILE REQUEST" end
	local fieldCount = 0
	for _ in source do
		fieldCount += 1
		if fieldCount > 8 then return nil, "PROFILE REQUEST IS TOO LARGE" end
	end
	local name, nameError = validateName(source.Name)
	if not name then return nil, nameError end
	if not contains(ProfileConfig.BodyTypes, source.BodyType) then return nil, "INVALID BODY TYPE" end
	local appearance, appearanceError = validateAppearance(source)
	if not appearance then return nil, appearanceError end
	return {
		Name = name,
		BodyType = source.BodyType,
		Appearance = appearance,
	}
end

function Schema.NewCharacter(account, draft, now)
	local id = nil
	for _ = 1, 5 do
		local candidate = HttpService:GenerateGUID(false)
		local hasCollision = false
		for _, character in account.Characters do
			if character.Id == candidate then hasCollision = true; break end
		end
		if not hasCollision then id = candidate; break end
	end
	if not id then return nil end
	return {
		Id = id,
		Name = draft.Name,
		BodyType = draft.BodyType,
		Level = ProfileConfig.DefaultLevel,
		LastPlayedUnix = 0,
		CreatedAtUnix = now,
		UpdatedAtUnix = now,
		Appearance = draft.Appearance,
	}
end

function Schema.ValidateStoredCharacter(source)
	if type(source) ~= "table" or type(source.Id) ~= "string" or #source.Id < 1 or #source.Id > 64 then
		return nil
	end
	local draft = Schema.ValidateDraft({
		Name = source.Name,
		BodyType = source.BodyType,
		Face = type(source.Appearance) == "table" and source.Appearance.Face or nil,
		Hair = type(source.Appearance) == "table" and source.Appearance.Hair or nil,
		TopArmour = type(source.Appearance) == "table" and source.Appearance.TopArmour or nil,
		Pants = type(source.Appearance) == "table" and source.Appearance.Pants or nil,
		Boots = type(source.Appearance) == "table" and source.Appearance.Boots or nil,
	})
	if not draft or not validInteger(source.Level, 1, 1000000)
		or not validInteger(source.LastPlayedUnix, 0, 9007199254740991)
	then return nil end
	if not validInteger(source.CreatedAtUnix, 0, 9007199254740991)
		or not validInteger(source.UpdatedAtUnix, 0, 9007199254740991)
	then return nil end
	return {
		Id = source.Id,
		Name = draft.Name,
		BodyType = draft.BodyType,
		Level = source.Level,
		LastPlayedUnix = source.LastPlayedUnix,
		CreatedAtUnix = source.CreatedAtUnix,
		UpdatedAtUnix = source.UpdatedAtUnix,
		Appearance = draft.Appearance,
	}
end

function Schema.NormalizeAccount(source)
	if type(source) ~= "table" or type(source.SchemaVersion) ~= "number" then
		return nil, nil, "FUNDAMENTALLY_MALFORMED_RECORD"
	end
	if source.SchemaVersion > PersistenceConfig.SchemaVersion then
		return nil, nil, "UNSUPPORTED_FUTURE_SCHEMA"
	end
	if source.SchemaVersion ~= 1 and source.SchemaVersion ~= PersistenceConfig.SchemaVersion then
		return nil, nil, "UNSUPPORTED_ACCOUNT_SCHEMA"
	end
	if type(source.Characters) ~= "table" or type(source.Metadata) ~= "table" then
		return nil, nil, "FUNDAMENTALLY_MALFORMED_RECORD"
	end
	if not validInteger(source.Metadata.CreatedAtUnix, 0, 9007199254740991)
		or not validInteger(source.Metadata.UpdatedAtUnix, 0, 9007199254740991)
	then
		return nil, nil, "MALFORMED_ACCOUNT_METADATA"
	end

	local diagnostics = newNormalizationDiagnostics(source.SchemaVersion)
	local account = Schema.NewAccount(source.Metadata.CreatedAtUnix)
	account.Metadata.UpdatedAtUnix = source.Metadata.UpdatedAtUnix
	local ids = {}
	local names = {}
	local sourceCount = 0
	for key in source.Characters do
		sourceCount += 1
		if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > ProfileConfig.MaximumProfiles then
			diagnostics.RemovedCharacterCount += 1
		end
		if sourceCount > ProfileConfig.MaximumProfiles + 32 then break end
	end
	for index = 1, ProfileConfig.MaximumProfiles do
		local candidate = source.Characters[index]
		if candidate == nil then continue end
		local character = Schema.ValidateStoredCharacter(candidate)
		local normalizedName = character and character.Name:lower() or nil
		if not character then
			diagnostics.RemovedCharacterCount += 1
		elseif ids[character.Id] then
			diagnostics.RemovedCharacterCount += 1
			diagnostics.RemovedDuplicateIdCount += 1
		elseif names[normalizedName] then
			diagnostics.RemovedCharacterCount += 1
			diagnostics.RemovedDuplicateNameCount += 1
		else
			ids[character.Id] = true
			names[normalizedName] = true
			table.insert(account.Characters, character)
		end
	end
	if type(source.SelectedCharacterId) == "string" and ids[source.SelectedCharacterId] then
		account.SelectedCharacterId = source.SelectedCharacterId
	elseif source.SelectedCharacterId ~= nil then
		diagnostics.SelectionWasCleared = true
	end
	local sourceSettings = type(source.Settings) == "table" and source.Settings or nil
	diagnostics.AddedDefaultSettingsDuringMigration = source.SchemaVersion == 1 and sourceSettings == nil
	local bindings, bindingDiagnostics = BindingConfig.NormalizeBindings(sourceSettings and sourceSettings.Bindings)
	local preferences, preferenceDiagnostics = PlayerPreferencesConfig.NormalizePreferences(
		sourceSettings and sourceSettings.Preferences
	)
	account.Settings.Bindings = bindings
	account.Settings.Preferences = preferences
	diagnostics.DefaultedBindingCount = bindingDiagnostics.DefaultedBindingCount
	diagnostics.RemovedBindingCount = bindingDiagnostics.RemovedBindingCount
	diagnostics.AddedMissingPreferenceDefaultCount = (
		preferenceDiagnostics.AddedMissingPreferenceDefaultCount
	)
	diagnostics.ReplacedInvalidPreferenceCount = preferenceDiagnostics.ReplacedInvalidPreferenceCount
	diagnostics.RemovedUnknownPreferenceCount = preferenceDiagnostics.RemovedUnknownPreferenceCount
	return account, diagnostics
end

function Schema.DiagnosticsRequireSave(diagnostics)
	return diagnostics.MigratedFromSchemaVersion ~= nil
		or diagnostics.RemovedCharacterCount > 0
		or diagnostics.SelectionWasCleared
		or diagnostics.DefaultedBindingCount > 0
		or diagnostics.RemovedBindingCount > 0
		or diagnostics.AddedMissingPreferenceDefaultCount > 0
		or diagnostics.ReplacedInvalidPreferenceCount > 0
		or diagnostics.RemovedUnknownPreferenceCount > 0
		or diagnostics.MetadataWasNormalized
end

function Schema.FindCharacter(account, profileId)
	if type(profileId) ~= "string" or #profileId > 64 then return nil, nil end
	for index, character in account.Characters do
		if character.Id == profileId then return character, index end
	end
	return nil, nil
end

function Schema.HasDuplicateName(account, name, excludedId)
	for _, character in account.Characters do
		if character.Id ~= excludedId and character.Name:lower() == name:lower() then return true end
	end
	return false
end

return Schema
