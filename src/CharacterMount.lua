-- Character Mount: Core logic, macro management, and event handling.

CharacterMount = CharacterMount or {}

local ADDON_NAME = "Luckys_Character_Mount"
local PREFIX     = LuckyUI.WC.goldAccent .. "CharMount:" .. LuckyUI.WC.reset

-- Chat warnings for blocked mount attempts. Mashing the macro while waiting
-- for combat to drop would otherwise flood chat, so repeats of the same
-- message are dropped for a few seconds.
local WARN_THROTTLE_SECONDS = 3
local lastWarnAt = {}

local function Warn(message)
    if CharacterMountDB.quietMountWarnings then return end
    local now = GetTime()
    if lastWarnAt[message] and now - lastWarnAt[message] < WARN_THROTTLE_SECONDS then
        return
    end
    lastWarnAt[message] = now
    print(PREFIX .. " " .. message)
end

-- ---------------------------------------------------------------------------
-- Mount source display (domain-specific, references LuckyUI colors)
-- ---------------------------------------------------------------------------

CharacterMount.SourceColor = {
    racial          = LuckyUI.WC.info,
    class           = LuckyUI.WC.danger,
    class_form      = LuckyUI.WC.danger,
    manual          = LuckyUI.WC.success,
    suggested_class = LuckyUI.WC.success,
    suggested_race  = LuckyUI.WC.info,
    rare            = LuckyUI.WC.purple,
    shop            = LuckyUI.WC.goldPrimary,
}

CharacterMount.SourceLabel = {
    racial          = "Racial",
    class           = "Class",
    class_form      = "Class",
    manual          = "Manual",
    suggested_class = "Suggested",
    suggested_race  = "Racial",
    rare            = "Rare",
    shop            = "Shop",
}

