local ActionBuffer = {}

ActionBuffer.Buffer = {}
ActionBuffer.MaxBufferTime = 0.35

function ActionBuffer:Push(action)
    table.insert(self.Buffer, {
        Action = action,
        Time = os.clock()
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

return ActionBuffer