---@meta _
---@diagnostic disable: lowercase-global

-- ── Tool unlock tables ────────────────────────────────────────────────────────
-- Under toolsanity, the four gathering tools are AP items/locations. They share
-- Schelmy's WeaponShop screen, so the location check is fired by the
-- HandleWeaponShopPurchase interception in reload.lua (which also suppresses the
-- vanilla unlock). Maps are symmetric to weapons.lua / WEAPON_LOCATIONS.

-- AP item name → game internal tool name (for H2AP_GiveItem). Keys must match the
-- bare item names from the apworld's items.csv exactly (no " Item" suffix — that
-- suffix only exists on the location names, e.g. "... Tool Unlock Location").
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
