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

    local btn = CreateFrame("Button", nil, MountJournal.MountDisplay, "UIPanelButtonTemplate")
    btn:SetSize(160, 22)
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

local SOURCE_COLOUR = {
    racial  = "|cffadd8e6",  -- light blue
    class   = "|cffffd700",  -- gold
    manual  = "|cff90ee90",  -- light green
}
local SOURCE_LABEL = {
    racial  = "Racial",
    class   = "Class",
    manual  = "Manual",
}
local COLOUR_RESET = "|r"
local COLOUR_DIM   = "|cff888888"

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

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(22, 22)
    row.icon:SetPoint("LEFT", row, "LEFT", 4, 0)

    row.actionBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.actionBtn:SetSize(55, 22)
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
    local nameLabelWidth = rowWidth - 4 - 22 - 5 - (hasSourceLabel and 62 or 0) - 59
    row.nameLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.nameLabel:SetSize(nameLabelWidth, ROW_HEIGHT)
    row.nameLabel:SetPoint("LEFT", row.icon, "RIGHT", 5, 0)
    row.nameLabel:SetJustifyH("LEFT")
    row.nameLabel:SetJustifyV("MIDDLE")
    row.nameLabel:SetWordWrap(false)

    if hasSourceLabel then
        row.sourceLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.sourceLabel:SetSize(58, ROW_HEIGHT)
        row.sourceLabel:SetPoint("LEFT", row.nameLabel, "RIGHT", 4, 0)
        row.sourceLabel:SetJustifyH("LEFT")
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
    -- Main frame
    -- Frame height 520px:
    --   22px  title bar (top)
    --   248px active scroll frame
    --   16px  divider band (shown only when exclusions exist)
    --   178px excluded rows band  (6 rows × 28px + 5 × 2px gap)
    --   8px   gap
    --   28px  bottom bar
    --   8px   bottom padding
    -- -----------------------------------------------------------------------
    local frame = CreateFrame("Frame", "CharacterMount_ListFrame", UIParent,
                              "BasicFrameTemplateWithInset")
    frame:SetSize(320, 520)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop",  frame.StopMovingOrSizing)
    frame:Hide()
    frame.TitleText:SetText("Character Mounts")

    -- -----------------------------------------------------------------------
    -- Bottom bar (y=8 from frame bottom)
    -- -----------------------------------------------------------------------
    local mountBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    mountBtn:SetSize(95, 28)
    mountBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 8)
    mountBtn:SetText("Mount Now")
    mountBtn:SetScript("OnClick", function() CharacterMount.MountRandom() end)

    local macroBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    macroBtn:SetSize(75, 28)
    macroBtn:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 10, 8)
    macroBtn:SetText("Macro")
    macroBtn:SetScript("OnClick", function() CharacterMount.CreateMacro() end)

    -- -----------------------------------------------------------------------
    -- Excluded rows (fixed positions, y=44..222 from frame bottom)
    -- Row i=1 → topmost displayed entry; i=6 → bottommost.
    -- fromBottom(i) = 44 + (EXCL_POOL_SIZE - i) * (ROW_HEIGHT + ROW_GAP)
    -- -----------------------------------------------------------------------
    frame.excludedPool = {}
    for i = 1, EXCL_POOL_SIZE do
        local row = CreateRow(frame, false, 290)
        local fromBottom = 44 + (EXCL_POOL_SIZE - i) * (ROW_HEIGHT + ROW_GAP)
        row:SetPoint("BOTTOMLEFT",  frame, "BOTTOMLEFT",  10, fromBottom)
        row:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, fromBottom)
        row:SetHeight(ROW_HEIGHT)
        frame.excludedPool[i] = row
    end

    -- -----------------------------------------------------------------------
    -- Divider: thin line + "Excluded" label (y=226 from frame bottom)
    -- -----------------------------------------------------------------------
    local divider = CreateFrame("Frame", nil, frame)
    divider:SetPoint("BOTTOMLEFT",  frame, "BOTTOMLEFT",  10, 226)
    divider:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 226)
    divider:SetHeight(16)
    divider:Hide()

    local divLine = divider:CreateTexture(nil, "ARTWORK")
    divLine:SetColorTexture(0.35, 0.35, 0.35, 1)
    divLine:SetHeight(1)
    divLine:SetPoint("BOTTOMLEFT",  divider, "BOTTOMLEFT",  0, 4)
    divLine:SetPoint("BOTTOMRIGHT", divider, "BOTTOMRIGHT", 0, 4)

    local divLabel = divider:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    divLabel:SetPoint("BOTTOMLEFT", divider, "BOTTOMLEFT", 0, 6)
    divLabel:SetText(COLOUR_DIM .. "Excluded" .. COLOUR_RESET)

    frame.divider = divider

    -- -----------------------------------------------------------------------
    -- Active scroll frame (y=242..490 from frame bottom ≈ 248px tall)
    -- -----------------------------------------------------------------------
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT",     frame, "TOPLEFT",    10, -30)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 44)
    frame.scrollFrame = scrollFrame

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetWidth(270)
    content:SetHeight(250)
    scrollFrame:SetScrollChild(content)
    frame.content = content

    -- Empty-state hint (shown when active list is empty)
    local emptyHint = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    emptyHint:SetPoint("TOPLEFT", content, "TOPLEFT", 10, -16)
    emptyHint:SetJustifyH("LEFT")
    emptyHint:SetText(
        COLOUR_DIM ..
        "No mounts yet.\nUse: /cmount add <name>" ..
        COLOUR_RESET
    )
    emptyHint:Hide()
    frame.emptyHint = emptyHint

    -- Pre-allocate active rows (positions are set in RefreshUI via ClearAllPoints)
    frame.activePool = {}
    for i = 1, ACTIVE_POOL_SIZE do
        frame.activePool[i] = CreateRow(content, true, 270)
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
            if row.sourceLabel then
                local c = SOURCE_COLOUR[entry.source] or ""
                local l = SOURCE_LABEL[entry.source]  or ""
                row.sourceLabel:SetText(c .. l .. COLOUR_RESET)
                row.sourceLabel:Show()
            end
            row.actionBtn:SetText("Remove")
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
    frame.emptyHint:SetShown(#activeList == 0)

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
    local scrollBottomY = (#excludedList > 0) and 242 or 44
    frame.scrollFrame:ClearAllPoints()
    frame.scrollFrame:SetPoint("TOPLEFT",     frame, "TOPLEFT",    10, -30)
    frame.scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, scrollBottomY)

    if #excludedList > 0 then
        frame.divider:Show()
        for i = 1, EXCL_POOL_SIZE do
            local row  = frame.excludedPool[i]
            local item = excludedList[i]
            if item then
                row.icon:SetTexture(item.icon)
                row.icon:SetDesaturated(true)
                row.nameLabel:SetText(COLOUR_DIM .. item.name .. COLOUR_RESET)
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
