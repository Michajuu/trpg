# Changelog

All notable changes to this project. One version per working day: every change made on the same day goes
into that day's version; the next day of work starts a new version. When starting a new version, also update
`config/version` in `project.godot` (Project Settings > Application > Config > Version): the game shows it on screen.

## [0.8.0] - 2026-11-07

### Added
- Turn order bar at the top of the screen: the round number and every unit in the order they act. The one acting now is highlighted.
- Slime animations: it swells up before attacking and slams down when it hits.
- Exploration walking: move freely in 8 directions with the arrow keys or gamepad, with smooth starts and stops. Walls block your way. Try it on the new test level.
  The camera follows you but never shows what lies beyond the edge of the map; a map smaller than the screen stays centered.

### Changed
- Turns are now separate: you take one action, then the enemies act one after another.
- Tempo drains only during your turn, not while the enemies move. Act fast to keep it.
- Enemies move a bit slower and pause between actions, so each move is easier to follow.
- Enemies take a turn to react when you step into their reach before they start winding up an attack.

## [0.7.0] - 2026-11-01

### Added
- New enemy: Wisp.
- New enemy: Haunted Armor. When it falls, a Wisp escapes from it and its empty armor stays behind.
- Wisps can bring empty armors back to life. Destroy the armor to stop them.
- New enemy: Bomboar. It explodes when killed, and its explosions can set off other Bomboars.
- New miniboss: Warpig. It throws Bomboars at you and is healed by their explosions.
- You can now turn around to face an enemy behind you.
- Defeated enemies and destroyed armors now crumble into pixels.
- Boss health bar at the top of the screen during miniboss fights. Marks show at what HP the boss
  starts using a new attack, and flash when it does.
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
