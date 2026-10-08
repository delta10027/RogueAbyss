\# ROGUE ABYSS — BUILD STATUS



\## Living implementation checklist



> Claude must read this file before beginning implementation.

>

> Update this file after meaningful development work.

>

> Never mark a feature complete merely because code exists. Mark it complete only after it has been tested.



\---



\# STATUS LEGEND



```text

\[ ] Not started

\[\~] In progress

\[x] Implemented and tested

\[!] Blocked

\[?] Needs playtesting

```



\---



\# 1. PROJECT FOUNDATION



\* \[ ] Roblox project created

\* \[ ] Repository/project structure established

\* \[ ] ReplicatedStorage structure created

\* \[ ] ServerScriptService structure created

\* \[ ] StarterPlayer structure created

\* \[ ] StarterGui structure created

\* \[ ] Shared module conventions established

\* \[ ] Server/client boundary established

\* \[ ] RemoteEvent structure established

\* \[ ] Debug logging convention established



\---



\# 2. PLAYER FOUNDATION



\* \[ ] Player movement

\* \[ ] Camera

\* \[ ] Player collision

\* \[ ] Basic interaction

\* \[ ] Player state

\* \[ ] Health

\* \[ ] Death/failure

\* \[ ] Restart

\* \[ ] Keyboard/mouse controls

\* \[ ] Controller controls

\* \[ ] Mobile controls



\---



\# 3. FIRST ROOM



\* \[ ] Safe starting room

\* \[ ] Starting camera framing

\* \[ ] Basic lighting

\* \[ ] Basic atmosphere

\* \[ ] First environmental mystery

\* \[ ] First interaction

\* \[ ] First exit



The starting room must immediately establish:



> "This is not a normal Roblox game."



\---



\# 4. FIRST TEN MINUTES



This section is the highest-priority playtest checklist.



\## 0–1 MINUTES



\* \[ ] Player understands movement

\* \[ ] Player understands basic interaction

\* \[ ] Player notices something strange

\* \[ ] No large tutorial wall

\* \[ ] No excessive UI

\* \[ ] First environment feels atmospheric



\## 1–3 MINUTES



\* \[ ] Player discovers first meaningful environmental clue

\* \[ ] Player learns that observation matters

\* \[ ] Player makes their first exploration decision



\## 3–5 MINUTES



\* \[ ] Player encounters meaningful risk

\* \[ ] Player has at least two reasonable choices

\* \[ ] Resource decision exists

\* \[ ] Player understands consequence



\## 5–7 MINUTES



\* \[ ] Two systems interact

\* \[ ] Player can exploit an environmental rule

\* \[ ] Player feels responsible for the outcome



\## 7–10 MINUTES



\* \[ ] Memorable event occurs

\* \[ ] Player discovers something unusual

\* \[ ] Player reaches deeper dungeon

\* \[ ] New mystery is introduced

\* \[ ] Player has a natural reason to continue



\---



\# 5. DUNGEON GENERATION



\* \[x] Seeded RNG

\* \[x] Logical floor graph

\* \[x] Start placement

\* \[x] Descent placement

\* \[x] Room archetypes

\* \[x] Connections

\* \[x] Branches

\* \[x] Landmarks

\* \[x] Secret candidates

\* \[x] Encounter slots

\* \[x] Generation validation

\* \[x] Deterministic repair

\* \[x] Deterministic regeneration

\* \[?] Debug seed loading

\* \[x] Procedural soak testing



\---



\# 6. FLOOR RULES



\* \[ ] Floor rule interface

\* \[ ] Rule selection

\* \[ ] Rule state

\* \[ ] Rule cleanup

\* \[ ] Rule clues

\* \[ ] Rule/environment interaction

\* \[ ] Rule/creature interaction

\* \[ ] Rule/item interaction

\* \[ ] At least 3 substantially different rules

\* \[ ] Rules are discoverable through observation



\---



\# 7. ROOMS



\* \[ ] Basic corridor

\* \[ ] Basic combat room

\* \[ ] Exploration room

\* \[ ] Landmark room

\* \[ ] Rest/safe room

