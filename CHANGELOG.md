# Changelog

All notable changes to Character Mount will be documented in this file.

## [1.1.0] - 2026-03-22

### Added
- Settings panel — accessible via ESC > Options > AddOns, or `/cmount settings`
- Debug mode toggle in settings (account-wide) — prints mount selection diagnostics to chat
- Mount list view in settings with remove buttons and source tags
- Open Mount Journal button in both the mount list UI and settings panel
- Debug logging migrated to shared LuckyLog utility from Luckys_Utils

### Changed
- Mount list dialog widened to better accommodate buttons and mount names
- `/cmount debug` now shows saved state (debug logging is controlled via settings)

## [1.0.0] - 2026-03-21

### Added
- Initial public release
- Per-character mount list with automatic racial and class mount detection
- Onboarding wizard for first-time setup — suggests racial, class, and rare mounts
- Spell-form support: Druid Travel Form, Dracthyr Soar, and Worgen Running Wild participate in the random mount pool
- Pre-roll macro system for seamless randomisation between journal mounts and spell forms
- Mount Journal integration — "Add/Remove" button on the Mount Journal detail panel
- Profession mount filtering — tailoring, engineering, and other profession-locked mounts excluded from onboarding suggestions
- Source tagging with colour-coded pills: Racial, Class, Manual, Suggested, Rare
- Slash commands: `/cmount` to open UI, `/cmount macro` to create action bar macro
- Setup button to re-run onboarding from the main UI
- Excluded mounts section with one-click restore
