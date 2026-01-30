-- Character Mount Helper Functions
-- Provides utility functions for mount management

local addonName, addon = ...

-- Mount type constants
local MOUNT_TYPE = {
    GROUND = 'ground',
    FLYING = 'flying',
    WATER = 'water',
    RIDEALONG = 'ridealong',
    NONE = 'none'
}

-- Mount type IDs from Blizzard API
local MOUNT_TYPE_IDS = {
    GROUND = {230, 241, 269, 284, 408, 412},
    FLYING = {247, 248, 398, 407, 424, 402},
    WATER = {231, 254, 232},  -- Turtle, underwater, Vashj'ir seahorse
    WATER_HYBRID = 407  -- Works in water & flying
}

-- Class and racial ability spell IDs
local CLASS_ABILITIES = {
    DRUID = {
        TRAVEL_FORM = 783,        -- Ground/water travel form
        FLIGHT_FORM = 165962,     -- Flying form (also includes travel form)
        AQUATIC_FORM = 1066,      -- Aquatic form (old)
    },
    SHAMAN = {
        GHOST_WOLF = 2645,        -- Ghost Wolf
    },
    WORGEN = {
        RUNNING_WILD = 87840,     -- Worgen racial mount ability
    },
}

-- Helper function to check if player is underwater
local function IsUnderwater()
    local timer, initial, maxvalue, scale, paused, label = GetMirrorTimerInfo(2)
    if timer == 'BREATH' and paused == 0 and scale < 0 then
        return true
    end
    return false
end

-- Helper function to check if player is in Vashj'ir
local function IsInVashjir()
    local zone = GetZoneText()
    return zone == 'Shimmering Expanse' 
        or zone == 'Abyssal Depths' 
        or zone == "Kelp'thar Forest"
end

-- Helper function to check if player should use ground mount (based on modifier keys)
-- This can be customized per character later
local function ShouldUseGroundMount()
    -- Default: Alt key forces ground mount
    return IsAltKeyDown()
end

-- Get player's class information
local function GetPlayerClass()
    local _, englishClass = UnitClass("player")
    return englishClass
end

-- Get player's race information
local function GetPlayerRace()
    local _, englishRace = UnitRace("player")
    return englishRace
end

-- Check if a spell is known by the player
local function IsSpellKnownByPlayer(spellID)
    local spellInfo = C_Spell.GetSpellInfo(spellID)
    if not spellInfo then
        return false
    end
    -- Check if the spell is usable, which implies it's known
    local isUsable = C_Spell.IsSpellUsable(spellID)
    return isUsable ~= nil
end

---
-- Checks if player can use a class or racial travel form
-- @param mountType string The type of mount needed ('flying', 'ground', 'water')
-- @return boolean True if player can use a form for this type
-- @return number|nil The spell ID to cast, or nil if not available
---
function CharacterMount_CanUseTravelForm(mountType)
    local class = GetPlayerClass()
    local race = GetPlayerRace()
    local playerLevel = UnitLevel("player")
    
    -- Druid forms
    if class == "DRUID" then
        if mountType == MOUNT_TYPE.FLYING then
            -- Flight Form requires level 30+ (or appropriate expansion)
            if IsSpellKnownByPlayer(CLASS_ABILITIES.DRUID.FLIGHT_FORM) then
                return true, CLASS_ABILITIES.DRUID.FLIGHT_FORM
            end
        elseif mountType == MOUNT_TYPE.WATER then
            -- Travel Form works in water, or use Aquatic Form
            if IsSpellKnownByPlayer(CLASS_ABILITIES.DRUID.TRAVEL_FORM) then
                return true, CLASS_ABILITIES.DRUID.TRAVEL_FORM
            elseif IsSpellKnownByPlayer(CLASS_ABILITIES.DRUID.AQUATIC_FORM) then
                return true, CLASS_ABILITIES.DRUID.AQUATIC_FORM
            end
        elseif mountType == MOUNT_TYPE.GROUND then
            -- Travel Form for ground movement
            if IsSpellKnownByPlayer(CLASS_ABILITIES.DRUID.TRAVEL_FORM) then
                return true, CLASS_ABILITIES.DRUID.TRAVEL_FORM
            end
        end
    end
    
    -- Worgen Running Wild (ground only)
    if race == "Worgen" and mountType == MOUNT_TYPE.GROUND then
        if IsSpellKnownByPlayer(CLASS_ABILITIES.WORGEN.RUNNING_WILD) then
            return true, CLASS_ABILITIES.WORGEN.RUNNING_WILD
        end
    end
    
    -- Shaman Ghost Wolf (ground only, indoor capable)
    if class == "SHAMAN" and mountType == MOUNT_TYPE.GROUND then
        if IsSpellKnownByPlayer(CLASS_ABILITIES.SHAMAN.GHOST_WOLF) then
            return true, CLASS_ABILITIES.SHAMAN.GHOST_WOLF
        end
    end
    
    return false, nil