\* \[ ] Secret room

\* \[ ] Environmental puzzle-like room

\* \[ ] Rare room

\* \[ ] Room revisit behavior

\* \[ ] Room visual differentiation



\---



\# 8. CREATURES



\* \[ ] Creature definition system

\* \[ ] Creature state machine

\* \[ ] Idle behavior

\* \[ ] Detection

\* \[ ] Investigation

\* \[ ] Pursuit

\* \[ ] Search

\* \[ ] Retreat/return behavior where appropriate

\* \[ ] Environmental interaction

\* \[ ] Difficulty scaling

\* \[ ] AI performance budget

\* \[ ] Creature cleanup



\---



\# 9. COMBAT



\* \[ ] Basic attack

\* \[ ] Basic enemy attack

\* \[ ] Damage validation

\* \[ ] Hit feedback

\* \[ ] Positioning matters

\* \[ ] Avoidance possible

\* \[ ] Environmental combat interaction

\* \[ ] Combat is not button spam

\* \[ ] Combat does not dominate every room



\---



\# 10. ITEMS



\* \[ ] Item definition system

\* \[ ] Small inventory

\* \[ ] Pickup interaction

\* \[ ] Item use

\* \[ ] Item state

\* \[ ] Item persistence where appropriate

\* \[ ] At least one item with secondary use

\* \[ ] Items visually readable

\* \[ ] No excessive currencies

\* \[ ] No loot boxes

\* \[ ] No gambling mechanics



\---



\# 11. DISCOVERY



\* \[ ] Discovery system

\* \[ ] Secret tracking

\* \[ ] Rule discovery

\* \[ ] Creature knowledge

\* \[ ] Shortcut discovery

\* \[ ] Discovery feedback

\* \[ ] Discovery persistence



The player should be able to become stronger through \*\*knowledge\*\*, not only statistics.



\---



\# 12. FAILURE



\* \[ ] Failure state

\* \[ ] Run summary

\* \[ ] Depth summary

\* \[ ] Discovery summary

\* \[ ] Interesting event summary

\* \[ ] Fast restart

\* \[ ] Failure explanation

\* \[ ] No excessive waiting

\* \[ ] No graphic death presentation



\---



\# 13. VISUAL IDENTITY



\* \[ ] Restrained palette

\* \[ ] Dark-but-readable lighting

\* \[ ] No constant neon

\* \[ ] No generic Roblox environment

\* \[ ] Strong silhouettes

\* \[ ] Distinct room compositions

\* \[ ] Environmental storytelling

\* \[ ] Atmospheric materials

\* \[ ] Original visual identity

\* \[ ] Rogue-era cover-art mood

\* \[ ] No direct copying of historical artwork



\---



\# 14. UI



\* \[ ] Minimal HUD

\* \[ ] Health/state

\* \[ ] Inventory

\* \[ ] Interaction prompt

\* \[ ] Floor/depth

\* \[ ] Run summary

\* \[ ] Discovery feedback

\* \[ ] No giant floating labels

\* \[ ] No permanent quest arrows

\* \[ ] No damage number spam

\* \[ ] No excessive reward notifications



\---



\# 15. AUDIO



\* \[ ] Footsteps

\* \[ ] Surface-specific footsteps

\* \[ ] Room ambience

\* \[ ] Environmental sounds

\* \[ ] Creature audio

\* \[ ] Interaction sounds

\* \[ ] Mechanism sounds

\* \[ ] Intentional silence

\* \[ ] Music system

\* \[ ] Music does not overwhelm atmosphere



\---



\# 16. PERSISTENCE



\* \[ ] Versioned save schema

\* \[ ] Discovery persistence

\* \[ ] Run statistics

\* \[ ] Personal best depth

\* \[ ] Cosmetic persistence if used

\* \[ ] Data migration

\* \[ ] Save error handling

\* \[ ] DataStore testing



\---



\# 17. SECURITY



\* \[ ] Server-authoritative run state

\* \[ ] Server-authoritative interactions

\* \[ ] Server-authoritative rewards

\* \[ ] Server-authoritative encounters

\* \[ ] Remote validation

