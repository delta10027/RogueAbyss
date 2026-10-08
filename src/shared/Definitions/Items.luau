--!strict
-- Item definitions. Every item has an obvious use, a secondary use, and a
-- reason to keep it (GAME_DESIGN §16).

export type ItemDef = {
	Id: string,
	Name: string,
	Short: string, -- 1-3 char HUD label
	Description: string,
	Use: "Throw" | "Drink" | "Passive",
	Stackable: boolean,
	Color: Color3,
}

local Items: { [string]: ItemDef } = {
	OilFlask = {
		Id = "OilFlask",
		Name = "Oil Flask",
		Short = "Oil",
		Description = "Throw to burn and light the ground. Press R to refill the lantern instead.",
		Use = "Throw",
		Stackable = false,
		Color = Color3.fromRGB(150, 108, 52),
	},
	TinBell = {
		Id = "TinBell",
		Name = "Tin Bell",
		Short = "Bel",
		Description = "Throw it. It keeps ringing where it lands. It can be picked up again.",
		Use = "Throw",
		Stackable = false,
		Color = Color3.fromRGB(150, 146, 128),
	},
	Tincture = {
		Id = "Tincture",
		Name = "Bitter Tincture",
		Short = "Tnc",
		Description = "Drink to recover two vigor.",
		Use = "Drink",
		Stackable = false,
		Color = Color3.fromRGB(96, 120, 84),
	},
	RustedKey = {
		Id = "RustedKey",
		Name = "Rusted Key",
		Short = "Key",
		Description = "Fits an iron door on this floor. It will not survive the descent.",
		Use = "Passive",
		Stackable = false,
		Color = Color3.fromRGB(128, 84, 58),
	},
}

return Items
