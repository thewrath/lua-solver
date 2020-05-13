--
-- simple fifo module for cqueues
--
-- ------------------------------------------------------------------------

local condition = require "cqueues.condition"

local fifo = {}

function fifo:new()
	local o = { condvar = condition.new(), count = 0 }
    setmetatable(o, { __index = self })
	return o  
end -- fifo.new

function fifo:put(msg)
	local tail = { data = msg }

	if self.tail then
		self.tail.next = tail
		self.tail = tail
	else
		self.head = tail
		self.tail = tail
	end

	self.count = self.count + 1

	self:signal()
end -- fifo:put

function fifo:get()
	if self.head then
		local head = self.head

		self.head = head.next

		if not self.head then
			self.tail = nil
		end

		assert(self.count > 0)
		self.count = self.count - 1

		return head.data
	end	

	assert(self.count == 0)
end -- fifo:get

function fifo:signal()
	self.condvar:signal()
end -- fifo:signal

function fifo:getcv()
	return self.condvar
end -- fifo:getcv

return fifo