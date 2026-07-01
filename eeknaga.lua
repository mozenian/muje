local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:FindFirstChild("Humanoid")

-- ==========================================
-- [ KONFIGURASI OTOMASI & SAFE-SELL ]
-- ==========================================
local Config = {
    EnableAutoSell = true,      -- Otomatis jual pet di tas
    EnableAutoUnequip = true,   -- Otomatis tarik pet biasa dari taman
    
    -- DAFTAR PET BIASA YANG BOLEH DITARIK & DIJUAL (Huruf kecil)
    PetsToProcess = {
        "bear", "frog", 
        "bunny", "owl", "deer", "turtle", "robin"
    },

    -- FILTER PENYELAMAT MUTLAK
    KeepRainbow = true,
    KeepGold = true,
    KeepBig = true,
    KeepMega = true,
}

-- ==========================================
-- 1. MEMBUAT GUI (DIPERBAIKI)
-- ==========================================
local player = game:GetService("Players").LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

if playerGui:FindFirstChild("AutoEggGUI") then
    playerGui.AutoEggGUI:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AutoEggGUI"
screenGui.IgnoreGuiInset = true -- Menambahkan ini
screenGui.Parent = playerGui 

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 330, 0, 340)
mainFrame.Position = UDim2.new(0, 20, 0, 20) -- Geser ke pojok agar terlihat
mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
mainFrame.BorderSizePixel = 2
mainFrame.Active = true
-- Hapus .Draggable jika masih blank
mainFrame.Parent = screenGui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 35)
title.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
title.TextColor3 = Color3.fromRGB(255, 215, 0)
title.Text = "Find Egg and Sell"
title.Font = Enum.Font.Code -- Gunakan ini, ini pasti valid
-- Jangan gunakan FontWeight untuk font ini
title.TextSize = 14
-- Hapus baris title.FontWeight karena tidak valid
title.Parent = mainFrame

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -20, 0, 30)
statusLabel.Position = UDim2.new(0, 10, 0, 45)
statusLabel.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
statusLabel.Text = "nunggu naga nya ee"
statusLabel.Font = Enum.Font.Code
statusLabel.TextSize = 13
statusLabel.Parent = mainFrame

local manualButton = Instance.new("TextButton")
manualButton.Size = UDim2.new(1, -20, 0, 30)
manualButton.Position = UDim2.new(0, 10, 0, 80)
manualButton.BackgroundColor3 = Color3.fromRGB(200, 100, 50)
manualButton.TextColor3 = Color3.fromRGB(255, 255, 255)
manualButton.Text = "🔄 Clearing backpack"
manualButton.Font = Enum.Font.Code
manualButton.TextSize = 13
manualButton.Parent = mainFrame

local logScroll = Instance.new("ScrollingFrame")
logScroll.Size = UDim2.new(1, -20, 1, -125)
logScroll.Position = UDim2.new(0, 10, 0, 115)
logScroll.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
logScroll.ScrollBarThickness = 4
logScroll.Parent = mainFrame

local uiListLayout = Instance.new("UIListLayout")
uiListLayout.Parent = logScroll

local function addLog(message)
    local logItem = Instance.new("TextLabel")
    logItem.Size = UDim2.new(1, 0, 0, 20)
    logItem.BackgroundTransparency = 1
    logItem.TextColor3 = Color3.fromRGB(200, 200, 200)
    logItem.Text = "[" .. os.date("%X") .. "] " .. message
    logItem.TextXAlignment = Enum.TextXAlignment.Left
    logItem.Font = Enum.Font.Code
    logItem.TextSize = 12
    logItem.Parent = logScroll
    logScroll.CanvasSize = UDim2.new(0, 0, 0, uiListLayout.AbsoluteContentSize.Y)
end

-- ==========================================
-- 2. LOGIKA PENYELAMAT & NETWORKING
-- ==========================================
local function isPetValuable(pet)
    local petName = string.lower(pet.Name)
    local petType = pet:GetAttribute("PetType") 
    
    -- Cek Atribut Mutasi
    if petType then
        local typeStr = string.lower(tostring(petType))
        if Config.KeepRainbow and string.find(typeStr, "rainbow") then return true end
        if Config.KeepGold and (string.find(typeStr, "gold") or string.find(typeStr, "shiny")) then return true end
        if Config.KeepBig and (string.find(typeStr, "big") or string.find(typeStr, "huge")) then return true end
        if Config.KeepMega and string.find(typeStr, "mega") then return true end
    end

    -- Cek Nama
    if Config.KeepBig and (string.find(petName, "big") or string.find(petName, "huge")) then return true end
    if Config.KeepMega and string.find(petName, "mega") then return true end
    
    return false 
end

-- Fungsi Mengirim Paket ke Server
local function sendPacket(header, uuid)
    local packetString = header .. uuid
    local args = { buffer.fromstring(packetString) }
    pcall(function()
        game:GetService("ReplicatedStorage"):WaitForChild("SharedModules"):WaitForChild("Packet"):WaitForChild("RemoteEvent"):FireServer(unpack(args))
    end)
