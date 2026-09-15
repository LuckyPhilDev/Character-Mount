-- luacheck: ignore 111 121

local function noop() end
local function stubTable()
    return setmetatable({}, { __index = function() return "" end })
end

-- A frame that tracks visibility and scripts; any other method is a no-op
-- returning another such frame, so textures and font strings come for free.
local function FakeFrame()
    local f = { shown = false, scripts = {} }
    function f:Show() self.shown = true end
    function f:Hide()
        if not self.shown then return end
        self.shown = false
        if self.scripts.OnHide then self.scripts.OnHide(self) end
    end
    function f:IsShown() return self.shown end
    function f:SetScript(event, fn) self.scripts[event] = fn end
    function f:Click() self.scripts.OnClick(self) end
    return setmetatable(f, { __index = function() return FakeFrame end })
end

LuckyUI = setmetatable({
    C = stubTable(), WC = stubTable(),
    CreatePanel = FakeFrame, CreateButton = FakeFrame,
}, { __index = function() return noop end })
CharacterMount = { Strings = stubTable() }
CreateFrame = FakeFrame

local timers = {}
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
local function RunTimers()
    local due = timers
    timers = {}
    for _, fn in ipairs(due) do fn() end
end

function tContains(t, value)
    for _, v in ipairs(t) do if v == value then return true end end
    return false
end

C_MountJournal = {
    GetMountInfoByID = function(id) return "Mount " .. id, nil, id end,
    GetMountInfoExtraByID = function() return 0 end,
}

local added = {}
CharacterMount.AddMount = function(id) added[#added + 1] = id end

dofile("src/CharacterMountUI.lua")

local Show = CharacterMount.ShowNewMountDialog

-- The reported bug: learning mounts back to back showed only the last one.
Show(1)
Show(2)
Show(2) -- the same mount twice is asked about once
Show(3)
local dialog = CharacterMount.newMountDialog
assert(dialog.mountID == 1)

dialog.btnCurrent:Click()
assert(not dialog:IsShown())
RunTimers()
assert(dialog:IsShown() and dialog.mountID == 2)

dialog.btnClose:Click()
RunTimers()
assert(dialog.mountID == 3)

dialog.btnCurrent:Click()
RunTimers()
assert(not dialog:IsShown())
assert(table.concat(added, ",") == "1,3")

print("NewMountQueueTest passed")
