local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/xHeptc/Kavo-UI-Library/main/source.lua"))()
local Window = Library.CreateLib("Edited Hub", "BloodTheme")

local Tab = Window:NewTab("Main")
local Section = Tab:NewSection("Automation Settings")

local autoBidEnabled = false
local autoPastEnabled = false

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local itemPrice = 0.17
local placeDelay = 0.5

local _Events = ReplicatedStorage:WaitForChild('Events')
local _Auction = _Events:WaitForChild('Auction')
local BidEvent = _Auction:WaitForChild('Bid')

local _NPCShopper = _Events:WaitForChild('NPCShopper')
local _ShowOffer = _NPCShopper:WaitForChild('ShowOffer')
local _RespondOffer = _NPCShopper:WaitForChild('RespondOffer')

local TransferEvent = _Events:WaitForChild("Vehicles"):WaitForChild("TransferVehicleItemsToInventory")
local InventoryEvent = _Events:WaitForChild("Inventory"):WaitForChild("GetPlayerInventory")
local PlaceStockEvent = _Events:WaitForChild("Plot"):WaitForChild("PlaceStockItem")

local UUID = nil
_ShowOffer.OnClientEvent:Connect(function(offerId)
    if typeof(offerId) == "string" or offerId ~= nil then
        UUID = offerId
    end
end)

local function isUUID(str)
    return type(str) == "string" and str:match("%w+%-%w+%-%w+%-%w+%-%w+") ~= nil
end

local function SellItems()
    if UUID then
        _RespondOffer:FireServer(UUID, true)
        task.wait(0.5)
    end
end
local function TeleportTo(cframe)
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        char.HumanoidRootPart.CFrame = cframe
    end
end

local function getMyVehicle()
    for _, obj in pairs(workspace:GetChildren()) do
        if obj:IsA("Model") then
            local ownerId = obj:GetAttribute("OwnerUserId")
            if ownerId and tostring(ownerId) == tostring(LocalPlayer.UserId) then
                return obj
            end
        end
    end
    
    local vehiclesFolder = workspace:FindFirstChild("Vehicles")
    if vehiclesFolder then
        for _, obj in pairs(vehiclesFolder:GetChildren()) do
            if obj:IsA("Model") then
                local ownerId = obj:GetAttribute("OwnerUserId")
                if ownerId and tostring(ownerId) == tostring(LocalPlayer.UserId) then
                    return obj
                end
            end
        end
    end
    return nil
end

local function MoveCarTo(targetCFrame)
    local myCar = getMyVehicle()
    if not myCar then return end
    pcall(function()
        myCar:PivotTo(targetCFrame)
    end)
end

local function getMyPlot()
    local plotsFolder = workspace:FindFirstChild("_Plots")
    if plotsFolder then
        for _, plot in pairs(plotsFolder:GetChildren()) do
            local val = plot:GetAttribute("OwnerName") or (plot:FindFirstChild("OwnerName") and plot.OwnerName.Value)
            if val and (tostring(val) == LocalPlayer.Name or tostring(val) == LocalPlayer.DisplayName or tostring(val) == tostring(LocalPlayer.UserId)) then
                return plot
            end
        end
    end
    return nil
end

local function getUnloadPosition(plot)
    if not plot then return nil end
    local structures = plot:FindFirstChild("Structures")
    if structures then
        for _, obj in pairs(structures:GetChildren()) do
            if obj.Name == "Asphalt Floor" then
                local targetPart = obj:IsA("Model") and obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
                if targetPart then
                    return targetPart.CFrame + Vector3.new(16, 0, 31)
                end
            end
        end
    end
    return nil
end

local function Teleport(targetCFrame, isPlot, plotInstance)
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    
    local currentPos = char.HumanoidRootPart.Position
    local targetPos = targetCFrame.Position
    local dist = (targetPos - currentPos).Magnitude
    
    if dist > 50 then
        local myCar = getMyVehicle()
        if myCar then
            local humanoid = char:FindFirstChild("Humanoid")
            local attempts = 0
            while humanoid and not humanoid.Sit do
                local carPart = myCar.PrimaryPart or myCar:FindFirstChild("DriveSeat", true) or myCar:FindFirstChildWhichIsA("BasePart")
                if carPart then
                    TeleportTo(carPart.CFrame + Vector3.new(0, 3, 0))
                end
                
                local driveSeat = myCar:FindFirstChild("DriveSeat", true)
                local seatPrompt = driveSeat and driveSeat:FindFirstChildWhichIsA("ProximityPrompt", true)
                if not seatPrompt then
                    for _, p in pairs(myCar:GetDescendants()) do
                        if p:IsA("ProximityPrompt") then
                            seatPrompt = p
                            break
                        end
                    end
                end

                if seatPrompt then
                    seatPrompt.RequiresLineOfSight = false
                    fireproximityprompt(seatPrompt)
                end
                
                task.wait(0.3)
                attempts = attempts + 1
                if attempts > 30 then break end
            end
            
            if humanoid and humanoid.Sit then
                task.wait(0.5)
                if isPlot and plotInstance then
                    local unloadCF = getUnloadPosition(plotInstance)
                    if unloadCF then
                        MoveCarTo(unloadCF + Vector3.new(0, 3, 0))
                    else
                        MoveCarTo(targetCFrame + Vector3.new(0, 3, 0))
                    end
                else
                    MoveCarTo(CFrame.new(targetPos + Vector3.new(25, 3, 25)))
                    task.wait(1)
                    humanoid.Jump = true
                    task.wait(0.8)
                end
            end
        end
    end
    
    if not isPlot then
        TeleportTo(targetCFrame)
        task.wait(0.5)
    end
