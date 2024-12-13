local speedBuffer, velBuffer, pauseActive, isCarHud, stress, speedMultiplier, PlayerData, SpeedType, PlayerData = {0.0,0.0}, {}, false, false, 0, nil, nil, nil
Display = nil
PlayerLoaded = nil
Loaded = nil
PlayerPed = nil
Framework = nil
Framework = GetFramework()
Citizen.CreateThread(function()
   while Framework == nil do Citizen.Wait(750) end
   Citizen.Wait(2500)
end)
Callback = Config.Framework == "ESX" or Config.Framework == "NewESX" and Framework.TriggerServerCallback or Framework.Functions.TriggerCallback

function Evaluate()
    return Config.Framework ~= nil and PlayerLoaded and PlayerPed ~= nil
end

Citizen.CreateThread(function()
    while true do
        PlayerPed = PlayerPedId()
        Citizen.Wait(4500)
    end
end)

local hudComponents = {6, 7, 8, 9, 3, 4}

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1)
        for _, component in ipairs(hudComponents) do
            HideHudComponentThisFrame(component)
        end
    end
end)

-- ! Stamina
Citizen.CreateThread(function()
    local wait, LastStamina, LastOxygen
    while true do
        local playerPed = PlayerPedId()
        local stamina = GetPlayerSprintStaminaRemaining(PlayerId())
        local inVehicle = IsPedInAnyVehicle(playerPed)
        local inWater = IsEntityInWater(playerPed)
        local isRunning = IsPedRunning(playerPed)
        local oxygen
        if inVehicle then
            wait = 2100
        else
            if inWater then
                wait = 125
                oxygen = GetPlayerUnderwaterTimeRemaining(PlayerId()) * 10
                if LastOxygen ~= oxygen then
                    LastOxygen = oxygen
                    SendNUIMessage({data = 'OXYGEN', value = math.ceil(oxygen)})
                end
            else
                wait = 1850
                if isRunning then
                    stamina = stamina - 1 
                    if stamina < 0 then stamina = 0 end 
                end
                if LastStamina ~= stamina then
                    LastStamina = stamina
                    local adjustedStamina = 100 - stamina
                    SendNUIMessage({data = 'STAMINA', value = math.ceil(adjustedStamina)})
                end
            end
        end
        Citizen.Wait(wait)
    end
end)

local parachuteTintIndex = 6
local waitTime = 1700

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(waitTime)
        local playerPed = PlayerPedId()
        local parachuteState = GetPedParachuteState(playerPed)
        local inAirVehicle = IsPedInAnyHeli(playerPed) or IsPedInAnyPlane(playerPed)
        if parachuteState >= 0 or inAirVehicle then
            SetPlayerParachutePackTintIndex(playerPed, parachuteTintIndex)
            local heightAboveGround = math.floor(GetEntityHeightAboveGround(playerPed))
            SendNUIMessage({ data = "PARACHUTE", value = heightAboveGround })
            SendNUIMessage({ data = "PARACHUTE_SET", value = true })
        else
            SendNUIMessage({ data = "PARACHUTE_SET", value = false })
        end
    end
end)

-- ! Health
local LastHealth
Citizen.CreateThread(function()
    local wait
    while true do
        if Evaluate() then
            local Health = math.floor((GetEntityHealth(PlayerPed)/2))
            if IsPedInAnyVehicle(PlayerPed) then wait = 250 else wait = 650 end
            if Health ~= LastHealth then
                if GetEntityModel(PlayerPed) == `mp_f_freemode_01` and Health ~= 0 then Health = (Health+13) end
                SendNUIMessage({data = 'HEALTH', Health})
                LastHealth = Health
            else
                wait = wait + 1200
            end
        else
            Citizen.Wait(2000)
        end
        Citizen.Wait(wait)
    end
end)

