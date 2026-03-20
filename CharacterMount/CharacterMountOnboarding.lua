-- Character Mount: Onboarding — first-time mount selection flow.
-- Presents class, suggested class, racial, suggested race, and rare mounts for the user to opt into.
-- Uses pre-allocated frame pools (same pattern as CharacterMountUI.lua).

CharacterMount = CharacterMount or {}

local PREFIX = "|cff00cc00CharMount:|r"

-- ---------------------------------------------------------------------------
-- Constants
-- ---------------------------------------------------------------------------

local ROW_HEIGHT    = 26
local ROW_GAP       = 2
local HEADER_HEIGHT = 20
local POOL_SIZE     = 60   -- pre-allocated checkbox rows

local SOURCE_PRIORITY = { "class", "suggested_class", "racial", "suggested_race", "rare" }
local SOURCE_DISPLAY_ORDER = {   -- sort order within each category
    racial          = 1,
    suggested_race  = 2,
    class           = 3,
    suggested_class = 4,
    rare            = 5,
}
local SOURCE_LABELS = {
    class           = "Class",
    suggested_class = "Suggested",
    racial          = "Racial",
    suggested_race  = "Suggested",
    rare            = "Rare",
}
local SOURCE_COLOURS = {
    class           = "|cffffd700",  -- gold
    suggested_class = "|cff90ee90",  -- light green
    racial          = "|cffadd8e6",  -- light blue
    suggested_race  = "|cff90ee90",  -- light green
    rare            = "|cffcc99ff",  -- light purple
}
local COLOUR_RESET = "|r"
local COLOUR_DIM   = "|cff888888"

local CATEGORY_ORDER  = { "ground", "flying", "water" }
local CATEGORY_LABELS = {
    ground = "Ground",
    flying = "Flying",
    water  = "Water",
}

-- ---------------------------------------------------------------------------
-- Mount type classification (reuses MountHelpers globals)
-- ---------------------------------------------------------------------------

local FLYING_TYPE_IDS = { [247]=true, [248]=true, [398]=true, [407]=true, [424]=true, [402]=true }
local WATER_TYPE_IDS  = { [231]=true, [254]=true, [232]=true }
-- Everything else is ground

local function ClassifyMount(mountID)
    local _, _, _, _, mountTypeID = C_MountJournal.GetMountInfoExtraByID(mountID)
    if not mountTypeID then return "ground" end
    if FLYING_TYPE_IDS[mountTypeID] then return "flying" end
    if WATER_TYPE_IDS[mountTypeID]  then return "water" end
    return "ground"
end

-- ---------------------------------------------------------------------------
-- Build the candidate list
-- ---------------------------------------------------------------------------

local function BuildCandidates()
    local _, englishRace = UnitRace("player")
    local _, classFile   = UnitClass("player")
    local MD = CharacterMount.MountData

    -- Gather IDs per source
    local pools = {
        class           = MD.GetClassMountIDs(classFile),
        suggested_class = MD.GetSuggestedClassMountIDs(classFile),
        racial          = MD.GetRacialMountIDs(englishRace),
        suggested_race  = MD.GetSuggestedRaceMountIDs(englishRace),
        rare            = MD.GetRareMountIDs(),
    }

    -- Dedupe across sources (higher priority source wins)
    local seen = {}
    local entries = {}   -- { id, name, icon, source, category, checked }

    for _, source in ipairs(SOURCE_PRIORITY) do
        for _, mountID in ipairs(pools[source]) do
            if not seen[mountID] then
                local name, _, icon, _, _, _, _, _, _, shouldHideOnChar, isCollected =
                    C_MountJournal.GetMountInfoByID(mountID)
                if isCollected and name and not shouldHideOnChar then
                    seen[mountID] = true
                    local preChecked = (source ~= "rare")
                    entries[#entries + 1] = {
                        id       = mountID,
                        name     = name,
                        icon     = icon,
                        source   = source,
                        category = ClassifyMount(mountID),
                        group    = MD.GetMountGroup(mountID),
                        checked  = preChecked,
                    }
                end
            end
        end
    end

    return entries
