local GroundSlashAnimationConfig = {
	HookName = "KatanaSlash1",
	PlaybackSpeed = 1,
	FadeInSeconds = 0.012,
	CancelFadeOutSeconds = 0.028,
	CompletionFadeOutSeconds = 0.04,

	-- These catalog asset candidates are reference material only. Keeping them here makes an
	-- accidental future assignment fail closed instead of loading an unapproved asset.
	ReferenceOnlyAssetIds = {
		["rbxassetid://9936936245"] = true,
		["rbxassetid://7598646037"] = true,
	},
}

return table.freeze(GroundSlashAnimationConfig)
