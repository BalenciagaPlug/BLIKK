local CharacterDependency = {}

local function resolveHumanoidAndRoot(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not rootPart or not rootPart:IsA("BasePart") then
		return nil, nil
	end
	return humanoid, rootPart
end

function CharacterDependency.WaitForChildBefore(parent, childName, deadline)
	local child = parent:FindFirstChild(childName)
	if child then return child end
	local remainingSeconds = deadline - os.clock()
	if remainingSeconds <= 0 then return nil end
	return parent:WaitForChild(childName, remainingSeconds)
end

function CharacterDependency.ObserveHumanoidAndRoot(
	character,
	timeoutSeconds,
	onReady,
	onInitialTimeout,
	requiredChildNames
)
	local isActive = true
	local descendantConnection = nil

	local function cancel()
		if not isActive then return end
		isActive = false
		if descendantConnection then
			descendantConnection:Disconnect()
			descendantConnection = nil
		end
	end

	local function tryResolve()
		if not isActive then return end
		local humanoid, rootPart = resolveHumanoidAndRoot(character)
		if not humanoid then return end
		local childNames = if type(requiredChildNames) == "function"
			then requiredChildNames(humanoid)
			else requiredChildNames
		for _, childName in childNames or {} do
			if not character:FindFirstChild(childName) then return end
		end
		cancel()
		onReady(humanoid, rootPart)
	end

	descendantConnection = character.DescendantAdded:Connect(tryResolve)
	tryResolve()
	task.delay(math.max(0, timeoutSeconds), function()
		if isActive and onInitialTimeout then onInitialTimeout() end
	end)

	return cancel
end

return CharacterDependency
