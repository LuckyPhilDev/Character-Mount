-- Character Mount: Static mount ID tables for racial and class mounts.
-- IDs verified against WarcraftMounts.com Blizzard ID field (= C_MountJournal mount ID).
-- To verify an ID in-game: /run local n=C_MountJournal.GetMountInfoByID(ID) print(n)
-- The isCollected check in CharacterMount.lua means only collected mounts appear in the list.

CharacterMount = CharacterMount or {}
CharacterMount.MountData = {}

local MD = CharacterMount.MountData

-- ---------------------------------------------------------------------------
-- Racial mounts
-- Keyed by the englishRace returned by UnitRace("player").
-- Each array lists mount journal IDs for that race's starter/vendor mounts.
-- ---------------------------------------------------------------------------
MD.RACIAL_MOUNTS = {
    -- -----------------------------------------------------------------------
    -- Alliance
    -- -----------------------------------------------------------------------

    ["Human"] = {
        6,    -- Brown Horse
        18,   -- Chestnut Mare
        11,   -- Pinto
        9,    -- Black Stallion
        53,   -- White Stallion
        91,   -- Swift Palomino
        92,   -- Swift White Steed
        93,   -- Swift Brown Steed
        321,  -- Swift Gray Steed
    },

    ["Dwarf"] = {
        25,   -- Brown Ram
        21,   -- Gray Ram
        24,   -- White Ram
        64,   -- Black Ram
        94,   -- Swift Brown Ram
        95,   -- Swift Gray Ram
        96,   -- Swift White Ram
    },

    ["NightElf"] = {
        31,   -- Spotted Frostsaber
        337,  -- Striped Dawnsaber
        26,   -- Striped Frostsaber
        34,   -- Striped Nightsaber
        85,   -- Swift Mistsaber
        87,   -- Swift Frostsaber
        107,  -- Swift Stormsaber
    },

    ["Gnome"] = {
        40,   -- Blue Mechanostrider
        57,   -- Green Mechanostrider
        39,   -- Red Mechanostrider
        58,   -- Unpainted Mechanostrider
        88,   -- Swift Yellow Mechanostrider
        89,   -- Swift White Mechanostrider
        90,   -- Swift Green Mechanostrider
    },

    ["Draenei"] = {
        147,  -- Brown Elekk
        163,  -- Gray Elekk
        164,  -- Purple Elekk
        166,  -- Great Blue Elekk
        165,  -- Great Green Elekk
        167,  -- Great Purple Elekk
    },

    ["Worgen"] = {},

    ["Pandaren"] = {
        452,  -- Green Dragon Turtle
        453,  -- Great Red Dragon Turtle
        492,  -- Black Dragon Turtle
        493,  -- Blue Dragon Turtle
        494,  -- Brown Dragon Turtle
        495,  -- Purple Dragon Turtle
        496,  -- Red Dragon Turtle
        497,  -- Great Green Dragon Turtle
        498,  -- Great Black Dragon Turtle
        499,  -- Great Blue Dragon Turtle
        500,  -- Great Brown Dragon Turtle
        501,  -- Great Purple Dragon Turtle
        450,  -- Pandaren Kite
        516,  -- Pandaren Kite
        464,  -- Azure Cloud Serpent
        465,  -- Golden Cloud Serpent
        471,  -- Onyx Cloud Serpent
        472,  -- Crimson Cloud Serpent
        517,  -- Thundering Ruby Cloud Serpent
        518,  -- Ashen Pandaren Phoenix
        519,  -- Emerald Pandaren Phoenix
        520,  -- Violet Pandaren Phoenix
        521,  -- Jade Pandaren Kite
        2069, -- Feathered Windsurfer
    },

    -- -----------------------------------------------------------------------
    -- Allied Races — Alliance
    -- -----------------------------------------------------------------------

    ["VoidElf"] = {
        1009, -- Starcursed Voidstrider
    },

    ["LightforgedDraenei"] = {
        1006, -- Lightforged Felcrusher
        -- 932, -- Lightforged Warframe (associated/faction mount, not the unlock mount)
    },

    ["DarkIronDwarf"] = {
        1048, -- Dark Iron Core Hound
        -- Mole Machine destinations are not Mount Journal mounts.
    },

    ["KulTiran"] = {
        1015, -- Dapple Gray
        1198, -- Kul Tiran Charger
    },

    ["Mechagnome"] = {
        1283, -- Mechagon Mechanostrider
    },

    -- -----------------------------------------------------------------------
    -- Horde
    -- -----------------------------------------------------------------------

    ["Orc"] = {
        20,   -- Brown Wolf
        19,   -- Dire Wolf
        14,   -- Timber Wolf
        310,  -- Black Wolf
        104,  -- Swift Brown Wolf
        105,  -- Swift Timber Wolf
        106,  -- Swift Gray Wolf
    },

    ["Undead"] = {
        66,   -- Blue Skeletal Horse
        67,   -- Brown Skeletal Horse
        65,   -- Red Skeletal Horse
        68,   -- Green Skeletal Warhorse
        100,  -- Purple Skeletal Warhorse
        314,  -- Black Skeletal Horse
    },

    ["Tauren"] = {
        72,   -- Brown Kodo
        71,   -- Gray Kodo
        309,  -- White Kodo
        103,  -- Great Brown Kodo
        102,  -- Great Gray Kodo
        101,  -- Great White Kodo
    },

    ["Troll"] = {
        27,   -- Emerald Raptor
        36,   -- Turquoise Raptor
        38,   -- Violet Raptor
        97,   -- Swift Blue Raptor
        98,   -- Swift Olive Raptor
        99,   -- Swift Orange Raptor
    },

    ["BloodElf"] = {
        158,  -- Blue Hawkstrider
        159,  -- Black Hawkstrider
        157,  -- Purple Hawkstrider
        152,  -- Red Hawkstrider
        302,  -- Silvermoon Hawkstrider
        161,  -- Swift Purple Hawkstrider
        320,  -- Swift Red Hawkstrider
        213,  -- Swift White Hawkstrider
        291,  -- Blue Dragonhawk
        292,  -- Red Dragonhawk
        330,  -- Sunreaver Dragonhawk
        548,  -- Armored Red Dragonhawk
    },

    ["Goblin"] = {
        388,  -- Goblin Trike
        389,  -- Goblin Turbo-Trike
    },

    -- -----------------------------------------------------------------------
    -- Allied Races — Horde
    -- -----------------------------------------------------------------------

    ["Nightborne"] = {
        1008, -- Nightborne Manasaber
    },

    ["HighmountainTauren"] = {
        1007, -- Highmountain Thunderhoof
    },

    ["MagharOrc"] = {
        1044, -- Mag'har Direwolf
    },

    ["ZandalariTroll"] = {
        1038, -- Zandalari Direhorn
    },

    ["Vulpera"] = {
        1286, -- Caravan Hyena
        1039, -- Mighty Caravan Brutosaur
    },

    -- -----------------------------------------------------------------------
    -- Neutral / Other
    -- -----------------------------------------------------------------------

    ["Dracthyr"] = {
        1664, -- Guardian Vorquin
        1665, -- Swift Armored Vorquin
        1667, -- Armored Vorquin Leystrider
        1668, -- Majestic Armored Vorquin
        1683, -- Crimson Vorquin
        1684, -- Sapphire Vorquin
        1685, -- Bronze Vorquin
        1686, -- Obsidian Vorquin
    },

    ["Earthen"] = {
        2214, -- Slatestone Ramolith
    },
}

