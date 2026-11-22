# Lumine Attack v0.7.3

Puzzle action game for Android (APK) and LÖVE 11.5 (desktop/PortMaster handhelds). Developed from Chromatic Tide v0.6.

## Gameplay

Four selectable rulesets share a rising microcell field:

- **SHINE**: rotating 2x2 cursor; monochrome 2x2 microcell squares become eligible; downwards sweep clears them.
- **LINK**: rotating 2x2 cursor; orthogonally connected groups of the configured size clear at the sweep. Optional independent X/O/+ icon connections and linked resonance.
- **ATTACK**: horizontal 2-cell swap cursor; 3+ straight lines clear after a configurable delay, with gravity.
- **BRIDGE**: rotating 2x2 cursor; a connected colour component must span from the left to right wall; sweep clears the entire component.

Microcells rise **one row at a time**, are interactive as soon as they enter fully, and top-out checks every row. Rising rows never become scoring-authorised on their own. Row generation samples different 2x2 pattern types, colour pairs and candidates; it penalises checkerboard regularity.

## Touch controls (exclusive)

On `OPTIONS > CONTROLS`, choose one option:

- `DPAD + BUTTONS`: four **equal 42x42** direction buttons in a proper D-pad, large CCW/CW rotation buttons and BOOST.
- `RELATIVE TOUCH` (default): drag your left-side finger to move the cursor a relative number of microcells; upper-right rotates clockwise, lower-right anticlockwise; a separate bottom-right BOOST button. No D-pad is shown in this mode.

Mouse control can independently be `OFF`, `DIRECT`, or `RELATIVE`. Direct mouse maps pointer location to the cursor and click rotates; relative mouse moves cursor by drag; right mouse rotates counterclockwise; middle mouse boosts. A USB/OTG gamepad, when supported by Android and LÖVE's joystick API, uses D-pad/left stick movement, A/B rotate, X or trigger boost, Y pause, shoulders rotate, Start confirm. Generic USB joystick fallback is provided. Touch-generated mouse duplicates are ignored.

**On-phone options navigation:** Swipe the option list vertically to scroll. Tap left/right half of a row to decrease/increase its value. Tap the top-left/top-right of the options header for previous/next page. Tap bottom-left BACK or bottom-right APPLY. With a gamepad use up/down, left/right, shoulder buttons, A/B.

## USB keyboard controls

USB/OTG and Bluetooth keyboards work on Android when Android and LÖVE expose ordinary key events. On the CONTROLS page, USB KEYBOARD can be enabled or disabled, the movement layout can be WASD + arrows, arrows only, or IJKL + arrows, and automatic key repeat can be changed. Z / X rotate, Space boosts, P pauses, O opens options, and Enter confirms. Physical keyboard input remains independent of the mutually exclusive touch overlay modes. Escape and O remain recovery keys for menus even with keyboard gameplay disabled.

## Controls and options

The menus include 17 option pages:

- FIELD, MATCH, POWERS, SURGE + GARBAGE, CURSES
- GRAPHICS, PALETTE, SOUND, CONTROLS, BOOST, VERSUS, PRESETS, EXTRAS
- SHINE RULES, LINK RULES, ATTACK RULES, BRIDGE RULES

Each matching mode has its own clear delay, chain window, row speed, gravity interval, and score scale. Shine/Link/Bridge additionally configure sweep speed. Boost speed and scoring risk reward are independently adjustable; accelerated rise is dangerous but rewards players who can sustain it.

Specials always carry an ordinary colour and activate only when cleared. Separate occurrence probabilities are available for small/medium/large bombs, H/V beams, freeze, painter, shifter, surge, three sizes of offensive garbage and cursed Self-Garbage. Self-Garbage always affects the active board, even in solo mode; it cannot be cancelled by offensive scoring. Matching next to any connected garbage structure clears its entire orthogonally connected mass. Garbage itself can be moved by swap/rotation.

VS CPU uses identical board rules for both sides; clears and combos send attacks with configurable CPU strength, garbage strength and delay. Eight saved preset slots each contain a full copy of the rules and cosmetic settings. Each slot has ten scores for every mode and solo/VS category. Saving over a slot resets its high-score table, preventing scores from mismatched rules from mixing. Unsaved custom settings are not assigned to a preset scoreboard until saved.

The display can be `NEON`, `8-BIT`, `4-BIT`, or `1-BIT` (dithered), with independent bloom/glow, particles, flash, shake, trails, hue, brightness, saturation, contrast, automatic cycling, 24 palette themes and adaptive quality. Low graphics values can be used for modest Android hardware.

## Build

The GitHub Actions workflow under `.github/workflows/android-apk.yml` packages `source/` into a `.love` archive and builds an Android debug APK with love-actions-android v2 and LÖVE 11.5a. The current display name is **Lumine Attack**. The existing Android application ID `com.chromatictide.game` and LÖVE filesystem identity `chromatic_tide` are deliberately retained to allow installing over the previous version and preserving saved settings/high scores.

For desktop, run the files under `source/` as a LÖVE game or open `LumineAttack_v0_7_3.love` with LÖVE 11.5. Avoid opening individual Lua files.

## Notes

The original Processing/OpenGL version and this LÖVE port use different renderers. Controller mappings, Android touch behaviour, and GPU support should still be verified on physical devices. Headless Lua logic and mocked LÖVE rendering tests are provided separately; those do not replace on-device testing.