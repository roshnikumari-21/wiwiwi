# wiwiwi — Production Plan (v1)

**Game:** wiwiwi · **Studio:** digicraft · **Engine:** Godot 4.7.2 (GDScript) · **Platform:** Android (Google Play)
**Package ID:** `com.digicraft.wiwiwi` — cannot change after the first upload.

> Facts marked **⚠ Verify** can change (store rules, plugin versions). Re-check before acting.
> Colors, fonts and art style are decided during development, not in this document.

## Contents
1. [Scope](#1-scope)
2. [Platform and Tech](#2-platform-and-tech)
3. [Gameplay Rules](#3-gameplay-rules)
4. [Screens and Flow](#4-screens-and-flow)
5. [Assets by Type](#5-assets-by-type)
6. [Tech Architecture](#6-tech-architecture)
7. [Google Services (no backend)](#7-google-services-no-backend)
8. [Android Export](#8-android-export)
9. [Testing](#9-testing)
10. [Release on Google Play](#10-release-on-google-play)
11. [Milestones M0–M5](#11-milestones-m0m5)
12. [Risks and Open Questions](#12-risks-and-open-questions)

---

## 1. Scope
- **v1:** 2 worlds × 10 levels. World 3 is a post-launch update.
- **World 1 — Meadow** (concept art): countryside, cottages, windmill. Teaches everything: run/jump, coins, milk, slimes, spikes, pits, moving platforms, checkpoints. Ends with the owner reunion.
- **World 2 — Sunset Town** (teased on the concept level map): rooftops at sunset, same rules plus one new enemy and one new hazard (e.g. crumbling tiles), harder levels; ends with the final "home" reunion.
- **Focus rule (29 Oct 2026):** build and polish **World 1 completely first**; World 2 starts only after World 1 is done properly.
- **Carried over from the prototype:** gentle energy + milk, owner reunion at the end of each world, stompable slimes, moving platforms.
- **New:** 3 hearts per level, checkpoints, 3-star rating, level select, settings, Play Games.
- **Not in v1:** coin shop, real-money purchases, ads, World 3, Hindi.
- **Prototype** (`cozy-cat-platformer`) is reference only. v1 is built fresh in `C:\Godot\Projects\wiwiwi`.
- **Design references:** level select + star reveal (Angry Birds), one-thumb controls + coin loop (Hill Climb Racing), themed worlds + hidden collectibles + checkpoints (Lep's World). Structure only, nothing copied.

## 2. Platform and Tech
| Item | Decision |
|---|---|
| Store | Google Play — **AAB** for upload, **APK** for testing |
| Target API | 36 (Play requirement since 31 Aug 2026). Godot 4.7 default — confirmed in our first APK. |
| Min Android | 7.0 (API 24, Godot default) |
| Orientation | Landscape only (Sensor Landscape) |
| Resolution | Base 1920×1080, stretch `canvas_items`, aspect `expand` |
| Screen shapes | Wider phones show more world sideways; tablets show more above/below. All UI inside a **SafeArea** container (notches, edge-to-edge). |
| Renderer | Compatibility (widest low-end support), target 60 FPS |
| Input | Touch only: left, right, jump, pause |
| Text | All strings through `tr()` + CSV, ready for more languages |

## 3. Gameplay Rules
- **Controls feel:** acceleration/deceleration, variable jump height, coyote time, jump buffer. First M1 values (in `player.gd`, tunable in the Inspector): run 520 px/s reached in 0.08 s · full jump ≈ 300 px (0.42 s to apex, faster fall) · tap = short hop ≈ 140 px · coyote 0.12 s · buffer 0.12 s. Cat ≈ 150 px tall on screen.
- **Failing:** spikes, pits, enemy side-hits cost 1 heart → respawn at last checkpoint (blink on respawn). 0 hearts → Level Failed card → "Try again" restarts the level with fresh hearts, coins and flags.
- **Checkpoint:** paw flag; first touch raises it and moves the respawn point there. **Goal (changed 30 Oct 2026):** the girl waits at the end of **every** level (no cat bed). She waits with clasped hands and bounces when the cat comes near; reaching her, she kneels down (crouch → kneel reaching → arms wide), the cat walks in, and they hug (3-frame loop) while hearts float up, then the result card with stars. The world-end reunion (level 10) stays as a bigger story moment.
- **Energy:** drains slowly while moving (full tank = 35 s of moving, `Player.energy_seconds`); milk refills it to full. At 0 the cat runs at 65 % speed with slower legs and yawns (sleepy idle) when standing: never a fail (a tired cat still clears the widest gaps; tested). The cat only drinks when not already full, so a bowl is not wasted. Each level sets `start_energy` (1-1 starts at 40 % to teach milk). HUD: milk icon + bar, orange below 25 %.
- **Stars:** ★ reach the goal · ★★ collect ≥ 80% of coins · ★★★ find the hidden Golden Yarn.
- **Levels:** 1–3 teach, 4–7 combine, 8–9 challenge, 10 finale + owner reunion. 60–150 s each.
- **Enemies:** World 1 slime; World 2 one new enemy + one new hazard.
- **Level data:** each level = a scene + a small `LevelData` resource (`data/levels/<id>.tres`: id, world, index, scene path, hint). `data/levels/level_catalog.tres` lists them in order; menus and unlocks read only from it. Regenerate with `tools/make_level_data.gd` after adding a level.
- **Level building = ground strips, not TileMap (decided 30 Oct 2026):** the World 1 art is a strip kit (left edge, repeating middle, right edge, thin floating piece) with no corners/slopes, so levels are made of resizable ground pieces. M1 uses grey `GreyboxBlock`s; in M2 the same pieces get the art skin, so greybox levels need no rebuild.
- **Save:** local versioned `user://save.json` (progress, coins, stats) with safe writes and migrations; `user://settings.cfg` for device settings. The save already has `wallet` and `cosmetics` fields so a shop needs no migration later.

## 4. Screens and Flow
```mermaid
flowchart TD
    A[Boot splash] --> B[Studio logo] --> C[Loading]
    C --> D{Play Games auto sign-in}
    D --> E[Main Menu]
    E --> F[World Select] --> G[Level Select]
    G --> H[Pre-level hint] --> I[Gameplay + HUD]
    G --> I
    I <--> J[Pause]
    J --> G
    I --> K[Level Complete]
    I --> L[Level Failed]
    K --> H
    K --> G
    L --> I
    L --> G
    I -->|level 10| M[Owner reunion] --> K
    K -->|after 2-10| N[Ending + Credits] --> E
    E --> O[Settings]
    E --> P[Leaderboards]
    E --> Q[Achievements]
    E --> R[Credits]
```
| Screen | Owner scene |
|---|---|
| Logo, Loading | `ui/screens/logo_screen.tscn`, `loading_screen.tscn` |
| Main Menu | `ui/screens/main_menu.tscn` |
| World Select, Level Select | `ui/screens/world_select.tscn`, `level_select.tscn` |
| Pre-level hint | `ui/screens/level_intro.tscn` |
| HUD (hearts, coins, yarn, energy, pause, touch controls) | `ui/hud/hud.tscn` |
| Pause, Level Complete, Level Failed | `ui/screens/pause_menu.tscn`, `level_complete.tscn`, `level_failed.tscn` |
| Settings (music, sound, control size/opacity, screen shake, language, Play Games, reset progress) | `ui/screens/settings.tscn` |
| Credits | `ui/screens/credits.tscn` |
| Owner reunion | `scenes/objects/owner/owner.tscn` |

**Android Back button:** every screen handles it (gameplay → pause, menus → previous screen, main menu → "leave?" dialog). No Quit button on Android.

## 5. Assets by Type
Sources: **Self** = we draw/record · **CC0** = Kenney packs as a base, restyled · **OFL** = open fonts · **AI** = ElevenLabs (⚠ commercial rights depend on plan).
P0 = needed for the vertical slice (M2) · P1 = needed for launch · P2 = nice to have.

| Type | Items | Source | Priority |
|---|---|---|---|
| Cat animations | idle, run, jump, fall, land, hurt (P0); collect, sleepy, win (P1) — sprite sheets for AnimatedSprite2D | Self | P0/P1 |
| Owner | idle, wave, hug (cutscene via AnimationPlayer) | Self | P1 |
| Enemies | W1 enemy (P0), W2 enemy (P1) | Self | P0/P1 |
| Ground kit | 1 per world: left edge, repeating middle, right edge, floating piece (ground strips, see §3) | Self (ChatGPT) | P0/P1 |
| Backgrounds | 3–4 parallax layers per world (Parallax2D) | CC0 base + Self | P0/P1 |
| Objects | coin, golden yarn, milk bowl, checkpoint flag, goal girl, spikes, platforms (one-way, moving, crumbling), decorations | Self / CC0 | P0/P1 |
| FX | sparkle, dust, confetti (CPUParticles2D textures) | Self | P0/P1 |
| UI | 9-slice buttons and panels, icon set, star icons, touch-control art, world cards | Self / CC0 | P0 |
| Fonts | 1 display + 1 UI font, open license, embedded with license file | OFL | P0 |
| Music | menu theme, 1 loop per world | AI / composer | P0/P1 |
| SFX | player, world, UI sounds | AI / CC0 / generated | P0 |
| Store assets | 512 icon, adaptive icon layers, feature graphic, screenshots, boot splash | Self | P1 |

**Folders:** `assets/art/{characters,enemies,objects,tiles,backgrounds,ui,fx}`, `assets/audio/{music,sfx}`, `assets/fonts` (+ `licenses/`), `data/`, `scenes/`, `ui/`, `autoload/`, `localization/`.
**Naming:** `snake_case` files, `PascalCase` nodes, prefixes `bg_`, `tiles_`, `fx_`, `ui_`, `mus_`, `sfx_`. No spaces or dates in names.

### 5.1 Concept art (`assets/raw_assets_idea/`, added 29 Oct 2026)
26 concept images define the **art direction**: chibi kawaii, hand-drawn look, warm brown outlines, soft countryside (cottage, windmill, meadow). They are the **reference and source** for game art, never used directly in the game.
- **Folder rules:** stays untouched as the master copy. Excluded from Godot (`.gdignore`, so ~40 MB never ships) and from Git (`.gitignore`; kept locally only, by decision 29 Oct 2026).
- **Source and rights:** generated with **ChatGPT** from our own prompts; per OpenAI's terms the output belongs to us (⚠ re-check their terms before launch and keep a note). New/missing art is made the same way so the style stays consistent.
- **Decisions:** the owner girl wears the **red pinafore dress** (pose sheet); the denim outfit in the banner is reference only. Settings screen: **toggles only** (music, sound) — no volume sliders, no vibration for now.
- **Pipeline (scripted, repeatable):** remove the white background → slice each sheet into single pieces → align animation frames to one baseline and cell size → export clean PNGs to `assets/art/...` → build SpriteFrames / 9-slice styles / atlases. Re-running the script after an art change updates the game.

| Concept sheet | Becomes in game | Work needed |
|---|---|---|
| Kitten animation + pose sheets | Cat: idle (3), walk (6), jump (2), hurt, cheer (2) frames; expressions for UI | Background removal, frame alignment; missing: fall, land, sleepy |
| Girl hugging animation sheet | Owner at the goal: wait (clasped hands), crouch, kneel reaching, kneel arms wide | Cut (`assets/art/characters/girl/`), aligned on her front shoe so she stays planted |
| Three-frame cat hug sheet | 3 hug frames (girl + kitten) | Cut, scaled to the kneel sheet's size (509/664) and auto-aligned on the dress/legs so the loop doesn't jiggle. (Older girl pose sheet + first hug sheet: replaced, not used) |
| Slime sheet | Slime walk (3) + squish; orange variant = World 2 or harder slime | Cut + align |
| Platformer asset sheet | Spikes, **checkpoint flag** (off/on), **cat bed = level goal**, floating island, signpost | Cut |
| Effects sheet | Dust, coin sparkle, star burst, heart break, checkpoint activation, confetti (5 frames each) | Cut into one-shot animations |
| Icon sheets | Coin spin (5 frames), milk bowl full/empty, heart full/empty, star full/empty, all menu icons | Cut into a UI atlas |
| UI asset sheet + control buttons | Pill buttons (4 colours × 3 states), round buttons, cream panel, wooden title sign, ribbon; touch controls ◀ ▶ 🐾 (normal/pressed) | Cut + 9-slice margins; text is added in Godot (translatable) |
| Meadow tileset + "Meadow Platform Tile Set" | World 1 ground strip skin (edges + repeating middle) and floating pieces | Check the middle piece repeats seamlessly; cut edges |
| Props sheets | Decorations: bushes, mushrooms, rocks, fences, logs, stumps, flowers | Cut |
| Countryside panorama | World 1 far background | Single flat layer, too small for scrolling → needs separate wide parallax layers |
| Screen mockups (loading, menu, level map, gameplay, pause, try again, level complete, settings) | **Layout reference** for each screen | Rebuilt in Godot from the cut pieces |
| App icons + banner | Play Store icon, adaptive icon, feature graphic (banner fits 1024×500) | Adaptive icon needs separate foreground/background layers |

**Still missing (create with the same tool/style):** Golden Yarn Ball · cat fall/land/sleepy frames · moving + one-way platform pieces · seamless World 1 tiles · layered wide backgrounds · HUD frames (hearts bar, coin counter, energy bar) · level-map node set (number, stars, lock) · all World 2 art (sunset town tiles, background, enemy, crumbling tile).

## 6. Tech Architecture
| Autoload | Job |
|---|---|
| `Events` | Global signal bus (coins, hearts, level results, achievement progress) |
| `GameState` | Current level, running attempt, level catalog, unlocks |
| `SaveManager` | Local save + settings, versions, migrations, cloud merge |
| `AudioManager` | Music crossfade, SFX pool, buses (Master → Music / SFX / UI) |
| `SceneTransition` | Fades between scenes, async loading |
| `PlayServices` | Wrapper for Play Games; does nothing on PC or when signed out |
| `Economy` *(future slot)* | Wallet + coin shop; hidden behind a feature flag in v1 |

- **Signals:** objects talk to parents locally; anything global goes through `Events`. Achievements are data-driven and tracked by one listener.
- **Levels:** `scenes/levels/level_base.tscn` + `level.gd` (Terrain, Objects, PlayerSpawn, Player + Camera, HUD with touch controls). The camera limits fit the terrain automatically; falling below it is a pit. Each level **inherits** the base and only adds terrain and objects (e.g. `scenes/levels/w1/level_w1_01.tscn`).
- **Performance:** texture atlases; lossless for UI/characters, VRAM-compressed (ETC2/ASTC) for large backgrounds; CPUParticles2D only, capped; enemies off-screen are disabled; one world's assets loaded at a time; AAB target < 80 MB.

## 7. Google Services (no backend)
**We run no backend of our own:** no servers, no database, no user accounts. Progress lives on the device. Everything online uses Google Play's prebuilt services.

### 7.1 Google Play Games Services — v1
- **What it's for:** sign-in, achievements, leaderboards, cloud save. **Not for payments.**
- **Sign-in:** automatic at launch (PGS v2); a manual "Sign in" button only if it fails or the player declines. The game works fully when signed out.
- **v1:** sign-in, ~12 achievements, 2 leaderboards. **v1.1:** cloud save (Saved Games/snapshots) using our existing save file.
- **Plugin:** `godot-play-game-services` v3.4.0 (github.com/godot-sdk-integrations, MIT). **Verified on Godot 4.7.2 on a real phone (M0).** Needs a Gradle build and a Play Games game ID in the export preset.
- **Setup:** create the app in Play Console → upload a build to internal testing → create the Play Games project → add credentials (SHA-1 of signing keys) → create achievements/leaderboards → add testers → put the game ID in export settings → publish with the release.
- **Status:** Play Games project created, linked to Google Cloud project **"wiwiwi"**, game ID **`254276654194`** (in both export presets). Credentials, testers and the real sign-in test happen in **M2**, after the first Internal testing upload.

### 7.2 Google Play Billing — future slot (not in v1)
- **What it's for:** real-money purchases (e.g. cosmetic packs) and subscriptions. **Not used in v1.**
- **Kept ready by:** the `Economy` autoload and save fields. A coin shop using only earned coins needs no Billing at all.
- **When added:** Google Play Billing Library via a Godot plugin (⚠ choose and verify the maintained plugin at that time); purchases are verified by Google Play, still no backend of our own. Adds Play Console products and a Data safety update.

## 8. Android Export
- [x] Godot 4.7.2 export templates · JDK 17 · Android SDK (platform-tools, build-tools 35.0.1, platforms 35 + 36, command-line tools, CMake 3.10.2, NDK r28b)
- [x] Export preset: package, version code/name, arm64 + armv7, immersive, landscape
- [x] Gradle build on (needed for plugins and AAB)
- [x] Release (upload) keystore `C:\Godot\Keys\wiwiwi-upload.keystore`, alias `upload`, valid to 2054; password only in Godot's ignored `export_credentials.cfg` (back up the file in 2 places)
- Certificate SHA-1 (public, for Play Games credentials): upload `3A:5B:4F:6F:9C:87:32:A5:99:D1:B2:3A:B7:A0:06:88:2B:F6:E4:49` · Godot debug `76:EA:46:81:AC:A0:5C:A5:6A:D6:A1:7E:D3:DA:E8:64:8F:E3:12:08` · app signing key: from Play Console after the first upload
- [x] Signed release AAB builds (`Android Release (AAB)` preset, ~53 MB)
- [ ] Play App Signing enrolled on first upload
- [ ] Debug build adds x86_64 only for the emulator; release stays ARM

## 9. Testing
- **Devices:** **Samsung Galaxy M11** (Android 12, 720×1560, punch-hole camera, Adreno 506) = our real low-end test phone, connected by wireless debugging. Android Emulator for other shapes (20:9, tablet). Play Console **pre-launch report** and **closed-test testers' phones** before release.
- **Emulator limits:** FPS is not realistic (uses the laptop GPU), and the mouse is one finger only. Performance and multi-touch are checked on the M11.
- **Each milestone:** feel test with 3–5 players, level checks (completable, no soft-locks), save tests (kill app mid-save, migrations), interruption tests (home button, screen off → auto-pause), Play Games signed in/out/offline, 10-min performance run on the slowest device.
- **Before release:** Play Console pre-launch report.

## 10. Release on Google Play
- **Account:** existing developer account **"DigiCraft Innovation"** (also publishes StoreMitr, `com.digicraft.storemitr`), owned by the co-founder. **The developer has Play Console access (granted 29 Oct 2026)** and uploads builds directly. The keystore and its password stay with the developer.
- **Official website:** **https://wiwiwi.digicraft.one/** — pages: `/privacy` (privacy policy, used in Play Console), `/terms`, `/support`, `/delete-data`. Any change to how the game handles data (cloud save, purchases, new SDKs) must be reflected in `/privacy` and the Data safety form in the same release.
- [x] App **wiwiwi** created in Play Console (Game, Free)
- [x] Privacy policy URL set: https://wiwiwi.digicraft.one/privacy (required even with no data collected)
- **Decisions:** App access = **"No restricted access"** (sign-in optional, no purchases; revisit if paid content is added). Store category = **Adventure** (recommended), with tags such as Platformer, Casual, Cute, Single player, Offline.
- [ ] Internal testing release (first upload claims the package and enrolls Play App Signing)
- [ ] Data safety form (we collect nothing ourselves; include what the Play Games SDK does)
- [ ] Content rating, target audience (⚠ under-13 → Families policy), ads: none
- [ ] Store listing: texts, icon, feature graphic, screenshots
- [ ] **Closed test: ≥ 12 testers opted in for 14 continuous days** — only if the account is a *personal* account created after Nov 2023 (⚠ check account type in Settings → Developer account; organization accounts are exempt), then apply for production access
- [ ] Staged rollout 20% → 100%; watch crashes/ANRs for 2 weeks

## 11. Milestones M0–M5
Estimates are combined focused hours. At **[X] h/week**: weeks = hours ÷ X (≈ 22 weeks at 20 h/week).

### M0 — Setup and export test (≈ 30 h) — ✅ closed 29 Oct 2026
Decision: build the game first; store upload and Play Games sign-in test move to M2 (when there is something to test).
- [x] Fresh project + local Git repo
- [x] GitHub (30 Oct 2026): private repo `roshnikumari-21/wiwiwi` (the renamed prototype repo). `main` = this game; the old prototype is kept on the `prototype` branch
- [x] Project settings, folders, empty autoloads, translation CSV
- [x] Android toolchain + debug APK (target SDK 36, landscape, no permissions)
- [x] SafeArea container + device-check screen
- [x] APK runs on a real phone (Galaxy M11): 60 FPS, landscape lock, punch-hole detected and avoided, fade works
- [x] Multi-touch check on the M11 (3 fingers detected)
- [x] Game name: **wiwiwi**
- [x] Studio name **digicraft** → package ID `com.digicraft.wiwiwi` (not used on Google Play as of 29 Oct 2026)
- [x] Release keystore (see §8) · Play Console app created in the DigiCraft Innovation account
- [x] Official website live: https://wiwiwi.digicraft.one/ (privacy, terms, support, data deletion)
- [x] Gradle build + Play Games plugin v3.4.0 (MIT) loads on the phone with Godot 4.7.2; `PlayServices` wrapper reports signed_out gracefully
- [x] Play Games project created (Cloud project "wiwiwi"); game ID `254276654194` in both export presets
- [x] First AAB export (real package ID, real game ID, signed with the upload key)
- [x] Project folder renamed to `C:\Godot\Projects\wiwiwi`
- Carried forward (not blocking M1): ElevenLabs commercial rights check · emulator check for 20:9 + tablet shapes (in M1 performance check)

### M1 — Prototype, greybox (≈ 70 h)
- [x] Concept art: `.gdignore` on `raw_assets_idea`; asset pipeline (`tools/art_pipeline/`: `cut_cat.py`, `cut_pieces.py`); 20 aligned cat frames → 8 animations (idle, walk, jump, fall, land, hurt, cheer, sleepy) + touch-button art
- [x] Player controller v2 + camera (look-ahead, vertical drag), greybox blocks, test room `dev/m1_movement_test.tscn` (current main scene); automated feel checks pass
- [x] Play-tested on the Galaxy M11 (30 Oct 2026): movement feel approved as is. Idle reworked: still pose from the new idle sheet + a blink made by pasting only the closed eyes onto the same frame (zero wobble), blinking every few seconds with an occasional double blink; breathing is a 1.2 % scale in code. Rule: never loop separately drawn AI frames for "still" poses. Air poses (30 Oct): a jump keeps the leap pose for the whole arc; legs fold only on touchdown ("land"); ledge drops without a jump use one steady "fall" frame (the folded L1 frame was removed)
- [x] `level_base` + `level.gd` (auto camera limits, pit respawn), `LevelData` + `LevelCatalog` + `tools/make_level_data.gd`, `GameState` (catalog, current level, `start_level`), greybox level 1-1 (main scene); tested on PC + phone
- [x] Level-end hug: girl at the goal `goal_girl.tscn` (waits → bounces → kneels down in 3 frames → cat walks in → 3-frame hug loop + hearts → result card); cat bed removed; `Player.walk_to()` for cutscenes; pipeline clears trapped white gaps (`hole_min_area`)
- [x] Hearts, checkpoints, respawn, coins, golden yarn, goal, stars: object scenes in `scenes/objects/` (coin, golden_yarn, checkpoint, goal_girl) using cut concept art; `Events` + `GameState` run the attempt; placeholder HUD (`ui/hud/hud.tscn`: hearts, coins x/y, yarn) + win/fail card; level 1-1 has 16 coins, 1 yarn, 1 flag, the girl; `dev/m1_rules_test.gd` passes (22 checks); runs on the M11
- [x] Energy + milk: `Player` energy (drain, tired speed, sleepy idle), `milk_bowl.tscn` (full → empty), HUD energy bar, 1 bowl in level 1-1; `dev/m1_energy_test.gd` passes (14 checks)
- [ ] Slime, spikes, pits, platforms
- [x] Touch controls in SafeArea (concept-art buttons, opacity/size ready for Settings)
- [ ] 3 greybox levels; playtest and tune; performance check (M11 + emulator 20:9/tablet)

### M2 — Vertical slice (≈ 110 h)
- [x] Art direction set by the concept art in `assets/raw_assets_idea/` (§5.1)
- [ ] Fonts chosen to match the concept lettering; Theme resource from the cut UI pieces
- [ ] Missing art created (§5.1 list); World 1 seamless tiles + layered background
- [ ] Final cat animations, World 1 tileset + parallax, core objects
- [ ] All screens + transitions + Back button
- [ ] SaveManager v1, AudioManager + core SFX, juice pass
- [ ] First Internal testing upload (claims the package, enrolls Play App Signing) → copy app-signing SHA-1
- [ ] Play Games credentials (app-signing + debug SHA-1) and testers → real sign-in on the phone
- [ ] Play Games: sign-in + 1 leaderboard + 2 achievements
- [ ] 3 polished World 1 levels; playtest

### M3 — Content (≈ 130 h)
- [ ] World 1 levels 4–10 + owner reunion
- [ ] World 2 tileset, parallax, enemy, hazard, levels 1–10
- [ ] Remaining animations, music, SFX
- [ ] All achievements + leaderboards (+ offline queue)
- [ ] `Economy` future slot (hidden)
- [ ] Level checks for all 20 levels

### M4 — Polish + closed test (≈ 60 h)
- [ ] Juice, settings (control size/opacity, screen shake), performance pass
- [ ] Bug bash, save + interruption tests, balance
- [ ] Real-device sign-off: pre-launch report + testers' phones (performance, multi-touch)
- [ ] Privacy policy + Data safety draft
- [ ] Start closed test (≥ 12 testers, 14 days) and fix feedback

### M5 — Release (≈ 35 h + review wait)
- [ ] Store assets and texts
- [ ] Content rating, target audience, Data safety
- [ ] Apply for production access; final AAB; staged rollout; monitor

## 12. Risks and Open Questions
| Risk | Mitigation |
|---|---|
| Play Games plugin breaks in a future Godot update | Proven on 4.7.2 (M0); pin Godot 4.7.x until launch |
| 14-day / 12-tester closed test (if the account is personal) | Check account type; if needed, recruit 15–20 testers early and start in M4 |
| Keystore loss | Play App Signing + 2 backups; a business backup with the co-founder (file and password via separate channels) |
| AI audio not licensed for commercial use | Check in M0; regenerate or replace |
| Only one real test phone (Galaxy M11) | Emulator for other shapes; Play pre-launch report + closed-test phones (M4) |
| Art bottleneck / scope creep | CC0 bases; new ideas go to a v1.1 list |
| Concept art not game-ready (no transparency, not on a grid, tiles not seamless, frames drift) | Scripted cleanup pipeline; regenerate missing/unsuitable pieces in the same style |
| Rights for AI-generated art (ChatGPT) | OpenAI terms assign output to us; re-check before launch and keep a record |

**Open:** hours per week · target audience (13+ or including kids) · ElevenLabs plan · who owns art vs code · Play Console account type (personal/organization).
