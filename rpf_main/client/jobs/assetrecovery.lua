--vRP = Proxy.getInterface("vRP")

local vehicle = nil
local vehicleBlip = nil
local dropOffBlip = nil
local dropOffLocationBlip = nil

AddEventHandler('lsv:startRecouvrement', function()
	local variant = Utils.GetRandom(Settings.assetRecovery.variants)

	Streaming.RequestModel(variant.vehicle)

	local vehicleHash = GetHashKey(variant.vehicle)

	vehicle = CreateVehicle(vehicleHash, variant.vehicleLocation.x, variant.vehicleLocation.y, variant.vehicleLocation.z, variant.vehicleLocation.heading, false, true)
	SetVehicleModKit(vehicle, 0)
	SetVehicleMod(vehicle, 16, 4)

	SetModelAsNoLongerNeeded(vehicleHash)

	vehicleBlip = AddBlipForEntity(vehicle)
	SetBlipHighDetail(vehicleBlip, true)
	SetBlipSprite(vehicleBlip, Blip.PersonalVehicleCar())
	SetBlipColour(vehicleBlip, Color.BlipGreen())
	SetBlipAlpha(vehicleBlip, 0)
	Map.SetBlipText(vehicleBlip, 'Vehicule')

	dropOffBlip = AddBlipForCoord(variant.dropOffLocation.x, variant.dropOffLocation.y, variant.dropOffLocation.z)
	SetBlipColour(dropOffBlip, Color.BlipYellow())
	SetBlipHighDetail(dropOffBlip, true)
	SetBlipAlpha(dropOffBlip, 0)

	dropOffLocationBlip = Map.CreateRadiusBlip(variant.dropOffLocation.x, variant.dropOffLocation.y, variant.dropOffLocation.z, Settings.assetRecovery.dropRadius, Color.BlipYellow())
	SetBlipAlpha(dropOffLocationBlip, 0)

	JobWatcher.StartJob('Recouvrement Amiable')

	local eventStartTime = GetGameTimer()
	local isInVehicle = false
	local jobId = JobWatcher.GetJobId()

	Citizen.CreateThread(function()
		Gui.StartJob('Recouvrement Amiable', 'Vole ce vehicule et apporte le dans la zone indiquer.')

		while true do
			Citizen.Wait(0)

			if JobWatcher.IsJobInProgress(jobId) then
				if not IsPlayerDead(PlayerId()) then
					Gui.DrawTimerBar('TEMPS LIMITE', math.floor((Settings.assetRecovery.time - GetGameTimer() + eventStartTime) / 1000))
					if isInVehicle then
						local healthProgress = GetEntityHealth(vehicle) / GetEntityMaxHealth(vehicle)
						local color = Color.GetHudFromBlipColor(Color.BlipGreen())
						if healthProgress < 0.33 then color = Color.GetHudFromBlipColor(Color.BlipRed())
						elseif healthProgress < 0.66 then color = Color.GetHudFromBlipColor(Color.BlipYellow()) end
						Gui.DrawProgressBar('DOMMAGE', healthProgress, color, 2)
					end
				end
			else return end
		end
	end)

	local routeBlip = nil

	while true do
		Citizen.Wait(0)

		if GetTimeDifference(GetGameTimer(), eventStartTime) < Settings.assetRecovery.time then
			if not DoesEntityExist(vehicle) or not IsVehicleDriveable(vehicle, false) then
				TriggerEvent('lsv:assetRecoveryFinished', false, 'Le vehicule est detruit.')
				return
			end

			isInVehicle = IsPedInVehicle(PlayerPedId(), vehicle, false)

			Gui.DisplayObjectiveText(isInVehicle and 'Va livret le ~g~vehicule~w~ dans la ~y~Zone~w~.' or 'Vole le ~g~vehicule~w~.')

			SetBlipAlpha(vehicleBlip, isInVehicle and 0 or 255)
			SetBlipAlpha(dropOffBlip, isInVehicle and 255 or 0)
			SetBlipAlpha(dropOffLocationBlip, isInVehicle and 128 or 0)

			if isInVehicle then
				if not NetworkGetEntityIsNetworked(vehicle) then
					NetworkRegisterEntityAsNetworked(vehicle)
					SetTimeout(3000, function() Gui.DisplayHelpText('Minimise le dommage du vehicule pour avoir plus de cash.') end)
				end

				if routeBlip ~= dropOffBlip then
					routeBlip = dropOffBlip
				end
			elseif routeBlip ~= vehicleBlip then
				routeBlip = vehicleBlip
			end

			if isInVehicle then
				World.SetWantedLevel(3)

				local playerX, playerY, playerZ = table.unpack(GetEntityCoords(PlayerPedId(), true))

				if GetDistanceBetweenCoords(playerX, playerY, playerZ, variant.dropOffLocation.x, variant.dropOffLocation.y, variant.dropOffLocation.z, true) < Settings.assetRecovery.dropRadius then
					TriggerServerEvent('lsv:assetRecoveryFinished', GetEntityHealth(vehicle) / GetEntityMaxHealth(vehicle))
					return
				end
			end
		else
			TriggerEvent('lsv:assetRecoveryFinished', false, 'Le temp est depasser.')
			return
		end
	end
end)


RegisterNetEvent('lsv:assetRecoveryFinished')
AddEventHandler('lsv:assetRecoveryFinished', function(success, reason)
	JobWatcher.FinishJob('Recouvrement Amiable')

	vehicle = nil

	RemoveBlip(vehicleBlip)
	vehicleBlip = nil

	RemoveBlip(dropOffBlip)
	dropOffBlip = nil

	RemoveBlip(dropOffLocationBlip)
	dropOffLocationBlip = nil

	World.SetWantedLevel(0)

	Gui.FinishJob('Recouvrement Amiable', success, reason)
end)
