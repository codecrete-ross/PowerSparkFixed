# PowerSpark (Fixed)

<p align="center">
  <img src="Logo.png" alt="PowerSpark (Fixed) logo" width="120">
</p>

PowerSpark (Fixed) is an English-documented fork of
[PowerSpark](https://github.com/starpt/PowerSpark) for World of Warcraft:
The Burning Crusade Classic / TBC Anniversary clients.

The addon ID and install folder are `PowerSparkFixed`, so it can be installed
beside the original `PowerSpark` addon without sharing addon metadata, saved
variables, or slash commands. In game, it displays as `PowerSpark (Fixed)`.

## Fork Status

This repository tracks `starpt/PowerSpark` as `upstream` and keeps local fixes
in this fork. The fork exists to make the energy spark more reliable on TBC
Anniversary while preserving the original addon's class behavior wherever the
game mechanics do not require a difference.

All project documentation in this fork is maintained in English.

## What The Addon Does

PowerSpark (Fixed) draws a small spark over supported player power bars.

- For energy users, the spark shows the 2-second energy regeneration cycle.
- For mana users, the spark shows the 2-second mana regeneration pulse and the
  5-second rule wait after spending mana.
- The spark hides while the player is dead or in ghost form.
- Out of combat, the spark can hide at full mana or full energy based on addon
  options.
- The addon supports Blizzard player bars and optional integrations with
  DruidBarFrame, Shadowed Unit Frames, ElvUI, Statusbars2, and BiechuUnitFrames.
- Rogue Adrenaline Rush keeps the original 1-second energy interval handling.
- Settings are available with `/psf`, `/powersparkfixed`, or through
  Options > AddOns > PowerSpark (Fixed).

## What Is Different From Upstream

Compared with `starpt/PowerSpark` v1.16.1, this fork currently changes only the
energy timing and synchronization path.

- Uses `GetTimePreciseSec()` when available, falling back to `GetTime()`, for
  finer timing.
- Moves the spark every rendered frame instead of throttling visual movement to
  0.02 seconds.
- Polls hidden energy state every 0.01 seconds to reduce missed first ticks
  after form changes.
- Tracks display-power and shapeshift changes so cat-form energy timing can
  sync sooner.
- Anchors druid energy timing only on likely natural energy ticks, not on large
  powershift grants.
- Keeps rogue mechanics aligned with upstream except for the shared timing
  precision and smoother visual update changes.

## Accuracy Notes

The addon can only sync to energy changes after the WoW client observes them. It
cannot know a hidden server tick timestamp before the client receives the update.
If the game merges a natural tick and another energy gain into one visible
update, the addon avoids guessing when that would create a worse sync point.

## Installation

1. Download or clone this repository.
2. Copy the addon folder into your WoW install as
   `Interface\AddOns\PowerSparkFixed`.
3. Restart the game or run `/reload`.

For the current local TBC Anniversary install, the addon path is:

```text
G:\Battle.net Games\World of Warcraft\_anniversary_\Interface\AddOns\PowerSparkFixed
```

Local deploy from this repository:

```powershell
Copy-Item -Path .\PowerSpark.lua, .\Options.lua, .\PowerSparkFixed.toc, .\README.md, .\Logo.png, .\Logo.tga -Destination 'G:\Battle.net Games\World of Warcraft\_anniversary_\Interface\AddOns\PowerSparkFixed' -Force
```

## Development

The original project remote should be kept as `upstream`. This fork's GitHub
remote should be `origin`.

Useful checks:

```sh
git diff --check
```

If Lua tooling is available:

```sh
luac -p PowerSpark.lua
```

## Upstream History

The original README changelog covered upstream PowerSpark releases through
v1.16.1. This fork begins from that version and documents fork-specific changes
in English going forward.
