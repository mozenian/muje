-- // AUTO GOLD MINING SCRIPT \\ --
-- // Game: [🪙] Plants & Brainrots 🌻 \\ --

local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local Interact = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Events"):WaitForChild("StPattys"):WaitForChild("Interact")

-- // Clean Old UI
local uiTarget = CoreGui
local success = pcall(function() local _ = CoreGui.Name end)
if not success then uiTarget = LocalPlayer:WaitForChild("PlayerGui") end

if uiTarget:FindFirstChild("AutoGoldMiningHub") then
    uiTarget.AutoGoldMiningHub:Destroy()
end

-- // VARIABLES
local isAutoMining = false

local BrainrotRegistry = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Registries"):WaitForChild("BrainrotRegistry"))
local ItemSell = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ItemSell")
local BuyGear = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("BuyGear")
local ConfirmSell = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ConfirmSell")
local GearRegistry = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Registries"):WaitForChild("GearRegistry"))

-- // AUTO YES UNTUK POP-UP SELL GODLY
ConfirmSell.OnClientEvent:Connect(function(p1, p2, p3)
    if isAutoMining then
        -- Langsung kirim balasan YES ke server
        ConfirmSell:FireServer(p1, p2, p3, true)
    end
end)

-- Loop gaib untuk menutup UI Pop-up jika masih muncul
task.spawn(function()
    while task.wait(0.1) do
        if isAutoMining then
            pcall(function()
                for _, v in ipairs(LocalPlayer.PlayerGui:GetDescendants()) do
                    if v:IsA("TextLabel") and (string.match(v.Text, "Are you sure you want to sell") or string.match(v.Text, "Godly")) then
                        -- Cari tombol "Yes" di sekitarnya
                        local popUpFrame = v.Parent
                        if popUpFrame then
                            local yesBtn = popUpFrame:FindFirstChild("Yes", true) or popUpFrame:FindFirstChild("Confirm", true)
                            if yesBtn and yesBtn:IsA("GuiButton") then
                                if getconnections then
                                    for _, conn in ipairs(getconnections(yesBtn.MouseButton1Click)) do
                                        conn:Fire()
                                    end
                                end
                            end
                            
                            -- Sembunyikan secara paksa untuk jaga-jaga
                            if popUpFrame.Name == "PopUp" or (popUpFrame.Parent and popUpFrame.Parent.Name == "PopUp") then
                                if popUpFrame.Name == "PopUp" then
                                    popUpFrame.Visible = false
                                else
                                    popUpFrame.Parent.Visible = false
                                end
                            end
                        end
                    end
                end
            end)
        end
    end
end)

local function buyAllGears()
    -- Karena toko Joel menggunakan stok rotasi dan parameter spesifik, 
    -- metode paling ampuh adalah dengan "mengeklik" tombol Beli di UI secara otomatis.
    local mainGui = LocalPlayer.PlayerGui:FindFirstChild("Main")
    if not mainGui then return end
    
    -- Mencari semua frame item di dalam Shop yang sedang terbuka
    for _, frame in ipairs(mainGui:GetDescendants()) do
        if frame:IsA("Frame") and frame:FindFirstChild("Buttons") then
            local buttons = frame:FindFirstChild("Buttons")
            local buyFrame = buttons and buttons:FindFirstChild("Buy")
            local buyBtn = buyFrame and buyFrame:FindFirstChild("TextButton")
            
            if buyBtn then
                -- 1. Klik tombol UI menggunakan executor getconnections berulang kali
                if getconnections then
                    pcall(function()
                        -- Loop 5 kali untuk memastikan semua sisa stok (x3, x2, x1) ludes diborong!
                        for i = 1, 5 do
                            for _, conn in ipairs(getconnections(buyBtn.MouseButton1Click)) do
                                conn:Fire()
                            end
                            task.wait(0.05) -- Jeda super singkat agar tidak dianggap spam
                        end
                    end)
                end
                
                -- 2. Fallback: Tembak remote berulang kali
                pcall(function()
                    for i = 1, 5 do
                        BuyGear:FireServer(frame.Name, "Cash")
                        task.wait(0.05)
                    end
                end)
                
                task.wait(0.1) -- Jeda sebelum beralih ke item berikutnya
            end
        end
    end
end

local function autoSellTrashBrainrots()
    -- Menggunakan metode NPC Barry: Jual seluruh brainrot secara instan!
    -- Mutasi Gold sudah otomatis masuk pot duluan, jadi sisanya aman untuk dijual semua.
    pcall(function()
        ItemSell:FireServer()
    end)
