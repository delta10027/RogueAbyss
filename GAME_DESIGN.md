\# ROGUE ABYSS — GAME DESIGN



\## What the player actually experiences



> This is the product contract for Rogue Abyss.

>

> Claude must read this before implementing gameplay. If an implementation conflicts with this document, do not silently change the design. Resolve the conflict by preserving the core identity of Rogue Abyss.



\---



\# 1. GAME IDENTITY



\*\*Game name:\*\* Rogue Abyss



\*\*Platform:\*\* Roblox



\*\*Genre:\*\* Procedural dungeon exploration / action-adventure / roguelike



\*\*Primary experience:\*\* Exploration, discovery, risk, environmental interaction, survival, and replayability.



Rogue Abyss is an original Roblox game inspired by the ideas behind \*\*Rogue (1985)\*\*.



It is NOT a remake.



Do not directly reproduce:



\* Rogue's exact artwork

\* Rogue's exact monsters

\* Rogue's exact maps

\* Rogue's exact item names

\* Rogue's exact UI

\* Rogue's exact characters

\* Rogue's exact typography

\* Rogue's exact cover composition



Instead, take inspiration from the underlying feeling:



> \*\*You are entering a place you do not fully understand, and knowledge is one of your strongest weapons.\*\*



\---



\# 2. NORTH STAR



Rogue Abyss should feel like:



> \*\*A forgotten fantasy computer game from another timeline, transformed into a mysterious physical 3D dungeon.\*\*



It should NOT feel like:



\* a generic Roblox simulator

\* a bright children's game

\* an anime battleground

\* a generic fantasy RPG

\* a loot-box game

\* an endless XP treadmill

\* an asset-store dungeon

\* a game designed primarily around dopamine notifications

\* a high-contrast "kids game" with glowing everything



The game should feel:



\* mysterious

\* intelligent

\* atmospheric

\* dangerous

\* strange

\* restrained

\* tactile

\* replayable

\* memorable



\---



\# 3. CORE PLAYER FANTASY



The player is not an unstoppable hero.



They are an explorer entering an ancient environment that operates according to rules they don't completely understand.



The dungeon existed before the player arrived.



The player's advantage is:



\* observation

\* experimentation

\* positioning

\* preparation

\* memory

\* understanding



The player should eventually think:



> "I understand how this place works."



Then:



> "Can I use that rule against it?"



That is the core fantasy.



\---



\# 4. CORE GAMEPLAY LOOP



The fundamental loop is:



\*\*Observe → Explore → Experiment → Understand → Risk → React → Discover → Descend\*\*



The game should NOT primarily revolve around:



\*\*Kill → XP → Upgrade → Repeat\*\*



Progression exists, but the dungeon itself is the primary source of entertainment.



\---



\# 5. MICRO LOOP



Every few seconds, the player should have something worth noticing.



Typical micro loop:



1\. Enter an area.

2\. Observe surroundings.

3\. Identify possible threats/opportunities.

4\. Choose a direction.

5\. Interact or move.

6\. See a consequence.

7\. Adjust behavior.



\---



\# 6. ROOM LOOP



A room should generally follow:



\*\*Enter → Read → Decide → Interact → Consequence → Reassess\*\*



Do not create rooms that exist only to contain enemies.



A room can be interesting because of:



\* architecture

\* sound

\* lighting

\* environmental clues

\* unusual geometry

\* an item

\* a creature

\* a secret

\* a trap

\* a strange rule

\* an interaction

\* a choice



\---



\# 7. FLOOR LOOP



Each floor should contain:



\* a readable main route

\* optional branches

\* a landmark

\* at least one unusual room

\* at least one meaningful risk

\* environmental clues

\* a special floor rule

\* a descent point

\* at least one reason to revisit or reconsider a previous area



The player should not simply walk from entrance to exit.



\---



\# 8. RUN LOOP



A complete run should feel like:



\*\*Enter → Learn → Adapt → Risk → Discover → Descend → Become invested → Decide whether to continue\*\*



The player should constantly balance:



> \*\*"I could leave now."\*\*



against:



> \*\*"But what is down there?"\*\*



\---



\# 9. THE TEN-MINUTE FIRST SESSION



Do not use manipulative mechanics to force players to stay.



Do not use:



\* fake countdowns

\* excessive notifications

\* daily reward pressure

\* artificial energy systems

\* gambling mechanics

\* endless reward popups



Instead, make the first ten minutes contain escalating curiosity.



\## 0:00–1:00



Player learns:



\* movement

\* camera

\* basic interaction