MD.CLASS_MOUNTS = {
    ["PALADIN"] = {
        -- Classic / racial paladin mounts
        41,    -- Warhorse
        84,    -- Charger
        150,   -- Thalassian Warhorse
        149,   -- Thalassian Charger
        350,   -- Sunwalker Kodo
        351,   -- Great Sunwalker Kodo
        367,   -- Exarch's Elekk
        368,   -- Great Exarch's Elekk
        1047,  -- Dawnforge Ram
        1046,  -- Darkforge Ram
        1225,  -- Crusader's Direhorn
        1568,  -- Lightforged Ruinstrider

        -- Legion class hall mounts
        885,   -- Highlord's Golden Charger
        892,   -- Highlord's Vengeful Charger
        893,   -- Highlord's Vigilant Charger
        894,   -- Highlord's Valorous Charger
    },

    ["WARLOCK"] = {
        17,   -- Felsteed
        83,   -- Dreadsteed
        898,  -- Netherlord's Chaotic Wrathsteed
        930,  -- Netherlord's Brimstone Wrathsteed
        931,  -- Netherlord's Accursed Wrathsteed
    },

    ["DEATHKNIGHT"] = {
        221,  -- Acherus Deathcharger
        866,  -- Deathlord's Vilebrood Vanquisher
    },

    ["DEMONHUNTER"] = {
        868,  -- Slayer's Felbroken Shrieker
    },

    ["DRUID"] = {
        -- Archdruid's Lunarwing Form is a class form/spell, not a Mount Journal mount ID.
    },

    ["HUNTER"] = {
        865,  -- Huntmaster's Loyal Wolfhawk
        870,  -- Huntmaster's Fierce Wolfhawk
        872,  -- Huntmaster's Dire Wolfhawk
    },

    ["MAGE"] = {
        860,  -- Archmage's Prismatic Disc
    },

    ["MONK"] = {
        864,  -- Ban-Lu, Grandmaster's Companion
    },

    ["PRIEST"] = {
        861,  -- High Priest's Lightsworn Seeker
    },

    ["ROGUE"] = {
        884,  -- Shadowblade's Murderous Omen
        889,  -- Shadowblade's Lethal Omen
        890,  -- Shadowblade's Baneful Omen
        891,  -- Shadowblade's Crimson Omen
    },

    ["SHAMAN"] = {
        888,  -- Farseer's Raging Tempest
    },

    ["WARRIOR"] = {
        867,  -- Battlelord's Bloodthirsty War Wyrm
    },

    ["EVOKER"] = {
        -- No unique class mount.
    },
}

