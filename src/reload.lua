---@meta _
---@diagnostic disable: lowercase-global

-- Hot-reloadable AP-icon / text-label helpers and SJSON hook handlers; library modules import from ready.lua / ready_late.lua instead.

-- ── AP icon ───────────────────────────────────────────────────────────────────

-- Animation name for our custom AP logo, packed in Tenacer_AP-HadesII_AP.pkg.
AP_ICON_ANIM = _PLUGIN.guid .. "\\ap_icon"

-- Show the Archipelago logo instead of per-spell artwork on every AP-controlled incantation.
function H2AP_PatchIncantationIcons()
	if WorldUpgradeData == nil then return end
	local settings = H2AP_LoadSettings() or {}
	local do_cauldron = settings.cauldronsanity == 1
	for key, _ in pairs(INCANTATION_LOCATIONS) do
		local data = WorldUpgradeData[key]
		if data then
			local is_ap = H2AP_IsApKeyedIncantation(key, settings)
				or (do_cauldron and not H2AP_IsSurfaceLockIncantation(key)
					and not H2AP_IsGoalIncantation(key))
			if is_ap then
				data.Icon = AP_ICON_ANIM
			end
		end
	end
end

-- ── Surface-lock incantation model (effect-on-receive, check-on-brew) ─────────

-- Widen Moros' reveal requirement so a player already cured by the AP item can still trigger the Unraveling recipe reveal; re-applied each room since the game reloads NamedRequirementsData.
function H2AP_PatchSurfaceIncantationReveal()
	if NamedRequirementsData == nil or NamedRequirementsData._ap_moros_reveal_patched then return end
	local settings = H2AP_LoadSettings() or {}
	if settings.lock_surface_incantations ~= 1 then return end
	-- OrRequirements must sit at the top level; net effect is (cursed OR reached-surface-this-run) AND the untouched clauses.
	NamedRequirementsData.MorosFirstSurfaceAppearance = {
		OrRequirements = {
			{ { Path = { "CurrentRun", "Hero", "TraitDictionary" }, HasAny = { "SurfacePenalty" } } },
			{ { Path = { "CurrentRun", "BiomesReached" }, HasAny = { "N" } } },
		},
		{ PathTrue = { "GameState", "TextLinesRecord", "MorosSecondAppearance" } },
		{ PathFalse = { "CurrentRun", "WorldUpgradesAdded", "WorldUpgradeMorosUnlock" } },
	}
	NamedRequirementsData._ap_moros_reveal_patched = true
end