\* \[ ] Remote rate limiting

\* \[ ] Invalid request handling

\* \[ ] Client cannot grant itself items

\* \[ ] Client cannot modify persistent state

\* \[ ] Client cannot determine combat outcomes



\---



\# 18. PERFORMANCE



\* \[ ] Old floors unload

\* \[ ] Temporary objects clean up

\* \[ ] AI update budgets

\* \[ ] Particle budgets

\* \[ ] Remote traffic reviewed

\* \[ ] Memory reviewed

\* \[ ] Mobile test

\* \[ ] Controller test

\* \[ ] Mid-range hardware test

\* \[ ] Long-session test



\---



\# 19. PLAYTESTING



\## FIRST PLAYTEST



Record:



\* Where did the player first become curious?

\* Where did the player become confused?

\* Where did they first make a meaningful decision?

\* What did they discover?

\* What made them smile/surprised?

\* Where did they stop?

\* Why did they stop?



Do not immediately fix everything based on one playtest.



Look for repeated patterns.



\---



\# 20. RETENTION DIAGNOSTIC



If players leave before ten minutes, DO NOT immediately add:



\* more rewards

\* more XP

\* more currencies

\* daily rewards

\* quests

\* notifications

\* free items

\* battle passes



Instead ask:



\### Did they understand the goal?



\### Did they encounter a mystery?



\### Did they make a meaningful decision?



\### Did they discover a system?



\### Did the systems interact?



\### Did anything surprising happen?



\### Did they understand why something happened?



\### Did they have another unanswered question?



Fix the underlying experience.



\---



\# 21. ANTI-SLOP REVIEW



Before release:



\* \[ ] No generic simulator progression

\* \[ ] No fake urgency

\* \[ ] No excessive currencies

\* \[ ] No gambling-like mechanics

\* \[ ] No loot boxes

\* \[ ] No giant reward popups

\* \[ ] No rainbow rarity explosions

\* \[ ] No constant neon

\* \[ ] No generic fantasy asset collage

\* \[ ] No shocked-face thumbnail

\* \[ ] No "FREE!!!" thumbnail

\* \[ ] No giant damage numbers

\* \[ ] No unnecessary quest arrows

\* \[ ] No feature exists solely to increase playtime without adding fun



\---



\# 22. CURRENT DEVELOPMENT STATE



\## Current phase



\*\*PHASE 1–4 — PLAYABLE VERTICAL SLICE (needs playtesting)\*\*



\## Current playable state



Vertical slice implemented and launching without errors in Studio (2026-10-08).
Only dungeon generation is verified so far (soak test: 420 floors, 0 failures, deterministic).
Everything else below is built but marked untested until a playtest confirms it.

Built: per-player runs, seeded 3x3/4x3/4x4 floors, 13 room archetypes, 3 floor rules
(Echoes, Hungry Dark, Tolling), Listener + Watcher creatures, oil flask / tin bell /
tincture / rusted key, noise system with visible rings, lantern fuel + dimming, creeping,
staff strike, cracked-wall secrets, vaults, shrine, buried machine, camp notes, draft dust law,
journal, run summary, fast restart, versioned DataStore persistence, /ra debug commands.

Blender creature meshes (Listener, Watcher) imported into the place at
ServerStorage.Assets.Creatures.<Kind> and verified in play (Listener heard, pursued,
telegraphed and hit). Source: blender/RogueAbyss_Art.blend, exports in blender/exports/.
These imported models live in the place file only - save the place after changing them.

Studio debug hook: ServerScriptService.DebugHook:Invoke("creatures" | "goto", kind, dist | "run", "floor", n
| "run", "give", itemId, n | "run", "exp", n | "use", itemId | "cast", abilityId | "start").

### Rogue-style RPG layer (2026-10-08, tested in Studio play mode)

* Main menu (Play / How to Play / Journal / Records). Runs no longer auto-start; the server
  waits for RequestRestart. Pause menu on M with "Quit to Main Menu" (RequestMenu).
* Stats: Health (20, +4 per experience level), Strength, Armor, Gold, Experience levels
  (Config.Levels). Status panel + Rogue-style message log at the top of the screen.
