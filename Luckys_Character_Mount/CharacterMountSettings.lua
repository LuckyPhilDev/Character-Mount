-- Character Mount: Settings panel (Interface Options integration)
-- Registers a canvas category in the modern Settings API so players can
-- access Character Mount options via ESC > Options > AddOns.

CharacterMount = CharacterMount or {}

local C  = LuckyUI.C

local ROW_HEIGHT = 26
local ROW_GAP    = 2
local POOL_SIZE  = 50

-- ---------------------------------------------------------------------------
-- Create one mount-list row inside the settings scroll content
-- ---------------------------------------------------------------------------
local function CreateSettingsRow(parent, index)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -(index - 1) * (ROW_HEIGHT + ROW_GAP))
    row:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
    row:Hide()

    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(C.highlight[1], C.highlight[2], C.highlight[3], C.highlight[4])

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(20, 20)
    row.icon:SetPoint("LEFT", 4, 0)

    -- Remove button
    row.removeBtn = LuckyUI.CreateButton(row, "\195\151", 24, 22, "secondary")
    row.removeBtn:SetPoint("RIGHT", row, "RIGHT", -4, 0)

    row.nameLabel = row:CreateFontString(nil, "OVERLAY")
    row.nameLabel:SetFont(LuckyUI.BODY_FONT, 12)
    row.nameLabel:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.nameLabel:SetJustifyH("LEFT")
    row.nameLabel:SetTextColor(C.textLight[1], C.textLight[2], C.textLight[3])

    -- Source pill
    row.pill = CreateFrame("Frame", nil, row)
    row.pill:SetHeight(14)
    row.pill:SetPoint("RIGHT", row.removeBtn, "LEFT", -4, 0)
    row.pillBg = row.pill:CreateTexture(nil, "BACKGROUND")
    row.pillBg:SetAllPoints()
    row.pillBg:SetColorTexture(1, 1, 1, 0.15)

    row.sourceLabel = row.pill:CreateFontString(nil, "OVERLAY")
    row.sourceLabel:SetFont(LuckyUI.BODY_FONT, 10)
    row.sourceLabel:SetPoint("CENTER", 0, 0)
    row.sourceLabel:SetJustifyH("CENTER")

    return row
end

