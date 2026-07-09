local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PacketEvent = ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("Packet"):WaitForChild("RemoteEvent")

-- ==========================================
-- PENGATURAN UTAMA (SUDAH DISESUAIKAN)
-- ==========================================
local targetItem = "Common Egg"
local spamDelay = 0.1  -- Jeda aman untuk server
local buyAmount = 2    -- Tembakan per siklus (jangan terlalu tinggi agar tidak kena cooldown)
local bufferPrefix = "H\001\020"
local bufferSuffix = "\000\000\000(P\132\172A" -- Ekor buffer

-- Membersihkan GUI Lama
local oldGui = game:GetService("CoreGui"):FindFirstChild("AutoDetectBuyGUI") 
    or Players.LocalPlayer:WaitForChild("PlayerGui"):FindFirstChild("AutoDetectBuyGUI")
if oldGui then oldGui:Destroy() end

-- Membuat GUI
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

-- Kolom Input Harga Maksimal (LANGSUNG SET KE 10M)
local priceBox = Instance.new("TextBox")
priceBox.Size = UDim2.new(1, -20, 0, 40)
priceBox.Position = UDim2.new(0, 10, 0, 35)
priceBox.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
priceBox.TextColor3 = Color3.fromRGB(200, 255, 200)
priceBox.PlaceholderText = "Max Harga (Misal: 50m, 500k)"
priceBox.Text = "30m" 
priceBox.TextScaled = true
priceBox.ClearTextOnFocus = false
priceBox.Parent = frame

-- Tombol Toggle (LANGSUNG MENYALA HIJAU SAAT DIEKSEKUSI)
local toggleButton = Instance.new("TextButton")
toggleButton.Size = UDim2.new(1, -20, 0, 50)
toggleButton.Position = UDim2.new(0, 10, 0, 85)
toggleButton.BackgroundColor3 = Color3.fromRGB(50, 255, 50)
toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleButton.TextScaled = true
toggleButton.Font = Enum.Font.SourceSansBold
toggleButton.Text = "MEMANTAU HARGA..."
toggleButton.Parent = frame

-- MENGAKTIFKAN AUTO BUY SECARA LANGSUNG
local autoBuy = true

-- 1. FUNGSI KONVERSI TEKS KE ANGKA
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

local function getTargetAuctionID(maxPriceLimit)
    local s, scrollingFrame = pcall(function()
        return Players.LocalPlayer.PlayerGui.Auction.Frame.ScrollingFrame
    end)
    
    if s and scrollingFrame then
        for _, child in pairs(scrollingFrame:GetChildren()) do
            if string.match(child.Name, "^Lot_auction:") then
                
                local foundID = nil
                local foundStatus = "KOSONG"
                
                pcall(function()
                    local mainFrame = child.Frame.Main_Frame
                    local itemNameLabel = mainFrame.ItemName
                    
                    if itemNameLabel.Text == targetItem then
                        local textNode = mainFrame.BuyButton:FindFirstChild("Text")
                        local priceText = textNode.TextLabel.Text
                        local itemPrice = textToNumber(priceText)
                        
                        if itemPrice <= maxPriceLimit then
                            foundID = string.gsub(child.Name, "Lot_", "")
                            foundStatus = "BISA_BELI"
                        else
                            foundStatus = "KEMAHALAN"
                        end
                    end
                end)
                
                if foundStatus ~= "KOSONG" then
                    return foundID, foundStatus
                end
            end
        end
    end
    return nil, "KOSONG"
end

-- 3. LOGIKA TOMBOL (Hanya untuk mematikan/menyalakan secara manual)
toggleButton.MouseButton1Click:Connect(function()
    autoBuy = not autoBuy
    if autoBuy then
        toggleButton.BackgroundColor3 = Color3.fromRGB(50, 255, 50)
        toggleButton.Text = "MEMANTAU HARGA..."
    else
        toggleButton.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
        toggleButton.Text = "AUTO BUY BERHENTI"
    end
end)

-- 4. LOOP UTAMA (BERJALAN OTOMATIS DI LATAR BELAKANG)
task.spawn(function()
    while true do
        if autoBuy then
            local maxPrice = textToNumber(priceBox.Text)
            
            if maxPrice > 0 then
                local currentAuctionID, status = getTargetAuctionID(maxPrice)
                
                if currentAuctionID and status == "BISA_BELI" then
                    local finalBufferString = bufferPrefix .. currentAuctionID .. bufferSuffix
                    
                    pcall(function()
                        local args = { buffer.fromstring(finalBufferString) }
                        for i = 1, buyAmount do
                            PacketEvent:FireServer(unpack(args))
                        end
                    end)
                    toggleButton.Text = "MEMBELI: " .. targetItem
                    
                elseif status == "KEMAHALAN" then
                    toggleButton.Text = "MENOLAK (HARGA MAHAL)"
                else
                    toggleButton.Text = "MENUNGGU " .. string.upper(targetItem) .. "..."
                end
            else
                toggleButton.Text = "⚠️ HARGA TIDAK VALID ⚠️"
            end
        end
        task.wait(spamDelay)
    end
end)
