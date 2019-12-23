--------------------------------------------
-- Loading
--------------------------------------------
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
f:RegisterEvent("PLAYER_LEAVE_COMBAT")
f:RegisterEvent("UNIT_HEALTH")
f:RegisterEvent("PLAYER_TARGET_CHANGED")
f:RegisterEvent("PLAYER_DEAD")
f:RegisterEvent("CHAT_MSG_BG_SYSTEM_NEUTRAL")
f:RegisterEvent("CHAT_MSG_BG_SYSTEM_ALLIANCE")
f:RegisterEvent("CHAT_MSG_BG_SYSTEM_HORDE")

SLASH_CCT1 = "/cct"
SlashCmdList["CCT"] = function(msg) CCT_OptionsFrame:Show() end

CCT_PlayerRealm = GetRealmName("player")
CCT_PlayerName = GetUnitName("player")
local CCT_CritCount = 1
local CCT_KillingBlowCount = 1
local CCT_HordeCaptures = 0
local CCT_AllianceCaptures = 0
local CCT_FinishHim_Announced = "false"
local CCT_KillingBlow_Announced = "false"
local CCT_BGMatch_Announced_One = "false"
local CCT_BGMatch_Announced_Two = "false"
local CCT_BGMatch_Announced_Three = "false"

local Hcount = 0
local Acount = 0
local Ncount = 0

function CCT_getVar(varName)
	return CCTSavedVars[CCT_PlayerRealm][CCT_PlayerName][varName]
end

function CCT_setVar(varName, value)
	CCTSavedVars[CCT_PlayerRealm][CCT_PlayerName][varName] = value
end

function tablelength(table)
	local count = 0
	for k, v in pairs(table) do
		count = count + 1
	end
	return count
end

--------------------------------------------
-- Event Scripts
--------------------------------------------
f:SetScript("OnEvent", function(self, event, ...)
	if event == "ADDON_LOADED" then
		local arg1 = ...
		if arg1 == "CombatCritTracker" then
			--print("Addon Loaded")
			if (CCTSavedVars == nil) then
				CCTSavedVars = {}
			end
			if (CCTSavedVars[CCT_PlayerRealm] == nil) then
				CCTSavedVars[CCT_PlayerRealm] = {}
			end
			if (CCTSavedVars[CCT_PlayerRealm][CCT_PlayerName] == nil) then
				CCTSavedVars[CCT_PlayerRealm][CCT_PlayerName] = {}
				CCT_Defaults()
			end
			local fontName, fontHeight, fontFlags = CCT_MessageFrame:GetFont()
			CCT_MessageFrame:SetFont(fontName, CCT_getVar("LogFontSize"), fontFlags)
			local BGfontName, BGfontHeight, BGfontFlags = CCT_BGMessageFrame:GetFont()
			CCT_BGMessageFrame:SetFont(BGfontName, CCT_getVar("BGLogFontSize"), BGfontFlags)
		end
	end
	if event == "COMBAT_LOG_EVENT_UNFILTERED" then
		local _, subevent, _, sourceGUID, _, _, _, destGUID, _, _, _ = CombatLogGetCurrentEventInfo()
		local sType, sName, amount, critical = nil, nil, nil, nil
		if subevent == "SWING_DAMAGE" then
			sName = "AutoAttack"
			amount, _, _, _, _, _, critical, _, _, _ = select(12, CombatLogGetCurrentEventInfo())
			sType = "Swing"
			if critical and scourceGUID == "player" then
				CCT_CritLogAndSound(sType, sName, amount)
			end
		end
		if subevent == "SPELL_DAMAGE" then
			sName, _, amount, _, _, _, _, _, critical, _, _, _ = select(13, CombatLogGetCurrentEventInfo())
			sType = "Spell"
			if critical and sourceGUID == "player" then
				CCT_CritLogAndSound(sType, sName, amount)
			end
		end
		if subevent == "RANGE_DAMAGE" then
			sName, _, amount, _, _, _, _, _, critical, _, _, _ = select(13, CombatLogGetCurrentEventInfo())
			sType = "Range"
			if critical and sourceGUID == "player" then
				CCT_CritLogAndSound(sType, sName, amount)
			end
		end
		if subevent == "SPELL_HEAL" then
			sName, _, amount, _, _, critical = select(13, CombatLogGetCurrentEventInfo())
			sType = "Heal"
			if critical and sourceGUID == "player" then
				CCT_CritLogAndSound(sType, sName, amount)
			end
		end
		if subevent == "UNIT_DIED" then
			if select(2, IsInInstance()) == "pvp" and sourceGUID == "player" and destGUID == "target" and UnitIsPlayer(destGUID) and CCT_getVar("BGKillingBlows") == "true"  and CCT_KillingBlow_Announced == "false" then
				if CCT_getVar("EnableSound") == "true" then
					if CCT_KillingBlowCount < 15 then
						PlaySoundFile(CCT_KillingBlowSounds[CCT_KillingBlowCount])
					else
						PlaySoundFile(CCT_KillingBlowSounds[14])
					end
				end
				if CCT_getVar("EnableCombatLog") == "true" then
					CCT_MessageFrame:AddMessage(CCT_LogMsg_KB[CCT_KillingBlowCount], CCT_getVar("CCT_RED"), CCT_getVar("CCT_GREEN"), CCT_getVar("CCT_BLUE"))
				end
				CCT_KillingBlowCount = CCT_KillingBlowCount + 1
				CCT_KillingBlow_Announced = "true"
			end
		end
	end
	if event == "CHAT_MSG_BG_SYSTEM_NEUTRAL" then
		local arg1 = ...
		CCT_BGEvent_Neutral(arg1)
	end

	if event == "CHAT_MSG_BG_SYSTEM_HORDE" then
		local arg1 = ...
		CCT_BGEvent_Horde(arg1)
	end
	if event == "CHAT_MSG_BG_SYSTEM_ALLIANCE" then
		local arg1 = ...
		CCT_BGEvent_Alliance(arg1)
	end

	if event == "PLAYER_LEAVE_COMBAT" then
		CCT_FinishHim_Announced = "false"
		if CCT_getVar("ResetCritCountAfterFight") == "true" then
			CCT_CritCount = 1
		end
	end
	if event == "PLAYER_TARGET_CHANGED" then
		if UnitIsDead("target") then
			--print("target is dead")
		else
			CCT_FinishHim_Announced = "false"
			CCT_KillingBlow_Announced = "false"
		end
	end
	if event == "UNIT_HEALTH" then
		local arg1 = ...
		if arg1 == "target" and UnitReaction("player", arg1) <= 4 then
			if CCT_getVar("EnableSound") == "true" and CCT_getVar("FinishHimSound") == "true" and CCT_FinishHim_Announced == "false" then
				local targetHealth = UnitHealth(arg1)
				if targetHealth < 20 and targetHealth > 0 then
					PlaySoundFile("Interface\\AddOns\\CombatCritTracker\\Sounds\\finishhim.ogg")
					CCT_FinishHim_Announced = "true"
				end
			end
		end
	end
	if event == "PLAYER_DEAD" then
		CCT_CritCount = 1
		CCT_FinishHim_Announced = "false"
		CCT_KillingBlowCount = 1
		CCT_KillingBlow_Announced = "false"
	end
end)