-- Temporarily mask WorldUpgradesAdded to the AP-checked truth while the cauldron builds its offer list; returns a save-list for the unmask.
function H2AP_MaskSurfaceIncantationsForOffer(settings)
	local saved = {}
	if not (GameState and GameState.WorldUpgradesAdded) then return saved end
	local checked = GameState.AP_SurfaceIncantationChecked or {}
	for key in pairs(SURFACE_LOCK_INCANTATION_KEYS) do
		if H2AP_IsApKeyedIncantation(key, settings) then
			saved[#saved + 1] = { key = key, orig = GameState.WorldUpgradesAdded[key] }
			GameState.WorldUpgradesAdded[key] = checked[key] or nil
		end
	end
	return saved
end

function H2AP_UnmaskSurfaceIncantations(saved)
	if not (GameState and GameState.WorldUpgradesAdded) then return end
	for _, e in ipairs(saved) do
		GameState.WorldUpgradesAdded[e.key] = e.orig
	end
end

-- Rewrite the goal incantations' brewing costs to match the per-seed thresholds.
function H2AP_PatchIncantationCosts()
	if WorldUpgradeData == nil then return end
	local settings = H2AP_LoadSettings() or {}
	if settings.true_ending ~= 1 then return end
	local zsand = tonumber(settings.zodiac_sand_needed) or 4
	local vlens = tonumber(settings.void_lens_needed) or 2
	local d = WorldUpgradeData["WorldUpgradeTimeStop"]
	if d and not d._ap_cost_patched then
		d.Cost = { MixerIBoss = zsand, MixerMythic = 1 }
		d._ap_cost_patched = true
	end
	local s = WorldUpgradeData["WorldUpgradeStormStop"]
	if s and not s._ap_cost_patched then
		s.Cost = { MixerQBoss = vlens, HadesSpearPoints = 1 }
		s._ap_cost_patched = true
	end
end

-- Show the AP logo banner when a keepsake gifting location check fires.
function H2AP_ShowKeepsakeCheckBanner(npc)
	thread(function()
		AdjustColorGrading({ Name = "Mythmaker", Duration = 0.66 })
		PlaySound({ Name = "/Leftovers/Menu Sounds/StarSelectConfirm" })
		thread(PlayVoiceLines, npc.GiftGivenVoiceLines, true)
		thread(PlayVoiceLines, CurrentRun.Hero.GiftReceivedVoiceLines, true)
		DisplayInfoBanner(nil, {
			Icon = AP_ICON_ANIM,
			IconScale = 1.3,
			IconMoveSpeed = 0.00001,
			IconOffsetY = 6,
			HighlightIcon = true,
			TitleText = "APCheckSent",
			FontScale = 0.82,
			AnimationName = "InfoBannerGiftIn",
			AnimationOutName = "InfoBannerGiftOut",
			IconBackingAnimationName = "LocationBackingIrisSmallSubtitleIn",
			IconBackingAnimationOutName = "LocationBackingIrisSmallSubtitleOut",
			IconBackingColor = Color.Lavender,
			IconBackingHSV = { 0.25, -0.2, 0.1 },
		})
		thread(function()
			wait(1.0)
			AdjustColorGrading({ Name = "Off", Duration = 1.0 })
		end)
		if CheckObjectiveSet("KeepsakePrompt") then
			UpdateAffordabilityStatus()
		end
	end)
end

-- Show the AP logo banner when a boss reward location check fires.
function H2AP_ShowBossRewardBanner()
	thread(function()
		DisplayInfoBanner(nil, {
			TitleText = "APCheckSent",
			FontScale = 0.82,
			Icon = AP_ICON_ANIM,
			IconScale = 1.3,
			IconMoveSpeed = 0.00001,
			IconOffsetY = 6,
			AnimationName = "InfoBannerCauldronIn",
			AnimationOutName = "InfoBannerCauldronOut",
			IconBackingAnimationName = "LocationBackingIrisSmallSubtitleIn",
			IconBackingAnimationOutName = "LocationBackingIrisSmallSubtitleOut",
		})
	end)
end

-- ── SJSON hook handlers ───────────────────────────────────────────────────────

function sjson_ShellText(data)
	for _, v in ipairs(data.Texts) do
		if v.Id == 'MainMenuScreen_PlayGame' then
			v.DisplayName = 'Play Hades II AP'
			break
		end
	end
end

-- Rewrite a text entry to advertise the scouted AP item at `ap_location`, preserving the vanilla name/description.
function H2AP_ApplyApLocationLabel(entry, ap_location, location_items)
	local item_entry = location_items[ap_location]
	local display = "AP Location Check"
	if type(item_entry) == "table" then
		display = item_entry.display or item_entry.item_name or display
	elseif type(item_entry) == "string" then
		-- Back-compat with the older flat string format.
		display = item_entry
	end
	local vanilla_name = entry.DisplayName
	local vanilla_desc = entry.Description
	local opener = (vanilla_name and vanilla_name ~= "") and vanilla_name or display
	local new_desc = "Archipelago location check for " .. opener .. "."
	if vanilla_desc and vanilla_desc ~= "" then
		new_desc = new_desc .. "\n\nOriginal: " .. vanilla_desc
	end
	entry.DisplayName = display
	entry.Description = new_desc
end

function sjson_HelpText(data)
	-- Inject the "AP Check Sent" banner title used by the cauldron hook.
	data.Texts[#data.Texts + 1] = { Id = "APCheckSent", DisplayName = "AP Check Sent" }

	-- Replace incantation / prophecy entries with AP info when their sanity option is on (weapon/tool/aspect labels live in TraitText).
	local settings = H2AP_LoadSettings() or {}
	local do_cauldron = settings.cauldronsanity == 1
	local do_fate = settings.fatesanity == 1
	local keyed = H2AP_KeyedIncantations(settings)
	local has_keyed = next(keyed) ~= nil
	if not (do_cauldron or do_fate or has_keyed) then return end

	local location_items = H2AP_ReadLocationItems() or {}

	-- Resolve an incantation key to its AP location name, only when AP-controlled under the current settings.
	local function incantation_location_for(id)
		if keyed[id] then return INCANTATION_LOCATIONS[id] end
		if do_cauldron
			and not H2AP_IsSurfaceLockIncantation(id)
			and not H2AP_IsGoalIncantation(id) then
			return INCANTATION_LOCATIONS[id]
		end
		return nil
	end

	for _, entry in ipairs(data.Texts) do
		local id = entry.Id
		if id then
			local ap_location = incantation_location_for(id)
				or (do_fate and PROPHECY_LOCATIONS[id])
			if ap_location then
				H2AP_ApplyApLocationLabel(entry, ap_location, location_items)
			else
				local base_id = id:match("^(.-)_Flavor$")
				local new_desc = ""
				if base_id and incantation_location_for(base_id) then
					local vanilla_flavor = entry.Description
					if vanilla_flavor and vanilla_flavor ~= "" then
						new_desc = "\n\nOriginal: " .. vanilla_flavor
					end
					entry.Description = new_desc
				end
			end
		end
	end
end

-- initial_weapon slot value → internal weapon name; kept local because the SJSON hooks can fire before lib/weapons.lua loads.
local STARTING_WEAPON_NAMES = {
	[0] = "WeaponStaffSwing",
	[1] = "WeaponDagger",
	[2] = "WeaponTorch",
	[3] = "WeaponAxe",
	[4] = "WeaponLob",
	[5] = "WeaponSuit",
}

function sjson_TraitText(data)
	local settings = H2AP_LoadSettings() or {}
	local do_weapon = settings.weaponsanity == 1
	local do_tool = settings.toolsanity == 1
	local do_aspect = settings.hidden_aspectsanity == 1
	if not (do_weapon or do_tool or do_aspect) then return end

	-- The starting weapon's shop slot is not an AP check, so keep its vanilla name.
	local start_weapon = STARTING_WEAPON_NAMES[settings.initial_weapon or 0]

	local location_items = H2AP_ReadLocationItems() or {}
	for _, entry in ipairs(data.Texts) do
		local id = entry.Id
		if id then
			local ap_location = (do_weapon and id ~= start_weapon and WEAPON_LOCATIONS[id])
				or (do_tool and TOOL_LOCATIONS[id])
				or (do_aspect and HIDDEN_ASPECT_LOCATIONS[id])
			if ap_location then
				H2AP_ApplyApLocationLabel(entry, ap_location, location_items)
			end
		end
	end
end
