--!strict
-- ClientMain: starts client controllers. The client owns input, camera,
-- UI, local audio and cosmetic effects only (TECH_ARCHITECTURE §16).

local Controllers = script:WaitForChild("Controllers")

local Camera = require(Controllers.CameraController)
local Character = require(Controllers.CharacterController)
local Hud = require(Controllers.Hud)
local Effects = require(Controllers.Effects)
local Prompts = require(Controllers.Prompts)
local Input = require(Controllers.InputController)
local Panels = require(Controllers.Panels)

local deps = {
	Camera = Camera,
	Character = Character,
	Hud = Hud,
	Panels = Panels,
	Effects = Effects,
	Input = Input,
}

Hud.Start(deps)
Panels.Start(deps)
Camera.Start()
Character.Start()
Effects.Start(deps)
Prompts.Start()
Input.Start(deps)
