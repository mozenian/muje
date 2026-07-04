local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser = game:GetService("VirtualUser")
local RemoteEvent = ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("Packet"):WaitForChild("RemoteEvent")
local LocalPlayer = Players.LocalPlayer
local Networking = require(ReplicatedStorage.SharedModules.Networking)

-- 1. BYPASS TUTORIAL
local function completeTutorialInstantly()
    print("[1/7] Bypass tutorial...")
    pcall(function()
        RemoteEvent:FireServer(unpack({buffer.fromstring("r\000\028\005\001\v\rShovel:Shovel\005\002\v\vBuild:Build\000")}))
        task.wait(0.2)
        RemoteEvent:FireServer(unpack({buffer.fromstring("9\001")}))
        task.wait(0.2)
        RemoteEvent:FireServer(unpack({buffer.fromstring("\174\000\029")}))
    end)
end

-- 2. TELEPORT KE STEVEN
local function teleportToSteven()
    print("[2/7] Teleport ke Steven...")
    local steven = Workspace:FindFirstChild("Steven", true)
    
    -- Tunggu jika Steven belum selesai loading
    if not steven then
        repeat
            task.wait(1)
            steven = Workspace:FindFirstChild("Steven", true)
        until steven
    end

    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if steven and root then
        local target = (steven:IsA("Model") and (steven.PrimaryPart or steven:FindFirstChild("HumanoidRootPart"))) or (steven:IsA("BasePart") and steven)
        if target then
            root.CFrame = target.CFrame + Vector3.new(0, 3, 3)
            task.wait(0.5)
            
            -- FITUR ANTI VOID: Mengunci karakter & membuat platform pijakan
            root.Anchored = true 
            local plat = Instance.new("Part")
            plat.Size = Vector3.new(50, 2, 50)
            plat.Position = root.Position - Vector3.new(0, 4, 0)
            plat.Anchored = true
            plat.Transparency = 1 
            plat.Parent = Workspace
        end
    end
end

-- 3. AUTO CLAIM MAIL
local function claimMail()
    print("[3/7] Memeriksa inbox...")
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
    print("[4/7] Memeriksa Daily Deal...")
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
        pcall(function()
            RemoteEvent:FireServer(unpack({buffer.fromstring("\178\000\026")}))
            task.wait(0.5)
            RemoteEvent:FireServer(unpack({buffer.fromstring("\179\000")}))
        end)
    end
end

-- 5. FPS BOOST
local function applyFpsBoost()
    print("[5/7] Mengaktifkan FPS Boost...")
    local objectsToDestroy = {"MidLayer", "Baseplate", "Middle", "Grass", "Gardens", "SpawnPoint"}
    for _, name in pairs(objectsToDestroy) do 
        if Workspace:FindFirstChild(name) then Workspace[name]:Destroy() end 
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
end

-- 6. AUTO SELL
local function startAutoSell()
    print("[6/7] Mengaktifkan Auto Sell...")
    local utilityTools = {
        ["Basic Pot"] = true, ["Watering Can"] = true, ["Trowel"] = true, 
        ["Super Trowel"] = true, ["Golden Trowel"] = true, ["Infinite Watering Can"] = true, ["Seed Bag"] = true
    }

    local function isSellableFruit(item)
        if not item:IsA("Tool") then return false end
        local name = item.Name
        if utilityTools[name] then return false end
        if name:find("Pot") or name:find("Can") or name:find("Trowel") or name:find("Bag") then return false end
        if name:find("Fertilizer") or name:find("Axe") or name:find("Pickaxe") or name:find("Shovel") then return false end
        return true
    end

    task.spawn(function()
        while true do
            task.wait(2)
            local fruits = {}
            
            if LocalPlayer:FindFirstChild("Backpack") then
                for _, item in ipairs(LocalPlayer.Backpack:GetChildren()) do
                    if isSellableFruit(item) then table.insert(fruits, item) end
                end
            end
            
            if LocalPlayer.Character then
                for _, item in ipairs(LocalPlayer.Character:GetChildren()) do
                    if isSellableFruit(item) then table.insert(fruits, item) end
                end
            end
            
            if #fruits > 0 then
                pcall(function() Networking.NPCS.SellAll:Fire() end)
                task.wait(0.5)
                
                local stillHasFruits = false
                if LocalPlayer:FindFirstChild("Backpack") then
                    for _, item in ipairs(LocalPlayer.Backpack:GetChildren()) do
                        if isSellableFruit(item) then stillHasFruits = true break end
                    end
                end
                
                if stillHasFruits then
                    for _, tool in ipairs(fruits) do
                        local id = tool:GetAttribute("Id")
                        if id and tool.Parent then 
                            pcall(function() Networking.NPCS.SellFruit:Fire(id) end)
                            task.wait(0.1)
                        end
                    end
                end
            end
        end
    end)
