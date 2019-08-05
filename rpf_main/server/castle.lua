local Tunnel = module("vrp", "lib/Tunnel")
local Proxy = module("vrp", "lib/Proxy")

vRP = Proxy.getInterface("vRP")
vRPclient = Tunnel.getInterface("vRP","lsv-main")

local logger = Logger:CreateNamedLogger('Castle')

local castleData = nil

local function getPlayerIndexById(id)
	for i, v in pairs(castleData.players) do
		if v.id == id then return i end
	end

	return nil
end

local function sortPlayersByPoints(l, r)
	if not l then return false end
	if not r then return true end
	return l.points > r.points
end


AddEventHandler('lsv:startCastle', function()
	castleData = { }
	castleData.players = { }
	castleData.placeIndex = math.random(Utils.GetTableLength(Settings.castle.places))
	castleData.eventStartTime = GetGameTimer()

	logger:Info('Start { '..castleData.placeIndex..' }')

	TriggerClientEvent('lsv:startCastle', -1, castleData.placeIndex)

	while true do
		Citizen.Wait(0)

		if castleData and GetGameTimer() - castleData.eventStartTime >= Settings.castle.duration then
			local winners = nil

			if not Utils.IsTableEmpty(castleData.players) then
				winners = { }

				for i = 1, Utils.GetTableLength(Settings.castle.rewards) do
					if castleData.players[i] then
						logger:Info('Vous avez gagner { '..i..', '..castleData.players[i].id..' }')
						vRP.giveMoney({castleData.players[i].id, Settings.castle.rewards[i]})
						table.insert(winners, castleData.players[i].id)
					else break end
				end
			else logger:Info('Vous avez perdu') end

			castleData = nil
			TriggerClientEvent('lsv:finishCastle', -1, winners)
			TriggerEvent('lsv:onEventStopped')
		end
	end
end)


RegisterServerEvent('lsv:castleAddPoint')
AddEventHandler('lsv:castleAddPoint', function()
	if not castleData then return end

	local player = source

	local playerIndex = getPlayerIndexById(player)
	if not playerIndex then table.insert(castleData.players, { id = player, points = 1 })
	else castleData.players[playerIndex].points = castleData.players[playerIndex].points + 1 end

	table.sort(castleData.players, sortPlayersByPoints)
	TriggerClientEvent('lsv:updateCastlePlayers', -1, castleData.players)
end)


AddEventHandler('lsv:playerConnected', function(player)
	if castleData then
		TriggerClientEvent('lsv:startCastle', player, castleData.placeIndex, GetGameTimer() - castleData.eventStartTime, castleData.players)
	end
end)


AddEventHandler('lsv:playerDropped', function(player)
	if not castleData then return end

	if Scoreboard.GetPlayersCount() == 0 then
		castleData = nil
		TriggerEvent('lsv:onEventStopped')
		return
	end

	local playerIndex = getPlayerIndexById(player)
	if not playerIndex then return end

	table.remove(castleData.players, playerIndex)
	table.sort(castleData.players, sortPlayersByPoints)
	TriggerClientEvent('lsv:updateCastlePlayers', -1, castleData.players)
end)
