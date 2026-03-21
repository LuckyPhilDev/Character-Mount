-- Character Mount: Core logic, macro management, and event handling.

CharacterMount = CharacterMount or {}

local ADDON_NAME = "CharacterMount"
local PREFIX     = LuckyUI.WC.goldAccent .. "CharMount:" .. LuckyUI.WC.reset

-- ---------------------------------------------------------------------------
-- Mount source display (domain-specific, references LuckyUI colors)
-- ---------------------------------------------------------------------------

CharacterMount.SourceColor = {
    racial          = LuckyUI.WC.info,
    class           = LuckyUI.WC.goldAccent,
    class_form      = LuckyUI.WC.goldAccent,
    manual          = LuckyUI.WC.success,
    suggested_class = LuckyUI.WC.success,
    suggested_race  = LuckyUI.WC.info,
    rare            = LuckyUI.WC.purple,
}

CharacterMount.SourceLabel = {
    racial          = "Racial",
    class           = "Class",
    class_form      = "Class",
    manual          = "Manual",
    suggested_class = "Suggested",
    suggested_race  = "Racial",
    rare            = "Rare",
}

-- RGB values for pill/tag backgrounds (matched to SourceColor)
CharacterMount.SourcePillRGB = {
    racial          = LuckyUI.C.info,
    class           = LuckyUI.C.goldAccent,
    class_form      = LuckyUI.C.goldAccent,
    manual          = LuckyUI.C.success,
    suggested_class = LuckyUI.C.success,
    suggested_race  = LuckyUI.C.info,
    rare            = LuckyUI.C.purple,
}

-- Spell-based "mounts" (class/racial forms). Keyed by a synthetic ID
-- constructed as "spell:<spellID>". Entries store the spell info needed
-- to cast the form and display it in the UI.
-- Travel Form (783) adapts to context: flight in flyable areas, cheetah on
-- ground, aquatic in water — so a single entry with category "all" is correct.
CharacterMount.FORM_SPELLS = {
    DRUID_TRAVEL    = { spellID = 783,    name = "Travel Form",  category = "all" },
    DRACTHYR_SOAR   = { spellID = 369536, name = "Soar",         category = "flying" },
    WORGEN_RUNNING  = { spellID = 87840,  name = "Running Wild",  category = "ground" },
}

-- Reverse lookup: spellID → category (used by MountRandom for type matching)
CharacterMount.FORM_SPELLS_BY_ID = {}
for _, form in pairs(CharacterMount.FORM_SPELLS) do
    CharacterMount.FORM_SPELLS_BY_ID[form.spellID] = form.category
