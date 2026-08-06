local CharacterPersistenceConfig = {
	DataStoreName = "BLIKKCharacterProfilesV1",
	KeyPrefix = "Player_",
	SchemaVersion = 3,
	AutosaveIntervalSeconds = 60,
	MutationSaveDebounceSeconds = 3,
	LoadRetryCount = 3,
	SaveRetryCount = 3,
	RetryBaseDelaySeconds = 0.5,
	ShutdownTimeoutSeconds = 10,
	RemoteMutationCooldownSeconds = 0.2,
}

return CharacterPersistenceConfig
