local garageData = {}
local garageBlip = nil -- Blip is not individual and shared by all players

-- Define your garage location
local YourGarageX = 123.45
local YourGarageY = 678.90
local YourGarageZ = 10.0

-- Setar a distancia maxima para guardar o veiculo
local MaxDistanceToGarage = 10.0

-- Setar a saude minima do veiculo para guardar
local MinVehicleHealthToSave = 100

-- Função para criar o blip de garagem
function CreateGarageBlip()
    garageBlip = AddBlipForCoord(YourGarageX, YourGarageY, YourGarageZ)
    SetBlipSprite(garageBlip, 357) -- Blip ID for a garage circle (customize as needed)
    SetBlipDisplay(garageBlip, 4)
    SetBlipScale(garageBlip, 0.8)
    SetBlipColour(garageBlip, 3) -- Color for the blip (blue)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Garage")
    EndTextCommandSetBlipName(garageBlip)
end

-- Função para remover o blip
function RemoveGarageBlip()
    if garageBlip and DoesBlipExist(garageBlip) then
        RemoveBlip(garageBlip)
    end
    garageBlip = nil
end

-- Função para salvar o estado do carro
function SaveCarData(playerId, vehicle)
    local data = garageData[playerId]
    if not data then
        return
    end

    local vehicleHealth = GetEntityHealth(vehicle)
    local vehiclePosition = GetEntityCoords(vehicle)
    local garagePosition = vector3(YourGarageX, YourGarageY, YourGarageZ)
    local distanceToGarage = #(vehiclePosition - garagePosition)

    if vehicleHealth >= MinVehicleHealthToSave and distanceToGarage <= MaxDistanceToGarage then
        local vehicleData = {
            model = GetEntityModel(vehicle),
            position = vehiclePosition,
            heading = GetEntityHeading(vehicle),
            health = vehicleHealth,
            engineHealth = GetVehicleEngineHealth(vehicle),
            bodyHealth = GetVehicleBodyHealth(vehicle),
            tuningMods = GetVehicleMods(vehicle),
            -- Add more data as needed
        }

        table.insert(data.vehicles, vehicleData)
        TriggerClientEvent("chatMessage", playerId, "^2Vehicle saved to the garage.")
    elseif vehicleHealth < MinVehicleHealthToSave then
        TriggerClientEvent("chatMessage", playerId, "^1Vehicle is too damaged to be saved.")
    elseif distanceToGarage > MaxDistanceToGarage then
        TriggerClientEvent("chatMessage", playerId, "^1Vehicle is too far from the garage.")
    end
end

-- Função para spawnar o carro direto da garagem
function SpawnSavedCar(playerId, index)
    local data = garageData[playerId]
    if not data or not data.vehicles[index] then
        return
    end

    local vehicleData = data.vehicles[index]
    local modelHash = vehicleData.model
    local spawnPos = vehicleData.position
    local spawnHeading = vehicleData.heading

    -- Spawnar o carro salvo
    local vehicle = CreateVehicle(modelHash, spawnPos.x, spawnPos.y, spawnPos.z, spawnHeading, true, false)

    -- Setar o estado geral do carro
    SetEntityHealth(vehicle, vehicleData.health)
    SetVehicleEngineHealth(vehicle, vehicleData.engineHealth)
    SetVehicleBodyHealth(vehicle, vehicleData.bodyHealth)

    -- Spawnar com os mods da mec
    for modType, modIndex in pairs(vehicleData.tuningMods) do
        SetVehicleMod(vehicle, modType, modIndex)
    end

    -- Adicionar o carro ao player
    local playerPed = GetPlayerPed(playerId)
    TaskWarpPedIntoVehicle(playerPed, vehicle, -1)
end

-- Trigger a menu when a player presses 'E' near the garage blip
Citizen.CreateThread(function()
    CreateGarageBlip()

    while true do
        Citizen.Wait(0)
        for playerId = 0, 31 do
            if NetworkIsPlayerActive(playerId) then
                local playerPed = GetPlayerPed(playerId)
                local coords = GetEntityCoords(playerPed)
                local data = garageData[playerId]

                if garageBlip and DoesBlipExist(garageBlip) then
                    local blipCoords = GetBlipCoords(garageBlip)
                    local distance = #(coords - blipCoords)

                    if distance < 5.0 then
                        -- Display a help prompt to open the garage menu
                        if IsControlJustPressed(0, 38) then -- 'E' key
                            OpenGarageMenu(playerId)
                        end
                    end
                end
            end
        end
    end
end)

