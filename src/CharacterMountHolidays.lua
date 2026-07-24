-- Character Mount: active-holiday detection via the in-game calendar.
-- The mount journal has no holiday link, so "is this holiday running today?"
-- is answered by scanning today's calendar day-events for HOLIDAY entries and
-- caching their titles. CharacterMount.MountData.HOLIDAY_MOUNTS joins a mount
-- to a title; this module answers whether that title is live.

CharacterMount = CharacterMount or {}

local devLog = LuckyLog:New("CharMount", function()
    return CharacterMountDB and CharacterMountDB.debugMode
end)

-- Set of holiday titles running today: activeTitles[title] = true.
local activeTitles = {}

-- The calendar reads events relative to its currently-viewed month, which the
-- player can change by browsing. Compute the offset from that month to today's
-- so a scan is always correct without snapping their calendar view around.
local function CurrentMonthOffset(now)
    local viewed = C_Calendar.GetMonthInfo(0)
    if not viewed then return 0 end
    return (now.year * 12 + now.month) - (viewed.year * 12 + viewed.month)
end

local function Rebuild()
    if not (C_DateAndTime and C_Calendar) then return end
    local now = C_DateAndTime.GetCurrentCalendarTime()
    if not now then return end

    local offset = CurrentMonthOffset(now)
    local count  = C_Calendar.GetNumDayEvents(offset, now.monthDay) or 0
    local titles = {}
    for i = 1, count do
        local e = C_Calendar.GetDayEvent(offset, now.monthDay, i)
        -- A HOLIDAY event listed on today's date runs today, whatever its
        -- sequenceType (START / ONGOING / END all touch the current day).
        if e and e.calendarType == "HOLIDAY" and e.title then
            titles[e.title] = true
        end
    end
    activeTitles = titles

    local list = {}
    for title in pairs(titles) do list[#list + 1] = title end
    devLog("[HOLIDAY] active: " .. (next(titles) and table.concat(list, ", ") or "none"))
end

--- Force a re-read of today's holidays from already-loaded calendar data.
function CharacterMount.RefreshHolidays()
    Rebuild()
end

--- Is a holiday (by its exact calendar title) running right now?
function CharacterMount.IsHolidayActive(title)
    return title ~= nil and activeTitles[title] == true
end

--- The set of currently-running holiday titles (read-only).
function CharacterMount.GetActiveHolidays()
    return activeTitles
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("CALENDAR_UPDATE_EVENT_LIST")
frame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        if C_Calendar and C_Calendar.OpenCalendar then
            C_Calendar.OpenCalendar()          -- loads current-month event data
        end
        -- Re-scan periodically so day-boundary and holiday start/end changes
        -- are picked up mid-session. ponytail: 30 min is plenty; holidays span
        -- days, so precision to the minute is never needed.
        C_Timer.NewTicker(1800, Rebuild)
        C_Timer.After(6, Rebuild)              -- first read once data has loaded
    else -- CALENDAR_UPDATE_EVENT_LIST: event data (re)loaded
        Rebuild()
    end
end)
