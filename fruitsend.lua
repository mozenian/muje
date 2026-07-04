-- Game Verification: Pastikan hanya berjalan di Grow a Garden 2
if game.PlaceId ~= 97598239454123 then
    warn("Script ini hanya untuk Grow a Garden 2!")
    return
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Hooking ke modul pengiriman surat bawaan game
local Networking = require(ReplicatedStorage.SharedModules.Networking)

-- Hapus GUI lama jika ada
local GUI_NAME = "MultiSelectFruitGUI"
if PlayerGui:FindFirstChild(GUI_NAME) then
    PlayerGui[GUI_NAME]:Destroy()
end

-- State variables
local availableFruits = {}
local selectedFruits = {} -- [Id] = true/false
local isSending = false

-- ===========================
-- MEMBUAT TAMPILAN GUI
-- ===========================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = GUI_NAME
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = PlayerGui

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 360, 0, 480)
MainFrame.Position = UDim2.new(0.5, -180, 0.5, -240)
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 8)
UICorner.Parent = MainFrame

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 40)
Title.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Text = " 🍓 Multi-Select Fruit Sender"
Title.Font = Enum.Font.GothamBold
Title.TextSize = 15
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = MainFrame
Instance.new("UICorner", Title).CornerRadius = UDim.new(0, 8)
local TitlePadding = Instance.new("UIPadding")
TitlePadding.PaddingLeft = UDim.new(0, 15)
TitlePadding.Parent = Title

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 40, 0, 40)
CloseBtn.Position = UDim2.new(1, -40, 0, 0)
CloseBtn.BackgroundTransparency = 1
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = Color3.fromRGB(200, 100, 100)
CloseBtn.TextSize = 18
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.Parent = Title
CloseBtn.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)

-- Recipient Input
local TargetBox = Instance.new("TextBox")
TargetBox.Size = UDim2.new(0.9, 0, 0, 35)
TargetBox.Position = UDim2.new(0.05, 0, 0, 50)
TargetBox.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
TargetBox.TextColor3 = Color3.fromRGB(255, 255, 255)
TargetBox.PlaceholderText = "Username Tujuan..."
TargetBox.Text = ""
TargetBox.Font = Enum.Font.Gotham
TargetBox.TextSize = 13
TargetBox.ClearTextOnFocus = false
TargetBox.Parent = MainFrame
Instance.new("UICorner", TargetBox).CornerRadius = UDim.new(0, 5)

-- Toolbar (Select All, Clear, Refresh)
local ToolBar = Instance.new("Frame")
ToolBar.Size = UDim2.new(0.9, 0, 0, 30)
ToolBar.Position = UDim2.new(0.05, 0, 0, 95)
ToolBar.BackgroundTransparency = 1
ToolBar.Parent = MainFrame

local function createMiniBtn(text, color, pos, parent)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.31, 0, 1, 0)
    btn.Position = pos
    btn.BackgroundColor3 = color
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Text = text
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11
    btn.Parent = parent
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
    return btn
end

local RefreshBtn = createMiniBtn("Refresh", Color3.fromRGB(60, 60, 80), UDim2.new(0, 0, 0, 0), ToolBar)
local SelectAllBtn = createMiniBtn("Pilih Semua", Color3.fromRGB(50, 120, 70), UDim2.new(0.345, 0, 0, 0), ToolBar)
local ClearBtn = createMiniBtn("Batal Pilih", Color3.fromRGB(150, 50, 50), UDim2.new(0.69, 0, 0, 0), ToolBar)

-- List Buah
local ScrollFrame = Instance.new("ScrollingFrame")
ScrollFrame.Size = UDim2.new(0.9, 0, 0, 150)
ScrollFrame.Position = UDim2.new(0.05, 0, 0, 135)
ScrollFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
ScrollFrame.BorderSizePixel = 0
ScrollFrame.ScrollBarThickness = 4
ScrollFrame.Parent = MainFrame
Instance.new("UICorner", ScrollFrame).CornerRadius = UDim.new(0, 5)

local ScrollList = Instance.new("UIListLayout")
ScrollList.Padding = UDim.new(0, 4)
ScrollList.Parent = ScrollFrame

