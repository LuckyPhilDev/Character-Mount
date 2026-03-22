-- Character Mount: UI — mount list window and Mount Journal integration.
-- Uses pre-allocated frame pools to avoid the WoW API bug where CreateFrame
-- accumulates frames that cannot be freed.

CharacterMount = CharacterMount or {}

-- ---------------------------------------------------------------------------
-- Mount Journal integration — "Add/Remove" button on the journal detail panel
-- ---------------------------------------------------------------------------

function CharacterMount.HookMountJournalButton()
    if not MountJournal then return end
    if CharacterMount.journalButton then return end

    local db = CharacterMount.db

    local btn = LuckyUI.CreateButton(MountJournal.MountDisplay, "", 160, 22, "secondary")
    btn:SetPoint("BOTTOMLEFT", MountJournal.MountDisplay, "BOTTOMLEFT", 4, 4)

    local function GetSelectedMountID()
        return MountJournal.selectedMountID or 0
    end

    local function IsAutoMount(mountID)
        for _, entry in ipairs(CharacterMount.GetEffectiveMountList()) do
            if entry.id == mountID and (entry.source == "racial" or entry.source == "class") then
                return true
            end
        end
        return false
    end

    local function UpdateButton()
        local mountID = GetSelectedMountID()
        if not mountID or mountID == 0 then
            btn:SetText("No Mount Selected")
            btn:Disable()
            return
        end

        btn:Enable()
        if db.additions[mountID] or IsAutoMount(mountID) then
            btn:SetText("Remove from Char List")
        else
            btn:SetText("Add to Char List")
        end
    end

    btn:SetScript("OnClick", function()
        local mountID = GetSelectedMountID()
        if not mountID or mountID == 0 then return end

        if db.additions[mountID] or IsAutoMount(mountID) then
            CharacterMount.RemoveMount(mountID)
        else
            CharacterMount.AddMount(mountID)
        end
        UpdateButton()
    end)

    -- Hook selection changes to keep button text in sync
    if MountJournal_Select then
        hooksecurefunc("MountJournal_Select", function() UpdateButton() end)
    end
    MountJournal:HookScript("OnShow", function() C_Timer.After(0, UpdateButton) end)

    UpdateButton()
    CharacterMount.journalButton = btn
end

-- ---------------------------------------------------------------------------
-- Character Mount list window
-- ---------------------------------------------------------------------------

local C  = LuckyUI.C
local WC = LuckyUI.WC

local ACTIVE_POOL_SIZE = 25
local EXCL_POOL_SIZE   = 6
local ROW_HEIGHT       = 28
local ROW_GAP          = 2

-- ---------------------------------------------------------------------------
-- Internal: create one reusable row frame
-- hasSourceLabel: true for active rows, false for excluded rows
-- ---------------------------------------------------------------------------
local function CreateRow(parent, hasSourceLabel, rowWidth)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(ROW_HEIGHT)
    row:SetWidth(rowWidth)
    row:Hide()
    row:EnableMouse(true)

    -- Hover highlight (HIGHLIGHT layer auto-shows on mouse over)
    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(C.highlight[1], C.highlight[2], C.highlight[3], C.highlight[4])

    -- Mount icon
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(22, 22)
    row.icon:SetPoint("LEFT", row, "LEFT", 4, 0)

    -- Action button (styled secondary)
    local btnWidth = hasSourceLabel and 24 or 55
    row.actionBtn = LuckyUI.CreateButton(row, "", btnWidth, 22, "secondary")
    row.actionBtn:SetPoint("RIGHT", row, "RIGHT", -4, 0)

    -- Callback reads row.mountID / row.isExcluded set at refresh time.
    -- The closure captures `row` (the specific frame object), not a loop variable.
    row.actionBtn:SetScript("OnClick", function()
        if row.isExcluded then
            CharacterMount.UnexcludeMount(row.mountID)
        else
            CharacterMount.RemoveMount(row.mountID)
        end
    end)

    -- Name label — width depends on whether a source label shares the space
    local nameLabelWidth = rowWidth - 4 - 22 - 5 - (hasSourceLabel and 72 or 0) - 30
    row.nameLabel = row:CreateFontString(nil, "OVERLAY")
    row.nameLabel:SetFont(LuckyUI.BODY_FONT, 13)
    row.nameLabel:SetSize(nameLabelWidth, ROW_HEIGHT)
    row.nameLabel:SetPoint("LEFT", row.icon, "RIGHT", 5, 0)
    row.nameLabel:SetJustifyH("LEFT")
    row.nameLabel:SetJustifyV("MIDDLE")
    row.nameLabel:SetWordWrap(false)
    row.nameLabel:SetTextColor(C.textLight[1], C.textLight[2], C.textLight[3])

    if hasSourceLabel then
        row.pill = CreateFrame("Frame", nil, row)
        row.pill:SetHeight(16)
        row.pill:SetPoint("RIGHT", row.actionBtn, "LEFT", -4, 0)
        row.pillBg = row.pill:CreateTexture(nil, "BACKGROUND")
        row.pillBg:SetAllPoints()
        row.pillBg:SetColorTexture(1, 1, 1, 0.15)

        row.sourceLabel = row.pill:CreateFontString(nil, "OVERLAY")
        row.sourceLabel:SetFont(LuckyUI.BODY_FONT, 10)
        row.sourceLabel:SetPoint("CENTER", 0, 0)
        row.sourceLabel:SetJustifyH("CENTER")
        row.sourceLabel:SetJustifyV("MIDDLE")
    end

    return row