-- ! Armour
local function updateArmor()
    local Armour = GetPedArmour(PlayerPed)
    SendNUIMessage({data = 'ARMOR', Armour})
  end
  
  Citizen.CreateThread(function()
    while true do
      updateArmor()
      Citizen.Wait(2500)
    end
end)

-- ? Status
RegisterNetEvent('hud:client:UpdateNeeds', function(newHunger, newThirst) -- Triggered in qb-core
    local Hungerr = 0
    local Thirstt = 0
    if math.ceil(newHunger) > 100 then
        Hungerr = 100
    else
        Hungerr = math.ceil(newHunger)
    end
    if math.ceil(newThirst) > 100 then
        Thirstt = 100
    else
        Thirstt = math.ceil(newThirst)
    end
    SendNUIMessage({data = "STATUS", hunger = Hungerr, thirst = Thirstt})
end)

local seatbeltOn = false
local ejected = false
local immune = false
local immuneTime = 2000 -- 2 saniye
local previousSpeed = 0.0

-- İleri vektör hesaplama fonksiyonu
local function Fwv(entity)
    local hr = GetEntityHeading(entity) + 90.0
    if hr < 0.0 then hr = 360.0 + hr end
    hr = hr * 0.0174533
    return { x = math.cos(hr) * 2.0, y = math.sin(hr) * 2.0 }
end

-- Ses çalma fonksiyonu
local function playSound(soundName)
    TriggerServerEvent("InteractSound_SV:PlayOnSource", soundName, 0.25)
end

-- Bildirim gösterme fonksiyonu
local function notify(message, type)
    TriggerEvent("notification", message, type)
end

-- Kemer takma/çıkarma komutu
RegisterCommand("seatbelt", function()
    local playerPed = PlayerPedId()
    if IsPedInAnyVehicle(playerPed, false) then
        seatbeltOn = not seatbeltOn
        immune = true
        Citizen.SetTimeout(immuneTime, function()
            immune = false
        end)
        if seatbeltOn then
            notify("Kemer takıldı", 1)
            playSound("carbuckle")
            ejected = false
        else
            notify("Kemer çıkarıldı", 2)
            playSound("carunbuckle")
        end
    else
        notify("Araçta değilsiniz", 2)
    end
end, false)

RegisterKeyMapping('seatbelt', 'Toggle Seatbelt', 'keyboard', Config.SeatbeltControl) 

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(100) 
        local playerPed = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(playerPed, false)
        if vehicle ~= 0 then
            if seatbeltOn then
                DisableControlAction(0, 75, true) 
                local currentSpeed = GetEntitySpeed(vehicle) * 3.6 
                local speedThreshold = 50.0
                local decelerationThreshold = 10.0 
                local deltaSpeed = previousSpeed - currentSpeed
                if deltaSpeed > decelerationThreshold and currentSpeed > speedThreshold and not immune then
                    if not ejected then
                        ejected = true
                        local forwardVector = Fwv(playerPed)
                        local coords = GetEntityCoords(playerPed)
                        SetEntityCoords(playerPed, coords.x + forwardVector.x, coords.y + forwardVector.y, coords.z - 0.47, true, true, true)
                        SetEntityVelocity(playerPed, 0.0, 0.0, 0.0) 
                        Citizen.Wait(500)
                        SetPedToRagdoll(playerPed, 1000, 1000, 0, false, false, false)
                        seatbeltOn = false
                        notify("Araçtan fırlatıldınız!", 2)
                        playSound("eject")
                        Citizen.Wait(5000)
                        ejected = false
                    end
                end
                previousSpeed = currentSpeed
            else
                previousSpeed = 0.0
                Citizen.Wait(1000) 
            end
        else
            previousSpeed = 0.0
            Citizen.Wait(1000) 
        end
    end
end)