-- ---------------------------------------------------------------------------
-- Accessor functions
-- ---------------------------------------------------------------------------

--- Returns the array of mount journal IDs for the given race, or {} if unknown.
-- @param englishRace string  e.g. "Human", "BloodElf", "Orc"
function MD.GetRacialMountIDs(englishRace)
    return MD.RACIAL_MOUNTS[englishRace] or {}
end

--- Returns the array of mount journal IDs for the given class, or {} if unknown.
-- @param classFile string  e.g. "PALADIN", "WARLOCK", "DEATHKNIGHT"
function MD.GetClassMountIDs(classFile)
    return MD.CLASS_MOUNTS[classFile] or {}
end

-- ---------------------------------------------------------------------------
-- Mount group names — maps mount IDs to a display group for onboarding UI.
-- Mounts in the same group get a shared sub-header with a select-all toggle.
-- ---------------------------------------------------------------------------
MD.MOUNT_GROUPS = {}
local function RegisterGroup(groupName, ids)
    for _, id in ipairs(ids) do
        MD.MOUNT_GROUPS[id] = groupName
    end
end

-- Racial ground families
RegisterGroup("Horses",          {6, 18, 11, 9, 53, 91, 92, 93, 321, 376, 579})
RegisterGroup("Skeletal Horses", {66, 67, 65, 68, 100, 314, 168})
RegisterGroup("Rams",            {25, 21, 24, 64, 94, 95, 96})
RegisterGroup("Sabers",          {31, 337, 26, 34, 85, 87, 107, 393})
RegisterGroup("Mechanostriders", {40, 57, 39, 58, 88, 89, 90})
RegisterGroup("Elekks",          {147, 163, 164, 166, 165, 167})
RegisterGroup("Wolves",          {20, 19, 14, 310, 104, 105, 106})
RegisterGroup("Kodos",           {72, 71, 309, 103, 102, 101, 350, 351})
RegisterGroup("Raptors",         {27, 36, 38, 97, 98, 99, 78})
RegisterGroup("Hawkstriders",    {158, 159, 157, 152, 302, 161, 320, 213})
RegisterGroup("Trikes",          {388, 389})
RegisterGroup("Dragon Turtles",  {452, 453, 492, 493, 494, 495, 496, 497, 498, 499, 500, 501})

