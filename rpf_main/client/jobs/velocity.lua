local vehicle = nil
local vehicleBlip = nil
local detonationSound = nil


AddEventHandler('lsv:startAlerteBombe', function()
	local location = Utils.GetRandom(Settings.velocity.locations)

	Streaming.RequestModel('voltic2')

	local vehicleHash = GetHashKey('voltic2')
	vehicle = CreateVehicle(vehicleHash, location.x, location.y, location.z, location.heading, false, true)
	SetVehicleModKit(vehicle, 0)
	SetVehicleMod(vehicle, 16, 4)

	SetModelAsNoLongerNeeded(vehicleHash)

	vehicleBlip = AddBlipForEntity(vehicle)
	SetBlipHighDetail(vehicleBlip, true)
	SetBlipSprite(vehicleBlip, Blip.RocketVoltic())
	SetBlipColour(vehicleBlip, Color.BlipGreen())

	JobWatcher.StartJob('Alerte Bombe')

	detonationSound = GetSoundId()

	local isInVehicle = false
	local preparationStage = nil
	local detonationStage = nil

	local eventStartTime = GetGameTimer()
	local startTimeToDetonate = GetGameTimer()
	local startPreparationStageTime = GetGameTimer()
	local almostDetonated = 0

	local jobId = JobWatcher.GetJobId()

	Citizen.CreateThread(function()
		Gui.StartJob('Alerte Bombe', 'Entre dans le vehicule et reste a la bonne vitesse pour evite la detonation.')

		while true do
			Citizen.Wait(0)

			if JobWatcher.IsJobInProgress(jobId) then
				if not IsPlayerDead(PlayerId()) then
					local totalTime = Settings.velocity.enterVehicleTime
					if preparationStage then totalTime = Settings.velocity.preparationTime
					elseif detonationStage then totalTime = Settings.velocity.detonationTime
					elseif isInVehicle and not preparationStage then totalTime = Settings.velocity.driveTime end

					local title = 'Temp limite'
					if preparationStage then title = 'Bombe activer'
					elseif detonationStage then title = 'Detonnation' end

					local startTime = eventStartTime
					if detonationStage then startTime = startTimeToDetonate
					elseif preparationStage then startTime = startPreparationStageTime end

					local timeLeft = totalTime - GetGameTimer() + startTime
					if detonationStage then
						Gui.DrawProgressBar(title, 1.0 - timeLeft / Settings.velocity.detonationTime, Color.GetHudFromBlipColor(Color.BlipRed()))
					else
						Gui.DrawTimerBar(title, math.floor(timeLeft / 1000))
					end

					if isInVehicle then
						local vehicleSpeedMph = math.floor(GetEntitySpeed(vehicle) * 2.236936)
						Gui.DrawBar('Vitesse', vehicleSpeedMph..' MPH', nil, 2)
						Gui.DrawBar('Presque detonne', almostDetonated, nil, 3)
					end

					Gui.DisplayObjectiveText(isInVehicle and 'Stay above '..Settings.velocity.minSpeed..' kmh pour evite une explosion.' or 'Entre dans la ~g~Rocket Voltic~w~.')
				end
			else return end
		end
	end)

	while true do
		Citizen.Wait(0)

		if not DoesEntityExist(vehicle) or not IsVehicleDriveable(vehicle, false) then
			TriggerEvent('lsv:velocityFinished', false, 'Le vehicule est detruit.')
			return
		end

		isInVehicle = IsPedInVehicle(PlayerPedId(), vehicle, false)
		if isInVehicle then
			if not NetworkGetEntityIsNetworked(vehicle) then NetworkRegisterEntityAsNetworked(vehicle) end

			if preparationStage == nil then
				preparationStage = true
				startPreparationStageTime = GetGameTimer()
			elseif preparationStage then
				if GetTimeDifference(GetGameTimer(), startPreparationStageTime) >= Settings.velocity.preparationTime then
					preparationStage = false
					eventStartTime = GetGameTimer()
					SetTimeout(3000, function() Gui.DisplayHelpText('Reste a la bonne vitesse pour evite une explosion.') end)
				end
			elseif GetTimeDifference(GetGameTimer(), eventStartTime) < Settings.velocity.driveTime then
				local vehicleSpeedMph = math.floor(GetEntitySpeed(vehicle) * 2.236936) -- https://runtime.fivem.net/doc/reference.html#_0xD5037BA82E12416F

				if vehicleSpeedMph < Settings.velocity.minSpeed then
					if not detonationStage then
						detonationStage = true
						startTimeToDetonate = GetGameTimer()
						TriggerServerEvent('lsv:velocityAboutToDetonate')
						almostDetonated = almostDetonated + 1
						PlaySoundFrontend(detonationSound, '5s_To_Event_Start_Countdown', 'GTAO_FM_Events_Soundset', false)
					end

					if GetTimeDifference(GetGameTimer(), startTimeToDetonate) >= Settings.velocity.detonationTime then
						local vehicleNetId = NetworkGetNetworkIdFromEntity(vehicle)
						NetworkRequestControlOfNetworkId(vehicleNetId)
						while not NetworkHasControlOfNetworkId(vehicleNetId) do Citizen.Wait(0) end

						NetworkExplodeVehicle(vehicle, true, false, false)

						TriggerEvent('lsv:velocityFinished', false, 'La bombe a exploser.')
						return
					end
				elseif detonationStage then
					if not HasSoundFinished(detonationSound) then StopSound(detonationSound) end
					detonationStage = false
				end
			else
				TriggerServerEvent('lsv:velocityFinished')
				return
			end
		elseif GetTimeDifference(GetGameTimer(), eventStartTime) >= Settings.velocity.enterVehicleTime then
			TriggerEvent('lsv:velocityFinished', false, 'Le temps est fini.')
			return
		end

		SetBlipAlpha(vehicleBlip, isInVehicle and 0 or 255)
	end
end)


RegisterNetEvent('lsv:velocityFinished')
AddEventHandler('lsv:velocityFinished', function(success, reason)
	JobWatcher.FinishJob('Alerte Bombe')

	vehicle = nil

	RemoveBlip(vehicleBlip)
	vehicleBlip = nil

	if not HasSoundFinished(detonationSound) then StopSound(detonationSound) end
	ReleaseSoundId(detonationSound)
	detonationSound = nil

	Gui.FinishJob('Alerte Bombe', success, reason)
end)
