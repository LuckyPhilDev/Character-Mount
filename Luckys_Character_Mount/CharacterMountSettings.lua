-- Character Mount: Settings panel (Interface Options integration)
-- Registers a canvas category in the modern Settings API so players can
-- access Character Mount options via ESC > Options > AddOns.

CharacterMount = CharacterMount or {}

local C  = LuckyUI.C

local ROW_HEIGHT = 26
local ROW_GAP    = 2
local INITIAL_POOL = 20

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

    local panel = LuckySettings:NewPanel("Lucky's Character Mount")
    CharacterMount.settingsCategory = panel.category

    -- Options
    panel:Toggle({
        label    = "Debug mode",
        desc     = "Print detailed mount selection diagnostics to chat.",
        checked  = CharacterMountDB.debugMode or false,
        gap      = 16,
        onToggle = function(checked) CharacterMountDB.debugMode = checked end,
    })

    local minimapState = CharacterMountDB.minimap or {}
    panel:Toggle({
        label    = "Minimap button",
        desc     = "Show the Character Mount button on the minimap.",
        checked  = not minimapState.hide,
        onToggle = function(checked)
            if CharacterMount.minimapButton then
                CharacterMount.minimapButton:SetShown_Persisted(checked)
            end
        end,
    })

    panel:Toggle({
        label    = "Allow dismount while flying",
        desc     = "When enabled, pressing the mount macro mid-air will dismount you.",
        checked  = CharacterMountDB.allowFlyingDismount or false,
        onToggle = function(checked)
            CharacterMountDB.allowFlyingDismount = checked
            CharacterMount.PreRoll()
        end,
    })

    ---------------------------------------------------------------------------
    -- Mount list (custom section below the builder controls)
    ---------------------------------------------------------------------------
    panel:Section("Mount List")

    local content = panel.content
    local anchor  = panel.lastAnchor

    -- Open Mount Journal button (next to heading)
    local journalBtn = LuckyUI.CreateButton(content, "Open Mount Journal", 140, 22, "secondary")
    journalBtn:SetPoint("LEFT", anchor, "RIGHT", 12, 0)
    journalBtn:SetScript("OnClick", function()
        HideUIPanel(SettingsPanel)
        C_Timer.After(0, function() ToggleCollectionsJournal(1) end)
    end)

    -- Mount count
    local mountCount = content:CreateFontString(nil, "OVERLAY")
    mountCount:SetFont(LuckyUI.BODY_FONT, 11)
    mountCount:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])
    mountCount:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -4)

    -- Scroll frame for mount list
    local listContainer = CreateFrame("Frame", nil, content)
    listContainer:SetPoint("TOPLEFT", mountCount, "BOTTOMLEFT", 0, -8)
    listContainer:SetPoint("RIGHT", content, "RIGHT", -16, 0)
    listContainer:SetHeight(INITIAL_POOL * (ROW_HEIGHT + ROW_GAP))

    -- Pre-allocate mount rows
    local rowPool = {}
    local RefreshMountList  -- forward declaration for button callbacks

    for i = 1, INITIAL_POOL do
        local row = CreateSettingsRow(listContainer, i)
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

        -- Grow pool if the list exceeds current capacity
        while #rowPool < #mountList do
            local idx = #rowPool + 1
            local row = CreateSettingsRow(listContainer, idx)
            row.removeBtn:SetScript("OnClick", function()
                CharacterMount.RemoveMount(row.mountID)
                RefreshMountList()
            end)
            rowPool[idx] = row
        end

        for i = 1, #rowPool do
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

        listContainer:SetHeight(math.max(100, #mountList * (ROW_HEIGHT + ROW_GAP)))
    end

    panel.panel:HookScript("OnShow", function()
        RefreshMountList()
    end)
end

-- ---------------------------------------------------------------------------
-- Open the settings panel programmatically
-- ---------------------------------------------------------------------------
function CharacterMount.OpenSettings()
    LuckySettings:Open(CharacterMount.settingsCategory)
end