-- Tombol Kirim
local SendBtn = Instance.new("TextButton")
SendBtn.Size = UDim2.new(0.9, 0, 0, 40)
SendBtn.Position = UDim2.new(0.05, 0, 0, 295)
SendBtn.BackgroundColor3 = Color3.fromRGB(50, 150, 80)
SendBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
SendBtn.Text = "KIRIM BUAH TERPILIH"
SendBtn.Font = Enum.Font.GothamBold
SendBtn.TextSize = 14
SendBtn.Parent = MainFrame
Instance.new("UICorner", SendBtn).CornerRadius = UDim.new(0, 5)

-- Status Log
local LogScroll = Instance.new("ScrollingFrame")
LogScroll.Size = UDim2.new(0.9, 0, 0, 125)
LogScroll.Position = UDim2.new(0.05, 0, 0, 345)
LogScroll.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
LogScroll.BorderSizePixel = 0
LogScroll.ScrollBarThickness = 4
LogScroll.Parent = MainFrame
Instance.new("UICorner", LogScroll).CornerRadius = UDim.new(0, 5)

local LogList = Instance.new("UIListLayout")
LogList.Padding = UDim.new(0, 2)
LogList.Parent = LogScroll

local function addLog(msg, color)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -5, 0, 15)
    lbl.BackgroundTransparency = 1
    lbl.Text = " " .. msg
    lbl.TextColor3 = color or Color3.fromRGB(200, 200, 200)
    lbl.TextSize = 11
    lbl.Font = Enum.Font.Code
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = LogScroll
    LogScroll.CanvasSize = UDim2.new(0, 0, 0, LogList.AbsoluteContentSize.Y)
    LogScroll.CanvasPosition = Vector2.new(0, LogList.AbsoluteContentSize.Y)
end

-- ===========================
-- LOGIKA UTAMA
-- ===========================

-- 1. Fungsi render daftar UI
local function renderList()
    -- Hapus daftar lama
    for _, child in ipairs(ScrollFrame:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    local count = 0
    for _, fruit in ipairs(availableFruits) do
        local Row = Instance.new("Frame")
        Row.Size = UDim2.new(1, -5, 0, 28)
        Row.BackgroundColor3 = selectedFruits[fruit.Id] and Color3.fromRGB(45, 45, 60) or Color3.fromRGB(30, 30, 35)
        Row.BorderSizePixel = 0
        Row.Parent = ScrollFrame
        Instance.new("UICorner", Row).CornerRadius = UDim.new(0, 4)

        local Check = Instance.new("TextLabel")
        Check.Size = UDim2.new(0, 25, 1, 0)
        Check.BackgroundTransparency = 1
        Check.Text = selectedFruits[fruit.Id] and "☑" or "☐"
        Check.TextColor3 = selectedFruits[fruit.Id] and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(150, 150, 150)
        Check.TextSize = 18
        Check.Parent = Row

        local NameLbl = Instance.new("TextLabel")
        NameLbl.Size = UDim2.new(1, -30, 1, 0)
        NameLbl.Position = UDim2.new(0, 30, 0, 0)
        NameLbl.BackgroundTransparency = 1
        NameLbl.Text = string.format("%s [%.2fkg]", fruit.Name, fruit.Weight)
        NameLbl.TextColor3 = Color3.fromRGB(220, 220, 220)
        NameLbl.TextSize = 12
        NameLbl.Font = Enum.Font.GothamMedium
        NameLbl.TextXAlignment = Enum.TextXAlignment.Left
        NameLbl.Parent = Row

        local Btn = Instance.new("TextButton")
        Btn.Size = UDim2.new(1, 0, 1, 0)
        Btn.BackgroundTransparency = 1
        Btn.Text = ""
        Btn.Parent = Row

        Btn.MouseButton1Click:Connect(function()
            selectedFruits[fruit.Id] = not selectedFruits[fruit.Id]
            renderList()
        end)
        count = count + 1
    end

    ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, count * 32)
end

