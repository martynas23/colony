local TextWidget = require("ui/widget/textwidget")
local VerticalGroup = require("ui/widget/verticalgroup")
local TopContainer = require("ui/widget/container/topcontainer")
local CenterContainer = require("ui/widget/container/centercontainer")
local BottomContainer = require("ui/widget/container/bottomcontainer") 
local OverlapGroup = require("ui/widget/overlapgroup")
local Font = require("ui/font")
local Device = require("device")
local Screen = Device.screen
local LineWidget = require("ui/widget/linewidget")
local Size = require("ui/size")
local FrameContainer = require("ui/widget/container/framecontainer")
local Widget = require("ui/widget/widget")

local ColonySimulator = {}

-- ui fonts 
local FontTitle = Font:getFace("cfont", 40)
local FontBody  = Font:getFace("cfont", 16)
local FontStats = Font:getFace("cfont", 30)



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
                gold = tonumber(lines[5]),
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
            state.wood, state.gold, state.morale))
        f:close()
    end
end


if not ColonySimulator.state then
    local saved = loadGame()
    if saved and saved.population then
        ColonySimulator.state = saved
    else
        ColonySimulator.state = { turn = 1, population = 5, food = 20, wood = 15, gold = 10, morale = 75 }
    end
end

--game logic
local function clamp(val, min, max)
    if val < min then return min end
    if val > max then return max end
    return val
end

local function simulateTurn(state)
    -- food
    local food_needed = state.population * 2
    state.food = state.food - food_needed

    -- resources per day
    local workers = math.floor(state.population * 0.6)
    state.food = state.food + math.random(4, 7) * workers
    state.wood = state.wood + math.random(1, 3) * workers
    state.gold = state.gold + math.random(0, 2) * workers

    -- morale
    if state.food < 0 then
        state.morale = state.morale - 15
        state.population = math.max(1, state.population - 1)
        state.food = 0
    elseif state.food > 50 then
        state.morale = state.morale + 3
    end

    -- colonist growth
    if state.morale > 80 and state.food > 30 then
        if math.random(1, 100) < 30 then state.population = state.population + 1 end
    elseif state.morale < 30 then
        if math.random(1, 100) < 20 then state.population = math.max(1, state.population - 1) end
    end

    state.morale = clamp(state.morale, 0, 100)

    -- random events
    local event_msg = ""
    local event_roll = math.random(1, 100)
    if event_roll < 8 then
        state.population = state.population + math.random(1, 2)
        event_msg = "oyesyes wem got some new schmuckkers"
    elseif event_roll < 15 then
        local loss = math.floor(state.food * 0.25)
        state.food = state.food - loss
        event_msg = "gedi szmatstwo we lost food"
    elseif event_roll < 22 then
        state.wood = state.wood + math.random(8, 15)
        event_msg = "oyempthve got wood"
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

---------------------------- top bar -------------------------------
    local titleAndDays = TextWidget:new{
        text = "Kosmolit's Colonists  | Day " .. state.turn,
        face = FontTitle,
        align = "center",
        halign = "center",
    }

    local topSeparatorTop = LineWidget:new{ dimen = { w = Screen:getWidth(), h = 3 } }
    local topSeparatorBottom = LineWidget:new{ dimen = { w = Screen:getWidth(), h = 3 } }
    local topPadding = Widget:new{ dimen = { w = 0, h = 10 } }

    local topGroup = VerticalGroup:new{
        halign = "center",
        topPadding,
        topSeparatorTop,
        titleAndDays,
        topSeparatorBottom,
    }

    local titleContainer = TopContainer:new{
        dimen = Screen:getSize(),
        topGroup
    }
------------------------------------------------------------------------

---------------------------- bottom bar ----------------------------
    local statsText = string.format(
        "Pop:%d  F:%d  W:%d  G:%d  M:%d%%",
        state.population,
        state.food,
        state.wood,
        state.gold,
        state.morale
    )

    local statsWidget = TextWidget:new{
        text = statsText,
        face = FontStats,
        align = "center",
        halign = "center",
    }

    local bottomSeparatorTop = LineWidget:new{ dimen = { w = Screen:getWidth(), h = 3 } }
    local bottomSeparatorBottom = LineWidget:new{ dimen = { w = Screen:getWidth(), h = 3 } }
    local bottomPadding = Widget:new{ dimen = { w = 0, h = 10 } }

    local bottomGroup = VerticalGroup:new{
        halign = "center",
        bottomPadding,
        bottomSeparatorTop,
        statsWidget,
        bottomSeparatorBottom,
    }

    local bottomContainer = BottomContainer:new{
        dimen = Screen:getSize(),
        bottomGroup
    }
------------------------------------------------------------------------

---------------------------- main content / info -------------------
    local infoLines = {
        "------------------------------",
        string.format("colony status is %-20s", status),
        event ~= "" and string.format(" %-28s", event) or "                            ",
        "------------------------------"
    }

    local infoWidgets = {}
    for _, line in ipairs(infoLines) do
        table.insert(infoWidgets, TextWidget:new{
            text = line,
            face = FontBody
        })
    end

    local infoGroup = VerticalGroup:new{
        align = "center",
        table.unpack(infoWidgets)
    }

    local infoContainer = CenterContainer:new{
        dimen = Screen:getSize(),
        infoGroup
    }
------------------------------------------------------------------------

    return OverlapGroup:new{
        dimen = Screen:getSize(),
        titleContainer,
        infoContainer,
        bottomContainer
    }
end

return ColonySimulator

