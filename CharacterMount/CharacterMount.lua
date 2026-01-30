-- Character Mount Addon
-- A World of Warcraft addon for character-specific mount management

local addonName, addon = ...

-- Initialize saved variables
CharacterMountDB = CharacterMountDB or {}

-- Event handler frame
local frame = CreateFrame("Frame")

-- Event handler
local function OnEvent(self, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon == addonName then
            -- Addon loaded
            print("|cff00ff00Character Mount|r loaded successfully!")
            frame:UnregisterEvent("ADDON_LOADED")
        end
    end
end

-- Register events
frame:SetScript("OnEvent", OnEvent)
frame:RegisterEvent("ADDON_LOADED")
