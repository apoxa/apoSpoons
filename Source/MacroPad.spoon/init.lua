--- === MacroPad ===
---
--- This is a helper module for the JC Pro Macro 2 Pad. It needs appropiate code on the board!
--- It provides some useful functions and controls the LEDs on the board (not yet).
---
--- Things like mute and raiseHand support common meeting apps I use. If you need another one,
--- feel free to add the keyStrokes to the lists.
---
local application = require("hs.application")
local watchable = require("hs.watchable")
local logger = require("hs.logger")
local audiodevice = require("hs.audiodevice")

local obj = {}
obj.__index = obj

obj.watchables = watchable.new("macropad")
obj.watchables.micState = "off"

local function timestamp(date)
    date = date or require"hs.timer".secondsSinceEpoch()
    return os.date("%F %T" .. ((tostring(date):match("(%.%d+)$")) or ""), math.floor(date))
end

-- Metadata
obj.name = "MacroPad"
obj.version = "0.1.0"
obj.author = "Benjamin Stier <ben@unpatched.de>"
obj.homepage = "https://github.com/apoxa/hammerspoon-macropad"
obj.license = "MIT - https://opensource.org/licenses/MIT"

obj.logger = logger.new('MacroPad', 'verbose')

--- MacroPad.serialPort
--- Variable
--- The Serial port where the MacroPad is connected.
--- Default is usbmodemHIDPH1
obj.serialPort = 'usbmodemHIDPH1'

--- MacroPad.muteLED
--- Variable
--- A table with an LED definition for the Mute buttons
---
--- Notes:
--- * {
---      number = 0,
---      off = "0 0 0",
---      muted = "255 0 0",
---      unmuted = "0 255 0",
--- *}
obj.muteLED = {
    number = 0,
    off = "0 0 0",
    muted = "255 0 0",
    unmuted = "0 255 0"
}

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
    self.logger.d("toggleMute triggered")
    local mic = audiodevice.defaultInputDevice()
    if not mic:inUse() then
        obj.watchables.micState = 'off'
    elseif mic:inputMuted() then
        mic:setInputMuted(false)
    else
        mic:setInputMuted(true)
    end
end

--- MacroPad:raiseHand()
--- Method
--- It toggles the raised hand state on the first application it finds.
---
--- Parameters:
---  * None
function obj:raiseHand()
    self.logger.d("raiseHand triggered")
    self:tryAppButtons('raiseHandButtons', hs.fnutils.filter(self.meetingApps, function(meetingApp)
        return meetingApp.raiseHandButtons ~= nil
    end))
end

function obj:tryAppButtons(buttonType, apps)
    apps = apps or {}
    for appl in pairs(apps) do
        local app = application.get(appl)
        if app ~= nil then
            buttons = self.meetingApps[appl]
            self.logger.df("found app for keyStrokes: %s\n", appl)
            hs.eventtap.keyStroke(buttons[buttonType][1], buttons[buttonType][2], 0, app)
            return appl
        end
    end
end

function obj:_sendSerial(data)
    local _serialPort = hs.serial.newFromName(obj.serialPort)
    if _serialPort ~= nil then
        _serialPort:open()
        _serialPort:sendData(data)
        _serialPort:close()
    end
end

obj._micWatcher = watchable.watch('macropad', 'micState', function(_, _, _, _, new)
    obj.logger.df("Current Mic state is %s", new)
    if obj.muteLED[new] ~= nil then
        obj:_sendSerial(string.format("LED %s %s\r\n", obj.muteLED.number, obj.muteLED[new]))
    end
end)

function obj:init()
    self.meetingApps = {
        ['bbb'] = {
            raiseHandButtons = {{'ctrl', 'alt'}, 'r'}
        },
        ['com.microsoft.teams'] = {
            raiseHandButtons = {{'cmd', 'shift'}, 'k'}
        },
        ['us.zoom.xos'] = {
            raiseHandButtons = {'alt', 'y'}
        }
    }
    return self
end

function obj:start()
    audiodevice.defaultInputDevice():watcherCallback(function(UID, event, scope, element)
        obj.logger.vf("UID <%s>, event <%s>, scope <%s>, element <%s>", UID, event, scope, element)
        if (event == 'gone' and scope == 'glob') then
            if audiodevice.findDeviceByUID(UID):inUse() then
                obj.watchables.micState = audiodevice.findDeviceByUID(UID):inputMuted() and 'muted' or 'unmuted'
            else
                obj.watchables.micState = 'off'
            end
        end
        if (event == 'mute' and scope == 'inpt') then
            obj.watchables.micState = audiodevice.findDeviceByUID(UID):inputMuted() and 'muted' or 'unmuted'
        end
    end):watcherStart()
    return self
end

function obj:stop()
    self._micWatcher:release()
    audiodevice.watcher.stop()
    audiodevice.defaultInputDevice():watcherStop()
    return self
end

return obj