--------------------------------------------
-- Crit Log and Sound Handler
--------------------------------------------
function CCT_CritLogAndSound(sType, sName, amount)
	if CCT_getVar("EnableCombatLog") == "true" then
		if sType == "Swing" and CCT_getVar("CombatLogMergeNormal") == "true" and CCT_CritCount >= CCT_getVar("LogThresh") then
			if CCT_CritCount < 13 then
				CCT_MessageFrame:AddMessage(CCT_LogMsg[CCT_CritCount] .. " x" .. CCT_CritCount .." [" ..amount .. "]", CCT_getVar("CCT_RED"), CCT_getVar("CCT_GREEN"), CCT_getVar("CCT_BLUE"))
			else
				CCT_MessageFrame:AddMessage(CCT_LogMsg[12] .. " x" .. CCT_CritCount .." [" ..amount .. "]", CCT_getVar("CCT_RED"), CCT_getVar("CCT_GREEN"), CCT_getVar("CCT_BLUE"))
			end
		end
		if sType == "Spell"  and CCT_getVar("CombatLogShowCrits") == "true" and CCT_CritCount >= CCT_getVar("LogThresh") then
			if CCT_CritCount < 13 then
				CCT_MessageFrame:AddMessage(CCT_LogMsg[CCT_CritCount] .. " x" .. CCT_CritCount .." [" ..amount .. "]", CCT_getVar("CCT_RED"), CCT_getVar("CCT_GREEN"), CCT_getVar("CCT_BLUE"))
			else
				CCT_MessageFrame:AddMessage(CCT_LogMsg[12] .. " x" .. CCT_CritCount .." [" ..amount .. "]", CCT_getVar("CCT_RED"), CCT_getVar("CCT_GREEN"), CCT_getVar("CCT_BLUE"))
			end
		end
		if sType == "Range"  and CCT_getVar("CombatLogShowCrits") == "true" and CCT_CritCount >= CCT_getVar("LogThresh") then
			if CCT_CritCount < 13 then
				CCT_MessageFrame:AddMessage(CCT_LogMsg[CCT_CritCount] .. " x" .. CCT_CritCount .." [" ..amount .. "]", CCT_getVar("CCT_RED"), CCT_getVar("CCT_GREEN"), CCT_getVar("CCT_BLUE"))
			else
				CCT_MessageFrame:AddMessage(CCT_LogMsg[12] .. " x" .. CCT_CritCount .." [" ..amount .. "]", CCT_getVar("CCT_RED"), CCT_getVar("CCT_GREEN"), CCT_getVar("CCT_BLUE"))
			end
		end
		if sType == "Heal" and CCT_getVar("CombatLogShowCrits") == "true" and CCT_getVar("TrackHealing") == "true" and CCT_CritCount >= CCT_getVar("LogThresh") then
			if CCT_CritCount < 13 then
				CCT_MessageFrame:AddMessage(CCT_LogMsg[CCT_CritCount] .. " x" .. CCT_CritCount .." [" ..amount .. "]", CCT_getVar("CCT_RED"), CCT_getVar("CCT_GREEN"), CCT_getVar("CCT_BLUE"))
			else
				CCT_MessageFrame:AddMessage(CCT_LogMsg[12] .. " x" .. CCT_CritCount .." [" ..amount .. "]", CCT_getVar("CCT_RED"), CCT_getVar("CCT_GREEN"), CCT_getVar("CCT_BLUE"))
			end
		end
		if CCT_getVar("CombatLogRecordBreak") == "true" then
			local records = CCTSavedVars[CCT_PlayerRealm][CCT_PlayerName]["Records"]
			local tempTable = {sName, amount}
			local recordsText = table.concat(tempTable, " - ")
			if tablelength(records) == 0 then
				table.insert(records, recordsText)
				CCT_MessageFrame:AddMessage("A New Record!1", CCT_getVar("CCT_RED"), CCT_getVar("CCT_GREEN"), CCT_getVar("CCT_BLUE"))
			end
			for i=1, tablelength(records) do
				local startPos, endPos = string.find(records[i], " - ")
				startPos = startPos - 1
				endPos = endPos + 3
				local rName = string.sub(records[i], 1, startPos)
				local rAmount = tonumber(string.sub(records[i], endPos))
				if sName == rName then
					if amount > rAmount then
						table.remove(records, i)
						table.insert(records, recordsText)
						CCT_MessageFrame:AddMessage("A New Record!2", CCT_getVar("CCT_RED"), CCT_getVar("CCT_GREEN"), CCT_getVar("CCT_BLUE"))
					end
				end
				if sName ~= rName then
					if tablelength(records) == 10 then
						table.remove(records, 1)
						table.insert(records, recordsText)
					else
						table.insert(records, recordsText)
					end
					CCT_MessageFrame:AddMessage("A New Record!3", CCT_getVar("CCT_RED"), CCT_getVar("CCT_GREEN"), CCT_getVar("CCT_BLUE"))
				end
			end
		end
	end
	if CCT_getVar("EnableSound") == "true" then
		if sType == "Swing" and CCT_getVar("MergeNormalSound") == "true" and CCT_CritCount >= CCT_getVar("SoundThresh") then
			if CCT_CritCount < 13 then
				PlaySoundFile(CCT_Sounds[CCT_CritCount])
			else
				PlaySoundFile(CCT_Sounds[12])
			end
		end
		if sType == "Spell" and CCT_getVar("CritSound") == "true" and CCT_CritCount >= CCT_getVar("SoundThresh") then
			if CCT_CritCount < 13 then
				PlaySoundFile(CCT_Sounds[CCT_CritCount])
			else
				PlaySoundFile(CCT_Sounds[12])
			end
		end
		if sType == "Range" and CCT_getVar("CritSound") == "true" and CCT_CritCount >= CCT_getVar("SoundThresh") then
			if CCT_CritCount < 13 then
				PlaySoundFile(CCT_Sounds[CCT_CritCount])
			else
				PlaySoundFile(CCT_Sounds[12])
			end
		end
		if sType == "Heal" and CCT_getVar("CritSound") == "true" and CCT_getVar("TrackHealing") == "true" and CCT_CritCount >= CCT_getVar("SoundThresh") then
			if CCT_CritCount < 13 then
				PlaySoundFile(CCT_Sounds[CCT_CritCount])
			else
				PlaySoundFile(CCT_Sounds[12])
			end
		end
	end
	CCT_CritCount = CCT_CritCount + 1			
