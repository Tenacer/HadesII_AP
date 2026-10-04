---@meta _
---@diagnostic disable: lowercase-global

-- Gathering tools: toolsanity shop checks and tool item delivery.

-- ═══ Data ════════════════════════════════════════════════════════════════════

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

-- ═══ Logic ═══════════════════════════════════════════════════════════════════

-- AP location for a tool shop slot, or nil when toolsanity is off or the slot isn't a tool (tools share the WeaponShop screen).
function H2AP_ToolShopLocation(item_name)
	local settings = H2AP_LoadSettings()
	if settings.toolsanity == 1 then return TOOL_LOCATIONS[item_name] end
	return nil
end

-- Tools: set WeaponsUnlocked only; WorldUpgradesAdded belongs to the shop interception so the slot check stays reachable. Returns nil for other items.
function H2AP_ToolGiveItem(item_name)
	local tool = TOOL_ITEM_TO_NAME[item_name]
	if not tool then return nil end
	GameState.WeaponsUnlocked[tool]         = true
	if CurrentRun then
		CurrentRun.WeaponsUnlocked = CurrentRun.WeaponsUnlocked or {}
		CurrentRun.WeaponsUnlocked[tool] = true
	end
	print("[HadesII_AP] Gave tool: " .. item_name .. " (" .. tool .. ")")
	return true
end

-- ═══ Presentation ════════════════════════════════════════════════════════════

-- Replace tool shop labels in TraitText with the scouted AP item under toolsanity.
function H2AP_ToolRelabelTraitText(data)
	local settings = H2AP_LoadSettings() or {}
	if settings.toolsanity ~= 1 then return end
	local location_items = H2AP_ReadLocationItems() or {}
	for _, entry in ipairs(data.Texts) do
		local ap_location = entry.Id and TOOL_LOCATIONS[entry.Id]
		if ap_location then
			H2AP_ApplyApLocationLabel(entry, ap_location, location_items)
		end
	end
end
