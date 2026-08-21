-- Character Mount: User-facing strings.
-- Centralised here so wording can be tweaked without hunting through feature
-- files. Format strings use Lua's standard %s / %d placeholders; pass through
-- string.format at the call site.
--
-- Debug output stays inline with the code that emits it, being diagnostics
-- rather than copy. So do the mount group and holiday names in MountData.lua:
-- those are matched against the game's own calendar and journal data, so they
-- are keys rather than labels.

CharacterMount = CharacterMount or {}

CharacterMount.Strings = LuckyStrings.New("CharacterMount.Strings", {
    addon = {
        title  = "Lucky's Character Mount",
        prefix = "CharMount:",
    },

    minimap = {
        tooltipTitle = "Lucky's Character Mount",
        leftClick    = "Left-click: Open mount list",
        rightClick   = "Right-click: Open settings",
        middleClick  = "Middle-click: Toggle dev mode",
        drag         = "Drag: Move button",
        devMode      = "Dev mode: %s",
        devModeOn    = "ON",
        devModeOff   = "OFF",
    },

    forms = {
        travelForm  = "Travel Form",
        soar        = "Soar",
        runningWild = "Running Wild",
        genericForm = "form",
        genericMount = "mount",
    },

    sources = {
        racial    = "Racial",
        class     = "Class",
        manual    = "Manual",
        suggested = "Suggested",
        rare      = "Rare",
        shop      = "Shop",
    },

    mountTypes = {
        ground = "Ground",
        flying = "Flying",
        water  = "Water",
    },

    menu = {
        useForSpecs        = "Use this mount for:",
        countAs            = "Count as:",
        defaultSuffix      = " (default)",
        flyingButCannotFly = "Summoned when flying, but it cannot fly",
        onlyDuringHoliday  = "Only during a holiday",
        removeFromList     = "Remove from Character List",
        reenableInList     = "Re-enable in Character List",
        excludeFromList    = "Exclude from Character List",
        addToList          = "Add to Character List",
    },

    specTooltip = {
        availableForSpecs = "Available for specs",
        specOffSuffix     = " (off)",
        countsAs          = "Counts as",
        nothingSelected   = "Nothing selected",
        onlyDuringActive  = "Only during %s (active now)",
        onlyDuringIdle    = "Only during %s (not running)",
        clickToChange     = "Click to change",
    },

    mountList = {
        title             = "Character Mounts",
        searchPlaceholder = "Search mounts...",
        mountNow          = "Mount Now",
        createMacro       = "Create Macro",
        setup             = "Setup",
        journal           = "Journal",
        openJournal       = "Open Mount Journal",
        restore           = "Restore",
        removeFromList    = "Remove from this list",
        clickToPreview    = "Click to preview this mount.",
        preview           = "Preview",
        noMounts          = "No mounts yet.\nUse /cmount add <name> or add mounts from the mount journal.",
        noMatches         = "No mounts match \"%s\".",
        countLabel        = "%d mounts in your character list",
        excludedToggle    = "Excluded (%d)",
        activeToggle      = "Your mounts (%d)",
        toggleHint        = "Click to show",
    },

    journalButton = {
        noneSelected   = "No Mount Selected",
        removeFromList = "Remove from Char List",
        addToList      = "Add to Char List",
        tooltipTitle   = "Character Mount",
        tooltipOnList  = "This mount is in your character mount list.",
        tooltipRemove  = "Middle-click the mount to remove it.",
    },

    newMount = {
        title       = "New Mount Unlocked!",
        question    = "Would you like to add it to your mount list?",
        disableHint = "(This prompt can be disabled in settings)",
        currentChar = "Current Char",
        noThanks    = "No Thanks",
        allChars    = "All Chars",
    },

    onboarding = {
        title          = "Set Up Your Mounts",
        subtitle       = "%s - %s %s",
        blurb          = "Choose mounts below to get your character list started. Click a mount to preview it. You can add or remove mounts later from the journal or by opening the /cmount menu.",
        noSuggestions  = "No suggested mounts found for your character.",
        addSelected    = "Add Selected",
        skip           = "Skip",
        selectAll      = "Select All",
        deselectAll    = "Deselect All",
        clickToPreview = "Click to preview this mount.",
        added          = "Added %d mounts to your list.",
        skipped        = "Onboarding skipped. Use /cmount add <name> to add mounts later.",
        reset          = "Onboarding reset.",
        resetConfirm   = "Running Setup again will clear your current mount list and any spec choices.\n\nContinue?",
    },

    settings = {
        debugMode          = "Debug mode",
        debugModeDesc      = "Print detailed mount selection diagnostics to chat.",
        minimapButton      = "Minimap button",
        minimapButtonDesc  = "Show the Character Mount button on the minimap.",
        whatsNew           = "What's New",
        preferences        = "Preferences",
        newMountsSection   = "New mounts",
        promptNewMount     = "Prompt on New Mount",
        promptNewMountDesc = "Show a dialog asking to add a newly unlocked mount to your character list.",
        showPreview        = "Show 3D mount preview",
        showPreviewDesc    = "Display a live 3D model of the mount next to the new-mount prompt.",
        holidaysSection    = "Holidays",
        holidayAssign      = "Assign mounts to holidays",
        holidayAssignDesc  = "Adds an \"Only during a holiday\" submenu to each mount's options, so you can limit any mount to a chosen in-game holiday.",
        microHolidays      = "Include micro-holidays",
        microHolidaysDesc  = "Adds the short events to that submenu too, such as Un'Goro Madness, Trial of Style, and the bonus event weeks.",
        holidayChance      = "Holiday mount chance",
        holidayChanceDesc  = "While a holiday is running, this is the chance each roll picks one of that holiday's mounts. The rest of the time a normal mount is chosen.",
        holidayNote        = "Covers: %s.",
        macros             = "Macros",
        defaultMacro       = "Default Macro",
        getDefaultMacro    = "Get Default Macro",
        getDefaultMacroDesc = "Puts the standard mount macro on your cursor. Drop it on an action bar to summon a random mount suited to where you are.",
        getDefaultMacroTip = "Creates the default macro that rolls a mount for your current location, then places it on your cursor ready to drop onto a bar.",
        groundMacro        = "Ground Macro",
        getGroundMacro     = "Get Ground Macro",
        getGroundMacroDesc = "Puts a ground-only mount macro on your cursor. Drop it on an action bar to summon a random ground mount, even in flying zones.",
        getGroundMacroTip  = "Creates a macro that always rolls a ground mount, then places it on your cursor ready to drop onto a bar.",
        macroBehaviour     = "Macro behaviour",
        allowDismount      = "Allow dismount while flying",
        allowDismountDesc  = "When enabled, pressing the mount macro mid-air will dismount you.",
        quietWarnings      = "Silence mount warnings",
        quietWarningsDesc  = "Stop chat messages when you cannot mount, such as in combat or indoors.",
        mountListGroup     = "Mount List",
        openJournal        = "Open Mount Journal",
        openJournalDesc    = "Open the Mount Journal to add or remove mounts from your character list.",
    },

    warnings = {
        cannotDismountFlying = "Flying, cannot dismount. Enable in settings to allow this.",
        inCombat             = "In combat, cannot mount.",
        dead                 = "Dead, cannot mount.",
        inVehicle            = "In vehicle or on taxi.",
        indoors              = "Indoors, cannot mount.",
    },

    mounts = {
        invalidID      = "Invalid mount ID: %s",
        added          = "Added %s to your list.",
        addedAllChars  = "Added %s to all character lists.",
        removed        = "Removed %s from your list.",
    },

    macro = {
        combatBlocked = "Cannot create macro during combat.",
        updated       = "Macro '%s' updated. Drag it to your action bar.",
        created       = "Created macro '%s'. Drag it to your action bar.",
        limitReached  = "Cannot create macro, the macro limit is reached.",
        menuAPIMissing = "Menu API not available, right-click integration disabled.",
    },

    slash = {
        exclusionsCleared = "All exclusions cleared.",
        allCleared        = "All exclusions and manual additions cleared.",
        noMatch           = "No collected mount found matching '%s'.",
        multipleAdd       = "Multiple matches, use /cmount add <id>:",
        multipleRemove    = "Multiple matches, use /cmount remove <id>:",
        matchLine         = "  [%d] %s",
        testPopup         = "Testing new-mount popup with mount ID %s.",
        noSampleMount     = "No sample mount available. Usage: /cmount testpopup <id>",
        needMountID       = "Please provide a valid mount ID. Usage: /cmount testunlock <id>",
        usageTitle        = "Usage:",
        usage = {
            "  /cmount              open or close the UI",
            "  /cmount add <name>   add mount by name (partial ok)",
            "  /cmount add <id>     add mount by ID",
            "  /cmount remove <name|id>",
            "  /cmount macro        create action bar macro",
            "  /cmount groundmacro  create ground-only macro",
            "  /cmount mount        mount now",
            "  /cmount settings         open settings panel",
            "  /cmount reset            clear all exclusions",
            "  /cmount reset all        clear exclusions and manual additions",
            "  /cmount reset onboarding reset and re-trigger onboarding",
            "  /cmount debug            show saved state for this character",
        },
    },
})