end

--------------------------------------------
-- Battleground Functions
--------------------------------------------
function CCT_BGMatchAnnounce(arg1)
	if arg1 == "three" and CCT_BGMatch_Announced_Three == "false" then
		if CCT_getVar("EnableSound") == "true" then
			PlaySoundFile("Interface\\AddOns\\CombatCritTracker\\Sounds\\three.ogg")
		end
		if CCT_getVar("EnableCombatLog") == "true" then
			CCT_BGMessageFrame:AddMessage("Three!", CCT_getVar("CCT_BG_RED"), CCT_getVar("CCT_BG_GREEN"), CCT_getVar("CCT_BG_BLUE"), 1, 1)
		end
		CCT_BGMatch_Announced_Three = "true"
	end
	if arg1 == "two" and CCT_BGMatch_Announced_Two == "false" then
		if CCT_getVar("EnableSound") == "true" then
			PlaySoundFile("Interface\\AddOns\\CombatCritTracker\\Sounds\\two.ogg")
		end
		if CCT_getVar("EnableCombatLog") == "true" then
			CCT_BGMessageFrame:AddMessage("Two!", CCT_getVar("CCT_BG_RED"), CCT_getVar("CCT_BG_GREEN"), CCT_getVar("CCT_BG_BLUE"), 1, 1)
		end
		CCT_BGMatch_Announced_Two = "true"
	end
	if arg1 == "one" and CCT_BGMatch_Announced_One == "false" then
		if CCT_getVar("EnableSound") == "true" then
			PlaySoundFile("Interface\\AddOns\\CombatCritTracker\\Sounds\\one.ogg")
		end
		if CCT_getVar("EnableCombatLog") == "true" then
			CCT_BGMessageFrame:AddMessage("One!", CCT_getVar("CCT_BG_RED"), CCT_getVar("CCT_BG_GREEN"), CCT_getVar("CCT_BG_BLUE"), 1, 1)
		end
		CCT_BGMatch_Announced_One = "true"
		CCT_TimerFrame:Hide()
	end
end

function CCT_BGEvent_Neutral (arg1)
	if CCT_getVar("BGMatchStart") == "true" and Ncount == 0 then
		local faction, _ = UnitFactionGroup("player")
		if string.match(arg1, "The battle for Warsong Gulch begins in 30 seconds.") then
			if CCT_getVar("EnableSound") == "true" then
				PlaySoundFile("Interface\\AddOns\\CombatCritTracker\\Sounds\\prepare.ogg")
			end
			if CCT_getVar("EnableCombatLog") == "true" then
				CCT_BGMessageFrame:AddMessage("Prepare to Fight!", CCT_getVar("CCT_BG_RED"), CCT_getVar("CCT_BG_GREEN"), CCT_getVar("CCT_BG_BLUE"))
			end
			CCT_BGT = GetTime()
			CCT_TimerFrame:Show()
		end
		if string.match(arg1, "Let the battle for Warsong Gulch begin!") then
			if CCT_getVar("EnableSound") == "true" then
				PlaySoundFile("Interface\\AddOns\\CombatCritTracker\\Sounds\\fight.ogg")
			end
			if CCT_getVar("EnableCombatLog") == "true" then
				CCT_BGMessageFrame:AddMessage("Fight!", CCT_getVar("CCT_BG_RED"), CCT_getVar("CCT_BG_GREEN"), CCT_getVar("CCT_BG_BLUE"))
			end
		end
--		if string.match(arg1, "The battle for Arathi Basin will begin in 30 seconds.") then
--			if CCT_getVar("EnableSound") == "true" then
--				PlaySoundFile("Interface\\AddOns\\CombatCritTracker\\Sounds\\prepare.ogg")
--			end
--			if CCT_getVar("EnableCombatLog") == "true" then
--				CCT_BGMessageFrame:AddMessage("Prepare to Fight!", CCT_getVar("CCT_BG_RED"), CCT_getVar("CCT_BG_GREEN"), CCT_getVar("CCT_BG_BLUE"))
--			end
--			CCT_BGT = GetTime()
--			CCT_TimerFrame:Show()
--		end
--		if string.match(arg1, "The Battle for Arathi Basin has begun!") then
--			if CCT_getVar("EnableSound") == "true" then
--				PlaySoundFile("Interface\\AddOns\\CombatCritTracker\\Sounds\\fight.ogg")
--			end
--			if CCT_getVar("EnableCombatLog") == "true" then
--				CCT_BGMessageFrame:AddMessage("Fight!", CCT_getVar("CCT_BG_RED"), CCT_getVar("CCT_BG_GREEN"), CCT_getVar("CCT_BG_BLUE"))
--			end
--		end
--		if string.match(arg1, "30 seconds until the battle for Alterac Valley begins.") then
--			if CCT_getVar("EnableSound") == "true" then
--				PlaySoundFile("Interface\\AddOns\\CombatCritTracker\\Sounds\\prepare.ogg")
--			end
--			if CCT_getVar("EnableCombatLog") == "true" then
--				CCT_BGMessageFrame:AddMessage("Prepare to Fight!", CCT_getVar("CCT_BG_RED"), CCT_getVar("CCT_BG_GREEN"), CCT_getVar("CCT_BG_BLUE"))
--			end
--			CCT_BGT = GetTime()
--			CCT_TimerFrame:Show()
--		end
--		if string.match(arg1, "The battle for Alterac Valley has begun!") then
--			if CCT_getVar("EnableSound") == "true" then
--				PlaySoundFile("Interface\\AddOns\\CombatCritTracker\\Sounds\\fight.ogg")
--			end
--			if CCT_getVar("EnableCombatLog") == "true" then
--				CCT_BGMessageFrame:AddMessage("Fight!", CCT_getVar("CCT_BG_RED"), CCT_getVar("CCT_BG_GREEN"), CCT_getVar("CCT_BG_BLUE"))
--			end
--		end
	end
	if Ncount == 0 then
		Ncount = 1
	else
		Ncount = 0
	end
