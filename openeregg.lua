-- ==========================================
-- KONFIGURASI WEBHOOK DISCORD
-- ==========================================
-- Ganti tulisan di dalam tanda kutip dengan link Webhook Discord kamu.
-- Kosongkan saja ("") jika sedang tidak ingin menggunakan Webhook.
local WebhookURL = "https://discord.com/api/webhooks/1489342206853513269/QPKARC7IelRlcRA-lQr33I4obZMqcXJh6QxpJKVGMFyb09qZfwkb3zyDQBiDZQ5mZLWE"

-- ==========================================
-- DAFTAR TARGET PET (GAMPANG DI-LISTING)
-- ==========================================
-- Format: {"Nama Pet", "Ukuran Pet", "Tipe/Mutasi Pet"}
-- Hapus baris yang tidak terpakai, JANGAN biarkan ada {"", "", ""}!

local TargetList = {
    {"Unicorn", "Mega", ""},
	{"Unicorn", "Huge", ""},
	{"Unicorn", "Huge", "Rainbow"},
	{"Unicorn", "Mega", "Rainbow"},
	{"Unicorn", "Big", "Rainbow"},
    {"Unicorn", "", "Rainbow"},
    {"Raccoon", "Big", ""},
	{"Raccoon", "Huge", ""},
	{"Raccoon", "Huge", "Rainbow"},
	{"Raccoon", "Big", "Rainbow"},
	{"Raccoon", "Mega", "Rainbow"},
    {"Raccoon", "Mega", ""},
    {"Raccoon", "", "Rainbow"},
    {"Bear", "Mega", ""},
	{"Bear", "Mega", "Rainbow"},
	{"Bear", "Huge", ""},
	{"Bear", "Huge", "Rainbow"},
	{"Bear", "Big", "Rainbow"},
    {"Bear", "", "Rainbow"},
    {"Bald Eagle", "Mega", ""},
	{"Bald Eagle", "Mega", "Rainbow"},
	{"Bald Eagle", "Huge", ""},
	{"Bald Eagle", "Huge", "Rainbow"},
    {"Bald Eagle", "Big", ""},
	{"Bald Eagle", "Big", "Rainbow"},
    {"Bald Eagle", "", "Rainbow"},
    {"Golden Dragonfly", "Mega", ""},
    {"Golden Dragonfly", "", "Rainbow"},
	{"Golden Dragonfly", "Huge", "Rainbow"},
	{"Golden Dragonfly", "Big", "Rainbow"},
	{"Golden Dragonfly", "Mega", "Rainbow"},
}

-- ==========================================
-- INISIALISASI VARIABEL
-- ==========================================
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remote = ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("Packet"):WaitForChild("RemoteEvent")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local HttpService = game:GetService("HttpService")

-- ==========================================
-- FUNGSI WEBHOOK DISCORD
-- ==========================================
local function sendWebhook(petDetails)
    -- Cek apakah URL webhook sudah diisi
    if WebhookURL == "" or WebhookURL == "ISI_LINK_WEBHOOK_DISINI" then return end
    
    local data = {
        ["content"] = "🎉 **Auto-Hatch Alert!** 🎉\nBerhasil mendapatkan target: **" .. petDetails .. "**\nRollback telah dibatalkan & data tersimpan aman!",
        ["username"] = "Pet Notifier",
        ["avatar_url"] = "https://cdn-icons-png.flaticon.com/512/826/826963.png"
    }
    
    -- Mendukung berbagai macam eksekutor (Synapse, Fluxus, KRNL, Delta, dll)
    local req = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request
    if req then
        pcall(function()
            req({
                Url = WebhookURL,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = HttpService:JSONEncode(data)
            })
        end)
    end
end

-- ==========================================
-- FUNGSI ROLLBACK & REJOIN
-- ==========================================
local function fireRollbackOnce()
    local payload = string.char(0x3A, 0xF7)
    Remote:FireServer(payload)
    Remote:FireServer(54, "\xEF\xBF")
    Remote:FireServer(54, ":\xF7")
end

local function disableRollbackOnce()
    Remote:FireServer(54, "")
    Remote:FireServer(54, string.char(0x20))
    Remote:FireServer(54)
    Remote:FireServer(20, "")
end

local function rejoinGame()
    TeleportService:Teleport(game.PlaceId, player)
