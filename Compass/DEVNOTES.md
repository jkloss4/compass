# Wayfinder Developer Notes

## Summary

Coding conventions and operational notes for contributors, kept separate from [HISTORY.md](HISTORY.md) (why the project exists) and [RELEASE.md](RELEASE.md) (what shipped when).

## Conventions

- **Namespacing.** Each file starts with `local _, addon = ...` and pulls in only the sub-namespaces it needs: `addon.API` (public surface, aliased `api`), `addon.private` (cross-file internals, aliased `_p`), `addon.Constants` (shared constants, aliased `_C`). When more than one is used, alias them in that order: `_p`, `api`, `_C`.
- **Naming.** `camelCase` for local/internal functions and variables; `PascalCase` for anything hung off `api` (e.g. `api.CardinalPoints.SetDetail`), mirroring Blizzard's own `C_*` namespace convention for the addon's public surface.
- **Comments.** A `---` block directly above a function or constant is that thing's doc comment - add `@param`/`@return` annotations when the signature isn't self-evident from its name. Plain `--` is for section headers and inline explanations. Trivial one-line wrappers around a single WoW API call don't need a comment at all.
- **Cached globals.** Frequently used globals (and WoW's namespaced `C_*` APIs) are cached as locals at the top of a file, under a `-- Cache global references` header when there's more than a couple.

## Known issues

- **WoW 12.0+ secret values.** Combat-related APIs (e.g. `GetUnitSpeed`) can return an opaque "secret" value while in combat, part of Blizzard's addon-disarmament system - arithmetic, comparison, and even `tostring()`/`print()` on one throws under tainted execution. Check `issecretvalue(value)` before touching a value from any such API and degrade gracefully (see `updateSuperTrackingReadout` and `debugSuperTracking` in [SuperTracking.lua](SuperTracking.lua)) rather than assuming a plain number.

## Reference

- **CI.** GitHub Actions (`.github/workflows/ci.yml`) runs `BigWigsMods/luacheck` (config in `.luacheckrc`) on every push and PR, and packages + publishes to CurseForge/Wago/WoWInterface via `BigWigsMods/packager` on tag pushes.
- **Third-party libraries.** Everything under `Libs/` (LibStub, CallbackHandler-1.0, HereBeDragons-2.0) is pulled in by `.pkgmeta` from its upstream repo - don't hand-edit it; update the pin in `.pkgmeta` instead.
- **Interop with other addons.** Wayfinder tracks `Enum.SuperTrackingType.UserWaypoint`, so any addon that sets one through Blizzard's standard `C_Map.SetUserWaypoint()` + `C_SuperTrack.SetSuperTrackedUserWaypoint(true)` - not just the map's right-click menu - shows up on the compass automatically, with no Wayfinder-specific integration on either side. Not yet confirmed that any specific popular addon actually uses this path (e.g. RareScanner integrates with TomTom instead, which is a separate, undocumented mechanism - see its own waypoint table on the global `TomTom` object if that's ever worth reading directly).