end
local function getCarCurrentWeight(myCar)
    if not myCar then return 0 end
    return myCar:GetAttribute("CargoWeight") or 0
end

local function unloadMyVehicle()
    local myCar = getMyVehicle()
    if not myCar then return end

    local itemUUIDs = {}
    for _, obj in pairs(myCar:GetDescendants()) do
        for _, attrValue in pairs(obj:GetAttributes()) do
            if isUUID(tostring(attrValue)) then
                table.insert(itemUUIDs, tostring(attrValue))
            end
        end
        if obj:IsA("StringValue") and isUUID(obj.Value) then
            table.insert(itemUUIDs, obj.Value)
        end
    end

    if #itemUUIDs > 0 then
        TransferEvent:FireServer(itemUUIDs)
    end
end

local function getDynamicPrice(targetUUID)
    local uiController = LocalPlayer.PlayerGui:FindFirstChild("UIControllerGui")
    local hotbar = uiController and uiController:FindFirstChild("HotbarContainer")
    if hotbar then
        for _, slotUi in pairs(hotbar:GetChildren()) do
            if slotUi:IsA("GuiObject") then
                local slotUUID = nil
                for attrName, attrValue in pairs(slotUi:GetAttributes()) do
                    if isUUID(tostring(attrValue)) then slotUUID = tostring(attrValue) break end
                end
                if not slotUUID then
                    for _, child in pairs(slotUi:GetDescendants()) do
                        if (child:IsA("StringValue") or child:IsA("ObjectValue")) and isUUID(tostring(child.Value)) then
                            slotUUID = tostring(child.Value) break
                        end
                    end
                end
                if slotUUID == targetUUID then
                    local priceLabel = slotUi:FindFirstChild("PriceLabel", true)
                    if priceLabel and priceLabel:IsA("TextLabel") then
                        local cleanText = priceLabel.Text:gsub("[^%d%.]", "") 
                        local numPrice = tonumber(cleanText)
                        if numPrice then return numPrice end
                    end
                end
            end
        end
    end
    return tonumber(itemPrice) 
end

