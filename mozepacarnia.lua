-- Konfigurasi Ketat (Ubah hanya di sini sebelum dijalankan)
local TARGET_USERNAME = "mozenian" -- Ganti dengan username target pengiriman

-- Daftar item terkunci untuk dikirim otomatis [Nama Item/Pet] = Jumlah minimal yang disimpan di tas (0 untuk kirim SEMUA)
local LOCKED_ITEMS_TO_SEND = {
    ["Dragon's Breath"] = 0,        -- Mengirim semua apel yang ada di tas tanpa sisa
    ["Moon Bloom"] = 0, -- Contoh buah lain
    ["Caroot"] = 0,
	["Strawberry"] = 0,
	["Super Sprinkler"] = 0,
	["Legendary Sprinkler"] = 0,
	["Super Watering Can"] = 0,
        ["Unicorn"] = 0,
	["Raccoon"] = 0,
	["Golden Dragonfly"] = 0,  -- Contoh: Masukkan nama Pet kamu di sini (hanya mengirim yang TIDAK sedang dipakai)
    -- Tambahkan item atau pet lainnya di bawah ini sesuai kebutuhanmu
}

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

print("[Auto-Mail] Menginisialisasi sistem pengiriman otomatis...")

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
-- LOGIKA PEMERIKSAAN DAN PENGIRIMAN
--------------------------------------------------------------------------------
local function checkAndSendInventory()
    local replica = PlayerStateClient:GetLocalReplica()
    if not replica or not replica.Data or not replica.Data.Inventory then return end
    
    local inventory = replica.Data.Inventory
    local apiBatch = {}
    
    -- Memeriksa kategori valid dari katalog game
    for _, cat in ipairs(MailboxItemCatalog.Categories) do
        local catData = inventory[cat]
        if typeof(catData) == "table" then
            
            -- Logika khusus untuk kategori Pet atau Buah Hasil Panen (Item yang memiliki ID unik/UUID)
            if cat == "Pets" or cat == "HarvestedFruits" then
                for itemKey, itemVal in pairs(catData) do
                    if typeof(itemVal) == "table" and itemVal.Id ~= nil then
                        -- Jika itu Pet, pastikan Pet tersebut tidak sedang dipakai (Equipped)
                        if cat == "Pets" and itemVal.Equipped == true then
                            continue
                        end
                        
                        local itemName = itemVal.Name or itemKey
                        if LOCKED_ITEMS_TO_SEND[itemName] then
                            -- Untuk Pet/Fruits, 'itemKey' yang dikirim adalah ID unik/UUID-nya
                            table.insert(apiBatch, {
                                Category = cat,
                                ItemKey = itemKey,
                                Count = 1 -- Pet dan Fruit jenis ini selalu dikirim 1 per 1 per slot
                            })
                        end
                    end
                end
            else
                -- Logika untuk item biasa yang menumpuk/stackable (Seeds, Buah biasa, dll.)
                for itemKey, count in pairs(catData) do
                    if typeof(count) == "number" and count > 0 then
                        local targetMinCount = LOCKED_ITEMS_TO_SEND[itemKey]
                        
                        if targetMinCount then
                            local amountToSend = count - targetMinCount
                            if amountToSend > 0 then
                                table.insert(apiBatch, {
                                    Category = cat,
                                    ItemKey = itemKey, -- Menggunakan nama item sebagai key
                                    Count = amountToSend
                                })
                            end
                        end
                    end
                end
            end
            
        end
    end
    
    -- Jika ada item atau pet yang cocok ditemukan, proses pengiriman dimulai
    if #apiBatch > 0 then
        print(string.format("[Auto-Mail] Terdeteksi %d item/pet yang cocok. Memproses pengiriman batch...", #apiBatch))
        
        -- Pengiriman dibagi per kelompok maksimal 20 item (batasan sistem game)
        local currentBatch = {}
        for i, item in ipairs(apiBatch) do
            table.insert(currentBatch, item)
            if #currentBatch == 20 or i == #apiBatch then
                local sendSuccess, result = pcall(function()
                    return Networking.Mailbox.SendBatch:Fire(targetUserId, currentBatch, "Automated Locked Delivery")
                end)
                
                if sendSuccess and result then
                    print("[Auto-Mail] Batch item berhasil dikirim!")
                else
                    warn("[Auto-Mail] Pengiriman gagal:", tostring(result))
                end
                currentBatch = {}
                task.wait(6) -- Jeda keamanan 6 detik untuk menghindari anti-rate limit game
            end
        end
    end
end

--------------------------------------------------------------------------------
-- LOOP PEMANTAUAN BACKGROUND
--------------------------------------------------------------------------------
-- Memeriksa inventaris secara otomatis setiap 15 detik
task.spawn(function()
    while true do
        pcall(checkAndSendInventory)
        task.wait(15)
    end
end)
