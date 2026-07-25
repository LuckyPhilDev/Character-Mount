-- Character Mount: Settings panel (Interface Options integration)
-- Registers a canvas category in the modern Settings API so players can
-- access Character Mount options via ESC > Options > AddOns.

CharacterMount = CharacterMount or {}

local R = LuckySettings.Rich.Theme
local R_FONT = LuckySettings.Rich.Font

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
    hl:SetColorTexture(R.accent[1], R.accent[2], R.accent[3], 0.06)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(20, 20)
    row.icon:SetPoint("LEFT", 4, 0)

    -- Remove button
    row.removeBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.removeBtn:SetSize(24, 22)
    row.removeBtn:SetText("\195\151")
    row.removeBtn:SetPoint("RIGHT", row, "RIGHT", -4, 0)

    -- Per-spec availability button (opens the shared spec dropdown)
    row.specBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.specBtn:SetSize(34, 22)
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

    local panel = LuckySettings:NewRichPanel("Lucky's Character Mount", {
        showAbout = false,
    })
    CharacterMount.settingsCategory = panel.category

    local general = panel:Group("General")
    general:Toggle({
        label    = "Debug mode",
        desc     = "Print detailed mount selection diagnostics to chat.",
        checked  = CharacterMountDB.debugMode or false,
        onToggle = function(checked) CharacterMountDB.debugMode = checked end,
    })

    local minimapState = CharacterMountDB.minimap or {}
    general:Toggle({
        label    = "Minimap button",
        desc     = "Show the Character Mount button on the minimap.",
        checked  = not minimapState.hide,
        onToggle = function(checked)
            if CharacterMount.minimapButton then
                CharacterMount.minimapButton:SetShown_Persisted(checked)
            end
        end,
    })

    general:Toggle({
        label    = "Silence mount warnings",
        desc     = "Stop chat messages when you cannot mount, such as in combat or indoors.",
        checked  = CharacterMountDB.quietMountWarnings or false,
        onToggle = function(checked)
            CharacterMountDB.quietMountWarnings = checked
        end,
    })

    local mountBehavior = panel:Group("Mount behavior")
    mountBehavior:Toggle({
        label    = "Allow dismount while flying",
        desc     = "When enabled, pressing the mount macro mid-air will dismount you.",
        checked  = CharacterMountDB.allowFlyingDismount or false,
        onToggle = function(checked)
            CharacterMountDB.allowFlyingDismount = checked
            CharacterMount.PreRoll()
        end,
    })

    mountBehavior:Toggle({
        label    = "Prompt on New Mount",
        desc     = "Show a dialog asking to add a newly unlocked mount to your character list.",
        checked  = CharacterMountDB.autoPromptNewMount ~= false,
        onToggle = function(checked)
            CharacterMountDB.autoPromptNewMount = checked
        end,
    })

    mountBehavior:Toggle({
        label    = "Show 3D mount preview",
        desc     = "Display a live 3D model of the mount next to the new-mount prompt.",
        checked  = CharacterMountDB.showMountPreview ~= false,
        onToggle = function(checked)
            CharacterMountDB.showMountPreview = checked
        end,
    })

    mountBehavior:Toggle({
        label    = "Assign mounts to holidays",
        desc     = "Adds an \"Only during a holiday\" submenu to each mount's options, so you can limit any mount to a chosen in-game holiday.",
        checked  = CharacterMountDB.holidayAssignEnabled or false,
        onToggle = function(checked)
            CharacterMountDB.holidayAssignEnabled = checked
        end,
    })

    mountBehavior:Toggle({
        label    = "Include micro-holidays",
        desc     = "Adds the short events to that submenu too, such as Un'Goro Madness, Trial of Style, and the bonus event weeks.",
        parent   = "Assign mounts to holidays",
        checked  = CharacterMountDB.microHolidaysEnabled or false,
        onToggle = function(checked)
            CharacterMountDB.microHolidaysEnabled = checked
        end,
    })

    mountBehavior:Slider({
        label    = "Holiday mount chance",
        desc     = "While a holiday is running, this is the chance each roll picks one of that holiday's mounts. The rest of the time a normal mount is chosen.",
        parent   = "Assign mounts to holidays",
        min      = 10,
        max      = 100,
        step     = 5,
        suffix   = "%",
        value    = CharacterMountDB.holidayWeightPercent or 50,
        onChanged = function(val)
            CharacterMountDB.holidayWeightPercent = val
        end,
    })

    local macros = panel:Group("Macros")

    macros:Section("Default Macro")
    macros:Button({
        label   = "Get Default Macro",
        desc    = "Puts the standard mount macro on your cursor. Drop it on an action bar to summon a random mount suited to where you are.",
        tooltip = "Creates the default macro that rolls a mount for your current location, then places it on your cursor ready to drop onto a bar.",
        width   = 160,
        onClick = function()
            CharacterMount.CreateMacro()
            HideUIPanel(SettingsPanel)
        end,
    })

    macros:Section("Ground Macro")
    macros:Button({
        label   = "Get Ground Macro",
        desc    = "Puts a ground-only mount macro on your cursor. Drop it on an action bar to summon a random ground mount, even in flying zones.",
        tooltip = "Creates a macro that always rolls a ground mount, then places it on your cursor ready to drop onto a bar.",
        width   = 160,
        onClick = function()
            CharacterMount.CreateGroundMacro()
            HideUIPanel(SettingsPanel)
        end,
    })

    local mountListGroup = panel:Group("Mount List")
    mountListGroup:Button({
        label   = "Open Mount Journal",
        desc    = "Open the Mount Journal to add or remove mounts from your character list.",
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
        general.byLabel["Debug mode"].checkbox:SetChecked(CharacterMountDB.debugMode or false)
        general.byLabel["Minimap button"].checkbox:SetChecked(not (CharacterMountDB.minimap or {}).hide)
        general.byLabel["Silence mount warnings"].checkbox:SetChecked(CharacterMountDB.quietMountWarnings or false)
        mountBehavior.byLabel["Allow dismount while flying"].checkbox:SetChecked(CharacterMountDB.allowFlyingDismount or false)
        mountBehavior.byLabel["Prompt on New Mount"].checkbox:SetChecked(CharacterMountDB.autoPromptNewMount ~= false)
        mountBehavior.byLabel["Show 3D mount preview"].checkbox:SetChecked(CharacterMountDB.showMountPreview ~= false)
        mountBehavior.byLabel["Assign mounts to holidays"].checkbox:SetChecked(CharacterMountDB.holidayAssignEnabled or false)
        mountBehavior.byLabel["Include micro-holidays"].checkbox:SetChecked(CharacterMountDB.microHolidaysEnabled or false)
        mountBehavior.byLabel["Holiday mount chance"].slider:SetValue(CharacterMountDB.holidayWeightPercent or 50)
        RefreshMountList()
    end)
end

-- ---------------------------------------------------------------------------
-- Open the settings panel programmatically
-- ---------------------------------------------------------------------------
function CharacterMount.OpenSettings()
    LuckySettings:Open(CharacterMount.settingsCategory)
end
