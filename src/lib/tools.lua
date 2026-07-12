---@meta _
---@diagnostic disable: lowercase-global

-- ── Tool unlock tables ────────────────────────────────────────────────────────
-- Under toolsanity, the four gathering tools are AP items/locations checked via the WeaponShop interception.

-- AP item name → game internal tool name (keys match items.csv exactly).
TOOL_ITEM_TO_NAME = {
	["Crescent Pickaxe"] = "ToolPickaxe",
	["Silver Spade"]     = "ToolShovel",
	["Tablet of Peace"]  = "ToolExorcismBook",
	["Rod of Fishing"]   = "ToolFishingRod",
}

-- Game internal tool name → AP location name (keyed off WeaponShop itemData.Name).
TOOL_LOCATIONS = {
	ToolPickaxe      = "Crescent Pickaxe",
	ToolShovel       = "Silver Spade",
	ToolExorcismBook = "Tablet of Peace",
	ToolFishingRod   = "Rod of Fishing",
}
