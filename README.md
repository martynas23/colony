# colony game lockscreen plugin for koreader


this is a koreader plugin that has been copied from this weather lock screen plugin (https://github.com/loeffner/WeatherLockscreen) 
and is being transformed into a game type thing. the premise of the idea is that you have a colony of survivalists living on your device, and they progress a day with each lock of the device.
very very early alpha at the moment, i honestly have no idea what i'm doing 

the way it's installed at the moment is by dropping the weatherlockscreen.koplugin folder into koreader/plugins
after you drop it in and restard koreader, it's gonna be up and working.

i think the only files are needed to run the game are _meta.lua, main.lua, and display_card.lua, but im not 100% sure 

### Initial Setup

1. Navigate to Tools > Weather Lockscreen
2. Set Display format to "minimal". this is where the game currently lives, in display_card.lua. any other selection will just show the weather like the og plugin does
3. Navigate to Settings > Screen > Sleep Screen > Wallpaper
4. Select "Show weather on sleep screen"

now whenever you lock your screen, the colony stats will appear, and they update every time you unlock and lock it again, this is the game

also the game save file is in koreader's root directory as colony_save.txt. you dont have to create it yourself the game does it for you