end

-- ---------------------------------------------------------------------------
-- Group entries by category, then by mount group within each category
-- Returns: { [cat] = { { group="Gryphons", entries={...} }, { group=nil, entries={...} }, ... } }
-- ---------------------------------------------------------------------------

local function GroupByCategory(entries)
    local catGroups = {}
    for _, cat in ipairs(CATEGORY_ORDER) do
        catGroups[cat] = {}
    end

    -- Bucket entries by category
    local byCat = {}
    for _, cat in ipairs(CATEGORY_ORDER) do byCat[cat] = {} end
    for _, entry in ipairs(entries) do
        local cat = entry.category
        if not byCat[cat] then byCat[cat] = {} end
        byCat[cat][#byCat[cat] + 1] = entry
    end

    -- Within each category, sub-group by mount group
    for _, cat in ipairs(CATEGORY_ORDER) do
        local catEntries = byCat[cat]
        local groupOrder = {}   -- ordered list of group names seen
        local byGroup = {}      -- { [groupName] = { entry, ... } }
        local ungrouped = {}

        for _, entry in ipairs(catEntries) do
            local grp = entry.group
            if grp then
                if not byGroup[grp] then
                    byGroup[grp] = {}
                    groupOrder[#groupOrder + 1] = grp
                end
                byGroup[grp][#byGroup[grp] + 1] = entry
            else
                ungrouped[#ungrouped + 1] = entry
            end
        end

        -- Sort helper: by source display order, then alphabetically
        local function sortEntries(a, b)
            local oa = SOURCE_DISPLAY_ORDER[a.source] or 99
            local ob = SOURCE_DISPLAY_ORDER[b.source] or 99
            if oa ~= ob then return oa < ob end
            return (a.name or "") < (b.name or "")
        end

        -- Build sub-groups list
        local result = {}

        -- Named groups stay together as one block each
        for _, grp in ipairs(groupOrder) do
            table.sort(byGroup[grp], sortEntries)
            result[#result + 1] = { group = grp, entries = byGroup[grp] }
        end

        -- Split ungrouped entries by source so each source sorts independently
        if #ungrouped > 0 then
            local bySource = {}
            local sourcesSeen = {}
            for _, entry in ipairs(ungrouped) do
                local src = entry.source
                if not bySource[src] then
                    bySource[src] = {}
                    sourcesSeen[#sourcesSeen + 1] = src
                end
                bySource[src][#bySource[src] + 1] = entry
            end
            for _, src in ipairs(sourcesSeen) do
                table.sort(bySource[src], sortEntries)
                result[#result + 1] = { group = nil, entries = bySource[src] }
            end
        end

        -- Sort all blocks by source display order, then groups before singles
        table.sort(result, function(a, b)
            local ea = a.entries[1]
            local eb = b.entries[1]
            local oa = ea and (SOURCE_DISPLAY_ORDER[ea.source] or 99) or 99
            local ob = eb and (SOURCE_DISPLAY_ORDER[eb.source] or 99) or 99
            if oa ~= ob then return oa < ob end
            -- Same source: named groups before ungrouped singles
            local aGrouped = a.group and true or false
            local bGrouped = b.group and true or false
            if aGrouped ~= bGrouped then return aGrouped end
            -- Both grouped or both ungrouped: alphabetical by group name
            if a.group and b.group then return a.group < b.group end
            return false
        end)

        catGroups[cat] = result
    end

    return catGroups
end

-- ---------------------------------------------------------------------------
-- Create one checkbox row (pre-allocated)
-- ---------------------------------------------------------------------------

local function CreateCheckboxRow(parent, rowWidth)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(ROW_HEIGHT)
    row:SetWidth(rowWidth)
    row:Hide()

    row.check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    row.check:SetSize(22, 22)
    row.check:SetPoint("LEFT", row, "LEFT", 0, 0)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(20, 20)
    row.icon:SetPoint("LEFT", row.check, "RIGHT", 2, 0)

    row.nameLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.nameLabel:SetPoint("LEFT", row.icon, "RIGHT", 5, 0)
    row.nameLabel:SetPoint("RIGHT", row, "RIGHT", -60, 0)
    row.nameLabel:SetJustifyH("LEFT")
    row.nameLabel:SetJustifyV("MIDDLE")
    row.nameLabel:SetWordWrap(false)

    row.sourceLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.sourceLabel:SetSize(55, ROW_HEIGHT)
    row.sourceLabel:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    row.sourceLabel:SetJustifyH("RIGHT")
    row.sourceLabel:SetJustifyV("MIDDLE")

    return row
end

-- ---------------------------------------------------------------------------
-- Create a category header (pre-allocated)
-- ---------------------------------------------------------------------------

local function CreateCategoryHeader(parent, width)
    local header = CreateFrame("Frame", nil, parent)
    header:SetHeight(HEADER_HEIGHT)
    header:SetWidth(width)
    header:Hide()

    header.check = CreateFrame("CheckButton", nil, header, "UICheckButtonTemplate")
    header.check:SetSize(22, 22)
    header.check:SetPoint("LEFT", header, "LEFT", 0, 0)

    header.text = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header.text:SetPoint("LEFT", header.check, "RIGHT", 2, 0)
    header.text:SetJustifyH("LEFT")

    local line = header:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(0.4, 0.4, 0.4, 0.8)
    line:SetHeight(1)
    line:SetPoint("LEFT", header.text, "RIGHT", 6, 0)
    line:SetPoint("RIGHT", header, "RIGHT", -4, 0)
    header.line = line

    return header
end

-- ---------------------------------------------------------------------------
-- Create a sub-group header (smaller, indented)
-- ---------------------------------------------------------------------------

local SUBHEADER_HEIGHT = 20

local function CreateSubGroupHeader(parent, width)
    local header = CreateFrame("Frame", nil, parent)
    header:SetHeight(SUBHEADER_HEIGHT)
    header:SetWidth(width)
    header:Hide()

    header.check = CreateFrame("CheckButton", nil, header, "UICheckButtonTemplate")
    header.check:SetSize(22, 22)
    header.check:SetPoint("LEFT", header, "LEFT", 0, 0)

    header.text = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    header.text:SetPoint("LEFT", header.check, "RIGHT", 2, 0)
    header.text:SetJustifyH("LEFT")

    return header
end

-- ---------------------------------------------------------------------------
-- Onboarding frame (created once, shown/hidden)
-- ---------------------------------------------------------------------------

local onboardingFrame
local rowPool = {}
local headerPool = {}
local subHeaderPool = {}
local HEADER_POOL_SIZE    = #CATEGORY_ORDER
local SUBHEADER_POOL_SIZE = 20  -- enough for sub-groups across all categories

function CharacterMount.ShowOnboarding()
    if onboardingFrame then
        onboardingFrame:Show()
        CharacterMount.RefreshOnboarding()
        return
    end

    -- -----------------------------------------------------------------------
    -- Main frame
    -- -----------------------------------------------------------------------
    local frame = CreateFrame("Frame", "CharacterMount_OnboardingFrame", UIParent,
                              "BasicFrameTemplateWithInset")
    frame:SetSize(380, 560)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop",  frame.StopMovingOrSizing)
    frame:SetFrameStrata("DIALOG")

    -- Title
    frame.TitleText:SetText("Set Up Your Mounts")

    -- Subtitle with character name, race, class (class-coloured)
    local localRace              = UnitRace("player")
    local localClass, classFile  = UnitClass("player")
    local playerName = UnitName("player")
    local classColour = RAID_CLASS_COLORS[classFile]
    local colourHex = classColour and classColour:GenerateHexColor() or "ffffffff"
    local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    subtitle:SetPoint("TOPLEFT", frame.InsetBorderTop or frame.Inset or frame, "TOPLEFT", 8, -8)
    subtitle:SetText("|c" .. colourHex .. playerName .. " - " .. localRace .. " " .. localClass .. COLOUR_RESET)

    -- Description blurb
    local blurb = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    blurb:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -6)
    blurb:SetPoint("RIGHT", frame, "RIGHT", -20, 0)
    blurb:SetJustifyH("LEFT")
    blurb:SetWordWrap(true)
    blurb:SetText(COLOUR_DIM
        .. "Choose mounts below to get your character list started. "
        .. "You can add or remove mounts later from the journal or "
        .. "by opening the /cmount menu."
        .. COLOUR_RESET)

    -- -----------------------------------------------------------------------
    -- Scroll frame
    -- -----------------------------------------------------------------------
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", blurb, "BOTTOMLEFT", -4, -6)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 48)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetWidth(320)
    content:SetHeight(100)  -- resized during refresh
    scrollFrame:SetScrollChild(content)
    frame.content = content

    -- -----------------------------------------------------------------------
    -- Pre-allocate pools
    -- -----------------------------------------------------------------------
    for i = 1, POOL_SIZE do
        rowPool[i] = CreateCheckboxRow(content, 320)
    end
    for i = 1, HEADER_POOL_SIZE do
        headerPool[i] = CreateCategoryHeader(content, 320)
    end
    for i = 1, SUBHEADER_POOL_SIZE do
        subHeaderPool[i] = CreateSubGroupHeader(content, 320)
    end

    -- -----------------------------------------------------------------------
    -- Empty state
    -- -----------------------------------------------------------------------
    local emptyHint = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    emptyHint:SetPoint("TOPLEFT", content, "TOPLEFT", 10, -20)
    emptyHint:SetText(COLOUR_DIM .. "No suggested mounts found for your character." .. COLOUR_RESET)
    emptyHint:Hide()
    frame.emptyHint = emptyHint

    -- -----------------------------------------------------------------------
    -- Bottom bar
    -- -----------------------------------------------------------------------
    local addBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    addBtn:SetSize(120, 28)
    addBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 10)
    addBtn:SetText("Add Selected")
    addBtn:SetScript("OnClick", function()
        CharacterMount.ApplyOnboarding()
    end)

    local skipBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    skipBtn:SetSize(80, 28)
    skipBtn:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 10, 10)
    skipBtn:SetText("Skip")
    skipBtn:SetScript("OnClick", function()
        CharacterMount.SkipOnboarding()
    end)

    -- Select All / Deselect All
    local selectAllBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    selectAllBtn:SetSize(90, 28)
    selectAllBtn:SetPoint("BOTTOM", frame, "BOTTOM", 0, 10)
    selectAllBtn:SetText("Select All")
    selectAllBtn:SetScript("OnClick", function()
        CharacterMount.ToggleAllOnboarding(true)
    end)
    frame.selectAllBtn = selectAllBtn

    onboardingFrame = frame
    CharacterMount.onboardingFrame = frame
    CharacterMount.RefreshOnboarding()
end

-- ---------------------------------------------------------------------------
-- Refresh the onboarding content
-- ---------------------------------------------------------------------------

-- Store entries for Apply to read
local currentEntries = {}

function CharacterMount.RefreshOnboarding()
    if not onboardingFrame then return end

    local content = onboardingFrame.content
    local entries = BuildCandidates()
    currentEntries = entries
    local catGroups = GroupByCategory(entries)

    -- Hide all pool frames
    for i = 1, POOL_SIZE do rowPool[i]:Hide() end
    for i = 1, HEADER_POOL_SIZE do headerPool[i]:Hide() end
    for i = 1, SUBHEADER_POOL_SIZE do subHeaderPool[i]:Hide() end

    if #entries == 0 then
        onboardingFrame.emptyHint:Show()
        content:SetHeight(100)
        return
    end
    onboardingFrame.emptyHint:Hide()

    local rowIdx       = 1
    local headerIdx    = 1
    local subHeaderIdx = 1
    local yOffset      = -4

    -- Collect all entries for a category (flat) for the category-level toggle
    local function FlatCatEntries(subGroups)
        local flat = {}
        for _, sg in ipairs(subGroups) do
            for _, entry in ipairs(sg.entries) do
                flat[#flat + 1] = entry
            end
        end
        return flat
    end

    for _, cat in ipairs(CATEGORY_ORDER) do
        local subGroups = catGroups[cat]
        if subGroups and #subGroups > 0 then
            local catRowStart = rowIdx
            local flatEntries = FlatCatEntries(subGroups)

            -- Category header
            if headerIdx <= HEADER_POOL_SIZE then
                local header = headerPool[headerIdx]
                header:ClearAllPoints()
                header:SetPoint("TOPLEFT", content, "TOPLEFT", 0, yOffset)
                header.text:SetText("|cffffffff" .. CATEGORY_LABELS[cat] .. COLOUR_RESET)

                local allChecked = true
                for _, entry in ipairs(flatEntries) do
                    if not entry.checked then allChecked = false; break end
                end
                header.check:SetChecked(allChecked)

                header.catEntries  = flatEntries
                header.catRowStart = catRowStart
                header.catRowCount = #flatEntries
                header.check:SetScript("OnClick", function(self)
                    local checked = self:GetChecked()
                    for _, entry in ipairs(self:GetParent().catEntries) do
                        entry.checked = checked
                    end
                    local start = self:GetParent().catRowStart
                    local count = self:GetParent().catRowCount
                    for i = start, math.min(start + count - 1, POOL_SIZE) do
                        if rowPool[i]:IsShown() and rowPool[i].entryRef then
                            rowPool[i].check:SetChecked(rowPool[i].entryRef.checked)
                        end
                    end
                    -- Also update sub-group header checkboxes
                    for i = 1, SUBHEADER_POOL_SIZE do
                        local sh = subHeaderPool[i]
                        if sh:IsShown() and sh.sgEntries then
                            local sgAll = true
                            for _, e in ipairs(sh.sgEntries) do
                                if not e.checked then sgAll = false; break end
                            end
                            sh.check:SetChecked(sgAll)
                        end
                    end
                end)

                header:Show()
                headerIdx = headerIdx + 1
                yOffset = yOffset - HEADER_HEIGHT
            end

            -- Sub-groups within this category
            for _, sg in ipairs(subGroups) do
                local sgRowStart = rowIdx

                -- Sub-group header (only for named groups with 2+ mounts)
                if sg.group and #sg.entries > 1 and subHeaderIdx <= SUBHEADER_POOL_SIZE then
                    local sh = subHeaderPool[subHeaderIdx]
                    sh:ClearAllPoints()
                    sh:SetPoint("TOPLEFT", content, "TOPLEFT", 20, yOffset)
                    sh.text:SetText(COLOUR_DIM .. sg.group .. COLOUR_RESET)

                    local allChecked = true
                    for _, entry in ipairs(sg.entries) do
                        if not entry.checked then allChecked = false; break end
                    end
                    sh.check:SetChecked(allChecked)

                    sh.sgEntries  = sg.entries
                    sh.sgRowStart = sgRowStart
                    sh.sgRowCount = #sg.entries
                    sh.check:SetScript("OnClick", function(self)
                        local checked = self:GetChecked()
                        for _, entry in ipairs(self:GetParent().sgEntries) do
                            entry.checked = checked
                        end
                        local start = self:GetParent().sgRowStart
                        local count = self:GetParent().sgRowCount
                        for i = start, math.min(start + count - 1, POOL_SIZE) do
                            if rowPool[i]:IsShown() and rowPool[i].entryRef then
                                rowPool[i].check:SetChecked(rowPool[i].entryRef.checked)
                            end
                        end
                    end)

                    sh:Show()
                    subHeaderIdx = subHeaderIdx + 1
                    yOffset = yOffset - SUBHEADER_HEIGHT
                end

                -- Mount rows
                local indent = (sg.group and #sg.entries > 1) and 34 or 0
                for _, entry in ipairs(sg.entries) do
                    if rowIdx > POOL_SIZE then break end
                    local row = rowPool[rowIdx]
                    row:ClearAllPoints()
                    row:SetPoint("TOPLEFT", content, "TOPLEFT", indent, yOffset)
                    row:SetWidth(320 - indent)

                    row.icon:SetTexture(entry.icon)
                    row.nameLabel:SetText(entry.name)

                    local sc = SOURCE_COLOURS[entry.source] or ""
                    local sl = SOURCE_LABELS[entry.source]  or ""
                    row.sourceLabel:SetText(sc .. sl .. COLOUR_RESET)

                    row.check:SetChecked(entry.checked)
                    row.entryRef = entry
                    row.check:SetScript("OnClick", function(self)
                        if row.entryRef then
                            row.entryRef.checked = self:GetChecked()
                        end
                    end)

                    row:Show()
                    rowIdx  = rowIdx + 1
                    yOffset = yOffset - (ROW_HEIGHT + ROW_GAP)
                end
            end
        end
    end

    content:SetHeight(math.max(100, math.abs(yOffset) + 10))
end

-- ---------------------------------------------------------------------------
-- Toggle all checkboxes
-- ---------------------------------------------------------------------------

function CharacterMount.ToggleAllOnboarding(state)
    for _, entry in ipairs(currentEntries) do
        entry.checked = state
    end
    -- Update visible mount checkboxes
    for i = 1, POOL_SIZE do
        local row = rowPool[i]
        if row:IsShown() and row.entryRef then
            row.check:SetChecked(row.entryRef.checked)
        end
    end
    -- Update category header checkboxes
    for i = 1, HEADER_POOL_SIZE do
        local h = headerPool[i]
        if h:IsShown() then h.check:SetChecked(state) end
    end
    -- Update sub-group header checkboxes
    for i = 1, SUBHEADER_POOL_SIZE do
        local sh = subHeaderPool[i]
        if sh:IsShown() then sh.check:SetChecked(state) end
    end
end

-- ---------------------------------------------------------------------------
-- Apply selections
-- ---------------------------------------------------------------------------

function CharacterMount.ApplyOnboarding()
    local count = 0
    for _, entry in ipairs(currentEntries) do
        if entry.checked then
            -- Silently add without printing per-mount messages
            CharacterMount.db.exclusions[entry.id] = nil
            CharacterMount.db.additions[entry.id]  = true
            count = count + 1
        end
    end

    CharacterMount.db.onboardingComplete = true
    onboardingFrame:Hide()

    print(PREFIX .. " Added " .. count .. " mounts to your list.")
    if CharacterMount.RefreshUI then CharacterMount.RefreshUI() end
end

-- ---------------------------------------------------------------------------
-- Skip onboarding
-- ---------------------------------------------------------------------------

function CharacterMount.SkipOnboarding()
    CharacterMount.db.onboardingComplete = true
    onboardingFrame:Hide()
    print(PREFIX .. " Onboarding skipped. Use /cmount add <name> to add mounts later.")
end

-- ---------------------------------------------------------------------------
-- Reset onboarding (for testing)
-- ---------------------------------------------------------------------------

function CharacterMount.ResetOnboarding()
    CharacterMount.db.onboardingComplete = nil
    CharacterMount.db.additions  = {}
    CharacterMount.db.exclusions = {}
    if CharacterMount.RefreshUI then CharacterMount.RefreshUI() end
    CharacterMount.ShowOnboarding()
    print(PREFIX .. " Onboarding reset.")
end
