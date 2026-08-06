local ActionCatalogue = require(script.Parent.ActionCatalogue)

local BindingConfig = {}

BindingConfig.Slots = {
	Primary = true,
	Secondary = true,
}

local mouseTokens = {
	MouseButton1 = true,
	MouseButton2 = true,
	MouseButton3 = true,
	MouseWheelUp = true,
	MouseWheelDown = true,
}

local function isValidToken(token)
	if type(token) ~= "string" then return false end
	if #token < 1 or #token > 64 then return false end
	if mouseTokens[token] then return true end
	local keyName = token:match("^KeyCode%.(.+)$")
	if not keyName then return false end
	local keyCode = Enum.KeyCode[keyName]
	return keyCode ~= nil and keyCode ~= Enum.KeyCode.Unknown and keyCode ~= Enum.KeyCode.Escape
end

function BindingConfig.DefaultBindings()
	local bindings = {}
	for _, action in ActionCatalogue.Ordered do
		bindings[action.Id] = {
			Primary = action.Primary,
			Secondary = action.Secondary,
		}
	end
	return bindings
end

function BindingConfig.IsValidToken(token)
	return isValidToken(token)
end

function BindingConfig.NormalizeBindings(source)
	local bindings = {}
	local diagnostics = {
		DefaultedBindingCount = 0,
		RemovedBindingCount = 0,
	}
	local claimedTokens = {}
	if type(source) == "table" then
		for actionId in source do
			if not ActionCatalogue.ById[actionId] then
				diagnostics.RemovedBindingCount += 1
			end
		end
	end

	for _, action in ActionCatalogue.Ordered do
		local stored = type(source) == "table" and source[action.Id] or nil
		local candidate = if type(stored) == "table" then stored else action
		bindings[action.Id] = {}
		if type(stored) ~= "table" then diagnostics.DefaultedBindingCount += 1 end
		if type(stored) == "table" then
			for slot in stored do
				if not BindingConfig.Slots[slot] then diagnostics.RemovedBindingCount += 1 end
			end
		end
		for _, slot in { "Primary", "Secondary" } do
			local token = candidate[slot]
			if token == nil then
				bindings[action.Id][slot] = nil
			elseif isValidToken(token) and not claimedTokens[token] then
				bindings[action.Id][slot] = token
				claimedTokens[token] = true
			else
				diagnostics.RemovedBindingCount += 1
			end
		end
	end

	for _, action in ActionCatalogue.Ordered do
		local binding = bindings[action.Id]
		if action.Protected and (action.Primary or action.Secondary)
			and not binding.Primary and not binding.Secondary
		then
			for _, slot in { "Primary", "Secondary" } do
				local token = action[slot]
				if token and not claimedTokens[token] then
					binding[slot] = token
					claimedTokens[token] = true
					break
				end
			end
			diagnostics.DefaultedBindingCount += 1
		end
	end

	return bindings, diagnostics
end

function BindingConfig.FindOwner(bindings, token)
	for _, action in ActionCatalogue.Ordered do
		local binding = bindings[action.Id]
		if binding then
			for _, slot in { "Primary", "Secondary" } do
				if binding[slot] == token then return action.Id, slot end
			end
		end
	end
	return nil, nil
end

function BindingConfig.CanClear(bindings, actionId, slot)
	local action = ActionCatalogue.ById[actionId]
	local binding = bindings[actionId]
	if not action or not binding or not BindingConfig.Slots[slot] then return false end
	if not action.Protected then return true end
	local otherSlot = if slot == "Primary" then "Secondary" else "Primary"
	return binding[otherSlot] ~= nil
end

return BindingConfig