end

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
-- If onboarding is complete: additions − exclusions only (no auto racial/class).
-- If onboarding not done (legacy): (racial ∪ class ∪ additions) − exclusions.
function CharacterMount.GetEffectiveMountList()
    local seen   = {}
    local result = {}

    local function addIfNew(entry)
        if not seen[entry.id] and not db.exclusions[entry.id] then
            seen[entry.id] = true
            result[#result + 1] = entry
        end
    end

    -- Only auto-include racial/class if onboarding hasn't been completed
    if not db.onboardingComplete then
        for _, entry in ipairs(GetRacialMounts()) do addIfNew(entry) end
        for _, entry in ipairs(GetClassMounts())  do addIfNew(entry) end
    end

    for key, source in pairs(db.additions) do
        print(PREFIX .. " [LIST] Processing addition key=" .. tostring(key)
            .. " (type=" .. type(key) .. ") source=" .. tostring(source)
            .. " seen=" .. tostring(seen[key])
            .. " excluded=" .. tostring(db.exclusions[key]))
        if not seen[key] and not db.exclusions[key] then
            -- Check for spell-based form entries (keyed as "spell:<id>")
            local spellID = type(key) == "string" and tonumber(key:match("^spell:(%d+)$"))
            print(PREFIX .. " [LIST] Parsed spellID=" .. tostring(spellID))
            if spellID then
                local spellInfo = C_Spell.GetSpellInfo(spellID)
                print(PREFIX .. " [LIST] C_Spell.GetSpellInfo(" .. spellID .. ") → "
                    .. tostring(spellInfo and spellInfo.name or "nil"))
                if spellInfo then
                    seen[key] = true
                    local srcTag = (type(source) == "string") and source or "class_form"
                    result[#result + 1] = {
                        id      = key,
                        spellID = spellID,
                        name    = spellInfo.name,
                        icon    = spellInfo.iconID,
                        source  = srcTag,
                    }
                end
            else
                local name, _, icon, _, _, _, _, _, _, _, isCollected =
                    C_MountJournal.GetMountInfoByID(key)
                if isCollected and name then
                    seen[key] = true
                    local srcTag = (type(source) == "string") and source or "manual"
                    result[#result + 1] = { id = key, name = name, icon = icon, source = srcTag }
                end
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
    db.additions[mountID]  = "manual"
    print(PREFIX .. " Added " .. name .. " to your list.")
    if CharacterMount.RefreshUI then CharacterMount.RefreshUI() end
    CharacterMount.PreRoll()
    return true
end

function CharacterMount.RemoveMount(mountID)
    local name
    -- Handle spell-form IDs (e.g. "spell:783")
    local spellID = type(mountID) == "string" and tonumber(mountID:match("^spell:(%d+)$"))
    if spellID then
        local spellInfo = C_Spell.GetSpellInfo(spellID)
        name = spellInfo and spellInfo.name or "form"
    else
        name = C_MountJournal.GetMountInfoByID(mountID) or "mount"
    end
    db.additions[mountID]  = nil
    db.exclusions[mountID] = true
    print(PREFIX .. " Removed " .. name .. " from your list.")
    if CharacterMount.RefreshUI then CharacterMount.RefreshUI() end
    CharacterMount.PreRoll()
end

function CharacterMount.UnexcludeMount(mountID)
    db.exclusions[mountID] = nil
    db.additions[mountID]  = "manual"
    if CharacterMount.RefreshUI then CharacterMount.RefreshUI() end
end

-- ---------------------------------------------------------------------------
-- MountRandom — called by the macro
-- ---------------------------------------------------------------------------

function CharacterMount.MountRandom()
    print(PREFIX .. " MountRandom called.")

    -- ── State diagnostics ──
    print(PREFIX .. " [STATE] IsMounted=" .. tostring(IsMounted())
        .. " IsFlying=" .. tostring(IsFlying())
        .. " InCombat=" .. tostring(InCombatLockdown())
        .. " IsIndoors=" .. tostring(IsIndoors())
        .. " IsDead=" .. tostring(UnitIsDeadOrGhost("player"))
        .. " InVehicle=" .. tostring(UnitInVehicle("player")))

    local _, playerClass = UnitClass("player")
    local formIndex = GetShapeshiftFormID()
    print(PREFIX .. " [STATE] Class=" .. tostring(playerClass)
        .. " ShapeshiftFormID=" .. tostring(formIndex))

    if IsMounted() then
        if IsFlying() then
            print(PREFIX .. " Flying — cannot dismount.")
        else
            print(PREFIX .. " Dismounting.")
            Dismount()
        end
        return
    end

    -- Druid Travel Form doesn't count as "mounted" but should toggle off
    -- when the player clicks the mount button again.
    if formIndex and formIndex > 0 then
        if playerClass == "DRUID" then
            print(PREFIX .. " Cancelling shapeshift form (formID=" .. formIndex .. ").")
            CancelShapeshiftForm()
            return
        end
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

    -- ── Dump the full effective list for diagnostics ──
    for i, entry in ipairs(mountList) do
        print(PREFIX .. "   [" .. i .. "] id=" .. tostring(entry.id)
            .. " name=" .. tostring(entry.name)
            .. " spellID=" .. tostring(entry.spellID)
            .. " source=" .. tostring(entry.source))
    end

    -- ── Dump saved variables state ──
    print(PREFIX .. " [DB] onboardingComplete=" .. tostring(db.onboardingComplete))
    local addCount, exclCount = 0, 0
    for k, v in pairs(db.additions) do
        addCount = addCount + 1
        print(PREFIX .. "   [DB.additions] key=" .. tostring(k)
            .. " (type=" .. type(k) .. ") value=" .. tostring(v))
    end
    for k, v in pairs(db.exclusions) do
        exclCount = exclCount + 1
        print(PREFIX .. "   [DB.exclusions] key=" .. tostring(k)
            .. " (type=" .. type(k) .. ") value=" .. tostring(v))
    end
    print(PREFIX .. " [DB] additions=" .. addCount .. " exclusions=" .. exclCount)

    -- MountRandom only handles journal mounts.  Spell forms (Travel Form etc.)
    -- are cast via /cast in the macro text — see PreRoll().
    -- Filter to journal mounts only.
    local usable = {}
    for _, entry in ipairs(mountList) do
        if not entry.spellID then
            local _, _, _, _, isUsable = C_MountJournal.GetMountInfoByID(entry.id)
            print(PREFIX .. " [MOUNT CHECK] id=" .. tostring(entry.id)
                .. " name=" .. tostring(entry.name)
                .. " isUsable=" .. tostring(isUsable))
            if isUsable then
                usable[#usable + 1] = entry
            end
        else
            print(PREFIX .. " [SKIP SPELL] " .. tostring(entry.name)
                .. " (handled by macro /cast)")
        end
    end
    print(PREFIX .. " Usable journal mounts: " .. #usable)

    -- Filter usable mounts by the eligible category
    if #usable > 0 and category ~= CharacterMount_MOUNT_TYPE.NONE then
        local preferred = {}
        for _, entry in ipairs(usable) do
            local _, _, _, _, mountTypeID, _, _, _, _, isSteadyFlight =
                C_MountJournal.GetMountInfoExtraByID(entry.id)
            local isMatch = CharacterMount_IsMountTypeMatch(category, mountTypeID, isSteadyFlight)
            print(PREFIX .. " [CAT MATCH] mountID=" .. tostring(entry.id)
                .. " typeID=" .. tostring(mountTypeID)
                .. " steadyFlight=" .. tostring(isSteadyFlight)
                .. " match=" .. tostring(isMatch))
            if isMatch then
                preferred[#preferred + 1] = entry
            end
        end
        print(PREFIX .. " Matching '" .. category .. "': " .. #preferred)

        local pool = #preferred > 0 and preferred or usable
        local pick = pool[math.random(#pool)]
        print(PREFIX .. " Picked from pool of " .. #pool .. ": " .. pick.name)
        C_MountJournal.SummonByID(pick.id)
        return
    end

    if #usable > 0 then
        local pick = usable[math.random(#usable)]
        print(PREFIX .. " Picked (no category filter): " .. pick.name)
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
-- Protected spells (Druid Travel Form) cannot be cast from Lua — they must
-- be invoked via /cast in macro text.  To support random selection that
-- includes both journal mounts and spell forms we use a "pre-roll" pattern:
--
--   1.  Each macro click ends with "/cmount roll" which randomly picks the
--       NEXT mount/form and rewrites the macro text accordingly.
--   2.  On the first click (before any roll has happened) the macro just
--       runs "/cmount mount" as a fallback, then "/cmount roll".
--   3.  When a spell form wins the roll the macro is rewritten to:
--           /dismount [mounted]
--           /cast Travel Form
--           /cmount roll
--       When a journal mount wins:
--           /cmount mount
--           /cmount roll
--
-- This means each click executes the action chosen by the PREVIOUS roll,
-- then immediately pre-rolls for the next click.
-- ---------------------------------------------------------------------------

local MACRO_NAME = "CharMount"
local MACRO_ICON = "136103"

--- Build macro body for a given pre-rolled result.
--- @param spellName string|nil  If non-nil, the macro casts this spell form.
function CharacterMount.BuildMacroBody(spellName)
    if spellName then
        -- Spell form: /cast handles the protected action, /cmount roll
        -- pre-rolls for the next click.
        return "/dismount [mounted]\n/cast " .. spellName .. "\n/cmount roll"
    end
    -- Journal mount: /cmount mount summons via SummonByID, then pre-roll.
    return "/cmount mount\n/cmount roll"
end

--- Pre-roll: randomly pick the next mount/form from the usable pool
--- and rewrite the macro so the next click executes it.
function CharacterMount.PreRoll()
    if InCombatLockdown() then return end

    local idx = GetMacroIndexByName(MACRO_NAME)
    if not idx or idx == 0 then return end

    local mountList = CharacterMount.GetEffectiveMountList()
    local category  = CharacterMount_GetEligibleMountCategory()

    -- Build usable + preferred pools (same logic as MountRandom)
    local usable, preferred = {}, {}
    for _, entry in ipairs(mountList) do
        local ok = false
        if entry.spellID then
            ok = IsSpellKnown(entry.spellID)
        else
            local _, _, _, _, isUsable = C_MountJournal.GetMountInfoByID(entry.id)
            ok = isUsable
        end
        if ok then
            usable[#usable + 1] = entry
            if entry.spellID then
                local formCat = CharacterMount.FORM_SPELLS_BY_ID[entry.spellID]
                if formCat == "all" or formCat == category then
                    preferred[#preferred + 1] = entry
                end
            elseif category ~= CharacterMount_MOUNT_TYPE.NONE then
                local _, _, _, _, mountTypeID, _, _, _, _, isSteadyFlight =
                    C_MountJournal.GetMountInfoExtraByID(entry.id)
                if CharacterMount_IsMountTypeMatch(category, mountTypeID, isSteadyFlight) then
                    preferred[#preferred + 1] = entry
                end
            end
        end
    end

    local pool = #preferred > 0 and preferred or usable
    if #pool == 0 then
        print(PREFIX .. " [ROLL] No usable mounts for next click.")
        return
    end

    local pick = pool[math.random(#pool)]
    local body
    if pick.spellID then
        print(PREFIX .. " [ROLL] Next click → spell: " .. pick.name)
        body = CharacterMount.BuildMacroBody(pick.name)
    else
        print(PREFIX .. " [ROLL] Next click → mount: " .. pick.name)
        body = CharacterMount.BuildMacroBody(nil)
    end

    EditMacro(idx, MACRO_NAME, MACRO_ICON, body)
end

function CharacterMount.CreateMacro()
    if InCombatLockdown() then
        print(PREFIX .. " Cannot create macro during combat.")
        return
    end

    -- Start with journal-mount body; first click will mount + pre-roll.
    local body = CharacterMount.BuildMacroBody(nil)
    local idx = GetMacroIndexByName(MACRO_NAME)
    if idx and idx > 0 then
        EditMacro(idx, MACRO_NAME, MACRO_ICON, body)
        print(PREFIX .. " Macro '" .. MACRO_NAME .. "' updated. Drag it to your action bar.")
        PickupMacro(MACRO_NAME)
        return
    end

    local macroID = CreateMacro(MACRO_NAME, MACRO_ICON, body, nil)
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
        -- Re-roll so the macro reflects current mount list.
        CharacterMount.PreRoll()
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
    elseif lower == "roll" then
        CharacterMount.PreRoll()
    elseif lower == "reset" then
        db.exclusions = {}
        if CharacterMount.RefreshUI then CharacterMount.RefreshUI() end
        print(PREFIX .. " All exclusions cleared.")
    elseif lower == "reset all" then
        db.exclusions = {}
        db.additions  = {}
        if CharacterMount.RefreshUI then CharacterMount.RefreshUI() end
        print(PREFIX .. " All exclusions and manual additions cleared.")
    elseif lower == "reset onboarding" then
        CharacterMount.ResetOnboarding()
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
    elseif lower == "debug" then
        print(PREFIX .. " --- Debug for " .. tostring(charKey) .. " ---")
        if not db then
            print("  ERROR: db is nil — saved variables not loaded")
        else
            print("  onboardingComplete: " .. tostring(db.onboardingComplete))
            local addCount = 0
            for _ in pairs(db.additions or {})  do addCount = addCount + 1 end
            local exclCount = 0
            for _ in pairs(db.exclusions or {}) do exclCount = exclCount + 1 end
            print("  additions: " .. addCount)
            if addCount > 0 and addCount <= 20 then
                for id in pairs(db.additions) do
                    local name = C_MountJournal.GetMountInfoByID(id)
                    print("    [" .. id .. "] " .. tostring(name))
                end
            end
            print("  exclusions: " .. exclCount)
            if exclCount > 0 and exclCount <= 20 then
                for id in pairs(db.exclusions) do
                    local name = C_MountJournal.GetMountInfoByID(id)
                    print("    [" .. id .. "] " .. tostring(name))
                end
            end
            local effective = CharacterMount.GetEffectiveMountList()
            print("  effective list: " .. #effective .. " mounts")
        end
    else
        print(PREFIX .. " Usage:")
        print("  /cmount              — open/close UI")
        print("  /cmount add <name>   — add mount by name (partial ok)")
        print("  /cmount add <id>     — add mount by ID")
        print("  /cmount remove <name|id>")
        print("  /cmount macro        — create action bar macro")
        print("  /cmount mount        — mount now")
        print("  /cmount reset            — clear all exclusions")
        print("  /cmount reset all        — clear exclusions and manual additions")
        print("  /cmount reset onboarding — reset and re-trigger onboarding")
        print("  /cmount debug            — show saved state for this character")
    end
end

-- ---------------------------------------------------------------------------
-- Event handling
-- ---------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
local addonLoaded_self        = false
local addonLoaded_collections = false
local playerLoggedIn          = false

--- Show onboarding once both the addon's SavedVariables and the player
--- data are available (requires both ADDON_LOADED and PLAYER_LOGIN).
local function TryShowOnboarding()
    if not addonLoaded_self or not playerLoggedIn then return end
    if db and not db.onboardingComplete then
        print(PREFIX .. " New character detected — showing onboarding.")
        CharacterMount.ShowOnboarding()
    end
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local loaded = ...
        if loaded == ADDON_NAME then
            InitDB()
            addonLoaded_self = true
            TryShowOnboarding()
        end
        if loaded == "Blizzard_Collections" then
            CharacterMount.HookMountJournalButton()
            addonLoaded_collections = true
        end
        if addonLoaded_self and addonLoaded_collections then
            eventFrame:UnregisterEvent("ADDON_LOADED")
        end
    elseif event == "PLAYER_LOGIN" then
        -- PLAYER_LOGIN can fire before ADDON_LOADED in some load orders.
        -- Ensure our saved variables are initialised before proceeding.
        if not addonLoaded_self then
            InitDB()
            addonLoaded_self = true
        end
        playerLoggedIn = true
        CharacterMount.CreateUI()
        CharacterMount.HookMountJournalMenu()
        if CharacterMount.RefreshUI then CharacterMount.RefreshUI() end
        if C_AddOns.IsAddOnLoaded("Blizzard_Collections") then
            CharacterMount.HookMountJournalButton()
            addonLoaded_collections = true
        end
        if addonLoaded_self and addonLoaded_collections then
            eventFrame:UnregisterEvent("ADDON_LOADED")
        end
        TryShowOnboarding()
    end
end)