end

-- ---------------------------------------------------------------------------
-- CreateUI — called once on PLAYER_LOGIN
-- ---------------------------------------------------------------------------
function CharacterMount.CreateUI()
    if CharacterMount.frame then return end

    -- -----------------------------------------------------------------------
    -- Main frame (dark panel with gold border)
    -- -----------------------------------------------------------------------
    local frame = LuckyUI.CreatePanel("CharacterMount_ListFrame", UIParent, 360, 520)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("MEDIUM")
    frame:Hide()
    tinsert(UISpecialFrames, "CharacterMount_ListFrame")

    -- Header bar (gradient background, gold title, close button)
    LuckyUI.CreateHeader(frame, "Character Mounts")

    -- -----------------------------------------------------------------------
    -- Footer separator line
    -- -----------------------------------------------------------------------
    local footerLine = frame:CreateTexture(nil, "ARTWORK")
    footerLine:SetHeight(1)
    footerLine:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 10, 42)
    footerLine:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 42)
    footerLine:SetColorTexture(C.borderDark[1], C.borderDark[2], C.borderDark[3])

    -- -----------------------------------------------------------------------
    -- Bottom bar buttons
    -- -----------------------------------------------------------------------
    local mountBtn = LuckyUI.CreateButton(frame, "Mount Now", 95, 28, "primary")
    mountBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 8)
    mountBtn:SetScript("OnClick", function() CharacterMount.MountRandom() end)

    local macroBtn = LuckyUI.CreateButton(frame, "Create Macro", 100, 28, "secondary")
    macroBtn:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 10, 8)
    macroBtn:SetScript("OnClick", function() CharacterMount.CreateMacro() end)

    local setupBtn = LuckyUI.CreateButton(frame, "Setup", 55, 28, "secondary")
    setupBtn:SetPoint("LEFT", macroBtn, "RIGHT", 6, 0)
    setupBtn:SetScript("OnClick", function()
        frame:Hide()
        CharacterMount.ResetOnboarding()
    end)

    local journalOpenBtn = LuckyUI.CreateButton(frame, "Journal", 55, 28, "secondary")
    journalOpenBtn:SetPoint("RIGHT", mountBtn, "LEFT", -6, 0)
    journalOpenBtn:SetScript("OnClick", function()
        ToggleCollectionsJournal(1)  -- 1 = Mount Journal tab
    end)

    -- -----------------------------------------------------------------------
    -- Excluded rows (fixed positions above footer)
    -- -----------------------------------------------------------------------
    frame.excludedPool = {}
    for i = 1, EXCL_POOL_SIZE do
        local row = CreateRow(frame, false, 330)
        local fromBottom = 48 + (EXCL_POOL_SIZE - i) * (ROW_HEIGHT + ROW_GAP)
        row:SetPoint("BOTTOMLEFT",  frame, "BOTTOMLEFT",  10, fromBottom)
        row:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, fromBottom)
        row:SetHeight(ROW_HEIGHT)
        frame.excludedPool[i] = row
    end

    -- -----------------------------------------------------------------------
    -- Divider: thin line + "Excluded" label
    -- -----------------------------------------------------------------------
    local divider = LuckyUI.CreateDivider(frame, "Excluded")
    divider:SetPoint("BOTTOMLEFT",  frame, "BOTTOMLEFT",  10, 230)
    divider:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 230)
    divider:Hide()
    frame.divider = divider

    -- -----------------------------------------------------------------------
    -- Active scroll frame
    -- -----------------------------------------------------------------------
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT",     frame, "TOPLEFT",    10, -36)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 48)
    frame.scrollFrame = scrollFrame

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetWidth(330)
    content:SetHeight(250)
    scrollFrame:SetScrollChild(content)
    frame.content = content

    -- Empty-state hint (shown when active list is empty)
    local emptyHint = content:CreateFontString(nil, "OVERLAY")
    emptyHint:SetFont(LuckyUI.BODY_FONT, 13)
    emptyHint:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])
    emptyHint:SetPoint("TOPLEFT", content, "TOPLEFT", 10, -16)
    emptyHint:SetJustifyH("LEFT")
    emptyHint:SetWordWrap(true)
    emptyHint:SetWidth(250)
    emptyHint:SetText("No mounts yet.\nUse /cmount add <name> or add mounts from the mount journal.")
    emptyHint:Hide()
    frame.emptyHint = emptyHint

    -- Open Mount Journal button (shown alongside empty hint)
    local journalBtn = LuckyUI.CreateButton(content, "Open Mount Journal", 140, 24, "secondary")
    journalBtn:SetPoint("TOPLEFT", emptyHint, "BOTTOMLEFT", 0, -10)
    journalBtn:SetScript("OnClick", function()
        ToggleCollectionsJournal(1)  -- 1 = Mount Journal tab
    end)
    journalBtn:Hide()
    frame.journalBtn = journalBtn

    -- Pre-allocate active rows (positions are set in RefreshUI via ClearAllPoints)
    frame.activePool = {}
    for i = 1, ACTIVE_POOL_SIZE do
        frame.activePool[i] = CreateRow(content, true, 330)
    end

    CharacterMount.frame = frame
