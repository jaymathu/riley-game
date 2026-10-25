# R.I.L.E.Y. — Really Impossible Landing Experiments, Yay!

A 3D physics arcade game for Android, built with **Godot 4 (GDScript)**. Riley, a six-year-old inventor,
blasts himself out of a homemade cannon and tries to chain trampoline, rooftop, spring and bumper
landings as far as possible. The camera is a 2.5D side view; all gameplay is real 3D physics locked
to one plane.

## Get the APK

Every push to `main` runs **Actions → Android build**. When it finishes, open the run and download the
**riley-debug-apk** artifact (a zip containing `riley-debug.apk`). On your phone, allow installs from
unknown sources for your browser/file manager and open the APK.

The same run also does a headless smoke test (plays automated runs in all four worlds) and uploads
`build-logs` (import, smoke and export logs).

### Signed release APK + Play Store AAB

Add these repository secrets (Settings → Secrets and variables → Actions):

| Secret | Value |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | `base64 -w0 release.keystore` |
| `ANDROID_KEYSTORE_ALIAS` | key alias |
| `ANDROID_KEYSTORE_PASSWORD` | keystore / key password |

The workflow then also uploads **riley-release** with `riley-release.apk` and `riley-release.aab`.
The AAB is built with Godot's Gradle template; its target SDK comes from the `target_sdk` workflow
input (default 36). Check the current Google Play requirement before submitting and change it if needed.
Version code = the workflow run number.

## Controls

| Phase | Touch | Keyboard (desktop testing) |
| --- | --- | --- |
| Aim | Tap once to lock power, tap again to lock angle and fire | Space |
| Flight | Hold left half = spin counter-clockwise, right half = clockwise (both = no spin) | A / D |
| Gadget | Round button bottom-right (bottom-left in left-handed mode) | W or G |
| Pause | Pause button, Android back, or leaving the app | Esc / P |

Land **feet first** (body roughly aligned with the surface) for Perfect/Good landings. Successive good
landings raise the combo multiplier (x1, x2, x3 … capped at x10); messy landings lower it; the ground ends it.

## What's in the game

- **Riley**: rigged 3D model (19 body bones + face-swap bones), 13 animation clips (idle, launch prep,
  launch, airborne, tuck, front/back tumble, panic flail, landing prep, perfect landing, awkward landing,
  cartoon crash, victory), 5 eye and 4 mouth expressions, articulated ragdoll for crashes.
- **Landing system**: orientation vs. surface normal, impact speed and spin decide Perfect / Good / Messy /
  Crash; each object defines its own response.
- **Interactive objects**: trampoline (deforming bed, bullseye bonus), bounce house, pool (dive out or
  splash), spring, mattress, rooftops (slide up and off), satellite dish (redirect), giant fan, moving
  truck, rubber duck, seesaw, giant tire, playground slide (kicker lip), rotating platform, conveyor,
  inflatable cushion, pinball bumper, wind tunnel, breakable ramp, wind gusts, low-gravity fields,
  rocket booster rings, thrusters, floating space pads.
- **Gadgets** (one per run, charges + cooldown, unlock by distance + coins, scale with Gadget Efficiency):
  Umbrella, Rocket Shoes, Giant Balloon, Propeller Hat, Plunger Gun, Emergency Mattress.
- **Four worlds** with their own objects and mechanics: Backyard Disaster, Neighborhood Mayhem,
  Amusement Park, Space Experiments (low gravity).
- **Procedural levels**: seeded generator; gaps bounded by each object's reachable distance, recovery
  surfaces every few objects, difficulty ramps with distance, coin arcs, world decor, cleanup behind.
- **Progression**: 7 upgrades, cosmetics (shirts, shoes, goggle lenses, headwear, launcher skins,
  trails — no gameplay effect), local records, top-10 runs, world unlocks.
- **Audio**: all effects, voice reactions and three music loops are original and synthesized
  (`tools/audio/make_audio.py`).

## Project layout

```
project.godot, export_presets.cfg     Godot project + Android presets (APK and Gradle AAB)
scenes/main.tscn                      entry scene (everything else is built from scripts)
scripts/autoload/                     Save (progress/settings), Audio, Assets
scripts/game/                         Game loop, Riley body/visual/ragdoll, gadgets, camera, level gen, FX
scripts/game/props/                   interactive objects
scripts/ui/                           HUD, menus, results, pause, settings
assets/                               glTF models, audio, fonts (OFL), icons, splash
tools/                                Blender/Python generators for every asset (ignored by Godot)
.github/workflows/android.yml         CI: import, smoke test, export, upload
```

## Regenerating assets

Requires Python 3.11 with the `bpy` wheel (Blender as a module) plus `numpy scipy soundfile pillow`.

```
python tools/blender/build_riley.py assets/characters/riley   # character, rig, animations
python tools/blender/build_props.py assets/props               # every prop / decor / gadget
python tools/audio/make_audio.py assets/audio                   # sound effects + music
python tools/branding/make_branding.py <renders> .              # icons + splash (renders via render_riley.py)
```

## Opening locally

Install Godot 4.5 (4.4+ should work), open `project.godot`, press Play. For Android export from the
editor: install export templates, set the Android SDK and debug keystore in Editor Settings, then
Project → Export → Android.

## Credits

Fonts: Lilita One and Nunito, SIL Open Font License (`assets/fonts/OFL-*.txt`). All other assets were
generated for this project.
