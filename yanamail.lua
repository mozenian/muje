-- Konfigurasi Ketat (Ubah hanya di sini sebelum dijalankan)
local TARGET_USERNAME = "sanzRNL_113" -- Ganti dengan username target pengiriman

-- Daftar item terkunci untuk dikirim otomatis [Nama Item/Pet] = Jumlah minimal yang disimpan di tas (0 untuk kirim SEMUA)
local LOCKED_ITEMS_TO_SEND = {
    -- === SEEDS & HASIL PANEN (PLANTS) ===
    ["Dragon's Breath"] = 0,
    ["Hypno Bloom"] = 0,
    ["Moon Bloom"] = 0,
    ["Ghost Pepper"] = 0,
    ["Venom Spitter"] = 0,
    ["Venus Fly Trap"] = 0,
    ["Rainbow"] = 0,
    ["Gold"] = 0,
    ["Bamboo"] = 0,
    ["Mushroom"] = 0,
    ["Pomegranate"] = 0,
    ["Poison Apple"] = 0,

    -- === GEARS & TOOLS (ALAT) ===
    ["Trowel"] = 0,
    ["Super Watering Can"] = 0,
    ["Common Watering Can"] = 0,
    ["Legendary Sprinkler"] = 0,
    ["Super Sprinkler"] = 0,
    ["Rare Sprinkler"] = 0,
    ["Uncommon Sprinkler"] = 0,
    ["Common Sprinkler"] = 0,
    ["Jump Mushroom"] = 0,
    ["Speed Mushroom"] = 0,
    ["Shrink Mushroom"] = 0,
    ["Invisibility Mushroom"] = 0,
    ["Gnome"] = 0,
    ["Basic Pot"] = 0,
    ["Sign"] = 0,
    ["Lantern"] = 0,
    ["Flashbang"] = 0,
    ["Teleporter"] = 0,
    ["Wheelbarrow"] = 0,

    -- === PETS (HEWAN PELIHARAAN) ===
    ["Ice Serpent"] = 0,
    ["Raccoon"] = 0,
    ["Unicorn"] = 0,
    ["GoldenDragonfly"] = 0,
    ["Black Dragon"] = 0,
    ["Bear"] = 0,

    -- === PROPS / CRATES (OPSIONAL) ===
    ["Ladder Crate"] = 0,
    ["Bench Crate"] = 0,
    ["Light Crate"] = 0,
    ["Sign Crate"] = 0,
    ["Arch Crate"] = 0,
    ["Roleplay Crate"] = 0,
    ["Bridge Crate"] = 0,
    ["Spring Crate"] = 0,
    ["Seesaw Crate"] = 0,
    ["Conveyor Crate"] = 0,
    ["Owner Door Crate"] = 0,
    ["Bear Trap Crate"] = 0,
    ["Fence Crate"] = 0,
    ["Teleporter Pad Crate"] = 0,
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
-- ANTI-AFK (WAJIB UNTUK MOBILE/PC JIKA DITINGGAL BERJAM-JAM)
--------------------------------------------------------------------------------
local VirtualUser = game:GetService("VirtualUser")
LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
    print("[Auto-Mail] Mencegah AFK Kick...")
end)

--------------------------------------------------------------------------------
-- LOOP PEMANTAUAN BACKGROUND (VERSI AMAN UNTUK DELTA / MOBILE)
--------------------------------------------------------------------------------
local cooldownWaktu = 21600 -- 6 jam dalam detik
local waktuTerakhirKirim = os.time() - cooldownWaktu -- Dikurangi agar saat pertama di-execute langsung ngirim

task.spawn(function()
    while true do
        local waktuSekarang = os.time()
        
        -- Jika selisih waktu sekarang dan terakhir kirim sudah lebih dari 6 jam
        if waktuSekarang - waktuTerakhirKirim >= cooldownWaktu then
            print("[Auto-Mail] Waktu 6 jam tercapai, mengeksekusi pengiriman...")
            pcall(checkAndSendInventory)
            waktuTerakhirKirim = os.time() -- Reset timer
        end
        
        -- Loop kecil 5 detik agar script tidak "tertidur" (dibunuh oleh Android)
        task.wait(5) 
    end
end)
