local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Branding = require(ReplicatedStorage.Shared.Branding.Branding)
local CharacterPreviewController = require(script.Parent.CharacterPreviewController)
local FrontendLayout = require(script.Parent.FrontendLayout)
local ProfileConfig = require(ReplicatedStorage.Shared.Character.ProfileConfig)

local Controller = {}
Controller.ProfileSelected = Instance.new("BindableEvent")
Controller.StateChanged = Instance.new("BindableEvent")
Controller.AccountSnapshotChanged = Instance.new("BindableEvent")

local profiles = {}
local selectedId = nil
local accountSettings = nil
local accountStatus = "Loading"
local transportStatus = "Resolving"
local statusMessage = "LOADING FIGHTERS..."
local isInitialised = false
local mutationInFlight = false
local requestRemote = nil
local updateRemote = nil
local updateRemoteConnection = nil
local discoveryConnections = {}
local discoveryGeneration = 0
local isSnapshotRequestInFlight = false
local beginRemoteDiscovery = nil

local REMOTE_DISCOVERY_WINDOW_SECONDS = 8

local colors = {
	Text = Color3.fromRGB(232, 230, 216),
	Muted = Color3.fromRGB(133, 140, 132),
	Accent = Color3.fromRGB(157, 216, 83),
	Panel = Color3.fromRGB(17, 19, 19),
	Error = Color3.fromRGB(194, 68, 72),
}

local function label(parent, text, size, textSize, color)
	local item = Instance.new("TextLabel")
	item.BackgroundTransparency = 1
	item.Font = Enum.Font.Code
	item.Text = text
	item.TextColor3 = color or colors.Text
	item.TextSize = textSize or 13
	item.TextXAlignment = Enum.TextXAlignment.Left
	item.Size = size
	item.Parent = parent
	return item
end

local function button(parent, text, size)
	local item = Instance.new("TextButton")
	item.AutoButtonColor = false
	item.BackgroundColor3 = colors.Panel
	item.Font = Enum.Font.Code
	item.Text = text
	item.TextColor3 = colors.Text
	item.TextSize = 13
	item.Size = size
	item.Parent = parent
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(68, 75, 69)
	stroke.Parent = item
	return item
end

local function selectedProfile()
	for _, profile in profiles do
		if profile.Id == selectedId then return profile end
	end
	return nil
end

local function profileById(profileId)
	for _, profile in profiles do
		if profile.Id == profileId then return profile end
	end
	return nil
end

local function fireStateChanged()
	Controller.StateChanged:Fire(accountStatus, statusMessage, transportStatus)
end

local function applyResult(result)
	if type(result) ~= "table" then return false, "PROFILE SERVICE RETURNED AN INVALID RESPONSE" end
	statusMessage = if type(result.Message) == "string" then result.Message else ""
	local snapshot = result.Snapshot
	if type(snapshot) == "table" and type(snapshot.Characters) == "table" then
		profiles = snapshot.Characters
		selectedId = snapshot.SelectedCharacterId
		accountSettings = snapshot.Settings
		accountStatus = if type(result.Status) == "string" then result.Status else accountStatus
		Controller.AccountSnapshotChanged:Fire(accountSettings)
	elseif accountStatus ~= "Ready" and type(result.Status) == "string" then
		accountStatus = result.Status
	end
	fireStateChanged()
	return result.Success == true, statusMessage
end

local function request(operation, payload)
	if not requestRemote or transportStatus ~= "Ready" then
		return nil, "PROFILE SERVICE IS RESOLVING // TRY AGAIN"
	end
	local succeeded, result = pcall(function()
		return requestRemote:InvokeServer(operation, payload)
	end)
	if not succeeded then
		requestRemote = nil
		transportStatus = "Unavailable"
		statusMessage = "PROFILE REQUEST FAILED // TRY AGAIN"
		fireStateChanged()
		task.defer(function() beginRemoteDiscovery() end)
		return nil, statusMessage
	end
	local accepted, message = applyResult(result)
	return if accepted then result else nil, message
end