end

-- // MAIN LOGIC
local function autoGoldMining()
    pcall(function()
        -- 1. Cek apakah progress sudah mencapai batas maksimal (misal: 50/50) untuk Reset
        local SurfaceGui = LocalPlayer.PlayerGui:FindFirstChild("Main") and LocalPlayer.PlayerGui.Main:FindFirstChild("StPattysNewSurfaceGui")
        if not SurfaceGui then
            local scriptedMap = workspace:FindFirstChild("ScriptedMap")
            local stPattys = scriptedMap and scriptedMap:FindFirstChild("StPattys")
            local surfaceModel = stPattys and stPattys:FindFirstChild("SurfaceModel")
            local surface = surfaceModel and surfaceModel:FindFirstChild("Surface")
            SurfaceGui = surface and surface:FindFirstChild("SurfaceGui")
        end
        
        if SurfaceGui then
            local main = SurfaceGui:FindFirstChild("Main")
            
            -- Cek utama: jika BodyReset visible, artinya event sudah bisa di-reset!
            local bodyReset = main and main:FindFirstChild("BodyReset")
            if bodyReset and bodyReset.Visible then
                Interact:FireServer("Reset")
                task.wait(1) -- Tunggu server mereset
                return
            end
            
            -- Cek fallback: melalui teks Progress_Amount
            local body = main and main:FindFirstChild("Body")
            local progress = body and body:FindFirstChild("Progress")
            local amountLabel = progress and progress:FindFirstChild("Progress_Amount") or (progress and progress:FindFirstChild("Amount"))
            
            if amountLabel and amountLabel:IsA("TextLabel") then
                local current, max = string.match(amountLabel.Text, "(%d+)%s*/%s*(%d+)")
                if current and max then
                    if tonumber(current) >= tonumber(max) then
                        Interact:FireServer("Reset")
                        task.wait(1)
                        return
                    end
                end
            end
        end

        -- 2. Otomatis Equip Brainrot/Plant [Gold] dari Backpack
        local char = LocalPlayer.Character
        local humanoid = char and char:FindFirstChildOfClass("Humanoid")
        
        if humanoid then
            local isEquipped = false
            local currentTool = char:FindFirstChildOfClass("Tool")
            
            -- Jika sedang memegang yang Gold, cek apakah itu Godly atau Telur
            if currentTool and string.match(currentTool.Name, "%[Gold%]") then
                local isEgg = string.match(currentTool.Name, "Egg")
                local baseName = currentTool:GetAttribute("Brainrot")
                local data = baseName and BrainrotRegistry[baseName]
                
                if not baseName or isEgg or (data and data.Rarity == "Godly") then
                    -- Kalau Plant (tidak ada baseName), Godly, atau Telur, unequip biar bisa cari yang lain
                    humanoid:UnequipTools()
                else
                    isEquipped = true
                end
            end
            
            -- Jika belum pegang yang valid, cari di Backpack dan equip
            if not isEquipped then
                for _, tool in ipairs(LocalPlayer.Backpack:GetChildren()) do
                    if tool:IsA("Tool") and string.match(tool.Name, "%[Gold%]") then
                        -- Abaikan jika itu Telur (Egg)
                        if string.match(tool.Name, "Egg") then
                            continue
                        end
                        
                        local baseName = tool:GetAttribute("Brainrot")
                        if not baseName then 
                            continue -- Skip Plant (tidak ada atribut Brainrot)
                        end
                        
                        local data = baseName and BrainrotRegistry[baseName]
                        if data and data.Rarity == "Godly" then
                            continue -- Skip yang Godly
                        end
                        
                        humanoid:EquipTool(tool)
                        task.wait(0.1) -- Jeda dikurangi dari 0.3 ke 0.1 agar lebih gesit
                        isEquipped = true
                        break
                    end
                end
            end
            
            -- 3. Jika sudah ter-equip, baru eksekusi Give ke Pot!
            if isEquipped then
                Interact:FireServer("RequestGive")
            end
        end
    end)
end

task.spawn(function()
    while task.wait(0.05) do -- Loop tiap 0.05 detik (sangat cepat)
        if isAutoMining then
            autoSellTrashBrainrots()
            autoGoldMining()
        end
    end
end)


-- // UI CREATION
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AutoGoldMiningHub"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = uiTarget

