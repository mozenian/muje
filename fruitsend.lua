-- Game Verification
if game.PlaceId ~= 97598239454123 then
    warn("Script ini hanya untuk Grow a Garden 2!")
    return
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Hooking ke modul internal game
local Networking = require(ReplicatedStorage.SharedModules.Networking)
local PlayerStateClient = require(ReplicatedStorage.ClientModules.PlayerStateClient)

local GUI_NAME = "AdvancedMultiMailSender"
if PlayerGui:FindFirstChild(GUI_NAME) then
    PlayerGui[GUI_NAME]:Destroy()
end

-- State variables
local availableItems = {}
local selectedItems = {} 
local currentTab = "All"
local isSending = false
local tabs = {"All", "Fruits", "Seeds", "Gears", "Pets"}
local tabButtons = {}

-- ===========================
-- MEMBUAT TAMPILAN GUI
-- ===========================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = GUI_NAME
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = PlayerGui

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 440, 0, 600)
MainFrame.Position = UDim2.new(0.5, -220, 0.5, -300)
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 26, 31)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 8)

local TitleFrame = Instance.new("Frame")
TitleFrame.Size = UDim2.new(1, 0, 0, 45)
TitleFrame.BackgroundColor3 = Color3.fromRGB(33, 34, 44)
TitleFrame.BorderSizePixel = 0
TitleFrame.Parent = MainFrame
Instance.new("UICorner", TitleFrame).CornerRadius = UDim.new(0, 8)

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -50, 1, 0)
Title.Position = UDim2.new(0, 15, 0, 0)
Title.BackgroundTransparency = 1
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Text = "📦 Advanced Multi-Select Mail Sender"
Title.Font = Enum.Font.GothamBold
Title.TextSize = 15
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TitleFrame

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 45, 0, 45)
CloseBtn.Position = UDim2.new(1, -45, 0, 0)
CloseBtn.BackgroundTransparency = 1
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = Color3.fromRGB(255, 90, 90)
CloseBtn.TextSize = 16
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.Parent = TitleFrame
CloseBtn.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)

local TargetBox = Instance.new("TextBox")
TargetBox.Size = UDim2.new(0.94, 0, 0, 40)
TargetBox.Position = UDim2.new(0.03, 0, 0, 60)
TargetBox.BackgroundColor3 = Color3.fromRGB(18, 19, 23)
TargetBox.TextColor3 = Color3.fromRGB(255, 255, 255)
TargetBox.PlaceholderText = "Username Tujuan..."
TargetBox.Text = ""
TargetBox.Font = Enum.Font.Gotham
TargetBox.TextSize = 14
TargetBox.ClearTextOnFocus = false
TargetBox.Parent = MainFrame
Instance.new("UICorner", TargetBox).CornerRadius = UDim.new(0, 6)

-- Input Jumlah (Spesifik)
local AmountBox = Instance.new("TextBox")
AmountBox.Size = UDim2.new(0.94, 0, 0, 40)
AmountBox.Position = UDim2.new(0.03, 0, 0, 110)
AmountBox.BackgroundColor3 = Color3.fromRGB(18, 19, 23)
AmountBox.TextColor3 = Color3.fromRGB(255, 255, 255)
AmountBox.PlaceholderText = "Jumlah Kirim per Item (Kosong = Kirim Semua)"
AmountBox.Text = ""
AmountBox.Font = Enum.Font.Gotham
AmountBox.TextSize = 14
AmountBox.ClearTextOnFocus = false
AmountBox.Parent = MainFrame
Instance.new("UICorner", AmountBox).CornerRadius = UDim.new(0, 6)

local ControlFrame = Instance.new("Frame")
ControlFrame.Size = UDim2.new(0.94, 0, 0, 35)
ControlFrame.Position = UDim2.new(0.03, 0, 0, 160)
ControlFrame.BackgroundTransparency = 1
ControlFrame.Parent = MainFrame

