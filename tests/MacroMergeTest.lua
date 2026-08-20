-- luacheck: ignore 111 121

local function noop() end
local function stubTable()
    return setmetatable({}, { __index = function() return "" end })
end

LuckyUI = { C = stubTable(), WC = stubTable() }
LuckyLog = { New = function() return noop end }
LuckyStrings = { New = function(_, tbl) return tbl end }
function LuckyMedia(file) return file end
SlashCmdList = {}
CharacterMount_MOUNT_TYPE = { NONE = "none", GROUND = "ground", FLYING = "flying", WATER = "water" }
CharacterMountDB = {}

function CreateFrame()
    return setmetatable({}, { __index = function() return noop end })
end

-- Form names come back localized from the client, so the merge matches on the
-- API name rather than the English one in FORM_SPELLS.
C_Spell = {
    GetSpellInfo = function(spellID)
        local names = { [783] = "Travel Form", [369536] = "Soar", [87840] = "Running Wild" }
        if names[spellID] then return { name = names[spellID] } end
    end,
}

dofile("src/Strings.lua")
dofile("src/CharacterMount.lua")

local Merge = CharacterMount.MergeMacroBody

local MOUNT       = "/cmount mount\n/cmount roll"
local GROUND      = "/cmount groundmount\n/cmount roll"
local FORM        = "/dismount [mounted, noflying]\n/cast Travel Form\n/cmount roll"
local GROUND_FORM = "/dismount [mounted, noflying]\n/cast Running Wild\n/cmount roll"

local function check(label, got, want)
    assert(got == want, ("%s\n  got:  %q\n  want: %q"):format(label, got, want))
end

-- An untouched macro is still rewritten wholesale by a roll.
check("clean mount -> form", Merge(MOUNT, FORM), FORM)
check("clean form -> mount", Merge(FORM, MOUNT), MOUNT)
check("empty body", Merge("", GROUND), GROUND)

-- A cast the player added above the mount survives every re-roll, in place.
local edited = "/cast Revive Battle Pets\n" .. MOUNT
check("player line kept above ours",
    Merge(edited, FORM),
    "/cast Revive Battle Pets\n" .. FORM)
check("and again on the next roll",
    Merge(Merge(edited, FORM), MOUNT),
    "/cast Revive Battle Pets\n" .. MOUNT)

local body = edited
for _ = 1, 20 do body = Merge(body, FORM) end
check("stable over many rolls", body, "/cast Revive Battle Pets\n" .. FORM)

-- The ground macro is protected the same way. A roll rewrites both macros
-- whichever one was clicked, so an edit here survives a click of the other.
local editedGround = "/cast Revive Battle Pets\n" .. GROUND
check("ground macro keeps player line",
    Merge(editedGround, GROUND_FORM),
    "/cast Revive Battle Pets\n" .. GROUND_FORM)
check("ground macro stable across rolls",
    Merge(Merge(editedGround, GROUND_FORM), GROUND),
    "/cast Revive Battle Pets\n" .. GROUND)

-- Our block holds its position when the player's lines sit below it.
check("player line below stays below",
    Merge(MOUNT .. "\n/say wheee", FORM),
    FORM .. "\n/say wheee")

-- A macro header and a trailing newline are the player's, not ours.
check("showtooltip kept at top",
    Merge("#showtooltip\n" .. MOUNT .. "\n", FORM),
    "#showtooltip\n" .. FORM)

-- A dismount of their own is not the conditional one we write.
check("bare dismount survives",
    Merge("/dismount\n" .. MOUNT, GROUND),
    "/dismount\n" .. GROUND)

-- Nothing of ours left in the body: our lines go on the end.
check("all-player body appends ours",
    Merge("/say hi\n/wave", MOUNT),
    "/say hi\n/wave\n" .. MOUNT)

-- Leading blank line with nothing else of the player's (splice index guard).
check("leading blank line", Merge("\n" .. MOUNT, GROUND), "\n" .. GROUND)

print("MacroMergeTest: all checks passed")
