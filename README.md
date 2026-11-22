# LUMINE ATTACK v0.8.0 / PUZZLE GAME MAKER

A modular puzzle-action game for LÖVE 11.5 on Android, PortMaster and desktop.

## Games

**Factory games (11):** SHINE (sweepable 2x2 squares), LINK (orthogonal matching), ATTACK (Panel de Pon-style swap and match-three), BRIDGE (coloured path spanning the well), TETRIS (falling tetrominoes and completed lines), TETRIS SWEEP (completed rows held until the scanner passes), PUYO (falling colour pairs), PUZZLE FIGHTER (colour gems and crash gems), BAKU BAKU (animal/food), SLIDEFALL (falling and sliding triads), and MIX LAB (choose falling piece family and clear rule).

**CUSTOM (12th entry):** choose any of the eleven underlying game families, change gameplay settings across all option pages, and save a named game in a user preset slot. If you want to mix tetrominoes, pairs or triads with line, sweep, colour group, crash-gem or animal/food clearing, use MIX LAB as the Custom base game and configure `LAB PIECE SHAPE` and `LAB CLEAR RULE` on the FALLING + LAB page.

## Game library and presets

- On the game-select screen, press **Tab** (or touch the heading) to switch between **Factory Games** and **My Presets**. Each of 16 user slots appears as a selectable game entry.
- Select CUSTOM on the Factory page and use **Options** to edit it. The **CUSTOM DESIGN** page selects a starting engine; all other gameplay, timing, special-block, visual, audio and control pages remain editable.
- Open **PRESETS** in Options, select a slot, then **SAVE PRESET**. The slot appears in My Presets. Choose **RENAME PRESET** to type an 18-character name using a physical keyboard or the Android software keyboard. **LOAD PRESET** restores its precise settings.
- Every saved user preset maintains its own separate top-10 score lists for SOLO and VS, per mode. Factory scores are tracked separately by mode; unsaved Custom games deliberately do not enter a leaderboard.
- Overwriting a slot with different game rules resets *that slot's* scores, to avoid comparing runs with incompatible rules. Re-saving identical rules and renaming the preset preserve its high scores.
- Records and settings are saved in the LÖVE application data directory. Back them up before uninstalling an APK or changing app signatures.

## Falling pieces and Zone

- Adjustable 0–3 hold slots and 0–5 look-ahead previews.
- Optional wall kicks, T-spin recognition, unlimited rotation lock reset, gravity interval and lock delay.
- Adjustable Zone charge, duration, release and gravity; an accumulating-line sweep option for extra-large line clears.
- Mode-specific clear delays, connected-group sizes, and special-block spawn chances.
- Optional CPU VS, garbage attacks and multi-block chain effects.

## Controls

- **Move:** D-pad, keyboard arrows, WASD or IJKL. Falling pieces: up rotates, left/right moves, down accelerates.
- **Rotate:** X/Z (A/B gamepad). **Hard drop:** Space (falling modes). **Hold:** V. **Change selected hold slot:** G. **Zone:** F.
- **Options:** O. **Pause:** P or Escape. **Mode select:** B from gameplay. **Game library tab:** Tab or gamepad shoulders while selecting a mode.
- Touch: **DPAD+BUTTONS** or **RELATIVE TOUCH** (exclusive), selected on CONTROLS page. Physical keyboard and gamepad input remain independently configurable.
- Android: USB-OTG keyboards and supported USB gamepads use LÖVE's standard input events. Exact mappings may vary with the controller/Android device.

## Graphics and performance

Choose NEON, 8-BIT, 4-BIT or 1-BIT. Set palette, saturation, brightness and hue, bloom strength, glow, explosions, particle count, trails, flashes, screen shake, background detail and adaptive quality independently. 14 designed palettes are included.

## Building

The `.github/workflows/android-apk.yml` workflow packages every required Lua source file into one LÖVE archive and builds a debug Android APK via `love-actions-android@v2`, using LÖVE 11.5a. Upload the whole project to GitHub and run the workflow; artifacts are under the successful run. The bundle ID `com.chromatictide.game` is kept for installation compatibility with v0.7.x.

For PortMaster, install the corresponding PortMaster ZIP; it uses the PortMaster LÖVE 11.5 shared runtime. No compilation is needed for that package.

## Validation and limits

Source syntax, 12-mode dispatch, headless falling-piece stress tests, saved-preset/record persistence tests, and a mocked LÖVE rendering/input run were checked. These are **not** substitutes for testing an installed APK or the game's visuals/sound on physical hardware. Gameplay mechanics are original interpretations and combinations, not exact reproductions of commercial games.