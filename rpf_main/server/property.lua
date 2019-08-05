local Tunnel = module("vrp", "lib/Tunnel")
local Proxy = module("vrp", "lib/Proxy")

vRP = Proxy.getInterface("vRP")
vRPclient = Tunnel.getInterface("vRP","lsv-main")

local logger = Logger:CreateNamedLogger('HotProperty')

local propertyData = nil

local function getPlayerIndexById(id)
	for i, v in pairs(propertyData.players) do
		if v.id == id then return i end
	end

	return nil
end

local function sortPlayersByTotalTime(l, r)
	if not l then return false end
	if not r then return true end
	return l.totalTime > r.totalTime
end


AddEventHandler('lsv:startHotProperty', function()
	propertyData = { }
	propertyData.players = { }
	propertyData.currentPlayer = nil
	propertyData.placeIndex = math.random(Utils.GetTableLength(Settings.castle.places))
	propertyData.eventStartTime = GetGameTimer()

	logger:Info('Start { '..propertyData.placeIndex..' }')

	TriggerClientEvent('lsv:startHotProperty', -1, propertyData.placeIndex)

	while true do
		Citizen.Wait(0)

		if propertyData and GetGameTimer() - propertyData.eventStartTime >= Settings.property.duration then
			local winners = nil

			if not Utils.IsTableEmpty(propertyData.players) then
				winners = { }

				for i = 1, Utils.GetTableLength(Settings.property.rewards) do
					if propertyData.players[i] then
						logger:Info('Gagner { '..i..', '..propertyData.players[i].id..' }')
						vRP.giveMoney({propertyData.players[i].id, Settings.property.rewards[i]})
						table.insert(winners, propertyData.players[i].id)
					else break end
				end
			else logger:Info('No winners') end

			propertyData = nil
			TriggerClientEvent('lsv:finishHotProperty', -1, winners)
			TriggerEvent('lsv:onEventStopped')
		end
	end
end)


AddEventHandler('lsv:playerConnected', function(player)
	if propertyData then
		TriggerClientEvent('lsv:startHotProperty', player, propertyData.placeIndex, GetGameTimer() - propertyData.eventStartTime, propertyData.players, propertyData.currentPlayer)
	end
end)


RegisterServerEvent('lsv:hotPropertyCollected')
AddEventHandler('lsv:hotPropertyCollected', function()
	if not propertyData or propertyData.currentPlayer then return end
	local player = source
	local playerIndex = getPlayerIndexById(player)
	if not playerIndex then table.insert(propertyData.players, { id = player, totalTime = 0 }) end
	propertyData.currentPlayer = player
	logger:Info('Collected { '..player..' }')
	table.sort(propertyData.players, sortPlayersByTotalTime)
	TriggerClientEvent('lsv:updateHotPropertyPlayers', -1, propertyData.players)
	TriggerClientEvent('lsv:hotPropertyCollected', -1, player)
end)


RegisterServerEvent('lsv:hotPropertyTimeUpdated')
AddEventHandler('lsv:hotPropertyTimeUpdated', function()
	if not propertyData then return end
	local player = source
	local playerIndex = getPlayerIndexById(player)
	if playerIndex then
		propertyData.players[playerIndex].totalTime = propertyData.players[playerIndex].totalTime + 1000
		table.sort(propertyData.players, sortPlayersByTotalTime)
		TriggerClientEvent('lsv:updateHotPropertyPlayers', -1, propertyData.players)
	end
end)


AddEventHandler('baseevents:onPlayerDied', function()
	local player = source
	if not propertyData or not propertyData.currentPlayer or propertyData.currentPlayer ~= player then return end
	logger:Info('Dropped { '..player..' }')
	propertyData.currentPlayer = nil
	TriggerClientEvent('lsv:hotPropertyDropped', -1, player)
end)


AddEventHandler('baseevents:onPlayerKilled', function()
	local player = source
	if not propertyData or not propertyData.currentPlayer or propertyData.currentPlayer ~= player then return end
	logger:Info('Dropped { '..player..' }')
	propertyData.currentPlayer = nil
	TriggerClientEvent('lsv:hotPropertyDropped', -1, player)
end)


AddEventHandler('lsv:playerDropped', function(player)
	if not propertyData then return end

	if Scoreboard.GetPlayersCount() == 0 then
		propertyData = nil
		TriggerEvent('lsv:onEventStopped')
		return
	end

	local playerIndex = getPlayerIndexById(player)
	if playerIndex then
		table.remove(propertyData.players, playerIndex)
		table.sort(propertyData.players, sortPlayersByTotalTime)
		TriggerClientEvent('lsv:updateHotPropertyPlayers', -1, propertyData.players)
	end

	if propertyData.currentPlayer == player then
		logger:Info('Dropped { '..player..' }')
		propertyData.currentPlayer = nil
		TriggerClientEvent('lsv:hotPropertyDropped', -1, player)
	end
end)
