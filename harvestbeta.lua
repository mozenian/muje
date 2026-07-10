-- ==========================================
-- ULTIMATE AUTO FARM (PLOT ID FIX & PLANTAREA OFFSET)
-- ==========================================

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local function forceClickToStart()
    if not game:IsLoaded() then
        game.Loaded:Wait()
    end
    
    task.wait(2) -- Tunggu UI game muncul
    
    local cam = workspace.CurrentCamera
    if cam then
        -- Target: Kiri Bawah (10% dari kiri, 90% dari bawah)
        -- Kamu bisa mengubah angka ini jika kurang pas
        local targetX = cam.ViewportSize.X * 0.1
        local targetY = cam.ViewportSize.Y * 0.9
        
        VirtualInputManager:SendMouseButtonEvent(targetX, targetY, 0, true, game, 1)
        task.wait(0.1)
        VirtualInputManager:SendMouseButtonEvent(targetX, targetY, 0, false, game, 1)
        
        print("Auto-Click executed at Bottom-Left: " .. targetX .. ", " .. targetY)
    end
end
task.spawn(forceClickToStart)

local LocalPlayer = Players.LocalPlayer
local RemoteEvent = ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("Packet"):WaitForChild("RemoteEvent")

-- Variabel Status
local autoWatering = false
local selectedOwner = nil
local selectedSeed = nil
local savedPlantCFrame = nil 

local rollbackActive = false
local autoRejoinActive = false
local waterCount = 0
local waterLimit = 50

-- ==========================================
-- SISTEM LOAD CONFIG
-- ==========================================
local configFileName = "WISNU_sswc.json"

local function LoadConfig()
    if readfile and isfile and isfile(configFileName) then
        local success, result = pcall(function()
            return HttpService:JSONDecode(readfile(configFileName))
        end)
        if success and type(result) == "table" then
            selectedOwner = result.Owner ~= "" and result.Owner or nil
            selectedSeed = result.Seed ~= "" and result.Seed or nil
            waterLimit = tonumber(result.Limit) or 50
            autoRejoinActive = result.Rejoin == true
            rollbackActive = result.Rollback == true
        end
    end
end
LoadConfig()

-- ==========================================
-- SISTEM ANTI-ERROR & SKIP LOADING SCREEN
-- ==========================================
local function skipLoadingScreen()
    task.spawn(function()
        pcall(function()
            local playerGui = LocalPlayer:WaitForChild("PlayerGui", 10)
            if not playerGui then return end
            
            -- Terus pantau selama 20 detik
            for i = 1, 20 do
                local foundSkip = false
                local targetGui = nil
                
                for _, gui in pairs(playerGui:GetChildren()) do
                    if gui:IsA("ScreenGui") and gui.Enabled then
                        for _, obj in pairs(gui:GetDescendants()) do
                            if obj:IsA("TextLabel") or obj:IsA("TextButton") then
                                local text = string.lower(obj.Text or "")
                                if text:find("click to skip") or text:find("skip") or text:find("play") or text:find("press any key") then
                                    foundSkip = true
                                    targetGui = gui
                                    
                                    -- Kalau dia button, kita fire signal internalnya pake task.spawn biar gak nyangkut
                                    if obj:IsA("TextButton") and getconnections then
                                        for _, conn in pairs(getconnections(obj.MouseButton1Click)) do 
                                            task.spawn(function() pcall(function() conn:Fire() end) end) 
                                        end
                                        for _, conn in pairs(getconnections(obj.Activated)) do 
                                            task.spawn(function() pcall(function() conn:Fire() end) end) 
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
                
                -- Jika ada tulisan Skip/Play, simulasikan klik + Spacebar!
                if foundSkip then
                    task.spawn(function()
                        -- 1. Simulasi Klik Tengah Layar
                        local cam = workspace.CurrentCamera
                        if cam then
                            local centerX, centerY = cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2
                            pcall(function()
                                VirtualInputManager:SendMouseButtonEvent(centerX, centerY, 0, true, game, 1)
                                task.wait(0.1)
                                VirtualInputManager:SendMouseButtonEvent(centerX, centerY, 0, false, game, 1)
                            end)
                        end
                        
                        -- 2. Simulasi pencet SPASI
                        pcall(function()
                            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
                            task.wait(0.1)
                            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
                        end)
                        
                        -- 3. Hancurkan GUI-nya sebagai fallback pamungkas
                        if targetGui then
                            pcall(function() targetGui.Enabled = false end)
                        end
                    end)
                end
                
                task.wait(1)
            end
        end)
    end)
