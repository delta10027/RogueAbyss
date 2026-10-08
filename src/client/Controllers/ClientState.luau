--!strict
-- Small local store shared by client controllers. Holds the last server
-- snapshot plus purely local choices (selected slot, input mode, aim).
-- Nothing here is authoritative.

local ClientState = {
	Snapshot = nil :: any,
	SelectedSlot = 1,
	InputMode = "Mouse" :: "Mouse" | "Gamepad" | "Touch",
	AimPoint = nil :: Vector3?,
	CameraYaw = 0,
	Creeping = false,
	UIBlocking = false, -- summary / journal open
	Changed = Instance.new("BindableEvent"),
}

function ClientState.Set(snapshot)
	ClientState.Snapshot = snapshot
	ClientState.Changed:Fire()
end

return ClientState
