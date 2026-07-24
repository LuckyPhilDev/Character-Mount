-- Character Mount: UI — mount list window and Mount Journal integration.
-- Uses pre-allocated frame pools to avoid the WoW API bug where CreateFrame
-- accumulates frames that cannot be freed.

CharacterMount = CharacterMount or {}

local C = LuckyUI.C

-- ---------------------------------------------------------------------------
-- Mount Journal integration — "Add/Remove" button on the journal detail panel
-- ---------------------------------------------------------------------------

local function NormalizeMountID(mountID)
    if type(mountID) == "string" then
        return tonumber(mountID) or mountID
    end
    return mountID
end

local function GetMountIDFromData(data)
    if type(data) == "number" then return NormalizeMountID(data) end
    if type(data) ~= "table" then return nil end

    if data.mountID then return NormalizeMountID(data.mountID) end
    if data.id and not data.GetObjectType then return NormalizeMountID(data.id) end
    if data.data then return GetMountIDFromData(data.data) end
    if data.mountInfo then return GetMountIDFromData(data.mountInfo) end
    return nil
end

local function GetJournalRowMountID(button, elementData)
    local mountID = GetMountIDFromData(elementData) or GetMountIDFromData(button)
    if mountID then return mountID end

    if button and type(button.GetElementData) == "function" then
        return GetMountIDFromData(button:GetElementData())
    end
    return nil
end

local function IsOnCharList(mountID)
    local db = CharacterMount.db
    if not db or not mountID then return false end
    if db.additions and db.additions[mountID] then return true end
    for _, entry in ipairs(CharacterMount.GetEffectiveMountList()) do
        if entry.id == mountID and (entry.source == "racial" or entry.source == "class") then
            return true
        end
    end
    return false
end

local function ToggleCharList(mountID)
    if IsOnCharList(mountID) then
        CharacterMount.RemoveMount(mountID)
    else
        CharacterMount.AddMount(mountID)
    end
    local journalButton = CharacterMount.journalButton
    if journalButton and journalButton.UpdateCharMountText then
        journalButton.UpdateCharMountText()
    end
end

-- Transparent full-row overlay so middle-click toggles the mount without
-- selecting it. Non-middle clicks propagate through to the journal row.
local function EnsureJournalRowMiddleClick(button)
    if button.charMountMiddleClick then return button.charMountMiddleClick end

    local overlay = CreateFrame("Frame", nil, button)
    overlay:SetAllPoints(button)
    overlay:EnableMouse(true)
    overlay:SetPropagateMouseClicks(true)
    overlay:SetPropagateMouseMotion(true)
    overlay:SetScript("OnMouseUp", function(_, mouseButton)
        if mouseButton ~= "MiddleButton" then return end
        local mountID = GetJournalRowMountID(button)
        if mountID then ToggleCharList(mountID) end
    end)

    button.charMountMiddleClick = overlay
    return overlay
end

local function HideJournalRowIndicator(button)
    if button and button.charMountBadge then
        button.charMountBadge:Hide()
    end
    if button and button.charMountCheck then
        button.charMountCheck:Hide()
    end
    if button and button.charMountTick then
        button.charMountTick:Hide()
    end
    if button and button.charMountTickHitbox then
        button.charMountTickHitbox:Hide()
    end
end