end

local function setupAutoReconnect()
    local GuiService = game:GetService("GuiService")
    -- Handle "Uh Oh" Disconnect Error 277 (Efek dari Datastore Crash / Rollback)
    GuiService.ErrorMessageChanged:Connect(function(errorMessage)
        task.spawn(function()
            while true do
                task.wait(5) -- Coba reconnect setiap 5 detik
                pcall(function()
                    TeleportService:Teleport(game.PlaceId, LocalPlayer)
                end)
            end
        end)
    end)
end

setupAutoReconnect()
skipLoadingScreen()


-- ==========================================
-- SISTEM GENERATOR BUFFER BINARY (DIKOREKSI)
-- ==========================================
local function getPlotId(plot)
    if not plot then return 1 end
    -- Mengekstrak angka dari nama plot (Contoh: "Plot2" -> 2)
    local num = string.match(plot.Name, "%d+")
    return tonumber(num) or 1
end

local function createSprinklerBuffer(pos, plotId)
    local buf = buffer.create(31)
    buffer.writeu16(buf, 0, 20)
    buffer.writef32(buf, 2, pos.X)
    buffer.writef32(buf, 6, pos.Y)
    buffer.writef32(buf, 10, pos.Z)
    buffer.writeu8(buf, 14, 15)
    buffer.writestring(buf, 15, "Super Sprinkler")
    -- FIX FATAL: Menggunakan ID Plot Asli, bukan hardcoded angka 3!
    buffer.writeu8(buf, 30, plotId) 
    return buf
end

local function createWaterBuffer(pos)
    local buf = buffer.create(33)
    buffer.writeu16(buf, 0, 67)
    buffer.writef32(buf, 2, pos.X)
    buffer.writef32(buf, 6, pos.Y)
    buffer.writef32(buf, 10, pos.Z)
    buffer.writeu8(buf, 14, 18)
    buffer.writestring(buf, 15, "Super Watering Can")
    return buf
end

-- ==========================================
-- SISTEM ROLLBACK EXPLOIT
-- ==========================================
local function fireRollbackOnce()
    if not RemoteEvent then return false end
    RemoteEvent:FireServer(string.char(0x3A, 0xF7))
    RemoteEvent:FireServer(54, "\xEF\xBF")
    RemoteEvent:FireServer(54, ":\xF7")
    rollbackActive = true
    return true
end

local function disableRollbackOnce()
    if not rollbackActive or not RemoteEvent then return false end
    RemoteEvent:FireServer(54, "")
    RemoteEvent:FireServer(54, string.char(0x20))
    RemoteEvent:FireServer(54)
    RemoteEvent:FireServer(20, "")
    rollbackActive = false
    return true
end

-- ==========================================
-- FUNGSI LOGIKA UTAMA & SMART DETEKSI
-- ==========================================
local function getPlotByOwner(ownerName)
    local gardens = Workspace:FindFirstChild("Gardens")
    if not gardens or not ownerName then return nil end
    for _, plot in pairs(gardens:GetChildren()) do
        local ownerAttr = plot:GetAttribute("Owner") or (plot:FindFirstChild("Owner") and plot.Owner.Value)
        if ownerAttr == ownerName then return plot end
    end
    return nil
end

