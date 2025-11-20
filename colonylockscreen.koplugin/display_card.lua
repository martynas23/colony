local TextWidget = require("ui/widget/textwidget")
local VerticalGroup = require("ui/widget/verticalgroup")
local TopContainer = require("ui/widget/container/topcontainer")
local CenterContainer = require("ui/widget/container/centercontainer")
local OverlapGroup = require("ui/widget/overlapgroup")
local Font = require("ui/font")
local Device = require("device")
local Screen = Device.screen

local ColonySimulator = {}

-- ui fonts 
local FontTitle = Font:getFace("cfont", 40)
local FontBody  = Font:getFace("cfont", 16)

-- Load/save
local function loadGame()
    local f = io.open("colony_save.txt", "r")
    if f then
        local lines = {}
        for i = 1, 6 do
            lines[i] = f:read("*l")
        end
        f:close()
        if lines[1] and lines[2] and lines[3] and lines[4] and lines[5] and lines[6] then
            return {
                turn = tonumber(lines[1]),
                population = tonumber(lines[2]),
                food = tonumber(lines[3]),
                wood = tonumber(lines[4]),
                serek = tonumber(lines[5]),
                morale = tonumber(lines[6])
            }
        end
    end
    return nil
end

local function saveGame(state)
    local f = io.open("colony_save.txt", "w")
    if f then
        f:write(string.format("%d\n%d\n%d\n%d\n%d\n%d\n",
            state.turn, state.population, state.food,
            state.wood, state.serek, state.morale))
        f:close()
    end
end

-- Initialize state
if not ColonySimulator.state then
    local saved = loadGame()
    if saved and saved.population then
        ColonySimulator.state = saved
    else
        ColonySimulator.state = { turn = 1, population = 5, food = 20, wood = 15, serek = 10, morale = 75 }
    end
end

-- Game logic
local function clamp(val, min, max)
    if val < min then return min end
    if val > max then return max end
    return val
end

local function simulateTurn(state)
    -- Food consumption
    local food_needed = state.population * 2
    state.food = state.food - food_needed

    -- Gather resources
    local workers = math.floor(state.population * 0.6)
    state.food = state.food + math.random(4, 7) * workers
    state.wood = state.wood + math.random(1, 3) * workers
    state.serek = state.serek + math.random(0, 2) * workers

    -- Morale effects
    if state.food < 0 then
        state.morale = state.morale - 15
        state.population = math.max(1, state.population - 1)
        state.food = 0
    elseif state.food > 50 then
        state.morale = state.morale + 3
    end

    -- Population growth
    if state.morale > 80 and state.food > 30 then
        if math.random(1, 100) < 30 then state.population = state.population + 1 end
    elseif state.morale < 30 then
        if math.random(1, 100) < 20 then state.population = math.max(1, state.population - 1) end
    end

    -- this is so morale cannot leave bounds
    state.morale = clamp(state.morale, 0, 100)

    --random events - needs major rebalancing
    local event_msg = ""
    local event_roll = math.random(1, 100)
    if event_roll < 8 then
        state.population = state.population + math.random(1, 2)
        event_msg = "oyem some new schmuckkers came over"
    elseif event_roll < 15 then
        local loss = math.floor(state.food * 0.25)
        state.food = state.food - loss
        event_msg = "fuck some food spoiled"
    elseif event_roll < 22 then
        state.wood = state.wood + math.random(8, 15)
        event_msg = "ayesyes we got some lumber"
    end

    state.turn = state.turn + 1
    return event_msg
end

-- Create display
function ColonySimulator:create()
    local state = ColonySimulator.state
    local event = simulateTurn(state)
    saveGame(state)

    local status = "OK"
    if state.morale < 30 then status = "BAD"
    elseif state.morale > 80 then status = "GREAT" end

----------------------------title and days--------------------------------

local titleWidget = TextWidget:new{
    text = "Kosmolit's Colonists",
    face = FontTitle,
    align = "center"
}


local titleAndDays = TextWidget:new{
    text = "Kosmolit's Colonists  " .. string.format("day %d", state.turn),
    face = FontTitle,
    align = "center"
}


local separator = TextWidget:new{
    text = string.rep("-", 120),
    face = FontBody,
    align = "center"
}


local topGroup = VerticalGroup:new{
    align = "center",  -- just in case xd
    titleAndDays,
    separator
}

local titleContainer = TopContainer:new{
    dimen = Screen:getSize(),
    topGroup
}

------------------------------------------------------------------------


--game stats 2025-11-20 ill be moving most of this shit around especially resources gonna be at the bottom very soon
    local lines = {
        
        "------------------------------",
        string.format("colonists:%2d", state.population),
        string.format("food:%3d", state.food),
        string.format("wood:%3d", state.wood),
        string.format("serek:%3d", state.serek),
        string.format("morale:%2d%%", state.morale),
        "------------------------------",
        string.format("colony status is %-20s", status),
        event ~= "" and string.format(" %-28s", event) or "                            ",
        "------------------------------"
    }

    local widgets = {}
    for _, line in ipairs(lines) do
        table.insert(widgets, TextWidget:new{
            text = line,
            face = FontBody
        })
    end

    local infoGroup = VerticalGroup:new{
        align = "center",
        table.unpack(widgets)
    }

    local infoContainer = CenterContainer:new{
        dimen = Screen:getSize(),
        infoGroup
    }

    -- combine top and middle
    return OverlapGroup:new{
        dimen = Screen:getSize(),
        titleContainer,
        infoContainer
    }
end

return ColonySimulator

