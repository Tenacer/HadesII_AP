---@meta _
---@diagnostic disable: lowercase-global

-- ── Item granting ─────────────────────────────────────────────────────────────

function H2AP_GiveItem(item_name)
	-- Vow items: reverse_Fear only — unlock a rank of the corresponding shrine vow.
	if H2AP_GetShrineForVowItem(item_name) then
		return H2AP_GiveItemVow(item_name)
	end

	-- Traps: queue mid-run effects (drained from H2AP_SetupMap).
	if TRAP_ITEMS and TRAP_ITEMS[item_name] then
		return H2AP_GiveItemTrap(item_name)
	end

	-- Helpers: persistent stat boosts (MaxHealth, InitialMoney, BoonBoost).
	if HELPER_ITEMS and HELPER_ITEMS[item_name] then
		return H2AP_GiveItemHelper(item_name)
	end

	local filler = FILLER_ITEMS[item_name]
	if filler then
		local settings = H2AP_LoadSettings()
		local amount = (settings and settings[filler.setting]) or 1
		AddResource(filler.resource, amount, _PLUGIN.guid)
		print("[HadesII_AP] Gave " .. amount .. "x " .. item_name)
		return true
	end
	-- Incantations deliver their effect from the received AP item; the location check fires on brew.
	local wu_key = INCANTATION_KEY_FOR_NAME[item_name]
	if wu_key then
		local settings = H2AP_LoadSettings()
		if H2AP_IsApKeyedIncantation(wu_key, settings) then
			-- Surface-lock: grant only WorldUpgrades so the brew/story sequence stays alive; SurfacePenaltyCure also needs WorldUpgradesAdded since part of its cure is gated on it.
			GameState.WorldUpgrades[wu_key]       = true
			GameState.WorldUpgradesViewed[wu_key] = true
			if wu_key == "WorldUpgradeSurfacePenaltyCure" then
				GameState.WorldUpgradesAdded[wu_key]    = true
				GameState.WorldUpgradesRevealed[wu_key] = true
				if CurrentRun and CurrentRun.WorldUpgradesAdded then
					CurrentRun.WorldUpgradesAdded[wu_key] = true
				end
			end
			print("[HadesII_AP] Incantation effect granted: " .. item_name)
			return true
		end
		-- Cauldronsanity 86: apply effect directly (vanilla brew is suppressed).
		GameState.WorldUpgrades[wu_key]         = true
		GameState.WorldUpgradesAdded[wu_key]    = true
		GameState.WorldUpgradesViewed[wu_key]   = true
		GameState.WorldUpgradesRevealed[wu_key] = true
		local itemData = WorldUpgradeData and WorldUpgradeData[wu_key]
		if itemData and itemData.OnActivateFinishedFunctionName then
			pcall(CallFunctionName, itemData.OnActivateFinishedFunctionName, itemData.OnActivateFinishedFunctionArgs)
		end
		print("[HadesII_AP] Incantation unlocked: " .. item_name)
		return true
	end
	-- True Ending ingredients: grant the resource and let H2AP_SyncStoryFlags handle flags.
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
	if item_name == "Entropy" then
		AddResource("MixerMythic", 1, _PLUGIN.guid)
		print("[HadesII_AP] Gave Entropy (MixerMythic)")
		return true
	end
	-- Keepsakes: track the AP unlock in AP_KeepsakeReceived so GiftPresentation stays clear and the gifting check remains reachable.
	local gift_id = KEEPSAKE_GIFT_IDS[item_name]
	if gift_id then
		GameState.AP_KeepsakeReceived = GameState.AP_KeepsakeReceived or {}
		GameState.AP_KeepsakeReceived[gift_id] = true
		print("[HadesII_AP] Gave keepsake: " .. item_name)
		return true
	end
	-- Familiars: set FamiliarsUnlocked (the whole unlock) and record AP_FamiliarReceived so a later recruit doesn't undo it.
	local familiar = FAMILIAR_ITEM_TO_NAME and FAMILIAR_ITEM_TO_NAME[item_name]
	if familiar then
		GameState.AP_FamiliarReceived = GameState.AP_FamiliarReceived or {}
		GameState.AP_FamiliarReceived[familiar] = true
		GameState.FamiliarsUnlocked = GameState.FamiliarsUnlocked or {}
		GameState.FamiliarsUnlocked[familiar] = true
		if CurrentRun then
			CurrentRun.FamiliarsUnlocked = CurrentRun.FamiliarsUnlocked or {}
			CurrentRun.FamiliarsUnlocked[familiar] = true
		end
		print("[HadesII_AP] Gave familiar: " .. item_name .. " (" .. familiar .. ")")
		return true
	end
	-- Tools: set WeaponsUnlocked only; WorldUpgradesAdded belongs to the shop interception so the slot check stays reachable.
	local tool = TOOL_ITEM_TO_NAME and TOOL_ITEM_TO_NAME[item_name]
	if tool then
		GameState.WeaponsUnlocked[tool]         = true
		if CurrentRun then
			CurrentRun.WeaponsUnlocked = CurrentRun.WeaponsUnlocked or {}
			CurrentRun.WeaponsUnlocked[tool] = true
		end
		print("[HadesII_AP] Gave tool: " .. item_name .. " (" .. tool .. ")")
		return true
	end
	-- Weapons: set WeaponsUnlocked only (same shop-slot reasoning as tools), then refresh the live kit if the player is at it.
	local weapon = WEAPON_ITEM_TO_NAME and WEAPON_ITEM_TO_NAME[item_name]
	if weapon then
		GameState.WeaponsUnlocked[weapon]        = true
		GameState.WeaponsTouched[weapon]         = true
		if CurrentRun then
			CurrentRun.WeaponsUnlocked = CurrentRun.WeaponsUnlocked or {}
			CurrentRun.WeaponsUnlocked[weapon] = true
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
	-- Hidden aspects: set WeaponsUnlocked only (same shop-slot reasoning as tools).
	local aspect = HIDDEN_ASPECT_ITEM_TO_NAME and HIDDEN_ASPECT_ITEM_TO_NAME[item_name]
	if aspect then
		GameState.WeaponsUnlocked[aspect]        = true
		if CurrentRun then
			CurrentRun.WeaponsUnlocked = CurrentRun.WeaponsUnlocked or {}
			CurrentRun.WeaponsUnlocked[aspect] = true
		end
		-- Refresh the kit's aspect prompt if the player is at the kit when it arrives.
		pcall(function() if UpdateWeaponKits then UpdateWeaponKits() end end)
		print("[HadesII_AP] Gave hidden aspect: " .. item_name .. " (" .. aspect .. ")")
		return true
	end
	-- Prophecies: grant the resource the vanilla cashout would have awarded.
	local quest_id = PROPHECY_QUEST_FOR_ITEM and PROPHECY_QUEST_FOR_ITEM[item_name]
	if quest_id then
		local questData = QuestData and QuestData[quest_id]
		local resource = questData and questData.RewardResourceName
		local amount = questData and questData.RewardResourceAmount
		if resource and amount then
			AddResource(resource, amount, _PLUGIN.guid, { SkipVoiceLines = true })
			print("[HadesII_AP] Gave prophecy reward: " .. item_name
				.. " (" .. amount .. "x " .. resource .. ")")
		else
			print("[HadesII_AP] Prophecy reward missing data: " .. item_name
				.. " (quest=" .. tostring(quest_id) .. ")")
		end
		return true
	end
	-- Unknown item — log and advance items_index so it isn't re-processed.
	print("[HadesII_AP] Received (pending implementation): " .. tostring(item_name))
	return true
end
