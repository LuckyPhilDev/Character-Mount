-- Character Mount: Settings panel (Interface Options integration)
-- Registers a canvas category in the modern Settings API so players can
-- access Character Mount options via ESC > Options > AddOns.

CharacterMount = CharacterMount or {}

local S = CharacterMount.Strings

local R = LuckySettings.Rich.Theme
local R_FONT = LuckySettings.Rich.Font

local ROW_HEIGHT = 26
local ROW_GAP    = 2
local INITIAL_POOL = 20

local function HolidayNote(titles)
    return S.settings.holidayNote:format(table.concat(titles, ", "))
end

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
    hl:SetColorTexture(R.accent[1], R.accent[2], R.accent[3], 0.06)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(20, 20)
    row.icon:SetPoint("LEFT", 4, 0)

    -- Remove button
    row.removeBtn = LuckyUI.CreateButton(row, "\195\151", 24, 22, "secondary")
    row.removeBtn:SetPoint("RIGHT", row, "RIGHT", -4, 0)

    -- Per-spec availability button (opens the shared spec dropdown)
    row.specBtn = LuckyUI.CreateButton(row, "", 34, 22, "secondary")
    row.specBtn:SetPoint("RIGHT", row.removeBtn, "LEFT", -4, 0)
    row.specBtn:SetScript("OnClick", function()
        CharacterMount.ShowSpecMenu(row.specBtn, row.mountID)
    end)
    row.specBtn:SetScript("OnEnter", function(self)
        CharacterMount.ShowSpecButtonTooltip(self, row.mountID)
    end)
    row.specBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    row.nameLabel = row:CreateFontString(nil, "OVERLAY")
    row.nameLabel:SetFont(R_FONT, 12, "")
    row.nameLabel:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.nameLabel:SetJustifyH("LEFT")
    row.nameLabel:SetTextColor(R.text[1], R.text[2], R.text[3])

    -- Source pill
    row.pill = CreateFrame("Frame", nil, row)
    row.pill:SetHeight(14)
    row.pill:SetPoint("RIGHT", row.specBtn, "LEFT", -4, 0)
    row.pillBg = row.pill:CreateTexture(nil, "BACKGROUND")
    row.pillBg:SetAllPoints()
    row.pillBg:SetColorTexture(1, 1, 1, 0.15)

    row.sourceLabel = row.pill:CreateFontString(nil, "OVERLAY")
    row.sourceLabel:SetFont(R_FONT, 10, "")
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

    local panel = LuckySettings:NewRichPanel(S.addon.title, {
        addonFolder   = "Luckys_Character_Mount",
        minVersion    = CharacterMount.WHATS_NEW_MIN_VERSION,
        devMode       = {
            label    = S.settings.debugMode,
            desc     = S.settings.debugModeDesc,
            checked  = function() return CharacterMountDB.debugMode end,
            onToggle = function(checked) CharacterMountDB.debugMode = checked end,
        },
        minimapButton = {
            label    = S.settings.minimapButton,
            desc     = S.settings.minimapButtonDesc,
            checked  = function() return not (CharacterMountDB.minimap or {}).hide end,
            onToggle = function(checked)
                if CharacterMount.minimapButton then
                    CharacterMount.minimapButton:SetShown_Persisted(checked)
                end
            end,
        },
    })
    CharacterMount.settingsCategory = panel.category

    -- Debug mode and the minimap button live in the title bar now, so this
    -- group exists to host the What's New list.
    panel:Group(S.settings.whatsNew)

    local preferences = panel:Group(S.settings.preferences)

    preferences:Section(S.settings.newMountsSection)
    preferences:Toggle({
        label    = S.settings.promptNewMount,
        desc     = S.settings.promptNewMountDesc,
        checked  = CharacterMountDB.autoPromptNewMount ~= false,
        onToggle = function(checked)
            CharacterMountDB.autoPromptNewMount = checked
        end,
    })

    preferences:Toggle({
        label    = S.settings.showPreview,
        desc     = S.settings.showPreviewDesc,
        parent   = S.settings.promptNewMount,
        checked  = CharacterMountDB.showMountPreview ~= false,
        onToggle = function(checked)
            CharacterMountDB.showMountPreview = checked
        end,
    })

    preferences:Section(S.settings.holidaysSection)
    preferences:Toggle({
        label    = S.settings.holidayAssign,
        desc     = S.settings.holidayAssignDesc,
        note     = HolidayNote(CharacterMount.MountData.HOLIDAYS),
        checked  = CharacterMountDB.holidayAssignEnabled or false,
        onToggle = function(checked)
            CharacterMountDB.holidayAssignEnabled = checked
        end,
    })

    preferences:Toggle({
        label    = S.settings.microHolidays,
        desc     = S.settings.microHolidaysDesc,
        note     = HolidayNote(CharacterMount.MountData.MICRO_HOLIDAYS),
        parent   = S.settings.holidayAssign,
        since    = "1.9.0",
        checked  = CharacterMountDB.microHolidaysEnabled or false,
        onToggle = function(checked)
            CharacterMountDB.microHolidaysEnabled = checked
        end,
    })

    preferences:Slider({
        label    = S.settings.holidayChance,
        desc     = S.settings.holidayChanceDesc,
        parent   = S.settings.holidayAssign,
        since    = "1.9.0",
        min      = 10,
        max      = 100,
        step     = 5,
        suffix   = "%",
        value    = CharacterMountDB.holidayWeightPercent or 50,
        onChanged = function(val)
            CharacterMountDB.holidayWeightPercent = val
        end,
    })

    local macros = panel:Group(S.settings.macros)

    macros:Section(S.settings.defaultMacro)
    macros:Button({
        label   = S.settings.getDefaultMacro,
        desc    = S.settings.getDefaultMacroDesc,
        tooltip = S.settings.getDefaultMacroTip,
        since   = "1.9.0",
        width   = 160,
        onClick = function()
            CharacterMount.CreateMacro()
            HideUIPanel(SettingsPanel)
        end,
    })

    macros:Section(S.settings.groundMacro)
    macros:Button({
        label   = S.settings.getGroundMacro,
        desc    = S.settings.getGroundMacroDesc,
        tooltip = S.settings.getGroundMacroTip,
        width   = 160,
        onClick = function()
            CharacterMount.CreateGroundMacro()
            HideUIPanel(SettingsPanel)
        end,
    })

    macros:Section(S.settings.macroBehaviour)
    macros:Toggle({
        label    = S.settings.allowDismount,
        desc     = S.settings.allowDismountDesc,
        checked  = CharacterMountDB.allowFlyingDismount or false,
        onToggle = function(checked)
            CharacterMountDB.allowFlyingDismount = checked
            CharacterMount.PreRoll()
        end,
    })

    macros:Toggle({
        label    = S.settings.quietWarnings,
        desc     = S.settings.quietWarningsDesc,
        checked  = CharacterMountDB.quietMountWarnings or false,
        onToggle = function(checked)
            CharacterMountDB.quietMountWarnings = checked
        end,
    })

    local mountListGroup = panel:Group(S.settings.mountListGroup, {
        showAbout = false,
    })
    mountListGroup:Button({
        label   = S.settings.openJournal,
        desc    = S.settings.openJournalDesc,
        width   = 140,
        onClick = function()
            HideUIPanel(SettingsPanel)
            C_Timer.After(0, function() ToggleCollectionsJournal(1) end)
        end,
    })

    local content = mountListGroup:Fill()

    -- Mount count
    local mountCount = content:CreateFontString(nil, "OVERLAY")
    mountCount:SetFont(R_FONT, 11, "")
    mountCount:SetTextColor(R.textDim[1], R.textDim[2], R.textDim[3])
    mountCount:SetPoint("TOPLEFT", 4, -4)

    -- Scroll content for the mount list
    local listContainer = CreateFrame("Frame", nil, content)
    listContainer:SetPoint("TOPLEFT", content, "TOPLEFT", 4, -30)
    listContainer:SetPoint("TOPRIGHT", content, "TOPRIGHT", -4, -30)

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

        mountCount:SetText(S.mountList.countLabel:format(#mountList))

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

                local activeForSpec = CharacterMount.IsMountEnabledForCurrentSpec(entry.id)
                row.icon:SetTexture(entry.icon)
                row.icon:SetDesaturated(not activeForSpec)
                row.nameLabel:SetText(entry.name)
                if activeForSpec then
                    row.nameLabel:SetTextColor(R.text[1], R.text[2], R.text[3])
                else
                    row.nameLabel:SetTextColor(R.textDim[1], R.textDim[2], R.textDim[3])
                end

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

                local enabled, total = CharacterMount.GetMountSpecCounts(entry.id)
                -- The count is spec-only; mount type choices never change it.
                row.specBtn:SetText(total > 1 and (enabled .. "/" .. total) or "...")
                row.specBtn:SetShown(total > 1 or type(entry.id) == "number")

                row:Show()
            else
                row:Hide()
            end
        end

        local listHeight = math.max(100, #mountList * (ROW_HEIGHT + ROW_GAP))
        listContainer:SetHeight(listHeight)
        content:SetHeight(listHeight + 30)
    end

    panel:OnOpen(function()
        macros.byLabel[S.settings.quietWarnings].checkbox:SetChecked(CharacterMountDB.quietMountWarnings or false)
        macros.byLabel[S.settings.allowDismount].checkbox:SetChecked(CharacterMountDB.allowFlyingDismount or false)
        preferences.byLabel[S.settings.promptNewMount].checkbox:SetChecked(CharacterMountDB.autoPromptNewMount ~= false)
        preferences.byLabel[S.settings.showPreview].checkbox:SetChecked(CharacterMountDB.showMountPreview ~= false)
        preferences.byLabel[S.settings.holidayAssign].checkbox:SetChecked(CharacterMountDB.holidayAssignEnabled or false)
        preferences.byLabel[S.settings.microHolidays].checkbox:SetChecked(CharacterMountDB.microHolidaysEnabled or false)
        preferences.byLabel[S.settings.holidayChance].slider:SetValue(CharacterMountDB.holidayWeightPercent or 50)
        RefreshMountList()
    end)

    panel:Finalize()
    LuckyPromo:AddToRichGroup(panel.whatsNewGroup, "Luckys_Character_Mount")
end

-- ---------------------------------------------------------------------------
-- Open the settings panel programmatically
-- ---------------------------------------------------------------------------
function CharacterMount.OpenSettings()
    LuckySettings:Open(CharacterMount.settingsCategory)
end
