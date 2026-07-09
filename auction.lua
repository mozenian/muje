local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local PacketEvent = ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("Packet"):WaitForChild("RemoteEvent")

local targetItem = "Common Egg"
local spamDelay = 0.1
local buyAmount = 7
local bufferPrefix = "H\001\020"
local bufferSuffix = "\000\000\000(P\132\172A"

-- Check and remove old GUI if it exists
local oldGui = game:GetService("CoreGui"):FindFirstChild("AutoDetectBuyGUI") 
    or Players.LocalPlayer:WaitForChild("PlayerGui"):FindFirstChild("AutoDetectBuyGUI")
if oldGui then oldGui:Destroy() end

-- Create New GUI
local gui = Instance.new("ScreenGui")
gui.Name = "AutoDetectBuyGUI"
local success, result = pcall(function() return game:GetService("CoreGui") end)
gui.Parent = success and result or Players.LocalPlayer:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 300, 0, 150)
frame.Position = UDim2.new(0.5, -150, 0.1, 0)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
frame.BorderSizePixel = 2
frame.BorderColor3 = Color3.fromRGB(100, 100, 100)
frame.Active = true
frame.Draggable = true
frame.Parent = gui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 25)
title.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Text = " Smart Auto Buy (" .. targetItem .. ")"
title.Font = Enum.Font.SourceSansBold
title.TextSize = 16
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

local priceBox = Instance.new("TextBox")
priceBox.Size = UDim2.new(1, -20, 0, 40)
priceBox.Position = UDim2.new(0, 10, 0, 35)
priceBox.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
priceBox.TextColor3 = Color3.fromRGB(200, 255, 200)
priceBox.PlaceholderText = "Max Price (e.g., 50m, 500k)"
priceBox.Text = "70m" 
priceBox.TextScaled = true
priceBox.ClearTextOnFocus = false
priceBox.Parent = frame

local toggleButton = Instance.new("TextButton")
toggleButton.Size = UDim2.new(1, -20, 0, 50)
toggleButton.Position = UDim2.new(0, 10, 0, 85)
toggleButton.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
toggleButton.TextColor3 = Color3.fromRGB(0, 0, 0)
toggleButton.TextScaled = true
toggleButton.Font = Enum.Font.SourceSansBold
toggleButton.Text = "WAIT"
toggleButton.Parent = frame

local autoBuy = false

-- Function to convert text to number (e.g., 1k -> 1000)
local function textToNumber(text)
    if not text then return 0 end
    text = string.lower(tostring(text))
    text = string.gsub(text, "[^%d%.kmb]", "")
    
    local multiplier = 1
    if string.find(text, "k") then
        multiplier = 1000
        text = string.gsub(text, "k", "")
    elseif string.find(text, "m") then
        multiplier = 1000000
        text = string.gsub(text, "m", "")
    elseif string.find(text, "b") then
        multiplier = 1000000000
        text = string.gsub(text, "b", "")
    end
    
    local finalNumber = tonumber(text)
    if finalNumber then
        return finalNumber * multiplier
    end
    return 0
end

-- Function to search for the target item in the auction GUI
local function getTargetAuctionID(maxPriceLimit)
    local s, scrollingFrame = pcall(function()
        return Players.LocalPlayer.PlayerGui.Auction.Frame.ScrollingFrame
    end)
    
    if s and scrollingFrame then
        for _, child in pairs(scrollingFrame:GetChildren()) do
            if string.match(child.Name, "^Lot_auction:") then
                local foundID = nil
                local foundStatus = "EMPTY"
                
                pcall(function()
                    local mainFrame = child.Frame.Main_Frame
                    local itemNameLabel = mainFrame:FindFirstChild("ItemName")
                    
                    if itemNameLabel and itemNameLabel.Text == targetItem then
                        
                        local stockText = mainFrame:FindFirstChild("Stock_Text")
                        if stockText then
                            local sText = string.lower(stockText.Text)
                            if string.find(sText, "sold") or string.find(sText, "out") then
                                foundStatus = "SOLD_OUT"
                                return 
                            end
                        end

                        local buyButton = mainFrame:FindFirstChild("BuyButton")
                        if buyButton then
                            local textNode = buyButton:FindFirstChild("Text")
                            if textNode and textNode:FindFirstChild("TextLabel") then
                                local priceText = textNode.TextLabel.Text
                                local itemPrice = textToNumber(priceText)
                                
                                if itemPrice <= maxPriceLimit then
                                    foundID = string.gsub(child.Name, "Lot_", "")
                                    foundStatus = "BUYING"
                                else
                                    foundStatus = "EXPENSIVE"
                                end
                            end
                        end
                    end
                end)
                
                if foundStatus ~= "EMPTY" then
                    return foundID, foundStatus
                end
            end
        end
    end
    return nil, "EMPTY"