-- // LOGO MINIMIZE (Sama seperti script.txt)
local MinimizedLogo = Instance.new("ImageButton")
MinimizedLogo.Name = "MinimizedLogo"
MinimizedLogo.Size = UDim2.new(0, 60, 0, 60)
MinimizedLogo.Position = UDim2.new(0.5, 0, 0.5, -50)
MinimizedLogo.AnchorPoint = Vector2.new(0.5, 0.5)
MinimizedLogo.Image = "rbxassetid://104624206636533"
MinimizedLogo.BackgroundColor3 = Color3.fromRGB(21, 27, 38)
MinimizedLogo.BackgroundTransparency = 0
MinimizedLogo.BorderSizePixel = 0
MinimizedLogo.Visible = false
MinimizedLogo.ZIndex = 10005
MinimizedLogo.Parent = ScreenGui

local LogoCorner = Instance.new("UICorner")
LogoCorner.CornerRadius = UDim.new(0, 15)
LogoCorner.Parent = MinimizedLogo

local LogoStroke = Instance.new("UIStroke")
LogoStroke.Color = Color3.fromRGB(36, 47, 65)
LogoStroke.Thickness = 2
LogoStroke.Parent = MinimizedLogo

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 320, 0, 185)
MainFrame.Position = UDim2.new(0.5, 170, 0.5, -100)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 19, 26) -- Dark Blue/Black seperti script.txt
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 12)
UICorner.Parent = MainFrame

local UIStroke = Instance.new("UIStroke")
UIStroke.Color = Color3.fromRGB(36, 47, 65)
UIStroke.Thickness = 2
UIStroke.Parent = MainFrame

-- DropShadow
local DropShadow = Instance.new("ImageLabel")
DropShadow.Name = "DropShadow"
DropShadow.AnchorPoint = Vector2.new(0.5, 0.5)
DropShadow.Position = UDim2.new(0.5, 0, 0.5, 0)
DropShadow.Size = UDim2.new(1, 30, 1, 30)
DropShadow.BackgroundTransparency = 1
DropShadow.Image = "rbxassetid://6014261993"
DropShadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
DropShadow.ImageTransparency = 0.55
DropShadow.ScaleType = Enum.ScaleType.Slice
DropShadow.SliceCenter = Rect.new(49, 49, 450, 450)
DropShadow.ZIndex = -1
DropShadow.Parent = MainFrame

-- Title
local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, 0, 0, 40)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "Auto Gold Mining"
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 18
TitleLabel.Parent = MainFrame

local Divider = Instance.new("Frame")
Divider.Size = UDim2.new(1, -20, 0, 1)
Divider.Position = UDim2.new(0, 10, 0, 40)
Divider.BackgroundColor3 = Color3.fromRGB(36, 47, 65)
Divider.BorderSizePixel = 0
Divider.Parent = MainFrame

-- Instruction / Hint
local HintLabel = Instance.new("TextLabel")
HintLabel.Size = UDim2.new(1, -30, 0, 45)
HintLabel.Position = UDim2.new(0, 15, 0, 45)
HintLabel.BackgroundTransparency = 1
HintLabel.Text = "Otomatis equip & menyetor Brainrot/Plant [Gold] dari tas. Langsung reset saat menyentuh batas 50."
HintLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
HintLabel.Font = Enum.Font.Gotham
HintLabel.TextSize = 12
HintLabel.TextWrapped = true
HintLabel.TextXAlignment = Enum.TextXAlignment.Center
HintLabel.Parent = MainFrame

-- Toggle Button
local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Size = UDim2.new(1, -40, 0, 40)
ToggleBtn.Position = UDim2.new(0, 20, 0, 100)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(21, 27, 38)
ToggleBtn.Text = "OFF"
ToggleBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.TextSize = 15
ToggleBtn.AutoButtonColor = false
ToggleBtn.Parent = MainFrame
local ToggleCorner = Instance.new("UICorner")
ToggleCorner.CornerRadius = UDim.new(0, 8)
ToggleCorner.Parent = ToggleBtn
local ToggleStroke = Instance.new("UIStroke")
ToggleStroke.Color = Color3.fromRGB(36, 47, 65)
ToggleStroke.Thickness = 2
ToggleStroke.Parent = ToggleBtn

ToggleBtn.MouseButton1Click:Connect(function()
    isAutoMining = not isAutoMining
    if isAutoMining then
        ToggleBtn.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
        ToggleBtn.TextColor3 = Color3.fromRGB(20, 20, 20)
        ToggleBtn.Text = "ON"
        ToggleStroke.Color = Color3.fromRGB(39, 174, 96)
        
        -- Beli semua gear saat script dinyalakan
        task.spawn(buyAllGears)
    else
        ToggleBtn.BackgroundColor3 = Color3.fromRGB(21, 27, 38)
        ToggleBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
        ToggleBtn.Text = "OFF"
        ToggleStroke.Color = Color3.fromRGB(36, 47, 65)
    end
end)

