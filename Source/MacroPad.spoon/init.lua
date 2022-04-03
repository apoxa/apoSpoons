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
    unmuted = "0 255 0",
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
    self.logger.v("toggleMute triggered")
    triggeredApp = self:tryAppButtons('muteButtons', hs.fnutils.filter(self.meetingApps, function(meetingApp)
        return meetingApp.muteButtons ~= nil
    end))
    if triggeredApp == nil then return end
    if (self.meetingApps[triggeredApp].checkAudio ~= nil) then
        state = self.meetingApps[triggeredApp].checkAudio() or 'off'
        self.logger.df("Current Mic State in %s is %s", triggeredApp, state)
        self.logger.df("Sending LED to %s with color %s", self.muteLED.number, self.muteLED[state])
        self:_sendSerial(string.format("LED %s %s\r\n", self.muteLED.number, self.muteLED[state]))
    end
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
            return application
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

function obj:_checkZoomAudio()
    local check = hs.application.get("us.zoom.xos")
    if (check ~= nil) then
        if check:findMenuItem({"Meeting", "Unmute Audio"}) then
            return 'muted'
        elseif check:findMenuItem({"Meeting", "Mute Audio"}) then
            return "unmuted"
        else
            return "off"
        end
    end
end

function obj:_checkTeamsAudio()
    local check = hs.application.get("com.microsoft.teams")
    local axApp = hs.axuielement.applicationElement(check)
    -- Fix accessability API in electron App
    axApp:setAttributeValue('AXManualAccessibility', true)
    -- AXDescription = "Mute (⌘+Shift+M)"
    -- AXDescription = "Unmute (⌘+Shift+M)",
    MicButtonSearch = hs.axuielement.searchCriteriaFunction({
        { attribute = "AXDOMIdentifier", value = "microphone-button" }
    })
    for i, window in ipairs(axApp.AXWindows) do
        if window.AXTitle:match('Meeting in') then
            axMicButton = window:elementSearch(nil, MicButtonSearch, {noCallback = true})[1]
            if axMicButton == nil then
                self.logger.d("Can't find Teams Mic Mute Button")
                return
            end
            if axMicButton.AXDescription:match("Unmute") then
                return 'muted'
            elseif axMicButton.AXDescription:match("Mute") then
                return 'unmuted'
            else
                return 'off'
            end
        end
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
            checkAudio = hs.fnutils.partial(self._checkTeamsAudio, self),
        },
        ['us.zoom.xos'] = {
            muteButtons = {{'cmd', 'shift'}, 'm'},
            raiseHandButtons = {'alt', 'y'},
            checkAudio = hs.fnutils.partial(self._checkZoomAudio, self),
        },
        ['com.hnc.Discord'] = {
            muteButtons = {{"cmd", "shift"}, "a"},
        },
    }
end

return obj