end

function CCT_BGEvent_Horde(arg1)
	if CCT_getVar("BGFlagsScore") == "true" and Hcount == 0 then
		local faction, _ = UnitFactionGroup("player")
		if string.match(arg1, "The Alliance Flag was picked up by") then
			if faction == "Horde" then
				--your horde team has enemy flag
				if CCT_getVar("EnableSound") == "true" then
					PlaySoundFile("Interface\\AddOns\\CombatCritTracker\\Sounds\\YourTeamHasTheEnemyFlag.ogg")
				end
				if CCT_getVar("EnableCombatLog") == "true" then
					CCT_BGMessageFrame:AddMessage("Your team has the enemy flag!", CCT_getVar("CCT_BG_RED"), CCT_getVar("CCT_BG_GREEN"), CCT_getVar("CCT_BG_BLUE"))
				end
			end
			if faction == "Alliance" then
				--enemy has your alliance flag
				if CCT_getVar("EnableSound") == "true" then
					PlaySoundFile("Interface\\AddOns\\CombatCritTracker\\Sounds\\TheEnemyHasYourFlag.ogg")
				end
				if CCT_getVar("EnableCombatLog") == "true" then
					CCT_BGMessageFrame:AddMessage("The Horde has your flag!", CCT_getVar("CCT_BG_RED"), CCT_getVar("CCT_BG_GREEN"), CCT_getVar("CCT_BG_BLUE"))
				end
			end
		end
		if string.match(arg1, "The Horde flag was dropped by") then
			if faction == "Horde" then
				--your horde flag was dropped
				if CCT_getVar("EnableSound") == "true" then
					--PlaySoundFile("Interface\\AddOns\\CombatCritTracker\\Sounds\\RedFlagDropped.ogg")
				end
				if CCT_getVar("EnableCombatLog") == "true" then
					CCT_BGMessageFrame:AddMessage("RedFlagDropped!", CCT_getVar("CCT_BG_RED"), CCT_getVar("CCT_BG_GREEN"), CCT_getVar("CCT_BG_BLUE"))
				end
			end
			if faction == "Alliance" then
				--the horde flag was dropped
				if CCT_getVar("EnableSound") == "true" then
					--PlaySoundFile("Interface\\AddOns\\CombatCritTracker\\Sounds\\RedFlagDropped.ogg")
				end
				if CCT_getVar("EnableCombatLog") == "true" then
					CCT_BGMessageFrame:AddMessage("RedFlagDropped!", CCT_getVar("CCT_BG_RED"), CCT_getVar("CCT_BG_GREEN"), CCT_getVar("CCT_BG_BLUE"))
				end
			end
		end
		if string.match(arg1, "captured the Alliance flag!") then
			if CCT_HordeCaptures ~= 3 then
				--Horde scores
				if CCT_getVar("EnableSound") == "true" then
					PlaySoundFile("Interface\\AddOns\\CombatCritTracker\\Sounds\\RedScores.ogg")
				end
				if CCT_getVar("EnableCombatLog") == "true" then
					CCT_BGMessageFrame:AddMessage("Horde Scores!", CCT_getVar("CCT_BG_RED"), CCT_getVar("CCT_BG_GREEN"), CCT_getVar("CCT_BG_BLUE"))
				end
				CCT_HordeCaptures = CCT_HordeCaptures + 1
			end
		end
		if string.match(arg1, "The Horde flag was returned to its base by") then
			--your horde flag returned
			if CCT_getVar("EnableSound") == "true" then
				PlaySoundFile("Interface\\AddOns\\CombatCritTracker\\Sounds\\RedFlagReturned.ogg")
			end
			if CCT_getVar("EnableCombatLog") == "true" then
				CCT_BGMessageFrame:AddMessage("Horde flag returend!", CCT_getVar("CCT_BG_RED"), CCT_getVar("CCT_BG_GREEN"), CCT_getVar("CCT_BG_BLUE"))
			end
		end
		if string.match(arg1, "The Horde flag has returned to its base") then
			--enemy horde flag returned
			if CCT_getVar("EnableSound") == "true" then
				PlaySoundFile("Interface\\AddOns\\CombatCritTracker\\Sounds\\RedFlagReturned.ogg")
			end
			if CCT_getVar("EnableCombatLog") == "true" then
				CCT_BGMessageFrame:AddMessage("Horde flag returned!", CCT_getVar("CCT_BG_RED"), CCT_getVar("CCT_BG_GREEN"), CCT_getVar("CCT_BG_BLUE"))
			end
		end
		if string.match(arg1, "The Horde wins!") then
			if faction == "Horde" then
				if CCT_getVar("EnableSound") == "true" then
					PlaySoundFile("Interface\\AddOns\\CombatCritTracker\\Sounds\\youwin.ogg")
				end
				if CCT_getVar("EnableCombatLog") == "true" then
					CCT_BGMessageFrame:AddMessage("You Win!", CCT_getVar("CCT_BG_RED"), CCT_getVar("CCT_BG_GREEN"), CCT_getVar("CCT_BG_BLUE"))
				end
			end
			if faction == "Alliance" then
				if CCT_getVar("EnableSound") == "true" then
					PlaySoundFile("Interface\\AddOns\\CombatCritTracker\\Sounds\\IOUS.ogg")
				end
				if CCT_getVar("EnableCombatLog") == "true" then
					CCT_BGMessageFrame:AddMessage("You Lose!", CCT_getVar("CCT_BG_RED"), CCT_getVar("CCT_BG_GREEN"), CCT_getVar("CCT_BG_BLUE"))
				end
			end
			--reset battleground variables here
			CCT_BGMatch_Announced_Three = "false"
			CCT_BGMatch_Announced_Two = "false"
			CCT_BGMatch_Announced_One = "false"
			CCT_KillingBlowCount = 1
			CCT_HordeCaptures = 0
			CCT_AllianceCaptures = 0
		end
	end
	if Hcount == 0 then
		Hcount = 1
	else
		Hcount = 0
	end
end

