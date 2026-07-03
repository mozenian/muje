-- Game Verification
if game.PlaceId ~= 97598239454123 then return end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- Mengambil referensi Module & RemoteEvent
local Networking = require(ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("Networking"))
local packetRemote = ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("Packet"):WaitForChild("RemoteEvent")

local function log(message)
    print("[AutoMail & DailyDeal]: " .. message)
end

-- Fungsi mendeteksi item buah
local function isSellableFruit(tool)
    return tool:IsA("Tool") and not (tool.Name:find("Pot") or tool.Name:find("Can") or tool.Name:find("Trowel") or tool.Name:find("Bag"))
end

-- 1. Fungsi Auto Claim Mail (Tanpa Sell)
local function claimMail()
    log("Memeriksa inbox...")
    
    local ok, inbox = pcall(function()
        return Networking.Mailbox.OpenInbox:Fire()
    end)
    
    if not ok or typeof(inbox) ~= "table" then return end
    
    local count = 0
    for _ in pairs(inbox) do count = count + 1 end
    
    if count == 0 then return end
    
    log("Mengklaim " .. count .. " item dari mail...")
    
    for id in pairs(inbox) do
        local success = pcall(function() 
            Networking.Mailbox.Claim:Fire(id) 
        end)
        
        if success then
            log("Berhasil klaim ID: " .. string.sub(id, 1, 8))
        end
        task.wait(0.5) 
    end
    
    log("Klaim mail selesai.")
end

-- 2. Fungsi Auto Daily Deal Steven
local function checkAndDealSteven()
    local fruitCount = 0
    local fruitsToDestroy = {}
    
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    local character = LocalPlayer.Character

    -- Hitung dan kumpulkan buah di Backpack
    if backpack then
        for _, item in pairs(backpack:GetChildren()) do
            if isSellableFruit(item) then
                fruitCount = fruitCount + 1
                table.insert(fruitsToDestroy, item)
            end
        end
    end

    -- Hitung dan kumpulkan buah yang sedang dipegang di Character
    if character then
        for _, item in pairs(character:GetChildren()) do
            if isSellableFruit(item) then
                fruitCount = fruitCount + 1
                table.insert(fruitsToDestroy, item)
            end
        end
    end

    -- Jika buah mencapai 10 atau lebih, jalankan Daily Deal
    if fruitCount >= 10 then
        log("Terdapat " .. fruitCount .. " buah. Menjalankan Daily Deal ke Steven...")
        
        -- Mengirim Packet 1
        local args1 = { buffer.fromstring("\178\000\026") }
        packetRemote:FireServer(unpack(args1))
        
        task.wait(0.5) -- Jeda aman agar server memproses request
        
        -- Mengirim Packet 2
        local args2 = { buffer.fromstring("\179\000") }
        packetRemote:FireServer(unpack(args2))
        
        -- Hilangkan objek menggunakan destroy agar inventory bersih
        for _, item in ipairs(fruitsToDestroy) do
            if item and item.Parent then
                item:Destroy()
            end
        end
        log("Daily Deal berhasil dan buah telah dihapus dari inventory.")
    end
end

-- ==========================================
-- EKSEKUSI & LOOPING
-- ==========================================

-- Jalankan pengecekan Mail sekali saat script pertama kali aktif
task.spawn(claimMail)

-- Event listener saat ada mail baru masuk
Networking.Mailbox.Updated.OnClientEvent:Connect(function()
    log("Mail baru terdeteksi!")
    task.spawn(claimMail)
end)

-- Loop berkala setiap 5 menit (300 detik) untuk memeriksa inbox (backup)
task.spawn(function()
    while true do
        task.wait(300)
        claimMail()
    end
end)

-- Loop untuk mengecek ketersediaan 10 buah secara berkala setiap 10 detik
task.spawn(function()
    while true do
        task.wait(10)
        pcall(checkAndDealSteven)
    end
end)

log("Script Auto Claim Mail & Daily Deal Steven telah aktif.")