-- ---------------------------------------------------------------------------
-- InitSettings — build and register the settings canvas
-- ---------------------------------------------------------------------------
function CharacterMount.InitSettings()
    local db = CharacterMount.db
    if not db then return end

    -- Canvas frame for Interface Options
    local canvas = CreateFrame("Frame")
    canvas:SetSize(600, 400)
    canvas:Hide()

    -- Title
    local title = canvas:CreateFontString(nil, "OVERLAY")
    title:SetFont(LuckyUI.TITLE_FONT, 16)
    title:SetTextColor(C.goldPrimary[1], C.goldPrimary[2], C.goldPrimary[3])
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Lucky's Character Mount")

    -- Description
    local desc = canvas:CreateFontString(nil, "OVERLAY")
    desc:SetFont(LuckyUI.BODY_FONT, 12)
    desc:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    desc:SetText("Configure settings and view your current mount list.")

    -- Options heading
    local optionsHeading = canvas:CreateFontString(nil, "OVERLAY")
    optionsHeading:SetFont(LuckyUI.TITLE_FONT, 14)
    optionsHeading:SetTextColor(C.goldAccent[1], C.goldAccent[2], C.goldAccent[3])
    optionsHeading:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -20)
    optionsHeading:SetText("Options")

    -- Debug mode checkbox (account-wide, stored at CharacterMountDB root)
    local debugCheck = LuckyUI.CreateCheckbox(canvas, 16)
    debugCheck:SetPoint("TOPLEFT", optionsHeading, "BOTTOMLEFT", 0, -10)
    debugCheck:SetChecked(CharacterMountDB.debugMode or false)
    debugCheck:SetScript("OnClick", function(self)
        CharacterMountDB.debugMode = self:GetChecked()
    end)

    local debugLabel = canvas:CreateFontString(nil, "OVERLAY")
    debugLabel:SetFont(LuckyUI.BODY_FONT, 13)
    debugLabel:SetTextColor(C.textLight[1], C.textLight[2], C.textLight[3])
    debugLabel:SetPoint("LEFT", debugCheck, "RIGHT", 8, 0)
    debugLabel:SetText("Debug mode")

    local debugHint = canvas:CreateFontString(nil, "OVERLAY")
    debugHint:SetFont(LuckyUI.BODY_FONT, 11)
    debugHint:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])
    debugHint:SetPoint("TOPLEFT", debugCheck, "BOTTOMLEFT", 0, -2)
    debugHint:SetText("Print detailed mount selection diagnostics to chat.")

    -- Mount list heading
    local mountHeading = canvas:CreateFontString(nil, "OVERLAY")
    mountHeading:SetFont(LuckyUI.TITLE_FONT, 14)
    mountHeading:SetTextColor(C.goldAccent[1], C.goldAccent[2], C.goldAccent[3])
    mountHeading:SetPoint("TOPLEFT", debugHint, "BOTTOMLEFT", 0, -20)
    mountHeading:SetText("Mount List")

    -- Open Mount Journal button (next to heading)
    local journalBtn = LuckyUI.CreateButton(canvas, "Open Mount Journal", 140, 22, "secondary")
    journalBtn:SetPoint("LEFT", mountHeading, "RIGHT", 12, 0)
    journalBtn:SetScript("OnClick", function()
        HideUIPanel(SettingsPanel)
        C_Timer.After(0, function() ToggleCollectionsJournal(1) end)
    end)

    -- Mount count
    local mountCount = canvas:CreateFontString(nil, "OVERLAY")
    mountCount:SetFont(LuckyUI.BODY_FONT, 11)
    mountCount:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])
    mountCount:SetPoint("TOPLEFT", mountHeading, "BOTTOMLEFT", 0, -4)

    -- Scroll frame for mount list
    local scrollFrame = CreateFrame("ScrollFrame", nil, canvas, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", mountCount, "BOTTOMLEFT", 0, -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", canvas, "BOTTOMRIGHT", -30, 16)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetWidth(540)
    content:SetHeight(1)
    scrollFrame:SetScrollChild(content)

    -- Pre-allocate mount rows
    local rowPool = {}
    local RefreshMountList  -- forward declaration for button callbacks

    for i = 1, POOL_SIZE do
        local row = CreateSettingsRow(content, i)
        row.removeBtn:SetScript("OnClick", function()
            CharacterMount.RemoveMount(row.mountID)
            RefreshMountList()
        end)
        rowPool[i] = row
    end

    -- Refresh the mount list display
    RefreshMountList = function()
        local mountList = CharacterMount.GetEffectiveMountList()
        table.sort(mountList, function(a, b) return (a.name or "") < (b.name or "") end)

        mountCount:SetText(#mountList .. " mounts in your character list")

        for i = 1, POOL_SIZE do
            local row   = rowPool[i]
            local entry = mountList[i]
            if entry then
                row.mountID = entry.id
                row.icon:SetTexture(entry.icon)
                row.nameLabel:SetText(entry.name)

                local sl  = CharacterMount.SourceLabel[entry.source] or ""
                local rgb = CharacterMount.SourcePillRGB[entry.source]
                row.sourceLabel:SetText(sl)
                if rgb then
                    row.sourceLabel:SetTextColor(rgb[1], rgb[2], rgb[3])
                    row.pillBg:SetColorTexture(rgb[1], rgb[2], rgb[3], 0.15)
                end
                local tw = row.sourceLabel:GetStringWidth()
                row.pill:SetWidth(math.max(tw + 10, 24))
                row.pill:Show()
                row:Show()
            else
                row:Hide()
            end
        end

        content:SetHeight(math.max(100, #mountList * (ROW_HEIGHT + ROW_GAP)))
    end

    canvas:SetScript("OnShow", function()
        debugCheck:SetChecked(CharacterMountDB.debugMode or false)
        RefreshMountList()
    end)

    -- Register with the modern Settings API
    local category = Settings.RegisterCanvasLayoutCategory(canvas, "Lucky's Character Mount")
    Settings.RegisterAddOnCategory(category)
    CharacterMount.settingsCategory = category
end

-- ---------------------------------------------------------------------------
-- Open the settings panel programmatically
-- ---------------------------------------------------------------------------
function CharacterMount.OpenSettings()
    if CharacterMount.settingsCategory then
        Settings.OpenToCategory(CharacterMount.settingsCategory:GetID())
    end
end
