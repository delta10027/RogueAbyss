--!strict
-- Custom rendering for ProximityPrompts: a small dark tag beside the
-- object instead of Roblox's default bubble (ART_BIBLE §19). Touch players
-- can tap the tag to trigger it.

local ProximityPromptService = game:GetService("ProximityPromptService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local UiKit = require(script.Parent.UiKit)
local ClientState = require(script.Parent.ClientState)

local C = UiKit.Colors

local Prompts = {}

local function keyLabel(prompt: ProximityPrompt): string
	if ClientState.InputMode == "Gamepad" then
		return "X"
	elseif ClientState.InputMode == "Touch" then
		return "tap"
	end
	return prompt.KeyboardKeyCode.Name
end

function Prompts.Start()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
		if prompt.Style ~= Enum.ProximityPromptStyle.Custom then
			return
		end
		local bb = Instance.new("BillboardGui")
		bb.Name = "PromptTag"
		bb.AlwaysOnTop = true
		bb.Size = UDim2.fromOffset(220, 30)
		bb.StudsOffset = Vector3.new(0, 2.6, 0)
		bb.LightInfluence = 0
		bb.Adornee = prompt.Parent :: Instance
		bb.Parent = playerGui
		local button = Instance.new("TextButton")
		button.AutomaticSize = Enum.AutomaticSize.X
		button.AnchorPoint = Vector2.new(0.5, 0.5)
		button.Position = UDim2.fromScale(0.5, 0.5)
		button.Size = UDim2.fromOffset(0, 26)
		button.BackgroundColor3 = C.Ink
		button.BackgroundTransparency = 0.2
		button.BorderSizePixel = 0
		button.AutoButtonColor = false
		button.FontFace = UiKit.Body
		button.TextSize = 16
		button.TextColor3 = C.Text
		button.Text = string.format("  %s  %s · %s  ", keyLabel(prompt), prompt.ActionText, prompt.ObjectText)
		button.Parent = bb
		UiKit.Stroke(button, C.LineDim, 1)
		button.Activated:Connect(function()
			if inputType == Enum.ProximityPromptInputType.Touch or UserInputService.TouchEnabled then
				prompt:InputHoldBegin()
				task.wait()
				prompt:InputHoldEnd()
			end
		end)
		local hidden
		hidden = prompt.PromptHidden:Connect(function()
			hidden:Disconnect()
			bb:Destroy()
		end)
		prompt.Destroying:Once(function()
			if bb.Parent then
				bb:Destroy()
			end
		end)
	end)
end

return Prompts