-- Racial/faction flying families
RegisterGroup("Gryphons",        {129, 130, 131, 132, 137, 138, 139})
RegisterGroup("Wind Riders",     {133, 134, 135, 136, 140, 141})
RegisterGroup("Hippogryphs",     {203, 329, 413, 568})
RegisterGroup("Dragonhawks",     {291, 292, 330, 548, 549})
RegisterGroup("Cloud Serpents",   {464, 465, 471, 472, 478, 517, 466, 473, 474, 475, 477, 504, 542, 561, 2582})
RegisterGroup("Kites",           {450, 516, 521, 2069})
RegisterGroup("Carpets",        {279, 285, 375, 603, 905, 2023, 2317})
RegisterGroup("Proto-Drakes",   {262, 263, 264, 265, 266, 267, 278, 306, 307, 1030, 1031, 1032, 1035, 1589, 1679, 1786})
RegisterGroup("Drakes",         {246, 247, 248, 249, 250, 253, 268, 349, 391, 392, 393, 394, 395, 396, 397, 407, 408, 442, 664, 1314, 1563, 1607, 1771})
RegisterGroup("Bats",            {544, 1049, 1210})
RegisterGroup("Yaks",            {460, 462, 484, 485, 486, 487})
RegisterGroup("Manasabers",      {881, 1008, 2670})
RegisterGroup("Shado-Pan Tigers", {505, 506, 507, 2087})
RegisterGroup("Bonesteeds",      {1196, 1197, 2679, 2681, 2682, 2683})

-- Class mount families
RegisterGroup("Paladin Chargers",   {41, 84, 150, 149, 350, 351, 367, 368, 1047, 1046, 1225, 1568, 885, 892, 893, 894, 2726, 338, 339})
RegisterGroup("Warlock Steeds",     {17, 83, 898, 930, 931, 2730})
RegisterGroup("Deathchargers",      {221, 866, 2720})
RegisterGroup("Demon Hunter Mounts", {868, 2721})
RegisterGroup("Wolfhawks",          {865, 870, 872, 2723})
RegisterGroup("Monk Companions",    {864, 2725})
RegisterGroup("Rogue Omens",        {884, 889, 890, 891, 2728})

-- Allied race mounts
RegisterGroup("Direhorns",       {1038, 1225})
RegisterGroup("Hyenas",          {1286})

--- Returns the group name for a mount, or nil if ungrouped.
function MD.GetMountGroup(mountID)
    return MD.MOUNT_GROUPS[mountID]
end

-- ---------------------------------------------------------------------------
-- Suggested mounts — opinionated, thematically fitting picks.
-- Race suggestions: faction flyers, race-themed mounts only.
-- Class suggestions: Felscorned mounts, thematic class picks only.
-- IDs need in-game verification: /run local n=C_MountJournal.GetMountInfoByID(ID) print(n)
-- ---------------------------------------------------------------------------
MD.SUGGESTED_MOUNTS = {
    race = {
        -- Alliance — Gryphons
        ["Human"]             = { 132, 137, 138, 139, 129, 130, 131 },
        ["Dwarf"]             = { 132, 137, 138, 139, 129, 130, 131 },
        ["Gnome"]             = { 205, 132, 137, 130, 131, 275, 574 },
        ["Draenei"]           = { 132, 137, 139, 130, 131 },
        ["Worgen"]            = { 132, 137, 130, 131 },
        -- Night Elf — Hippogryphs
        ["NightElf"]          = { 203, 329, 413, 568, 393, 1577 },
        -- Pandaren — Thundering / Heavenly Cloud Serpents
        ["Pandaren"]          = { 460, 462, 466, 473, 474, 475, 477, 478, 484, 485, 486, 487, 504, 505, 506, 507, 542, 561, 2087, 2582 },
        -- Allied — Alliance
        ["VoidElf"]           = { 139, 132, 130 },
        ["LightforgedDraenei"]= { 132, 139, 130 },
        ["DarkIronDwarf"]     = { 132, 137, 130, 275, 574 },
        ["KulTiran"]          = { 132, 130, 1013 },
        ["Mechagnome"]        = { 205, 132, 130, 275, 574 },

        -- Horde — Wind Riders
        ["Orc"]               = { 136, 140, 141, 133, 134, 135, 341 },
        ["Tauren"]            = {},
        ["Troll"]             = { 136, 140, 133, 134, 78 },
        ["Goblin"]            = { 205, 275, 574 },
        -- Undead — Bats
        ["Undead"]            = { 544, 1049, 1210, 168, 1196, 1197, 2679, 2681, 2682, 2683 },
        ["BloodElf"]          = {},
        -- Allied — Horde
        ["Nightborne"]        = { 881, 2670 },
        ["HighmountainTauren"]= {},
        ["MagharOrc"]         = { 341 },
        ["ZandalariTroll"]    = { 1043, 78 },
        ["Vulpera"]           = {},

        -- Neutral
        ["Dracthyr"]          = {},
        ["Earthen"]           = { 132, 130 },
    },

    class = {
        ["PALADIN"]     = { 2726, 338, 339 },
        ["WARLOCK"]     = { 2730, 168, 279, 285, 375, 603, 905, 2023, 2317 },
        ["DEATHKNIGHT"] = { 2720, 168, 219, 238, 1196, 1197, 2679, 2681, 2682, 2683 },
        ["DEMONHUNTER"] = { 2721 },
        ["DRUID"]       = { 2722, 393, 845 },
        ["HUNTER"]      = { 2723, 78 },
        ["MAGE"]        = { 2724, 566, 279, 285, 375, 603, 905, 2023, 2317 },
        ["MONK"]        = { 2725, 566, 523, 524, 525 },
        ["PRIEST"]      = { 2727, 279, 285, 375, 603, 905, 2023, 2317 },
        ["ROGUE"]       = { 2728, 168 },
        ["SHAMAN"]      = { 2729 },
        ["WARRIOR"]     = { 2731, 341, 338 },
        ["EVOKER"]      = {},
    },
}

