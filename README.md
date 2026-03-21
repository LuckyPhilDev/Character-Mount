**Character Mount** is a lightweight World of Warcraft addon that gives each of your characters a personal mount list and summons a random mount from it with a single button press.

---

### Features

- **Per-character mount list** — each character has their own curated set of mounts, stored account-wide in SavedVariables.
- **Onboarding wizard** — on first login, suggests racial mounts, class mounts, and notable rare mounts for your character. Pick what you want and get started in seconds.
- **Spell form support** — Druid Travel Form, Dracthyr Soar, and Worgen Running Wild are treated as mounts and participate in the random pool alongside journal mounts.
- **Random summoning** — click the macro button to summon a random mount from your list, filtered by context (ground, flying, or water).
- **Mount Journal integration** — right-click any mount in the journal to add or remove it from your character list. An "Add/Remove" button also appears on the mount detail panel.
- **Source tags** — mounts are tagged with colour-coded pills showing their source: Racial, Class, Manual, Suggested, or Rare.
- **Excluded mounts** — removed mounts appear in an "Excluded" section at the bottom of the UI, with a one-click restore button.

---

### Setup

1. Install the addon (requires **LuckyUI** dependency).
2. Log in — the onboarding wizard appears automatically for new characters.
3. Select the mounts you want and click **Add Selected**.
4. Type `/cmount macro` to create an action bar macro, then drag it to your bar.
5. Click the macro to summon a random mount from your list.

---

### Slash Commands

| Command | Description |
|---|---|
| `/cmount` | Open or close the mount list UI |
| `/cmount macro` | Create or update the action bar macro |
| `/cmount mount` | Summon a random mount from your list |
| `/cmount add <name or id>` | Add a mount by name (partial match) or ID |
| `/cmount remove <name or id>` | Remove a mount by name or ID |
| `/cmount reset` | Clear all exclusions |
| `/cmount reset all` | Clear all exclusions and manual additions |
| `/cmount reset onboarding` | Reset and re-run the onboarding wizard |
| `/cmount debug` | Show saved state for the current character |

---

### How It Works

- **Onboarding** populates your list with racial, class, and suggested mounts. You can re-run it at any time via the **Setup** button or `/cmount reset onboarding`.
- **Spell forms** (Travel Form, Soar, Running Wild) are cast via `/cast` in the macro text since protected spells cannot be invoked from Lua. The addon uses a pre-roll system: each macro click randomly picks the *next* mount and rewrites the macro accordingly, so spell forms and journal mounts share the random pool equally.
- **Mount category matching** automatically filters your list based on context — flyable zones use flying mounts, ground-only zones use ground mounts, and underwater areas prefer aquatic mounts.
- **Profession mounts** (tailoring carpets, engineering machines, etc.) are filtered out of onboarding suggestions since they require specific professions.

---

### Dependencies

- **LuckyUI** — shared UI framework (required)

---

### Known Issues

- The first macro click after creating the macro uses a fallback random mount (pre-roll hasn't happened yet). Subsequent clicks use the full random pool including spell forms.
- Spell form availability is checked via `IsSpellKnown()` — if a spell is temporarily unavailable (e.g., level-restricted), it won't appear in the pool.
