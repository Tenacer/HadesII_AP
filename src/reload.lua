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
import 'lib/weapons.lua'

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

-- Show the AP logo banner when a keepsake gifting location check fires.
-- Mirrors PlayerReceivedGiftPresentation's sound/voice/color-grading but
-- uses the AP logo and gift-style banner animations instead of the vanilla keepsake icon.
function ap_show_keepsake_check_banner(npc)
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

-- ── Keepsakesanity gifting hook ───────────────────────────────────────────────

-- Hook ReceivedGiftPresentation (called in GiveGift before the GiftPresentation
-- check) to send AP location checks in keepsakesanity mode. This fires regardless
-- of whether give_item already set GiftPresentation, which means we always catch
-- the gifting event and can send the check even if the keepsake was AP-received first.
-- Uses direct Lua replacement (no modutil wrap) to avoid the GC crash on game reset.
if not _ap_orig_ReceivedGiftPresentation then
    _ap_orig_ReceivedGiftPresentation = ReceivedGiftPresentation
end
function ReceivedGiftPresentation(npc, giftAnimation)
    _ap_orig_ReceivedGiftPresentation(npc, giftAnimation)
    if giftAnimation ~= "GiftNPC" then return end
    local settings = ap_load_settings()
    if not (settings and settings.keepsakesanity == 1) then return end
    local name = GetGenusName and GetGenusName(npc)
    local giftData = GiftData and name and GiftData[name]
    if not giftData then return end
    for _, giftLevelData in ipairs(giftData) do
        local gift_id = giftLevelData and giftLevelData.Gift
        if gift_id then
            local location = KEEPSAKE_LOCATION_FOR_GIFT and KEEPSAKE_LOCATION_FOR_GIFT[gift_id]
            if location then
                local state = ap_load_state()
                local already_sent = false
                for _, cl in ipairs(state.checked_locations or {}) do
                    if cl == location then already_sent = true; break end
                end
                ap_check_location(location)
                if GameState and GameState.GiftPresentation then
                    GameState.GiftPresentation[gift_id] = true
                end
                if not already_sent then
                    ap_show_keepsake_check_banner(npc)
                end
            end
        end
    end
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