RegisterNetEvent('HudPlayerLoad', function(eyes)
    Citizen.Wait(tonumber(200))  
    local frameworkType = Config.Framework
    local playerDataFunc = (frameworkType == "ESX" or frameworkType == "NewESX")
        and Framework.GetPlayerData or Framework.Functions.GetPlayerData
    PlayerData = playerDataFunc()  
    stress = Config.Stress.Enabled and eyes or 0
    SendNUIMessage({data = "STRESS", stress = stress})
    if frameworkType == 'QBCore' or frameworkType == 'OLDQBCore' then 
        local metadata = PlayerData.metadata
        SendNUIMessage({
            data = "STATUS",
            hunger = math.ceil(metadata["hunger"]),
            thirst = math.ceil(metadata["thirst"])
        })
    end
    PlayerLoaded = true
end)


exports('eyestore', function(state)
    SendNUIMessage({ data = 'EXIT', args = state })
end)

local LastData = {
    speedMultiplier = 'KM/H',
    Speed = 0,
    Rpm = 0,
    Fuel = 0,
    Engine = false,
    Light = false,
    seatbeltOn = false,
    cruiseOn = false,
    doorsLocked = false,
    Signal = false,
    Gear = 0,
}

----------------------------------------------------------------------------------

Citizen.CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)
        if IsPedInVehicle(ped, vehicle, false) then
            local Percentage = (speedMultiplier == 'KM/H') and 3.6 or 2.23694
            local Speed = math.floor(GetEntitySpeed(vehicle) * Percentage)
            local RawRpm = GetVehicleCurrentRpm(vehicle)
            local Fuel = getFuelLevel(vehicle)
            local EngineHealth = GetVehicleEngineHealth(vehicle)
            local Engine = (EngineHealth / 10)
            if Engine > 100 then
                Engine = 100
            elseif Engine < 0 then
                Engine = 0
            end
            if Fuel > 100 then
                Fuel = 100
            elseif Fuel < 0 then
                Fuel = 0
            end
            local Seatbelt = seatbeltOn
            local Gear = GetVehicleCurrentGear(vehicle)
            local Cruise = cruiseOn
            local Doors = doorsLocked
            local _, LightLights, LightHighlights = GetVehicleLightsState(vehicle)
            local Light = LightLights == 1 or LightHighlights == 1
            local Signal = GetVehicleIndicatorLights(vehicle)
            local Rpm = math.floor(RawRpm * 190)
            Rpm = (Rpm == 40) and 0 or Rpm
            if LastData.Speed ~= Speed or LastData.Gear ~= Gear or LastData.Rpm ~= Rpm or LastData.Fuel ~= Fuel or 
               LastData.Engine ~= Engine or LastData.Light ~= Light or LastData.seatbeltOn ~= Seatbelt or 
               LastData.cruiseOn ~= Cruise or LastData.doorsLocked ~= Doors or LastData.Signal ~= Signal then
                DisplayRadar(true)
                SendNUIMessage({
                    data = 'CAR',
                    speed = Speed,
                    rpm = Rpm,
                    fuel = Fuel,
                    gear = Gear,
                    engine = Engine,
                    state = Light,
                    seatbelt = Seatbelt,
                    brakes = Cruise,
                    door = Doors,
                    signal = Signal,
                    multipler = speedMultiplier
                })
                LastData.Speed = Speed
                LastData.Rpm = Rpm
                LastData.Fuel = Fuel
                LastData.Engine = Engine
                LastData.Light = Light
                LastData.seatbeltOn = Seatbelt
                LastData.Gear = Gear
                LastData.cruiseOn = Cruise
                LastData.doorsLocked = Doors
                LastData.Signal = Signal
            end
            Citizen.Wait(100) 
        else
            SendNUIMessage({ data = 'CIVIL' })
            DisplayRadar(false)
            SetRadarBigmapEnabled(false, false)
            SetRadarZoom(1000)
            Citizen.Wait(1000) 
        end
    end
end)
 
local lastFuelUpdate = 0
function getFuelLevel(vehicle)
    local updateTick = GetGameTimer()
    if (updateTick - lastFuelUpdate) > 2000 then
        lastFuelUpdate = updateTick
        LastFuel = math.floor(Config.GetVehFuel(vehicle))
    end
    return LastFuel