-- Tick on each journal list row for mounts on the character list.
local function UpdateJournalRowIndicator(button, elementData)
    if not button then return end

    local mountID = GetJournalRowMountID(button, elementData)
    if not mountID then
        HideJournalRowIndicator(button)
        return
    end

    local overlay = EnsureJournalRowMiddleClick(button)

    local tick = button.charMountTick
    if not tick then
        -- Parented to the overlay so its middle-clicks propagate up to it.
        local hitbox = CreateFrame("Frame", nil, overlay)
        hitbox:SetSize(30, 30)
        hitbox:SetPoint("RIGHT", button, "RIGHT", -8, 0)
        hitbox:EnableMouse(true)
        hitbox:SetPropagateMouseClicks(true)
        if button.GetFrameLevel and hitbox.SetFrameLevel then
            hitbox:SetFrameLevel(button:GetFrameLevel() + 8)
        end
        hitbox:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine("Character Mount")
            GameTooltip:AddLine("This mount is in your character mount list.", 0.9, 0.85, 0.65, true)
            GameTooltip:AddLine("Middle-click the mount to remove it.", 0.9, 0.85, 0.65, true)
            GameTooltip:Show()
        end)
        hitbox:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        tick = hitbox:CreateTexture(nil, "OVERLAY", nil, 7)
        tick:SetSize(22, 22)
        tick:SetPoint("CENTER", hitbox, "CENTER", 0, 0)
        tick:SetAtlas("common-icon-checkmark")
        tick:SetVertexColor(C.success[1], C.success[2], C.success[3], 1)
        button.charMountTick = tick
        button.charMountTickHitbox = hitbox
    end

    HideJournalRowIndicator(button)
    local shown = IsOnCharList(mountID)
    tick:SetShown(shown)
    if button.charMountTickHitbox then
        button.charMountTickHitbox:SetShown(shown)
    end
end

local function GetMountJournalScrollBox()
    if not MountJournal then return nil end
    if MountJournal.ScrollBox then return MountJournal.ScrollBox end
    if MountJournal.ListScrollFrame and MountJournal.ListScrollFrame.ScrollBox then
        return MountJournal.ListScrollFrame.ScrollBox
    end
    return nil
end

local function EnumerateVisibleJournalRows(callback)
    local scrollBox = GetMountJournalScrollBox()
    if scrollBox and scrollBox.ForEachFrame then
        scrollBox:ForEachFrame(callback)
        return
    end

    if MountJournal and MountJournal.ListScrollFrame and MountJournal.ListScrollFrame.buttons then
        for _, button in ipairs(MountJournal.ListScrollFrame.buttons) do
            if button and button:IsShown() then callback(button) end
        end
    end
end

local function TryHookJournalRows()
    local scrollBox = GetMountJournalScrollBox()
    if not scrollBox or scrollBox.CharacterMountHooked then return end

    scrollBox.CharacterMountHooked = true
    if ScrollUtil and ScrollUtil.AddAcquiredFrameCallback then
        ScrollUtil.AddAcquiredFrameCallback(scrollBox, function(_, row, elementData)
            UpdateJournalRowIndicator(row, elementData)
        end, nil, true)
    elseif ScrollUtil and ScrollUtil.AddInitializedFrameCallback then
        ScrollUtil.AddInitializedFrameCallback(scrollBox, function(_, row, elementData)
            UpdateJournalRowIndicator(row, elementData)
        end, nil, true)
    end
end

function CharacterMount.RefreshJournalIndicators()
    TryHookJournalRows()
    EnumerateVisibleJournalRows(UpdateJournalRowIndicator)
end

function CharacterMount.HookMountJournalButton()
    if not MountJournal then return end
    if CharacterMount.journalButton then
        CharacterMount.RefreshJournalIndicators()
        return
    end

    local btn = LuckyUI.CreateButton(MountJournal.MountDisplay, "", 160, 22, "secondary")
    btn:SetPoint("BOTTOMLEFT", MountJournal.MountDisplay, "BOTTOMLEFT", 4, 4)

    local function GetSelectedMountID()
        return MountJournal.selectedMountID or 0
    end

    local function UpdateButton()
        local mountID = GetSelectedMountID()
        if not mountID or mountID == 0 then
            btn:SetText("No Mount Selected")
            btn:Disable()
            return
        end

        btn:Enable()
        if IsOnCharList(mountID) then
            btn:SetText("Remove from Char List")
        else
            btn:SetText("Add to Char List")
        end
    end

    btn.UpdateCharMountText = UpdateButton

    btn:SetScript("OnClick", function()
        local mountID = GetSelectedMountID()
        if not mountID or mountID == 0 then return end

        if IsOnCharList(mountID) then
            CharacterMount.RemoveMount(mountID)
        else
            CharacterMount.AddMount(mountID)
        end
        UpdateButton()
    end)

    -- Hook selection changes to keep button text in sync.
    -- MountJournal_UpdateMountDisplay is the reliable hook in TWW — it fires
    -- whenever the detail panel refreshes for a new selection regardless of
    -- how the selection was made. MountJournal_Select is kept as a fallback
    -- for older clients where it still exists as a global.
    if MountJournal_UpdateMountDisplay then
        hooksecurefunc("MountJournal_UpdateMountDisplay", function() UpdateButton() end)
    elseif MountJournal_Select then
        hooksecurefunc("MountJournal_Select", function() UpdateButton() end)
    end
    if MountJournal_InitMountButton then
        hooksecurefunc("MountJournal_InitMountButton", UpdateJournalRowIndicator)
    end
    MountJournal:HookScript("OnShow", function()
        C_Timer.After(0, function()
            UpdateButton()
            CharacterMount.RefreshJournalIndicators()
        end)
    end)

    UpdateButton()
    CharacterMount.RefreshJournalIndicators()
    CharacterMount.journalButton = btn
