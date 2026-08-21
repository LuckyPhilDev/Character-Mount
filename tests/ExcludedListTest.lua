-- luacheck: ignore 111 121

local function noop() end
local function stubTable()
    return setmetatable({}, { __index = function() return "" end })
end

LuckyUI = setmetatable({ C = stubTable(), WC = stubTable() },
                       { __index = function() return noop end })
CharacterMount = { Strings = stubTable() }

function CreateFrame()
    return setmetatable({}, { __index = function() return noop end })
end

dofile("src/CharacterMountUI.lua")

local Resolve = CharacterMount.ResolveList

local function names(list)
    local out = {}
    for i, entry in ipairs(list) do out[i] = entry.name end
    return table.concat(out, ",")
end

local ACTIVE   = { { name = "Yak" }, { name = "Dragon Turtle" }, { name = "Windsurfer" } }
local EXCLUDED = { { name = "Tiger" }, { name = "Ancient Yak" } }

-- The active list is the default view, sorted by name.
local shown, showExcluded = Resolve(false, ACTIVE, EXCLUDED, "")
assert(names(shown) == "Dragon Turtle,Windsurfer,Yak")
assert(showExcluded == false)

-- The toggle swaps the whole window over, so the two lists never share it.
shown, showExcluded = Resolve(true, ACTIVE, EXCLUDED, "")
assert(names(shown) == "Ancient Yak,Tiger")
assert(showExcluded == true)

-- The reported bug: however long the excluded list grows it cannot crowd out
-- the active one, because only one list is ever on screen.
local many = {}
for i = 1, 200 do many[i] = { name = ("Mount %03d"):format(i) } end
assert(#Resolve(false, ACTIVE, many, "") == #ACTIVE)

-- Restoring the last exclusion drops the excluded view rather than stranding
-- the window on an empty list.
shown, showExcluded = Resolve(true, ACTIVE, {}, "")
assert(showExcluded == false)
assert(#shown == #ACTIVE)

-- The search box filters whichever list is showing.
assert(names(Resolve(false, ACTIVE, EXCLUDED, "yak")) == "Yak")
assert(names(Resolve(true,  ACTIVE, EXCLUDED, "yak")) == "Ancient Yak")
assert(#Resolve(true, ACTIVE, EXCLUDED, "zzz") == 0)

print("ExcludedListTest: OK")
