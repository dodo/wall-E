require "helper"
require "wall"
require "framework"

-- values

nr = 32
env = {
    stars = {level=3},
}



-- helpervalues
-- local __maxbound = 1.5
-- local __reznr = 1 / (nr*0.1) -- / (nr*3)
-- local __maxd = 0


local operator = {
    ["+"]=function(a,b)return a+b end,
    ["-"]=function(a,b)return a-b end}

--------------------------------------------------------------------------------

function starlight(t) -- temperature in kelvin
    local max = 50
    t = math.min(30000,math.max(0,t))
    if t < 3500 then
        return math.ceil(t/3500*max), 0, 0
    elseif t < 6000 then
        return max, math.ceil((t-3500)/2500*max), 0
    elseif t < 10000 then
        return max, max, math.ceil((t-6000)/4000*max)
    else
        local r = max - math.ceil((t-10000)/20000*max)
        return r, r, max
    end
end

--------------------------------------------------------------------------------

Vector = Object:new()
function Vector:init(opts)
    opts = opts or {}
    self.x = opts.x or 0.0
    self.y = opts.y or 0.0
end

function Vector:clone()
    return Vector(self)
end

function Vector:add(vec)
    self.x = self.x + vec.x
    self.y = self.y + vec.y
    return self -- chainable
end

function Vector:sub(vec)
    self.x = self.x - vec.x
    self.y = self.y - vec.y
    return self -- chainable
end

function Vector:mul(val)
    if type(val) == 'number' then
        self.x = self.x * val
        self.y = self.y * val
    else
        self.x = self.x * val.x
        self.y = self.y * val.y
    end
    return self -- chainable
end

function Vector:dot(vec)
    return self.x * vec.x + self.y * vec.y
end

function Vector:len()
    return math.sqrt(self:dot(self))
end

function Vector:norm()
    local len = self:len()
    if len < 0.00000001 then
        self:mul(0)
    else
        self:mul(1/len)
    end
    return self -- chainable
end

--------------------------------------------------------------------------------

Star = Object:new()
function Star:init(opts)
    opts = opts or {}
    self.pos = Vector(opts)
    self.dir = Vector(opts.dir)
    self.color = opts.color or hex( 20, 20, 0 )
end

function Star:update()
    self.pos:add(self.dir)
    self.pos.x = inroundbound(self.pos.x, 0, wall.width)
    self.pos.y = inroundbound(self.pos.y, 0, wall.height)

    if #(env.player._state) > 0 then
        for _, oc in ipairs(env.player._state) do
            local o, c = oc:sub(1,1), oc:sub(2)
            self.dir[c] = operator[o](self.dir[c], -0.6)
        end
        self.dir:norm():mul(0.6)
    else
        self.dir:norm():mul(0.1)
    end
end

function Star:draw()
    local x, y = self.pos.x, self.pos.y
    wall:pixel(round(x), round(y), self.color)
end

--------------------------------------------------------------------------------

Player = Object:new()
function Player:init(opts)
    opts = opts or {}
    self.pos = Vector(opts)
    self.coords = self.pos:clone()
    self.color = opts.color or hex(200, 200, 200)
    self._state = {}
    self.projectiles = setmetatable({length=0}, { __mode = 'k' })
end

function Player:update()
    local newstate = {}
    for dir, oc in pairs({left="-x", right="+x", up="-y", down="+y" }) do
        if wall.input[1][dir] then
            local o, c = oc:sub(1,1), oc:sub(2)
            self.pos[c] = operator[o](self.pos[c], 0.5)
            table.insert(newstate, oc)
        end
    end
    local cx, cy
    self.pos.x, cx = inroundbound_with_count(self.pos.x, 0, wall.width)
    self.pos.y, cy = inroundbound_with_count(self.pos.y, 0, wall.height)
    self.coords:add { x = -cx * wall.width, y = -cy * wall.height }
    if #newstate > 0 then
        self._state = newstate
    end

    -- halt
    if wall.input[1].b then
        self._state = {}
    end

    -- direction
    local dir = Vector()
    for _, oc in ipairs(self._state) do
        local o, c = oc:sub(1,1), oc:sub(2)
        dir[c] = operator[o](dir[c], 1)
    end
    self.coords:add(dir)
--     print(self.coords.x, self.coords.y)

    -- shoot
    if wall.input[1].a and self.projectiles.length <3 then
        if dir:len() > 0 then
            local projectile = Projectile {
                source  = self,
                x = self.pos.x+1,
                y = self.pos.y+1,
                dir = dir:norm():mul(0.8),
            }
            projectile.life = projectile -- self reference
            self.projectiles[projectile] = projectile
            self.projectiles.length = self.projectiles.length + 1
        end
    end

    for key, projectile in pairs(self.projectiles) do
        if key ~= "length" then
            projectile:update()
        end
    end

end

function Player:draw()
    for key, projectile in pairs(self.projectiles) do
        if key ~= "length" then
            projectile:draw()
        end
    end

    local x, y = floor(self.pos.x), floor(self.pos.y)
    wall:pixel(x, y, self.color)

    if #(self._state) > 0 then
        for _, oc in ipairs(self._state) do
            local o, c = oc:sub(1,1), oc:sub(2)
            local coord = { x=x , y=y }
            coord[c] = operator[o](coord[c], -1)
            coord[c] = inbound(coord[c], 1, wall[({x="width",y="height"})[c]])
            wall:pixel(coord.x, coord.y, self.color)
        end
    end

end

--------------------------------------------------------------------------------

