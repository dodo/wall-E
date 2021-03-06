require "socket"
require "bit"

Wall = Object:new()

local input_masks = {
	up = 1,
	down = 2,
	left = 4,
	right = 8,
	select = 16,
	start = 32,
	a = 64,
	b = 128,
}

local local_keys = {
	{
		up = "up",
		down = "down",
		left = "left",
		right = "right",
		select = "rshift",
		start = "return",
		a = "o",
		b = "p",
	}, {
		up = "w",
		down = "s",
		left = "a",
		right = "d",
		select = "lshift",
		start = "lctrl",
		a = "1",
		b = "2",
	}
}


function Wall:init(host, port, priority, remote_pads)

	self.buffer = {}

	self.width = 16
	self.height = 15

	for i = 1, self.width * self.height do
		self.buffer[i] = "000000"
	end

	-- button set-up
	self.input = { {}, {} }
	for _, player in ipairs(self.input) do
		for button in pairs(input_masks) do
			player[button] = false
		end
	end

	if host == false then return end

	host = host or "ledwall"
	port = port or 1338
	priority = priority or 3

	self.msg = ""
	self.socket = socket.tcp()
	self.socket:connect(host, port)
	self:priority(priority)

	self.remote_pads = remote_pads
	-- subscribe input
	if remote_pads then
		self.socket:send("0901\r\n")
	end

end


function Wall:priority(priority)
	if self.socket then
		self.socket:send("04%02d\r\n" % priority)
	end
end

function Wall:record(flag)
	if self.socket then
		local opcode = flag and "05" or "06"
		self.socket:send(opcode .. "\r\n")
	end
end

function Wall:pixel(x, y, color)
	if 0 <= x and x < self.width and 0 <= y and y < self.height then
		self.buffer[y * self.width + x + 1] = color
	end
end


function Wall:update_input()

	if self.remote_pads then
		while true do
			local t = socket.select({ self.socket }, nil, 0)[1]
			if not t then
				break
			end
			
			local msg = self.socket:receive()
			local nr, bits
			if msg then
				nr, bits = msg:match "09(..)(..).."
			end

			if nr then
				-- convert from hex
				nr = tonumber("0x" .. nr)
				bits = tonumber("0x" .. bits)

				if nr >= 1 and nr <= 2 then
					local player = self.input[nr]
					for button, mask in pairs(input_masks) do
						player[button] = bit.band(mask, bits) > 0
					end
				end
			end

		end
	else

		for nr, keys in ipairs(local_keys) do
			local player = self.input[nr]
			for button, key in pairs(keys) do
				player[button] = love.keyboard.isDown(key)
			end
		end

	end

end

function Wall:draw()
	local w = love.graphics.getWidth() / self.width
	local h = love.graphics.getHeight() / self.height
	for i, color in ipairs(self.buffer) do
		local x = ((i - 1) % self.width) * w
		local y = math.floor((i - 1) / self.width) * h
		local r, g, b = color:match "(..)(..)(..)"
		r = tonumber("0x" .. r)
		g = tonumber("0x" .. g)
		b = tonumber("0x" .. b)
		love.graphics.setColor(r, g, b)
		love.graphics.rectangle("fill", x, y, w, h)
	end
	local msg = table.concat(self.buffer)
	if msg ~= self.msg and self.socket then
		self.msg = msg
		self.socket:send("03%s\r\n" % msg)
	end
end