\* basic health/state



Player also notices something unexplained.



There should be a question in their mind.



Example:



Three identical doors.



Only one has dust moving beneath it.



Do not explain why.



\---



\## 1:00–3:00



Player encounters the first meaningful discovery.



Examples:



\* footprints reveal creature movement

\* sound reveals nearby danger

\* lighting reveals a hidden route

\* a symbol predicts a room behavior

\* an object can be manipulated

\* a creature follows a predictable rule



The player learns:



> "The environment contains information."



\---



\## 3:00–5:00



Give the player their first real decision.



Examples:



\* safe route vs strange route

\* use resource vs save it

\* fight vs avoid

\* descend vs investigate

\* open suspicious door vs continue



The game should respect the player's decision.



\---



\## 5:00–7:00



Create the first \*\*system interaction\*\*.



Example:



The player learns:



\* creature reacts to sound

\* bell creates sound



Later they encounter a room containing both.



The player realizes:



> "I can manipulate this creature."



This is one of the most important feelings in Rogue Abyss.



\---



\## 7:00–10:00



Deliver a memorable run moment.



Examples:



\* escape through a route the player previously ignored

\* trick a creature using the environment

\* discover a secret room

\* recognize a symbol before something happens

\* intentionally trigger one dungeon rule to counter another

\* discover a shortcut

\* survive a dangerous room because of something learned earlier



At approximately ten minutes, present a new mystery.



Examples:



\* a sealed staircase

\* a strange entity

\* a previously impossible door becoming accessible

\* evidence of another explorer

\* an unexplained change in the dungeon



The player should think:



> "I want to know what that is."



\---



\# 10. THE DUNGEON HAS RULES



Every floor should have at least one meaningful environmental rule.



Examples:



\* sound travels unusually far

\* light attracts certain creatures

\* certain doors move

\* marked tiles behave differently

\* rooms repeat under specific conditions

\* reflections reveal hidden objects

\* certain objects influence nearby rooms

\* creatures respond differently to different environmental states



The important rule:



\## The player must be able to learn the rule.



Do not make important mechanics completely random.



The player should eventually be able to say:



> "That happened because I understand the rule."



\---



\# 11. PROCEDURAL GENERATION



Procedural generation must create \*\*interesting situations\*\*, not random noise.



Do NOT generate thousands of meaningless rooms.



Use authored:



\* room archetypes

\* corridors

\* landmarks

\* encounter patterns

\* secrets

\* environmental rules

\* events

\* architectural sets



Then combine them intelligently.



The dungeon should feel procedurally generated while still feeling authored.



\---



\# 12. PROCEDURAL GENERATION PRINCIPLE



Generate the floor in layers.



\### Layer 1 — Macro structure



Determine:



\* entrance

\* main route

\* branches

\* descent

\* landmarks



\### Layer 2 — Room composition



Place:



\* combat rooms

\* exploration rooms

\* puzzle-like rooms

\* environmental rooms

\* rest/safe rooms

\* secret candidates



\### Layer 3 — Encounters



Determine:



\* creature locations

\* environmental hazards

\* interactive objects



\### Layer 4 — Secrets



Add:



\* hidden passages

\* unusual interactions

\* rare rooms

\* alternate routes



\### Layer 5 — Presentation



Instantiate:



\* geometry

\* lighting

\* audio

\* particles

\* environmental storytelling



\---



\# 13. COMBAT



Combat should be:



\* deliberate

\* readable

\* dangerous

\* short

\* positional



Avoid constant attack spam.



A player should win because they:



\* understood the enemy

\* positioned correctly

\* used the environment

\* chose the right moment

\* recognized danger early



Not because they simply had the largest damage number.



\---



\# 14. ENEMY DESIGN



Enemies need recognizable rules.



Examples:



\### The Listener



React strongly to sound.



\### The Watcher



Only moves when the player isn't directly observing it.



\### The Burrower



Uses predictable underground movement.



\### The Hoarder



Protects objects rather than simply attacking the player.



\### The Wanderer



Moves through the dungeon according to a repeatable pattern.



These are examples, not mandatory final enemies.



The principle is:



> \*\*Enemies should be understandable enough to outsmart.\*\*



\---



\# 15. INFORMATION IS LOOT



Rogue Abyss should treat knowledge as progression.



The player can discover:



\* creature behaviors

\* floor rules

\* shortcuts

\* secret rooms

\* environmental interactions

\* symbols

\* patterns

\* safe routes

\* dangerous routes

\* item interactions



A knowledgeable player should perform better.



