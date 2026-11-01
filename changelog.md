# Changelog

All notable changes to this project. One version per working day: every change made on the same day goes
into that day's version; the next day of work starts a new version. When starting a new version, also update
`config/version` in `project.godot` (Project Settings > Application > Config > Version): the game shows it on screen.

## [0.7.0] - 2026-11-01

### Added
- Wisp enemy: strikes one diagonal tile in front of itself (upper or lower, whichever the player is on) after a
  1-turn warning (`Battle/AI/Wisp/wisp.json`).
- Haunted Armor enemy: sweeps the 3 tiles in front of itself after a 1-turn warning
  (`Battle/AI/HauntedArmor/haunted_armor.json`). When it dies, a Wisp falls out onto a free neighbour tile and the
  empty armor (`knight-armor.png`) stays on its tile.
- Remains (`Battle/Entities/Remains/remains.gd`): the body a dead enemy leaves behind. It doesn't block movement,
  has its own HP and a health bar, and can be destroyed by attacks that hurt enemies.
- Enemy export group "Death": `death_spawn_id`, `leaves_remains`, `remains_hp`, `remains_texture`, `remains_modulate`.
- AI action `possess {turns, steps}`: walks to the nearest Remains and, after standing on it for `turns` turns,
  revives that enemy with full HP. Any Wisp can revive any armor.
- Encounter field `"remains"`: place empty bodies at the start of a battle.
- Tile pattern preset `wide_front` (`[[1, -1], [1, 0], [1, 1]]`).
- `Battle.spawn_enemy()`, `Battle.spawn_remains()`, `Battle.revive_remains()`: spawning enemies mid-battle.
- Test encounters `wisp_test.json` and `haunted_armor_test.json`.
- Game version shown in the bottom-right corner of every screen (autoload `VersionLabel`,
  `Global/VersionLabel/`). It reads `application/config/version` from `project.godot`.
- This changelog.
- Turning toward an enemy behind you: moving into an enemy you have your back to turns the player around
  instead. It costs as much as a move: enemies take their turn and Tempo decay is reset.

### Changed
- Units are depth-sorted by grid row (`z_index` set from `map_position`), so units closer to the camera draw over
  the ones behind them.
- Damage numbers moved to `z_index` 20 so they stay above all units.

### Fixed
- Warning tiles drew over enemies; they now lie on the floor below every unit.
- A blocked move no longer turns the player around for free (bumping into a wall or an enemy flipped facing).

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