end

-- ---------------------------------------------------------------------------
-- Character Mount list window
-- ---------------------------------------------------------------------------

local INITIAL_ACTIVE_POOL = 20
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

    row:SetScript("OnMouseUp", function(self, mouseButton)
        if mouseButton ~= "LeftButton" then return end
        CharacterMount.ShowMountPreview(self.mountID, CharacterMount.frame)
    end)

    row:SetScript("OnEnter", function(self)
        if type(self.mountID) ~= "number" then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Click to preview this mount.", 0.9, 0.85, 0.65, true)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)

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

    -- Name label — width depends on whether the source label and spec button
    -- share the trailing space (active rows only).
    local nameLabelWidth = rowWidth - 4 - 22 - 5 - (hasSourceLabel and 110 or 0) - 30
    row.nameLabel = row:CreateFontString(nil, "OVERLAY")
    row.nameLabel:SetFont(LuckyUI.BODY_FONT, 13)
    row.nameLabel:SetSize(nameLabelWidth, ROW_HEIGHT)
    row.nameLabel:SetPoint("LEFT", row.icon, "RIGHT", 5, 0)
    row.nameLabel:SetJustifyH("LEFT")
    row.nameLabel:SetJustifyV("MIDDLE")
    row.nameLabel:SetWordWrap(false)
    row.nameLabel:SetTextColor(C.textLight[1], C.textLight[2], C.textLight[3])

    if hasSourceLabel then
        -- Per-mount options button. Shows enabled/total spec count and opens a
        -- dropdown to toggle the mount per spec and per mount type.
        row.specBtn = LuckyUI.CreateButton(row, "", 34, 22, "secondary")
        row.specBtn:SetPoint("RIGHT", row.actionBtn, "LEFT", -4, 0)
        row.specBtn:SetScript("OnClick", function()
            CharacterMount.ShowSpecMenu(row.specBtn, row.mountID)
        end)
        row.specBtn:SetScript("OnEnter", function(self)
            CharacterMount.ShowSpecButtonTooltip(self, row.mountID)
        end)
        row.specBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

        row.pill = CreateFrame("Frame", nil, row)
        row.pill:SetHeight(16)
        row.pill:SetPoint("RIGHT", row.specBtn, "LEFT", -4, 0)
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

    -- Count label (right side of header)
    frame.countLabel = frame:CreateFontString(nil, "OVERLAY")
    frame.countLabel:SetFont(LuckyUI.BODY_FONT, 11)
    frame.countLabel:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])
    frame.countLabel:SetPoint("RIGHT", frame, "TOPRIGHT", -36, -18)
    frame.countLabel:SetJustifyH("RIGHT")

    -- -----------------------------------------------------------------------
    -- Search box (filters the active mount list by name)
    -- -----------------------------------------------------------------------
    frame.searchQuery = ""
    local search = LuckyUI.CreateSearchBox(frame, {
        height      = 22,
        placeholder = "Search mounts...",
        onChange    = function(query)
            frame.searchQuery = query
            CharacterMount.RefreshUI()
        end,
    })
    search:SetPoint("TOPLEFT",  frame, "TOPLEFT",  10, -38)
    search:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -38)
    frame.search = search

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
    -- Excluded rows (pool grows dynamically in RefreshUI)
    -- -----------------------------------------------------------------------
    frame.excludedPool = {}

    -- -----------------------------------------------------------------------
    -- Divider: thin line + "Excluded" label (positioned dynamically in RefreshUI)
    -- -----------------------------------------------------------------------
    local divider = LuckyUI.CreateDivider(frame, "Excluded")
    divider:Hide()
    frame.divider = divider

    -- -----------------------------------------------------------------------
    -- Active scroll frame
    -- -----------------------------------------------------------------------
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT",     frame, "TOPLEFT",    10, -66)
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
    for i = 1, INITIAL_ACTIVE_POOL do
        frame.activePool[i] = CreateRow(content, true, 322)
    end

    CharacterMount.frame = frame
