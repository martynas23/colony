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
local Widget = require("ui/widget/widget")
local ImageWidget = require("ui/widget/imagewidget")

local ColonySimulator = {}

-- ui fonts 
local FontTitle = Font:getFace("cfont", 40)
local FontBody  = Font:getFace("cfont", 16)
local FontStats = Font:getFace("cfont", 30)

---------------------------------------------------------
-- saving / loading
---------------------------------------------------------
local function loadGame()
    local f = io.open("colony_save.txt", "r")
    if f then
        local lines = {}
        for i = 1, 6 do
            lines[i] = f:read("*l")
        end
        f:close()
        if lines[1] then
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

---------------------------------------------------------
-- game logic
---------------------------------------------------------
local function clamp(val, min, max)
    if val < min then return min end
    if val > max then return max end
    return val
end

-- for the turn report
local function simulateTurn(state)
    local report = {
        food_gained = 0,
        wood_gained = 0,
        gold_gained = 0,
        pop_change = 0,
        morale_change = 0,
        event = ""
    }

    local before = {
        food = state.food,
        wood = state.wood,
        gold = state.gold,
        pop = state.population,
        morale = state.morale
    }

    -- food consumption
    local food_needed = state.population * 2
    state.food = state.food - food_needed

    -- production
    local workers = math.floor(state.population * 0.6)
    local fg = math.random(4, 7) * workers
    local wg = math.random(1, 3) * workers
    local gg = math.random(0, 2) * workers

    state.food = state.food + fg
    state.wood = state.wood + wg
    state.gold = state.gold + gg

    report.food_gained = fg
    report.wood_gained = wg
    report.gold_gained = gg

    -- morale effect
    if state.food < 0 then
        state.morale = state.morale - 15
        state.population = math.max(1, state.population - 1)
        state.food = 0
    elseif state.food > 50 then
        state.morale = state.morale + 3
    end

    -- pop change
    if state.morale > 80 and state.food > 30 then
        if math.random(1, 100) < 30 then
            state.population = state.population + 1
        end
    elseif state.morale < 30 then
        if math.random(1, 100) < 20 then
            state.population = math.max(1, state.population - 1)
        end
    end

    -- random events
    local event_roll = math.random(1, 100)
    if event_roll < 8 then
        local inc = math.random(1, 2)
        state.population = state.population + inc
        report.event = "oyesyes wem got some new schmuckkers(+" .. inc .. ")"
    elseif event_roll < 15 then
        local loss = math.floor(state.food * 0.25)
        state.food = state.food - loss
        report.event = "kurwa geci some food rotted away (-" .. loss .. ")"
    elseif event_roll < 22 then
        local gain = math.random(8, 15)
        state.wood = state.wood + gain
        report.event = "oyempthve we got some wood (+" .. gain .. ")"
    end

    report.pop_change = state.population - before.pop
    report.morale_change = state.morale - before.morale

    state.morale = clamp(state.morale, 0, 100)
    state.turn = state.turn + 1

    return report
end

---------------------------------------------------------
-- ui
---------------------------------------------------------
function ColonySimulator:create()
    local state = ColonySimulator.state
    local report = simulateTurn(state)
    saveGame(state)

    local status = "OK"
    if state.morale < 30 then status = "BAD"
    elseif state.morale > 80 then status = "GREAT" end

    -----------------------------------------------------
    -- top bar for game name and day number
    -----------------------------------------------------
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

    -----------------------------------------------------
    -- middle section with image
    -----------------------------------------------------
   
    local imageWidget = ImageWidget:new{
        file = "plugins/colonylockscreen.koplugin/img/1.png",
        width = 500,
        height = 600,
        scale = false,
        centeredh = true,
        centeredv = true,
        alpha = true, --need this for transparency
    }

    local infoLines = {

        --string.format("colony status is %-20s", status),
        --this shit is kinda depricated at this point but there might be some uses for it later well see

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
        imageWidget,
        table.unpack(infoWidgets)
    }

    local infoContainer = CenterContainer:new{
        dimen = Screen:getSize(),
        infoGroup
    }

    -----------------------------------------------------
    -- report of the last turn (above the stats bar)
    -----------------------------------------------------
    local reportLines = {
        "Last Turn:",
        string.format(" F:   %d", report.food_gained),
        string.format(" W   %d", report.wood_gained),
        string.format(" G:   %d", report.gold_gained),
        string.format(" Pop:    %+d", report.pop_change),
    }

    -- main stats line
    local mainStatsText = table.concat({
        reportLines[1],
        reportLines[2],
        reportLines[3],
        reportLines[4],
        reportLines[5],
    }, "   |   ")

    local mainStatsWidget = TextWidget:new{
        text = mainStatsText,
        face = FontBody,
        align = "center",
        halign = "center",
    }

    -- event line with manual wrapping
    local eventText = report.event ~= "" and (" Event: " .. report.event) or " Event: none"
    local maxCharsPerLine = 75
    local eventLines = {}
    
    if #eventText > maxCharsPerLine then
        local remaining = eventText
        while #remaining > 0 do
            if #remaining <= maxCharsPerLine then
                table.insert(eventLines, remaining)
                break
            else
                local line = remaining:sub(1, maxCharsPerLine)
                table.insert(eventLines, line)
                remaining = remaining:sub(maxCharsPerLine + 1)
            end
        end
    else
        table.insert(eventLines, eventText)
    end
    
    local eventWidgets = {}
    for _, line in ipairs(eventLines) do
        table.insert(eventWidgets, TextWidget:new{
            text = line,
            face = FontBody,
            align = "center",
            halign = "center",
        })
    end
    
    local eventWidget = VerticalGroup:new{
        align = "center",
        table.unpack(eventWidgets)
    }

    local reportSeparatorTop = LineWidget:new{ dimen = { w = Screen:getWidth(), h = 3 } }
    local reportSeparatorBottom = LineWidget:new{ dimen = { w = Screen:getWidth(), h = 3 } }
    local reportPadding = Widget:new{ dimen = { w = 0, h = 10 } }

    local reportBar = VerticalGroup:new{
        halign = "center",
        reportPadding,
        reportSeparatorTop,
        mainStatsWidget,
        eventWidget,
        reportSeparatorBottom,
    }

    -----------------------------------------------------
    -- bottom bar - stats
    -----------------------------------------------------
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

    local statsSeparatorTop = LineWidget:new{ dimen = { w = Screen:getWidth(), h = 3 } }
    local statsSeparatorBottom = LineWidget:new{ dimen = { w = Screen:getWidth(), h = 3 } }
    local statsPadding = Widget:new{ dimen = { w = 0, h = 10 } }

    local statsBar = VerticalGroup:new{
        halign = "center",
        statsPadding,
        statsSeparatorTop,
        statsWidget,
        statsSeparatorBottom,
    }

    -----------------------------------------------------
    -- combine the bottom bars
    -----------------------------------------------------
    local bottomBars = VerticalGroup:new{
        halign = "center",
        reportBar,
        statsBar
    }

    local bottomContainer = BottomContainer:new{
        dimen = Screen:getSize(),
        bottomBars
    }

    -----------------------------------------------------
    -- entire screen stack
    -----------------------------------------------------
    return OverlapGroup:new{
        dimen = Screen:getSize(),
        titleContainer,
        infoContainer,
        bottomContainer
    }
end

return ColonySimulator