---@meta _
---@diagnostic disable: lowercase-global

-- ── Tool unlock tables ────────────────────────────────────────────────────────
-- Under toolsanity, the four gathering tools are AP items/locations. They share
-- Schelmy's WeaponShop screen, so the location check is fired by the
-- HandleWeaponShopPurchase interception in reload.lua (which also suppresses the
-- vanilla unlock). Maps are symmetric to weapons.lua / WEAPON_LOCATIONS.

-- AP item name → game internal tool name (for H2AP_GiveItem).
TOOL_ITEM_TO_NAME = {
	["Crescent Pickaxe Tool Unlock Item"] = "ToolPickaxe",
	["Silver Spade Tool Unlock Item"]     = "ToolShovel",
	["Tablet of Peace Tool Unlock Item"]  = "ToolExorcismBook",
	["Rod of Fishing Tool Unlock Item"]   = "ToolFishingRod",
}

-- Game internal tool name → AP location name (keyed off WeaponShop itemData.Name).
TOOL_LOCATIONS = {
	ToolPickaxe      = "Crescent Pickaxe Tool Unlock Location",
	ToolShovel       = "Silver Spade Tool Unlock Location",
	ToolExorcismBook = "Tablet of Peace Tool Unlock Location",
	ToolFishingRod   = "Rod of Fishing Tool Unlock Location",
}
