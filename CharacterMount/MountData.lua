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