\---



\# 16. ITEMS



Avoid enormous inventories.



Items should be meaningful.



Every item should ideally have:



1\. an obvious use

2\. a potential secondary use

3\. a reason to save it



Example:



A small oil flask can:



\* illuminate an area

\* create a temporary distraction

\* interact with certain environmental objects



The player should sometimes think:



> "Wait... could I use this for something else?"



\---



\# 17. RISK



Rogue Abyss should constantly present:



\*\*Known safety vs unknown possibility.\*\*



Examples:



\* obvious treasure in a dangerous room

\* unexplored corridor

\* suspicious shortcut

\* limited healing resource

\* optional elite encounter

\* mysterious lever



The player must decide how much uncertainty they are willing to accept.



\---



\# 18. FAILURE



Failure should be:



\* quick

\* understandable

\* fair

\* informative



Avoid graphic violence.



After failure, show:



\* depth reached

\* notable discoveries

\* interesting events

\* useful run statistics

\* optional hints about unexplored possibilities



Then allow a fast restart.



The intended reaction is:



> "I understand what went wrong. I want to try again."



Not:



> "That was random."



\---



\# 19. DEATH SHOULD NOT WASTE THE PLAYER'S TIME



A failed run should still give the player something:



\* knowledge

\* discovery

\* understanding

\* a new strategy



Do not create long death animations or mandatory waiting periods.



Restart should be fast.



\---



\# 20. MULTIPLAYER



The game must work solo first.



After the solo experience is strong, support small cooperative sessions.



Co-op should introduce new decisions.



Examples:



\* one player observes while another interacts

\* players can split up

\* one player attracts an enemy while another escapes

\* players discover different clues

\* sound-based systems can create accidental problems

\* players have to communicate information



Do not simply multiply enemy health for multiplayer.



\---



\# 21. SOCIAL DESIGN



Do not rely on:



\* daily login pressure

\* fake urgency

\* excessive currencies

\* gambling

\* loot boxes

\* constant reward screens



Instead use:



\* run history

\* personal depth records

\* discovered secrets

\* rare events

\* challenge seeds

\* cosmetics

\* unusual run summaries

\* shareable stories



A player should be able to tell a friend:



> "You won't believe what happened on my last run."



That is valuable social retention.



\---



\# 22. AUDIO



Audio is part of gameplay.



Use:



\* footsteps

\* room acoustics

\* distant sounds

\* creature audio

\* mechanisms

\* environmental noise

\* occasional silence



Silence can itself be information.



Do not put constant music underneath everything.



Music should appear when it matters.



\---



\# 23. CAMERA



Use an elevated / top-down perspective.



The player needs to understand:



\* room layout

\* threats

\* exits

\* important objects



The camera should feel like the player is looking into a physical miniature dungeon.



Do not use:



\* excessive shake

\* excessive zoom

\* constant camera effects

\* cinematic effects that reduce readability



\---



\# 24. UI



UI should be minimal.



Display only what matters:



\* health/state

\* inventory

\* interaction prompt

\* floor/depth

\* important temporary information



Avoid:



\* huge quest markers

\* permanent arrows

\* damage-number spam

\* giant floating labels

\* constant achievement banners

\* rainbow rarity colors

\* screen-filling notifications



\---



\# 25. ROBLOX DESIGN



Take advantage of Roblox without allowing Roblox's default visual language to define the game.



The game must support:



\* keyboard/mouse

\* controller

\* mobile

\* fast joining

\* stable servers

\* reasonable hardware

\* small multiplayer sessions



Prioritize readable controls and performance.



\---



\# 26. ANTI-SLOP TEST



Before adding any feature, ask:



1\. Does this make the dungeon more interesting?

2\. Does this create a decision?

3\. Does it reward observation?

4\. Does it create emergent interactions?

5\. Is it visually consistent with Rogue Abyss?

6\. Would it still be fun without XP?

7\. Does it make the player curious?

8\. Can the player understand why it happened?

9\. Does it avoid unnecessary UI clutter?

10\. Could a player remember this moment afterward?



If most answers are no:



\*\*Do not add the feature.\*\*



\---



\# 27. SUCCESS CRITERIA



A strong first session should produce reactions such as:



> "Wait, what was that?"



> "I think I understand this."



> "Can I use that?"



> "I should have gone the other way."



> "That enemy actually has a pattern."



> "I didn't know the dungeon could do that."



> "I found something weird."



> "One more floor."



That is the retention strategy.



\*\*Curiosity + agency + readable consequences + discovery.\*\*



