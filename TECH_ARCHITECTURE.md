\# ROGUE ABYSS — TECH ARCHITECTURE



\## How the code works



> This document defines the technical architecture for Rogue Abyss.

>

> The goal is a maintainable Roblox/Luau project that Claude can continue developing without creating one enormous script or fragile procedural systems.



\---



\# 1. ENGINEERING NORTH STAR



Rogue Abyss should be:



\* server-authoritative

\* modular

\* deterministic where useful

\* testable

\* performant

\* data-driven

\* easy to debug



Do not build the game as one giant server script.



Do not allow client code to control important game state.



Do not couple procedural generation directly to visual rendering.



\---



\# 2. RECOMMENDED PROJECT STRUCTURE



```text

ReplicatedStorage

│

├── Shared

│   ├── Config

│   ├── Constants

│   ├── Types

│   ├── Utility

│   ├── RNG

│   ├── Definitions

│   │   ├── RoomDefinitions

│   │   ├── CreatureDefinitions

│   │   ├── ItemDefinitions

│   │   ├── FloorRuleDefinitions

│   │   └── EventDefinitions

│   └── Serialization

│

├── Remotes

│   ├── Interaction

│   ├── Run

│   ├── UI

│   └── Effects

│

└── Assets

&#x20;   ├── Rooms

&#x20;   ├── Props

&#x20;   ├── Creatures

&#x20;   ├── Items

&#x20;   ├── VFX

&#x20;   └── Audio

│

ServerScriptService

│

├── ServerMain.server.lua

│

├── Services

│   ├── RunService

│   ├── DungeonService

│   ├── GenerationService

│   ├── RulesService

│   ├── EncounterService

│   ├── InteractionService

│   ├── PlayerStateService

│   ├── PersistenceService

│   └── AnalyticsService

│

└── Systems

&#x20;   ├── CreatureSystem

&#x20;   ├── EnvironmentSystem

&#x20;   ├── ItemSystem

&#x20;   └── FloorSystem

│

StarterPlayer

│

└── StarterPlayerScripts

&#x20;   ├── ClientMain.client.lua

&#x20;   ├── Controllers

&#x20;   │   ├── InputController

&#x20;   │   ├── CameraController

&#x20;   │   ├── InteractionController

&#x20;   │   ├── UIController

&#x20;   │   └── AudioController

&#x20;   │

&#x20;   └── Presentation

&#x20;       ├── Effects

&#x20;       └── Animation

│

StarterGui

│

└── GameUI

```



Names can change if necessary, but responsibilities must remain separated.



\---



\# 3. SERVICE RESPONSIBILITIES



\## RunService



Owns the run lifecycle.



State:



```text

Idle

↓

Starting

↓

Active

↓

FloorTransition

↓

Active

↓

Completed / Failed / Exited

↓

Summary

↓

Restart

```



RunService should be the authoritative source of run state.



\---



\# 4. DUNGEON SERVICE



DungeonService owns the currently active dungeon.



Responsibilities:



\* create floor

\* unload floor

\* track floor number

\* expose dungeon state

\* manage landmarks

\* manage floor transitions

\* clean up generated instances



It should not contain procedural algorithms directly.



\---



\# 5. GENERATION SERVICE



GenerationService creates the logical dungeon.



It should operate primarily on data.



Input:



```text

RunSeed

FloorNumber

Difficulty

FloorRule

GenerationConfig

```



Output:



```text

LogicalFloor

```



Only after the logical floor is validated should it be converted into Roblox Instances.



\---



\# 6. LOGICAL FLOOR REPRESENTATION



Do not make physical Roblox Parts the only representation of the dungeon.



Use a logical model such as:



```lua

local Floor = {

&#x20;   Seed = 0,

&#x20;   Depth = 1,

&#x20;   RuleId = "",



&#x20;   Rooms = {},

&#x20;   Connections = {},

&#x20;   Landmarks = {},

&#x20;   Events = {},

}

```



A room might contain:



```lua

local Room = {

&#x20;   Id = "",

&#x20;   Archetype = "",

&#x20;   Position = Vector2.zero,

&#x20;   Connections = {},

&#x20;   Tags = {},

&#x20;   State = {},

}

```



This makes the dungeon:



\* testable

\* reproducible

\* debuggable

\* analyzable

\* easier to regenerate



\---



\# 7. DETERMINISTIC RNG



Use a dedicated seeded random system.



Important dungeon generation should never depend on uncontrolled global randomness.



Derive randomness from:



```text

RunSeed

\+ FloorNumber

\+ GenerationStage

```



Separate randomness for:



\* layout

\* encounters

\* items

\* events

\* secrets



This prevents one small random change from completely changing unrelated parts of a floor.



\---



\# 8. GENERATION PIPELINE



Use this general pipeline:



```text

Create Run Seed

&#x20;       ↓

Select Floor Rule

&#x20;       ↓

Create Macro Graph

&#x20;       ↓

Place Start

&#x20;       ↓

Place Descent

&#x20;       ↓

Place Landmarks

&#x20;       ↓

Place Required Room Types

&#x20;       ↓

Create Optional Branches

&#x20;       ↓

Assign Encounters

&#x20;       ↓

Assign Secrets

&#x20;       ↓

Validate

&#x20;       ↓

Repair / Regenerate if Necessary

&#x20;       ↓

Instantiate Roblox Assets

&#x20;       ↓

Post-Generation Validation

```



\---



\# 9. GENERATION VALIDATION



Never assume procedural generation is valid.



Check:



\* start is reachable

\* descent is reachable

\* all required rooms are reachable

\* no impossible corridor

\* no invalid room overlap

\* no impossible player spawn

\* branch count is reasonable

\* encounter density is reasonable

\* required interactions exist



If validation fails:



1\. attempt deterministic repair

2\. if repair fails, regenerate

3\. log the seed

4\. log the failure reason



A broken procedural floor should never silently ship to players.



\---



\# 10. ROOM DEFINITIONS



Rooms should be data-driven.



Example:



```lua

return {

&#x20;   Id = "CollapsedArchive",



&#x20;   Footprint = Vector2.new(3, 4),



&#x20;   Tags = {

&#x20;       "Exploration",

&#x20;       "Landmark",

&#x20;   },



&#x20;   Generation = {

&#x20;       MinDepth = 2,

&#x20;       MaxDepth = 999,

&#x20;       Weight = 0.35,

&#x20;   },



&#x20;   Features = {

&#x20;       CanContainSecret = true,

&#x20;       CanContainEncounter = true,

&#x20;   },

}

```



Do not hardcode every room directly into GenerationService.



\---



\# 11. FLOOR RULE SYSTEM



Each floor can have a unique environmental rule.



Rules should use a common interface.



Conceptually:



```lua

local Rule = {

&#x20;   Id = "ExampleRule",



&#x20;   Configure = function(context)

&#x20;   end,



&#x20;   OnRoomEntered = function(context, room)

&#x20;   end,



&#x20;   OnInteraction = function(context, interaction)

&#x20;   end,



&#x20;   OnTick = function(context, deltaTime)

&#x20;   end,



&#x20;   Cleanup = function(context)

&#x20;   end,

}



return Rule

```



Rules should not directly control unrelated systems.



They communicate through well-defined services/events.



\---



\# 12. ENCOUNTER ARCHITECTURE



Encounters should be data-driven.



An encounter defines:



\* trigger

\* participants

\* starting state

\* behavior

\* environment interaction

\* resolution

\* consequences



Complex creatures should use explicit state machines.



Example:



```text

Idle

↓

Investigating

↓

Alert

↓

Pursuing

↓

Searching

↓

Returning

```



Avoid giant nested `if` statements for AI.



\---



\# 13. AI PHILOSOPHY



AI should be understandable.



Players should be able to learn:



\* what attracts an enemy

\* what scares it

\* where it patrols

\* when it attacks

\* when it retreats

\* how it searches



Avoid enemies that behave randomly purely to create difficulty.



The player should lose because they misunderstood or misplayed a system, not because the game arbitrarily decided to kill them.



\---



\# 14. AI PERFORMANCE



Use relevance-based update rates.



\### Near player



Full behavior updates.



\### Same room



Highly responsive.



\### Nearby



Reduced frequency.



\### Far away



Simulated state.



\### Unloaded



No active AI.



Do not run expensive AI logic for every creature every frame.



\---



\# 15. INTERACTION SYSTEM



All meaningful interactions go through InteractionService.



Client sends:



```text

RequestInteract

```



Server validates:



\* player exists

\* target exists

\* target is interactable

\* player is close enough

\* target is in valid state

\* cooldown is valid

\* action is allowed



Then the server performs the action.



\---



\# 16. CLIENT / SERVER RESPONSIBILITIES



\## CLIENT



Client owns:



\* input

\* camera

\* local UI

\* local animation presentation

\* cosmetic effects

\* local audio

\* visual feedback



\## SERVER



Server owns:



\* run state

\* dungeon state

\* generation

\* encounters

\* important interactions

\* player progression

\* important inventory

\* persistence



\## SHARED



Shared code owns:



\* definitions

\* constants

\* types

\* deterministic algorithms

\* pure utilities

\* serialization



\---



\# 17. NEVER TRUST THE CLIENT



The client must never be able to directly decide:



\* damage

\* rewards

\* item creation

\* permanent progression

\* enemy state

\* floor completion

\* discovery unlocks

\* saved data



The client requests.



The server decides.



\---



\# 18. NETWORKING



Prefer semantic RemoteEvents.



Good:



```text

RequestInteract

RequestDescend

RequestLeaveRun

```



Bad:



```text

SetHealth

GiveItem

SetPlayerState

SetEnemyState

```



The server should interpret requests.



Rate-limit interaction requests.



Validate all arguments.



Reject malformed requests.



\---



\# 19. PERSISTENCE



Persist information that gives the player identity without making new players powerless.



Good candidates:



\* discovered secrets

\* discovered rules

