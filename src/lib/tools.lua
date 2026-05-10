---@meta _
---@diagnostic disable: lowercase-global

-- ── Tool unlock tables ────────────────────────────────────────────────────────
-- Tools are always in the AP item/location pool (no toolsanity option yet).
-- Maps are symmetric to weapons.lua / WEAPON_LOCATIONS.

-- AP item name → game internal tool name (for give_item).
TOOL_ITEM_TO_NAME = {
	["Crescent Pickaxe Tool Unlock Item"] = "ToolPickaxe",
	["Silver Spade Tool Unlock Item"]     = "ToolShovel",
	["Tablet of Peace Tool Unlock Item"]  = "ToolExorcismBook",
	["Rod of Fishing Tool Unlock Item"]   = "ToolFishingRod",
}

-- Game internal tool name → AP location name (for ap_check_tool_unlocks).
TOOL_LOCATIONS = {
	ToolPickaxe      = "Crescent Pickaxe Tool Unlock Location",
	ToolShovel       = "Silver Spade Tool Unlock Location",
	ToolExorcismBook = "Tablet of Peace Tool Unlock Location",
	ToolFishingRod   = "Rod of Fishing Tool Unlock Location",
}

-- Polled from prefix_SetupMap: send the AP location check for any tool that's
-- currently unlocked but hasn't been reported yet. Covers both unlock paths —
-- the player buying the tool at Skelly's shop, and give_item granting the
-- tool when the AP item arrives. ap_check_location is idempotent.
function ap_check_tool_unlocks()
	if not GameState or not GameState.WeaponsUnlocked then return end
	for tool, location in pairs(TOOL_LOCATIONS) do
		if GameState.WeaponsUnlocked[tool] then
			ap_check_location(location)
		end
	end
end
