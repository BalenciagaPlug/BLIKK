local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:FindFirstChild("Shared")
assert(Shared, "Shared must be acquired by the client composition root before binding state")
local ActionCatalogue = require(Shared.Input.ActionCatalogue)

local BindingState = {}

BindingState.Changed = Instance.new("BindableEvent")

local bindings = {}

local function resetAction(actionId)
	local definition = ActionCatalogue.ById[actionId]
	bindings[actionId] = {
		Primary = definition.Primary,
		Secondary = definition.Secondary,
	}
end

for _, action in ActionCatalogue.Ordered do
	resetAction(action.Id)
end

function BindingState:Get(actionId, slot)
	return bindings[actionId] and bindings[actionId][slot]
end

function BindingState:GetActionBindings(actionId)
	return bindings[actionId]
end

function BindingState:FindOwner(token, excludedAction, excludedSlot)
	if not token then
		return nil
	end

	for actionId, slots in bindings do
		for slot, boundToken in slots do
			if boundToken == token and (actionId ~= excludedAction or slot ~= excludedSlot) then
				return actionId, slot
			end
		end
	end

	return nil
end

function BindingState:CanClear(actionId, slot)
	local definition = ActionCatalogue.ById[actionId]
	local otherSlot = if slot == "Primary" then "Secondary" else "Primary"
	return not definition.Protected or bindings[actionId][otherSlot] ~= nil
end

function BindingState:Set(actionId, slot, token)
	local slots = bindings[actionId]

	if not slots or (slot ~= "Primary" and slot ~= "Secondary") then
		return false
	end

	if token and slots[if slot == "Primary" then "Secondary" else "Primary"] == token then
		return false
	end

	if not token and not self:CanClear(actionId, slot) then
		return false
	end

	slots[slot] = token
	self.Changed:Fire(actionId, slot, token)
	return true
end

function BindingState:Replace(actionId, slot, token, oldAction, oldSlot)
	if oldAction and oldSlot then
		if not self:CanClear(oldAction, oldSlot) then
			return false
		end
		bindings[oldAction][oldSlot] = nil
		self.Changed:Fire(oldAction, oldSlot, nil)
	end

	return self:Set(actionId, slot, token)
end

function BindingState:ResetAction(actionId)
	resetAction(actionId)
	self.Changed:Fire(actionId, "Reset", nil)
end

function BindingState:ResetAll()
	for _, action in ActionCatalogue.Ordered do
		resetAction(action.Id)
	end

	self.Changed:Fire(nil, "ResetAll", nil)
end

function BindingState:ApplyConfirmed(confirmedBindings)
	if type(confirmedBindings) ~= "table" then return end
	for _, action in ActionCatalogue.Ordered do
		local confirmed = confirmedBindings[action.Id]
		if type(confirmed) == "table" then
			bindings[action.Id] = {
				Primary = confirmed.Primary,
				Secondary = confirmed.Secondary,
			}
		end
	end
	self.Changed:Fire(nil, "Confirmed", nil)
end

return BindingState
