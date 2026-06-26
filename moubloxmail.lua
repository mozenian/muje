-- Konfigurasi Ketat (Ubah hanya di sini sebelum dijalankan)
local TARGET_USERNAME = "Moonstok10" -- Ganti dengan username target pengiriman

--------------------------------------------------------------------------------
-- KEAMANAN & INISIALISASI
--------------------------------------------------------------------------------
if game.PlaceId ~= 97598239454123 then
    warn("[Auto-Mail] Salah game. Script dihentikan.")
    return
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local Networking = require(ReplicatedStorage.SharedModules.Networking)
local PlayerStateClient = require(ReplicatedStorage.ClientModules.PlayerStateClient)
local MailboxItemCatalog = require(LocalPlayer.PlayerScripts.Controllers.MailboxController.MailboxItemCatalog)

print("[Auto-Mail] Menginisialisasi sistem pengiriman Bypass All Inventory...")

-- Mencari UserId dari target username
local targetUserId = nil
local success, id, displayName = pcall(function()
    return Networking.Mailbox.LookupPlayer:Fire(TARGET_USERNAME)
end)

if success and id and id > 0 then
    targetUserId = id
    print(string.format("[Auto-Mail] Target terkunci: %s (ID: %d)", displayName, targetUserId))
else
    warn("[Auto-Mail] Tidak dapat menemukan pengguna target. Silakan periksa kembali username-nya.")
    return
end

--------------------------------------------------------------------------------
-- LOGIKA PEMERIKSAAN DAN PENGIRIMAN (ALL INVENTORY BYPASS)
--------------------------------------------------------------------------------
local function checkAndSendInventory()
    local replica = PlayerStateClient:GetLocalReplica()
    if not replica or not replica.Data or not replica.Data.Inventory then return end
    
    local inventory = replica.Data.Inventory
    local apiBatch = {}
    
    -- Memeriksa seluruh kategori valid dari katalog game
    for _, cat in ipairs(MailboxItemCatalog.Categories) do
        local catData = inventory[cat]
        if typeof(catData) == "table" then
            
            -- Logika khusus untuk kategori Pet atau Buah Hasil Panen (Item UUID unik)
            if cat == "Pets" or cat == "HarvestedFruits" then
                for itemKey, itemVal in pairs(catData) do
                    if typeof(itemVal) == "table" and itemVal.Id ~= nil then
                        -- Fitur Keamanan: Jangan kirim pet yang sedang dipakai (Equipped)
                        if cat == "Pets" and itemVal.Equipped == true then
                            continue
                        end
                        
                        table.insert(apiBatch, {
                            Category = cat,
                            ItemKey = itemKey, -- Menggunakan ID Unik/UUID
                            Count = 1
                        })
                    end
                end
            else
                -- Logika untuk item biasa yang menumpuk (Seeds, Tools, Material, dll.)
                for itemKey, itemData in pairs(catData) do
                    local amount = 0
                    local actualItemKey = itemKey

                    -- Deteksi fleksibel: apakah jumlah item disimpan sebagai angka langsung atau di dalam tabel (seperti Seeds)
                    if typeof(itemData) == "number" then
                        amount = itemData
                    elseif typeof(itemData) == "table" then
                        amount = itemData.Amount or itemData.Count or itemData.Value or 1
                        actualItemKey = itemData.Id or itemKey 
                    end

                    -- Jika item ada (lebih dari 0), masukkan ke antrean pengiriman
                    if amount > 0 then
                        table.insert(apiBatch, {
                            Category = cat,
                            ItemKey = actualItemKey,
                            Count = amount -- Kirim SEMUA jumlah yang ada secara langsung
                        })
                    end
                end
            end
            
        end
    end
    
    -- Jika ada item yang terdeteksi di tas, LANGSUNG KIRIM SEMUA SEKALIGUS
    if #apiBatch > 0 then
        print(string.format("[Auto-Mail] Mem-bypass batas! Mengirim total %d slot item sekaligus ke %s...", #apiBatch, displayName))
        
        -- Bypass: Menembakkan seluruh isi array `apiBatch` sekaligus tanpa dipecah per 20 item
        local sendSuccess, result = pcall(function()
            return Networking.Mailbox.SendBatch:Fire(targetUserId, apiBatch, "Automated Bulk Bypass Delivery")
        end)
        
        -- Evaluasi hasil tembakan ke server
        if sendSuccess then
            print("[Auto-Mail] Bypass dieksekusi! (Cek apakah item benar-benar terkirim atau ditolak oleh server)")
        else
            warn("[Auto-Mail] Pengiriman gagal. Server menolak bypass limit:", tostring(result))
        end
    end
end

--------------------------------------------------------------------------------
-- LOOP PEMANTAUAN BACKGROUND (15 DETIK)
--------------------------------------------------------------------------------
task.spawn(function()
    while true do
        pcall(checkAndSendInventory)
        task.wait(15) -- Melakukan scan dan kirim otomatis setiap 15 detik
    end
end)