end

---
-- Uses a class or racial travel form
-- @param spellID number The spell ID to cast
-- @return boolean True if successful
-- @return string Status or error message
---
function CharacterMount_UseTravelForm(spellID)
    if not spellID then
        return false, 'No spell ID provided.'
    end
    
    -- Check if it's a valid time to use form
    local canMount, reason = CharacterMount_CanMount()
    if not canMount then
        return false, reason
    end
    
    -- Check if spell is usable
    local spellInfo = C_Spell.GetSpellInfo(spellID)
    if not spellInfo then
        return false, 'Spell not found.'
    end
    
    local isUsable, notEnoughMana = C_Spell.IsSpellUsable(spellID)
    if notEnoughMana then
        return false, 'Not enough mana.'
    end
    
    if not isUsable then
        return false, 'Spell cannot be used here.'
    end
    
    -- Cast the spell
    C_Spell.CastSpell(spellID)
    return true, 'Using ' .. spellInfo.name .. '...'
end

---
-- Checks if player should prefer travel form over mounts
-- @return boolean True if player should use forms when available
---
function CharacterMount_ShouldPreferTravelForm()
    -- This can be customized with saved variables later
    -- Default: druids and worgen prefer their forms for convenience
    local class = GetPlayerClass()
    local race = GetPlayerRace()
    
    return class == "DRUID" or race == "Worgen"
end

---
-- Determines which mount category is currently eligible for the player
-- @return string The mount type: 'flying', 'ground', 'water', 'ridealong', or 'none'
---
function CharacterMount_GetEligibleMountCategory()
    -- Check if indoors
    if IsIndoors() then
        return MOUNT_TYPE.NONE
    end
    
    -- Check if modifier key is forcing ground mount
    if ShouldUseGroundMount() then
        return MOUNT_TYPE.GROUND
    end
    
    -- Check if underwater or in Vashj'ir while submerged
    if IsUnderwater() or (IsInVashjir() and IsSubmerged()) then
        return MOUNT_TYPE.WATER
    end
    
    local playerLevel = UnitLevel("player")
    
    -- Level 10-19: Can use flying mounts but may not have pathfinder
    if playerLevel >= 10 and playerLevel < 20 then
        if IsModifierKeyDown() then
            return MOUNT_TYPE.GROUND
        else
            return MOUNT_TYPE.FLYING
        end
    end
    
    -- Check if area allows flying
    if IsFlyableArea() == false and IsAdvancedFlyableArea() == false then
        return MOUNT_TYPE.GROUND
    end
    
    -- Level 10+: Use flying if available
    if IsFlyableArea() and playerLevel >= 10 then
        return MOUNT_TYPE.FLYING
    end
    
    -- Check if swimming or submerged
    if IsSubmerged() or IsSwimming() then
        return MOUNT_TYPE.WATER
    end
    
    -- Default to ground mount
    return MOUNT_TYPE.GROUND
end

---
-- Checks if it's a valid time to mount
-- @return boolean True if can mount, false otherwise
-- @return string Reason message if cannot mount
---
function CharacterMount_CanMount()
    if UnitIsFeignDeath("player") then
        return false, 'You are feigning death.'
    end
    
    if UnitIsDeadOrGhost("player") then
        return false, 'You are dead.'
    end
    
    local spellName = UnitCastingInfo("player")
    if spellName ~= nil then
        return false, 'You are casting ' .. spellName .. '.'
    end
    
    local channelName = UnitChannelInfo("player")
    if channelName ~= nil then
        return false, 'You are channeling ' .. channelName .. '.'
    end
    
    if IsFlying() == true then
        return false, 'You are flying.'
    end
    
    if UnitInVehicle("player") == true then
        return false, 'You are in a vehicle.'
    end
    
    if UnitOnTaxi("player") == true then
        return false, 'You are in a taxi.'
    end
    
    if InCombatLockdown() then
        return false, 'You are in combat.'
    end
    
    return true, nil
