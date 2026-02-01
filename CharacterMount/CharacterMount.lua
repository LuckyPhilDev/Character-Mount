-- Character Mount Addon
-- A World of Warcraft addon for character-specific mount management

local addonName, addon = ...

-- Initialize saved variables
CharacterMountDB = CharacterMountDB or {}

-- Get character key for saved variables
local function GetCharacterKey()
    local playerName = UnitName("player")
    local realmName = GetRealmName()
    return playerName .. "-" .. realmName
end

-- Initialize character mount list
local function InitializeCharacterData()
    local charKey = GetCharacterKey()
    
    if not CharacterMountDB[charKey] then
        CharacterMountDB[charKey] = {
            mounts = {}  -- Array of mount IDs
        }
    end
end

-- Add mount to current character's list
function CharacterMount_AddMount(mountID)
    if not mountID then
        print("|cffff0000Character Mount:|r No mount ID provided")
        return false
    end
    
    local charKey = GetCharacterKey()
    
    -- Check if mount is already in list
    for _, id in ipairs(CharacterMountDB[charKey].mounts) do
        if id == mountID then
            print("|cffff0000Character Mount:|r Mount already in list")
            return false
        end
    end
    
    -- Get mount info
    local name = C_MountJournal.GetMountInfoByID(mountID)
    if not name then
        print("|cffff0000Character Mount:|r Invalid mount ID")
        return false
    end
    
    -- Add to list
    table.insert(CharacterMountDB[charKey].mounts, mountID)
    print("|cff00ff00Character Mount:|r Added " .. name .. " to your list")
    
    -- Update macro
    CharacterMount_UpdateMacro()
    
    return true
end

-- Remove mount from current character's list
function CharacterMount_RemoveMount(mountID)
    local charKey = GetCharacterKey()
    
    for i, id in ipairs(CharacterMountDB[charKey].mounts) do
        if id == mountID then
            table.remove(CharacterMountDB[charKey].mounts, i)
            local name = C_MountJournal.GetMountInfoByID(mountID)
            print("|cff00ff00Character Mount:|r Removed " .. (name or "mount") .. " from your list")
            
            -- Update macro
            CharacterMount_UpdateMacro()
            
            return true
        end
    end
    
    print("|cffff0000Character Mount:|r Mount not in list")
    return false
end

-- Get current character's mount list
function CharacterMount_GetMountList()
    local charKey = GetCharacterKey()
    return CharacterMountDB[charKey].mounts
end