-- Minimize Button (-)
local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(1, -40, 0, 25)
MinBtn.Position = UDim2.new(0, 20, 0, 150)
MinBtn.BackgroundColor3 = Color3.fromRGB(21, 27, 38)
MinBtn.Text = "MINIMIZE"
MinBtn.TextColor3 = Color3.fromRGB(150, 150, 150)
MinBtn.Font = Enum.Font.Gotham
MinBtn.TextSize = 12
MinBtn.AutoButtonColor = false
MinBtn.Parent = MainFrame
local MinCorner = Instance.new("UICorner")
MinCorner.CornerRadius = UDim.new(0, 6)
MinCorner.Parent = MinBtn

MinBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
    MinimizedLogo.Visible = true
end)

MinimizedLogo.MouseButton1Click:Connect(function()
    MinimizedLogo.Visible = false
    MainFrame.Visible = true
end)

-- Close Button
local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 30, 0, 30)
CloseBtn.Position = UDim2.new(1, -35, 0, 5)
CloseBtn.BackgroundTransparency = 1
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 18
CloseBtn.Parent = MainFrame
CloseBtn.MouseButton1Click:Connect(function()
    ScreenGui:Destroy()
end)

print("Auto Gold Mining Loaded!")

-- Admin Machine Predictor
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")

local AdminMachine = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("AdminMachine")
local SetNextEvent = AdminMachine:WaitForChild("SetNextEvent")

local uiTarget = CoreGui
local success = pcall(function() local _ = CoreGui.Name end)
if not success then uiTarget = Players.LocalPlayer:WaitForChild("PlayerGui") end

if uiTarget:FindFirstChild("AdminMachinePredictor") then
    uiTarget.AdminMachinePredictor:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AdminMachinePredictor"
ScreenGui.Parent = uiTarget

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 300, 0, 150)
MainFrame.Position = UDim2.new(0.5, 170, 0.5, 100)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 19, 26)
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 12)
UICorner.Parent = MainFrame

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 30)
Title.BackgroundTransparency = 1
Title.Text = "Admin Machine Predictor"
Title.TextColor3 = Color3.fromRGB(255, 215, 0)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 16
Title.Parent = MainFrame

local InfoText = Instance.new("TextLabel")
InfoText.Size = UDim2.new(1, -20, 1, -40)
InfoText.Position = UDim2.new(0, 10, 0, 30)
InfoText.BackgroundTransparency = 1
InfoText.Text = "Waiting for data..."
InfoText.TextColor3 = Color3.fromRGB(200, 200, 200)
InfoText.Font = Enum.Font.Gotham
InfoText.TextSize = 14
InfoText.TextWrapped = true
InfoText.TextYAlignment = Enum.TextYAlignment.Top
InfoText.Parent = MainFrame

local function updateInfo(data)
    if not data then return end
    
    local text = ""
    if data.WeatherEventData then
        text = text .. "Weather: " .. tostring(data.WeatherEventData.WeatherEventName) .. "\n"
    end
    if data.BrainrotSpawnEventData then
        text = text .. "Brainrot: " .. tostring(data.BrainrotSpawnEventData.BrainrotName) .. "\n"
    end
    if data.SeedStockEventData then
        text = text .. "Seed: " .. tostring(data.SeedStockEventData.SeedName) .. " (x" .. tostring(data.SeedStockEventData.Amount) .. ")\n"
    end
    if data.LuckEventData then
        text = text .. "Luck: +" .. tostring(data.LuckEventData.LuckIncrease) .. "\n"
    end
    
    if data.RevealTime then
        local timeRemaining = math.max(0, data.RevealTime - workspace:GetServerTimeNow())
        text = text .. "\nReveals in: " .. string.format("%.0fs", timeRemaining)
    end
    
    InfoText.Text = text
end

-- Try to find existing data in memory (GC)
task.spawn(function()
    if getgc then
        local found = false
        for _, v in ipairs(getgc(true)) do
            if type(v) == "table" and rawget(v, "WeatherEventData") and rawget(v, "BrainrotSpawnEventData") then
                updateInfo(v)
                found = true
                break
            end
        end
        if not found then
            InfoText.Text = "No active event data found in memory. Waiting for server update..."
        end
    end
end)

-- Listen to updates
SetNextEvent.OnClientEvent:Connect(function(data)
    updateInfo(data)
end)

print("Admin Machine Predictor loaded!")