end

-- 7. AUTO BUY (SUDAH DIPERBARUI: Beda opcode untuk Seeds dan Gears)
local function startAutoBuy()
    print("[7/7] Mengaktifkan Auto Buy...")
    
    local SEEDS = {
        "Carrot", "Coconut", "Moon Bloom",
        "Hypno Bloom", "Dragon's Breath", "Venom Spitter", "Venus Fly Trap"
    } 
    
    local GEARS = {
        "Rare Sprinkler", "Legendary Sprinkler", "Super Sprinkler", "Super Watering Can"
    }

    task.spawn(function()
        while true do
            -- Eksekusi Beli Bibit (Menggunakan awalan "{\000")
            for _, itemName in ipairs(SEEDS) do 
                local payloadString = "{\000" .. string.char(#itemName) .. itemName
                local args = { buffer.fromstring(payloadString) }
                for i = 1, 3 do 
                    pcall(function() RemoteEvent:FireServer(unpack(args)) end)
                    task.wait(0.3) 
                end
            end
            
            -- Eksekusi Beli Alat (Menggunakan awalan "\127\000")
            for _, itemName in ipairs(GEARS) do 
                local payloadString = "\127\000" .. string.char(#itemName) .. itemName
                local args = { buffer.fromstring(payloadString) }
                for i = 1, 3 do 
                    pcall(function() RemoteEvent:FireServer(unpack(args)) end)
                    task.wait(0.3)
                end
            end
            
            task.wait(10)
        end
    end)
end

-- ANTI AFK
local function setupAntiAFK()
    print("[+] Anti-AFK diaktifkan.")
    LocalPlayer.Idled:Connect(function()
        VirtualUser:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
        task.wait(1)
        VirtualUser:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
    end)
end

-- ==========================
-- --- EKSEKUSI URUTAN ---
-- ==========================
setupAntiAFK()
Networking.Mailbox.Updated.OnClientEvent:Connect(function() task.spawn(claimMail) end)

task.spawn(function()
    -- 1. BYPASS TUTORIAL
    if Workspace:GetAttribute("InTutorial") then
        completeTutorialInstantly()
        while Workspace:GetAttribute("InTutorial") do
            task.wait(0.5)
        end
        task.wait(1)
    end
    
    -- 2. TELEPORT KE STEVEN (Sudah ada pengaman map void)
    teleportToSteven()
    task.wait(1)
    
    -- 3. CLAIM MAIL
    claimMail()
    task.wait(0.5)
    
    -- 4. DAILY DEAL (STEVEN)
    checkAndDealSteven()
    task.wait(0.5)
    
    -- 5. FPS BOOST
    applyFpsBoost()
    task.wait(0.5)
    
    -- 6. AUTO SELL
    startAutoSell()
    
    -- 7. AUTO BUY
    startAutoBuy()
    
    print("[+] Selesai! Semua urutan tereksekusi dengan sempurna.")
end)