-- RGB values for pill/tag backgrounds (matched to SourceColor)
CharacterMount.SourcePillRGB = {
    racial          = LuckyUI.C.info,
    class           = LuckyUI.C.danger,
    class_form      = LuckyUI.C.danger,
    manual          = LuckyUI.C.success,
    suggested_class = LuckyUI.C.success,
    suggested_race  = LuckyUI.C.info,
    rare            = LuckyUI.C.purple,
    shop            = LuckyUI.C.goldPrimary,
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

-- Debug logging — only prints when debugMode is true (account-wide setting)
local devLog = LuckyLog:New(PREFIX, function()
    return CharacterMountDB and CharacterMountDB.debugMode
end)

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
            additions      = {},
            exclusions     = {},
            specExclusions = {},
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

    charData.additions      = charData.additions      or {}
    charData.exclusions     = charData.exclusions     or {}
    charData.specExclusions = charData.specExclusions or {}
    charData.mountTypes     = charData.mountTypes     or {}

    db = charData
    CharacterMount.db = db
end

-- ---------------------------------------------------------------------------
-- Mount list construction
-- ---------------------------------------------------------------------------

local function GetRacialMounts()
    local localRace, englishRace = UnitRace("player")
    devLog("[DEBUG] UnitRace: localized='" .. tostring(localRace) .. "' english='" .. tostring(englishRace) .. "'")
    local ids = CharacterMount.MountData.GetRacialMountIDs(englishRace)
    devLog("[DEBUG] Racial mount IDs found for '" .. tostring(englishRace) .. "': " .. #ids)
    local result = {}
    for _, mountID in ipairs(ids) do
        local name, _, icon, _, _, _, _, _, _, _, isCollected =
            C_MountJournal.GetMountInfoByID(mountID)
        devLog("[DEBUG] Mount ID " .. mountID .. ": name='" .. tostring(name) .. "' isCollected=" .. tostring(isCollected))
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
        devLog("[LIST] Processing addition key=" .. tostring(key)
            .. " (type=" .. type(key) .. ") source=" .. tostring(source)
            .. " seen=" .. tostring(seen[key])
            .. " excluded=" .. tostring(db.exclusions[key]))
        if not seen[key] and not db.exclusions[key] then
            -- Check for spell-based form entries (keyed as "spell:<id>")
            local spellID = type(key) == "string" and tonumber(key:match("^spell:(%d+)$"))
            devLog("[LIST] Parsed spellID=" .. tostring(spellID))
            if spellID then
                local spellInfo = C_Spell.GetSpellInfo(spellID)
                devLog("[LIST] C_Spell.GetSpellInfo(" .. spellID .. ") → "
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
-- Per-spec availability
-- ---------------------------------------------------------------------------
-- Mounts are character-wide by default. db.specExclusions[mountID] is a set of
-- spec IDs the mount is turned off for: db.specExclusions[mountID][specID] = true.
-- A mount with no entry (or an empty set) is available for every spec.

local function GetCurrentSpecID()
    local idx = GetSpecialization()
    if not idx then return nil end          -- below level 10: no active spec
    return (GetSpecializationInfo(idx))
end

--- Ordered list of the character's specs: { { id, name, icon }, ... }
function CharacterMount.GetCharacterSpecs()
    local specs = {}
    local num = GetNumSpecializations()
    if not num then return specs end
    for i = 1, num do
        local id, name, _, icon = GetSpecializationInfo(i)
        if id then
            specs[#specs + 1] = { id = id, name = name, icon = icon }
        end
    end
    return specs
end

--- Is the mount enabled for a specific spec ID?
function CharacterMount.IsMountEnabledForSpec(mountID, specID)
    if not specID then return true end
    local ex = db.specExclusions and db.specExclusions[mountID]
    return not (ex and ex[specID])
end

--- Is the mount enabled for the player's current spec? (true when no spec yet)
function CharacterMount.IsMountEnabledForCurrentSpec(mountID)
    local specID = GetCurrentSpecID()
    if not specID then return true end
    return CharacterMount.IsMountEnabledForSpec(mountID, specID)
end

--- Returns how many of the character's specs this mount is enabled for, and the total.
function CharacterMount.GetMountSpecCounts(mountID)
    local specs = CharacterMount.GetCharacterSpecs()
    local enabled = 0
    for _, spec in ipairs(specs) do
        if CharacterMount.IsMountEnabledForSpec(mountID, spec.id) then
            enabled = enabled + 1
        end
    end
    return enabled, #specs
end

--- Enable or disable a mount for a single spec, then refresh UI and macro.
function CharacterMount.SetMountSpecEnabled(mountID, specID, enabled)
    if not specID then return end
    db.specExclusions = db.specExclusions or {}
    if enabled then
        local ex = db.specExclusions[mountID]
        if ex then
            ex[specID] = nil
            if next(ex) == nil then db.specExclusions[mountID] = nil end
        end
    else
        db.specExclusions[mountID] = db.specExclusions[mountID] or {}
        db.specExclusions[mountID][specID] = true
    end
    if CharacterMount.RefreshUI then CharacterMount.RefreshUI() end
    CharacterMount.PreRoll()
end

--- Drop all per-mount settings (called when it is added/removed/reset).
local function ClearMountSettings(mountID)
    if db.specExclusions then db.specExclusions[mountID] = nil end
    if db.mountTypes then db.mountTypes[mountID] = nil end
end

-- ---------------------------------------------------------------------------
-- Per-mount "count as" types
-- ---------------------------------------------------------------------------
-- db.mountTypes[mountID] is the set of categories a mount is picked for, e.g.
-- { ground = true, flying = true }. No entry means "use the mount's real type",
-- so only mounts the player has customised take up saved-variable space.

local TYPE_OPTIONS = {
    { key = CharacterMount_MOUNT_TYPE.GROUND, label = "Ground" },
    { key = CharacterMount_MOUNT_TYPE.FLYING, label = "Flying" },
    { key = CharacterMount_MOUNT_TYPE.WATER,  label = "Water"  },
}

local function GetMountTypeID(mountID)
    local _, _, _, _, mountTypeID = C_MountJournal.GetMountInfoExtraByID(mountID)
    return mountTypeID
end

--- The categories a mount currently counts as: the player's choice if they
--- made one, otherwise the mount's real types.
function CharacterMount.GetMountTypes(mountID)
    local chosen = db.mountTypes and db.mountTypes[mountID]
    if chosen then return chosen end
    return CharacterMount_GetNaturalMountTypes(GetMountTypeID(mountID))
end

function CharacterMount.IsMountCountedAs(mountID, mountType)
    return CharacterMount.GetMountTypes(mountID)[mountType] == true
end

function CharacterMount.SetMountCountedAs(mountID, mountType, enabled)
    db.mountTypes = db.mountTypes or {}
    local types = db.mountTypes[mountID]
    if not types then
        types = CharacterMount.GetMountTypes(mountID)
        db.mountTypes[mountID] = types
    end
    types[mountType] = enabled or nil
    CharacterMount.PreRoll()
end

--- Does this mount count as `category` right now? Honours the player's
--- "count as" choice, falling back to the mount's real type.
local function MountCountsAsCategory(mountID, category, mountTypeID, isSteadyFlight)
    local chosen = db.mountTypes and db.mountTypes[mountID]
    if not chosen then
        return CharacterMount_IsMountTypeMatch(category, mountTypeID, isSteadyFlight)
    end
    if not chosen[category] then return false end
    -- Underwater-only mounts still need real water; no setting changes that.
    if category == CharacterMount_MOUNT_TYPE.WATER
        and CharacterMount_IsWaterOnlyMount(mountTypeID) then
        return CharacterMount_IsMountTypeMatch(category, mountTypeID, isSteadyFlight)
    end
    return true
end

--- Open the per-mount spec and type dropdown anchored to `anchor`.
function CharacterMount.ShowSpecMenu(anchor, mountID)
    if not mountID or not MenuUtil or not MenuUtil.CreateContextMenu then return end
    local specs = CharacterMount.GetCharacterSpecs()
    local isJournalMount = type(mountID) == "number"
    if #specs == 0 and not isJournalMount then return end

    MenuUtil.CreateContextMenu(anchor, function(_, root)
        if #specs > 0 then
            root:CreateTitle("Use this mount for:")
            for _, spec in ipairs(specs) do
                root:CreateCheckbox(spec.name,
                    function()
                        return CharacterMount.IsMountEnabledForSpec(mountID, spec.id)
                    end,
                    function()
                        CharacterMount.SetMountSpecEnabled(mountID, spec.id,
                            not CharacterMount.IsMountEnabledForSpec(mountID, spec.id))
                        return MenuResponse.Refresh
                    end)
            end
        end

        if not isJournalMount then return end

        local natural  = CharacterMount_GetNaturalMountTypes(GetMountTypeID(mountID))
        local canFly   = natural[CharacterMount_MOUNT_TYPE.FLYING]

        if #specs > 0 then root:CreateDivider() end
        root:CreateTitle("Count as:")
        for _, option in ipairs(TYPE_OPTIONS) do
            local label = option.label
            if natural[option.key] then
                label = label .. LuckyUI.WC.textMuted .. " (default)" .. LuckyUI.WC.reset
            end
            root:CreateCheckbox(label,
                function()
                    return CharacterMount.IsMountCountedAs(mountID, option.key)
                end,
                function()
                    CharacterMount.SetMountCountedAs(mountID, option.key,
                        not CharacterMount.IsMountCountedAs(mountID, option.key))
                    return MenuResponse.Refresh
                end)
        end

        if not canFly and CharacterMount.IsMountCountedAs(mountID, CharacterMount_MOUNT_TYPE.FLYING) then
            root:CreateTitle(LuckyUI.WC.danger
                .. "Summoned when flying, but it cannot fly" .. LuckyUI.WC.reset)
        end
    end)
end

--- Tooltip for the per-mount spec/type button, shared by both list panels.
function CharacterMount.ShowSpecButtonTooltip(button, mountID)
    if not mountID then return end
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")

    local specs = CharacterMount.GetCharacterSpecs()
    if #specs > 0 then
        GameTooltip:AddLine("Available for specs")
        for _, spec in ipairs(specs) do
            if CharacterMount.IsMountEnabledForSpec(mountID, spec.id) then
                GameTooltip:AddLine(spec.name, 0.45, 0.85, 0.45)
            else
                GameTooltip:AddLine(spec.name .. " (off)", 0.75, 0.4, 0.4)
            end
        end
    end

    if type(mountID) == "number" then
        if #specs > 0 then GameTooltip:AddLine(" ") end
        GameTooltip:AddLine("Counts as")
        local any = false
        for _, option in ipairs(TYPE_OPTIONS) do
            if CharacterMount.IsMountCountedAs(mountID, option.key) then
                GameTooltip:AddLine(option.label, 0.45, 0.85, 0.45)
                any = true
            end
        end
        if not any then
            GameTooltip:AddLine("Nothing selected", 0.75, 0.4, 0.4)
        end
    end

    GameTooltip:AddLine("Click to change", 0.6, 0.6, 0.6)
    GameTooltip:Show()
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
    ClearMountSettings(mountID)
    print(PREFIX .. " Added " .. name .. " to your list.")
    if CharacterMount.RefreshUI then CharacterMount.RefreshUI() end
    CharacterMount.PreRoll()
    return true
end

function CharacterMount.AddMountToAllCharacters(mountID)
    local name = C_MountJournal.GetMountInfoByID(mountID)
    if not name then return false end
    
    for _, data in pairs(CharacterMountDB) do
        if type(data) == "table" and data.additions and data.exclusions then
            data.exclusions[mountID] = nil
            data.additions[mountID] = "manual"
            if data.specExclusions then data.specExclusions[mountID] = nil end
            if data.mountTypes then data.mountTypes[mountID] = nil end
        end
    end
    print(PREFIX .. " Added " .. name .. " to all character lists.")
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
    ClearMountSettings(mountID)
    print(PREFIX .. " Removed " .. name .. " from your list.")
    if CharacterMount.RefreshUI then CharacterMount.RefreshUI() end
    CharacterMount.PreRoll()
end

function CharacterMount.UnexcludeMount(mountID)
    db.exclusions[mountID] = nil
    db.additions[mountID]  = "manual"
    ClearMountSettings(mountID)
    if CharacterMount.RefreshUI then CharacterMount.RefreshUI() end
end

-- ---------------------------------------------------------------------------
-- MountRandom — called by the macro
-- ---------------------------------------------------------------------------

--- Encounters where Blizzard allows mounting during combat. SummonByID is
--- only situationally blocked in combat; in these zones the block is lifted,
--- and it works fine from insecure code (mount SPELL casts stay blocked even
--- from secure macros, so summoning by ID is the only path). Zone list
--- mirrors LiteMount's combat override.
local function IsCombatMountZone()
    -- Amirdrassil raid (Tindral Sageswift): 2234 is the parent of the
    -- relevant maps, so walk up the map tree from the player's map.
    local mapID = C_Map.GetBestMapForUnit("player")
    local id = mapID
    while id and id > 0 do
        if id == 2234 then return true end
        local info = C_Map.GetMapInfo(id)
        id = info and info.parentMapID
    end

    local instanceID = select(8, GetInstanceInfo())
    -- The Dawnbreaker dungeon (TWW).
    if instanceID == 2662 then return true end
    -- Manaforge Omega raid (Dimensius): only the fight's own maps.
    if instanceID == 2810 and mapID and mapID >= 2467 and mapID <= 2470 then
        return true
    end
    return false
end

--- @param forcedCategory string|nil  When set (e.g. GROUND), summon that
--- category regardless of where the player is standing. nil = eligible category.
function CharacterMount.MountRandom(forcedCategory)
    devLog("MountRandom called." .. (forcedCategory and (" forced=" .. forcedCategory) or ""))

    -- State diagnostics
    devLog("[STATE] IsMounted=" .. tostring(IsMounted())
        .. " IsFlying=" .. tostring(IsFlying())
        .. " InCombat=" .. tostring(InCombatLockdown())
        .. " IsIndoors=" .. tostring(IsIndoors())
        .. " IsDead=" .. tostring(UnitIsDeadOrGhost("player"))
        .. " InVehicle=" .. tostring(UnitInVehicle("player")))

    local _, playerClass = UnitClass("player")
    local formIndex = GetShapeshiftFormID()
    devLog("[STATE] Class=" .. tostring(playerClass)
        .. " ShapeshiftFormID=" .. tostring(formIndex))

    if IsMounted() then
        if IsFlying() and not CharacterMountDB.allowFlyingDismount then
            Warn("Flying, cannot dismount. Enable in settings to allow this.")
        else
            devLog("Dismounting.")
            Dismount()
        end
        return
    end

    -- Druid Travel Form doesn't count as "mounted" but should toggle off
    -- when the player clicks the mount button again.
    if formIndex and formIndex > 0 then
        if playerClass == "DRUID" then
            devLog("Cancelling shapeshift form (formID=" .. formIndex .. ").")
            CancelShapeshiftForm()
            return
        end
    end

    if InCombatLockdown() and not IsCombatMountZone() then
        Warn("In combat, cannot mount.")
        return
    end

    if UnitIsDeadOrGhost("player") then
        Warn("Dead, cannot mount.")
        return
    end

    if UnitInVehicle("player") or UnitOnTaxi("player") then
        Warn("In vehicle or on taxi.")
        return
    end

    if IsIndoors() then
        Warn("Indoors, cannot mount.")
        return
    end

    local category = forcedCategory or CharacterMount_GetEligibleMountCategory()
    devLog("Category: " .. category .. (forcedCategory and " (forced)" or " (eligible)"))

    local mountList = CharacterMount.GetEffectiveMountList()
    devLog("Effective list: " .. #mountList .. " mounts.")

    -- Dump the full effective list for diagnostics
    for i, entry in ipairs(mountList) do
        devLog("  [" .. i .. "] id=" .. tostring(entry.id)
            .. " name=" .. tostring(entry.name)
            .. " spellID=" .. tostring(entry.spellID)
            .. " source=" .. tostring(entry.source))
    end

    -- Dump saved variables state
    devLog("[DB] onboardingComplete=" .. tostring(db.onboardingComplete))
    local addCount, exclCount = 0, 0
    for k, v in pairs(db.additions) do
        addCount = addCount + 1
        devLog("  [DB.additions] key=" .. tostring(k)
            .. " (type=" .. type(k) .. ") value=" .. tostring(v))
    end
    for k, v in pairs(db.exclusions) do
        exclCount = exclCount + 1
        devLog("  [DB.exclusions] key=" .. tostring(k)
            .. " (type=" .. type(k) .. ") value=" .. tostring(v))
    end
    devLog("[DB] additions=" .. addCount .. " exclusions=" .. exclCount)

    -- MountRandom only handles journal mounts.  Spell forms (Travel Form etc.)
    -- are cast via /cast in the macro text — see PreRoll().
    -- Filter to journal mounts only.
    local usable = {}
    for _, entry in ipairs(mountList) do
        if not CharacterMount.IsMountEnabledForCurrentSpec(entry.id) then
            devLog("[SPEC SKIP] " .. tostring(entry.name)
                .. " (disabled for current spec)")
        elseif not entry.spellID then
            local _, _, _, _, isUsable = C_MountJournal.GetMountInfoByID(entry.id)
            devLog("[MOUNT CHECK] id=" .. tostring(entry.id)
                .. " name=" .. tostring(entry.name)
                .. " isUsable=" .. tostring(isUsable))
            if isUsable then
                usable[#usable + 1] = entry
            end
        else
            devLog("[SKIP SPELL] " .. tostring(entry.name)
                .. " (handled by macro /cast)")
        end
    end
    devLog("Usable journal mounts: " .. #usable)

    -- Filter usable mounts by the eligible category
    if #usable > 0 and category ~= CharacterMount_MOUNT_TYPE.NONE then
        local preferred = {}
        for _, entry in ipairs(usable) do
            local _, _, _, _, mountTypeID, _, _, _, _, isSteadyFlight =
                C_MountJournal.GetMountInfoExtraByID(entry.id)
            local isMatch = MountCountsAsCategory(entry.id, category, mountTypeID, isSteadyFlight)
            devLog("[CAT MATCH] mountID=" .. tostring(entry.id)
                .. " typeID=" .. tostring(mountTypeID)
                .. " steadyFlight=" .. tostring(isSteadyFlight)
                .. " match=" .. tostring(isMatch))
            if isMatch then
                preferred[#preferred + 1] = entry
            end
        end
        devLog("Matching '" .. category .. "': " .. #preferred)

        local pool = #preferred > 0 and preferred or usable
        local pick = pool[math.random(#pool)]
        devLog("Picked from pool of " .. #pool .. ": " .. pick.name)
        C_MountJournal.SummonByID(pick.id)
        return
    end

    if #usable > 0 then
        local pick = usable[math.random(#usable)]
        devLog("Picked (no category filter): " .. pick.name)
        C_MountJournal.SummonByID(pick.id)
        return
    end

    -- Effective list is empty or nothing usable — fall back to full collection.
    devLog("No list mounts usable, falling back to full collection.")
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
            devLog("Summoning: " .. tostring(name))
            C_MountJournal.SummonByID(pick)
            return
        end
    end

    Warn("No usable mount found.")
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
local GROUND_MACRO_NAME = "CharMountGround"
local GROUND_MACRO_ICON = "ability_mount_whitetiger"

-- Every CharMount macro that can exist. All end their body with /cmount roll,
-- which pre-rolls every one of them; only the summon verb and the category the
-- roll is forced to differ. category nil means "use the eligible category for
-- where the player is standing" (the normal macro); GROUND forces ground mounts
-- regardless of whether flying is allowed.
local MACRO_SPECS = {
    { name = MACRO_NAME,        icon = MACRO_ICON,        mountCmd = "mount",       category = nil },
    { name = GROUND_MACRO_NAME, icon = GROUND_MACRO_ICON, mountCmd = "groundmount", category = CharacterMount_MOUNT_TYPE.GROUND },
}

--- Build macro body for a given pre-rolled result.
--- @param spellName string|nil  If non-nil, the macro casts this spell form.
--- @param mountCmd string|nil   Summon verb for journal mounts (default "mount").
function CharacterMount.BuildMacroBody(spellName, mountCmd)
    if spellName then
        -- Spell form: /cast handles the protected action, /cmount roll
        -- pre-rolls for the next click.
        local dismountCond = CharacterMountDB.allowFlyingDismount
            and "[mounted]" or "[mounted, noflying]"
        return "/dismount " .. dismountCond .. "\n/cast " .. spellName .. "\n/cmount roll"
    end
    -- Journal mount: /cmount mount summons via SummonByID. In combat that is
    -- blocked except in encounters where Blizzard allows mounting; MountRandom
    -- checks the zone and summons there too.
    return "/cmount " .. (mountCmd or "mount") .. "\n/cmount roll"
end

--- Build the usable/preferred pools for a given category (shared by PreRoll).
--- @param category string  Eligible category to prefer, or forced category.
local function BuildRollPool(category)
    local mountList = CharacterMount.GetEffectiveMountList()
    local usable, preferred = {}, {}
    for _, entry in ipairs(mountList) do
        local ok
        if not CharacterMount.IsMountEnabledForCurrentSpec(entry.id) then
            ok = false
        elseif entry.spellID then
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
                if MountCountsAsCategory(entry.id, category, mountTypeID, isSteadyFlight) then
                    preferred[#preferred + 1] = entry
                end
            end
        end
    end
    return #preferred > 0 and preferred or usable
end

--- Pre-roll every existing CharMount macro: pick each one's next mount/form and
--- rewrite it so the next click executes it. The normal macro rolls against the
--- eligible category; the ground macro forces GROUND.
function CharacterMount.PreRoll()
    if InCombatLockdown() then return end

    local eligible = CharacterMount_GetEligibleMountCategory()

    for _, spec in ipairs(MACRO_SPECS) do
        local idx = GetMacroIndexByName(spec.name)
        if idx and idx > 0 then
            local pool = BuildRollPool(spec.category or eligible)
            if #pool == 0 then
                devLog("[ROLL] " .. spec.name .. ": no usable mounts for next click.")
            else
                local pick = pool[math.random(#pool)]
                local body
                if pick.spellID then
                    devLog("[ROLL] " .. spec.name .. " next click → spell: " .. pick.name)
                    body = CharacterMount.BuildMacroBody(pick.name, spec.mountCmd)
                else
                    devLog("[ROLL] " .. spec.name .. " next click → mount: " .. pick.name)
                    body = CharacterMount.BuildMacroBody(nil, spec.mountCmd)
                end
                -- ponytail: nil name/icon => keep the user's chosen icon (and any
                -- rename); only the body is ours to rewrite each roll.
                EditMacro(idx, nil, nil, body)
            end
        end
    end
end

local function CreateMacroFromSpec(spec)
    if InCombatLockdown() then
        print(PREFIX .. " Cannot create macro during combat.")
        return
    end

    -- Start with journal-mount body; first click will mount + pre-roll.
    local body = CharacterMount.BuildMacroBody(nil, spec.mountCmd)
    local idx = GetMacroIndexByName(spec.name)
    if idx and idx > 0 then
        -- ponytail: nil name/icon => don't reset a user's custom icon/rename on re-create.
        EditMacro(idx, nil, nil, body)
        print(PREFIX .. " Macro '" .. spec.name .. "' updated. Drag it to your action bar.")
        PickupMacro(spec.name)
        return
    end

    local macroID = CreateMacro(spec.name, spec.icon, body, nil)
    if macroID then
        print(PREFIX .. " Created macro '" .. spec.name .. "'. Drag it to your action bar.")
        PickupMacro(spec.name)
    else
        print(PREFIX .. " Cannot create macro — macro limit reached.")
    end
end

function CharacterMount.CreateMacro()
    CreateMacroFromSpec(MACRO_SPECS[1])
end

function CharacterMount.CreateGroundMacro()
    CreateMacroFromSpec(MACRO_SPECS[2])
end

function CharacterMount.UpdateMacro()
    -- Re-roll every existing macro so they reflect the current mount list.
    CharacterMount.PreRoll()
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
-- Minimap button
-- ---------------------------------------------------------------------------

function CharacterMount.InitMinimapButton()
    if not LuckyMinimap then return end

    CharacterMount.minimapButton = LuckyMinimap:Create({
        name    = "CharacterMountMinimapButton",
        icon    = MACRO_ICON,
        dbKey   = "minimap",
        db      = CharacterMountDB,
        defaultAngle = 200,
        onClick = function(_, mouseBtn)
            if mouseBtn == "MiddleButton" then
                CharacterMountDB.debugMode = not CharacterMountDB.debugMode
                local state = CharacterMountDB.debugMode and "ON" or "OFF"
                print(PREFIX .. " Dev mode: " .. state)
            elseif mouseBtn == "RightButton" then
                CharacterMount.OpenSettings()
            else
                CharacterMount.CreateUI()
                if CharacterMount.frame then
                    if CharacterMount.frame:IsShown() then
                        CharacterMount.frame:Hide()
                    else
                        CharacterMount.frame:Show()
                        CharacterMount.RefreshUI()
                    end
                end
            end
        end,
        tooltip = function(tt)
            tt:AddLine("Lucky's Character Mount")
            tt:AddLine(" ")
            tt:AddLine("Left-click: Open mount list", 0.9, 0.8, 0.5)
            tt:AddLine("Right-click: Open settings", 0.9, 0.8, 0.5)
            tt:AddLine("Middle-click: Toggle dev mode", 0.9, 0.8, 0.5)
            tt:AddLine("Drag: Move button", 0.54, 0.49, 0.41)
        end,
    })
end

-- ---------------------------------------------------------------------------
-- Sample mount for /cmount testpopup
-- ---------------------------------------------------------------------------
-- Resolve a mount ID to preview when testing the new-mount popup. The player's
-- first collected mount is the most reliable "commonly-owned" sample; the
-- constant is only a fallback for the rare case of an empty collection.
local FALLBACK_SAMPLE_MOUNT_ID = 460  -- Grand Expedition Yak (widely owned)

function CharacterMount.GetSampleMountID()
    local allIDs = C_MountJournal.GetMountIDs()
    if allIDs then
        for _, id in ipairs(allIDs) do
            local name, _, _, _, _, _, _, _, _, _, isCollected =
                C_MountJournal.GetMountInfoByID(id)
            if isCollected and name then return id end
        end
    end
    -- No collected mounts — fall back to a known journal entry. Its display
    -- still renders even if the mount isn't in the player's collection.
    if C_MountJournal.GetMountInfoByID(FALLBACK_SAMPLE_MOUNT_ID) then
        return FALLBACK_SAMPLE_MOUNT_ID
    end
    return nil
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
    elseif lower == "groundmacro" then
        CharacterMount.CreateGroundMacro()
    elseif lower == "mount" then
        CharacterMount.MountRandom()
    elseif lower == "groundmount" then
        CharacterMount.MountRandom(CharacterMount_MOUNT_TYPE.GROUND)
    elseif lower == "roll" then
        CharacterMount.PreRoll()
    elseif lower == "reset" then
        db.exclusions     = {}
        db.specExclusions = {}
        db.mountTypes     = {}
        if CharacterMount.RefreshUI then CharacterMount.RefreshUI() end
        print(PREFIX .. " All exclusions cleared.")
    elseif lower == "reset all" then
        db.exclusions     = {}
        db.additions      = {}
        db.specExclusions = {}
        db.mountTypes     = {}
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
    elseif lower == "settings" or lower == "config" or lower == "options" then
        CharacterMount.OpenSettings()
    elseif lower == "testpopup" or lower:sub(1, 10) == "testpopup " then
        -- Trigger the real new-mount popup on demand for testing the dialog
        -- and its 3D preview. An optional ID overrides the sample mount.
        local arg = msg:sub(11):match("^%s*(.-)%s*$")
        local mountID = tonumber(arg) or CharacterMount.GetSampleMountID()
        if mountID and CharacterMount.ShowNewMountDialog then
            print(PREFIX .. " Testing new-mount popup with mount ID " .. mountID .. ".")
            CharacterMount.ShowNewMountDialog(mountID)
        else
            print(PREFIX .. " No sample mount available. Usage: /cmount testpopup <id>")
        end
    elseif lower:sub(1, 11) == "testunlock " then
        local arg = msg:sub(12):match("^%s*(.-)%s*$")
        local mountID = tonumber(arg)
        if mountID then
            if CharacterMount.ShowNewMountDialog then
                CharacterMount.ShowNewMountDialog(mountID)
            end
        else
            print(PREFIX .. " Please provide a valid mount ID. Usage: /cmount testunlock <id>")
        end
    elseif lower == "sources" or lower:sub(1, 8) == "sources " then
        -- Dev probe: does the journal expose a usable "In-Game Shop" source flag?
        local filter = tonumber(msg:sub(9))
        local counts, order, matched = {}, {}, {}
        for _, mountID in ipairs(C_MountJournal.GetMountIDs()) do
            local name, _, _, _, _, sourceType, _, _, _, _, isCollected =
                C_MountJournal.GetMountInfoByID(mountID)
            if isCollected and sourceType then
                if not counts[sourceType] then
                    counts[sourceType] = 0
                    order[#order + 1] = sourceType
                end
                counts[sourceType] = counts[sourceType] + 1
                if sourceType == filter then
                    local _, _, sourceText = C_MountJournal.GetMountInfoExtraByID(mountID)
                    sourceText = (sourceText or ""):gsub("\n", " | ")
                    matched[#matched + 1] = string.format("  [%d] %s — %s", mountID, tostring(name), sourceText)
                end
            end
        end
        table.sort(order)
        print(PREFIX .. " Collected mounts by sourceType:")
        for _, sourceType in ipairs(order) do
            print(string.format("  %2d  %-24s %d",
                sourceType,
                tostring(_G["BATTLE_PET_SOURCE_" .. sourceType]),
                counts[sourceType]))
        end
        if filter then
            print(PREFIX .. " sourceType " .. filter .. " (" .. #matched .. "):")
            for _, line in ipairs(matched) do print(line) end
        else
            print("  /cmount sources <n> — list the mounts in one source bucket")
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
        print("  /cmount groundmacro  — create ground-only macro")
        print("  /cmount mount        — mount now")
        print("  /cmount settings         — open settings panel")
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
eventFrame:RegisterEvent("NEW_MOUNT_ADDED")
eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
local addonLoaded_self        = false
local addonLoaded_collections = false
local playerLoggedIn          = false

--- Show onboarding once both the addon's SavedVariables and the player
--- data are available (requires both ADDON_LOADED and PLAYER_LOGIN).
local function TryShowOnboarding()
    if not addonLoaded_self or not playerLoggedIn then return end
    if db and not db.onboardingComplete then
        -- Defer slightly so the game UI is fully initialised before
        -- we create and show the onboarding dialog.
        C_Timer.After(0.5, function()
            if db and not db.onboardingComplete then
                devLog("Showing onboarding (deferred).")
                CharacterMount.ShowOnboarding()
            end
        end)
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
        CharacterMount.InitSettings()
        CharacterMount.InitMinimapButton()
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
    elseif event == "NEW_MOUNT_ADDED" then
        local mountID = ...
        if CharacterMountDB.autoPromptNewMount == false then return end
        
        local name = C_MountJournal.GetMountInfoByID(mountID)
        if name and CharacterMount.ShowNewMountDialog then
            CharacterMount.ShowNewMountDialog(mountID)
        end
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        local unit = ...
        if unit and unit ~= "player" then return end
        -- Re-roll the macro and refresh the list so per-spec choices take effect.
        CharacterMount.UpdateMacro()
        if CharacterMount.RefreshUI then CharacterMount.RefreshUI() end
    end
end)
