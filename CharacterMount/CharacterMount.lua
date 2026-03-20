-- Character Mount: Core logic, macro management, and event handling.

CharacterMount = CharacterMount or {}

local ADDON_NAME = "CharacterMount"
local PREFIX     = "|cff00cc00CharMount:|r"

-- Module-level references set during ADDON_LOADED
local db      -- CharacterMountDB[charKey] for the current character
local charKey -- "CharName-RealmName"

-- ---------------------------------------------------------------------------
-- Saved variable helpers
-- ---------------------------------------------------------------------------

local function GetCharacterKey()
    return UnitName("player") .. "-" .. GetRealmName()
end

local function InitDB()
    charKey = GetCharacterKey()
    CharacterMountDB = CharacterMountDB or {}

    if not CharacterMountDB[charKey] then
        CharacterMountDB[charKey] = {
            additions  = {},
            exclusions = {},
        }
    end

    local charData = CharacterMountDB[charKey]

    -- Migrate legacy 'mounts' array (v0.x) → additions sparse set
    if charData.mounts then
        for _, id in ipairs(charData.mounts) do
            charData.additions[id] = true
        end
        charData.mounts = nil
    end

    charData.additions  = charData.additions  or {}
    charData.exclusions = charData.exclusions or {}

    db = charData
    CharacterMount.db = db
end

-- ---------------------------------------------------------------------------
-- Mount list construction
-- ---------------------------------------------------------------------------