\* personal depth record

\* run statistics

\* challenge completions

\* cosmetics



Avoid extreme permanent power progression.



The game should remain primarily about player knowledge and skill.



\---



\# 20. DATA VERSIONING



Use schema versions.



Example:



```lua

local Data = {

&#x20;   SchemaVersion = 1,



&#x20;   Discoveries = {},

&#x20;   Statistics = {},

&#x20;   Cosmetics = {},

}

```



When changing the schema, implement migration logic.



Never assume old player data matches the newest format.



\---



\# 21. PERFORMANCE



Design around performance from the beginning.



Prioritize:



\* reusable room templates

\* limited active AI

\* controlled particles

\* object cleanup

\* pooling for temporary objects

\* streaming-friendly dungeon construction

\* old-floor cleanup



Never leave previous floors inside Workspace.



\---



\# 22. DEBUG TOOLS



Create internal developer tools early.



Useful commands:



```text

GenerateSeed

JumpFloor

RevealMap

ShowGraph

ShowRule

SpawnEncounter

RestartRun

ValidateFloor

```



Developer commands must be permission-gated or disabled in production.



\---



\# 23. TESTING



\## Unit tests



Test:



\* RNG

\* graph generation

\* room validation

\* rule selection

\* serialization

\* state transitions



\## Integration tests



Test:



\* starting a run

\* generating a floor

\* entering rooms

\* interacting

\* encounters

\* descending

\* failure

\* restart



\## Procedural soak tests



Generate large numbers of floors and check:



\* unreachable rooms

\* unreachable descent

\* overlaps

\* impossible paths

\* excessive encounters

\* missing assets

\* server errors



\---



\# 24. ANALYTICS



Analytics should answer:



> "Why did the player stop having fun?"



Track:



\* session start

\* first interaction

\* first discovery

\* first encounter

\* first floor completion

\* first failure

\* restart

\* depth

\* run duration

\* quit location

\* optional branch selection



Do NOT use analytics to manufacture manipulative engagement systems.



\---



\# 25. ERROR HANDLING



A broken optional system should not destroy the entire run.



Use:



\* defensive checks

\* cleanup handlers

\* safe fallback states

\* timeouts

\* useful warnings



The core dungeon should continue whenever safely possible.



\---



\# 26. IMPLEMENTATION ORDER



\## PHASE 1 — PLAYABLE SKELETON



Implement:



\* movement

\* camera

\* one room

\* one interaction

\* one creature

\* one basic encounter

\* floor transition



Goal:



\*\*A tiny but playable Rogue Abyss.\*\*



\---



\## PHASE 2 — DUNGEON SYSTEM



Implement:



\* logical map

\* seeded generation

\* room templates

\* connections

\* validation

\* landmarks

\* branches



Goal:



\*\*A replayable dungeon.\*\*



\---



\## PHASE 3 — RULE SYSTEM



Implement:



\* floor rules

\* environmental clues

\* rule interactions

\* rule state management



Goal:



\*\*The dungeon starts feeling intelligent.\*\*



\---



\## PHASE 4 — CONTENT



Implement:



\* room archetypes

\* creatures

\* items

\* landmarks

\* secrets

\* environmental interactions



Goal:



\*\*The first ten minutes become genuinely interesting.\*\*



\---



\## PHASE 5 — PRESENTATION



Implement:



\* lighting

\* materials

\* audio

\* VFX

\* UI

\* animation



Goal:



\*\*Rogue Abyss gets its identity.\*\*



\---



\## PHASE 6 — PERSISTENCE



Implement:



\* discoveries

\* run statistics

\* depth records

\* cosmetics

\* data migration



Goal:



\*\*Players have a persistent relationship with the dungeon.\*\*



\---



\## PHASE 7 — POLISH



Perform:



\* procedural testing

\* mobile testing

\* controller testing

\* performance profiling

\* first-session playtesting

\* visual consistency pass

\* audio consistency pass



\---



\# 27. CODE QUALITY RULES



Claude must:



\* use small modules

\* avoid giant scripts

\* avoid global mutable state

\* avoid magic numbers

\* use explicit names

\* separate data from behavior

\* clean up connections

\* validate client input

\* document complex algorithms

\* keep generation testable

\* keep presentation separate from game state



Do not introduce a new framework or abstraction merely because it sounds sophisticated.



Prefer simple systems that are easy to understand.



\---



\# 28. DEFINITION OF DONE



A feature is not done simply because it works once.



It is done when:



\* it works in a fresh server

\* it works after restarting

\* invalid requests fail safely

\* connections are cleaned up

\* generated objects are cleaned up

\* it performs acceptably

\* it fits the art direction

\* it has readable player feedback

\* it contributes to the core gameplay

\* it does not create unnecessary complexity



\---



\# 29. CLAUDE IMPLEMENTATION RULE



When uncertain between:



\*\*more features\*\*



and



\*\*better execution of an existing feature\*\*



choose better execution.



Rogue Abyss should have a smaller number of deeply interacting systems rather than dozens of shallow systems.