end

-- ==========================================
-- FUNGSI DETEKSI PET & TELUR
-- ==========================================
local function checkPetMatch(petInstance)
    if not petInstance then return false, nil end

    local petNameAttr = petInstance:GetAttribute("Pet")
    -- Fallback jika attribute "Pet" tidak ada, kita pakai nama instance-nya
    if not petNameAttr then petNameAttr = petInstance.Name end 

    local petSizeAttr = petInstance:GetAttribute("PetSize")
    local petTypeAttr = petInstance:GetAttribute("PetType")
    local objName = petInstance.Name

    for _, target in ipairs(TargetList) do
        local tName = target[1]
        local tSize = target[2]
        local tType = target[3]

        -- ANTI-BLUNDER: Jika ketiga kolom kosong, abaikan baris ini!
        if tName == "" and tSize == "" and tType == "" then
            continue 
        end

        local matchPet = true
        local matchSize = true
        local matchType = true

        -- Deteksi Nama
        if tName ~= "" then
            matchPet = (petNameAttr == tName) or string.find(objName, tName)
        end
        
        -- Deteksi Size (Contoh: Mega, Big)
        if tSize ~= "" then
            matchSize = (petSizeAttr == tSize) or string.find(objName, tSize)
        end
        
        -- Deteksi Type (Contoh: Rainbow)
        -- Diperbarui: Sekarang ikut mengecek objName untuk berjaga-jaga
        if tType ~= "" then
            matchType = (petTypeAttr == tType) or string.find(objName, tType)
        end

        -- Jika KETIGA syarat terpenuhi (atau syarat yang diisi saja)
        if matchPet and matchSize and matchType then
            local details = string.format("%s (Size: %s, Type: %s)", 
                tostring(tName), 
                tostring(tSize ~= "" and tSize or "Normal"), 
                tostring(tType ~= "" and tType or "Normal")
            )
            return true, details
        end
    end
    
    return false, nil
end
local function hasTargetPet()
    local backpack = player:FindFirstChild("Backpack")
    if backpack then
        for _, item in ipairs(backpack:GetChildren()) do
            local isMatch, details = checkPetMatch(item)
            if isMatch then return true, details end
        end
    end

    local petVisuals = workspace:FindFirstChild("_PetVisualClient")
    local petModels = petVisuals and petVisuals:FindFirstChild("Models")
    if petModels then
        for _, model in ipairs(petModels:GetChildren()) do
            local isMatch, details = checkPetMatch(model)
            if isMatch then return true, details end
        end
    end

    return false, nil
end

local function hasEgg()
    local inBackpack = player:FindFirstChild("Backpack") and player.Backpack:FindFirstChild("Common Egg")
    local inCharacter = player.Character and player.Character:FindFirstChild("Common Egg")
    return inBackpack or inCharacter
end

-- ==========================================
-- FUNGSI SPAM TELUR
-- ==========================================
local function openEggs(amount)
    local args = { buffer.fromstring("\142\000&\nCommon Egg") }
    for i = 1, amount do
        task.spawn(function()
            Remote:FireServer(unpack(args))
        end)
    end
end

-- ==========================================
-- MAIN LOOP (CORE)
-- ==========================================
local function startBot()
    fireRollbackOnce()
    
    if not player.Character then player.CharacterAdded:Wait() end
    task.wait(2)

    while task.wait(1) do
        local found, petDetails = hasTargetPet()
        
        if found then
            disableRollbackOnce()
            sendWebhook(petDetails) -- MENGIRIM PESAN KE DISCORD
            task.wait(3) 
            player:Kick("🎉 Berhasil mendapatkan target: " .. petDetails .. " 🎉\nRollback telah dibatalkan & data tersimpan!")
            return 
        end

        if hasEgg() then
            openEggs(500)
        else
            task.wait(25)
            
            local finalFound, finalDetails = hasTargetPet()
            if finalFound then
                disableRollbackOnce()
                sendWebhook(finalDetails) -- MENGIRIM PESAN KE DISCORD
                task.wait(3) 
                player:Kick("🎉 Berhasil mendapatkan target di detik terakhir: " .. finalDetails .. " 🎉\nRollback dibatalkan!")
                return
            end

            rejoinGame()
            return 
        end
    end
end

task.spawn(startBot)
