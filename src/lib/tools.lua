---@meta _
---@diagnostic disable: lowercase-global

-- ── Tool unlock tables ────────────────────────────────────────────────────────
-- Tools are always in the AP item/location pool (no toolsanity option yet).
-- Maps are symmetric to weapons.lua / WEAPON_LOCATIONS.

-- AP item name → game internal tool name (for H2AP_GiveItem).
TOOL_ITEM_TO_NAME = {
	["Crescent Pickaxe Tool Unlock Item"] = "ToolPickaxe",
	["Silver Spade Tool Unlock Item"]     = "ToolShovel",
	["Tablet of Peace Tool Unlock Item"]  = "ToolExorcismBook",
	["Rod of Fishing Tool Unlock Item"]   = "ToolFishingRod",
}

-- Game internal tool name → AP location name (for H2AP_CheckToolUnlocks).
TOOL_LOCATIONS = {
	ToolPickaxe      = "Crescent Pickaxe Tool Unlock Location",
	ToolShovel       = "Silver Spade Tool Unlock Location",
	ToolExorcismBook = "Tablet of Peace Tool Unlock Location",
	ToolFishingRod   = "Rod of Fishing Tool Unlock Location",
}

-- Polled from H2AP_SetupMap: send the AP location check for any tool that's
-- currently unlocked but hasn't been reported yet. Covers both unlock paths —
-- the player buying the tool at Skelly's shop, and H2AP_GiveItem granting the
-- tool when the AP item arrives. H2AP_CheckLocation is idempotent.
function H2AP_CheckToolUnlocks()
	if not GameState or not GameState.WeaponsUnlocked then return end
	for tool, location in pairs(TOOL_LOCATIONS) do
		if GameState.WeaponsUnlocked[tool] then
			H2AP_CheckLocation(location)
		end
	end
end
