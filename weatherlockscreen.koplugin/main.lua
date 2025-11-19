--[[
    Weather Lockscreen Plugin for KOReader

    Displays weather information on the sleep screen.

    Author: Andreas Lösel
    License: GNU AGPL v3
--]]

local WidgetContainer = require("ui/widget/container/widgetcontainer")
local UIManager = require("ui/uimanager")
local Device = require("device")
local Screen = Device.screen
local DataStorage = require("datastorage")
local ImageWidget = require("ui/widget/imagewidget")
local TextWidget = require("ui/widget/textwidget")
local VerticalGroup = require("ui/widget/verticalgroup")
local CenterContainer = require("ui/widget/container/centercontainer")
local LeftContainer = require("ui/widget/container/leftcontainer")
local RightContainer = require("ui/widget/container/rightcontainer")
local OverlapGroup = require("ui/widget/overlapgroup")
local FrameContainer = require("ui/widget/container/framecontainer")
local Font = require("ui/font")
local Blitbuffer = require("ffi/blitbuffer")
local ScreenSaverWidget = require("ui/widget/screensaverwidget")
local InputDialog = require("ui/widget/inputdialog")
local logger = require("logger")
local _ = require("gettext")
local T = require("ffi/util").template
local WeatherUtils = require("weather_utils")

local WeatherLockscreen = WidgetContainer:extend {
    name = "weatherlockscreen",
    is_doc_only = false,
    default_location = "London",
    default_api_key = "637e03f814b440f782675255250411",
    default_temp_scale = "C",
}

function WeatherLockscreen:getPluginDir()
    return WeatherUtils:getPluginDir()
end

function WeatherLockscreen:init()
    self.ui.menu:registerToMainMenu(self)
    self:patchScreensaver()
end

function WeatherLockscreen:addToMainMenu(menu_items)
    menu_items.weather_lockscreen = {
        text = _("Weather Lockscreen"),
        sub_item_table_func = function()
            return self:getSubMenuItems()
        end,
        sorting_hint = "tools",
    }
end

function WeatherLockscreen:getSubMenuItems()
    local menu_items = {
    }
    return menu_items
end

function WeatherLockscreen:patchScreensaver()
    -- Store reference to self for use in closures
    local plugin_instance = self

    -- Hook into Screensaver.show() to handle "weather" type
    local Screensaver = require("ui/screensaver")

    -- Save original show method if not already saved
    if not Screensaver._orig_show_before_weather then
        Screensaver._orig_show_before_weather = Screensaver.show
    end

    Screensaver.show = function(screensaver_instance)
        if screensaver_instance.screensaver_type == "weather" then
            logger.dbg("WeatherLockscreen: Weather screensaver activated")

            -- Close any existing screensaver widget
            if screensaver_instance.screensaver_widget then
                UIManager:close(screensaver_instance.screensaver_widget)
                screensaver_instance.screensaver_widget = nil
            end

            -- Set device to screen saver mode
            Device.screen_saver_mode = true

            -- Handle rotation if needed
            local rotation_mode = Screen:getRotationMode()
            Device.orig_rotation_mode = rotation_mode
            local bit = require("bit")
            if bit.band(Device.orig_rotation_mode, 1) == 1 then
                Screen:setRotationMode(Screen.DEVICE_ROTATED_UPRIGHT)
            else
                Device.orig_rotation_mode = nil
            end

            -- Create weather widget
            local weather_widget, fallback = plugin_instance:createWeatherWidget()

            if weather_widget then
                local bg_color = Blitbuffer.COLOR_WHITE
                local display_style = "display_card"

                screensaver_instance.screensaver_widget = ScreenSaverWidget:new {
                    widget = weather_widget,
                    background = bg_color,
                    covers_fullscreen = true,
                }
                screensaver_instance.screensaver_widget.modal = true
                screensaver_instance.screensaver_widget.dithered = true

                UIManager:show(screensaver_instance.screensaver_widget, "full")
                logger.dbg("WeatherLockscreen: Widget displayed")
            else
                logger.warn("WeatherLockscreen: Failed to create widget, falling back")
                screensaver_instance.screensaver_type = "disable"
                Screensaver._orig_show_before_weather(screensaver_instance)
            end
        else
            Screensaver._orig_show_before_weather(screensaver_instance)
        end
    end

    -- Patch the screensaver menu to add weather option
    -- We need to override dofile to inject our menu item
    if not _G._orig_dofile_before_weather then
        local orig_dofile = dofile
        _G._orig_dofile_before_weather = orig_dofile

        _G.dofile = function(filepath)
            local result = orig_dofile(filepath)

            -- Check if this is the screensaver menu being loaded
            if filepath and filepath:match("screensaver_menu%.lua$") then
                logger.dbg("WeatherLockscreen: Patching screensaver menu")

                if result and result[1] and result[1].sub_item_table then
                    local wallpaper_submenu = result[1].sub_item_table

                    local function genMenuItem(text, setting, value, enabled_func, separator)
                        return {
                            text = text,
                            enabled_func = enabled_func,
                            checked_func = function()
                                return G_reader_settings:readSetting(setting) == value
                            end,
                            callback = function()
                                G_reader_settings:saveSetting(setting, value)
                            end,
                            radio = true,
                            separator = separator,
                        }
                    end

                    -- Add weather option
                    local weather_item = genMenuItem(_("Show weather on sleep screen"), "screensaver_type", "weather")

                    -- Insert before "Leave screen as-is" option (position 6)
                    table.insert(wallpaper_submenu, 6, weather_item)

                    logger.dbg("WeatherLockscreen: Added weather option to screensaver menu")
                end

                -- Restore original dofile after patching
                _G.dofile = orig_dofile
                _G._orig_dofile_before_weather = nil
            end

            return result
        end
    end
end


function WeatherLockscreen:createWeatherWidget()
    -- Load appropriate display module
    -- aka the one i see you're using
    display_module = require("display_card")

    return display_module:create(self, weather_data), fallback
end

return WeatherLockscreen
