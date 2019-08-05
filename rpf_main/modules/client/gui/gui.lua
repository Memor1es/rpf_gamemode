Gui = { }

local cashGained = 0
local cashGainedTime = nil


Citizen.CreateThread(function()
	AddTextEntry('MONEY_ENTRY', '$~1~')
end)


function Gui.GetPlayerName(serverId, color, lowercase)
	if Player.ServerId() == serverId then
		if lowercase then
			return "Tu"
		else
			return "Tu"
		end
	else
		if not color then
			if Player.isCrewMember(serverId) then
				color = '~b~'
			else
				color = '~w~'
			end
		end


		return color..'<C>'..GetPlayerName(GetPlayerFromServerId(serverId))..'</C>~w~'
	end
end


function Gui.DisplayHelpText(text)
	BeginTextCommandDisplayHelp('STRING')
	AddTextComponentScaleform(tostring(text))
	EndTextCommandDisplayHelp(0, 0, 1, -1)
end


function Gui.DisplayNotification(text, pic, title, subtitle, icon)
	SetNotificationTextEntry("STRING")
	AddTextComponentSubstringPlayerName(tostring(text))

	if pic then
		SetNotificationMessage(pic, pic, false, icon or 4, title or "", subtitle or "")
	end

	DrawNotification(false, true)
end


function Gui.DrawRect(position, width, height, color)
	DrawRect(position.x, position.y, width, height, color.r, color.g, color.b, color.a)
end


function Gui.SetTextParams(font, color, scale, shadow, outline, center)
	SetTextFont(font)
	SetTextColour(color.r, color.g, color.b, color.a)
	SetTextScale(scale, scale)

	if shadow then
		SetTextDropshadow(8, 0, 0, 0, 255)
		SetTextDropShadow()
	end

	if outline then
		SetTextEdge(4, 0, 0, 0, 255)
		SetTextOutline()
	end

	if center then
		SetTextCentre(true)
	end
end


function Gui.DrawText(text, position, width)
	BeginTextCommandDisplayText('STRING')
	AddTextComponentSubstringPlayerName(tostring(text))
	if width then
		SetTextRightJustify(true)
		SetTextWrap(position.x - width, position.x)
	end
	EndTextCommandDisplayText(position.x, position.y)
end


function Gui.DrawNumeric(number, position)
	BeginTextCommandDisplayText('NUMBER')
	if type(number) == 'number' and not string.find(number, '%.') then
		AddTextComponentInteger(number)
	else
		AddTextComponentFloat(number, 2)
	end
	EndTextCommandDisplayText(position.x, position.y)
end


function Gui.DrawNumericTextEntry(entry, position, ...) -- Generalize it more?
	local params = { ... }
	BeginTextCommandDisplayText(entry)
	for _, v in ipairs(params) do
		if type(v) == 'number' and not string.find(v, '%.') then -- Move it to Utils?
			AddTextComponentInteger(v)
		else
			AddTextComponentFloat(v, 2) -- Configure it?
		end
	end
	EndTextCommandDisplayText(position.x, position.y)
end


function Gui.DisplayObjectiveText(text)
	BeginTextCommandPrint('STRING')
	AddTextComponentString(tostring(text))
	EndTextCommandPrint(1, true)
end


function Gui.DrawPlaceMarker(x, y, z, radius, r, g, b, a)
	DrawMarker(1, x, y, z, 0, 0, 0, 0, 0, 0, radius, radius, radius, r, g, b, a, false, nil, nil, false)
end


function Gui.StartJob(name, message, tip)
	local scaleform = Scaleform:Request('MIDSIZED_MESSAGE')
	scaleform:Call('SHOW_SHARD_MIDSIZED_MESSAGE', name, message or "")
	if tip then SetTimeout(11000, function() Gui.DisplayHelpText(tip) end) end
	PlaySoundFrontend(-1, 'EVENT_START_TEXT', 'GTAO_FM_EVENTS_SOUNDSET', true)
	scaleform:RenderFullscreenTimed(10000)
	scaleform:Delete()
end


function Gui.FinishJob(name, success, reason)
	StartScreenEffect('SuccessMichael', 0, false)

	if success then PlaySoundFrontend(-1, 'Mission_Pass_Notify', 'DLC_HEISTS_GENERAL_FRONTEND_SOUNDS', true)
	elseif not IsPlayerDead(PlayerId()) then PlaySoundFrontend(-1, 'ScreenFlash', 'MissionFailedSounds', true) end

	local status = success and 'COMPLETED' or 'FAILED'
	local message = reason or ''

	local scaleform = Scaleform:Request('MIDSIZED_MESSAGE')

	scaleform:Call('SHOW_SHARD_MIDSIZED_MESSAGE', string.upper(name)..' '..status, message)
	scaleform:RenderFullscreenTimed(7000)

	scaleform:Delete()
end


AddEventHandler('lsv:cashUpdated', function(cash)
	cashGained = cashGained + cash
	cashGainedTime = GetGameTimer()
end)


AddEventHandler('lsv:init', function()
	cashGainedTime = GetGameTimer()

	Streaming.RequestStreamedTextureDict('MPHud')

	local screenWidth, screenHeight = GetScreenResolution()
	local spriteScale = 18.0
	local textScale = 0.5

	while true do
		Citizen.Wait(0)

		if GetTimeDifference(GetGameTimer(), cashGainedTime) < Settings.cashGainedNotificationTime then
			if cashGained ~=0 and not IsPlayerDead(PlayerId()) then
				local playerX, playerY, playerZ = table.unpack(GetEntityCoords(PlayerPedId()))
				local z = playerZ + 1.0
				local sign = cashGained > 0 and '+' or '-'
				local color = cashGained > 0 and Color.GetHudFromBlipColor(Color.BlipWhite()) or Color.GetHudFromBlipColor(Color.BlipRed())

				SetDrawOrigin(playerX, playerY, z, 0)
				DrawSprite('MPHud', 'mp_anim_cash', 0.0, 0.0, spriteScale / screenWidth, spriteScale / screenHeight, 0.0, 255, 255, 255, 255)
				Gui.SetTextParams(4, color, textScale, true, true)
				Gui.DrawText(sign..''..math.abs(cashGained), { x = spriteScale / 2 / screenWidth, y = -spriteScale / 2 / screenHeight - 0.004 })
				ClearDrawOrigin()
			end
		else cashGained = 0 end
	end
end)