* Gear (Definitions/Items): 6 weapons (quarterstaff, dagger, mace, spear, long sword,
  two-handed sword) with damage/reach/arc/speed/noise; 6 armors (leather .. plate mail),
  each point blocks 7% damage (cap 60%). +1/+2 enchantments. Weapon is visible on the character.
* Consumables: potions (healing, extra healing, strength), scrolls (enchant weapon/armor,
  magic mapping, teleportation), food rations, plus oil flasks and bells. Stackable.
* Inventory: 12-slot pack, slots 1-4 are the hotbar. Inventory panel (I / Tab) to
  wield/wear/drink/read/drop/move to hotbar (RequestInventory).
* Chests (Fixtures.Chest, Definitions/Loot): 1-2 per level + secret room; ornate chest in
  the vault. Loot rolled deterministically per seed when opened, spilled on the ground.
  Gold piles on the floor; monsters drop gold; treasures (curios) are worth gold.
* Monsters: Creatures/Beast.luau adds giant rats (packs), kobolds, bats (erratic, drawn to
  a bright lantern), zombies (level 3+). They see only within lantern reach + 6 studs and
  investigate noise, so dimming/sneaking matters. Every attack is telegraphed.
* Abilities (AbilityService, Definitions/Abilities), unlocked by level with cooldowns:
  Dash (2, Space), Magic Missile (3, Z), Light (4, X - counts as firelight for Watchers),
  Slow Monster (5, C), Blink (6, V).
* Death screen is a Rogue tombstone (name, gold, cause, level) + tips and run events.
* Controls panel always on screen, toggled with H (adapts to keyboard / gamepad / touch).
* All player-facing text rewritten in plain language (rules, journal, notes, prompts).

Verified in play: menu loop (menu -> play -> death -> menu -> play), equip via inventory,
melee kills + exp + level-up unlock notices, all five abilities, every scroll type, chest
loot, plaque reading, death tombstone, pause menu. Generation soak 420 floors, 0 failures,
deterministic. Not yet verified: gamepad and touch bindings, DataStore save of new stats
(Studio has no API access), balance over a full run.

### Combat, progression and presentation overhaul (2026-10-08, tested in Studio)

Superseded parts of the section above: abilities are replaced by spells + dash, and the
Play button by character creation.

* Floor-8 fall-through fixed: StreamingEnabled meant deep start rooms had not streamed in
  when the server teleported the player. RunDirector.SafeTeleport now holds the player
  anchored (RequestStreamAroundAsync + AwaitGround/ClientReady handshake) until the client
  sees floor under them. Falling out of the map is no longer fatal (return to last footing, -3 HP).
* Combat (CombatService): stamina per swing (winded when empty), 3-hit combos with a
  finisher, hold-to-charge heavy attacks, crits, backstabs, per-weapon quirks and a Q
  special per weapon. Explosions, breakable pots/crates/barrels, explosive oil barrels.
* Weapons: 7 melee + 4 magic staffs with detailed part models (Builder/Gear), trails,
  enchant glow. Armor tiers visibly change the character; enchants add glowing runes; the
  cloak gains trim at level 4 and turns crimson at 7.
* Spells (SpellService, Definitions/Spells): 13 spells, mana, slots (2 + levels 4/7/10 +
  perks), learned from spellbooks, forgettable. Dash on Space for everyone.
* Progression (ProgressionService, Definitions/Boons): character creation boons/flaws,
  20 level-up perks chosen 3 at a time (L).
* Monsters (Creatures/Beast): rat, kobold (throws spears), bat (dives), slime (splits),
  zombie (slam, exposed), skeleton (shield block), orc (charge, dazed on walls), wraith
  (only hurt in light). Depth scaling and elites (CreatureService). Status effects.
* Client: procedural swing/cast animations (Animator), hit flash, damage numbers, enemy
  health bars, telegraph markers, hit-stop and camera shake (Feedback), colour grading,
  ambience/music layers, distant sounds, dust motes, torch flicker, low-HP heartbeat
  (Atmosphere), ornate UI kit, new HUD (health/mana/stamina/exp, spell bar, Q skill, perk
  prompt), Sanctum menu scene and character-creation cutscene (Sanctum), new panels.

