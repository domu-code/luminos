# Lumine Attack v0.9.2: 13 Styles / 67 Submodes / Landing Ghost

Android / Desktop LÖVE 11.5 edition. This version continues the **v0.9.1 Unified VFX** game with all 13 first-level styles, the original v0.9 triangulation VFX systems, nine pixel tilesets and the smooth, scale-aware synthesiser.

## Navigation

1. Choose one of the **13 puzzle-game styles** from the factory screen.
2. A **second GAME MODE screen** appears, containing mode-specific rules and goals. Use D-pad or arrow keys, or tap a mode to launch it.
3. Choose a mode. **B / Back** returns to the game-style selection; **Y / O** opens Options.
4. When gameplay ends, your score is recorded in the top-ten leaderboard **for that exact game style and submode**. Successful 40-line Sprint records rank by fastest completion time, followed by score.
5. From Options > Presets > High Scores, navigate the base styles with Left/Right and their submodes with Up/Down; `V` toggles solo/VS records. Legacy pre-submode scores remain available as the `LEGACY SCORES` (submode index zero) page without mixing into new competitions.

**Touch:** Menus have individually selectable rows. The longer SHINE list scrolls with a vertical gesture. In falling-piece games, a translucent landing ghost appears at the resting position. The **HARD DROP** button is now on the right, directly beneath the rotation controls. HOLD and ZONE remain at the top as separate optional actions. For relative-touch mode, the right-side gesture area is shortened to leave a dedicated HARD DROP button.

**Options > TETRIS PIECES** now includes GHOST LANDING and GHOST OPACITY. Both are saved with all other numeric/boolean preset settings. Submode choices are saved per style, plus the active selection.

## Submodes by game style

| Style | Submodes |
|---|---|
| SHINE (Lumines-like) | Challenge, Time Attack 1/3/5 minutes, Mission 100, Rotation Trial, VS CPU, Chill Shine |
| LINK | Endless Link, Time Attack, Link Mission, Chain Trial, Zen Link |
| ATTACK (Panel de Pon-like) | Endless, Time Trial, Stage Clear, Swap Trial, VS CPU |
| BRIDGE | Bridge Survival, Time Trial, Bridge Mission, Zen Bridge |
| TETRIS | Marathon 150 lines, Sprint 40 lines, Ultra 3 minutes, Endless, Master |
| TETRIS SWEEP | Zone Marathon 150, Sprint 40, Ultra 3 minutes, Endless Sweep, Chill Scanner |
| PUYO | Endless, Chain Trial, Time Attack, 100 Clear Mission, Zen Puyo |
| PUZZLE FIGHTER | Arcade VS CPU, Endless Gems, Crash Rush, Time Attack, Training |
| BAKU BAKU | Arcade VS CPU, Endless Baku, Time Trial, Feed Mission, Practice |
| SLIDEFALL | Endless Triads, Time Attack, Cluster Rush, Chain Trial, Zen Slide |
| MIX LAB | Free Lab, Time Attack, Clear 120, Chain Trial, Zen Lab |
| ZONE GARDEN | Deep Chill, Zone Harvest, Time Garden, Long Zone, Endless Zone |
| CUSTOM | Free Play, Time Attack, Mission 100, Chain Trial, Zen Custom |

**Goals function in-game:** time-limited modes stop when the timer expires, Sprint/Marathon stop at the target line count, clear and chain goals stop when earned, Stage Clear requires reducing the starting stack, and move-limited trials end when out of actions. Marathon/Master accelerate falling gravity as lines are cleared. Timers pause when gameplay is paused. Some challenge modes temporarily override their respective gameplay parameters for that run; original preset values are preserved separately.

**Fidelity distinction:** The full authored puzzle campaigns, official level layouts, character stories, original audio/visual assets, and advanced special-rules such as full Puyo Fever are not recreated here. Modes named *Trial*, *Mission*, *Zen* and *Zone Garden* are original adaptations grounded in the existing engine. They are playable objectives rather than empty labels.

## Research references

- Tetris Effect: Connected beginner's guide: https://www.tetriseffect.game/beginners-community-guide/ (Marathon 150, Sprint 40, Ultra 3-minute).
- Tetris Effect: Connected: https://www.tetriseffect.game/ (Zone and Effect Modes).
- Lumines Remastered: https://luminesremastered.com/ (Challenge, Time Attack, Mission, Puzzle, Vs CPU).
- Tetris Attack modes: https://tetris.wiki/Tetris_Attack (Endless, Time Trial, Stage Clear, Puzzle, VS).
- Sega's Puyo Puyo Tetris challenge mode chart: https://puyo.sega.com/tetris/rule/challenge/index.html (Endless Puyo, Endless Fever, Marathon, Sprint, Ultra).
- Official Puzzle Fighter manual: https://secure.cdn.us.playstation.com/manuals/classic/games/super-puzzle-fighter-ii-turbo-manual-en.pdf (Arcade and Versus).
- Baku Baku Game Gear manual: https://manuals.plus/m/b18b73c381719fb6949a400b3aceb6b847274ad95903df0e60a4f6f40106af3d (solo CPU and 2P/Practice modes).

## Implementation and validation

- New `source/submodes.lua` describes **67** options across the 13 styles.
- `source/main.lua` implements the second selection UI state, touch handling, per-run progress and end conditions.
- `source/render.lua` implements the second selection screen, clear objectives, configurable landing ghosts, relocated hard-drop controls and per-submode score viewer.
- `source/records.lua` isolates top tens by base game + submode, preserves existing legacy tables, and includes completion time for Sprint.
- `source/versus.lua` uses the falling-piece CPU engine when the selected game is a falling game.
- `source/engine.lua` now reports successful cursor actions to support limited-move challenges.
- Run `texlua test_syntax.lua` and `texlua test_suite.lua` from the source package root. Tests simulate Android-style input and rendering without audio hardware.

**Android builds are test builds**, intended for on-device feedback. The dedicated build uses its own Android package ID, so it does not replace the user's installed v0.9.1 and other experimental editions. On-device touch and real audio hardware performance have not been exhaustively tested.