Target = Object:new()
function Target:init(opts)
    opts = opts or {}
    self.coords = Vector(opts)
    self.color = opts.color or hex(0, 180, 0)
    self.away_color = opts.away_color or hex(0, 60, 0)
    self.source = opts.source
    if not self.source then
        error("no source given")
    end
end

function Target:update()

end

function Target:draw()
    local pos = self.coords:clone():sub(self.source.coords):add(self.source.pos)
    local x,y
    x = inbound(pos.x, 1, wall.width)
    y = inbound(pos.y, 1, wall.height)
    local color = self.color
    if pos.x ~= x or pos.y ~= y then
        color = self.away_color
    end
    wall:pixel(floor(x-1), floor(y-1), color)
end

--------------------------------------------------------------------------------
Enemy = Object:new()
function Enemy:init(opts)
    opts = opts or {}
    self.coords = Vector(opts)
    self.dir = Vector(opts.dir)
    self.color = opts.color or hex(180, 0, 0)
    self.away_color = opts.away_color or hex(60, 0, 0)
    self.source = opts.source
    if not self.source then
        error("no source given")
    end
end

function Enemy:update()
    self.coords:add(self.dir)

end

function Enemy:draw()
    local pos = self.coords:clone():sub(self.source.coords):add(self.source.pos)
    local x,y
    x = inbound(pos.x, 1, wall.width)
    y = inbound(pos.y, 1, wall.height)
    local color = self.color
    if pos.x ~= x or pos.y ~= y then
        color = self.away_color
    end
    wall:pixel(floor(x-1), floor(y-1), color)
end


--------------------------------------------------------------------------------

Projectile = Object:new()
function Projectile:init(opts)
    opts = opts or {}
    self.pos = Vector(opts)
    self.dir = Vector(opts.dir)
    self.color = opts.color or hex(180, 20, 0)
    self.energy = opts.energy or 10
    self.max_energy = self.energy
    self.life = nil -- will be set by parent
    self.source = opts.source
    if not self.source then
        error("no source given")
    end
end

function Projectile:update()
    if self.life == nil then return end
    self.energy = self.energy - 1
    if self.energy == 0 then
        self.source.projectiles[self] = nil
        self.source.projectiles.length = self.source.projectiles.length - 1
        self.life = nil -- delete, or just simply die
        return
    end
    local rel_energy = self.energy/self.max_energy
    if rel_energy > 0.2 then
        local dir = Vector()
        for _, oc in ipairs(self.source._state) do
            local o, c = oc:sub(1,1), oc:sub(2)
            dir[c] = operator[o](dir[c], 1)
        end
        self.pos:add(dir:norm():mul(rel_energy))
    end
    self.pos:add(self.dir)
end

function Projectile:draw()
    if self.life == nil then return end
    if self.pos.x == inbound(self.pos.x, 1, wall.width) and
       self.pos.y == inbound(self.pos.y, 1, wall.height) then
        wall:pixel(round(self.pos.x-1), round(self.pos.y-1), self.color)
    end
end

--------------------------------------------------------------------------------

function update()
    wall:update_input()

    for y = 1, wall.height do
        for x = 1, wall.width do
            wall:pixel(x-1, y-1, hex(0,0,0))
        end
    end

    for level = 1, env.stars.level do
        if tick%level == 0 then
            for _, star in ipairs(env.stars[level] or {}) do
                star:update()
            end
        end
    end

    env.player:update()

    for _, target in ipairs(env.targets or {}) do
        target:update()
    end

    for _, enemy in ipairs(env.enemys or {}) do
        enemy:update()
    end

    tick = tick + 1
end

function draw()

    for level = 1, env.stars.level do
        if tick%(level*10) then
            for _, star in ipairs(env.stars[level] or {}) do
                star:draw()
            end
        end
    end

    for _, target in ipairs(env.targets or {}) do
        target:draw()
    end

    for _, enemy in ipairs(env.enemys or {}) do
        enemy:draw()
    end

    env.player:draw()

end

--------------------------------------------------------------------------------

function love.load()
    wall = Wall(false, 1338, 3, false) -- "176.99.24.251"

--     __maxd = math.sqrt(wall.width*wall.height)

    time = love.timer.getTime() * 1000

    tick = 0


    -- initialize

    for level = 1, env.stars.level do
        env.stars[level] = env.stars[level] or {}
        for i = 1, 10 do
            star = Star {
                x = (R()*wall.width),
                y = (R()*wall.height),
                dir = {
                    x = (R()*0.2),
                    y = (R()*0.08-0.04),
                },
                color = hex( starlight(((174-level*20)*R())^2) ),
--                 color = hex( starlight(30000*R()) ),
            }

--             env.stars[1][(level-1)*10+i] = star
            env.stars[level][i] = star

        end
    end

    env.player = Player {
        x = wall.width*0.5,
        y = wall.height*0.5,
    }

    env.targets = {}
    env.targets[1] = Target {
        source = env.player,
        x = 0,
        y = 0,
    }

    env.enemys = {}
    env.enemys[1] = Enemy {
        source = env.player,
        x = 3,
        y = 3,
        dir = {x=-0.01, y=-0.01}
    }
end


function love.keypressed(key)
    if key == "escape" then
        love.event.push "q"
    end
end

function love.update(dt)
    -- constant 30 FPS
    local t = love.timer.getTime() * 1000
    time = time + 1000 / 30
    love.timer.sleep(time - t)

    update()
end


function love.draw()
    draw()
    -- send the stuff abroad
    wall:draw()
end