local function disconnectDiscovery()
	for _, connection in discoveryConnections do connection:Disconnect() end
	table.clear(discoveryConnections)
end

local function requestSnapshot()
	if isSnapshotRequestInFlight or transportStatus ~= "Ready" then return end
	isSnapshotRequestInFlight = true
	task.spawn(function()
		request("Request", nil)
		isSnapshotRequestInFlight = false
	end)
end

local function completeRemoteDiscovery()
	if requestRemote and not requestRemote:IsDescendantOf(ReplicatedStorage) then requestRemote = nil end
	if updateRemote and not updateRemote:IsDescendantOf(ReplicatedStorage) then
		updateRemote = nil
		if updateRemoteConnection then updateRemoteConnection:Disconnect() end
		updateRemoteConnection = nil
	end
	if not requestRemote or not updateRemote then return false end
	transportStatus = "Ready"
	discoveryGeneration += 1
	disconnectDiscovery()
	if not updateRemoteConnection then
		updateRemoteConnection = updateRemote.OnClientEvent:Connect(applyResult)
	end
	if accountStatus == "Loading" then statusMessage = "LOADING FIGHTERS..." end
	fireStateChanged()
	requestSnapshot()
	return true
end

local function inspectRemote(child)
	if child.Name == "CharacterProfilesRequest" and child:IsA("RemoteFunction") then
		requestRemote = child
	elseif child.Name == "CharacterProfilesUpdated" and child:IsA("RemoteEvent") then
		updateRemote = child
	end
	completeRemoteDiscovery()
end

beginRemoteDiscovery = function()
	if completeRemoteDiscovery() then return end
	discoveryGeneration += 1
	local generation = discoveryGeneration
	disconnectDiscovery()
	transportStatus = "Resolving"
	statusMessage = if accountStatus == "Ready" then "PROFILE SERVICE IS RESOLVING..."
		else "LOADING FIGHTERS..."
	fireStateChanged()

	local function inspectFolder(folder)
		for _, child in folder:GetChildren() do inspectRemote(child) end
		if transportStatus == "Ready" then return end
		table.insert(discoveryConnections, folder.ChildAdded:Connect(inspectRemote))
	end

	local folder = ReplicatedStorage:FindFirstChild("BLIKKRemotes")
	if folder then
		inspectFolder(folder)
	else
		table.insert(discoveryConnections, ReplicatedStorage.ChildAdded:Connect(function(child)
			if child.Name == "BLIKKRemotes" then inspectFolder(child) end
		end))
	end

	task.delay(REMOTE_DISCOVERY_WINDOW_SECONDS, function()
		if generation ~= discoveryGeneration or transportStatus == "Ready" then return end
		discoveryGeneration += 1
		disconnectDiscovery()
		transportStatus = "Unavailable"
		statusMessage = "PROFILE SERVICE IS UNAVAILABLE // REOPEN TO RETRY"
		fireStateChanged()
	end)
end

local function isRequestReady()
	return transportStatus == "Ready" and accountStatus == "Ready" and not mutationInFlight
end

function Controller:GetProfiles()
	return profiles
end

function Controller:GetSelectedProfile()
	return selectedProfile()
end

function Controller:GetAccountSettings()
	return accountSettings
end

function Controller:RequestAccountMutation(operation, payload)
	if mutationInFlight then return nil, "ACCOUNT REQUEST ALREADY IN PROGRESS" end
	if not isRequestReady() then return nil, "ACCOUNT STORAGE OR TRANSPORT IS NOT READY" end
	mutationInFlight = true
	local result, message = request(operation, payload)
	mutationInFlight = false
	return result, message
end

function Controller:CreateProfile(data)
	if mutationInFlight then return nil, "PROFILE REQUEST ALREADY IN PROGRESS" end
	if transportStatus ~= "Ready" or accountStatus ~= "Ready" then
		return nil, "PROFILE STORAGE OR TRANSPORT IS NOT READY"
	end
	mutationInFlight = true
	local result, message = request("Create", data)
	mutationInFlight = false
	return result and selectedProfile() or nil, message
