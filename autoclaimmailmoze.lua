-- Game Verification
if game.PlaceId ~= 97598239454123 then return end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Networking = require(ReplicatedStorage.SharedModules.Networking)
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local function log(message)
    print("[AutoClaimSell]: " .. message)
end

-- Fungsi untuk mendeteksi apakah item adalah buah yang bisa dijual
local function isSellableFruit(tool)
    -- Sesuaikan dengan logika pengecekan item yang ada di script Anda
    return tool:IsA("Tool") and not (tool.Name:find("Pot") or tool.Name:find("Can") or tool.Name:find("Trowel") or tool.Name:find("Bag"))
end

-- Fungsi untuk menjual semua isi inventory
local function sellAllFruits()
    log("Menjual isi inventory...")
    pcall(function()
        Networking.NPCS.SellAll:Fire()
    end)
end

local function claimAndSell()
    log("Memeriksa inbox...")
    
    local ok, inbox = pcall(function()
        return Networking.Mailbox.OpenInbox:Fire()
    end)
    
    if not ok or typeof(inbox) ~= "table" then
        return
    end
    
    local count = 0
    for _ in pairs(inbox) do count = count + 1 end
    
    if count == 0 then return end
    
    log("Mengklaim " .. count .. " item...")
    
    for id in pairs(inbox) do
        local success = pcall(function() 
            Networking.Mailbox.Claim:Fire(id) 
        end)
        
        if success then
            log("Berhasil klaim ID: " .. string.sub(id, 1, 8))
        end
        task.wait(0.5) 
    end
    
    log("Klaim selesai, memicu penjualan...")
    task.wait(1.0) -- Jeda singkat agar item masuk ke inventory sebelum dijual
    sellAllFruits()
end

-- 1. Jalankan sekali saat script aktif
task.spawn(claimAndSell)

-- 2. Jalankan otomatis saat ada mail baru masuk
Networking.Mailbox.Updated.OnClientEvent:Connect(function()
    log("Mail baru terdeteksi!")
    task.spawn(claimAndSell)
end)

-- 3. Loop berkala setiap 5 menit (300 detik)
task.spawn(function()
    while true do
        task.wait(300)
        claimAndSell()
    end
end)

log("Auto Claim & Sell aktif.")
