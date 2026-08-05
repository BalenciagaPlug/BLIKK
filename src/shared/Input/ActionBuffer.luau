local ActionCatalogue = require(script.Parent.ActionCatalogue)
local InputConfig = require(script.Parent.InputConfig)

local ActionBuffer = {}

ActionBuffer.Buffer = {}
ActionBuffer.MaxBufferTime = InputConfig.ActionBufferDurationSeconds

function ActionBuffer:Push(action)
	if not ActionCatalogue.ById[action] then
		return
	end

	table.insert(self.Buffer, {
		Action = action,
		Time = os.clock(),
	})

	self:Cleanup()
end

function ActionBuffer:Cleanup()
	local now = os.clock()

	for i = #self.Buffer, 1, -1 do
		if now - self.Buffer[i].Time > self.MaxBufferTime then
			table.remove(self.Buffer, i)
		end
	end
end

function ActionBuffer:GetBuffer()
	return self.Buffer
end

function ActionBuffer:Clear()
	table.clear(self.Buffer)
end

return ActionBuffer
