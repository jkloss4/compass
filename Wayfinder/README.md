# Wayfinder

Welcome to Wayfinder, an addon for World of Warcraft that enhances your navigation experience with a compass banner.

![Wayfinder tracking a quest, with the compass banner, marker, distance, and ETA all visible](Media/Screenshot.png)

## Table of Contents

- [Wayfinder](#wayfinder)
  - [Table of Contents](#table-of-contents)
  - [Installation](#installation)
  - [Usage](#usage)
  - [Commands](#commands)
  - [Contributing](#contributing)
  - [License](#license)

## Installation

1. Download the latest release from the [Releases](https://github.com/wyomarus/wayfinder/releases) page.
2. Extract the contents of the zip file to your World of Warcraft `Interface/AddOns` directory.
3. Ensure the folder is named `Wayfinder`.

## Usage

Once installed, Wayfinder will automatically display a compass banner at the top of your screen when you log into the game. The banner shows cardinal and intercardinal directions plus a marker, distance, and ETA readout for whatever you're currently super-tracking (a quest, a waypoint, a corpse run, etc.). It hides itself automatically while you're inside an instance.

The banner is locked in place by default; `/wayfinder unlock` it to drag it to a new spot, then `/wayfinder lock` it back down - see [Commands](#commands).

SuperTracking currently follows quests, user-placed waypoints, area POIs, taxi nodes, and your own corpse. Other trackable target types (scenarios, world content, party members, vignettes) aren't handled yet, so the marker just won't appear for those.

All of the above is configurable from a "Wayfinder" panel in the game's own Settings (Escape > Options > AddOns), reachable with `/wayfinder settings` or from the minimap's Addon Compartment dropdown, which also toggles the banner with a click.

## Commands

All commands are available under `/wayfinder` or the shorter `/wf`.

| Command | Effect |
| --- | --- |
| `/wayfinder show` | Show the compass banner |
| `/wayfinder hide` | Hide the compass banner |
| `/wayfinder lock` | Lock the compass banner in place |
| `/wayfinder unlock` | Unlock the compass banner so it can be dragged to a new position |
| `/wayfinder resetposition` | Reset the compass banner to its default position |
| `/wayfinder settings` | Open the Wayfinder settings panel |
| `/wayfinder compass enable\|disable` | Enable or disable the cardinal/intercardinal direction markers |
| `/wayfinder detail <0-3>` | Set how much compass detail is shown (0 = none, 3 = cardinals + intercardinals + 15° ticks) |
| `/wayfinder tracking enable\|disable` | Enable or disable the SuperTracking marker |
| `/wayfinder distance enable\|disable` | Show or hide the SuperTracking distance readout |
| `/wayfinder eta enable\|disable` | Show or hide the SuperTracking ETA readout |
| `/wayfinder debug tracking` | Print SuperTracking diagnostic info, for troubleshooting a missing marker |

## Contributing

Bug reports, feature requests, and pull requests are welcome via [GitHub Issues](https://github.com/wyomarus/Wayfinder/issues) and [Pull Requests](https://github.com/wyomarus/Wayfinder/pulls). See [DEVNOTES.md](DEVNOTES.md) for the project's coding conventions.

## License

See LICENSE.md