end

-- ---------------------------------------------------------------------------
-- RefreshUI — show/hide and reconfigure pool rows; never creates new frames
-- ---------------------------------------------------------------------------
function CharacterMount.RefreshUI()
    local frame = CharacterMount.frame
    if not frame then return end

    local content    = frame.content
    local activeList = CharacterMount.GetEffectiveMountList()

    -- -----------------------------------------------------------------------
    -- 1. Active rows
    -- -----------------------------------------------------------------------
    for i = 1, ACTIVE_POOL_SIZE do
        local row   = frame.activePool[i]
        local entry = activeList[i]
        if entry then
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", content, "TOPLEFT",
                         0, -6 - (i - 1) * (ROW_HEIGHT + ROW_GAP))
            row.icon:SetTexture(entry.icon)
            row.icon:SetDesaturated(false)
            row.nameLabel:SetText(entry.name)
            row.nameLabel:SetTextColor(C.textLight[1], C.textLight[2], C.textLight[3])
            if row.sourceLabel then
                local sl = CharacterMount.SourceLabel[entry.source] or ""
                local rgb = CharacterMount.SourcePillRGB[entry.source]
                row.sourceLabel:SetText(sl)
                if rgb then
                    row.sourceLabel:SetTextColor(rgb[1], rgb[2], rgb[3])
                    row.pillBg:SetColorTexture(rgb[1], rgb[2], rgb[3], 0.15)
                end
                local tw = row.sourceLabel:GetStringWidth()
                row.pill:SetWidth(math.max(tw + 12, 30))
                row.pill:Show()
            end
            row.actionBtn:SetText("\195\151")
            row.mountID    = entry.id
            row.isExcluded = false
            row:Show()
        else
            row:Hide()
        end
    end

    -- Resize scroll content to fit rows
    content:SetHeight(math.max(200, #activeList * (ROW_HEIGHT + ROW_GAP) + 14))

    -- Empty hint
    local isEmpty = #activeList == 0
    frame.emptyHint:SetShown(isEmpty)
    frame.journalBtn:SetShown(isEmpty)

    -- -----------------------------------------------------------------------
    -- 2. Excluded rows
    -- -----------------------------------------------------------------------
    local excludedList = {}
    for mountID in pairs(CharacterMount.db.exclusions) do
        local name, _, icon = C_MountJournal.GetMountInfoByID(mountID)
        if name then
            excludedList[#excludedList + 1] = { id = mountID, name = name, icon = icon }
        end
    end
    table.sort(excludedList, function(a, b) return a.name < b.name end)

    -- Resize scroll frame: expand to fill the frame when no excluded section is shown.
    local scrollBottomY = (#excludedList > 0) and 248 or 48
    frame.scrollFrame:ClearAllPoints()
    frame.scrollFrame:SetPoint("TOPLEFT",     frame, "TOPLEFT",    10, -36)
    frame.scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, scrollBottomY)

    if #excludedList > 0 then
        frame.divider:Show()
        for i = 1, EXCL_POOL_SIZE do
            local row  = frame.excludedPool[i]
            local item = excludedList[i]
            if item then
                row.icon:SetTexture(item.icon)
                row.icon:SetDesaturated(true)
                row.nameLabel:SetText(item.name)
                row.nameLabel:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])
                row.actionBtn:SetText("Restore")
                row.mountID    = item.id
                row.isExcluded = true
                row:Show()
            else
                row:Hide()
            end
        end
    else
        frame.divider:Hide()
        for i = 1, EXCL_POOL_SIZE do
            frame.excludedPool[i]:Hide()
        end
    end
end
