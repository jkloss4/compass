# Release Notes

## [1.0.0] - 2026-09-24
### Changed
- Promoted from beta to a stable release. No functional changes since 1.0.0-beta.2 - the only blocker was the WoW: Forever beta's SavedVariables-not-read-back bug (see 1.0.0-beta.1's "Known issues" below). Blizzard has since fixed it upstream (Forever beta build 70009), it's been verified in-game against Wayfinder's own settings, and 1.0.0-beta.2 confirmed the automated release pipeline (CurseForge, Wago, and WoWInterface) publishes cleanly.

## [1.0.0-beta.2] - 2026-09-24
### Changed
- Docs/comment cleanup: removed the SavedVariables-bug notes from code comments, `Wayfinder.toc`, and DEVNOTES.md now that it's fixed upstream (Forever beta build 70009) - see 1.0.0-beta.1's "Known issues" below for the original context.
- Packaging: verifies the WoWInterface publish target added after 1.0.0-beta.1 (`X-WoWI-ID`) publishes correctly via the automated packager, ahead of the next stable release.

## [1.0.0-beta.1] - 2026-09-20
### Added
- Interface support for World of Warcraft: Forever (1.60.1, interface 16001), alongside current retail (12.1.0, interface 120100).
- SuperTracking: a marker, distance, and ETA readout on the compass banner for whatever you're currently super-tracking - quests, user-placed waypoints, area POIs, taxi nodes, and your own corpse.
- Configurable compass detail levels (0-3: none, cardinals, intercardinals, or a full ring of pips).
- A draggable, lockable compass banner (`/wayfinder unlock`/`lock`/`resetposition`), with its position remembered.
- A native in-game Settings panel (Escape > Options > AddOns, or `/wayfinder settings`), including an About page with the addon's icon and info.
- A minimap Addon Compartment entry for quick access, plus a proper addon icon shown there and in the addon list.

### Fixed
- SuperTracking marker never appearing (was using the wrong texture API for its atlas-based icon).
- SuperTracking failing to resolve a destination for older, pre-modern-navigation-system quest content.
- Updated the embedded HereBeDragons-2.0 library, whose vendored copy only indexed map IDs up to 2500 and would silently fail to resolve coordinates (breaking SuperTracking) in any zone added since then.
- A crash in the ETA readout when reading player speed while in combat, under WoW 12.0+'s "secret values" addon-disarmament system.

### Changed
- General code cleanup for idiomatic Lua/WoW addon conventions.

### Known issues
- WoW: Forever beta does not reliably read SavedVariables back on reload/restart (a confirmed upstream client bug, not a Wayfinder issue - see DEVNOTES.md). Compass detail, tracking toggles, and banner position may silently revert to their defaults until Blizzard fixes this.

## [1.0.0-alpha.1] - 2024-09-28
### Added
- Initial (alpha) release of Wayfinder.
- The main compass banner
- Cardinal waypoints

### Fixed
- N/A

### Changed
- N/A