function CCT_BGEvent_Alliance(arg1)
	if CCT_getVar("BGFlagsScore") == "true" and Acount == 0 then
		local faction, _ = UnitFactionGroup("player")
		if string.match(arg1, "The Horde flag was picked up by") then
			if faction == "Alliance" then
				--your alliance team has enemy flag
				if CCT_getVar("EnableSound") == "true" then
					PlaySoundFile("Interface\\AddOns\\CombatCritTracker\\Sounds\\YourTeamHasTheEnemyFlag.ogg")
				end
				if CCT_getVar("EnableCombatLog") == "true" then
					CCT_BGMessageFrame:AddMessage("Your team has the enemy flag!", CCT_getVar("CCT_BG_RED"), CCT_getVar("CCT_BG_GREEN"), CCT_getVar("CCT_BG_BLUE"))
				end
			end
			if faction == "Horde" then
				print ("Horde one went")
				--enemy has your alliance flag
				if CCT_getVar("EnableSound") == "true" then
					PlaySoundFile("Interface\\AddOns\\CombatCritTracker\\Sounds\\TheEnemyHasYourFlag.ogg")
				end
				if CCT_getVar("EnableCombatLog") == "true" then
					CCT_BGMessageFrame:AddMessage("The Alliance has your flag!", CCT_getVar("CCT_BG_RED"), CCT_getVar("CCT_BG_GREEN"), CCT_getVar("CCT_BG_BLUE"))
				end
			end
		end
		if string.match(arg1, "The Alliance Flag was dropped by") then
			if faction == "Alliance" then
				--your alliance flag was dropped
				if CCT_getVar("EnableSound") == "true" then
					--PlaySoundFile("Interface\\AddOns\\CombatCritTracker\\Sounds\\BlueFlagDropped.ogg")
				end
				if CCT_getVar("EnableCombatLog") == "true" then
					CCT_BGMessageFrame:AddMessage("BlueFlagDropped!", CCT_getVar("CCT_BG_RED"), CCT_getVar("CCT_BG_GREEN"), CCT_getVar("CCT_BG_BLUE"))
				end
			end
			if faction == "Horde" then
				--the alliance flag was dropped
				if CCT_getVar("EnableSound") == "true" then
					--PlaySoundFile("Interface\\AddOns\\CombatCritTracker\\Sounds\\RedFlagDropped.ogg")
				end
				if CCT_getVar("EnableCombatLog") == "true" then
					CCT_BGMessageFrame:AddMessage("BlueFlagDropped!", CCT_getVar("CCT_BG_RED"), CCT_getVar("CCT_BG_GREEN"), CCT_getVar("CCT_BG_BLUE"))
				end
			end
		end
		if string.match(arg1, "captured the Horde flag!") then
			if CCT_AllianceCaptures ~= 3 then
				--Alliance scores
				if CCT_getVar("EnableSound") == "true" then
					PlaySoundFile("Interface\\AddOns\\CombatCritTracker\\Sounds\\BlueScores.ogg")
				end
				if CCT_getVar("EnableCombatLog") == "true" then
					CCT_BGMessageFrame:AddMessage("Alliance Scores!", CCT_getVar("CCT_BG_RED"), CCT_getVar("CCT_BG_GREEN"), CCT_getVar("CCT_BG_BLUE"))
				end
				CCT_AllianceCaptures = CCT_AllianceCaptures + 1
			end
		end
		if string.match(arg1, "The Alliance Flag was returned to its base by") then
			--your alliance flag returned
			if CCT_getVar("EnableSound") == "true" then
				PlaySoundFile("Interface\\AddOns\\CombatCritTracker\\Sounds\\BlueFlagReturned.ogg")
			end
			if CCT_getVar("EnableCombatLog") == "true" then
				CCT_BGMessageFrame:AddMessage("Alliance flag returned!", CCT_getVar("CCT_BG_RED"), CCT_getVar("CCT_BG_GREEN"), CCT_getVar("CCT_BG_BLUE"))
			end
		end
		if string.match(arg1, "The Alliance Flag has returned to its base") then
			--enemy alliance flag returned
			if CCT_getVar("EnableSound") == "true" then
				PlaySoundFile("Interface\\AddOns\\CombatCritTracker\\Sounds\\BlueFlagReturned.ogg")
			end
			if CCT_getVar("EnableCombatLog") == "true" then
				CCT_BGMessageFrame:AddMessage("Alliance flag returned!", CCT_getVar("CCT_BG_RED"), CCT_getVar("CCT_BG_GREEN"), CCT_getVar("CCT_BG_BLUE"))
			end
		end
		if string.match(arg1, "The Alliance wins!") then
			if faction == "Alliance" then
				if CCT_getVar("EnableSound") == "true" then
					PlaySoundFile("Interface\\AddOns\\CombatCritTracker\\Sounds\\youwin.ogg")
				end
				if CCT_getVar("EnableCombatLog") == "true" then
					CCT_BGMessageFrame:AddMessage("You Win!", CCT_getVar("CCT_BG_RED"), CCT_getVar("CCT_BG_GREEN"), CCT_getVar("CCT_BG_BLUE"))
				end
			end
			if faction == "Horde" then
				if CCT_getVar("EnableSound") == "true" then
					PlaySoundFile("Interface\\AddOns\\CombatCritTracker\\Sounds\\IOUS.ogg")
				end
				if CCT_getVar("EnableCombatLog") == "true" then
					CCT_BGMessageFrame:AddMessage("You Lose!", CCT_getVar("CCT_BG_RED"), CCT_getVar("CCT_BG_GREEN"), CCT_getVar("CCT_BG_BLUE"))
				end
			end
			--reset battleground variables here
			CCT_BGMatch_Announced_Three = "false"
			CCT_BGMatch_Announced_Two = "false"
			CCT_BGMatch_Announced_One = "false"
			CCT_KillingBlowCount = 1
			CCT_HordeCaptures = 0
			CCT_AllianceCaptures = 0
		end
	end
	if Acount == 0 then
		Acount = 1
	else
		Acount = 0
	end
end

function CCT_TimerFrame_OnUpdate()
	local t = GetTime() - CCT_BGT
	local s = floor(t)
	if s == 28 then
		CCT_BGMatchAnnounce("three")
	end
	if s == 29 then
		CCT_BGMatchAnnounce("two")
	end
	if s == 30 then
		CCT_BGMatchAnnounce("one")
	end