-- ---------------------------------------------------------------------------
-- Rare mounts — notable collectibles any character might want.
-- Universal list, not keyed by class or race. Shown unchecked by default.
-- ---------------------------------------------------------------------------
MD.RARE_MOUNTS = {
    -- Classic / Wrath iconic
    363,  -- Invincible
    219,  -- Headless Horseman's Mount
    405,  -- Spectral Steed
    237,  -- White Polar Bear

    -- Burning Crusade / Classic prestige
    183,  -- Ashes of Al'ar
    168,  -- Fiery Warhorse's Reins
    213,  -- Swift White Hawkstrider

    -- Wrath of the Lich King
    304,  -- Mimiron's Head

    -- Cataclysm
    393,  -- Phosphorescent Stone Drake
    395,  -- Drake of the North Wind
    396,  -- Drake of the South Wind
    397,  -- Vitreous Stone Drake
    392,  -- Drake of the East Wind
    394,  -- Drake of the West Wind
    407,  -- Vial of the Sands

    -- Warlords of Draenor
    634,  -- Solar Spirehawk
    622,  -- Armored Razorback
    611,  -- Tundra Icehoof

    -- Legion
    945,  -- Vicious War Fox
    764,  -- Grove Warden
    791,  -- Fiendish Hellfire Core
    804,  -- Ratstallion

    -- Battle for Azeroth
    1217, -- G.M.O.D.
    1053, -- Underrot Crawg
    1219, -- Glacial Tidestorm
    1218, -- Dazar'alor Windreaver

    -- Shadowlands
    1304, -- Mawsworn Soulhunter
    1500, -- Sanctum Gloomcharger
    1481, -- Cartel Master's Gearglider
    1417, -- Hand of Hrestimorak

    -- Utility / valuable mounts
    449,  -- Azure Water Strider
    522,  -- Sky Golem
    275,  -- Mekgineer's Chopper
}

-- ---------------------------------------------------------------------------
-- Accessor functions for suggested/rare
-- ---------------------------------------------------------------------------

--- Returns suggested race mount IDs for the given race.
function MD.GetSuggestedRaceMountIDs(englishRace)
    return MD.SUGGESTED_MOUNTS.race[englishRace] or {}
end

--- Returns suggested class mount IDs for the given class.
function MD.GetSuggestedClassMountIDs(classFile)
    return MD.SUGGESTED_MOUNTS.class[classFile] or {}
end

--- Returns the flat array of rare mount IDs.
function MD.GetRareMountIDs()
    return MD.RARE_MOUNTS
end