local function PlaceItemsFromInventory()
    local success, inventory = pcall(function() return InventoryEvent:InvokeServer() end)
    if not success or not inventory then return 0 end

    local myPlot = getMyPlot()
    if not myPlot then return 0 end

    local furnitureFolder = myPlot:FindFirstChild("Furniture")
    if not furnitureFolder then return 0 end

    local itemQueue = {}
    for k, v in pairs(inventory) do
        local uuid = tostring(k)
        if isUUID(uuid) then table.insert(itemQueue, {uuid = uuid, info = v}) end
    end
    if #itemQueue == 0 then return 0 end

    local snapPointsQueue = {}
    for _, furniture in pairs(furnitureFolder:GetChildren()) do
        local furnGUID = furniture:GetAttribute("GUID") or furniture:GetAttribute("Id") or "1"
        for _, desc in pairs(furniture:GetDescendants()) do
            local nameLower = string.lower(desc.Name)
            if (desc:IsA("BasePart") or desc:IsA("Attachment")) and nameLower:find("snap") then
                if desc:FindFirstChild("ShelfAddItemPrompt") then
                    table.insert(snapPointsQueue, {
                        point = desc,
                        guid = tostring(furnGUID)
                    })
                end
            end
        end
    end

    if #snapPointsQueue == 0 then return 0 end

    for i = 1, math.min(#itemQueue, #snapPointsQueue) do
        local itemData = itemQueue[i]
        local snapData = snapPointsQueue[i]
        local uuid = itemData.uuid
        local itemID = tostring(itemData.info.ItemId or "2")
        
        local price = getDynamicPrice(uuid)
        local slot = snapData.guid
        
        local snapPoint = snapData.point
        local targetCFrame = snapPoint:IsA("Attachment") and snapPoint.WorldCFrame or snapPoint.CFrame

        PlaceStockEvent:FireServer(
            uuid, itemID, targetCFrame, price, slot, snapPoint.Name, nil, nil, true
        )
        task.wait(placeDelay)
    end
    return #itemQueue
end

Section:NewToggle("Auto Bid", "", function(state)
    autoBidEnabled = state
end)

Section:NewToggle("Auto place", "", function(state)
    autoPastEnabled = state
end)
local currentGarage = nil 
local myWonGarage = nil    

task.spawn(function()
    while true do
        task.wait(0.5)
        if autoPastEnabled then
            local success, inventory = pcall(function() return InventoryEvent:InvokeServer() end)
            local hasInventoryItems = false
            if success and inventory then
                for k, _ in pairs(inventory) do
                    if isUUID(tostring(k)) then hasInventoryItems = true break end
                end
            end
            if hasInventoryItems then
                if UUID then
                    SellItems()
                else
                    PlaceItemsFromInventory()
                end
                task.wait(1)
                continue
            end
            local myCar = getMyVehicle()
            if myCar then
                local currentWeight = getCarCurrentWeight(myCar)
                if currentWeight > 0 then
                    local myPlot = getMyPlot()
                    if myPlot then
                        Teleport(CFrame.new(0,0,0), true, myPlot)
                        task.wait(1.5)
                        unloadMyVehicle()
                        task.wait(2)
                    end
                    continue
                end
            end
        end
        if myWonGarage then
            local humanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")
            if humanoid and humanoid.Sit then
                humanoid.Jump = true
                task.wait(0.5)
            end

            local carryables = workspace:FindFirstChild("_Carryables")
            local garagePos = myWonGarage:GetPivot().Position
            local foundItems = 0

            local function collectPrompts(parentObj)
                if not parentObj then return end
                for _, prompt in pairs(parentObj:GetDescendants()) do
                    if prompt:IsA("ProximityPrompt") and prompt.Enabled then
                        local part = prompt.Parent
                        if part and part:IsA("BasePart") and part.Name ~= "DriveSeat" and not part:IsA("VehicleSeat") and part.Name ~= "PromptPart" then
                            local dist = (part.Position - garagePos).Magnitude
                            if dist <= 40 then 
                                foundItems = foundItems + 1
                                TeleportTo(part.CFrame + Vector3.new(0, 2, 0))
                                task.wait(0.3)
                                prompt.RequiresLineOfSight = false
                                fireproximityprompt(prompt)
                                task.wait(0.5)
                            end
                        end
                    end
                end
            end

            collectPrompts(carryables)
            collectPrompts(myWonGarage)

            if foundItems == 0 then
                myWonGarage = nil
            end
            continue 
        end
        if autoBidEnabled then
            local debrisFolder = workspace:FindFirstChild("_Debris")
            if debrisFolder and debrisFolder:FindFirstChild("Garages") then
                if currentGarage then
                    local invBlocker = currentGarage:FindFirstChild("InvisibleBlocker")
                    if not invBlocker or invBlocker.CanCollide == false then
                        task.wait(2) 
                        myWonGarage = currentGarage 
                        currentGarage = nil
                    else
                        BidEvent:FireServer()
                        task.wait(0.4)
                    end
                    continue
                end

                local myCash = LocalPlayer:GetAttribute('MaxCash') or 0
                local availableGarages = {}

                for _, garage in pairs(debrisFolder.Garages:GetChildren()) do
                    local auctioneer = garage:FindFirstChild("Auctioneer")
                    local invBlocker = garage:FindFirstChild("InvisibleBlocker")

                    if auctioneer or (invBlocker and invBlocker.CanCollide == false) then continue end

                    if invBlocker and invBlocker.CanCollide == true then
                        local prompt = garage:FindFirstChildWhichIsA("ProximityPrompt", true)
                        
                        if prompt and prompt.Parent then
                            local requiredCash = 0
                            local entrySquare = garage:FindFirstChild("EntrySquare")
                            if entrySquare then
                                local promptPart = entrySquare:FindFirstChild("PromptPart")
                                if promptPart then
                                    local bg = promptPart:FindFirstChild("BillboardGui")
                                    if bg and bg:FindFirstChild("Container") and bg.Container:FindFirstChild("MinNetWorth") then
                                        local text = bg.Container.MinNetWorth.Text
                                        local numStr = string.gsub(text, "[^%d]", "")
                                        requiredCash = tonumber(numStr) or 0
                                    end
                                end
                            end

                            if myCash >= requiredCash then
                                table.insert(availableGarages, {
                                    GarageObj = garage,
                                    PromptObj = prompt,
                                    Price = requiredCash
                                })
                            end
                        end
                    end
                end

                if #availableGarages > 0 then
                    table.sort(availableGarages, function(a, b)
                        return a.Price > b.Price
                    end)

                    local target = availableGarages[1]
                    local targetGarage = target.GarageObj
                    local targetPrompt = target.PromptObj
                    
                    Teleport(targetPrompt.Parent.CFrame + Vector3.new(0, 2, 0))
                    
                    targetPrompt.RequiresLineOfSight = false
                    fireproximityprompt(targetPrompt)
                    task.wait(1.5)
                    
                    if targetGarage:FindFirstChild("Auctioneer") then
                        currentGarage = targetGarage
                        BidEvent:FireServer()
                    end
                end
            end
        end
    end
end)
