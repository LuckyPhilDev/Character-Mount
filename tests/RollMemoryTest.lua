-- luacheck: ignore 111 112 121 122 143
--
-- Drives the real MountRandom against a fake mount journal, so the wiring
-- between the roll and CharacterMountRecency is checked, not just the rules.

math.randomseed(1)

local function noop() end
local function stubTable()
    return setmetatable({}, { __index = function() return "" end })
end

LuckyUI      = { C = stubTable(), WC = stubTable() }
LuckyLog     = { New = function() return noop end }
LuckyStrings = { New = function(_, tbl) return tbl end }
function LuckyMedia(file) return file end
SlashCmdList  = {}
CharacterMountDB = {}

CharacterMount_MOUNT_TYPE = { NONE = "none", GROUND = "ground", FLYING = "flying", WATER = "water" }

-- Player state the roll checks before it will summon anything.
function IsMounted() return false end
function IsFlying() return false end
function InCombatLockdown() return false end
function IsIndoors() return false end
function UnitIsDeadOrGhost() return false end
function UnitInVehicle() return false end
function UnitOnTaxi() return false end
function UnitClass() return "Warrior", "WARRIOR" end
function UnitRace() return "Human", "Human" end
function UnitName() return "Tester" end
function GetRealmName() return "Realm" end
function GetShapeshiftFormID() return nil end
function GetSpecialization() return nil end
function IsSpellKnown() return false end
function IsSpellKnownByPlayer() return false end
function GetMacroIndexByName() return 0 end
C_Timer  = { After = noop }
C_Spell  = { GetSpellInfo = function() return nil end }
C_AddOns = { IsAddOnLoaded = function() return false end }
C_Map    = { GetBestMapForUnit = function() return nil end, GetMapInfo = function() return nil end }
C_Calendar = setmetatable({}, { __index = function() return noop end })

-- Every mount here is a collected, usable ground mount, so the category filter
-- keeps the whole list and the roll is the only thing choosing.
local MOUNTS = { 101, 102, 103, 104, 105, 106 }
C_MountJournal = {
    GetMountIDs = function() return MOUNTS end,
    GetMountInfoByID = function(id)
        return "Mount " .. tostring(id), nil, "icon", nil, true, nil, nil, nil, nil, nil, true
    end,
    GetMountInfoExtraByID = function() return nil, nil, nil, nil, 230, nil, nil, nil, nil, false end,
    SummonByID = function(id) CharacterMount.__summoned = id end,
}

local now = 0
function GetTime() return now end

local frames = {}
function CreateFrame()
    local frame = setmetatable({ scripts = {} }, {
        __index = function(_, key)
            if key == "SetScript" then
                return function(self, name, fn) self.scripts[name] = fn end
            end
            return noop
        end,
    })
    frames[#frames + 1] = frame
    return frame
end

dofile("src/Strings.lua")
dofile("src/CharacterMountHelpers.lua")
dofile("src/MountData.lua")
dofile("src/CharacterMountHolidays.lua")
dofile("src/CharacterMountRecency.lua")
dofile("src/CharacterMount.lua")

-- Where the player is standing is not what this test is about, so the category
-- is decided outright rather than stubbing swimming, flying and the alt key.
local category = CharacterMount_MOUNT_TYPE.GROUND
CharacterMount_GetEligibleMountCategory = function() return category end

-- Boot the saved variables the way ADDON_LOADED does in game.
for _, frame in ipairs(frames) do
    if frame.scripts.OnEvent then
        frame.scripts.OnEvent(frame, "ADDON_LOADED", "Luckys_Character_Mount")
    end
end

local db = CharacterMount.db
assert(db, "InitDB did not run")
db.onboardingComplete = true
for _, id in ipairs(MOUNTS) do db.additions[id] = "manual" end
assert(#CharacterMount.GetEffectiveMountList() == #MOUNTS)

--- Summon and return the mount ID that reached the journal.
local function roll()
    CharacterMount.__summoned = nil
    CharacterMount.MountRandom()
    assert(CharacterMount.__summoned, "nothing was summoned")
    return CharacterMount.__summoned
end

local function rollAt(t)
    now = t
    return roll()
end

--- Get off the mount at `t`, the way the game reports it.
local function dismountAt(t)
    now = t
    for _, frame in ipairs(frames) do
        if frame.scripts.OnEvent then
            frame.scripts.OnEvent(frame, "PLAYER_MOUNT_DISPLAY_CHANGED")
        end
    end
end

-- ---------------------------------------------------------------------------
-- Vary your mounts, on by default
-- ---------------------------------------------------------------------------

assert(CharacterMountDB.varyMounts == nil, "the setting should default on unsaved")

-- The reported bug: the same mount coming up several times in a row. Over a
-- long run no mount may reappear until three others have been in front of it.
local HISTORY = CharacterMount.Recency.HISTORY_SIZE
local seen = {}
for i = 1, 40 do
    local id = rollAt(i * 100)
    for back = 1, HISTORY do
        assert(seen[i - back] ~= id,
            ("roll %d repeated the mount from roll %d"):format(i, i - back))
    end
    seen[i] = id
end

-- The check above has teeth: with the setting off, a repeat does turn up.
CharacterMountDB.varyMounts = false
local repeated = false
seen = {}
for i = 1, 40 do
    local id = rollAt(5000 + i * 100)
    if seen[i - 1] == id then repeated = true end
    seen[i] = id
end
assert(repeated, "expected an unvaried run to repeat a mount")

-- A one mount list still summons that mount every time rather than nothing at
-- all, because the block yields as soon as it would empty the pool.
for i = 2, #MOUNTS do db.exclusions[MOUNTS[i]] = true end
CharacterMountDB.varyMounts = true
assert(rollAt(1200) == MOUNTS[1])
assert(rollAt(1300) == MOUNTS[1])

for i = 2, #MOUNTS do db.exclusions[MOUNTS[i]] = nil end

-- ---------------------------------------------------------------------------
-- Stay on the same mount
-- ---------------------------------------------------------------------------

CharacterMountDB.varyMounts = true
CharacterMountDB.stayOnMountSeconds = 0

-- Off at zero: the roll runs and variety pushes it to a different mount.
local first = rollAt(2000)
dismountAt(2001)
assert(rollAt(2002) ~= first)

CharacterMountDB.stayOnMountSeconds = 10

-- Tuulani's rule: off again inside the window and the next summon is the same
-- mount, however long you waited before summoning, however many times.
first = rollAt(3000)
dismountAt(3002)
assert(rollAt(3050) == first)
dismountAt(3053)
assert(rollAt(3500) == first)

-- A ride as long as the window rolls again, even straight after, and variety
-- keeps it off the one just ridden.
dismountAt(3510)
assert(rollAt(3511) ~= first)

-- A summon that never went off has no dismount to measure from, so a quick
-- second press gets the same mount and a late one rolls.
first = rollAt(3600)
assert(rollAt(3602) == first)
assert(rollAt(3700) ~= first)

-- A category change defeats it: the ground mount is not summoned underwater.
-- Every mount in this journal is ground-only, so a water roll has no match and
-- falls back to the full list, which is where a stuck sticky would show up.
first = rollAt(4000)
dismountAt(4000.5)
category = CharacterMount_MOUNT_TYPE.WATER
local held = 0
for i = 1, 20 do
    if rollAt(4000 + i) == first then held = held + 1 end
end
assert(held < 20, "the ground mount was held on to after moving to water")

print("RollMemoryTest: OK")
