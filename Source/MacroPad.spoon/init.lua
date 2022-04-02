--- === MacroPad ===
---
--- This is a helper module for the JC Pro Macro 2 Pad. It needs appropiate code on the board!
--- It provides some useful functions and controls the LEDs on the board (not yet).
---
--- Things like mute and raiseHand support common meeting apps I use. If you need another one,
--- feel free to add the keyStrokes to the lists.
---

local obj = {}
obj.__index = obj

-- Metadata
obj.name = "MacroPad"
obj.version = "0.1.0"
obj.author = "Benjamin Stier <ben@unpatched.de>"
obj.homepage = "https://github.com/apoxa/hammerspoon-macropad"
obj.license = "MIT - https://opensource.org/licenses/MIT"

obj.logger = hs.logger.new('MacroPad')

--- MacroPad.serialPort
--- Variable
--- The Serial port where the MacroPad is connected.
--- Default is usbmodemHIDPH1
obj.serialPort = 'usbmodemHIDPH1'

--- MacroPad:bindHotkeys(mapping)
--- Method
--- Binds hotkeys for ReloadConfiguration
---
--- Parameters:
---  * mapping - A table containing hotkey modifier/key details for the following items:
---   * toggleMute - This will toggle MicMute in meeting apps like Teams and Zoom
function obj:bindHotkeys(mapping)
    local def = {
        toggleMute = hs.fnutils.partial(self.toggleMute, self),
        raiseHand = hs.fnutils.partial(self.raiseHand, self)
    }
    hs.spoons.bindHotkeysToSpec(def, mapping)
end

--- MacroPad:toggleMute()
--- Method
--- It toggles the microphone mute state on the first application it finds.
---
--- Parameters:
---  * None
function obj:toggleMute()
    self.logger.v("toggleMute triggered")
    self:tryAppButtons('muteButtons', hs.fnutils.filter(self.meetingApps, function(meetingApp)
        return meetingApp.muteButtons ~= nil
    end))
end

--- MacroPad:raiseHand()
--- Method
--- It toggles the raised hand state on the first application it finds.
---
--- Parameters:
---  * None
function obj:raiseHand()
    self.logger.v("raiseHand triggered")
    self:tryAppButtons('raiseHandButtons', hs.fnutils.filter(self.meetingApps, function(meetingApp)
        return meetingApp.raiseHandButtons ~= nil
    end))
end

function obj:tryAppButtons(buttonType, apps)
    apps = apps or {}
    for application in pairs(apps) do
        local app = hs.application.get(application)
        if app ~= nil then
            buttons = self.meetingApps[application]
            self.logger.df("found app for keyStrokes: %s\n", application)
            hs.eventtap.keyStroke(buttons[buttonType][1], buttons[buttonType][2], 0, app)
            break
        end
    end
end

function sendSerial(data)
    local _serialPort = hs.serial.newFromName(obj.serialPort)
    if _serialPort ~= nil then
        _serialPort:open()
        _serialPort:sendData(data)
        _serialPort:close()
    end
end

function obj:init()
    self.meetingApps = {
        ['bbb'] = {
            muteButtons = {{'ctrl', 'alt'}, 'm'},
            raiseHandButtons = {{'ctrl', 'alt'}, 'r'},
        },
        ['com.microsoft.teams'] = {
            muteButtons = {{'cmd', 'shift'}, 'm'},
            raiseHandButtons = {{'cmd', 'shift'}, 'k'},
        },
        ['us.zoom.xos'] = {
            muteButtons = {{'cmd', 'shift'}, 'm'},
            raiseHandButtons = {'alt', 'y'},
        },
        ['com.hnc.Discord'] = {
            muteButtons = {{"cmd", "shift"}, "a"},
        },
    }
end

return obj