end
--------------------------------------------
-- Options Frame
--------------------------------------------
function CCT_OptionsFrame_OnShow(self)
	CCT_OptionsFrameLogThreshSlider:SetValue(CCT_getVar("LogThresh"))
	CCT_OptionsFrameSoundThreshSlider:SetValue(CCT_getVar("SoundThresh"))

	if CCT_getVar("EnableCombatLog") == "true" then
		CCT_OptionsFrameCheck11:SetChecked(true)
	else
		CCT_OptionsFrameCheck11:SetChecked(false)
	end
	if CCT_getVar("CombatLogShowCrits") == "true" then
		CCT_OptionsFrameCheck12:SetChecked(true)
	else
		CCT_OptionsFrameCheck12:SetChecked(false)
	end
	if CCT_getVar("CombatLogMergeNormal") == "true" then
		CCT_OptionsFrameCheck13:SetChecked(true)
	else
		CCT_OptionsFrameCheck13:SetChecked(false)
	end
	if CCT_getVar("CombatLogRecordBreak") == "true" then
		CCT_OptionsFrameCheck14:SetChecked(true)
	else
		CCT_OptionsFrameCheck14:SetChecked(false)
	end

	if CCT_getVar("EnableSound") == "true" then
		CCT_OptionsFrameCheck21:SetChecked(true)
	else
		CCT_OptionsFrameCheck21:SetChecked(false)
	end
	if CCT_getVar("CritSound") == "true" then
		CCT_OptionsFrameCheck22:SetChecked(true)
	else
		CCT_OptionsFrameCheck22:SetChecked(false)
	end
	if CCT_getVar("MergeNormalSound") == "true" then
		CCT_OptionsFrameCheck23:SetChecked(true)
	else
		CCT_OptionsFrameCheck23:SetChecked(false)
	end
	if CCT_getVar("RecordBreakSound") == "true" then
		CCT_OptionsFrameCheck24:SetChecked(true)
	else
		CCT_OptionsFrameCheck24:SetChecked(false)
	end
	if CCT_getVar("FinishHimSound") == "true" then
		CCT_OptionsFrameCheck25:SetChecked(true)
	else
		CCT_OptionsFrameCheck25:SetChecked(false)
	end

	if CCT_getVar("ResetCritCountAfterFight") == "true" then
		CCT_OptionsFrameCheck31:SetChecked(true)
	else
		CCT_OptionsFrameCheck31:SetChecked(false)
	end
	if CCT_getVar("TrackHealing") == "true" then
		CCT_OptionsFrameCheck32:SetChecked(true)
	else
		CCT_OptionsFrameCheck32:SetChecked(false)
	end
	
	if CCT_getVar("BGMatchStart") == "true" then
		CCT_OptionsFrameCheck41:SetChecked(true)
	else
		CCT_OptionsFrameCheck41:SetChecked(false)
	end
	if CCT_getVar("BGKillingBlows") == "true" then
		CCT_OptionsFrameCheck42:SetChecked(true)
	else
		CCT_OptionsFrameCheck42:SetChecked(false)
	end
	if CCT_getVar("BGFlagsScore") == "true" then
		CCT_OptionsFrameCheck43:SetChecked(true)
	else
		CCT_OptionsFrameCheck43:SetChecked(false)
	end
end

function CCT_LogThreshSlider_OnValueChanged(self)
	CCT_setVar("LogThresh", self:GetValue())
	getglobal(self:GetName().."Text"):SetText("Log Crit Threshold : "..CCT_getVar("LogThresh"))
end

function CCT_SoundThreshSlider_OnValueChanged(self)
	CCT_setVar("SoundThresh", self:GetValue())
	getglobal(self:GetName().."Text"):SetText("Sound Crit Threshold : "..CCT_getVar("SoundThresh"))
end

function CCT_Helper_Tooltip(self)
	local text = self:GetName()
	GameTooltip:SetText(CCT_OptionsFrame_Tooltips[text], 0.8, 0.6, 0, 1, 1)
	GameTooltip:SetHeight(GameTooltip:GetHeight())
	local width = 20 + getglobal(GameTooltip:GetName().."TextLeft"..GameTooltip:NumLines()):GetWidth()
	if GameTooltip:GetWidth() < width then
		GameTooltip:SetWidth(width)
	end
end

--------------------------------------------
-- Minimap
--------------------------------------------
function CCT_MinimapButton_DragFrame_OnUpdate()
	local mx, my = _G.Minimap:GetCenter()
	local px, py = _G.GetCursorPosition()
	local scale = _G.Minimap:GetEffectiveScale()

	px, py = px / scale, py / scale
	local myPosition = math.deg(math.atan2(py-my, px-mx)) % 360

	local angel = math.rad(myPosition)
	local cos = math.cos(angel)
	local sin = math.sin(angel)
	local x, y = cos*80, sin*80

	CCT_MinimapButton:ClearAllPoints()
	CCT_MinimapButton:SetPoint("CENTER", x, y)
end

function CCT_MinimapButton_OnClick(self, button)
	if button == "LeftButton" then
		if IsShiftKeyDown() then
			CCT_OptionsFrame:Hide()
			CCT_MessageFrameHelper:Show()
			CCT_MessageFrame:SetBackdropColor(1, 1, 1, 1)
			CCT_BGMessageFrame:SetBackdropColor(1, 1, 1, 1)
			CCT_MessageFrame:EnableMouse(true)
			CCT_BGMessageFrame:EnableMouse(true)
			CCT_MessageFrame:RegisterForDrag("LeftButton")
			CCT_BGMessageFrame:RegisterForDrag("LeftButton")
			CCT_MessageFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
			CCT_BGMessageFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
			CCT_MessageFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
			CCT_BGMessageFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
		else
			if CCT_OptionsFrame:IsShown() then
				CCT_OptionsFrame:Hide()
			else
				CCT_OptionsFrame:Show()
			end
		end
	end
	if button == "RightButton" then
		if IsShiftKeyDown() then
			CCT_CritCount = 1
			print("Reseting Crit Counter")
		else
			if CCT_getVar("MinimapButtonUnlocked") == "true" then
				CCT_setVar("MinimapButtonUnlocked", "false")
				GameTooltip:Hide()
				GameTooltip:SetOwner(self, "ANCHOR_LEFT")
				CCT_MinimapButton_Tooltip()
			else
				CCT_setVar("MinimapButtonUnlocked", "true")
				GameTooltip:Hide()
				GameTooltip:SetOwner(self, "ANCHOR_LEFT")
				CCT_MinimapButton_Tooltip()
			end
		end
	end
end

