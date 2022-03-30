local obj = {}
obj.__index = obj

-- Metadata
obj.name = "MacroPad"
obj.version = "0.1"
obj.author = "Benjamin Stier <ben@unpatched.de>"
obj.homepage = "https://github.com/apoxa/hammerspoon-macropad"
obj.license = "MIT - https://opensource.org/licenses/MIT"

obj.logger = hs.logger.new('MacroPad', 'info')

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

function obj:toggleMute()
    self.logger.d("toggleMute triggered")
    local AppMuteButtons = {
        ['bbb'] = {{"ctrl", "alt"}, "m"},
        ['com.microsoft.teams'] = {{"cmd", "shift"}, "m"},
        ['us.zoom.xos'] = {{"cmd", "shift"}, "m"},
        ['com.hnc.Discord'] = {{"cmd", "shift"}, "a"}
    }
    tryAppButtons(AppMuteButtons)
end

function obj:raiseHand()
    self.logger.d("raiseHand triggered")
    local AppRaiseButtons = {
        ['bbb'] = {{"ctrl", "alt"}, "r"},
        ['com.microsoft.teams'] = {{"cmd", "shift"}, "k"},
        ['us.zoom.xos'] = {{"alt"}, "y"}
    }
    tryAppButtons(AppRaiseButtons)
end

function tryAppButtons(AppButtons)
    for application, buttons in pairs(AppButtons) do
        local app = hs.application.get(application)
        if not (app == nil) then
            hs.eventtap.keyStroke(buttons[1], buttons[2], 0, app)
            break
        end
    end
end

return obj