end

-- ==========================================
-- 3. PROSES TAMAN (UNEQUIP) & TAS (SELL)
-- ==========================================
local function processGardenAndInventory(isManual)
    -- TAHAP 1: TARIK DARI TAMAN (UNEQUIP)
    if Config.EnableAutoUnequip or isManual then
        local unequippedCount = 0
        -- Memindai Workspace untuk mencari pet dengan PetId
        for _, obj in pairs(workspace:GetDescendants()) do
            local petUUID = obj:GetAttribute("PetId")
            
            if petUUID and type(petUUID) == "string" then
                local petName = string.lower(obj.Name)
                local isTarget = false
                
                for _, target in pairs(Config.PetsToProcess) do
                    if string.find(petName, target) then isTarget = true; break end
                end

                -- Jika masuk target dan BUKAN pet berharga
                if isTarget and not isPetValuable(obj) then
                    unequippedCount = unequippedCount + 1
                    sendPacket("J\000$", petUUID) -- Header Tarik (Unequip)
                    if isManual then addLog("🔄 Menarik dari taman: " .. obj.Name) end
                    task.wait(0.1)
                end
            end
        end
        if isManual and unequippedCount > 0 then addLog("✅ Berhasil menarik " .. unequippedCount .. " pet.") end
    end

    -- TAHAP 2: JUAL DARI TAS (SELL)
    if Config.EnableAutoSell or isManual then
        local backpack = player:FindFirstChild("Backpack")
        if backpack then
            local soldCount = 0
            for _, pet in pairs(backpack:GetChildren()) do
                if pet:IsA("Tool") then
                    local petName = string.lower(pet.Name)
                    local isTarget = false
                    
                    for _, target in pairs(Config.PetsToProcess) do
                        if string.find(petName, target) then isTarget = true; break end
                    end

                    if isTarget and not isPetValuable(pet) then
                        local petUUID = pet:GetAttribute("PetId")
                        if petUUID then
                            soldCount = soldCount + 1
                            sendPacket("\173\000\021$", petUUID) -- Header Jual (Sell)
                            addLog("💰 Terjual: " .. pet.Name)
                            task.wait(3)
                        end
                    end
                end
            end
            if isManual and soldCount > 0 then addLog("✅ Terjual " .. soldCount .. " pet dari tas.") end
        end
    end
end

manualButton.MouseButton1Click:Connect(function()
    addLog("🔍 Memulai pembersihan...")
    processGardenAndInventory(true)
end)

-- ==========================================
-- 4. LOGIKA UTAMA (HATCH & LOOP)
-- ==========================================
local isFarming = false
local lastEgg = nil
local tickCounter = 0

local function findEgg()
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj.Name and string.find(string.lower(obj.Name), "egg") then
            if not obj:FindFirstChild("Humanoid") and not (obj.Parent and obj.Parent:FindFirstChild("Humanoid")) then
                if obj:IsA("Model") then
                    local targetPart = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
                    if targetPart then return targetPart, obj end
                elseif obj:IsA("BasePart") then
                    return obj, obj
                end
            end
        end
    end
    return nil, nil
end

local function interactWithEgg(eggModel)
    local interacted = false
    local prompt = eggModel:FindFirstChildWhichIsA("ProximityPrompt", true)
    if prompt then fireproximityprompt(prompt, 1); interacted = true end
    
    local clickDetector = eggModel:FindFirstChildWhichIsA("ClickDetector", true)
    if clickDetector then fireclickdetector(clickDetector); interacted = true end
    
    return interacted
end

task.spawn(function()
    addLog("🚀 Sistem Aktif. Mengamankan taman...")
    while task.wait(0.5) do 
        tickCounter = tickCounter + 1
        character = player.Character or player.CharacterAdded:Wait()
        humanoid = character:FindFirstChild("Humanoid")
        local rootPart = character:FindFirstChild("HumanoidRootPart")
        
        if not humanoid or not rootPart then continue end

        -- Jalankan Auto-Tarik & Auto-Jual setiap 2.5 detik (agar tidak lag)
        if tickCounter % 5 == 0 then
            pcall(function() processGardenAndInventory(false) end)
        end

        local eggPart, eggModel = findEgg()
        
        if eggPart then
            if not isFarming or lastEgg ~= eggModel then
                isFarming = true
                lastEgg = eggModel
                statusLabel.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
                statusLabel.Text = "Status: Target " .. eggModel.Name .. "!"
            end
            
            local distance = (rootPart.Position - eggPart.Position).Magnitude
            if distance > 6 then
                humanoid:MoveTo(eggPart.Position)
            else
                statusLabel.BackgroundColor3 = Color3.fromRGB(200, 200, 50)
                statusLabel.Text = "Status: Hatching " .. eggModel.Name .. "..."
                if interactWithEgg(eggModel) then
                    task.wait(1.5) 
                end
            end
        else
            if isFarming then
                isFarming = false
                lastEgg = nil
                statusLabel.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
                statusLabel.Text = "Status: Menunggu Egg..."
            end
        end
    end
end)