local function GetRacialMounts()
    local localRace, englishRace = UnitRace("player")
    print(PREFIX .. " [DEBUG] UnitRace: localized='" .. tostring(localRace) .. "' english='" .. tostring(englishRace) .. "'")
    local ids = CharacterMount.MountData.GetRacialMountIDs(englishRace)
    print(PREFIX .. " [DEBUG] Racial mount IDs found for '" .. tostring(englishRace) .. "': " .. #ids)
    local result = {}
    for _, mountID in ipairs(ids) do
        local name, _, icon, _, _, _, _, _, _, _, isCollected =
            C_MountJournal.GetMountInfoByID(mountID)
        print(PREFIX .. " [DEBUG] Mount ID " .. mountID .. ": name='" .. tostring(name) .. "' isCollected=" .. tostring(isCollected))
        if isCollected and name then
            result[#result + 1] = { id = mountID, name = name, icon = icon, source = "racial" }
        end
    end
    return result
end

local function GetClassMounts()
    local _, classFile = UnitClass("player")
    local ids = CharacterMount.MountData.GetClassMountIDs(classFile)
    local result = {}
    for _, mountID in ipairs(ids) do
        local name, _, icon, _, _, _, _, _, _, _, isCollected =
            C_MountJournal.GetMountInfoByID(mountID)
        if isCollected and name then
            result[#result + 1] = { id = mountID, name = name, icon = icon, source = "class" }
        end
    end
    return result
end

--- Returns the effective mount list for the current character.
-- effective = (racial_collected ∪ class_collected ∪ additions) − exclusions
function CharacterMount.GetEffectiveMountList()
    local seen   = {}
    local result = {}

    local function addIfNew(entry)
        if not seen[entry.id] and not db.exclusions[entry.id] then
            seen[entry.id] = true
            result[#result + 1] = entry
        end
    end

    for _, entry in ipairs(GetRacialMounts()) do addIfNew(entry) end
    for _, entry in ipairs(GetClassMounts())  do addIfNew(entry) end

    for mountID in pairs(db.additions) do
        if not seen[mountID] and not db.exclusions[mountID] then
            local name, _, icon, _, _, _, _, _, _, _, isCollected =
                C_MountJournal.GetMountInfoByID(mountID)
            if isCollected and name then
                seen[mountID] = true
                result[#result + 1] = { id = mountID, name = name, icon = icon, source = "manual" }
            end
        end
    end

    return result
end

-- ---------------------------------------------------------------------------
-- Public add / remove / unexclude
-- ---------------------------------------------------------------------------

function CharacterMount.AddMount(mountID)
    local name = C_MountJournal.GetMountInfoByID(mountID)
    if not name then
        print(PREFIX .. " Invalid mount ID: " .. tostring(mountID))
        return false
    end
    db.exclusions[mountID] = nil
    db.additions[mountID]  = true
    print(PREFIX .. " Added " .. name .. " to your list.")
    if CharacterMount.RefreshUI then CharacterMount.RefreshUI() end
    return true
end

function CharacterMount.RemoveMount(mountID)
    local name = C_MountJournal.GetMountInfoByID(mountID) or "mount"
    db.additions[mountID]  = nil
    db.exclusions[mountID] = true
    print(PREFIX .. " Removed " .. name .. " from your list.")
    if CharacterMount.RefreshUI then CharacterMount.RefreshUI() end
end

function CharacterMount.UnexcludeMount(mountID)
    db.exclusions[mountID] = nil
    if CharacterMount.RefreshUI then CharacterMount.RefreshUI() end
end

-- ---------------------------------------------------------------------------
-- MountRandom — called by the macro
-- ---------------------------------------------------------------------------

function CharacterMount.MountRandom()
    print(PREFIX .. " MountRandom called.")

    if IsMounted() then
        if IsFlying() then
            print(PREFIX .. " Flying — cannot dismount.")
        else
            print(PREFIX .. " Dismounting.")
            Dismount()
        end
        return
    end

    if InCombatLockdown() then
        print(PREFIX .. " In combat — cannot mount.")
        return
    end

    if UnitIsDeadOrGhost("player") then
        print(PREFIX .. " Dead — cannot mount.")
        return
    end

    if UnitInVehicle("player") or UnitOnTaxi("player") then
        print(PREFIX .. " In vehicle or on taxi.")
        return
    end

    if IsIndoors() then
        print(PREFIX .. " Indoors — cannot mount.")
        return
    end

    local category = CharacterMount_GetEligibleMountCategory()
    print(PREFIX .. " Eligible category: " .. category)

    local mountList = CharacterMount.GetEffectiveMountList()
    print(PREFIX .. " Effective list: " .. #mountList .. " mounts.")

    local usable = {}
    for _, entry in ipairs(mountList) do
        local _, _, _, _, isUsable = C_MountJournal.GetMountInfoByID(entry.id)
        if isUsable then
            usable[#usable + 1] = entry
        end
    end
    print(PREFIX .. " Usable from list: " .. #usable)

    -- Filter usable mounts by the eligible category
    if #usable > 0 and category ~= CharacterMount_MOUNT_TYPE.NONE then
        local preferred = {}
        for _, entry in ipairs(usable) do
            local _, _, _, _, mountTypeID, _, _, _, _, isSteadyFlight =
                C_MountJournal.GetMountInfoExtraByID(entry.id)
            if CharacterMount_IsMountTypeMatch(category, mountTypeID, isSteadyFlight) then
                preferred[#preferred + 1] = entry
            end
        end
        print(PREFIX .. " Matching '" .. category .. "': " .. #preferred)

        -- Use preferred list if any match; otherwise fall back to all usable
        local pool = #preferred > 0 and preferred or usable
        local pick = pool[math.random(#pool)]
        print(PREFIX .. " Summoning: " .. pick.name)
        C_MountJournal.SummonByID(pick.id)
        return
    end

    if #usable > 0 then
        local pick = usable[math.random(#usable)]
        print(PREFIX .. " Summoning: " .. pick.name)
        C_MountJournal.SummonByID(pick.id)
        return
    end

    -- Effective list is empty or nothing usable — fall back to full collection.
    print(PREFIX .. " No list mounts usable, falling back to full collection.")
    local allIDs = C_MountJournal.GetMountIDs()
    if allIDs then
        local collected = {}
        local collectedPreferred = {}
        for _, mountID in ipairs(allIDs) do
            local name, _, _, _, isUsable, _, _, _, _, _, isCollected =
                C_MountJournal.GetMountInfoByID(mountID)
            if isCollected and isUsable and name then
                collected[#collected + 1] = mountID
                if category ~= CharacterMount_MOUNT_TYPE.NONE then
                    local _, _, _, _, mountTypeID, _, _, _, _, isSteadyFlight =
                        C_MountJournal.GetMountInfoExtraByID(mountID)
                    if CharacterMount_IsMountTypeMatch(category, mountTypeID, isSteadyFlight) then
                        collectedPreferred[#collectedPreferred + 1] = mountID
                    end
                end
            end
        end
        local pool = #collectedPreferred > 0 and collectedPreferred or collected
        if #pool > 0 then
            local pick = pool[math.random(#pool)]
            local name = C_MountJournal.GetMountInfoByID(pick)
            print(PREFIX .. " Summoning: " .. tostring(name))
            C_MountJournal.SummonByID(pick)
            return
        end
    end

    print(PREFIX .. " No usable mount found.")
end

-- ---------------------------------------------------------------------------
-- Macro management
-- ---------------------------------------------------------------------------

local MACRO_NAME = "CharMount"
local MACRO_ICON = "136103"
local MACRO_BODY = "/run CharacterMount.MountRandom()"

function CharacterMount.CreateMacro()
    if InCombatLockdown() then
        print(PREFIX .. " Cannot create macro during combat.")
        return
    end

    local idx = GetMacroIndexByName(MACRO_NAME)
    if idx and idx > 0 then
        EditMacro(idx, MACRO_NAME, MACRO_ICON, MACRO_BODY)
        print(PREFIX .. " Macro '" .. MACRO_NAME .. "' updated. Drag it to your action bar.")
        PickupMacro(MACRO_NAME)
        return
    end

    local macroID = CreateMacro(MACRO_NAME, MACRO_ICON, MACRO_BODY, nil)
    if macroID then
        print(PREFIX .. " Created macro '" .. MACRO_NAME .. "'. Drag it to your action bar.")
        PickupMacro(MACRO_NAME)
    else
        print(PREFIX .. " Cannot create macro — macro limit reached.")
    end
end

function CharacterMount.UpdateMacro()
    if InCombatLockdown() then return end
    local idx = GetMacroIndexByName(MACRO_NAME)
    if idx and idx > 0 then
        EditMacro(idx, MACRO_NAME, MACRO_ICON, MACRO_BODY)
    end
end

-- ---------------------------------------------------------------------------
-- Mount Journal right-click context menu hook (TWW Menu system)
-- ---------------------------------------------------------------------------

function CharacterMount.HookMountJournalMenu()
    if not Menu or not Menu.ModifyMenu then
        print(PREFIX .. " Menu API not available — right-click integration disabled.")
        return
    end

    Menu.ModifyMenu("MENU_MOUNT_JOURNAL", function(owner, rootDescription)
        -- In TWW the owner is the mount entry button; mountID is stored on it.
        ---@diagnostic disable-next-line: undefined-field
        local mountID = owner and (owner.mountID or (owner.data and owner.data.mountID))
        if not mountID then return end

        local name = C_MountJournal.GetMountInfoByID(mountID)
        if not name then return end

        rootDescription:CreateDivider()

        if db.additions[mountID] then
            rootDescription:CreateButton("Remove from Character List", function()
                CharacterMount.RemoveMount(mountID)
            end)
        elseif db.exclusions[mountID] then
            rootDescription:CreateButton("Re-enable in Character List", function()
                CharacterMount.UnexcludeMount(mountID)
            end)
        else
            local isAuto = false
            for _, entry in ipairs(CharacterMount.GetEffectiveMountList()) do
                if entry.id == mountID and (entry.source == "racial" or entry.source == "class") then
                    isAuto = true
                    break
                end
            end
            if isAuto then
                rootDescription:CreateButton("Exclude from Character List", function()
                    CharacterMount.RemoveMount(mountID)
                end)
            else
                rootDescription:CreateButton("Add to Character List", function()
                    CharacterMount.AddMount(mountID)
                end)
            end
        end
    end)
end

-- ---------------------------------------------------------------------------
-- Mount search helper
-- ---------------------------------------------------------------------------

local function FindMountsByName(partialName)
    local lower = partialName:lower()
    local allIDs = C_MountJournal.GetMountIDs()
    if not allIDs then return {} end
    local matches = {}
    for _, mountID in ipairs(allIDs) do
        local name, _, _, _, _, _, _, _, _, _, isCollected =
            C_MountJournal.GetMountInfoByID(mountID)
        if isCollected and name and name:lower():find(lower, 1, true) then
            matches[#matches + 1] = { id = mountID, name = name }
        end
    end
    return matches
end

-- ---------------------------------------------------------------------------
-- Slash commands
-- ---------------------------------------------------------------------------

SLASH_CHARACTERMOUNT1 = "/cmount"
SLASH_CHARACTERMOUNT2 = "/charactermount"
SlashCmdList["CHARACTERMOUNT"] = function(msg)
    msg = (msg or ""):match("^%s*(.-)%s*$")
    local lower = msg:lower()

    if lower == "" then
        CharacterMount.CreateUI()
        if CharacterMount.frame then
            if CharacterMount.frame:IsShown() then
                CharacterMount.frame:Hide()
            else
                CharacterMount.frame:Show()
                CharacterMount.RefreshUI()
            end
        end
    elseif lower == "macro" then
        CharacterMount.CreateMacro()
    elseif lower == "mount" then
        CharacterMount.MountRandom()
    elseif lower == "reset" then
        db.exclusions = {}
        if CharacterMount.RefreshUI then CharacterMount.RefreshUI() end
        print(PREFIX .. " All exclusions cleared.")
    elseif lower == "reset all" then
        db.exclusions = {}
        db.additions  = {}
        if CharacterMount.RefreshUI then CharacterMount.RefreshUI() end
        print(PREFIX .. " All exclusions and manual additions cleared.")
    elseif lower:sub(1, 4) == "add " then
        local arg = msg:sub(5):match("^%s*(.-)%s*$")
        local mountID = tonumber(arg)
        if mountID then
            CharacterMount.AddMount(mountID)
        else
            local matches = FindMountsByName(arg)
            if #matches == 0 then
                print(PREFIX .. " No collected mount found matching '" .. arg .. "'.")
            elseif #matches == 1 then
                CharacterMount.AddMount(matches[1].id)
            else
                print(PREFIX .. " Multiple matches — use /cmount add <id>:")
                for _, m in ipairs(matches) do
                    print(string.format("  [%d] %s", m.id, m.name))
                end
            end
        end
    elseif lower:sub(1, 7) == "remove " then
        local arg = msg:sub(8):match("^%s*(.-)%s*$")
        local mountID = tonumber(arg)
        if mountID then
            CharacterMount.RemoveMount(mountID)
        else
            local matches = FindMountsByName(arg)
            if #matches == 0 then
                print(PREFIX .. " No collected mount found matching '" .. arg .. "'.")
            elseif #matches == 1 then
                CharacterMount.RemoveMount(matches[1].id)
            else
                print(PREFIX .. " Multiple matches — use /cmount remove <id>:")
                for _, m in ipairs(matches) do
                    print(string.format("  [%d] %s", m.id, m.name))
                end
            end
        end
    else
        print(PREFIX .. " Usage:")
        print("  /cmount              — open/close UI")
        print("  /cmount add <name>   — add mount by name (partial ok)")
        print("  /cmount add <id>     — add mount by ID")
        print("  /cmount remove <name|id>")
        print("  /cmount macro        — create action bar macro")
        print("  /cmount mount        — mount now")
        print("  /cmount reset        — clear all exclusions")
        print("  /cmount reset all    — clear exclusions and manual additions")
    end
end

-- ---------------------------------------------------------------------------
-- Event handling
-- ---------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local loaded = ...
        if loaded == ADDON_NAME then
            InitDB()
        elseif loaded == "Blizzard_Collections" then
            CharacterMount.HookMountJournalButton()
            eventFrame:UnregisterEvent("ADDON_LOADED")
        end
    elseif event == "PLAYER_LOGIN" then
        CharacterMount.CreateUI()
        CharacterMount.HookMountJournalMenu()
        if CharacterMount.RefreshUI then CharacterMount.RefreshUI() end
        -- Blizzard_Collections may already be loaded if another addon forced it
        if C_AddOns.IsAddOnLoaded("Blizzard_Collections") then
            CharacterMount.HookMountJournalButton()
            eventFrame:UnregisterEvent("ADDON_LOADED")
        end
    end
end)