local UIListControl = Instance.new("UIListLayout")
UIListControl.FillDirection = Enum.FillDirection.Horizontal
UIListControl.HorizontalAlignment = Enum.HorizontalAlignment.Center
UIListControl.Padding = UDim.new(0.02, 0)
UIListControl.SortOrder = Enum.SortOrder.LayoutOrder
UIListControl.Parent = ControlFrame

local function createControlBtn(text, color, parent)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.32, 0, 1, 0)
    btn.BackgroundColor3 = color
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Text = text
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 13
    btn.Parent = parent
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    return btn
end

local RefreshBtn = createControlBtn("Refresh", Color3.fromRGB(65, 68, 88), ControlFrame)
local SelectAllBtn = createControlBtn("Pilih Semua", Color3.fromRGB(56, 128, 70), ControlFrame)
local ClearBtn = createControlBtn("Batal Pilih", Color3.fromRGB(160, 60, 60), ControlFrame)

local TabFrame = Instance.new("Frame")
TabFrame.Size = UDim2.new(0.94, 0, 0, 30)
TabFrame.Position = UDim2.new(0.03, 0, 0, 205)
TabFrame.BackgroundTransparency = 1
TabFrame.Parent = MainFrame

local TabListLayout = Instance.new("UIListLayout")
TabListLayout.FillDirection = Enum.FillDirection.Horizontal
TabListLayout.Padding = UDim.new(0, 10)
TabListLayout.Parent = TabFrame

local function createTab(name)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.18, 0, 1, 0)
    btn.BackgroundColor3 = Color3.fromRGB(40, 42, 54)
    btn.TextColor3 = Color3.fromRGB(200, 200, 200)
    btn.Text = name
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 12
    btn.Parent = TabFrame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    return btn
end

local ScrollFrame = Instance.new("ScrollingFrame")
ScrollFrame.Size = UDim2.new(0.94, 0, 0, 180)
ScrollFrame.Position = UDim2.new(0.03, 0, 0, 245)
ScrollFrame.BackgroundColor3 = Color3.fromRGB(18, 19, 23)
ScrollFrame.BorderSizePixel = 0
ScrollFrame.ScrollBarThickness = 5
ScrollFrame.Parent = MainFrame
Instance.new("UICorner", ScrollFrame).CornerRadius = UDim.new(0, 6)

local ScrollList = Instance.new("UIListLayout")
ScrollList.Padding = UDim.new(0, 5)
ScrollList.Parent = ScrollFrame

local SendBtn = Instance.new("TextButton")
SendBtn.Size = UDim2.new(0.94, 0, 0, 45)
SendBtn.Position = UDim2.new(0.03, 0, 0, 435)
SendBtn.BackgroundColor3 = Color3.fromRGB(56, 160, 85)
SendBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
SendBtn.Text = "KIRIM ITEM TERPILIH"
SendBtn.Font = Enum.Font.GothamBold
SendBtn.TextSize = 15
SendBtn.Parent = MainFrame
Instance.new("UICorner", SendBtn).CornerRadius = UDim.new(0, 6)

local LogScroll = Instance.new("ScrollingFrame")
LogScroll.Size = UDim2.new(0.94, 0, 0, 95)
LogScroll.Position = UDim2.new(0.03, 0, 0, 490)
LogScroll.BackgroundColor3 = Color3.fromRGB(12, 13, 16)
LogScroll.BorderSizePixel = 0
LogScroll.ScrollBarThickness = 3
LogScroll.Parent = MainFrame
Instance.new("UICorner", LogScroll).CornerRadius = UDim.new(0, 6)

local LogList = Instance.new("UIListLayout")
LogList.Padding = UDim.new(0, 3)
LogList.Parent = LogScroll

