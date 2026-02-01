# GitHub Copilot Instructions for Character Mount

## Project Overview
Character Mount is a simple World of Warcraft addon for character-specific mount management. It allows players to set preferences for which mounts to use on specific characters, creating a personalized mount experience per character.

## Code Style & Conventions

### Lua Standards
- **Lua Version**: Lua 5.1 (WoW's embedded version)
- **Line Length**: 120 characters maximum
- **Indentation**: 2 spaces (no tabs)
- **Comments**: Use `--` for single-line, document complex logic
- **String Quotes**: Prefer double quotes `"` for user-facing strings, single quotes `'` for internal keys

### Naming Conventions
```lua
-- Global addon namespace (PascalCase)
CharacterMount = {}

-- Public functions (PascalCase)
function CharacterMount.SummonMount() end
function CharacterMount.GetPreferredMount() end

-- Local/private functions (camelCase)
local function isGroundMount() end
local function isFlyingMount() end

-- Constants (UPPER_SNAKE_CASE)
local MAX_RETRIES = 3
local MOUNT_CACHE_DURATION = 60

-- Variables (camelCase)
local preferredMounts = {}
local mountCache = {}
```

### File Organization
```
CharacterMount/
├── CharacterMount.lua    -- Main addon logic, initialization, event handling
├── MountHelpers.lua      -- Helper functions for mount operations
└── CharacterMount.toc    -- Addon metadata
```

## WoW API Patterns

### Safe API Calls
Always use pcall for potentially failing WoW APIs:
```lua
local ok, mountID = pcall(C_MountJournal.GetMountFromItem, itemID)
if ok and mountID then
  -- use mountID
end
```

### Event Handling
```lua
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("COMPANION_UPDATE")
frame:SetScript("OnEvent", function(_, event, ...)
  if event == "PLAYER_LOGIN" then
    -- handle login
  elseif event == "COMPANION_UPDATE" then
    -- handle mount collection changes
  end
end)
```

### Mount API
```lua
-- Get mount collection
C_MountJournal.GetNumMounts()
C_MountJournal.GetMountIDs()

-- Get mount info
local name, spellID, icon, isActive, isUsable, sourceType, isFavorite, isFactionSpecific, 
      faction, shouldHideOnChar, isCollected, mountID = C_MountJournal.GetMountInfoByID(mountID)

-- Summon mount
C_MountJournal.SummonByID(mountID)
```

## Addon-Specific Patterns

### Character Preferences
Store character-specific mount preferences:
```lua
CharacterMountDB = {
  characters = {
    ["RealmName-CharName"] = {
      groundMount = 123,     -- Mount ID for ground
      flyingMount = 456,     -- Mount ID for flying
      favoriteList = {789, 234, 567},
    }
  }
}
```

### Debug Logging
Use simple debug printing:
```lua
local DEBUG = false

local function dprint(...)
  if DEBUG then
    print("[CharacterMount]", ...)
  end
end
```

### SavedVariables
```lua
-- Per-character preferences
CharacterMountDB = {
  currentCharacter = "RealmName-CharName",
  characters = {},
  settings = {
    autoSummon = false,
    useRandomFavorite = true,
  }
}
```

## Testing & Debugging

### Testing Commands
Add slash commands for testing mount functionality:
```lua
SLASH_CHARMOUNT1 = "/charmount"
SLASH_CHARMOUNT2 = "/cm"
SlashCmdList["CHARMOUNT"] = function(msg)
  if msg == "summon" then
    CharacterMount.SummonMount()
  elseif msg == "list" then
    CharacterMount.ListPreferredMounts()
  elseif msg == "debug" then
    DEBUG = not DEBUG
    print("Debug:", DEBUG and "ON" or "OFF")
  end
end
```

## Common Pitfalls to Avoid

### ❌ Don't: Summon mounts without checking usability
```lua
-- Bad: Direct summon without checks
C_MountJournal.SummonByID(mountID)
```

### ✅ Do: Verify mount is usable
```lua
-- Good: Check if mount can be used
local _, _, _, _, isUsable, _, _, _, _, _, isCollected = C_MountJournal.GetMountInfoByID(mountID)
if isCollected and isUsable then
  C_MountJournal.SummonByID(mountID)
else
  print("Mount is not available")
end
```

### ❌ Don't: Assume player key format
```lua
-- Bad: Inconsistent key format
local key = UnitName("player")
```

### ✅ Do: Use consistent realm-name format
```lua
-- Good: Consistent character key
local realm = GetRealmName()
local name = UnitName("player")
local key = realm .. "-" .. name
```

### ❌ Don't: Cache mount data indefinitely
```lua
-- Bad: Never refreshing cache
if not mountCache then
  mountCache = ScanMounts()
end
```

### ✅ Do: Refresh mount cache periodically
```lua
-- Good: Time-based cache invalidation
local lastCacheTime = 0
local function getMounts()
  if GetTime() - lastCacheTime > 60 then
    mountCache = ScanMounts()
    lastCacheTime = GetTime()
  end
  return mountCache
end
```

## Architecture Principles

### Module Separation
- **CharacterMount.lua**: Core logic, event handling, mount summoning
- **MountHelpers.lua**: Utility functions for mount operations, filtering, sorting

### Event Flow
```
PLAYER_LOGIN
  → Initialize SavedVariables
  → Load character preferences
  → Cache mount collection

COMPANION_UPDATE
  → Refresh mount cache
  → Update UI if visible

Mount Summon Request
  → Check current zone/situation
  → Select appropriate mount
  → Verify usability
  → Summon mount
```

### Data Flow
```
User sets preferred mount
  → Store in CharacterMountDB
  → Update cache

User requests mount summon
  → Check zone (flying allowed?)
  → Load character preferences
  → Select mount from preferences
  → Summon selected mount
```

## TOC File Requirements

When adding new Lua files, update `CharacterMount.toc`:
```toc
## Interface: 120000
## Title: Character Mount
## Notes: A World of Warcraft addon for character-specific mount management
## Version: 0.0.1
## Author: Lucky Phil
## SavedVariables: CharacterMountDB

MountHelpers.lua
CharacterMount.lua
NewFile.lua  ← Add here in load order
```

## Performance Considerations

- **Cache mount data**: Don't scan journal repeatedly
- **Lazy load UI**: Only create frames when needed
- **Minimal event registration**: Only register events you need
- **Efficient mount selection**: Pre-filter usable mounts

## Git Workflow

### Commit Messages
Follow conventional commits:
```bash
feat: add random favorite mount selection
fix: correct flying mount detection in Dragonflight zones
docs: update README with usage examples
chore: bump version to 0.1.0
ci: improve release workflow packaging
```

### Release Process
```bash
# 1. Update version in TOC file
# 2. Update CHANGELOG.md with new version (if exists)
# 3. Commit changes
git add .
git commit -m "chore: bump version to v0.1.0"

# 4. Push to main
git push origin main

# 5. Create and push tag
git tag v0.1.0
git push origin v0.1.0

# 6. GitHub Actions automatically:
#    - Packages addon from CharacterMount subfolder
#    - Creates release zip
#    - Uploads to CurseForge via BigWigsMods packager
#    - Optionally creates GitHub Release (if GITHUB_OAUTH set)
```

## When Making Changes

1. **Check for existing patterns** - Look at similar code in other files
2. **Test in-game** - Try summoning mounts in different zones and situations
3. **Enable debug logging** - Use debug flag to see mount selection logic
4. **Handle edge cases** - nil checks, mount not collected, zone restrictions
5. **Update CHANGELOG.md** - Add user-facing changes only (new features, bug fixes, behavior changes). Skip internal refactoring, code cleanup, or non-visible changes
6. **Update documentation** - README.md and inline comments when needed
7. **Verify TOC load order** - Ensure dependencies are loaded first

### Changelog Guidelines
- **Include**: New features, bug fixes, behavior changes users will notice, mount selection improvements
- **Exclude**: Code refactoring, variable renames, internal architecture changes
- **Format**: Use Added/Changed/Fixed/Removed categories under the version heading

## Resources

- [WoW API Documentation](https://wowpedia.fandom.com/wiki/World_of_Warcraft_API)
- [Mount Journal API](https://wowpedia.fandom.com/wiki/API_C_MountJournal)
- [Companion API](https://wowpedia.fandom.com/wiki/API_C_Companion)
- [Lua 5.1 Reference](https://www.lua.org/manual/5.1/)