end

-- ---------------------------------------------------------------------------
-- RefreshUI — show/hide and reconfigure pool rows; never creates new frames
-- ---------------------------------------------------------------------------
function CharacterMount.RefreshUI()
    CharacterMount.RefreshJournalIndicators()

    local frame = CharacterMount.frame
    if not frame then return end

    local content    = frame.content
    local fullList   = CharacterMount.GetEffectiveMountList()
    local query      = frame.searchQuery and frame.searchQuery:lower() or ""

    -- Filter the active list by the search query (case-insensitive name match).
    local activeList = fullList
    if query ~= "" then
        activeList = {}
        for _, entry in ipairs(fullList) do
            if entry.name and entry.name:lower():find(query, 1, true) then
                activeList[#activeList + 1] = entry
            end
        end
    end

    table.sort(activeList, function(a, b) return a.name < b.name end)

    -- -----------------------------------------------------------------------
    -- 1. Active rows (pool grows dynamically if the list exceeds capacity)
    -- -----------------------------------------------------------------------
    while #frame.activePool < #activeList do
        frame.activePool[#frame.activePool + 1] = CreateRow(frame.content, true, 322)
    end

    for i = 1, #frame.activePool do
        local row   = frame.activePool[i]
        local entry = activeList[i]
        if entry then
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", content, "TOPLEFT",
                         0, -6 - (i - 1) * (ROW_HEIGHT + ROW_GAP))
            row.mountID    = entry.id
            row.isExcluded = false

            -- Dim mounts that are turned off for the current spec.
            local activeForSpec = CharacterMount.IsMountEnabledForCurrentSpec(entry.id)
            row.icon:SetTexture(entry.icon)
            row.icon:SetDesaturated(not activeForSpec)
            row.nameLabel:SetText(entry.name)
            if activeForSpec then
                row.nameLabel:SetTextColor(C.textLight[1], C.textLight[2], C.textLight[3])
            else
                row.nameLabel:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])
            end

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

            if row.specBtn then
                local enabled, total = CharacterMount.GetMountSpecCounts(entry.id)
                -- The count is spec-only; mount type choices never change it.
                row.specBtn:SetText(total > 1 and (enabled .. "/" .. total) or "...")
                row.specBtn:SetShown(total > 1 or type(entry.id) == "number")
            end

            row.actionBtn:SetText("\195\151")
            row:Show()
        else
            row:Hide()
        end
    end

    -- Resize scroll content to fit rows
    content:SetHeight(math.max(200, #activeList * (ROW_HEIGHT + ROW_GAP) + 14))

    -- Empty hint — distinguishes "no mounts at all" from "no search matches".
    local isEmpty = #activeList == 0
    frame.emptyHint:SetShown(isEmpty)
    if isEmpty then
        if query ~= "" then
            frame.emptyHint:SetText("No mounts match \"" .. frame.searchQuery .. "\".")
        else
            frame.emptyHint:SetText("No mounts yet.\nUse /cmount add <name> or add mounts from the mount journal.")
        end
    end
    frame.journalBtn:SetShown(isEmpty and query == "")

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

    -- Update header count label (shows "X of Y" while a search filter is active)
    local exclStr = #excludedList > 0 and (" • " .. #excludedList .. " excluded") or ""
    local mountsStr = (query ~= "")
        and (#activeList .. " of " .. #fullList .. " mounts")
        or  (#fullList .. " mounts")
    frame.countLabel:SetText(mountsStr .. exclStr)

    -- Resize scroll frame: expand to fill the frame when no excluded section is shown.
    local exclCount = #excludedList
    local exclHeight = exclCount * (ROW_HEIGHT + ROW_GAP)
    local scrollBottomY = exclCount > 0 and (48 + exclHeight + 22) or 48
    frame.scrollFrame:ClearAllPoints()
    frame.scrollFrame:SetPoint("TOPLEFT",     frame, "TOPLEFT",    10, -66)
    frame.scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, scrollBottomY)

    -- Grow excluded pool if needed
    while #frame.excludedPool < exclCount do
        frame.excludedPool[#frame.excludedPool + 1] = CreateRow(frame, false, 330)
    end

    if exclCount > 0 then
        for i = 1, #frame.excludedPool do
            local row  = frame.excludedPool[i]
            local item = excludedList[i]
            if item then
                local fromBottom = 48 + (exclCount - i) * (ROW_HEIGHT + ROW_GAP)
                row:ClearAllPoints()
                row:SetPoint("BOTTOMLEFT",  frame, "BOTTOMLEFT",  10, fromBottom)
                row:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, fromBottom)
                row:SetHeight(ROW_HEIGHT)
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
        frame.divider:ClearAllPoints()
        frame.divider:SetPoint("BOTTOMLEFT",  frame, "BOTTOMLEFT",  10, 48 + exclHeight + 2)
        frame.divider:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 48 + exclHeight + 2)
        frame.divider:Show()
    else
        for i = 1, #frame.excludedPool do
            frame.excludedPool[i]:Hide()
        end
        frame.divider:Hide()
    end
end

-- ---------------------------------------------------------------------------
-- Mount model preview
-- ---------------------------------------------------------------------------

local DEFAULT_CAM_SCALE = 1.4
local MIN_CAM_SCALE = 0.7
local MAX_CAM_SCALE = 4

-- Load the live 3D mount model into a PlayerModel frame. Returns false when
-- the mount has no usable display (spell-form entries, missing data).
--
-- Model frames render blank when SetDisplayInfo runs before the frame is
-- shown or before the model's data has loaded. We work around this by only
-- loading after the frame is visible and re-applying the display info on the
-- next render tick via a one-shot OnUpdate.
local function LoadMountModel(model, mountID)
    if type(mountID) ~= "number" then return false end

    -- First return of GetMountInfoExtraByID is the creatureDisplayID.
    local displayID = C_MountJournal.GetMountInfoExtraByID(mountID)
    if not displayID or displayID == 0 then return false end

    local function apply()
        model:SetDisplayInfo(displayID)
        model:SetPortraitZoom(0)
        model:SetPosition(0, 0, 0)
        model:SetFacing(0.6)
        model.camScale = DEFAULT_CAM_SCALE
        model:SetCamDistanceScale(DEFAULT_CAM_SCALE)
    end

    model:ClearModel()
    apply()

    model:SetScript("OnUpdate", function(self)
        self:SetScript("OnUpdate", nil)
        apply()
    end)
    return true
end

-- Standalone preview window, opened by clicking a mount row in the list or
-- setup window. Pinned beside the window it was opened from: it is parented
-- to that window so it moves and hides with it, and cannot be dragged away.
function CharacterMount.ShowMountPreview(mountID, anchorFrame)
    -- Spell-form entries ("spell:<id>") have no mount model to show.
    if type(mountID) ~= "number" then return end

    local name = C_MountJournal.GetMountInfoByID(mountID)
    if not name then return end

    local frame = CharacterMount.previewFrame
    if not frame then
        frame = LuckyUI.CreatePanel("CharacterMount_MountPreview", UIParent, 260, 320)
        frame:Hide()
        tinsert(UISpecialFrames, "CharacterMount_MountPreview")
        LuckyUI.CreateHeader(frame, "Preview")

        frame:SetMovable(false)
        frame:RegisterForDrag()
        frame:SetScript("OnDragStart", nil)
        frame:SetScript("OnDragStop", nil)

        -- Fires when the parent window closes; without this the preview would
        -- pop back up the next time that window is shown.
        frame:SetScript("OnHide", function(self) self:Hide() end)

        local nameLabel = frame:CreateFontString(nil, "OVERLAY")
        nameLabel:SetFont(LuckyUI.BODY_FONT, 13)
        nameLabel:SetTextColor(C.textLight[1], C.textLight[2], C.textLight[3])
        nameLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -38)
        nameLabel:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -38)
        nameLabel:SetJustifyH("CENTER")
        nameLabel:SetWordWrap(true)
        frame.nameLabel = nameLabel

        local model = CreateFrame("PlayerModel", nil, frame)
        model:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -60)
        model:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 8)
        frame.model = model

        -- Left-click drag spins the model.
        model:EnableMouse(true)
        model:SetScript("OnMouseDown", function(self, mouseButton)
            if mouseButton ~= "LeftButton" then return end
            self.dragStartX = GetCursorPosition()
            self:SetScript("OnUpdate", function(s)
                -- The mouse can be released off the model, where OnMouseUp
                -- never reaches us, so stop on the button state too.
                if not IsMouseButtonDown("LeftButton") then
                    s:SetScript("OnUpdate", nil)
                    return
                end
                local x = GetCursorPosition()
                s:SetFacing(s:GetFacing() + (x - s.dragStartX) * 0.01)
                s.dragStartX = x
            end)
        end)
        model:SetScript("OnMouseUp", function(self)
            self:SetScript("OnUpdate", nil)
        end)

        -- Scroll to zoom.
        model:EnableMouseWheel(true)
        model:SetScript("OnMouseWheel", function(self, delta)
            local scale = (self.camScale or DEFAULT_CAM_SCALE) - delta * 0.2
            scale = math.max(MIN_CAM_SCALE, math.min(MAX_CAM_SCALE, scale))
            self.camScale = scale
            self:SetCamDistanceScale(scale)
        end)

        CharacterMount.previewFrame = frame
    end

    frame:SetParent(anchorFrame or UIParent)
    frame:ClearAllPoints()
    if anchorFrame then
        frame:SetPoint("TOPLEFT", anchorFrame, "TOPRIGHT", 10, 0)
    else
        frame:SetFrameStrata("DIALOG")
        frame:SetPoint("CENTER")
    end

    frame.nameLabel:SetText(name)
    frame:Show()
    if not LoadMountModel(frame.model, mountID) then
        frame:Hide()
    end
