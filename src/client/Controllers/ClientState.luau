--!strict
-- Small local store shared by client controllers. Holds the last server
-- snapshot plus purely local choices (selected slot, input mode, aim, which
-- panel is open). Nothing here is authoritative.

local ClientState = {
	Snapshot = nil :: any,
	SelectedSlot = 1,
	InputMode = "Mouse" :: "Mouse" | "Gamepad" | "Touch",
	AimPoint = nil :: Vector3?,
	CameraYaw = 0,
	Creeping = false,
	UIBlocking = false, -- a menu or panel is open; gameplay input is ignored
	Panel = nil :: string?, -- "Inventory" | "Journal" | "Pause" | "Menu" | "Summary" | "Perks" | "Create"
	InRun = false,
	CameraOverride = false, -- the menu scene owns the camera
	CooldownEnds = {} :: { [string]: number },
	LastConfig = nil :: any, -- the last character made (for "play again")
	Changed = Instance.new("BindableEvent"),
	VitalsChanged = Instance.new("BindableEvent"),
}

function ClientState.Set(snapshot)
	ClientState.Snapshot = snapshot
	local now = os.clock()
	local ends = {}
	for id, remaining in snapshot.Cooldowns or {} do
		ends[id] = now + remaining
	end
	-- Keep locally predicted cooldowns that the server hasn't confirmed yet.
	for id, t in ClientState.CooldownEnds do
		if not ends[id] and t > now and t - now < 1.5 then
			ends[id] = t
		end
	end
	ClientState.CooldownEnds = ends
	ClientState.Changed:Fire()
end

-- Frequent small updates for the bars.
function ClientState.SetVitals(v)
	local snap = ClientState.Snapshot
	if not snap then
		return
	end
	for k, val in v do
		snap[k] = val
	end
	ClientState.VitalsChanged:Fire()
end

function ClientState.SetPanel(panel: string?)
	ClientState.Panel = panel
	ClientState.UIBlocking = panel ~= nil
	ClientState.Changed:Fire()
end

function ClientState.CooldownLeft(id: string): number
	return math.max(0, (ClientState.CooldownEnds[id] or 0) - os.clock())
end

return ClientState