local function destroyAllPlantsEverywhere()
    local gardens = Workspace:FindFirstChild("Gardens")
    if not gardens then return end

    for _, plot in pairs(gardens:GetChildren()) do
        local plantsFolder = plot:FindFirstChild("Plants")
        if plantsFolder then
            local children = plantsFolder:GetChildren()
            for i, plant in ipairs(children) do
                pcall(function()
                    plant:Destroy()
                end)
                
                -- Memberi jeda setiap 20 tanaman agar tidak lag/skip
                if i % 20 == 0 then
                    task.wait() 
                end
            end
        end
    end
    print("Cleanup selesai!")
end
local function isSprinklerActive(plot)
    if not plot then return false end
    local sprinklersFolder = plot:FindFirstChild("Sprinklers")
    if sprinklersFolder then
        for _, obj in pairs(sprinklersFolder:GetChildren()) do
            local sprName = obj:GetAttribute("SprinklerName")
            if sprName == "Super Sprinkler" or string.find(obj.Name, "Super Sprinkler") then
                return true
            end
        end
    end
    return false
end

local function equipTool(toolName)
    local char = LocalPlayer.Character
    if not char then return nil end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return nil end

    local toolInChar = char:FindFirstChild(toolName)
    if toolInChar then return toolInChar end

    local toolInBackpack = LocalPlayer.Backpack:FindFirstChild(toolName)
    if toolInBackpack then
        humanoid:EquipTool(toolInBackpack)
        task.wait(0.2)
        return toolInBackpack
    end
    return nil
end

-- PHYSICS FLIGHT
local function flyToTarget(targetPos)
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") or not char:FindFirstChild("Humanoid") then return false end
    
    local root = char.HumanoidRootPart
    local hum = char.Humanoid
    
    local finalTarget = Vector3.new(targetPos.X, root.Position.Y, targetPos.Z)
    local distance = (root.Position - finalTarget).Magnitude
    if distance <= 12 then return true end 
    
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(999999, 999999, 999999)
    bv.Velocity = Vector3.zero
    bv.Parent = root
    
    local noclip = RunService.Stepped:Connect(function()
        if char then
            for _, p in pairs(char:GetDescendants()) do
                if p:IsA("BasePart") then p.CanCollide = false end
            end
        end
    end)
    
    hum:ChangeState(Enum.HumanoidStateType.Physics)
    
    local speed = 25 
    local timeout = 0
    local maxTime = (distance / speed) + 10 
    
    while char and root and (root.Position - finalTarget).Magnitude > 8 and timeout < maxTime do
        local direction = (finalTarget - root.Position).Unit
        bv.Velocity = direction * speed
        task.wait(0.1)
        timeout = timeout + 0.1
    end
    
    if bv then bv:Destroy() end
    if noclip then noclip:Disconnect() end
    
    root.Velocity = Vector3.zero
    hum:ChangeState(Enum.HumanoidStateType.GettingUp)
    task.wait(0.3)
    
    return (root.Position - finalTarget).Magnitude <= 15
end

-- ==========================================
-- PEMBUATAN GUI MINIMALIST
-- ==========================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "FarmGUI_Minimalist"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = game:GetService("CoreGui")

local MainFrame = Instance.new("Frame")
MainFrame.Name = "Main"
MainFrame.Parent = ScreenGui
MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
MainFrame.Position = UDim2.new(0.5, -140, 0.2, 0)
MainFrame.Size = UDim2.new(0, 280, 0, 0)
MainFrame.AutomaticSize = Enum.AutomaticSize.Y
MainFrame.Active = true
MainFrame.Draggable = true
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 10)

local UIListLayout = Instance.new("UIListLayout", MainFrame)
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
UIListLayout.Padding = UDim.new(0, 8)
UIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

local UIPadding = Instance.new("UIPadding", MainFrame)
UIPadding.PaddingTop = UDim.new(0, 10)
UIPadding.PaddingBottom = UDim.new(0, 10)

