local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FrontendLayout = require(script.Parent.FrontendLayout)

local Controller = {}

local function label(parent, text, position, size, textSize)
	local value = Instance.new("TextLabel"); value.BackgroundTransparency = 1; value.Font = Enum.Font.Code
	value.TextColor3 = Color3.fromRGB(230, 227, 215); value.Text = text; value.Position = position
	value.Size = size; value.TextSize = textSize or 13; value.TextXAlignment = Enum.TextXAlignment.Left; value.Parent = parent; return value
end

local function button(parent, text, position, size)
	local value = Instance.new("TextButton"); value.BackgroundColor3 = Color3.fromRGB(24, 25, 29); value.Font = Enum.Font.Code
	value.TextColor3 = Color3.fromRGB(230, 227, 215); value.Text = text; value.Position = position; value.Size = size; value.TextSize = 12; value.Parent = parent; return value
end

function Controller:CreatePage(parent, navigation)
	local page = Instance.new("Frame"); page.Name = "Clans"; page.BackgroundColor3 = Color3.fromRGB(5, 6, 8); page.Size = UDim2.fromScale(1, 1); page.Parent = parent
	local canvas = FrontendLayout:CreateCanvas(page); label(canvas, "CLANS", UDim2.fromOffset(28, 28), UDim2.fromOffset(400, 44), 28)
	local request = ReplicatedStorage:WaitForChild("BLIKKRemotes"):WaitForChild("ClanRequest")
	local updated = ReplicatedStorage.BLIKKRemotes:WaitForChild("ClanUpdated")
	local status = label(canvas, "LOADING...", UDim2.fromOffset(28, 78), UDim2.new(1, -56, 0, 30), 13)
	local nameBox = Instance.new("TextBox"); nameBox.PlaceholderText = "CLAN NAME"; nameBox.Text = ""; nameBox.Position = UDim2.fromOffset(28, 125); nameBox.Size = UDim2.fromOffset(330, 40); nameBox.Parent = canvas
	local tagBox = Instance.new("TextBox"); tagBox.PlaceholderText = "TAG"; tagBox.Text = ""; tagBox.Position = UDim2.fromOffset(370, 125); tagBox.Size = UDim2.fromOffset(130, 40); tagBox.Parent = canvas
	local create = button(canvas, "CREATE CLAN", UDim2.fromOffset(512, 125), UDim2.fromOffset(150, 40))
	local targetBox = Instance.new("TextBox"); targetBox.PlaceholderText = "TARGET USER ID OR EXACT USERNAME"; targetBox.Text = ""; targetBox.Position = UDim2.fromOffset(28, 180); targetBox.Size = UDim2.fromOffset(330, 40); targetBox.Parent = canvas
	local invite = button(canvas, "INVITE", UDim2.fromOffset(370, 180), UDim2.fromOffset(130, 40))
	local leave = button(canvas, "LEAVE", UDim2.fromOffset(512, 180), UDim2.fromOffset(150, 40))
	local accept = button(canvas, "ACCEPT FIRST INVITE", UDim2.fromOffset(674, 125), UDim2.fromOffset(180, 40))
	local decline = button(canvas, "DECLINE FIRST", UDim2.fromOffset(866, 125), UDim2.fromOffset(150, 40))
	local kick = button(canvas, "KICK TARGET", UDim2.fromOffset(674, 180), UDim2.fromOffset(130, 40))
	local role = button(canvas, "TOGGLE ROLE", UDim2.fromOffset(816, 180), UDim2.fromOffset(130, 40))
	local transfer = button(canvas, "TRANSFER", UDim2.fromOffset(958, 180), UDim2.fromOffset(120, 40))
	local disband = button(canvas, "DISBAND", UDim2.fromOffset(1090, 180), UDim2.fromOffset(110, 40))
	local roster = label(canvas, "", UDim2.fromOffset(28, 245), UDim2.new(1, -56, 1, -320), 13); roster.TextYAlignment = Enum.TextYAlignment.Top
	local latestSnapshot = nil
	local back = button(canvas, "RETURN TO HUB", UDim2.new(1, -205, 1, -62), UDim2.fromOffset(175, 36)); back.Activated:Connect(function() navigation:GoTo("OperationsHub") end)
	local function render(snapshot)
		latestSnapshot = snapshot
		if not snapshot or not snapshot.Clan then local lines = { "NO CLAN // CREATE OR ACCEPT AN INVITE", "PENDING INVITES // " .. tostring(snapshot and #snapshot.Invites or 0) }; for _, pending in snapshot and snapshot.Invites or {} do table.insert(lines, pending.InviteId .. " // [" .. pending.ClanTag .. "] " .. pending.ClanName) end; status.Text = lines[1]; roster.Text = table.concat(lines, "\n"); return end
		local clan = snapshot.Clan; status.Text = string.format("[%s] %s // %d MEMBERS", clan.Tag, clan.Name, #clan.Members)
		local lines = {}; for _, member in clan.Members do table.insert(lines, string.format("%d // %s // %s", member.UserId, member.Role, member.Online and "ONLINE" or "OFFLINE")) end; roster.Text = table.concat(lines, "\n")
	end
	local function invoke(operation, payload) local ok, result = pcall(request.InvokeServer, request, operation, payload); if ok and result.Success then render(result.Snapshot) else status.Text = ok and tostring(result.Code) or "CLAN SERVICE UNAVAILABLE" end end
	create.Activated:Connect(function() invoke("Create", { Name = nameBox.Text, Tag = tagBox.Text, Description = "" }) end)
	invite.Activated:Connect(function() invoke("Invite", tonumber(targetBox.Text) or targetBox.Text) end)
	leave.Activated:Connect(function() invoke("Leave") end)
	accept.Activated:Connect(function() local pending = latestSnapshot and latestSnapshot.Invites and latestSnapshot.Invites[1]; if pending then invoke("AcceptInvite", pending.InviteId) end end)
	decline.Activated:Connect(function() local pending = latestSnapshot and latestSnapshot.Invites and latestSnapshot.Invites[1]; if pending then invoke("DeclineInvite", pending.InviteId) end end)
	kick.Activated:Connect(function() invoke("Kick", tonumber(targetBox.Text)) end)
	local nextRole = "OFFICER"
	role.Activated:Connect(function()
		invoke("SetRole", { TargetUserId = tonumber(targetBox.Text), Role = nextRole })
		nextRole = if nextRole == "OFFICER" then "MEMBER" else "OFFICER"
		role.Text = if nextRole == "OFFICER" then "PROMOTE NEXT" else "DEMOTE NEXT"
	end)
	transfer.Activated:Connect(function() invoke("TransferOwnership", tonumber(targetBox.Text)) end)
	disband.Activated:Connect(function() invoke("Disband") end)
	updated.OnClientEvent:Connect(render)
	local object = {}; function object:SetVisible(visible) page.Visible = visible; if visible then invoke("Snapshot") end end; return object
end

return Controller
