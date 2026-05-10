---@meta _
---@diagnostic disable: lowercase-global

-- ── Item granting ─────────────────────────────────────────────────────────────

function give_item(item_name)
	-- Vow items: reverse_Fear only — unlock a rank of the corresponding shrine vow.
	if get_shrine_for_vow_item(item_name) then
		return give_item_vow(item_name)
	end

	local filler = FILLER_ITEMS[item_name]
	if filler then
		local settings = ap_load_settings()
		local amount = (settings and settings[filler.setting]) or 1
		AddResource(filler.resource, amount, _PLUGIN.guid)
		print("[HadesII_AP] Gave " .. amount .. "x " .. item_name)
		return true
	end
	-- Incantation: unlock the world upgrade and fire its effect.
	local wu_key = INCANTATION_KEY_FOR_NAME[item_name]
	if wu_key then
		-- Set flags directly rather than via UnlockWorldUpgrade, because
		-- UnlockWorldUpgrade skips WorldUpgrades[name]=true if WorldUpgradesAdded
		-- is already set (which it is after a cauldronsanity AP purchase).
		GameState.WorldUpgrades[wu_key]         = true
		GameState.WorldUpgradesAdded[wu_key]    = true
		GameState.WorldUpgradesViewed[wu_key]   = true
		GameState.WorldUpgradesRevealed[wu_key] = true
		-- Fire the upgrade's effect (opens shops, unlocks systems, etc.).
		local itemData = WorldUpgradeData and WorldUpgradeData[wu_key]
		if itemData and itemData.OnActivateFinishedFunctionName then
			pcall(CallFunctionName, itemData.OnActivateFinishedFunctionName, itemData.OnActivateFinishedFunctionArgs)
		end
		print("[HadesII_AP] Incantation unlocked: " .. item_name)
		return true
	end
	-- True Ending ingredients: grant the resource and let sync_story_flags handle flags.
	if item_name == "Zodiac Sand" then
		AddResource("MixerIBoss", 1, _PLUGIN.guid)
		print("[HadesII_AP] Gave Zodiac Sand (MixerIBoss)")
		return true
	end
	if item_name == "Void Lens" then
		AddResource("MixerQBoss", 1, _PLUGIN.guid)
		print("[HadesII_AP] Gave Void Lens (MixerQBoss)")
		return true
	end
	if item_name == "Gigaros" then
		AddResource("HadesSpearPoints", 1, _PLUGIN.guid)
		print("[HadesII_AP] Gave Gigaros (HadesSpearPoints)")
		return true
	end
	-- Goal incantations: unlock the WorldUpgrade when received from AP.
	if item_name == "Dissolution of Time" then
		GameState.WorldUpgradesViewed["WorldUpgradeTimeStop"]   = true
		GameState.WorldUpgradesRevealed["WorldUpgradeTimeStop"] = true
		UnlockWorldUpgrade("WorldUpgradeTimeStop")
		local itemData = WorldUpgradeData and WorldUpgradeData["WorldUpgradeTimeStop"]
		if itemData and itemData.OnActivateFinishedFunctionName then
			-- UnblockHubExitForNarrative touches MapState — safe only in the hub.
			pcall(CallFunctionName, itemData.OnActivateFinishedFunctionName, itemData.OnActivateFinishedFunctionArgs)
		end
		print("[HadesII_AP] Gave Dissolution of Time (WorldUpgradeTimeStop)")
		return true
	end
	if item_name == "Disintegration of Monstrosity" then
		GameState.WorldUpgradesViewed["WorldUpgradeStormStop"]   = true
		GameState.WorldUpgradesRevealed["WorldUpgradeStormStop"] = true
		UnlockWorldUpgrade("WorldUpgradeStormStop")
		print("[HadesII_AP] Gave Disintegration of Monstrosity (WorldUpgradeStormStop)")
		return true
	end
	-- Keepsakes: unlock immediately in the equip screen so the player can equip
	-- the keepsake as soon as it's received from AP. The ReceivedGiftPresentation
	-- hook in reload.lua sends the AP location check when the player actually gifts
	-- the NPC (keepsakesanity mode), firing before GiftLogic's GiftPresentation check.
	local gift_id = KEEPSAKE_GIFT_IDS[item_name]
	if gift_id then
		GameState.GiftPresentation = GameState.GiftPresentation or {}
		GameState.NewKeepsakeItem  = GameState.NewKeepsakeItem  or {}
		GameState.NewKeepsakeItem[gift_id] = true
		GameState.GiftPresentation[gift_id] = true
		print("[HadesII_AP] Gave keepsake: " .. item_name)
		return true
	end
	-- Weapons: set every flag the game uses for unlock detection. Equipability in
	-- the Training Grounds applies on the next map setup; if the player is already
	-- there, ActivateWeaponKit makes the kit useable in the live scene.
	local weapon = WEAPON_ITEM_TO_NAME and WEAPON_ITEM_TO_NAME[item_name]
	if weapon then
		GameState.WeaponsUnlocked[weapon]        = true
		GameState.WeaponsTouched[weapon]         = true
		GameState.WorldUpgrades[weapon]          = true
		GameState.WorldUpgradesAdded[weapon]     = true
		GameState.WorldUpgradesViewed[weapon]    = true
		GameState.WorldUpgradesRevealed[weapon]  = true
		if CurrentRun then
			CurrentRun.WeaponsUnlocked = CurrentRun.WeaponsUnlocked or {}
			CurrentRun.WeaponsUnlocked[weapon] = true
			CurrentRun.WorldUpgradesAdded = CurrentRun.WorldUpgradesAdded or {}
			CurrentRun.WorldUpgradesAdded[weapon] = true
		end
		pcall(function()
			local kit = GetWeaponKit and GetWeaponKit(weapon)
			if kit then
				kit.OnUsedFunctionName = "UseWeaponKit"
				if SetWeaponKitUseText then SetWeaponKitUseText(kit) end
				UseableOn({ Id = kit.ObjectId })
				SetAlpha({ Id = kit.ObjectId, Fraction = 1.0 })
			end
		end)
		print("[HadesII_AP] Gave weapon: " .. item_name .. " (" .. weapon .. ")")
		return true
	end
	-- Hidden aspects: WeaponsUnlocked drives the aspect equip screen
	-- (WeaponUpgradeLogic.lua:71); WorldUpgradesAdded drives HasAnyAspectUnlocked
	-- which gates the kit's aspect-select prompt.
	local aspect = HIDDEN_ASPECT_ITEM_TO_NAME and HIDDEN_ASPECT_ITEM_TO_NAME[item_name]
	if aspect then
		GameState.WeaponsUnlocked[aspect]        = true
		GameState.WorldUpgrades[aspect]          = true
		GameState.WorldUpgradesAdded[aspect]     = true
		GameState.WorldUpgradesViewed[aspect]    = true
		GameState.WorldUpgradesRevealed[aspect]  = true
		if CurrentRun then
			CurrentRun.WeaponsUnlocked = CurrentRun.WeaponsUnlocked or {}
			CurrentRun.WeaponsUnlocked[aspect] = true
			CurrentRun.WorldUpgradesAdded = CurrentRun.WorldUpgradesAdded or {}
			CurrentRun.WorldUpgradesAdded[aspect] = true
		end
		print("[HadesII_AP] Gave hidden aspect: " .. item_name .. " (" .. aspect .. ")")
		return true
	end
	-- Unknown item — log and advance items_index so it isn't re-processed.
	print("[HadesII_AP] Received (pending implementation): " .. tostring(item_name))
	return true
end
