--!strict
-- ClientMain: starts client controllers. The client owns input, camera,
-- UI, local audio, animation and cosmetic effects only (TECH_ARCHITECTURE §16).

local Controllers = script:WaitForChild("Controllers")

local Camera = require(Controllers.CameraController)
local Character = require(Controllers.CharacterController)
local Hud = require(Controllers.Hud)
local Effects = require(Controllers.Effects)
local Feedback = require(Controllers.Feedback)
local Animator = require(Controllers.Animator)
local Atmosphere = require(Controllers.Atmosphere)
local Sanctum = require(Controllers.Sanctum)
local Prompts = require(Controllers.Prompts)
local Input = require(Controllers.InputController)
local Panels = require(Controllers.Panels)

local deps = {
	Camera = Camera,
	Character = Character,
	Hud = Hud,
	Panels = Panels,
	Effects = Effects,
	Feedback = Feedback,
	Animator = Animator,
	Atmosphere = Atmosphere,
	Sanctum = Sanctum,
	Input = Input,
}

Hud.Start(deps)
Camera.Start()
Character.Start()
Animator.Start()
Feedback.Start(deps)
Effects.Start(deps)
Atmosphere.Start()
Sanctum.Start()
Prompts.Start()
Input.Start(deps)
Panels.Start(deps)