---
-- Mount a random mount from the character's list (used by macro)
---
function CharacterMount_MountRandom()
    local mounts = CharacterMount_GetMountList()
    
    if #mounts == 0 then
        print("|cffff0000Character Mount:|r No mounts in your list. Use /cmount to add mounts.")
        return
    end
    
    -- Pick a random mount
    local randomIndex = math.random(1, #mounts)
    local mountID = mounts[randomIndex]
    
    -- Summon the mount
    local success, message = CharacterMount_SummonMount(mountID, nil, false)
    if not success and message then
        print("|cffff0000Character Mount:|r " .. message)
    end
end

---
-- Create or update the Character Mount macro
---
function CharacterMount_CreateMacro()
    local macroName = "CharMount"
    local macroIcon = "136103"  -- Same icon as ZoneMount
    local macroBody = "/run CharacterMount_MountRandom()"
    
    -- Check if macro already exists
    local existingMacro = GetMacroInfo(macroName)
    
    if existingMacro then
        -- Macro exists, just pick it up for the user
        print("|cff00ff00Character Mount:|r Macro '" .. macroName .. "' already exists. Drag it to your action bar.")
        PickupMacro(macroName)
        return
    end
    
    -- Try to create the macro
    local macroID = CreateMacro(macroName, macroIcon, macroBody, nil)
    
    if macroID then
        print("|cff00ff00Character Mount:|r Created macro '" .. macroName .. "'. Drag it to your action bar.")
        PickupMacro(macroName)
    else
        print("|cffff0000Character Mount:|r Cannot create macro - macro limit reached. Please delete some macros.")
    end
end

---
-- Update the Character Mount macro (called when mounts are added/removed)
---
function CharacterMount_UpdateMacro()
    if InCombatLockdown() then
        return
    end
    
    local macroName = "CharMount"
    local macroIndex = GetMacroIndexByName(macroName)
    
    if macroIndex > 0 then
        local macroIcon = "136103"
        local macroBody = "/run CharacterMount_MountRandom()"
        EditMacro(macroIndex, macroName, macroIcon, macroBody)
    end
end

-- Event handler frame
local frame = CreateFrame("Frame")

-- Event handler
local function OnEvent(self, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon == addonName then
            -- Initialize character data
            InitializeCharacterData()
            
            -- Addon loaded
            print("|cff00ff00Character Mount|r loaded successfully!")
            frame:UnregisterEvent("ADDON_LOADED")
        end
    elseif event == "PLAYER_LOGIN" then
        -- Create UI elements after player login
        CharacterMount_CreateMountListUI()
        CharacterMount_HookMountJournalMenu()
        
        -- Create/update the macro
        CharacterMount_CreateMacro()
    end
end

-- Register events
frame:SetScript("OnEvent", OnEvent)
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")

---
-- Hook into the mount journal right-click menu
---
function CharacterMount_HookMountJournalMenu()
    -- Store original function
    local originalShowDropdown = MountJournal.ShowMountDropdown
    
    -- Replace with our hooked version
    MountJournal.ShowMountDropdown = function(self, mountID, anchorTo, offsetX, offsetY)
        -- Store the mount ID for later use
        CharacterMount_CurrentContextMountID = mountID
        
        -- Call original function
        originalShowDropdown(self, mountID, anchorTo, offsetX, offsetY)
    end
    
    -- Hook the dropdown initialization to add our button
    hooksecurefunc("UIDropDownMenu_AddButton", function(info, level)
        -- Only add once per menu and when we have a mount ID
        if CharacterMount_CurrentContextMountID and not CharacterMount_MenuItemAdded then
            CharacterMount_MenuItemAdded = true
            
            local mountID = CharacterMount_CurrentContextMountID
            local name = C_MountJournal.GetMountInfoByID(mountID)
            if not name then return end
            
            -- Check if already in list
            local charKey = GetCharacterKey()
            local isInList = false
            for _, id in ipairs(CharacterMountDB[charKey].mounts) do
                if id == mountID then
                    isInList = true
                    break
                end
            end
            
            -- Add separator after a slight delay to ensure it's added at the end
            C_Timer.After(0, function()
                CharacterMount_MenuItemAdded = false
                
                UIDropDownMenu_AddSeparator()
                
                -- Add our menu option
                local menuInfo = UIDropDownMenu_CreateInfo()
                if isInList then
                    menuInfo.text = "Remove from Character List"
                    menuInfo.func = function()
                        CharacterMount_RemoveMount(mountID)
                        CharacterMount_RefreshMountListUI()
                    end
                else
                    menuInfo.text = "Add to Character List"
                    menuInfo.func = function()
                        CharacterMount_AddMount(mountID)
                        CharacterMount_RefreshMountListUI()
                    end
                end
                menuInfo.notCheckable = true
                UIDropDownMenu_AddButton(menuInfo)
            end)
        end
    end)
    
    print("|cff00ff00Character Mount:|r Right-click menu hook installed")
end

---
-- Create simple on-screen display for mount list
---
function CharacterMount_CreateMountListUI()
    -- Create main frame
    local listFrame = CreateFrame("Frame", "CharacterMountListFrame", UIParent, "BasicFrameTemplateWithInset")
    listFrame:SetSize(300, 400)
    listFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    listFrame:SetMovable(true)
    listFrame:EnableMouse(true)
    listFrame:RegisterForDrag("LeftButton")
    listFrame:SetScript("OnDragStart", listFrame.StartMoving)
    listFrame:SetScript("OnDragStop", listFrame.StopMovingOrSizing)
    listFrame:Hide()  -- Hidden by default
    
    -- Title
    listFrame.title = listFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    listFrame.title:SetPoint("TOP", 0, -5)
    listFrame.title:SetText("Character Mounts")
    
    -- Add Mount ID input section
    local inputLabel = listFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    inputLabel:SetPoint("TOPLEFT", listFrame, "TOPLEFT", 15, -30)
    inputLabel:SetText("Mount ID:")
    
    -- Create input box
    local inputBox = CreateFrame("EditBox", nil, listFrame, "InputBoxTemplate")
    inputBox:SetSize(80, 20)
    inputBox:SetPoint("LEFT", inputLabel, "RIGHT", 5, 0)
    inputBox:SetAutoFocus(false)
    inputBox:SetMaxLetters(10)
    inputBox:SetNumeric(true)
    
    -- Add button next to input
    local addButton = CreateFrame("Button", nil, listFrame, "UIPanelButtonTemplate")
    addButton:SetSize(60, 22)
    addButton:SetPoint("LEFT", inputBox, "RIGHT", 5, 0)
    addButton:SetText("Add")
    addButton:SetScript("OnClick", function()
        local mountID = tonumber(inputBox:GetText())
        if mountID and mountID > 0 then
            if CharacterMount_AddMount(mountID) then
                inputBox:SetText("")
                CharacterMount_RefreshMountListUI()
            end
        else
            print("|cffff0000Character Mount:|r Please enter a valid mount ID")
        end
    end)
    
    -- Allow Enter key to add
    inputBox:SetScript("OnEnterPressed", function(self)
        addButton:Click()
        self:ClearFocus()
    end)
    
    -- Create scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", nil, listFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", listFrame, "TOPLEFT", 10, -60)
    scrollFrame:SetPoint("BOTTOMRIGHT", listFrame, "BOTTOMRIGHT", -30, 40)
    
    -- Create content frame
    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(260, 1)
    scrollFrame:SetScrollChild(content)
    
    listFrame.content = content
    listFrame.mountEntries = {}
    
    -- Close button (X is already there from BasicFrameTemplateWithInset)
    
    -- Mount button at bottom
    local mountButton = CreateFrame("Button", nil, listFrame, "UIPanelButtonTemplate")
    mountButton:SetSize(100, 25)
    mountButton:SetPoint("BOTTOM", listFrame, "BOTTOM", 0, 10)
    mountButton:SetText("Mount")
    mountButton:SetScript("OnClick", function()
        local mounts = CharacterMount_GetMountList()
        
        if #mounts == 0 then
            print("|cffff0000Character Mount:|r No mounts in your list")
            return
        end
        
        -- Pick a random mount
        local randomIndex = math.random(1, #mounts)
        local mountID = mounts[randomIndex]
        
        -- Summon the mount
        local success, message = CharacterMount_SummonMount(mountID, nil, false)
        if message then
            print("|cff00ff00Character Mount:|r " .. message)
        end
    end)
    
    -- Create slash command to toggle
    SLASH_CHARACTERMOUNT1 = "/cmount"
    SLASH_CHARACTERMOUNT2 = "/charactermount"
    SlashCmdList["CHARACTERMOUNT"] = function(msg)
        if listFrame:IsShown() then
            listFrame:Hide()
        else
            listFrame:Show()
            CharacterMount_RefreshMountListUI()
        end
    end
    
    -- Store reference
    CharacterMount_ListFrame = listFrame
end

---
-- Refresh the mount list display
---
function CharacterMount_RefreshMountListUI()
    local listFrame = CharacterMount_ListFrame
    if not listFrame then return end
    
    local content = listFrame.content
    
    -- Clear existing entries
    for _, entry in ipairs(listFrame.mountEntries) do
        entry:Hide()
        entry:SetParent(nil)
    end
    listFrame.mountEntries = {}
    
    -- Get mount list
    local mounts = CharacterMount_GetMountList()
    
    if #mounts == 0 then
        local noMounts = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        noMounts:SetPoint("TOPLEFT", content, "TOPLEFT", 10, -10)
        noMounts:SetText("No mounts in list yet.\n\nOpen the Mount Journal and\nclick 'Add to List' to add mounts.")
        table.insert(listFrame.mountEntries, noMounts)
        return
    end
    
    -- Create entries for each mount
    local yOffset = -10
    for i, mountID in ipairs(mounts) do
        local name, spellID, icon = C_MountJournal.GetMountInfoByID(mountID)
        
        if name then
            -- Create entry frame
            local entry = CreateFrame("Frame", nil, content)
            entry:SetSize(250, 30)
            entry:SetPoint("TOPLEFT", content, "TOPLEFT", 5, yOffset)
            
            -- Icon
            local iconTexture = entry:CreateTexture(nil, "ARTWORK")
            iconTexture:SetSize(24, 24)
            iconTexture:SetPoint("LEFT", entry, "LEFT", 5, 0)
            iconTexture:SetTexture(icon)
            
            -- Name
            local nameText = entry:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            nameText:SetPoint("LEFT", iconTexture, "RIGHT", 5, 0)
            nameText:SetText(name)
            nameText:SetJustifyH("LEFT")
            nameText:SetWidth(150)
            
            -- Remove button
            local removeBtn = CreateFrame("Button", nil, entry, "UIPanelButtonTemplate")
            removeBtn:SetSize(60, 20)
            removeBtn:SetPoint("RIGHT", entry, "RIGHT", 0, 0)
            removeBtn:SetText("Remove")
            removeBtn:SetScript("OnClick", function()
                CharacterMount_RemoveMount(mountID)
                CharacterMount_RefreshMountListUI()
            end)
            
            table.insert(listFrame.mountEntries, entry)
            yOffset = yOffset - 32
        end
    end
    
    -- Update content height
    content:SetHeight(math.max(350, math.abs(yOffset)))
end
