local logger = Logger:CreateNamedLogger('StuntJump')


local isStuntJumpInProcess = false
local stuntJumpHeight = 0.0
local playerVehicle = nil
local startingCoords = nil


local function resetStuntJump()
	logger:Debug('Reset')
	isStuntJumpInProcess = false
	stuntJumpHeight = 0.0
	playerVehicle = nil
	startingCoords = nil
end


AddEventHandler('lsv:init', function()
	local lastStuntJumpTime = GetGameTimer()

	while true do
		Citizen.Wait(0)

		local playerPed = PlayerPedId()
		local isPlayerInVehicle = IsPedSittingInAnyVehicle(playerPed)
		if not isPlayerInVehicle then
			if playerVehicle then resetStuntJump() end
		else
			local vehicle = GetVehiclePedIsUsing(playerPed)
			if playerVehicle and playerVehicle ~= vehicle then resetStuntJump() end
			if not IsPedInAnyHeli(playerPed) and not IsPedInAnyPlane(playerPed) then playerVehicle = vehicle end
		end

		if playerVehicle and not IsPlayerDead(PlayerId()) then
			if IsEntityInAir(playerVehicle) and GetTimeDifference(GetGameTimer(), lastStuntJumpTime) > Settings.stuntMinInterval then
				local height = GetEntityHeightAboveGround(playerVehicle)
				if height > 0.0 then
					if not isStuntJumpInProcess then
						logger:Debug('Started')
						isStuntJumpInProcess = true
						startingCoords = GetEntityCoords(playerPed, true)
					end

					if height > stuntJumpHeight then
						stuntJumpHeight = height
						logger:Debug('Height: '..stuntJumpHeight)
					end
				end
			elseif isStuntJumpInProcess then
				local isStuntJumpHeightEnough = stuntJumpHeight > Settings.stuntJumpMinHeight
				local isStuntJumpSucceeded = isStuntJumpHeightEnough and IsVehicleDriveable(playerVehicle) and not IsVehicleStuckOnRoof(playerVehicle)

				if isStuntJumpSucceeded then
					currentCoords = GetEntityCoords(playerPed, true)
					TriggerServerEvent('lsv:stuntJumpCompleted', stuntJumpHeight, CalculateTravelDistanceBetweenPoints(startingCoords.x, startingCoords.y, startingCoords.z, currentCoords.x, currentCoords.y, currentCoords.z))
					lastStuntJumpTime = GetGameTimer()
				elseif isStuntJumpHeightEnough then Gui.DisplayNotification('Stunt Jump failed.') end

				resetStuntJump()
			end
		end
	end
end)


RegisterNetEvent('lsv:stuntJumpCompleted')
AddEventHandler('lsv:stuntJumpCompleted', function(height, distance)
	StartScreenEffect('SuccessMichael', 0, false)
	SetTimeout(1000, function() Gui.DisplayNotification('~b~Stunt Jump valider ! ~w~\nDistance : '..string.format('%.1f', distance)..'Hauteur: '..string.format('%.1f', height)..'metre') end)
end)