end

-- ---------------------------------------------------------------------------
-- New Mount Dialog
-- ---------------------------------------------------------------------------

-- Honours the CharacterMountDB.showMountPreview toggle (default on).
local function RefreshMountPreview(dialog, mountID)
    local preview = dialog.preview
    if not preview then return end

    if CharacterMountDB and CharacterMountDB.showMountPreview == false then
        preview:Hide()
        return
    end

    preview:SetShown(LoadMountModel(dialog.previewModel, mountID))
end

function CharacterMount.ShowNewMountDialog(mountID)
    local name, _, icon = C_MountJournal.GetMountInfoByID(mountID)
    if not name then return end

    if not CharacterMount.newMountDialog then
        local frame = LuckyUI.CreatePanel("CharacterMount_NewMountDialog", UIParent, 340, 180)
        frame:SetPoint("CENTER", 0, 150)
        frame:SetFrameStrata("DIALOG")
        LuckyUI.CreateHeader(frame, "New Mount Unlocked!")
        
        local iconTex = frame:CreateTexture(nil, "ARTWORK")
        iconTex:SetSize(40, 40)
        iconTex:SetPoint("TOPLEFT", 16, -45)
        frame.iconTex = iconTex
        
        local label = frame:CreateFontString(nil, "OVERLAY")
        label:SetFont(LuckyUI.BODY_FONT, 14)
        label:SetPoint("TOPLEFT", iconTex, "TOPRIGHT", 10, 0)
        label:SetPoint("RIGHT", frame, "RIGHT", -16, 0)
        label:SetJustifyH("LEFT")
        label:SetWordWrap(true)
        frame.label = label
        
        local subLabel = frame:CreateFontString(nil, "OVERLAY")
        subLabel:SetFont(LuckyUI.BODY_FONT, 11)
        subLabel:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -8)
        subLabel:SetPoint("RIGHT", frame, "RIGHT", -16, 0)
        subLabel:SetJustifyH("LEFT")
        subLabel:SetTextColor(LuckyUI.C.textMuted[1], LuckyUI.C.textMuted[2], LuckyUI.C.textMuted[3])
        subLabel:SetText("Would you like to add it to your mount list?")
        
        local hintLabel = frame:CreateFontString(nil, "OVERLAY")
        hintLabel:SetFont(LuckyUI.BODY_FONT, 10)
        hintLabel:SetPoint("BOTTOM", frame, "BOTTOM", 0, 16)
        hintLabel:SetTextColor(0.5, 0.5, 0.5)
        hintLabel:SetText("(This prompt can be disabled in settings)")
        
        local btnCurrent = LuckyUI.CreateButton(frame, "Current Char", 100, 26, "primary")
        btnCurrent:SetPoint("BOTTOM", frame, "BOTTOM", 0, 40)
        frame.btnCurrent = btnCurrent
        
        local btnClose = LuckyUI.CreateButton(frame, "No Thanks", 90, 26, "secondary")
        btnClose:SetPoint("RIGHT", btnCurrent, "LEFT", -8, 0)
        frame.btnClose = btnClose
        
        local btnAll = LuckyUI.CreateButton(frame, "All Chars", 100, 26, "primary")
        btnAll:SetPoint("LEFT", btnCurrent, "RIGHT", 8, 0)
        frame.btnAll = btnAll

        -- 3D model preview panel, anchored to the right of the dialog.
        local preview = LuckyUI.CreatePanel("CharacterMount_NewMountPreview", frame, 220, 220)
        preview:SetPoint("LEFT", frame, "RIGHT", 10, 0)
        -- Keep the preview pinned to the dialog rather than independently draggable.
        preview:SetMovable(false)
        preview:EnableMouse(false)
        preview:RegisterForDrag()
        preview:SetScript("OnDragStart", nil)
        preview:SetScript("OnDragStop", nil)
        preview:Hide()

        local previewTitle = preview:CreateFontString(nil, "OVERLAY")
        previewTitle:SetFont(LuckyUI.TITLE_FONT, 13)
        previewTitle:SetTextColor(LuckyUI.C.goldPrimary[1], LuckyUI.C.goldPrimary[2], LuckyUI.C.goldPrimary[3])
        previewTitle:SetPoint("TOP", preview, "TOP", 0, -8)
        previewTitle:SetText("Preview")

        local model = CreateFrame("PlayerModel", nil, preview)
        model:SetPoint("TOPLEFT", preview, "TOPLEFT", 6, -28)
        model:SetPoint("BOTTOMRIGHT", preview, "BOTTOMRIGHT", -6, 6)

        frame.preview      = preview
        frame.previewModel = model

        CharacterMount.newMountDialog = frame
    end
    
    local dialog = CharacterMount.newMountDialog
    dialog.iconTex:SetTexture(icon)
    dialog.label:SetText(name)
    
    dialog.btnCurrent:SetScript("OnClick", function()
        CharacterMount.AddMount(mountID)
        dialog:Hide()
    end)
    
    dialog.btnAll:SetScript("OnClick", function()
        CharacterMount.AddMountToAllCharacters(mountID)
        dialog:Hide()
    end)
    
    dialog.btnClose:SetScript("OnClick", function()
        dialog:Hide()
    end)
    
    dialog:Show()
    -- Load the model after the dialog is shown — see RefreshMountPreview.
    RefreshMountPreview(dialog, mountID)
end