function CCT_MinimapButton_Tooltip()
	local cState
	if CCT_getVar("MinimapButtonUnlocked") == "true" then
		cState= "Lock"
	else
		cState = "Unlock"
	end
	if CCT_MinimapButton_DragFrame:IsShown() then
		
	else
		GameTooltip:SetText("Combat Crit Tracker")
		GameTooltip:SetHeight(90)
		GameTooltip:SetWidth(270)
		GameTooltip:AddLine("|cffffff00Left Click : |rOpen Options Menu", 0.8, 0.8, 0.8)
		GameTooltip:AddLine("|cffffff00Right Click: |r"..cState.." Minimap Button", 0.8, 0.8, 0.8)
		GameTooltip:AddLine("|cffffff00Shift + Left Click: |rEdit Message Frames", 0.8, 0.8, 0.8)
		GameTooltip:AddLine("|cffffff00Shift + Right Click: |rReset Crit Counter", 0.8, 0.8, 0.8)
	end
end

-------------------------------------------
-- Message Frame Helper
-------------------------------------------
function CCT_MessageFrameHelper_OnShow()
	CCT_MessageFrameHelperFontSlider:SetValue(CCT_getVar("LogFontSize"))
	CCT_MessageFrameHelperBGFontSlider:SetValue(CCT_getVar("BGLogFontSize"))
end

function CCT_FontSlider_OnValueChanged(self)
	CCT_setVar("LogFontSize", self:GetValue())
	local fontName, fontHeight, fontFlags = CCT_MessageFrame:GetFont()
	CCT_MessageFrame:SetFont(fontName, self:GetValue(), fontFlags)
	getglobal(self:GetName().."Text"):SetText("Log Font Size : "..CCT_getVar("LogFontSize"))
end

function CCT_BGFontSlider_OnValueChanged(self)
	CCT_setVar("BGLogFontSize", self:GetValue())
	local BGfontName, BGfontHeight, BGfontFlags = CCT_BGMessageFrame:GetFont()
	CCT_BGMessageFrame:SetFont(BGfontName, self:GetValue(), BGfontFlags)
	getglobal(self:GetName().."Text"):SetText("Battleground Font Size : "..CCT_getVar("BGLogFontSize"))
end

function CCT_MessageFrameHelperTestButton_OnClick()
	local val = math.random(1, 22)
	CCT_MessageFrame:AddMessage(CCT_LogMsg[val] .. " x" .. val .." [999]", CCT_getVar("CCT_RED"), CCT_getVar("CCT_GREEN"), CCT_getVar("CCT_BLUE"))
	CCT_BGMessageFrame:AddMessage("The enemy has your flag!", CCT_getVar("CCT_BG_RED"), CCT_getVar("CCT_BG_GREEN"), CCT_getVar("CCT_BG_BLUE"))
end

function CCT_MessageFrameHelperColorButton_OnClick()
	ColorPickerFrame:SetColorRGB(CCT_getVar("CCT_RED"), CCT_getVar("CCT_GREEN"), CCT_getVar("CCT_BLUE"), 1)
	ColorPickerFrame.hasOpacity = nil
	ColorPickerFrame.previousValues = {CCT_getVar("CCT_RED"), CCT_getVar("CCT_GREEN"), CCT_getVar("CCT_BLUE"), 1}
	ColorPickerFrame.func, ColorPickerFrame.cancelFunc = CCT_ColorCallBack, CCT_ColorCallBack
	ColorPickerFrame:Hide()
	ColorPickerFrame:Show()
end

function CCT_ColorCallBack(restore)
	local newR, newG, newB, newA
	if restore then
		newR, newG, newB, newA = unpack(restore)
	else
		newR, newG, newB = ColorPickerFrame:GetColorRGB()
	end
	CCT_setVar("CCT_RED", newR)
	CCT_setVar("CCT_GREEN", newG)
	CCT_setVar("CCT_BLUE", newB)
	CCT_MessageFrameFontString:SetTextColor(CCT_getVar("CCT_RED"), CCT_getVar("CCT_GREEN"), CCT_getVar("CCT_BLUE"), 1)
end

function CCT_MessageFrameHelperCloseButton_OnClick()
	CCT_MessageFrameHelper:Hide()
	CCT_MessageFrame:SetBackdropColor(1, 1, 1, 0)
	CCT_BGMessageFrame:SetBackdropColor(1, 1, 1, 0)
	CCT_MessageFrame:EnableMouse(false)
	CCT_BGMessageFrame:EnableMouse(false)
	CCT_MessageFrame:SetScript("OnDragStart", nil)
	CCT_BGMessageFrame:SetScript("OnDragStart", nil)
	CCT_MessageFrame:SetScript("OnDragStop", nil)
	CCT_BGMessageFrame:SetScript("OnDragStop", nil)
end

--------------------------------------------
-- Records Frame
--------------------------------------------
function CCT_RecordsFrame_OnShow()
	local records = CCTSavedVars[CCT_PlayerRealm][CCT_PlayerName]["Records"]
	local recordsText = table.concat(records, "\n\n")
	CCT_RecordsFrameText:SetText(recordsText)
end

function CCT_ClearRecords()
	print("Clearing Records")
	CCTSavedVars[CCT_PlayerRealm][CCT_PlayerName]["Records"] = {}
	CCT_RecordsFrameText:SetText()
end

function CCT_FakeRecords()
	print("Loading fake records")
	CCTSavedVars[CCT_PlayerRealm][CCT_PlayerName]["Records"] = {
	"FirstAttack - 100",
	"SecondAttack - 200",
	"ThirdAttack - 300",
	"FourthAttack - 400",
	"FifthAttack - 500",
	"SixthAttack - 600",
	"SeventhAttack - 700",
	"EighthAttack - 800",
	"NinthAttack - 900",
	"TenthAttack - 1000",
	}
end

