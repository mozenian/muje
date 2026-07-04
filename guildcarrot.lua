local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser = game:GetService("VirtualUser")
local RemoteEvent = ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("Packet"):WaitForChild("RemoteEvent")
local LocalPlayer = Players.LocalPlayer

-- Fungsi Anti-AFK
local function setupAntiAFK()
    print("[+] Anti-AFK diaktifkan.")
    LocalPlayer.Idled:Connect(function()
        VirtualUser:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
        task.wait(1)
        VirtualUser:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
    end)
    
    -- Loop pergerakan kecil setiap 5 menit agar tidak terbaca diam
    task.spawn(function()
        while true do
            task.wait(300)
            local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if root then
                root.CFrame = root.CFrame + Vector3.new(0, 0.1, 0)
                task.wait(0.1)
                root.CFrame = root.CFrame - Vector3.new(0, 0.1, 0)
            end
        end
    end)
end

local function performAntigravitySell()
    local Networking = require(ReplicatedStorage.SharedModules.Networking)
    pcall(function() Networking.NPCS.SellAll:Fire() end)
end

local function performAutoHarvest()
    local gardensFolder = Workspace:FindFirstChild("Gardens")
    if not gardensFolder then return end

    local Plot = nil
    for _, plot in ipairs(gardensFolder:GetChildren()) do
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
    if seedName == "Carrot" then
        local args = { buffer.fromstring("y\000\006Carrot") }
        RemoteEvent:FireServer(unpack(args))
    else
        local payload = "y\000" .. string.char(#seedName) .. seedName
        local args = { buffer.fromstring(payload) }
        RemoteEvent:FireServer(unpack(args))
    end
end

local function buyGear(gearName)
    if gearName == "" then return end
    local payload = "}\000" .. string.char(#gearName) .. gearName
    local args = { buffer.fromstring(payload) }
    RemoteEvent:FireServer(unpack(args))
end

local function equipTool(toolName)
    local character = LocalPlayer.Character
    if not character then return end
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if backpack then
        local tool = backpack:FindFirstChild(toolName)
        if tool and tool:IsA("Tool") then
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if humanoid then humanoid:EquipTool(tool) end
        end
    end
end

local function interactWithNPC(npcName)
    local npc = Workspace:FindFirstChild(npcName, true)
    if npc then
        local prompt = npc:FindFirstChildWhichIsA("ProximityPrompt", true)
        if prompt then
            local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
            local root = character:WaitForChild("HumanoidRootPart")
            local targetPart = npc:IsA("Model") and (npc.PrimaryPart or npc:FindFirstChild("HumanoidRootPart")) or (npc:IsA("BasePart") and npc)
            if targetPart then
                root.CFrame = targetPart.CFrame + Vector3.new(0, 0, 3)
                task.wait(0.5)
                fireproximityprompt(prompt)
                task.wait(1) 
            end
        end
    end
end

local function runTutorialSteps()
    interactWithNPC("Sam")
    send("\006\000\005SeedsT\000\133\215\132C\197\000\018C\228Y\015\195")
    task.wait(2) 
    buySeed("Carrot")
    task.wait(1.5)
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

    local objectsToDestroy = {"MidLayer", "Baseplate", "Middle", "Grass", "Gardens", "SpawnPoint"}
    for _, name in pairs(objectsToDestroy) do
        local obj = Workspace:FindFirstChild(name)
        if obj then obj:Destroy() end
    end

    for _, effect in pairs(Lighting:GetChildren()) do
        if effect:IsA("PostEffect") or effect:IsA("BloomEffect") or effect:IsA("Sky") then effect:Destroy() end
    end

    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") then
            obj.Material = Enum.Material.SmoothPlastic
            local decal = obj:FindFirstChildOfClass("Decal")
            if decal then decal:Destroy() end
        end
    end
    Lighting.GlobalShadows = false
    Workspace.CurrentCamera.FieldOfView = 30
end

local function startAutoBuy()
    local SEEDS_TO_BUY = {"Carrot"}
    local GEARS_TO_BUY = {}
    task.spawn(function()
        while true do
            for _, seedName in pairs(SEEDS_TO_BUY) do
                for i = 1, 10 do 
                    pcall(function() buySeed(seedName) end)
                    task.wait(0.2) 
                end
            end
            for _, gearName in pairs(GEARS_TO_BUY) do
                for i = 1, 10 do 
                    pcall(function() buyGear(gearName) end)
                    task.wait(0.2) 
                end
            end
            task.wait(10)
        end
    end)
end

-- --- EKSEKUSI ---
setupAntiAFK()

if Workspace:GetAttribute("InTutorial") then
    runTutorialSteps()
end
applyFpsBoost()
startAutoBuy()
