local Config = {
	SampleRateHz = 5, RollingBufferSeconds = 30, PreEventSeconds = 10,
	PostEventSeconds = 3, MaximumClipsPerMatch = 30, MaximumEventsPerMatch = 512,
	MaximumSerializedClipBytes = 48000, RequestCooldownSeconds = 2,
	PostMatchRetentionSeconds = 600,
	PlaybackSpeeds = { 0.5, 1, 2 },
	ReportStoreName = "BLIKKReportsV1", ReportSchemaVersion = 1,
	ReportNoteMaximumLength = 160, MaximumReportsPerMatch = 3,
	MaximumReportsPerWindow = 5, ReportWindowSeconds = 1800,
	SameTargetCooldownSeconds = 300,
	ReportReasons = { "Exploiting", "Cheating", "Harassment", "UnsportingBehavior", "InappropriateNameOrClan", "Other" },
}

return Config