local function createButton(text, color, parent)
    local btn = Instance.new("TextButton")
    btn.Parent = parent
    btn.Size = UDim2.new(0.9, 0, 0, 40)
    btn.BackgroundColor3 = color
    btn.Font = Enum.Font.GothamSemibold
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextSize = 14
    btn.AutoButtonColor = true
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    return btn
end

local Title = Instance.new("TextLabel")
Title.Parent = MainFrame
Title.BackgroundTransparency = 1
Title.Size = UDim2.new(1, 0, 0, 30)
Title.Font = Enum.Font.GothamBold
Title.Text = "WISNU AUTO SS SWC"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 18

local function createDropdown(placeholder)
    local DropdownBtn = createButton(placeholder, Color3.fromRGB(50, 50, 50), MainFrame)
    local ScrollFrame = Instance.new("ScrollingFrame")
    ScrollFrame.Parent = MainFrame
    ScrollFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    ScrollFrame.Size = UDim2.new(0.9, 0, 0, 120)
    ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    ScrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    ScrollFrame.ScrollBarThickness = 4
    ScrollFrame.Visible = false
    Instance.new("UICorner", ScrollFrame).CornerRadius = UDim.new(0, 6)
    
    local ScrollLayout = Instance.new("UIListLayout", ScrollFrame)
    ScrollLayout.SortOrder = Enum.SortOrder.LayoutOrder
    
    DropdownBtn.MouseButton1Click:Connect(function()
        ScrollFrame.Visible = not ScrollFrame.Visible
    end)
    return DropdownBtn, ScrollFrame
end

local PlotDropdown, PlotScroll = createDropdown(selectedOwner or "Pilih Plot (Owner)")
local PlantDropdown, PlantScroll = createDropdown(selectedSeed or "Pilih Pohon/Seed")

local RollbackBtn = createButton(
    rollbackActive and "Rollback: ON" or "Rollback: OFF", 
    rollbackActive and Color3.fromRGB(251, 197, 49) or Color3.fromRGB(70, 70, 70), 
    MainFrame
)

local LimitInput = Instance.new("TextBox")
LimitInput.Parent = MainFrame
LimitInput.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
LimitInput.Size = UDim2.new(0.9, 0, 0, 35)
LimitInput.Font = Enum.Font.Gotham
LimitInput.Text = tostring(waterLimit)
LimitInput.TextColor3 = Color3.fromRGB(255, 255, 255)
LimitInput.TextSize = 14
Instance.new("UICorner", LimitInput).CornerRadius = UDim.new(0, 6)

local AutoRejoinBtn = createButton(autoRejoinActive and "Auto Rejoin: ON" or "Auto Rejoin: OFF", autoRejoinActive and Color3.fromRGB(76, 209, 55) or Color3.fromRGB(70, 70, 70), MainFrame)

local SaveConfigBtn = createButton("Save Config Manual", Color3.fromRGB(0, 150, 136), MainFrame)
local AutoFarmBtn = createButton("Auto Farm: OFF (0)", Color3.fromRGB(232, 65, 24), MainFrame)

local StatusText = Instance.new("TextLabel")
StatusText.Parent = MainFrame
StatusText.BackgroundTransparency = 1
StatusText.Size = UDim2.new(1, 0, 0, 20)
StatusText.Font = Enum.Font.Gotham
StatusText.Text = "Status: Siap!"
StatusText.TextColor3 = Color3.fromRGB(150, 150, 150)
StatusText.TextSize = 12