-- Function to open the garage menu
function OpenGarageMenu(playerId)
    local data = garageData[playerId]
    local menu = {}

    if not data or #data.vehicles == 0 then
        TriggerClientEvent("chatMessage", playerId, "^1No saved vehicles in the garage.")
    else
        -- Add vehicle information to the menu
        for index, vehicleData in ipairs(data.vehicles) do
            local vehicleInfo = "Model: " .. GetDisplayNameFromVehicleModel(vehicleData.model) .. "\n" ..
                                "Health: " .. vehicleData.health .. "\n" ..
                                "Engine Health: " .. vehicleData.engineHealth .. "\n" ..
                                "Body Health: " .. vehicleData.bodyHealth .. "\n"

            table.insert(menu, {
                name = "save_" .. index,
                label = "Guardar Veículo",
                value = vehicleInfo,
                index = index
            })

            table.insert(menu, {
                name = "spawn_" .. index,
                label = "Retirar Veículo",
                value = "Press Enter to Spawn",
                index = index
            })
        end

        -- Add an option to save a nearby vehicle
        table.insert(menu, {
            name = "save_nearby",
            label = "Guardar Próximo",
            value = "Press Enter to Save Nearby Vehicle"
        })
    end

    TriggerClientEvent("garage:openMenu", playerId, menu)
end

-- Menu garagem
function OpenGarageMenu(playerId)
    local data = garageData[playerId]
    if not data or #data.vehicles == 0 then
        TriggerClientEvent("chatMessage", playerId, "^1No saved vehicles in the garage.")
        return
    end

    local menu = NativeUI.CreateMenu("Garage", "Choose an option:")

    for index, vehicleData in ipairs(data.vehicles) do
        local vehicleName = GetLabelText(GetDisplayNameFromVehicleModel(vehicleData.model))

        local saveItem = NativeUI.CreateItem("Guardar Veículo", "Save this vehicle in the garage.")
        saveItem:SetRightBadge(NativeUI.BadgeStyle.Tick)
        saveItem.Activated = function(ParentMenu, SelectedItem)
            SaveCarData(playerId, vehicleData)
        end

        local retrieveItem = NativeUI.CreateItem("Retirar Veículo", "Retrieve this vehicle from the garage.")
        retrieveItem:SetRightBadge(NativeUI.BadgeStyle.Tick)
        retrieveItem.Activated = function(ParentMenu, SelectedItem)
            SpawnSavedCar(playerId, index)
        end

        menu:AddItem(saveItem)
        menu:AddItem(retrieveItem)
    end

    local saveNearbyItem = NativeUI.CreateItem("Guardar Próximo", "Save a nearby vehicle in the garage.")
    saveNearbyItem:SetRightBadge(NativeUI.BadgeStyle.Tick)
    saveNearbyItem.Activated = function(ParentMenu, SelectedItem)
        local playerPed = GetPlayerPed(playerId)
        local vehicle = GetVehiclePedIsIn(playerPed, false)
        
        if DoesEntityExist(vehicle) then
            SaveCarData(playerId, vehicle)
        else
            TriggerClientEvent("chatMessage", playerId, "^1No nearby vehicle to save.")
        end
    end

    menu:AddItem(saveNearbyItem)
    menu:Visible(true)
end

-- Register an event to handle the garage menu selection
RegisterServerEvent("garage:menuSelection")
AddEventHandler("garage:menuSelection", function(selection, playerId)
    local data = garageData[playerId]
    if not data then
        return
    end

    local action, index = string.match(selection, "^(%a+)_(%d+)$")

    if action == "save" and data.vehicles[index] then
        SaveCarData(playerId, data.vehicles[index])
    elseif action == "spawn" and data.vehicles[index] then
        SpawnSavedCar(playerId, index)
    elseif selection == "save_nearby" then
        local playerPed = GetPlayerPed(playerId)
        local vehicle = GetVehiclePedIsIn(playerPed, false)
        
        if DoesEntityExist(vehicle) then
            SaveCarData(playerId, vehicle)
        else
            TriggerClientEvent("chatMessage", playerId, "^1No nearby vehicle to save.")
        end
    end
end)

-- Initialize the garage data for each player
AddEventHandler("playerSpawned", function()
    local playerId = source
    garageData[playerId] = { vehicles = {} }
end)