local function addLog(msg, color)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -10, 0, 16)
    lbl.Position = UDim2.new(0, 5, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = msg
    lbl.TextColor3 = color or Color3.fromRGB(150, 200, 255)
    lbl.TextSize = 12
    lbl.Font = Enum.Font.Code
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = LogScroll
    LogScroll.CanvasSize = UDim2.new(0, 0, 0, LogList.AbsoluteContentSize.Y)
    LogScroll.CanvasPosition = Vector2.new(0, LogList.AbsoluteContentSize.Y)
end

-- ===========================
-- LOGIKA UTAMA (UNIVERSAL SCANNER V6)
-- ===========================

local function renderList()
    for _, child in ipairs(ScrollFrame:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    local count = 0
    for _, item in ipairs(availableItems) do
        if currentTab == "All" or item.TabCategory == currentTab then
            local Row = Instance.new("Frame")
            Row.Size = UDim2.new(1, -8, 0, 34)
            Row.BackgroundColor3 = selectedItems[item.Id] and Color3.fromRGB(45, 48, 65) or Color3.fromRGB(33, 34, 44)
            Row.BorderSizePixel = 0
            Row.Parent = ScrollFrame
            Instance.new("UICorner", Row).CornerRadius = UDim.new(0, 4)

            local Check = Instance.new("TextLabel")
            Check.Size = UDim2.new(0, 30, 1, 0)
            Check.BackgroundTransparency = 1
            Check.Text = selectedItems[item.Id] and "☑" or "☐"
            Check.TextColor3 = selectedItems[item.Id] and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(150, 150, 150)
            Check.TextSize = 18
            Check.Parent = Row

            local NameLbl = Instance.new("TextLabel")
            NameLbl.Size = UDim2.new(1, -40, 1, 0)
            NameLbl.Position = UDim2.new(0, 30, 0, 0)
            NameLbl.BackgroundTransparency = 1
            
            if item.Weight then
                NameLbl.Text = string.format("[%s] %s [%.2fkg]", item.TabCategory, item.Name, item.Weight)
            elseif item.Count > 1 then
                NameLbl.Text = string.format("[%s] %s (x%s)", item.TabCategory, item.Name, tostring(item.Count))
            else
                NameLbl.Text = string.format("[%s] %s", item.TabCategory, item.Name)
            end
            
            NameLbl.TextColor3 = Color3.fromRGB(220, 220, 220)
            NameLbl.TextSize = 12
            NameLbl.Font = Enum.Font.GothamMedium
            NameLbl.TextXAlignment = Enum.TextXAlignment.Left
            NameLbl.TextTruncate = Enum.TextTruncate.AtEnd
            NameLbl.Parent = Row

            local Btn = Instance.new("TextButton")
            Btn.Size = UDim2.new(1, 0, 1, 0)
            Btn.BackgroundTransparency = 1
            Btn.Text = ""
            Btn.Parent = Row

            Btn.MouseButton1Click:Connect(function()
                selectedItems[item.Id] = not selectedItems[item.Id]
                renderList()
            end)
            count = count + 1
        end
    end

    ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, count * 39)
end

-- FUNGSI SCAN HYBRID: MENGGABUNGKAN BACKPACK DAN DATABASE
local function scanInventory()
    availableItems = {}
    local validIds = {}
    local counts = {Fruits = 0, Pets = 0, Stacks = 0}

    -- 1. SCAN BACKPACK (Fokus untuk Buah yang ada di tas fisik)
    for _, item in pairs(LocalPlayer.Backpack:GetChildren()) do
        local uuid = item:GetAttribute("Id")
        if uuid then
            -- Deteksi buah berdasarkan atribut
            local isFruit = item:GetAttribute("HarvestedFruit") == true or item:GetAttribute("Weight") ~= nil
            if isFruit and not validIds[uuid] then
                table.insert(availableItems, {
                    Id = uuid,
                    Name = item:GetAttribute("FruitName") or item:GetAttribute("Fruit") or item.Name,
                    Weight = item:GetAttribute("Weight"),
                    Count = 1,
                    TabCategory = "Fruits",
                    MailCategory = "HarvestedFruits"
                })
                validIds[uuid] = true
                counts.Fruits = counts.Fruits + 1
            end
        end
    end

    -- 2. SCAN DATABASE (Untuk Pets dan item Stackable seperti Seeds, Gears)
    local replica = PlayerStateClient:GetLocalReplica()
    if replica and replica.Data and replica.Data.Inventory then
        for cat, catData in pairs(replica.Data.Inventory) do
            if typeof(catData) == "table" then
                
                -- AMBIL PETS DARI DATABASE
                if cat == "Pets" then
                    for itemKey, itemVal in pairs(catData) do
                        if typeof(itemVal) == "table" and itemVal.Equipped ~= true then
                            local uuid = itemVal.Id or itemKey
                            if not validIds[uuid] then
                                table.insert(availableItems, {
                                    Id = uuid,
                                    Name = itemVal.Name or itemKey,
                                    Count = 1,
                                    TabCategory = "Pets",
                                    MailCategory = "Pets"
                                })
                                validIds[uuid] = true
                                counts.Pets = counts.Pets + 1
                            end
                        end
                    end
                
                -- AMBIL BUAH DARI DATABASE (Sebagai cadangan jika tas gagal)
                elseif cat == "HarvestedFruits" or cat == "Crops" then
                    for itemKey, itemVal in pairs(catData) do
                        if typeof(itemVal) == "table" then
                            local uuid = itemVal.Id or itemKey
                            if not validIds[uuid] then
                                local itemName = itemVal.Name or itemVal.FruitName or itemVal.Fruit or itemKey
                                if type(itemName) == "string" and #itemName > 25 then itemName = "Harvested Crop" end
                                
                                table.insert(availableItems, {
                                    Id = uuid,
                                    Name = itemName,
                                    Weight = itemVal.Weight,
                                    Count = 1,
                                    TabCategory = "Fruits",
                                    MailCategory = "HarvestedFruits"
                                })
                                validIds[uuid] = true
                                counts.Fruits = counts.Fruits + 1
                            end
                        end
                    end

                -- AMBIL STACKABLES DARI DATABASE (Seeds, Gears, Dll)
                else
                    for itemKey, count in pairs(catData) do
                        if typeof(count) == "number" and count > 0 then
                            if itemKey ~= "Shovel" and itemKey ~= "Build" then
                                if not validIds[itemKey] then
                                    local tabCat = "Gears"
                                    if cat == "Seeds" then tabCat = "Seeds" end
                                    
                                    table.insert(availableItems, {
                                        Id = itemKey,
                                        Name = itemKey,
                                        Count = count,
                                        TabCategory = tabCat,
                                        MailCategory = cat
                                    })
                                    validIds[itemKey] = true
                                    counts.Stacks = counts.Stacks + 1
                                end
                            end
                        end
                    end
                end

            end
        end
    else
        addLog("Peringatan: Tidak bisa memuat PlayerState database.", Color3.fromRGB(255, 150, 100))
    end

    -- Membersihkan memori pilihan jika barang sudah tidak ada di tas
    for id, _ in pairs(selectedItems) do
        if not validIds[id] then selectedItems[id] = nil end
    end

    renderList()
    addLog(string.format("Scan Selesai: %d Buah, %d Pet, %d Stackable.", counts.Fruits, counts.Pets, counts.Stacks), Color3.fromRGB(100, 200, 255))
end

local function changeTab(tabName)
    currentTab = tabName
    for name, btn in pairs(tabButtons) do
        if name == tabName then
            btn.BackgroundColor3 = Color3.fromRGB(90, 140, 210)
            btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        else
            btn.BackgroundColor3 = Color3.fromRGB(40, 42, 54)
            btn.TextColor3 = Color3.fromRGB(200, 200, 200)
        end
    end
    renderList()
end

for _, tabName in ipairs(tabs) do
    local btn = createTab(tabName)
    tabButtons[tabName] = btn
    btn.MouseButton1Click:Connect(function() changeTab(tabName) end)
end
changeTab("All")

RefreshBtn.MouseButton1Click:Connect(scanInventory)
SelectAllBtn.MouseButton1Click:Connect(function()
    for _, item in ipairs(availableItems) do 
        if currentTab == "All" or item.TabCategory == currentTab then
            selectedItems[item.Id] = true 
        end
    end
    renderList()
end)
ClearBtn.MouseButton1Click:Connect(function()
    if currentTab == "All" then
        selectedItems = {}
    else
        for _, item in ipairs(availableItems) do
            if item.TabCategory == currentTab then
                selectedItems[item.Id] = nil
            end
        end
    end
    renderList()
end)

SendBtn.MouseButton1Click:Connect(function()
    if isSending then return end
    local targetUser = TargetBox.Text:match("^%s*(.-)%s*$")
    
    if targetUser == "" then
        addLog("ERROR: Masukkan Username tujuan!", Color3.fromRGB(255, 100, 100))
        return
    end

    local itemsToSend = {}
    for _, item in ipairs(availableItems) do
        if selectedItems[item.Id] then
            table.insert(itemsToSend, item)
        end
    end

    if #itemsToSend == 0 then
        addLog("ERROR: Tidak ada item yang dipilih!", Color3.fromRGB(255, 100, 100))
        return
    end

    local globalAmountText = AmountBox.Text:match("^%s*(.-)%s*$")
    local globalAmount = tonumber(globalAmountText)

    isSending = true
    SendBtn.Text = "MEMPROSES PENGIRIMAN..."
    SendBtn.BackgroundColor3 = Color3.fromRGB(150, 130, 50)
    
    task.spawn(function()
        addLog("Mencari ID untuk " .. targetUser .. "...", Color3.fromRGB(220, 220, 100))
        local ok, targetId, displayName = pcall(function()
            return Networking.Mailbox.LookupPlayer:Fire(targetUser)
        end)

        if not ok or not targetId or targetId <= 0 then
            addLog("ERROR: Username tidak ditemukan/salah!", Color3.fromRGB(255, 100, 100))
            isSending = false
            SendBtn.Text = "KIRIM ITEM TERPILIH"
            SendBtn.BackgroundColor3 = Color3.fromRGB(56, 160, 85)
            return
        end

        addLog("Penerima: " .. displayName .. ". Memulai...", Color3.fromRGB(100, 255, 100))

        local batch = {}
        local batchNumber = 1
        local totalSentCount = 0
        
        for i, item in ipairs(itemsToSend) do
            local amountToSend = item.Count
            
            -- Terapkan batas khusus jika user memasukkan angka, DAN item tersebut BUKAN item unik
            if globalAmount and globalAmount > 0 then
                if item.TabCategory ~= "Pets" and item.TabCategory ~= "Fruits" then
                    amountToSend = math.min(globalAmount, item.Count)
                end
            end

            table.insert(batch, {
                Category = item.MailCategory,
                ItemKey = item.Id,
                Count = amountToSend
            })

            if #batch >= 20 or i == #itemsToSend then
                addLog(string.format("Mengirim batch %d...", batchNumber), Color3.fromRGB(200, 200, 200))
                
                local success, result, errMsg = pcall(function()
                    return Networking.Mailbox.SendBatch:Fire(targetId, batch, "Multi-Select Item Send")
                end)

                if success and result then
                    addLog(string.format("Batch %d BERHASIL!", batchNumber), Color3.fromRGB(100, 255, 100))
                    for _, sentItem in ipairs(batch) do
                        selectedItems[sentItem.ItemKey] = nil
                        totalSentCount = totalSentCount + sentItem.Count
                    end
                else
                    local errTxt = typeof(errMsg) == "string" and errMsg or tostring(result)
                    addLog("GAGAL: " .. errTxt, Color3.fromRGB(255, 100, 100))
                    for _, b in ipairs(batch) do
                        addLog(string.format("-> [Cat: %s | Key: %s | Qty: %d]", tostring(b.Category), tostring(b.ItemKey), b.Count), Color3.fromRGB(255, 150, 150))
                    end
                end

                batch = {}
                batchNumber = batchNumber + 1
                
                if i < #itemsToSend then task.wait(5.5) end
            end
        end

        addLog(string.format("PENGIRIMAN SELESAI! Total Item: %d", totalSentCount), Color3.fromRGB(100, 255, 255))
        isSending = false
        SendBtn.Text = "KIRIM ITEM TERPILIH"
        SendBtn.BackgroundColor3 = Color3.fromRGB(56, 160, 85)
        
        scanInventory()
    end)
end)

scanInventory()
addLog("Hybrid Scanner V6 siap digunakan.", Color3.fromRGB(100, 255, 100))
