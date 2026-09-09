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
local mounted = false
function IsMounted() return mounted end
function Dismount() mounted = false end
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

local function mountDisplayChanged()
    for _, frame in ipairs(frames) do
        if frame.scripts.OnEvent then
            frame.scripts.OnEvent(frame, "PLAYER_MOUNT_DISPLAY_CHANGED")
        end
    end
end

--- Click the macro at `t` and start the cast without landing on the mount,
--- the way walking out of it leaves things. Returns the mount ID that
--- reached the journal.
local function summonAt(t)
    now = t
    CharacterMount.__summoned = nil
    CharacterMount.MountRandom()
    assert(CharacterMount.__summoned, "nothing was summoned")
    return CharacterMount.__summoned
end

--- Summon at `t` and get on the mount, the way a cast left alone ends.
local function rollAt(t)
    local id = summonAt(t)
    mounted = true
    mountDisplayChanged()
    return id
end

--- Get off the mount at `t`, the way the game reports it.
local function dismountAt(t)
    now = t
    mounted = false
    mountDisplayChanged()
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
    dismountAt(i * 100 + 50)
end

-- The check above has teeth: with the setting off, a repeat does turn up.
CharacterMountDB.varyMounts = false
local repeated = false
seen = {}
for i = 1, 40 do
    local id = rollAt(5000 + i * 100)
    if seen[i - 1] == id then repeated = true end
    seen[i] = id
    dismountAt(5000 + i * 100 + 50)
end
assert(repeated, "expected an unvaried run to repeat a mount")

-- A one mount list still summons that mount every time rather than nothing at
-- all, because the block yields as soon as it would empty the pool.
for i = 2, #MOUNTS do db.exclusions[MOUNTS[i]] = true end
CharacterMountDB.varyMounts = true
assert(rollAt(9200) == MOUNTS[1])
dismountAt(9250)
assert(rollAt(9300) == MOUNTS[1])
dismountAt(9350)

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
dismountAt(2003)

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

-- A category change defeats it: the ground mount is not summoned underwater.
-- Every mount in this journal is ground-only, so a water roll has no match and
-- falls back to the full list, which is where a stuck sticky would show up.
dismountAt(3512)
first = rollAt(4000)
dismountAt(4000.5)
category = CharacterMount_MOUNT_TYPE.WATER
local held = 0
for i = 1, 20 do
    if rollAt(4000 + i) == first then held = held + 1 end
    dismountAt(4000 + i + 0.5)
end
assert(held < 20, "the ground mount was held on to after moving to water")

-- ---------------------------------------------------------------------------
-- A summon has to land
-- ---------------------------------------------------------------------------

category = CharacterMount_MOUNT_TYPE.GROUND
CharacterMountDB.varyMounts = false

-- A long ride, so the mount that follows is rolled rather than repeated.
rollAt(4500)
dismountAt(4600)

-- Tuulani's case: start a cast, walk out of it, and it is as if it never
-- happened. Every click here rolls afresh instead of handing back the mount
-- that never came up.
local afterCancel = {}
for i = 1, 20 do afterCancel[summonAt(4600 + i)] = true end
local distinct = 0
for _ in pairs(afterCancel) do distinct = distinct + 1 end
assert(distinct > 1, "a cast that was walked out of was remembered anyway")

-- ---------------------------------------------------------------------------
-- Forget it after
-- ---------------------------------------------------------------------------

category = CharacterMount_MOUNT_TYPE.GROUND
CharacterMountDB.varyMounts = false
CharacterMountDB.stayForgetMinutes = 5

-- Fishing: hop off, fish, re-summon, and the same mount keeps coming back for
-- the five minutes. Variety is off, so only the cap can break the hold.
first = rollAt(6000)
for hop = 1, 4 do
    dismountAt(6000 + hop * 60 - 57)
    assert(rollAt(6000 + hop * 60) == first, "the hop chain dropped the mount early")
end

-- Past five minutes from the first summon it gives up, however short the hops.
dismountAt(6243)
held = 0
for i = 1, 20 do
    if rollAt(6301 + i * 4) == first then held = held + 1 end
    dismountAt(6303 + i * 4)
end
assert(held < 20, "the mount kept coming back past the cap")

CharacterMountDB.stayForgetMinutes = nil

print("RollMemoryTest: OK")
