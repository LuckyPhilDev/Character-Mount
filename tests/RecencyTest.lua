-- luacheck: ignore 111 121

dofile("src/CharacterMountRecency.lua")

local R = CharacterMount.Recency

local function mount(id, holiday) return { id = id, holiday = holiday } end
local function isLiveHoliday(entry) return entry.holiday == true end

local function ids(pool)
    local out = {}
    for i, entry in ipairs(pool) do out[i] = tostring(entry.id) end
    return table.concat(out, ",")
end

local function newState() return { recent = {} } end

-- ---------------------------------------------------------------------------
-- Vary your mounts
-- ---------------------------------------------------------------------------

local SIX = { mount(1), mount(2), mount(3), mount(4), mount(5), mount(6) }

-- The reported bug: on a short list the last few summons are held back, so the
-- same mount cannot come up over and over.
local state = newState()
R.Record(state, 1, "ground", 0)
R.Record(state, 2, "ground", 10)
R.Record(state, 3, "ground", 20)
assert(ids(R.Filter(SIX, state)) == "4,5,6")

-- Only HISTORY_SIZE summons are held, so the fourth lets the first back in.
R.Record(state, 4, "ground", 30)
assert(ids(R.Filter(SIX, state)) == "1,5,6")

-- Re-summoning something already held moves it to the front rather than
-- filling the history with duplicates of one mount.
state = newState()
R.Record(state, 1, "ground", 0)
R.Record(state, 2, "ground", 10)
R.Record(state, 1, "ground", 20)
assert(ids(R.Filter(SIX, state)) == "3,4,5,6")

-- The block is soft. Two mounts alternate: blocking both would leave nothing,
-- so the older one is given back and the newer stays held.
local TWO = { mount(1), mount(2) }
state = newState()
R.Record(state, 1, "ground", 0)
assert(ids(R.Filter(TWO, state)) == "2")
R.Record(state, 2, "ground", 10)
assert(ids(R.Filter(TWO, state)) == "1")
R.Record(state, 1, "ground", 20)
assert(ids(R.Filter(TWO, state)) == "2")

-- One water mount still comes up every time you go underwater.
local ONE = { mount(9) }
state = newState()
R.Record(state, 9, "water", 0)
assert(ids(R.Filter(ONE, state)) == "9")

-- An empty history leaves the pool alone.
assert(ids(R.Filter(SIX, newState())) == "1,2,3,4,5,6")

-- ---------------------------------------------------------------------------
-- Holidays
-- ---------------------------------------------------------------------------

-- A mount whose event is running is never held back, so the holiday chance
-- setting gives the odds it says it does.
local WITH_HOLIDAY = { mount(1), mount(2, true), mount(3) }
state = newState()
R.Record(state, 1, "ground", 0)
R.Record(state, 2, "ground", 10, true)
R.Record(state, 3, "ground", 20)
assert(ids(R.Filter(WITH_HOLIDAY, state, isLiveHoliday)) == "2")

-- ...and it never enters the history either, so it does not push a normal
-- mount out of the list of what to avoid.
assert(#state.recent == 2)
assert(state.recent[1] == 3 and state.recent[2] == 1)

-- It is still the mount you can stay on, though.
assert(state.last.key == 3)

-- ---------------------------------------------------------------------------
-- Stay on the same mount
-- ---------------------------------------------------------------------------

-- Tuulani's rule: on a mount for less than the window, and the next summon is
-- that mount again, however long ago you got off it.
state = newState()
R.Record(state, 4, "ground", 100)
R.RecordDismount(state, 103)
assert(R.StickyPick(SIX, state, "ground", 105, 10).id == 4)
assert(R.StickyPick(SIX, state, "ground", 900, 10).id == 4)

-- A ride as long as the window rolls as normal, even straight after.
state = newState()
R.Record(state, 4, "ground", 100)
R.RecordDismount(state, 110)
assert(R.StickyPick(SIX, state, "ground", 111, 10) == nil)

-- Only the first dismount ends the ride. A later one (a spell form, a mount
-- summoned outside the addon) does not stretch a short hop into a long one.
state = newState()
R.Record(state, 4, "ground", 100)
R.RecordDismount(state, 103)
R.RecordDismount(state, 500)
assert(R.StickyPick(SIX, state, "ground", 501, 10).id == 4)

-- No dismount seen yet, so the ride is counted up to now. This is what the
-- macro's pre-roll sees on the dismount click, and what a summon that never
-- went off leaves behind.
state = newState()
R.Record(state, 4, "ground", 100)
assert(R.StickyPick(SIX, state, "ground", 105, 10).id == 4)
assert(R.StickyPick(SIX, state, "ground", 110, 10) == nil)

-- Zero seconds turns the whole thing off.
R.RecordDismount(state, 103)
assert(R.StickyPick(SIX, state, "ground", 105, 0) == nil)
assert(R.StickyPick(SIX, state, "ground", 105, nil) == nil)

-- Tuulani's case: hitting the water must not put you back on the ground mount.
assert(R.StickyPick(SIX, state, "water", 105, 10) == nil)

-- A mount that has left the pool (excluded, off for this spec, holiday over)
-- falls through to a roll instead of being summoned anyway.
assert(R.StickyPick({ mount(1), mount(2) }, state, "ground", 105, 10) == nil)

-- ---------------------------------------------------------------------------
-- Forget it after
-- ---------------------------------------------------------------------------

-- Tuulani's case: fish, re-summon, fish again. The mount keeps coming back
-- until the cap, counted from when it first came up, then a roll takes over.
state = newState()
R.Record(state, 4, "ground", 100)
for hop = 1, 4 do
    local off = 100 + hop * 60
    R.RecordDismount(state, off - 57)
    assert(R.StickyPick(SIX, state, "ground", off, 10, 300).id == 4)
    R.Record(state, 4, "ground", off)
end
R.RecordDismount(state, 343)
assert(R.StickyPick(SIX, state, "ground", 399, 10, 300).id == 4)
assert(R.StickyPick(SIX, state, "ground", 400, 10, 300) == nil)

-- Re-summoning is what the cap has to survive: it must not restart the clock.
assert(state.last.time == 340 and state.last.since == 100)

-- The ride itself is still short, so only the cap ended it. Zero holds on.
assert(R.StickyPick(SIX, state, "ground", 400, 10, 0).id == 4)
assert(R.StickyPick(SIX, state, "ground", 400, 10, nil).id == 4)

-- Summoning something else starts a fresh clock rather than inheriting one.
state = newState()
R.Record(state, 4, "ground", 100)
R.Record(state, 5, "ground", 500)
R.RecordDismount(state, 503)
assert(R.StickyPick(SIX, state, "ground", 600, 10, 300).id == 5)

-- A dismount with nothing summoned is nothing to remember.
R.RecordDismount(newState(), 100)

-- Nothing summoned yet.
assert(R.StickyPick(SIX, newState(), "ground", 105, 10) == nil)

print("RecencyTest: OK")
