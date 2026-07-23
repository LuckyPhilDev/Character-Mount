[Join the Discord](https://discord.gg/87HRHcAYP)

**Character Mount** gives each of your characters a personal mount list and summons a random mount from it with a single button press.

---

### Features

- **Per-character mount list**: every character gets their own curated set of mounts, stored account-wide in SavedVariables.
- **Onboarding wizard**: on first login, suggests racial mounts, class mounts, and notable rare mounts. Pick what you want and get started in seconds.
- **New mount prompt**: when you unlock a new mount, a dialog appears offering to add it to your current character's list or all characters at once, with a live 3D preview of the mount alongside it.
- **Spell form support**: Druid Travel Form, Dracthyr Soar, and Worgen Running Wild are treated as mounts and randomised alongside journal mounts.
- **Random summoning**: click the macro to summon a random mount from your list, automatically filtered by context (ground, flying, or water).
- **Combat mounting**: the macro also works mid-combat in the rare encounters where the game allows it, such as Tindral Sageswift, Dimensius, and The Dawnbreaker.
- **Mount Journal integration**: Add and remove mounts from the list from the mount journal.
- **Search the list**: a search box at the top of the mount list filters your mounts by name as you type, with the header showing how many match.
- **Source tags**: colour-coded pills show each mount's origin: Racial, Class, Manual, Suggested, or Rare.
- **Per-spec control**: each mount has a spec button showing how many of your specs it applies to. Click it to tick the specs a mount should be used for. Mounts switched off for your current spec are dimmed in the list and skipped when you summon a random mount.
- **Excluded mounts**: removed mounts appear in an "Excluded" section with a one-click restore.
- **Minimap button**: left-click to open the mount list, right-click for settings, middle-click to toggle dev mode. Drag to reposition.
- **Settings panel**: configure options and view your mount list via ESC > Options > AddOns, or `/cmount settings`. Includes toggles to disable the new mount prompt, its 3D preview, and the chat warnings shown when you cannot mount.
- **Debug mode**: account-wide toggle to print mount selection diagnostics to chat.
- **Open Mount Journal**: quick-access button in both the mount list and settings panel.

---

### How to Use

1. Install the addon (requires **Lucky's Utils** dependency).
2. Log in. The onboarding wizard appears automatically for new characters.
3. Select the mounts you want and click **Add Selected**.
4. Type `/cmount macro` to create an action bar macro, then drag it to your bar.
5. Click the macro to summon a random mount from your list.

You can re-run the onboarding at any time via the **Setup** button in the mount list, or `/cmount reset onboarding`. Both ask you to confirm first, since re-running Setup clears your current mount list.

---

### Slash Commands

| Command | Description |
|---|---|
| `/cmount` | Open or close the mount list UI |
| `/cmount settings` | Open the settings panel |
| `/cmount macro` | Create or update the action bar macro |
| `/cmount mount` | Summon a random mount from your list |
| `/cmount add <name or id>` | Add a mount by name (partial match) or ID |
| `/cmount remove <name or id>` | Remove a mount by name or ID |
| `/cmount reset` | Clear all exclusions |
| `/cmount reset all` | Clear exclusions and manual additions |
| `/cmount reset onboarding` | Reset and re-run the onboarding wizard |
| `/cmount debug` | Show saved state for the current character |

---

### Known Issues & Notes

- The first macro click after creating the macro uses a fallback random mount. Subsequent clicks use the full random pool including spell forms.
- Spell form availability is checked via `IsSpellKnown()`. If a spell is temporarily unavailable (e.g., level-restricted), it won't appear in the pool.
- Profession mounts (tailoring carpets, engineering machines, etc.) are filtered out of onboarding suggestions.