end

function Controller:DeleteSelected()
	if not isRequestReady() or not selectedId then return false, "NO FIGHTER SELECTED OR SERVICE NOT READY" end
	mutationInFlight = true
	local result, message = request("Delete", selectedId)
	mutationInFlight = false
	return result ~= nil, message
end

function Controller:UpdateProfile(data)
	if not isRequestReady() then return nil, "PROFILE REQUEST IS TEMPORARILY UNAVAILABLE" end
	mutationInFlight = true
	local result, message = request("Update", data)
	mutationInFlight = false
	return result and profileById(data.Id) or nil, message
end

function Controller:SelectProfile(profileId)
	if not isRequestReady() then return nil, "PROFILE REQUEST IS TEMPORARILY UNAVAILABLE" end
	mutationInFlight = true
	local result, message = request("Select", profileId)
	mutationInFlight = false
	return result and selectedProfile() or nil, message

end

function Controller:Init()
	if isInitialised then return end
	isInitialised = true
	beginRemoteDiscovery()
	script.Destroying:Connect(function()
		discoveryGeneration += 1
		disconnectDiscovery()
		if updateRemoteConnection then updateRemoteConnection:Disconnect() end
	end)
end

function Controller:CreatePage(parent, navigation, fighterController)
	local page = Instance.new("Frame")
	page.Name = "CharacterProfiles"
	page.BackgroundColor3 = Color3.fromRGB(7, 8, 8)
	page.Size = UDim2.fromScale(1, 1)
	page.Parent = parent
	local canvas = FrontendLayout:CreateCanvas(page)
	Branding.CreateFullLogo(canvas, {
		Position = UDim2.fromOffset(24, 4),
		Size = Branding.Sizes.CharacterProfiles,
	})
	local header = label(canvas, "CHARACTER PROFILES", UDim2.fromOffset(600, 42), 28)
	header.Position = UDim2.fromOffset(224, 20)
	local sub = label(canvas, "OPERATIVE REGISTRY // 5 SLOTS", UDim2.fromOffset(500, 18), 10, colors.Accent)
	sub.Position = UDim2.fromOffset(227, 63)
	local status = label(canvas, "", UDim2.fromOffset(500, 18), 10, colors.Muted)
	status.Position = UDim2.fromOffset(227, 82)

	local left = Instance.new("Frame")
	left.BackgroundTransparency = 1
	left.Position = UDim2.new(0.025, 0, 0.17, 0)
	left.Size = UDim2.new(0.48, 0, 0.7, 0)
	left.Parent = canvas
	local list = Instance.new("Frame")
	list.BackgroundTransparency = 1
	list.Size = UDim2.new(1, 0, 1, -60)
	list.Parent = left
	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 9)
	listLayout.Parent = list
	local actions = Instance.new("Frame")
	actions.BackgroundTransparency = 1
	actions.AnchorPoint = Vector2.new(0, 1)
	actions.Position = UDim2.fromScale(0, 1)
	actions.Size = UDim2.new(1, 0, 0, 45)
	actions.Parent = left
	local actionLayout = Instance.new("UIListLayout")
	actionLayout.FillDirection = Enum.FillDirection.Horizontal
	actionLayout.Padding = UDim.new(0, 10)
	actionLayout.Parent = actions

	local preview = Instance.new("ViewportFrame")
	preview.BackgroundColor3 = Color3.fromRGB(11, 13, 13)
	preview.Position = UDim2.new(0.54, 0, 0.12, 0)
	preview.Size = UDim2.new(0.435, 0, 0.68, 0)
	preview.Parent = canvas
	local appearanceLabel = label(canvas, "", UDim2.new(0.435, 0, 0.1, 0), 10, colors.Muted)
	appearanceLabel.Position = UDim2.new(0.54, 0, 0.82, 0)
	appearanceLabel.TextWrapped = true
	appearanceLabel.TextYAlignment = Enum.TextYAlignment.Top

	local function updateAppearanceLabel(profile)
		local appearance = profile and profile.Appearance
		appearanceLabel.Text = appearance and string.format(
			"FACE // %s   HAIR // %s\nTOP // %s   PANTS // %s   BOOTS // %s",
			appearance.Face, appearance.Hair, appearance.TopArmour, appearance.Pants, appearance.Boots
		) or ""
	end

	local refresh
	refresh = function()
		status.Text = if transportStatus ~= "Ready" then statusMessage
			elseif accountStatus == "Loading" then "LOADING FIGHTERS..."
			elseif accountStatus == "Unavailable" then statusMessage
			else ""
		for _, child in list:GetChildren() do
			if child ~= listLayout then child:Destroy() end
		end
		for index = 1, ProfileConfig.MaximumProfiles do
			local profile = profiles[index]
			local text = profile
				and string.format("%02d  %s\n%s // LV %d // %s", index, profile.Name:upper(), profile.BodyType:upper(), profile.Level, profile.LastPlayedUnix == 0 and "NEW" or os.date("%Y-%m-%d", profile.LastPlayedUnix))
				or string.format("%02d  EMPTY PROFILE", index)
			local row = button(list, text, UDim2.new(1, 0, 0, 70))
			row.TextXAlignment = Enum.TextXAlignment.Left
			row.TextWrapped = true
			if profile and profile.Id == selectedId then row.BackgroundColor3 = Color3.fromRGB(44, 65, 34) end
			row.Activated:Connect(function()
				if profile then
					local confirmed, message = self:SelectProfile(profile.Id)
					refresh()
					if confirmed then
						updateAppearanceLabel(confirmed)
						CharacterPreviewController:Render(preview, confirmed, false)
					else
						status.Text = message
					end
				elseif isRequestReady() then
					navigation:GoTo("Creation")
				end
			end)
		end
	end

	local play = button(actions, "PLAY", UDim2.new(0.32, 0, 1, 0))
	local create = button(actions, "NEW FIGHTER", UDim2.new(0.32, 0, 1, 0))
	local delete = button(actions, "DELETE", UDim2.new(0.32, 0, 1, 0))
	delete.TextColor3 = colors.Error
	create.Activated:Connect(function()
		if isRequestReady() then navigation:GoTo("Creation") end
	end)
	delete.Activated:Connect(function()
		local deleted, message = self:DeleteSelected()
		if not deleted then status.Text = message; return end
		refresh()
		local profile = selectedProfile()
		if profile then
			updateAppearanceLabel(profile)
			CharacterPreviewController:Render(preview, profile, false)
		else
			navigation:GoTo("Creation")
		end
	end)
	play.Activated:Connect(function()
		local profile = selectedProfile()
		if not profile then return end
		local confirmed, message = self:SelectProfile(profile.Id)
		if not confirmed then status.Text = message; return end
		fighterController:SetBodyType(confirmed.BodyType)
		self.ProfileSelected:Fire(confirmed)
		navigation:GoTo("OperationsHub", confirmed)
	end)

	local object = {}
	function object:SetVisible(visible)
		page.Visible = visible
		if visible then
			if transportStatus ~= "Ready" then beginRemoteDiscovery() end
			if transportStatus == "Ready" and accountStatus ~= "Ready" then requestSnapshot() end
			if isRequestReady() and #profiles == 0 then
				task.defer(function()
					if page.Visible and isRequestReady() and #profiles == 0 then
						navigation:GoTo("Creation")
					end
				end)
			end
			refresh()
			local profile = selectedProfile()
			updateAppearanceLabel(profile)
			CharacterPreviewController:Render(preview, profile, false)
		else
			CharacterPreviewController:Stop()
		end
	end
	Controller.StateChanged.Event:Connect(function()
		if not page.Visible then return end
		if isRequestReady() and #profiles == 0 then
			navigation:GoTo("Creation")
			return
		end
		refresh()
		local profile = selectedProfile()
		updateAppearanceLabel(profile)
		CharacterPreviewController:Render(preview, profile, false)
	end)
	return object
end

return Controller