end

------------------------------------------------------------------------------------------------------------------------------------

Citizen.CreateThread(function()
    Citizen.Wait(100)
    local defaultAspectRatio = 1920 / 1080
    local resolutionX, resolutionY = GetActiveScreenResolution()
    local aspectRatio = resolutionX / resolutionY
    local minimapOffset = 0

    if aspectRatio > defaultAspectRatio then
        minimapOffset = ((defaultAspectRatio - aspectRatio) / 3.6) - 0.008
    end
    RequestStreamedTextureDict("squaremap", false)
    while not HasStreamedTextureDictLoaded("squaremap") do
        Wait(150)
    end

    SetMinimapClipType(0)
    AddReplaceTexture("platform:/textures/graphics", "radarmasksm", "squaremap", "radarmasksm")
    AddReplaceTexture("platform:/textures/graphics", "radarmask1g", "squaremap", "radarmasksm")

    SetMinimapComponentPosition("minimap", "L", "B", 0.0 + minimapOffset, -0.1, 0.1638, 0.183)
    SetMinimapComponentPosition("minimap_mask", "L", "B", 0.0 + minimapOffset, 0.015, 0.128, 0.2)
    SetMinimapComponentPosition("minimap_blur", "L", "B", -0.010 + minimapOffset, 0.0099, 0.320, 0.3)

    SetBlipAlpha(GetNorthRadarBlip(), 0)
    SetRadarBigmapEnabled(true, false)
    SetMinimapClipType(0)
    Wait(0)
    SetRadarBigmapEnabled(false, false)
end)

------------------------------------------------------------------------------------------------------------------------------------

exports('eyestore', function(state)
    SendNUIMessage({ data = 'EXIT', args = state })
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(650)
        local isMenuActive = IsPauseMenuActive()
        if isMenuActive ~= pauseActive then
            exports[GetCurrentResourceName()]:eyestore(not isMenuActive)
            pauseActive = isMenuActive
        end
    end
end)


local playerPed = nil
local function updatePlayerPed()
  playerPed = PlayerPedId()
end

local function relieveStress(action, configKey)
  updatePlayerPed()
  if Config.RemoveStress[configKey].enable and action(playerPed) then
    local val = math.random(Config.RemoveStress[configKey].min, Config.RemoveStress[configKey].max)
    TriggerServerEvent('hud:server:RelieveStress', val)
  end
end


local function addStress(condition, action, configKey)
  updatePlayerPed()
  if Config.AddStress[configKey].enable and condition() then
    action(Config.AddStress[configKey])
  end
end


