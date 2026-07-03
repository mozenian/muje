local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteEvent = ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("Packet"):WaitForChild("RemoteEvent")
local LocalPlayer = Players.LocalPlayer

-- ==========================================
-- FUNGSI UTAMA (FARM & NETWORK)
-- ==========================================

local function performAntigravitySell()
    local Networking = require(ReplicatedStorage.SharedModules.Networking)
    pcall(function() Networking.NPCS.SellAll:Fire() end)
end

local function performAutoHarvest()
    local Plot = nil
    for _, plot in ipairs(Workspace.Gardens:GetChildren()) do
        if plot:GetAttribute("Owner") == LocalPlayer.Name or plot:GetAttribute("OwnerUserId") == LocalPlayer.UserId then
            Plot = plot
            break
        end
    end
    if Plot and Plot:FindFirstChild("Plants") then
        for _, plant in ipairs(Plot.Plants:GetChildren()) do
            local prompt = plant:FindFirstChildWhichIsA("ProximityPrompt", true) 
            if prompt then
                fireproximityprompt(prompt)
                task.wait(0.2)
            end
        end
    end
end

local function send(data)
    RemoteEvent:FireServer(buffer.fromstring(data))
end

local function buySeed(seedName)
    local bufferData = buffer.create(1 + 1 + #seedName)
    buffer.writeu8(bufferData, 0, 121) -- 'y'
    buffer.writeu8(bufferData, 1, #seedName)
    for i = 1, #seedName do
        buffer.writeu8(bufferData, 1 + i, string.byte(seedName, i))
    end
    RemoteEvent:FireServer(bufferData)
end

local function equipTool(toolName)
    local character = LocalPlayer.Character
    if not character then return end
    if character:FindFirstChild(toolName) then return end
    
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if backpack then
        local tool = backpack:FindFirstChild(toolName)
        if tool and tool:IsA("Tool") then
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                humanoid:EquipTool(tool)
            end
        end
    end
end

-- ==========================================
-- TUTORIAL SEQUENCE
-- ==========================================

local function runTutorialSteps()
    send("\006\000\005SeedsT\000\133\215\132C\197\000\018C\228Y\015\195")
    task.wait(2) 
    
    buySeed("Carrot")
    task.wait(1.5) 
    
    equipTool("Carrot")
    task.wait(1.5)
    
    -- \b diganti menjadi \8 agar Potassium tidak error
    send("\006\000\006GardenT\000\192\151\200C\006\129\018C\8\172\003\195")
    task.wait(2)
    
    local pingArgs = { 495, 1782960161.888541 }
    game:GetService("ReplicatedStorage"):WaitForChild("UserGenerated"):WaitForChild("Analytics"):WaitForChild("ClientKit"):WaitForChild("Ping"):FireServer(unpack(pingArgs))
    
    -- \n diganti menjadi \10 dan \r diganti menjadi \13
    local plantArgs = { buffer.fromstring("\10\000t\213\212C\254Z\014C\153\241\13\195\006Carrot"), {Instance.new("Tool")} }
    RemoteEvent:FireServer(unpack(plantArgs))
    
    task.wait(15)
    performAutoHarvest()
    task.wait(2)
    
    send("\006\000\004SellT\000\242.\134C\006\001\018C\180\240\254\194")
    task.wait(2)
    performAntigravitySell()
end

-- ==========================================
-- OPTIMASI ANTI-MEMORY LEAK (POTATO MODE)
-- ==========================================

local function applyMemorySafePotatoMode()
    -- 1. Turunkan Kualitas Grafis Bawaan
    pcall(function()
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
    end)

    -- 2. Posisi Karakter
    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local root = character:WaitForChild("HumanoidRootPart")
    local NpcSam = Workspace:FindFirstChild("Sam", true) or Workspace:FindFirstChild("Middle", true)
    
    if NpcSam then
        local targetCFrame = NpcSam:IsA("Model") and (NpcSam.PrimaryPart or NpcSam:FindFirstChild("HumanoidRootPart")) and (NpcSam.PrimaryPart or NpcSam:FindFirstChild("HumanoidRootPart")).CFrame or (NpcSam:IsA("BasePart") and NpcSam.CFrame)
        if targetCFrame then root.CFrame = targetCFrame + Vector3.new(0, 2, 3) end
    end

    -- 3. Sembunyikan Objek Fisik (TIDAK MENGGUNAKAN DESTROY AGAR RAM AMAN)
    local objectsToHide = {"MidLayer", "Baseplate", "Middle", "Grass", "Gardens", "SpawnPoint"}
    for _, name in pairs(objectsToHide) do
        local obj = Workspace:FindFirstChild(name)
        if obj then
            for _, desc in pairs(obj:GetDescendants()) do
                if desc:IsA("BasePart") then
                    desc.Transparency = 1
                    desc.CanCollide = false
                end
            end
            if obj:IsA("BasePart") then
                obj.Transparency = 1
                obj.CanCollide = false
            end
        end
    end

    -- 4. Matikan Lighting & Cuaca
    Lighting.GlobalShadows = false
    Lighting.FogEnd = 9e9
    Lighting.Brightness = 0
    Lighting.Ambient = Color3.fromRGB(150, 150, 150)
    Lighting.OutdoorAmbient = Color3.fromRGB(150, 150, 150)

    for _, effect in pairs(Lighting:GetChildren()) do
        if effect:IsA("PostEffect") or effect:IsA("Sky") or effect:IsA("Atmosphere") or effect:IsA("Clouds") then
            effect:Destroy()
        end
    end

    -- 5. Ubah semua part menjadi abu-abu polos & matikan efek partikel
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") then
            obj.Material = Enum.Material.SmoothPlastic
            obj.CastShadow = false
            obj.Reflectance = 0
            obj.Color = Color3.fromRGB(150, 150, 150)
            
        elseif obj:IsA("Decal") or obj:IsA("Texture") then
            obj.Transparency = 1
            
        elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then
            obj.Enabled = false
        end
    end

    -- 6. Optimasi Terrain
    local Terrain = Workspace:FindFirstChildOfClass("Terrain")
    if Terrain then
        Terrain.WaterWaveSize = 0
        Terrain.WaterWaveSpeed = 0
        Terrain.WaterReflectance = 0
        Terrain.WaterTransparency = 1
        Terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(150, 150, 150))
    end
    
    Workspace.CurrentCamera.FieldOfView = 30

    -- 7. Batasi FPS untuk AFK
    pcall(function()
        if setfpscap then setfpscap(15) end
    end)
end

-- ==========================================
-- EKSEKUSI
-- ==========================================

if Workspace:GetAttribute("InTutorial") then
    runTutorialSteps()
end

applyMemorySafePotatoMode()

local SEEDS_TO_BUY = {"Carrot"}
task.spawn(function()
    while true do
        for _, seedName in pairs(SEEDS_TO_BUY) do
            for i = 1, 10 do 
                pcall(function() buySeed(seedName) end)
                task.wait(0.2) 
            end
        end
        
        task.wait(120)
    end
end)
