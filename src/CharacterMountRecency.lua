-- Character Mount: Roll memory.
--
-- Two rules share one piece of state, the last summon:
--
--   Stay on the same mount   A mount you got off after only moments comes back
--                            on the next summon instead of a fresh roll.
--   Vary your mounts         Anything summoned recently is skipped, so a short
--                            list stops repeating itself.
--
-- Both are decided from data passed in, so nothing here calls a WoW API and
-- tests/RecencyTest.lua can run the whole thing standalone.

CharacterMount = CharacterMount or {}
CharacterMount.Recency = {}

local Recency = CharacterMount.Recency

-- How many past summons "Vary your mounts" holds against the pool. Three keeps
-- a six mount list from doubling up without the block being felt on a big one.
Recency.HISTORY_SIZE = 3

--- Stable identity for a roll entry: a journal mount is its numeric ID, a
--- spell form the "spell:<id>" key it is stored under.
function Recency.Key(entry)
    return entry and entry.id
end

--- Note a summon. `key` leads the recent list unless `skipHistory` is set,
--- which is how a live holiday mount stays out of the way of the holiday
--- chance setting while still being the mount you can stay on.
function Recency.Record(state, key, category, now, skipHistory)
    if key == nil then return end

    state.last = { key = key, category = category, time = now }
    if skipHistory then return end

    local recent = state.recent or {}
    for i = #recent, 1, -1 do
        if recent[i] == key then table.remove(recent, i) end
    end
    table.insert(recent, 1, key)
    for i = #recent, Recency.HISTORY_SIZE + 1, -1 do
        recent[i] = nil
    end
    state.recent = recent
end

--- Note the dismount that ends the last summon's ride. Only the first one
--- counts: a later dismount belongs to something else (a spell form, a mount
--- summoned outside the addon) and must not overwrite how long the ride was.
function Recency.RecordDismount(state, now)
    local last = state.last
    if last and not last.ride then last.ride = now - last.time end
end

--- The entry to stay on, or nil to roll instead. A category change defeats it,
--- so a quick hop out of the water still gets you something that flies, and so
--- does a mount that has left the pool since.
---
--- What is measured is how long you were on the mount, summon to dismount, so
--- a short hop comes back however long ago you got off. Until the dismount has
--- been seen (still on it, or the summon never went off) the ride is counted
--- up to now, which is what the macro's pre-roll sees on the dismount click.
function Recency.StickyPick(pool, state, category, now, windowSeconds)
    local last = state.last
    if not windowSeconds or windowSeconds <= 0 then return nil end
    if not last or last.category ~= category then return nil end
    local ride = last.ride or (now - last.time)
    if ride >= windowSeconds then return nil end

    for i = 1, #pool do
        if Recency.Key(pool[i]) == last.key then return pool[i] end
    end
    return nil
end

--- `pool` with recently summoned entries taken out. The block is soft: the
--- oldest are given back one at a time until something is left to roll, so two
--- mounts alternate rather than falling back to a coin flip, and one mount
--- always comes up.
---
--- `isExempt(entry)` marks entries the block never applies to.
function Recency.Filter(pool, state, isExempt)
    local recent = state.recent
    if not recent or #recent == 0 or #pool == 0 then return pool end

    for depth = #recent, 1, -1 do
        local blocked = {}
        for i = 1, depth do blocked[recent[i]] = true end

        local kept = {}
        for i = 1, #pool do
            local entry = pool[i]
            if not blocked[Recency.Key(entry)] or (isExempt and isExempt(entry)) then
                kept[#kept + 1] = entry
            end
        end
        if #kept > 0 then return kept end
    end

    return pool
end