-- 2. Fungsi memindai isi ransel
local function scanBackpack()
    availableFruits = {}
    
    for _, item in pairs(LocalPlayer.Backpack:GetChildren()) do
        -- Hanya ambil item yang memiliki atribut HarvestedFruit
        if item:GetAttribute("HarvestedFruit") == true then
            local id = item:GetAttribute("Id")
            if id then
                table.insert(availableFruits, {
                    Id = id,
                    Name = item:GetAttribute("FruitName") or item:GetAttribute("Fruit") or item.Name,
                    Weight = item:GetAttribute("Weight") or 0
                })
            end
        end
    end

    -- Hapus item yang di-select sebelumnya tapi sudah tidak ada di tas
    local validIds = {}
    for _, v in ipairs(availableFruits) do validIds[v.Id] = true end
    for id, _ in pairs(selectedFruits) do
        if not validIds[id] then selectedFruits[id] = nil end
    end

    renderList()
    addLog(string.format("Scan selesai. Menemukan %d buah di Backpack.", #availableFruits), Color3.fromRGB(100, 200, 255))
end

-- Event tombol toolbar
RefreshBtn.MouseButton1Click:Connect(scanBackpack)
SelectAllBtn.MouseButton1Click:Connect(function()
    for _, fruit in ipairs(availableFruits) do selectedFruits[fruit.Id] = true end
    renderList()
end)
ClearBtn.MouseButton1Click:Connect(function()
    selectedFruits = {}
    renderList()
end)

-- 3. Fungsi Kirim
SendBtn.MouseButton1Click:Connect(function()
    if isSending then return end
    
    local targetUser = TargetBox.Text:match("^%s*(.-)%s*$")
    
    if targetUser == "" then
        addLog("ERROR: Masukkan Username tujuan!", Color3.fromRGB(255, 100, 100))
        return
    end

    -- Kumpulkan buah yang dicentang
    local fruitsToSend = {}
    for _, fruit in ipairs(availableFruits) do
        if selectedFruits[fruit.Id] then
            table.insert(fruitsToSend, fruit)
        end
    end

    if #fruitsToSend == 0 then
        addLog("ERROR: Tidak ada buah yang dipilih!", Color3.fromRGB(255, 100, 100))
        return
    end

    isSending = true
    SendBtn.Text = "MEMPROSES PENGIRIMAN..."
    SendBtn.BackgroundColor3 = Color3.fromRGB(150, 150, 50)
    
    task.spawn(function()
        addLog("Mencari ID untuk " .. targetUser .. "...", Color3.fromRGB(200, 200, 100))
        local ok, targetId, displayName = pcall(function()
            return Networking.Mailbox.LookupPlayer:Fire(targetUser)
        end)

        if not ok or not targetId or targetId <= 0 then
            addLog("ERROR: Username tidak ditemukan/salah!", Color3.fromRGB(255, 100, 100))
            isSending = false
            SendBtn.Text = "KIRIM BUAH TERPILIH"
            SendBtn.BackgroundColor3 = Color3.fromRGB(50, 150, 80)
            return
        end

        addLog("Penerima: " .. displayName .. ". Memulai...", Color3.fromRGB(100, 255, 100))

        local batch = {}
        local batchNumber = 1
        local totalSent = 0
        
        for i, fruit in ipairs(fruitsToSend) do
            table.insert(batch, {
                Category = "HarvestedFruits",
                ItemKey = fruit.Id,
                Count = 1
            })

            -- Batch maksimal 20 (Batasan aman server)
            if #batch >= 20 or i == #fruitsToSend then
                addLog(string.format("Mengirim batch %d (%d buah)...", batchNumber, #batch), Color3.fromRGB(200, 200, 200))
                
                local success, result, errMsg = pcall(function()
                    return Networking.Mailbox.SendBatch:Fire(targetId, batch, "Multi-Select Fruit Send")
                end)

                if success and result then
                    totalSent = totalSent + #batch
                    addLog(string.format("Batch %d BERHASIL!", batchNumber), Color3.fromRGB(100, 255, 100))
                    
                    -- Hapus dari daftar seleksi jika berhasil dikirim
                    for _, sentItem in ipairs(batch) do
                        selectedFruits[sentItem.ItemKey] = nil
                    end
                else
                    local errTxt = typeof(errMsg) == "string" and errMsg or tostring(result)
                    addLog("GAGAL: " .. errTxt, Color3.fromRGB(255, 100, 100))
                end

                batch = {}
                batchNumber = batchNumber + 1
                
                -- Delay wajib antar batch agar tidak terdeteksi spamming (Rate-Limit)
                if i < #fruitsToSend then
                    task.wait(5.5) 
                end
            end
        end

        addLog(string.format("PENGIRIMAN SELESAI! Total: %d buah.", totalSent), Color3.fromRGB(100, 255, 255))
        isSending = false
        SendBtn.Text = "KIRIM BUAH TERPILIH"
        SendBtn.BackgroundColor3 = Color3.fromRGB(50, 150, 80)
        
        -- Perbarui daftar otomatis setelah kirim
        scanBackpack()
    end)
end)

-- Scan ransel saat pertama kali UI dibuka
scanBackpack()
addLog("Siap digunakan.", Color3.fromRGB(100, 255, 100))
