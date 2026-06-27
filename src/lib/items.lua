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
	-- Incantation: AP-keyed items (surface lock, goal incantations) only flip
	-- the unlock TextLinesRecord flag — the cauldron entry then appears for the
	-- player to brew normally, and brewing applies the vanilla effect + fires
	-- the AP location check via the HandleGhostAdminPurchase wrap.
	-- Non-AP-keyed cauldronsanity incantations (the other 86) get the
	-- WorldUpgrade flag set directly here because the cauldron wrap suppresses
	-- the vanilla effect — this is the only path that grants the effect.
	local wu_key = INCANTATION_KEY_FOR_NAME[item_name]
	if wu_key then
		local settings = H2AP_LoadSettings()
		if H2AP_IsApKeyedIncantation(wu_key, settings) then
			local flag = H2AP_UnlockFlagFor(wu_key)
			GameState.TextLinesRecord = GameState.TextLinesRecord or {}
			GameState.TextLinesRecord[flag] = true
			if CurrentRun and CurrentRun.TextLinesRecord then
				CurrentRun.TextLinesRecord[flag] = true
			end
			print("[HadesII_AP] Incantation cauldron-unlocked: " .. item_name)
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
	-- Keepsakes: track the AP-received unlock in our own GameState field so the
	-- vanilla GiftPresentation flag stays clear. That way GiveGift still calls
	-- PlayerReceivedGiftPresentation when the player gifts the NPC, letting our
	-- ready.lua wrap fire and send the AP location check. CreateKeepsakeIcon
	-- (also wrapped in ready.lua) reads AP_KeepsakeReceived to mark the keepsake
	-- as equipable on the rack.
	local gift_id = KEEPSAKE_GIFT_IDS[item_name]
	if gift_id then
		GameState.AP_KeepsakeReceived = GameState.AP_KeepsakeReceived or {}
		GameState.AP_KeepsakeReceived[gift_id] = true
		print("[HadesII_AP] Gave keepsake: " .. item_name)
		return true
	end
	-- Familiars: grant the companion. FamiliarsUnlocked is the canonical "owns this
	-- familiar" flag everything (kit / traits / codex) keys off, so setting it is the
	-- whole unlock. We also record AP_FamiliarReceived so the recruit wrap (ready.lua)
	-- knows not to undo FamiliarsUnlocked when the player later recruits the wild
	-- familiar for its location check (the item-first case).
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
	-- Tools: grant usability only. HasAccessToTool reads WeaponsUnlocked, so this
	-- alone makes the tool work at gathering nodes. We deliberately do NOT touch
	-- WorldUpgradesAdded — that flag is owned solely by the WeaponShop-purchase
	-- interception (reload.lua), which uses it to retire the shop slot once the AP
	-- location check is fired. Keeping them separate means the shop slot survives
	-- when the item arrives first, so the location check stays reachable either way.
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
	-- Weapons: grant usability only. IsWeaponUnlocked reads WeaponsUnlocked, which
	-- drives kit availability (AssignWeaponKits / UpdateWeaponKits). We deliberately
	-- do NOT touch WorldUpgradesAdded — that flag is owned solely by the WeaponShop-
	-- purchase interception (reload.lua), which uses it to retire the shop slot once
	-- the AP location check fires. Keeping them separate means the shop slot survives
	-- when the item arrives first, so the location check stays reachable either way.
	-- Equipability applies on the next map setup; if the player is already in the
	-- Training Grounds, ActivateWeaponKit makes the kit useable in the live scene.
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
	-- Hidden aspects: grant usability only. WeaponsUnlocked drives both the per-aspect
	-- entry in the upgrade screen (WeaponUpgradeLogic.lua:71) and our overridden
	-- HasAnyAspectUnlocked (reload.lua), which gates the kit's aspect-select prompt.
	-- We deliberately do NOT touch WorldUpgradesAdded — vanilla HasAnyAspectUnlocked
	-- reads it, but our override re-points that to WeaponsUnlocked so the shop slot
	-- (owned by the WeaponShop-purchase interception) survives the item arriving first.
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
	-- Prophecies: grant the same resource the vanilla quest cashout would award.
	-- The CashOutQuest override in reload.lua suppresses the vanilla AddResource,
	-- so this is the sole grant path for prophecy rewards.
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