--------------------------------------------
-- Default Settings
--------------------------------------------
function CCT_Defaults()
	print("Loading Defaults")
	CCTSavedVars[CCT_PlayerRealm][CCT_PlayerName] = {}
	CCTSavedVars[CCT_PlayerRealm][CCT_PlayerName]["Records"] = {}

	CCT_setVar("MinimapButtonUnlocked", "true")

	CCT_setVar("EnableCombatLog", "true")
	CCT_setVar("CombatLogShowCrits", "true")
	CCT_setVar("CombatLogMergeNormal", "false")
	CCT_setVar("CombatLogRecordBreak", "true")
	CCT_setVar("LogThresh", 1)

	CCT_setVar("EnableSound", "true")
	CCT_setVar("CritSound", "true")
	CCT_setVar("MergeNormalSound", "false")
	CCT_setVar("RecordBreakSound", "true")
	CCT_setVar("FinishHimSound", "true")
	CCT_setVar("SoundThresh", 1)
	
	CCT_setVar("ResetCritCountAfterFight", "true")
	CCT_setVar("TrackHealing", "false")

	CCT_setVar("BGMatchStart", "true")
	CCT_setVar("BGKillingBlows", "true")
	CCT_setVar("BGFlagsScore", "true")

	CCT_setVar("LogFontSize", 24)
	CCT_setVar("BGLogFontSize", 24)
	CCT_setVar("CCT_RED", 1)
	CCT_setVar("CCT_GREEN", 1)
	CCT_setVar("CCT_BLUE", 1)
	CCT_setVar("CCT_BG_RED", 0.5)
	CCT_setVar("CCT_BG_GREEN", 0.5)
	CCT_setVar("CCT_BG_BLUE", 0.5)
end

--------------------------------------------
-- Crit Sounds Array
--------------------------------------------
CCT_Sounds = {
"Interface\\AddOns\\CombatCritTracker\\Sounds\\yeah.ogg", --1
"Interface\\AddOns\\CombatCritTracker\\Sounds\\ohyeah.ogg", --2
"Interface\\AddOns\\CombatCritTracker\\Sounds\\unstoppable.ogg", --3
"Interface\\AddOns\\CombatCritTracker\\Sounds\\killingspree.ogg", --4
"Interface\\AddOns\\CombatCritTracker\\Sounds\\dominating.ogg", --5
"Interface\\AddOns\\CombatCritTracker\\Sounds\\ultrakill.ogg", --6
"Interface\\AddOns\\CombatCritTracker\\Sounds\\wickedsick.ogg", --7
"Interface\\AddOns\\CombatCritTracker\\Sounds\\godlike.ogg", --8
"Interface\\AddOns\\CombatCritTracker\\Sounds\\holyshit.ogg", --9
"Interface\\AddOns\\CombatCritTracker\\Sounds\\monsterkill.ogg", --10
"Interface\\AddOns\\CombatCritTracker\\Sounds\\ludicrouskill.ogg", --11
"Interface\\AddOns\\CombatCritTracker\\Sounds\\ownage.ogg", --12
}

--------------------------------------------
-- Killing Blow Sounds Array
--------------------------------------------
CCT_KillingBlowSounds = {
"Interface\\AddOns\\CombatCritTracker\\Sounds\\firstblood.ogg", --1
"Interface\\AddOns\\CombatCritTracker\\Sounds\\doublekill.ogg", --2
"Interface\\AddOns\\CombatCritTracker\\Sounds\\triplekill.ogg", --3
"Interface\\AddOns\\CombatCritTracker\\Sounds\\multikill.ogg", --4
"Interface\\AddOns\\CombatCritTracker\\Sounds\\ultrakill.ogg", --5
"Interface\\AddOns\\CombatCritTracker\\Sounds\\megakill.ogg", --6
"Interface\\AddOns\\CombatCritTracker\\Sounds\\monsterkill.ogg", --7
"Interface\\AddOns\\CombatCritTracker\\Sounds\\ludicrouskill.ogg", --8
"Interface\\AddOns\\CombatCritTracker\\Sounds\\wickedsick.ogg", --9
"Interface\\AddOns\\CombatCritTracker\\Sounds\\holyshit.ogg", --10
"Interface\\AddOns\\CombatCritTracker\\Sounds\\godlike.ogg", --11
"Interface\\AddOns\\CombatCritTracker\\Sounds\\ownage.ogg", --12
"Interface\\AddOns\\CombatCritTracker\\Sounds\\invincible.ogg", --13
"Interface\\AddOns\\CombatCritTracker\\Sounds\\god.ogg", --14
}

--------------------------------------------
-- Crit LogMsg Array
--------------------------------------------
CCT_LogMsg = {
"Yeah!", --1
"Oh Yeah!", --2
"Unstoppable!", --3
"Killing Spree!", --4
"Dominating!", --5
"Ultra Kill!", --6
"Wicked Sick!", --7
"God Like!", --8
"Holy Shit!", --9
"Monster Kill!", --10
"Ludicrous Kill!", --11
"Ownage!", --12
}

--------------------------------------------
-- Killing Blow LogMsg Array
--------------------------------------------
CCT_LogMsg_KB = {
"First Blood!", --1
"Double Kill!", --2
"Triple Kill!", --3
"Multikill!", --4
"Ultrakill!", --5
"Megakill!", --6
"Monster Kill!", --7
"Ludicrous Kill!", --8
"Wicked Sick!", --9
"Holy Shit!", --10
"Godlike!", --11
"Ownage!", -- 12
"Invincible!", --13
"God!", --14
}

--------------------------------------------
-- OptionsFrame Tooltips Array
--------------------------------------------
CCT_OptionsFrame_Tooltips = {
	["CCT_OptionsFrameCheck11"] = "This toggles ALL announcements printed on screen",
	["CCT_OptionsFrameCheck12"] = "This toggles ability crit announcements",
	["CCT_OptionsFrameCheck13"] = "This toggles auto attack crit announcements",
	["CCT_OptionsFrameCheck14"] = "This shows an announcement when a new highest crit occurs",
	
	["CCT_OptionsFrameLogThreshSlider"] = "This sets the number of crits needed before announcements start happening",
	
	["CCT_OptionsFrameCheck21"] = "This toggles ALL sound effects",
	["CCT_OptionsFrameCheck22"] = "This toggles ability crit sounds",
	["CCT_OptionsFrameCheck23"] = "This toggles auto attack crit sounds",
	["CCT_OptionsFrameCheck24"] = "This plays a sound when a new highest crit occurs",
	["CCT_OptionsFrameCheck25"] = "This plays a sound when your target is low health",
	
	["CCT_OptionsFrameSoundThreshSlider"] = "This sets the number of crits needed before sounds start happening",
	
	["CCT_OptionsFrameCheck31"] = "This toggles reseting the crit counter once you leave combat",
	["CCT_OptionsFrameCheck32"] = "This toggles including healing spell crits with your other abilities",
	
	["CCT_OptionsFrameCheck41"] = "This toggles battleground starting announcements",
	["CCT_OptionsFrameCheck42"] = "This toggles your battleground killingblow announcements",
	["CCT_OptionsFrameCheck43"] = "This toggles battleground announcements for flags and scoring",
}