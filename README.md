# Compass

A personal fork, for retail and WoW: Forever, of [Wayfinder](https://github.com/wyomarus/wayfinder) by **Wyomarus**: a compass
banner at the top of the screen, with a marker, distance and ETA for whatever you're super-tracking.

The addon folder is `Compass`. It keeps upstream's `WayfinderSettings` saved variable, so don't install it alongside
the upstream addon. It's tuned to work alongside **Waypoint UI**.

## Changes from upstream

- **Taint fix.** The options page is built from Wayfinder's own frames (a canvas category) instead of Blizzard's
  pooled Settings controls. Upstream's dropdown ran addon code inside Blizzard's recycled controls, which later broke
  Nameplates → Style ("attempt to perform arithmetic on a secret number value (execution tainted by 'Wayfinder')").
- **Options page** with **General** and **Colors** tabs (styled like BlizzMove's), Blizzard's standard dropdown and
  slider, and the About page removed.
- **Distance from Blizzard's navigation** (`C_Navigation.GetDistance`) instead of the quest's map pin, which can be
  several yards off. Rounded up with thousands separators and refreshed on the same schedule as Waypoint UI (every
  frame while moving, every 0.1s while still), so the two addons show the same number.
- **ETA from closing speed** (how fast the distance actually shrinks, smoothed), like Waypoint UI, instead of raw
  movement speed; works in combat, formatted `1h 2m 5s`, hidden while there's no estimate.
- **Hide near the target:** the marker and readout fade out within a configurable distance (default 25 yds) and
  inside the tracked quest's objective area, where the map pin is least reliable as a direction.
- **Point at edge** option (rotate the marker when it's pinned at the edge of the banner).
- **Rares / treasures** (super-tracked vignettes) get a marker.
- **Compass colors:** configurable color and opacity for the cardinal and intercardinal letters, tick marks and
  center line (Blizzard's color picker), with a reset.
- The marker and readout draw above the compass letters.
- The CurseForge/Wago/WoWInterface project ids have been removed from the TOC on purpose, so managers won't replace
  this with upstream.

Slash commands: `/compass` (see `/compass` for the list; `/compass settings` opens the options). The original `/wayfinder` and `/wf` still work.

## Install

Download `Compass-<version>.zip` from the [latest release](../../releases/latest) and extract the
`Compass` folder into `World of Warcraft\_retail_\Interface\AddOns\` (for WoW: Forever, `_classic_beta_` instead of `_retail_`).

An addon manager that installs from GitHub releases (e.g. WowUp: *Install from URL* with this repo's URL) can also
install and update it, **but only if the repository is public**.

To update from the command line (works for a private repo, needs `gh auth login` once):

```powershell
.\scripts\update-from-release.ps1
```

## Developing / releasing

- Test local changes: `.\scripts\install-local.ps1` copies the addon folder into `AddOns`, then `/reload`.
- After a WoW patch: bump `## Interface:` in `Compass/Compass.toc`.
- Release: `git tag v1.1.0 && git push --tags`. The [Release workflow](.github/workflows/release.yml) stamps the
  version into the TOC, builds the zip (with a `release.json` so addon managers see it's a retail and Forever build), and
  publishes the GitHub release.

The addon folder also contains upstream's own README, HISTORY, DEVNOTES and RELEASE notes, kept as they were.

## Credits and license

Wayfinder was created by **Wyomarus**. Licensed under the **MIT License**, the same as upstream
([`LICENSE.md`](LICENSE.md), also included in the addon folder). Upstream's bundled libraries (HereBeDragons, LibStub,
CallbackHandler) are no longer included: the world coordinates come straight from Blizzard's map API.
