local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteEvent = ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("Packet"):WaitForChild("RemoteEvent")
local LocalPlayer = Players.LocalPlayer

local function performAntigravitySell()
    local Networking = require(ReplicatedStorage.SharedModules.Networking)
    pcall(function() Networking.NPCS.SellAll:Fire() end)
end

local function performAutoHarvest()
    local Plot = nil
    for _, plot in ipairs(workspace.Gardens:GetChildren()) do
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

-- Fungsi untuk membeli benih
local function buySeed(seedName)
    local bufferData = buffer.create(1 + 1 + #seedName)
    buffer.writeu8(bufferData, 0, 121) -- 'y'
    buffer.writeu8(bufferData, 1, #seedName)
    for i = 1, #seedName do
        buffer.writeu8(bufferData, 1 + i, string.byte(seedName, i))
    end
    RemoteEvent:FireServer(bufferData)
end

-- Fungsi BARU: Mengambil tool dari Backpack dan memegangnya (Equip)
local function equipTool(toolName)
    local character = LocalPlayer.Character
    if not character then return end
    
    -- Cek apakah sudah dipegang di tangan (Character)
    if character:FindFirstChild(toolName) then return end
    
    -- Cari di Backpack dan equip menggunakan Humanoid
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

local function runTutorialSteps()
    send("\006\000\005SeedsT\000\133\215\132C\197\000\018C\228Y\015\195")
    task.wait(2) 
    
    -- Beli Carrot
    buySeed("Carrot")
    task.wait(1.5) -- Beri waktu sedikit agar item masuk ke Backpack
    
    -- Pegang Carrot agar tutorial terdeteksi
    equipTool("Carrot")
    task.wait(1.5)
    
    send("\006\000\006GardenT\000\192\151\200C\006\129\018C\b\172\003\195")
    task.wait(2)
    
    local pingArgs = { 495, 1782960161.888541 }
    game:GetService("ReplicatedStorage"):WaitForChild("UserGenerated"):WaitForChild("Analytics"):WaitForChild("ClientKit"):WaitForChild("Ping"):FireServer(unpack(pingArgs))
    
    local plantArgs = { buffer.fromstring("\n\000t\213\212C\254Z\014C\153\241\r\195\006Carrot"), {Instance.new("Tool")} }
    RemoteEvent:FireServer(unpack(plantArgs))
    
    task.wait(15)
    performAutoHarvest()
    task.wait(2)
    
    send("\006\000\004SellT\000\242.\134C\006\001\018C\180\240\254\194")
    task.wait(2)
    performAntigravitySell()
end

local function applyFpsBoost()
    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local root = character:WaitForChild("HumanoidRootPart")
    local NpcSam = Workspace:FindFirstChild("Sam", true) or Workspace:FindFirstChild("Middle", true)
    
    if NpcSam then
        local targetCFrame = NpcSam:IsA("Model") and (NpcSam.PrimaryPart or NpcSam:FindFirstChild("HumanoidRootPart")) and (NpcSam.PrimaryPart or NpcSam:FindFirstChild("HumanoidRootPart")).CFrame or (NpcSam:IsA("BasePart") and NpcSam.CFrame)
        if targetCFrame then root.CFrame = targetCFrame + Vector3.new(0, 2, 3) end
    end

    -- Menghapus objek visual yang tidak perlu + memastikan SpawnPoint dihapus
    local objectsToRemove = {"MidLayer", "Baseplate", "Middle", "Grass", "Gardens", "SpawnPoint"}
    for _, name in pairs(objectsToRemove) do
        local obj = Workspace:FindFirstChild(name)
        if obj then
            if obj:IsA("BasePart") then obj.Transparency = 1; obj.CanCollide = false else obj:Destroy() end
        end
    end

    for _, effect in pairs(Lighting:GetChildren()) do
        if effect:IsA("PostEffect") or effect:IsA("BloomEffect") or effect:IsA("Sky") then effect:Destroy() end
    end

    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") then
            obj.Material = Enum.Material.SmoothPlastic
            if obj:FindFirstChildOfClass("Decal") then obj:FindFirstChildOfClass("Decal"):Destroy() end
        end
    end
    
    Lighting.GlobalShadows = false
    Workspace.CurrentCamera.FieldOfView = 30

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
end

if Workspace:GetAttribute("InTutorial") then
    runTutorialSteps()
end
applyFpsBoost()