end

---
-- Mounts the player on the specified mount, or uses travel form if preferred
-- @param mountID number The mount ID to summon (optional if using travel form)
-- @param mountType string The type of mount needed (optional, will be determined if not provided)
-- @param preferForm boolean If true, prefer travel form over mount (optional)
-- @return boolean True if successful, false otherwise
-- @return string Error message if failed
---
function CharacterMount_SummonMount(mountID, mountType, preferForm)
    -- Check if it's a valid time to mount
    local canMount, reason = CharacterMount_CanMount()
    if not canMount then
        return false, reason
    end
    
    -- Determine mount type if not provided
    if not mountType then
        mountType = CharacterMount_GetEligibleMountCategory()
    end
    
    -- Check if we should prefer travel form
    if preferForm == nil then
        preferForm = CharacterMount_ShouldPreferTravelForm()
    end
    
    -- Try to use travel form if preferred and available
    if preferForm and mountType ~= MOUNT_TYPE.NONE then
        local canUseForm, formSpellID = CharacterMount_CanUseTravelForm(mountType)
        if canUseForm then
            return CharacterMount_UseTravelForm(formSpellID)
        end
    end
    
    if not mountID then
        return false, 'No mount ID provided and no travel form available.'
    end
    
    -- Verify the mount exists and is collected
    local name, spellID, icon, isActive, isUsable, sourceType, isFavorite, 
        isFactionSpecific, faction, shouldHideOnChar, isCollected, mountID_check, isSteadyFlight
        = C_MountJournal.GetMountInfoByID(mountID)
    
    if not isCollected then
        return false, 'Mount not collected.'
    end
    
    if not isUsable then
        return false, 'Mount cannot be used here.'
    end
    
    -- Check if already mounted on this mount
    if isActive then
        return false, 'Already mounted on ' .. name .. '.'
    end
    
    -- Summon the mount
    C_MountJournal.SummonByID(mountID)
    return true, 'Summoning ' .. name .. '...'
end

---
-- Dismounts the player with safety checks
-- @param force boolean If true, dismount even while flying (dangerous!)
-- @return boolean True if dismounted or dismount initiated
-- @return string Status message
---
function CharacterMount_Dismount(force)
    if not IsMounted() then
        return false, 'You are not mounted.'
    end
    
    if IsFlying() and not force then
        return false, 'You are flying. Use force parameter to dismount anyway.'
    end
    
    Dismount()
    return true, 'Dismounted.'
end

---
-- Checks if a mount type ID matches the required mount category
-- @param requiredType string The required mount type ('flying', 'ground', 'water')
-- @param mountTypeID number The mount's type ID from the API
-- @param isSteadyFlight boolean Whether the mount has steady flight
-- @return boolean True if the mount matches the required type
---
function CharacterMount_IsMountTypeMatch(requiredType, mountTypeID, isSteadyFlight)
    if requiredType == MOUNT_TYPE.WATER then
        -- Turtles (231) work on land or water
        -- Hybrid (407) works in water & flying
        if mountTypeID == 231 or mountTypeID == 407 then
            return true
        end
        -- Underwater mounts (254) only if actually underwater
        if mountTypeID == 254 and (IsUnderwater() or (IsInVashjir() and IsSubmerged())) then
            return true
        end
        -- Vashj'ir Seahorse (232) only works in Vashj'ir zones
        if mountTypeID == 232 and IsInVashjir() then
            return true
        end
        return false
        
    elseif requiredType == MOUNT_TYPE.FLYING then
        -- Flying mount type IDs
        for _, typeID in ipairs(MOUNT_TYPE_IDS.FLYING) do
            if mountTypeID == typeID then
                return true
            end
        end
        return false
        
    elseif requiredType == MOUNT_TYPE.GROUND then
        -- Ground mount type IDs
        for _, typeID in ipairs(MOUNT_TYPE_IDS.GROUND) do
            if mountTypeID == typeID then
                return true
            end
        end
        return false
    end
    
    return false
end

-- Export constants for external use
CharacterMount_MOUNT_TYPE = MOUNT_TYPE