Citizen.CreateThread(function()
  while true do
    Citizen.Wait(1000) 
    relieveStress(IsPedSwimming, "on_swimming")
    relieveStress(IsPedRunning, "on_running")
    addStress(function()
      return IsPedInAnyVehicle(playerPed, false) and GetEntitySpeed(GetVehiclePedIsIn(playerPed, false)) * 3.6 > 110
    end, function(config)
      TriggerServerEvent('hud:server:GainStress', math.random(config.min, config.max))
    end, "on_fastdrive")
    if Config.AddStress["on_shoot"].enable then
      local weapon = GetSelectedPedWeapon(playerPed)
      if weapon ~= `WEAPON_UNARMED` and IsPedShooting(playerPed) then
        if math.random() < 0.15 and not IsWhitelistedWeaponStress(weapon) then
          TriggerServerEvent('hud:server:GainStress', math.random(Config.AddStress["on_shoot"].min, Config.AddStress["on_shoot"].max))
        end
      end
    end
  end
end)

   
   function IsWhitelistedWeaponStress(weapon)
      if weapon then
         for _, v in pairs(Config.WhitelistedWeaponStress) do
            if weapon == v then
               return true
            end
         end
      end
      return false
   end

   Citizen.CreateThread(function()
   while true do
      local ped = PlayerPedId()
      if tonumber(stress) >= 100 then
         local ShakeIntensity = GetShakeIntensity(stress)
         local FallRepeat = math.random(2, 4)
         local RagdollTimeout = (FallRepeat * 1750)
         ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', ShakeIntensity)
         SetFlash(0, 0, 500, 3000, 500)
   
         if not IsPedRagdoll(ped) and IsPedOnFoot(ped) and not IsPedSwimming(ped) then
            SetPedToRagdollWithFall(ped, RagdollTimeout, RagdollTimeout, 1, GetEntityForwardVector(ped), 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
         end
   
         Wait(500)
         for i=1, FallRepeat, 1 do
            Wait(750)
            DoScreenFadeOut(200)
            Wait(1000)
            DoScreenFadeIn(200)
            ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', ShakeIntensity)
            SetFlash(0, 0, 200, 750, 200)
         end
      end
   
      if stress >= 50 then
         local ShakeIntensity = GetShakeIntensity(stress)
         ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', ShakeIntensity)
         SetFlash(0, 0, 500, 2500, 500)
      end
      Wait(GetEffectInterval(stress))
   end
   end)
   
   
   function GetShakeIntensity(stresslevel)
      local retval = 0.05
      local Intensity = Config.Intensity
      for k, v in pairs(Intensity['shake']) do
         if stresslevel >= v.min and stresslevel <= v.max then
            retval = v.intensity
            break
         end
      end
      return retval
   end
   
   function GetEffectInterval(stresslevel)
      local EffectInterval = Config.EffectInterval
      local retval = 10000
      for k, v in pairs(EffectInterval) do
         if stresslevel >= v.min and stresslevel <= v.max then
            retval = v.timeout
            break
         end
      end
      return retval
   end
   
   RegisterNetEvent('hud:client:UpdateStress', function(newStress) -- Add this event with adding stress elsewhere
    stress = newStress
    SendNUIMessage({ data = 'STRESS', stress = math.ceil(newStress) })
   end)
   
   RegisterNetEvent('esx_basicneeds:onEat')
   AddEventHandler('esx_basicneeds:onEat', function()
   if Config.RemoveStress["on_eat"].enable then
      local val = math.random(Config.RemoveStress["on_eat"].min, Config.RemoveStress["on_eat"].max)
      TriggerServerEvent('hud:server:RelieveStress', val)
   end
   end)
   
   RegisterNetEvent('consumables:client:Eat')
   AddEventHandler('consumables:client:Eat', function()
   if Config.RemoveStress["on_eat"].enable then
      local val = math.random(Config.RemoveStress["on_eat"].min, Config.RemoveStress["on_eat"].max)
      TriggerServerEvent('hud:server:RelieveStress', val)
   end
   end)
   
   
   RegisterNetEvent('consumables:client:Drink')
   AddEventHandler('consumables:client:Drink', function()
   if Config.RemoveStress["on_drink"].enable then
      local val = math.random(Config.RemoveStress["on_drink"].min, Config.RemoveStress["on_drink"].max)
      TriggerServerEvent('hud:server:RelieveStress', val)
   end
   end)
   RegisterNetEvent('consumables:client:DrinkAlcohol')
   AddEventHandler('consumables:client:DrinkAlcohol', function()
   if Config.RemoveStress["on_drink"].enable then
      local val = math.random(Config.RemoveStress["on_drink"].min, Config.RemoveStress["on_drink"].max)
      TriggerServerEvent('hud:server:RelieveStress', val)
   end
   end)
   
   RegisterNetEvent('devcore_needs:client:StartEat')
   AddEventHandler('devcore_needs:client:StartEat', function()
   if Config.RemoveStress["on_eat"].enable then
      local val = math.random(Config.RemoveStress["on_eat"].min, Config.RemoveStress["on_eat"].max)
      TriggerServerEvent('hud:server:RelieveStress', val)
   end
   end)
   RegisterNetEvent('devcore_needs:client:DrinkShot')
   AddEventHandler('devcore_needs:client:DrinkShot', function()
   if Config.RemoveStress["on_drink"].enable then
      local val = math.random(Config.RemoveStress["on_drink"].min, Config.RemoveStress["on_drink"].max)
      TriggerServerEvent('hud:server:RelieveStress', val)
   end
   end)
   
   RegisterNetEvent('devcore_needs:client:StartDrink')
   AddEventHandler('devcore_needs:client:StartDrink', function()
   if Config.RemoveStress["on_drink"].enable then
      local val = math.random(Config.RemoveStress["on_drink"].min, Config.RemoveStress["on_drink"].max)
      TriggerServerEvent('hud:server:RelieveStress', val)
   end
   end)
   
   RegisterNetEvent('esx_optionalneeds:onDrink')
   AddEventHandler('esx_optionalneeds:onDrink', function()
   if Config.RemoveStress["on_drink"].enable then
      local val = math.random(Config.RemoveStress["on_drink"].min, Config.RemoveStress["on_drink"].max)
      TriggerServerEvent('hud:server:RelieveStress', val)
   end
   end)
   
   
   RegisterNetEvent('esx_basicneeds:onDrink')
   AddEventHandler('esx_basicneeds:onDrink', function()
   if Config.RemoveStress["on_drink"].enable then
      local val = math.random(Config.RemoveStress["on_drink"].min, Config.RemoveStress["on_drink"].max)
      TriggerServerEvent('hud:server:RelieveStress', val)
   end
   end)
   
   AddEventHandler('esx:onPlayerDeath', function()
   TriggerServerEvent('hud:server:RelieveStress', 10000)
   end)
   
   RegisterNetEvent('hospital:client:RespawnAtHospital')
   AddEventHandler('hospital:client:RespawnAtHospital', function()
   TriggerServerEvent('hud:server:RelieveStress', 10000)
   end)

------------------------------------------------------------------------------------------------------------------------------------


function setMicrophoneSettings(type, value)
    SendNUIMessage({ data = "SOUND", type = type, value = value })
end

local micIsOn = true
local firstCheck = true
function registerEvent(eventName, handler)
    RegisterNetEvent(eventName)
    AddEventHandler(eventName, handler)
end
if Config.Voice == 'mumble' or Config.Voice == 'pma' then
    registerEvent('pma-voice:setTalkingMode', function(voiceMode)
        setMicrophoneSettings('mic_level', voiceMode)
    end)
    registerEvent("mumble:SetVoiceData", function(player, key, value)
        local playerPed = PlayerPedId() 
        if GetPlayerServerId(NetworkGetEntityOwner(playerPed)) == player and key == 'mode' then
            setMicrophoneSettings('mic_level', value)
        end
    end)
    CreateThread(function()
        local isTalking = false
        while true do
            isTalking = NetworkIsPlayerTalking(PlayerId())
            setMicrophoneSettings('isTalking', isTalking)
            Wait(800)
        end
    end)
    CreateThread(function()
        while true do
            local isConnected = MumbleIsConnected()
            if isConnected ~= micIsOn or firstCheck then
                micIsOn = isConnected
                firstCheck = false
                setMicrophoneSettings('isMuted', not isConnected)
            end
            Wait(2000)
        end
    end)
else
    registerEvent('SaltyChat_VoiceRangeChanged', function(voiceRange, index)
        setMicrophoneSettings('mic_level', index + 1)
    end)

    registerEvent('SaltyChat_TalkStateChanged', function(isTalking)
        setMicrophoneSettings('isTalking', isTalking)
    end)

    registerEvent('SaltyChat_PluginStateChanged', function(state)
        setMicrophoneSettings('isMuted', state == 0 or state == -1)
    end)

    registerEvent('SaltyChat_MicStateChanged', function(isMicrophoneMuted)
        setMicrophoneSettings('isMuted', isMicrophoneMuted)
    end)
end