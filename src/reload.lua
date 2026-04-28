---@meta _
---@diagnostic disable: lowercase-global

import 'lib/json.lua'
import 'lib/ipc.lua'
import 'lib/settings.lua'
import 'lib/state.lua'
import 'lib/IncantationData.lua'
import 'lib/ItemData.lua'
import 'lib/story.lua'
import 'lib/fear.lua'
import 'lib/items.lua'
import 'lib/score.lua'
import 'lib/death.lua'
import 'lib/inbox.lua'

-- ── AP icon ───────────────────────────────────────────────────────────────────

-- Animation name for our custom AP logo, packed in Tenacer_AP-HadesII_AP.pkg.
AP_ICON_ANIM = _PLUGIN.guid .. "\\ap_icon"

-- Replace the Icon field on every tracked incantation in WorldUpgradeData so
-- the cauldron screen shows the Archipelago logo instead of per-spell artwork.
function ap_patch_incantation_icons()
	if WorldUpgradeData == nil then return end
	for key, _ in pairs(INCANTATION_LOCATIONS) do
		local data = WorldUpgradeData[key]
		if data then
			data.Icon = AP_ICON_ANIM
		end
	end
end

-- Show the AP logo banner when a boss reward location check fires.
-- Uses the same InfoBanner presentation as the cauldron "AP Check Sent" popup.
function ap_show_boss_reward_banner()
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

function sjson_HelpText(data)
	-- Inject the "AP Check Sent" banner title used by the cauldron hook.
	data.Texts[#data.Texts + 1] = { Id = "APCheckSent", DisplayName = "AP Check Sent" }
end
