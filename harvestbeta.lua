-- ==========================================
-- KONFIGURASI WEBHOOK DISCORD
-- ==========================================
local WebhookURL = "https://discord.com/api/webhooks/1489342206853513269/QPKARC7IelRlcRA-lQr33I4obZMqcXJh6QxpJKVGMFyb09qZfwkb3zyDQBiDZQ5mZLWE"

-- ==========================================
-- DAFTAR TARGET PET (BOT BERHENTI JIKA INI DIDAPAT)
-- ==========================================
local TargetList = {
    {"Unicorn", "Mega", ""},
    {"Unicorn", "Big", ""},
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
-- DAFTAR TELUR YANG INGIN DI-HATCH
-- ==========================================
local TargetEggs = {
    "Common Egg",
    "Rainbow Egg"
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

local NotifiedPets = {} 

-- ==========================================
-- FUNGSI WEBHOOK DISCORD
-- ==========================================
local function sendWebhook(messageContent)
    if WebhookURL == "" or WebhookURL == "ISI_LINK_WEBHOOK_DISINI" then return end
    
    local data = {
        ["content"] = messageContent,
        ["username"] = "Pet Notifier",
        ["avatar_url"] = "https://media.discordapp.net/attachments/1518293361096654948/1524668262225285130/IMG-20251016-WA0000.jpg?ex=6a509578&is=6a4f43f8&hm=2fef5e7ff037f577f0d4a9d9836764c6fbd95e8a77154ceb9f1a6475d83b9784&=&format=webp"
    }
    
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
-- PERSIAPAN MENGABAIKAN PET LAMA (ANTI-SPAM)
-- ==========================================
local function registerInitialPets()
    local bp = player:FindFirstChild("Backpack")
    if bp then
        for _, item in ipairs(bp:GetChildren()) do
            NotifiedPets[item] = true
        end
    end
    if player.Character then
        for _, item in ipairs(player.Character:GetChildren()) do
            if item:IsA("Tool") then
                NotifiedPets[item] = true
            end
        end
    end
end

-- ==========================================
-- FUNGSI UTAMA PENDETEKSIAN PET
-- ==========================================
local function scanPets()
    local itemsToCheck = {}
    
    -- 1. Ambil dari Folder Temporary (Visual Animasi)
    local tempFolder = workspace:FindFirstChild("Temporary")
    if tempFolder then
        for _, item in ipairs(tempFolder:GetChildren()) do
            -- FILTER KETAT: Abaikan komponen UI/Attachment, hanya proses Model/Part asli
            if not string.find(item.Name, "Attachment") and not string.find(item.Name, "Effect") then
                if item:IsA("Model") or item:IsA("BasePart") then
                    table.insert(itemsToCheck, item)
                end
            end
        end
    end
    
    -- 2. Ambil dari Backpack (Data Pet Asli)
    local bp = player:FindFirstChild("Backpack")
    if bp then
        for _, item in ipairs(bp:GetChildren()) do
            -- FILTER KETAT: Hanya proses jika dia berjenis "Tool" (Bentuk asli pet di inventory)
            if item:IsA("Tool") and not table.find(TargetEggs, item.Name) then 
                table.insert(itemsToCheck, item)
            end
        end
    end

    local newlyHatchedRare = {}
    local foundTarget = false
    local targetDetails = nil

    for _, item in ipairs(itemsToCheck) do
        if not NotifiedPets[item] then
            NotifiedPets[item] = true
            
            local petNameAttr = item:GetAttribute("Pet") or ""
            local petSizeAttr = item:GetAttribute("PetSize") or ""
            local petTypeAttr = item:GetAttribute("PetType") or ""
            local objName = item.Name

            local visualText = ""
            pcall(function()
                for _, desc in ipairs(item:GetDescendants()) do
                    if desc:IsA("TextLabel") and desc.Text ~= "" then
                        visualText = visualText .. " " .. desc.Text
                    end
                end
            end)

            local petName = (petNameAttr ~= "") and petNameAttr or objName
            local displaySize = petSizeAttr
            local displayType = petTypeAttr

            if displaySize == "" then
                if string.find(objName, "Big") or string.find(visualText, "Big") then displaySize = "Big"
                elseif string.find(objName, "Mega") or string.find(visualText, "Mega") then displaySize = "Mega"
                elseif string.find(objName, "Huge") or string.find(visualText, "Huge") then displaySize = "Huge"
                end
            end

            if displayType == "" then
                if string.find(objName, "Rainbow") or string.find(visualText, "Rainbow") then displayType = "Rainbow" end
            end

            -- =======================================
            -- CEK TARGET UNTUK STOP BOT
            -- =======================================
            for _, target in ipairs(TargetList) do
                local tName = target[1]
                local tSize = target[2]
                local tType = target[3]

                if tName == "" and tSize == "" and tType == "" then continue end

                local matchPet = (tName == "") or (petNameAttr == tName) or string.find(objName, tName) or string.find(visualText, tName)
                local matchSize = (tSize == "") or (displaySize == tSize)
                local matchType = (tType == "") or (displayType == tType)

                if matchPet and matchSize and matchType then
                    foundTarget = true
                    targetDetails = string.format("%s (Size: %s, Type: %s)", 
                        tName ~= "" and tName or petName, 
                        tSize ~= "" and tSize or "Normal", 
                        tType ~= "" and tType or "Normal"
                    )
                    break
                end
            end

            -- =======================================
            -- CEK RARE UNTUK WEBHOOK
            -- =======================================
            local isRare = false
			if string.find(petName, "Unicorn") or 
               string.find(petName, "Bear") or 
               string.find(petName, "Raccoon") or 
               string.find(petName, "Golden Dragonfly") then
                 isRare = true
            if displaySize == "Big" or displaySize == "Mega" or displaySize == "Huge" then isRare = true end
            if displayType == "Rainbow" then isRare = true end

            if isRare then
                local details = string.format("**%s** (Size: %s, Type: %s)", 
                    petName, 
                    displaySize ~= "" and displaySize or "Normal", 
                    displayType ~= "" and displayType or "Normal"
                )
                table.insert(newlyHatchedRare, details)
            end
        end
    end

    -- =======================================
    -- KIRIM PESAN KE DISCORD
    -- =======================================
    if #newlyHatchedRare > 0 then
        local messageChunk = "🌟 **Rare Pets Hatched!** 🌟\nMendapatkan:\n"
        for _, petDetail in ipairs(newlyHatchedRare) do
            local nextLine = "- " .. petDetail .. "\n"
            if string.len(messageChunk) + string.len(nextLine) > 1900 then
                sendWebhook(messageChunk)
                messageChunk = "🌟 **Rare Pets Hatched (Lanjutan)!** 🌟\nMendapatkan:\n"
            end
            messageChunk = messageChunk .. nextLine
        end
        if messageChunk ~= "🌟 **Rare Pets Hatched!** 🌟\nMendapatkan:\n" and messageChunk ~= "🌟 **Rare Pets Hatched (Lanjutan)!** 🌟\nMendapatkan:\n" then
            sendWebhook(messageChunk)
        end
    end

    return foundTarget, targetDetails
end

-- ==========================================
-- FUNGSI SPAM TELUR
-- ==========================================
local function hasEgg()
    local inBackpack = player:FindFirstChild("Backpack")
    local inCharacter = player.Character

    for _, eggName in ipairs(TargetEggs) do
        if (inBackpack and inBackpack:FindFirstChild(eggName)) or (inCharacter and inCharacter:FindFirstChild(eggName)) then
            return true
        end
    end
    return false
end

local function openEggs(amount)
    for _, eggName in ipairs(TargetEggs) do
        local payloadString = "\142\000&" .. string.char(#eggName) .. eggName
        local args = { buffer.fromstring(payloadString) }
        
        for i = 1, amount do
            task.spawn(function()
                Remote:FireServer(unpack(args))
            end)
        end
    end
end

-- ==========================================
-- MAIN LOOP (CORE)
-- ==========================================
local function startBot()
    registerInitialPets()
    
    fireRollbackOnce()
    
    if not player.Character then player.CharacterAdded:Wait() end
    task.wait(2)

    while task.wait(1) do
        local found, petDetails = scanPets()
        
        if found then
            disableRollbackOnce()
            local successMessage = "@everyone 🎉 **Auto-Hatch Alert!** 🎉\nBerhasil mendapatkan target: **" .. petDetails .. "**\nRollback telah dibatalkan & data tersimpan aman!"
            sendWebhook(successMessage) 
            task.wait(3) 
            player:Kick(successMessage)
            return 
        end

        if hasEgg() then
            openEggs(500)
        else
            local temporaryFolder = workspace:FindFirstChild("Temporary")
            if temporaryFolder then
                while #temporaryFolder:GetChildren() > 0 do
                    local waitFound, waitDetails = scanPets()
                    if waitFound then
                        disableRollbackOnce()
                        local waitMessage = "@everyone 🎉 **Auto-Hatch Alert!** 🎉\nBerhasil mendapatkan target saat menunggu animasi: **" .. waitDetails .. "**\nRollback dibatalkan!"
                        sendWebhook(waitMessage)
                        task.wait(3) 
                        player:Kick(waitMessage)
                        return
                    end
                    task.wait(0.5)
                end
            end
            
            task.wait(5)
            
            local finalFound, finalDetails = scanPets()
            if finalFound then
                disableRollbackOnce()
                local finalMessage = "@everyone 🎉 **Auto-Hatch Alert!** 🎉\nBerhasil mendapatkan target di detik terakhir: **" .. finalDetails .. "**\nRollback dibatalkan!"
                sendWebhook(finalMessage)
                task.wait(3) 
                player:Kick(finalMessage)
                return
            end

            rejoinGame()
            return 
        end
    end
end

task.spawn(startBot)
