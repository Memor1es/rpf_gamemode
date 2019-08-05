local logger = Logger:CreateNamedLogger('Castle')

local castleData = nil

local titles = { 'WINNER', '2ND PLACE', '3RD PLACE' }


local function getPlayerPoints()
	for i, v in pairs(castleData.players) do
		if v.id == Player.ServerId() then return v.points end
	end

	return 0
end


RegisterNetEvent('lsv:startCastle')
AddEventHandler('lsv:startCastle', function(placeIndex, passedTime, players)
	local place = Settings.castle.places[placeIndex]

	castleData = { }
	castleData.place = place
	castleData.zoneBlip = Map.CreateRadiusBlip(place.x, place.y, place.z, Settings.castle.radius, Color.BlipPurple())

	castleData.blip = AddBlipForCoord(place.x, place.y, place.z)
	SetBlipSprite(castleData.blip, Blip.Castle())
	SetBlipScale(castleData.blip, 1.1)
	SetBlipColour(castleData.blip, Color.BlipPurple())
	SetBlipHighDetail(castleData.blip, true)

	if Player.IsInFreeroam() then
		FlashMinimapDisplay()
		Map.SetBlipFlashes(castleData.blip)
		PlaySoundFrontend(-1, 'MP_5_SECOND_TIMER', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
		vRP.notifyPicture({"CHAR_CARSITE4", 1, "ARENA WAR", "~g~La partie commence !", "Va aux ~r~Arena War~w~ et tien le plus longtemp possible dans la zone pour avoir le ~g~Liquide~w~."})
		--Gui.DisplayNotification('')
	end

	castleData.startTime = GetGameTimer()
	if passedTime then castleData.startTime = castleData.startTime - passedTime end
	castleData.players = { }
	if players then castleData.players = players end
end)


RegisterNetEvent('lsv:updateCastlePlayers')
AddEventHandler('lsv:updateCastlePlayers', function(players)
	if castleData then
		castleData.players = players
	end
end)


RegisterNetEvent('lsv:finishCastle')
AddEventHandler('lsv:finishCastle', function(winners)
	if castleData then
		RemoveBlip(castleData.blip)
		RemoveBlip(castleData.zoneBlip)
	end

	if not winners then
		castleData = nil
		Gui.DisplayNotification('Arena War est fini.')
		return
	end

	if not Player.IsActive() then
		castleData = nil
		return
	end

	if Player.IsOnMission() then
		castleData = nil
		FlashMinimapDisplay()
		Gui.DisplayNotification(Gui.GetPlayerName(winners[1], '~p~')..' est le Roi de ~r~Arena War~w~.')
		return
	end

	local isPlayerWinner = false
	for i = 1, 3 do
		if winners[i] and winners[i] == Player.ServerId() then
			isPlayerWinner = i
			break
		end
	end

	local messageText = isPlayerWinner and 'Tu es le Roi de ~r~Arena War~w~ voici ton score '..getPlayerPoints() or Gui.GetPlayerName(winners[1])..' Nouveau gagnent.'

	castleData = nil

	if isPlayerWinner then PlaySoundFrontend(-1, 'Mission_Pass_Notify', 'DLC_HEISTS_GENERAL_FRONTEND_SOUNDS', true)
	else PlaySoundFrontend(-1, 'ScreenFlash', 'MissionFailedSounds', true) end

	local scaleform = Scaleform:Request('MIDSIZED_MESSAGE')

	scaleform:Call('SHOW_SHARD_MIDSIZED_MESSAGE', isPlayerWinner and titles[isPlayerWinner] or 'YOU LOSE', messageText, 21)
	scaleform:RenderFullscreenTimed(10000)

	scaleform:Delete()
end)


AddEventHandler('lsv:init', function()
	local pointAddedLastTime = GetGameTimer()
	local playerColors = { Color.BlipYellow(), Color.BlipGrey(), Color.BlipBrown() }
	local playerPositions = { '1st: ', '2nd: ', '3rd: ' }

	while true do
		Citizen.Wait(0)

		if castleData then
			local isAnyJobInProgress = JobWatcher.IsAnyJobInProgress()

			SetBlipAlpha(castleData.blip, isAnyJobInProgress and 0 or 255)
			SetBlipAlpha(castleData.zoneBlip, isAnyJobInProgress and 0 or 128)

			if Player.IsInFreeroam() then
				Gui.DrawTimerBar('FIN EVENT', math.max(0, math.floor((Settings.castle.duration - GetGameTimer() + castleData.startTime) / 1000)))
				Gui.DrawBar('TON SCORE', getPlayerPoints(), nil , 2)

				if not Utils.IsTableEmpty(castleData.players) then
					local barPosition = 3
					for i = 3, 1, -1 do
						if castleData.players[i] then
							Gui.DrawBar(playerPositions[i]..GetPlayerName(GetPlayerFromServerId(castleData.players[i].id)), castleData.players[i].points,
								Color.GetHudFromBlipColor(playerColors[i]), barPosition, true)
							barPosition = barPosition + 1
						end
					end
				end

				local playerX, playerY, playerZ = table.unpack(GetEntityCoords(PlayerPedId(), true))
				local isPlayerInCastleArea = GetDistanceBetweenCoords(playerX, playerY, playerZ, castleData.place.x, castleData.place.y, castleData.place.z, true) <= Settings.castle.radius

				Gui.DisplayObjectiveText(isPlayerInCastleArea and 'Defend cette ~r~Endroit~w~ contre les autres Joueurs.')

				if isPlayerInCastleArea and GetTimeDifference(GetGameTimer(), pointAddedLastTime) >= 1000 then
					TriggerServerEvent('lsv:castleAddPoint')
					pointAddedLastTime = GetGameTimer()
				end
			end
		end
	end
end)