end

-- Toggle Button Logic
toggleButton.MouseButton1Click:Connect(function()
    autoBuy = not autoBuy
    if autoBuy then
        toggleButton.BackgroundColor3 = Color3.fromRGB(50, 255, 50)
        toggleButton.Text = "WAITING"
    else
        toggleButton.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
        toggleButton.Text = "STOP BUY"
    end
end)

-- Function to teleport and interact with NPC
local function goToAndOpenAuction()
    local char = Players.LocalPlayer.Character or Players.LocalPlayer.CharacterAdded:Wait()
    local hrp = char:WaitForChild("HumanoidRootPart")
    
    local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
    local auctionButton = playerGui:WaitForChild("TeleportButtons")
                                    :WaitForChild("TeleportButtons")
                                    :WaitForChild("Auction")

    toggleButton.Text = "TELEPORTING VIA UI"
    
    if auctionButton then
        pcall(function()
            firesignal(auctionButton.MouseButton1Click)
            firesignal(auctionButton.Activated)
        end)
        
        task.wait(2) 
    else
        warn("Auction Teleport button not found in PlayerGui!")
        toggleButton.Text = "UI BUTTON NOT FOUND"
        task.wait(2)
    end

    toggleButton.Text = "INTERACTING WITH NPC..."
    
    local closestPrompt = nil
    local shortestDistance = 15 

    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") then
            local part = obj.Parent
            if part and part:IsA("BasePart") then
                local distance = (part.Position - hrp.Position).Magnitude
                if distance < shortestDistance then
                    shortestDistance = distance
                    closestPrompt = obj
                end
            end
        end
    end

    if closestPrompt then
        fireproximityprompt(closestPrompt)
        toggleButton.Text = "NPC DIALOG"
        
        task.wait(2.5) 
    else
        warn("Interact prompt not found near player after teleporting!")
        toggleButton.Text = "NPC NOT FOUND"
        task.wait(2)
    end

    autoBuy = true
    toggleButton.BackgroundColor3 = Color3.fromRGB(50, 255, 50)
    toggleButton.Text = "WAIT BUY"
end

-- Main Loop
task.spawn(function()
    goToAndOpenAuction()

    while true do
        if autoBuy then
            local maxPrice = textToNumber(priceBox.Text)
            
            if maxPrice > 0 then
                local currentAuctionID, status = getTargetAuctionID(maxPrice)
                
                if status == "SOLD_OUT" then
                    toggleButton.BackgroundColor3 = Color3.fromRGB(255, 150, 0)
                    toggleButton.Text = "RESTOCK"
                    
                elseif currentAuctionID and status == "BUYING" then
                    toggleButton.BackgroundColor3 = Color3.fromRGB(50, 255, 50)
                    
                    local finalBufferString = bufferPrefix .. currentAuctionID .. bufferSuffix
                    
                    pcall(function()
                        local args = { buffer.fromstring(finalBufferString) }
                        for i = 1, buyAmount do
                            PacketEvent:FireServer(unpack(args))
                        end
                    end)
                    toggleButton.Text = "BUYING: " .. targetItem
                    
                elseif status == "EXPENSIVE" then
                    toggleButton.BackgroundColor3 = Color3.fromRGB(200, 200, 50)
                    toggleButton.Text = "EXPENSIVE"
                    
                else
                    toggleButton.BackgroundColor3 = Color3.fromRGB(50, 255, 50)
                    toggleButton.Text = "WAITING " .. string.upper(targetItem) .. "..."
                end
            else
                toggleButton.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
                toggleButton.Text = "⚠️ INVALID ⚠️"
            end
        end
        task.wait(spamDelay)
    end
end)
