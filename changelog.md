# Changelog

All notable changes to this project. One version per working day: every change made on the same day goes
into that day's version; the next day of work starts a new version. When starting a new version, also update
`config/version` in `project.godot` (Project Settings > Application > Config > Version): the game shows it on screen.

## [0.7.0] - 2026-11-01

### Added
- New enemy: Wisp.
- New enemy: Haunted Armor. When it falls, a Wisp escapes from it and its empty armor stays behind.
- Wisps can bring empty armors back to life. Destroy the armor to stop them.
- New enemy: Bomboar. It explodes when killed, and its explosions can set off other Bomboars.
- New miniboss: Warpig. It throws Bomboars at you and is healed by their explosions.
- You can now turn around to face an enemy behind you.
- Defeated enemies and destroyed armors now crumble into pixels.
- Game version shown in the bottom-right corner.
- Changelog.

### Changed
- Units closer to the camera are now drawn in front of the ones behind them.
- Damage numbers always show above units.
- Enemies show how much they heal.

### Fixed
- Attack warnings were drawn over enemies.
- Bumping into a wall or an enemy turned the player around.

## [0.6.0] - 2026-10-31

### Added
- Charger enemy.

### Changed
- Player health bar shows hearts instead of a progress bar.

## [0.5.0] - 2026-10-16

### Added
- More info in skill definitions.
- `facing` parameter for units in encounters.

## [0.4.0] - 2026-10-14

### Added
- Skill handling.
- Critical hits and backstabs.

### Changed
- TempoBar replaced with the Tempometer for clearer visuals.
- Code comments translated from Polish to English.

### Fixed
- Movement speed depended on FPS.

## [0.3.0] - 2026-10-13

### Added
- Tempo mechanic and its bar.
- Damage numbers.
- Dummy enemy for testing.
- New font (Press Start 2P).

### Removed
- Debugging print.

## [0.2.0] - 2026-10-11

### Added
- Debug function that prints the A* grid with weights.

### Changed
- Enemies turn toward the player when moving horizontally.
- Battle manager reference set on instantiation instead of `get_parent()`.
- Files in the System folder sorted.

### Fixed
- Slime not walking to the player from some positions.

## [0.1.0] - 2026-10-09

### Added
- Initial project.
