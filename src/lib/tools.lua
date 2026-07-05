---@meta _
---@diagnostic disable: lowercase-global

-- ── Tool unlock tables ────────────────────────────────────────────────────────
-- Under toolsanity, the four gathering tools are AP items/locations checked via the WeaponShop interception.

-- AP item name → game internal tool name (keys match items.csv exactly).
TOOL_ITEM_TO_NAME = {
	["Crescent Pickaxe Tool Unlock"] = "ToolPickaxe",
	["Silver Spade Tool Unlock"]     = "ToolShovel",
	["Tablet of Peace Tool Unlock"]  = "ToolExorcismBook",
	["Rod of Fishing Tool Unlock"]   = "ToolFishingRod",
}

-- Game internal tool name → AP location name (keyed off WeaponShop itemData.Name).
TOOL_LOCATIONS = {
	ToolPickaxe      = "Crescent Pickaxe Tool Unlock Location",
	ToolShovel       = "Silver Spade Tool Unlock Location",
	ToolExorcismBook = "Tablet of Peace Tool Unlock Location",
	ToolFishingRod   = "Rod of Fishing Tool Unlock Location",
}