Verified in play: menu over the 3D sanctum, full creation flow (name, flaws, boons, spell),
run start with chosen boons, light/heavy attacks, Whirlwind special, Firebolt explosion,
perk choice, plate armor + long sword visible on the character, all 8 new monster kinds
engage without AI errors at depth 7, safe teleports on levels 8-11 (released in ~0.3s,
standing on the floor), "Same Again", tombstone. Generation soak 500 floors (depth 1-10),
0 failures, deterministic.
Notes: lights created far from the camera need re-enabling once it arrives (Sanctum does
this); lights parented under the Camera never illuminate, so local visuals live in Workspace.
Not yet verified: every weapon special/spell visually, gamepad/touch, balance over a run.



\## Current game name



\*\*Rogue Abyss\*\*



\## Core experience



Procedural dungeon exploration with:



\* environmental discovery

\* meaningful risk

\* systemic interactions

\* readable creature behavior

\* limited resources

\* mysterious floor rules

\* replayable runs



\## Camera



Elevated / top-down.



\## Primary retention strategy



Curiosity and systemic discovery.



\## Visual identity



Restrained, atmospheric fantasy inspired by the mood of classic 1980s fantasy computer-game artwork.



\## Procedural generation



Authored modular pieces combined through deterministic generation.



\## Multiplayer



Solo-first.



Small-session co-op can be added after the core solo loop works.



\---



\# 23. CLAUDE OPERATING INSTRUCTIONS



Claude must follow these rules while building Rogue Abyss.



\### RULE 1



Read all four project documents before major implementation:



```text

GAME\_DESIGN.md

ART\_BIBLE.md

TECH\_ARCHITECTURE.md

BUILD\_STATUS.md

```



\### RULE 2



Do not change the game's identity just because a more common Roblox pattern exists.



\### RULE 3



Do not add features simply because successful Roblox games use them.



\### RULE 4



Prioritize the core gameplay loop.



\### RULE 5



Build a complete vertical slice before building huge amounts of content.



\### RULE 6



Test procedural generation aggressively.



\### RULE 7



Protect the art direction.



\### RULE 8



Do not use manipulation as the primary retention strategy.



\### RULE 9



When something is uncertain, prefer the solution that creates more player agency and discovery.



\### RULE 10



After meaningful implementation work, update this file.



\---



\# 24. CHANGE LOG



\## 2026-10-08 (RPG layer)

* Added main/pause menus, inventory, weapons, armor, potions, scrolls, food, chests, gold,
  experience levels, abilities/spells, 4 new monster types, tombstone death screen,
  toggleable controls panel, plain-language rewrite of all player-facing text
* Chests are found in the dungeon only; nothing is purchasable (no loot-box monetisation)
* Camera turn moved from Z/C to Left/Right arrow (Z/X/C/V are now spells)

## 2026-10-08 (implementation)



\* Built full vertical slice (see Current playable state)

\* Generation soak-tested: 60 seeds x 7 depths, 0 failures, deterministic

\* Listener and Watcher modelled in Blender, exported as FBX

\* Removed Lighting.Technology from project.json (plugins cannot set it; set Future manually)



\## 2026-10-08



\* Project named \*\*Rogue Abyss\*\*

\* Established original Roblox interpretation of Rogue-inspired gameplay

\* Established curiosity-driven first-session design

\* Established ten-minute first-session target

\* Established restrained visual identity

\* Established Rogue-era fantasy cover-art inspiration

\* Established server-authoritative architecture

\* Established modular procedural generation

\* Established solo-first development

\* Established anti-slop design rules



\---



\# 25. FINAL PRODUCT TEST



Before calling Rogue Abyss ready for public release, ask:



> If I removed every XP bar, currency, daily reward, quest, badge, notification, and progression screen, would exploring the dungeon still be fun?



If the answer is \*\*no\*\*, the core game is not finished.



If the answer is \*\*yes\*\*, the project is succeeding at what Rogue Abyss is supposed to be.



