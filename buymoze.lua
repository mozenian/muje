local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteEvent = ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("Packet"):WaitForChild("RemoteEvent")
local LocalPlayer = Players.LocalPlayer
local Networking = require(ReplicatedStorage.SharedModules.Networking)

-- 1. BYPASS TUTORIAL
local function completeTutorialInstantly()
    print("[1/6] Bypass tutorial...")
    RemoteEvent:FireServer(unpack({buffer.fromstring("r\000\028\005\001\v\rShovel:Shovel\005\002\v\vBuild:Build\000")}))
    task.wait(0.2)
    RemoteEvent:FireServer(unpack({buffer.fromstring("9\001")}))
    task.wait(0.2)
    RemoteEvent:FireServer(unpack({buffer.fromstring("\174\000\029")}))
end

-- 2. TELEPORT KE STEVEN
local function teleportToSteven()
    print("[2/6] Teleport ke Steven...")
    local steven = Workspace:FindFirstChild("Steven", true)
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    
    if steven and root then
        local target = (steven:IsA("Model") and (steven.PrimaryPart or steven:FindFirstChild("HumanoidRootPart"))) or (steven:IsA("BasePart") and steven)
        if target then
            root.CFrame = target.CFrame + Vector3.new(0, 2, 3)
        end
    end
end

-- 3. AUTO CLAIM MAIL
local function claimMail()
    print("[3/6] Memeriksa inbox...")
    local ok, inbox = pcall(function() return Networking.Mailbox.OpenInbox:Fire() end)
    if ok and typeof(inbox) == "table" then
        for id in pairs(inbox) do
            pcall(function() Networking.Mailbox.Claim:Fire(id) end)
            task.wait(0.3)
        end
    end
end

-- 4. AUTO DAILY DEAL (STEVEN)
local function checkAndDealSteven()
    print("[4/6] Memeriksa Daily Deal...")
    local fruitCount = 0
    local function countFruits(container)
        for _, item in pairs(container:GetChildren()) do
            if item:IsA("Tool") and not (item.Name:find("Pot") or item.Name:find("Can") or item.Name:find("Trowel") or item.Name:find("Bag")) then
                fruitCount = fruitCount + 1
            end
        end
    end
    if LocalPlayer:FindFirstChild("Backpack") then countFruits(LocalPlayer.Backpack) end
    if LocalPlayer.Character then countFruits(LocalPlayer.Character) end

    if fruitCount >= 10 then
        RemoteEvent:FireServer(unpack({buffer.fromstring("\178\000\026")}))
        task.wait(0.5)
        RemoteEvent:FireServer(unpack({buffer.fromstring("\179\000")}))
    end
end

-- 5. FPS BOOST
local function applyFpsBoost()
    print("[5/6] Mengaktifkan FPS Boost...")
    local objectsToDestroy = {"MidLayer", "Baseplate", "Middle", "Grass", "Gardens", "SpawnPoint"}
    for _, name in pairs(objectsToDestroy) do if Workspace:FindFirstChild(name) then Workspace[name]:Destroy() end end
    for _, effect in pairs(Lighting:GetChildren()) do if effect:IsA("PostEffect") or effect:IsA("BloomEffect") or effect:IsA("Sky") then effect:Destroy() end end
    for _, obj in pairs(Workspace:GetDescendants()) do if obj:IsA("BasePart") then obj.Material = Enum.Material.SmoothPlastic; if obj:FindFirstChildOfClass("Decal") then obj:FindFirstChildOfClass("Decal"):Destroy() end end end
    Lighting.GlobalShadows = false
    Workspace.CurrentCamera.FieldOfView = 30
end

-- 6. AUTO BUY
local function startAutoBuy()
    print("[6/6] Mengaktifkan Auto Buy...")
    local SEEDS = {"Carrot", "Moon Bloom", "Hypno Bloom", "Dragon's Breath", "Venom Spitter", "Venus Fly Trap"}
    local GEARS = {"Common Watering Can", "Common Sprinkler", "Uncommon Sprinkler", "Rare Sprinkler", "Legendary Sprinkler", "Super Sprinkler", "Super Watering Can", "Trowel"}

    task.spawn(function()
        while true do
            for _, s in pairs(SEEDS) do 
                local p = (s == "Carrot") and "y\000\006Carrot" or "y\000" .. string.char(#s) .. s
                for i=1, 5 do pcall(function() RemoteEvent:FireServer(buffer.fromstring(p)) end); task.wait(0.1) end
            end
            for _, g in pairs(GEARS) do 
                local p = "}\000" .. string.char(#g) .. g
                for i=1, 5 do pcall(function() RemoteEvent:FireServer(buffer.fromstring(p)) end); task.wait(0.1) end
            end
            task.wait(10)
        end
    end)
end

-- --- EKSEKUSI URUTAN ---
if Workspace:GetAttribute("InTutorial") then
    completeTutorialInstantly()
    task.wait(1)
end

teleportToSteven()
task.wait(1)
claimMail()
checkAndDealSteven()
applyFpsBoost()
startAutoBuy()

Networking.Mailbox.Updated.OnClientEvent:Connect(function() task.spawn(claimMail) end)