-- ==========================================
-- LOGIKA DROPDOWN DINAMIS & AUTO LOCATE
-- ==========================================
local function locateTargetPlant()
    if not selectedOwner or not selectedSeed then return false end
    
    -- Mencoba mencari sebanyak 5 kali dengan jeda 2 detik
    for i = 1, 5 do
        local plot = getPlotByOwner(selectedOwner)
        if plot then
            local plantsFolder = plot:FindFirstChild("Plants")
            if plantsFolder then
                for _, plant in pairs(plantsFolder:GetChildren()) do
                    if plant:GetAttribute("SeedName") == selectedSeed then
                        local root = plant:FindFirstChild("HumanoidRootPart") or plant:FindFirstChildWhichIsA("BasePart")
                        if root then
                            savedPlantCFrame = root.CFrame
                            return true
                        end
                    end
                end
            end
        end
        StatusText.Text = "Status: Mencari pohon (Percobaan " .. i .. "/5)..."
        task.wait(2)
    end
    return false
end

local function updatePlantList()
    for _, child in pairs(PlantScroll:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end
    selectedSeed, savedPlantCFrame = nil, nil
    PlantDropdown.Text = "Pilih Pohon/Seed"

    local plot = getPlotByOwner(selectedOwner)
    if not plot then return end
    
    local plantsFolder = plot:FindFirstChild("Plants")
    if not plantsFolder then return end

    local seenSeeds = {} 
    for _, plant in pairs(plantsFolder:GetChildren()) do
        local seedName = plant:GetAttribute("SeedName")
        local root = plant:FindFirstChild("HumanoidRootPart") or plant:FindFirstChildWhichIsA("BasePart")

        if seedName and root and not seenSeeds[seedName] then
            seenSeeds[seedName] = true
            local btn = Instance.new("TextButton")
            btn.Parent = PlantScroll
            btn.Size = UDim2.new(1, 0, 0, 30)
            btn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
            btn.TextColor3 = Color3.fromRGB(255, 255, 255)
            btn.Font = Enum.Font.Gotham
            btn.Text = seedName
            btn.TextSize = 14
            
            btn.MouseButton1Click:Connect(function()
                selectedSeed = seedName
                PlantDropdown.Text = seedName
                PlantScroll.Visible = false
                savedPlantCFrame = root.CFrame 
            end)
        end
    end
end

local function updatePlotList()
    for _, child in pairs(PlotScroll:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end
    local gardens = Workspace:FindFirstChild("Gardens")
    if not gardens then return end

    for _, plot in pairs(gardens:GetChildren()) do
        local ownerAttr = plot:GetAttribute("Owner") or (plot:FindFirstChild("Owner") and plot.Owner.Value)
        if ownerAttr then
            local btn = Instance.new("TextButton")
            btn.Parent = PlotScroll
            btn.Size = UDim2.new(1, 0, 0, 30)
            btn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
            btn.TextColor3 = Color3.fromRGB(255, 255, 255)
            btn.Font = Enum.Font.Gotham
            btn.Text = ownerAttr
            btn.TextSize = 14
            
            btn.MouseButton1Click:Connect(function()
                selectedOwner = ownerAttr
                PlotDropdown.Text = ownerAttr
                PlotScroll.Visible = false
                updatePlantList()
            end)
        end
    end
end

PlotDropdown.MouseButton1Click:Connect(updatePlotList)

-- ==========================================
-- AKSI TOMBOL
-- ==========================================
RollbackBtn.MouseButton1Click:Connect(function()
    if rollbackActive then
        disableRollbackOnce()
        RollbackBtn.Text = "Rollback: OFF"
        RollbackBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
    else
        fireRollbackOnce()
        RollbackBtn.Text = "Rollback: ON"
        RollbackBtn.BackgroundColor3 = Color3.fromRGB(251, 197, 49)
    end
end)

LimitInput.FocusLost:Connect(function()
    local num = tonumber(LimitInput.Text)
    if num and num > 0 then
        waterLimit = num
    else
        LimitInput.Text = tostring(waterLimit)
    end
end)

AutoRejoinBtn.MouseButton1Click:Connect(function()
    autoRejoinActive = not autoRejoinActive
    if autoRejoinActive then
        AutoRejoinBtn.Text = "Auto Rejoin: ON"
        AutoRejoinBtn.BackgroundColor3 = Color3.fromRGB(76, 209, 55)
    else
        AutoRejoinBtn.Text = "Auto Rejoin: OFF"
        AutoRejoinBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
    end
end)

SaveConfigBtn.MouseButton1Click:Connect(function()
    if writefile then
        local data = {
            Owner = selectedOwner or "",
            Seed = selectedSeed or "",
            Limit = waterLimit,
            Rejoin = autoRejoinActive,
            Rollback = rollbackActive
        }
        local success, err = pcall(function()
            writefile(configFileName, HttpService:JSONEncode(data))
        end)
        
        if success then
            SaveConfigBtn.Text = "Config Saved!"
            SaveConfigBtn.BackgroundColor3 = Color3.fromRGB(76, 209, 55)
        else
            SaveConfigBtn.Text = "Error Saving!"
            SaveConfigBtn.BackgroundColor3 = Color3.fromRGB(232, 65, 24)
        end
    else
        SaveConfigBtn.Text = "Executor Not Supported!"
        SaveConfigBtn.BackgroundColor3 = Color3.fromRGB(232, 65, 24)
    end
    task.wait(1.5)
    SaveConfigBtn.Text = "Save Config Manual"
    SaveConfigBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 136)
end)

-- Main Trigger Auto Farm
local function ToggleAutoFarm()
    if not selectedOwner or not selectedSeed or not savedPlantCFrame then 
        StatusText.Text = "Status: Target belum lengkap!"
        return 
    end

    autoWatering = not autoWatering
    if autoWatering then
        AutoFarmBtn.Text = "Auto Farm: ON ("..waterCount..")"
        AutoFarmBtn.BackgroundColor3 = Color3.fromRGB(76, 209, 55)
        StatusText.Text = "Status: Memulai siklus..."
        
        destroyAllPlantsEverywhere() 

        task.spawn(function()
            local lastWaterTime = 0
            local lastCleanupTime = os.clock() -- Tambahkan variabel timer ini

            while autoWatering do
                -- Logic Destroy setiap 10 detik
                if os.clock() - lastCleanupTime >= 10 then
                    destroyAllPlantsEverywhere()
                    lastCleanupTime = os.clock() -- Reset timer
                end

                local currentPlot = getPlotByOwner(selectedOwner)
                if currentPlot then
                    
                    -- ===============================================
                    -- KALKULASI POSISI AMAN (PLANTAREA DETECTION)
                    -- ===============================================
                    local plantPos = savedPlantCFrame.Position
                    local pullCenter = currentPlot:GetPivot().Position
                    
                    -- Cari Area Kebun (PlantAreaColumn) yang paling dekat dengan pohon
                    local visual = currentPlot:FindFirstChild("Visual")
                    if visual then
                        local closestArea = nil
                        local minDist = math.huge
                        for _, obj in pairs(visual:GetChildren()) do
                            if obj:IsA("BasePart") and string.find(obj.Name, "PlantArea") then
                                local dist = (Vector3.new(obj.Position.X, 0, obj.Position.Z) - Vector3.new(plantPos.X, 0, plantPos.Z)).Magnitude
                                if dist < minDist then
                                    minDist = dist
                                    closestArea = obj
                                end
                            end
                        end
                        if closestArea then
                            -- Titik pusat penarikan sekarang adalah TEPAT di tengah area bertanah
                            pullCenter = closestArea.Position
                        end
                    end
                    
                    local dirXZ = Vector3.new(pullCenter.X - plantPos.X, 0, pullCenter.Z - plantPos.Z)
                    local pullDistance = 3.5
                    
                    if dirXZ.Magnitude > 0 then 
                        if dirXZ.Magnitude < pullDistance then pullDistance = dirXZ.Magnitude end
                        dirXZ = dirXZ.Unit 
                    else 
                        dirXZ = Vector3.new(0,0,1) 
                        pullDistance = 0
                    end
                    
                    -- Titik taruh Sprinkler ditarik mendekati tengah PlantArea agar tidak mepet pagar
                    local safeSprinklerPos = plantPos + (dirXZ * pullDistance)
                    safeSprinklerPos = Vector3.new(safeSprinklerPos.X, plantPos.Y, safeSprinklerPos.Z)
                    
                    local safePlayerPos = plantPos + (dirXZ * 5)
                    -- ===============================================
                    
                    -- 1. CEK SPRINKLER
                    if not isSprinklerActive(currentPlot) then
                        StatusText.Text = "Status: Terbang (Sprinkler)..."
                        if flyToTarget(safePlayerPos) then
                            StatusText.Text = "Status: Placing Sprinkler..."
                            local sprinklerTool = equipTool("Super Sprinkler")
                            if sprinklerTool then
                                -- MENGGUNAKAN PLOT ID DINAMIS & POSISI AMAN
                                local plotId = getPlotId(currentPlot)
                                local sprBuf = createSprinklerBuffer(safeSprinklerPos, plotId)
                                RemoteEvent:FireServer(sprBuf, {sprinklerTool})
                                task.wait(1.5) 
                            end
                        end
                    end
                    
                    -- 2. PAKSA SIRAM SETIAP 5 DETIK
                    local now = os.clock()
                    if now - lastWaterTime >= 5 then
                        StatusText.Text = "Status: Menuju pohon siram..."
                        if flyToTarget(safePlayerPos) then
                            StatusText.Text = "Status: Menyiram..."
                            local waterTool = equipTool("Super Watering Can")
                            if waterTool then
                                local waterBuf = createWaterBuffer(plantPos)
                                RemoteEvent:FireServer(waterBuf, {waterTool})
                                
                                waterCount = waterCount + 1
                                AutoFarmBtn.Text = "Auto Farm: ON ("..waterCount..")"
                                lastWaterTime = os.clock()
                                
                                if autoRejoinActive and waterCount >= waterLimit then
                                    autoWatering = false
                                    StatusText.Text = "Status: Limit Rejoin Tercapai!"
                                    task.wait(1)
                                    TeleportService:Teleport(game.PlaceId, LocalPlayer)
                                    break
                                end
                            end
                        else
                            StatusText.Text = "Status: Gagal sampai ke pohon!"
                        end
                    end
                end
                task.wait(0.5) 
            end
        end)
    else
        AutoFarmBtn.Text = "Auto Farm: OFF ("..waterCount..")"
        AutoFarmBtn.BackgroundColor3 = Color3.fromRGB(232, 65, 24)
        StatusText.Text = "Status: Farming dihentikan."
    end
end

AutoFarmBtn.MouseButton1Click:Connect(ToggleAutoFarm)

-- ==========================================
-- AUTO-START EXECUTION (SETELAH REJOIN/LOAD)
-- ==========================================
task.spawn(function()
    StatusText.Text = "Status: Loading..."
    
    -- Tunggu hingga LocalPlayer benar-benar memiliki Character
    if not LocalPlayer.Character then
        LocalPlayer.CharacterAdded:Wait()
    end
    
    -- Jeda aman untuk memastikan semua folder di Workspace ter-load
    task.wait(8) 
    
    updatePlotList()
    
    if rollbackActive then
        fireRollbackOnce()
    end
    
    -- Logika pencarian pohon dengan retry yang sudah teruji
    for i = 1, 5 do
        if locateTargetPlant() then
            StatusText.Text = "Status: Pohon ditemukan! Auto-Start..."
            task.wait(1)
            ToggleAutoFarm()
            return -- Berhenti jika sudah berhasil
        else
            StatusText.Text = "Status: Mencari pohon (Percobaan " .. i .. "/5)..."
            task.wait(3)
        end
    end
    
    StatusText.Text = "Status: Gagal menemukan pohon."
end)
