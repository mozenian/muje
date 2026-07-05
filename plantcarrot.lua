--[[
    Grow a Garden 2 - Sprinkler Planter Script
    Optimized v2: Faster, Accurate, Clean
]]

-- ===========================
-- SERVICES
-- ===========================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local VirtualInputManager = game:GetService("VirtualInputManager")

-- ===========================
-- PLAYER REFERENCES
-- ===========================
local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
local Humanoid = Character:WaitForChild("Humanoid")
local Backpack = LocalPlayer:WaitForChild("Backpack")

-- ===========================
-- CONFIGURATION
-- ===========================
local CONFIG = {
    SPACING = 1,              -- Jarak antar tanaman (studs)
    RADIUS = 25,              -- Radius sprinkler
    DELAY = 0,                -- Delay antar tanam (detik)
    BATCH_SIZE = 10,          -- Jumlah tanam sebelum jeda 1 frame
    TOOL_NAME = "Carrot",     -- Nama tool
}

local GUI_NAME = "SprinklerPlanterV2"

-- ===========================
-- COLORS (Spotify Theme)
-- ===========================
local Colors = {
    BG_MAIN = Color3.fromRGB(18, 18, 18),
    BG_SECONDARY = Color3.fromRGB(24, 24, 24),
    BG_ELEVATED = Color3.fromRGB(40, 40, 40),
    ACCENT = Color3.fromRGB(29, 185, 84),
    TEXT_PRIMARY = Color3.fromRGB(255, 255, 255),
    TEXT_SECONDARY = Color3.fromRGB(179, 179, 179),
    ERROR = Color3.fromRGB(233, 20, 41),
    WARNING = Color3.fromRGB(255, 200, 0),
}

-- ===========================
-- STATE
-- ===========================
local isRunning = false
local isPaused = false
local totalPlanted = 0
local currentRadius = CONFIG.RADIUS
local currentSpacing = CONFIG.SPACING

-- ===========================
-- GET REMOTE
-- ===========================
local PlantRemote do
    local mod = ReplicatedStorage:WaitForChild("SharedModules", 5)
    if mod then
        mod = mod:WaitForChild("Packet", 5)
        if mod then
            mod = mod:WaitForChild("RemoteEvent", 5)
        end
    end
    PlantRemote = mod
end

-- ===========================
-- UTILITY FUNCTIONS
-- ===========================
local function Log(msg, color)
    print("[Planter] " .. msg)
end

local function CreateBuffer(x, y, z)
    local name = CONFIG.TOOL_NAME
    local header = string.char(10, 0)
    local coords = string.pack("<fff", x, y, z)
    local nameLen = string.char(#name)
    return buffer.fromstring(header .. coords .. nameLen .. name)
end

local function GetCarrotTool()
    -- Cek di character
    local tool = Character:FindFirstChild(CONFIG.TOOL_NAME)

    -- Cek di backpack
    if not tool and Backpack then
        tool = Backpack:FindFirstChild(CONFIG.TOOL_NAME)
        if tool then
            Humanoid:EquipTool(tool)
            task.wait(0.03)
            tool = Character:FindFirstChild(CONFIG.TOOL_NAME)
        end
    end

    return tool
end

local function PlantAt(position)
    local tool = GetCarrotTool()
    if not tool then
        return false, "Tool not found"
    end

    local buffer = CreateBuffer(position.X, position.Y, position.Z)
    PlantRemote:FireServer(buffer, {tool})
    return true
end

local function GetGroundY(position, excludeList)
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = excludeList or {Character}
    params.FilterType = Enum.RaycastFilterType.Exclude

    local result = workspace:Raycast(position + Vector3.new(0, 50, 0), Vector3.new(0, -100, 0), params)
    return result and result.Position.Y or position.Y - 2.5
end

-- ===========================
-- FIND SPRINKLER
-- ===========================
local function FindSprinkler()
    local gardens = workspace:FindFirstChild("Gardens")
    if not gardens then
        Log("Gardens folder not found!", Colors.ERROR)
        return nil
    end

    local playerPos = HumanoidRootPart.Position
    local closest = nil
    local closestDist = math.huge

    for _, plot in ipairs(gardens:GetChildren()) do
        local sprinklers = plot:FindFirstChild("Sprinklers")
        if not sprinklers then continue end

        for _, sprinkler in ipairs(sprinklers:GetChildren()) do
            if not (sprinkler:IsA("Model") or sprinkler:IsA("BasePart")) then continue end

            local pos = sprinkler:GetPivot().Position
            local dist = (pos - playerPos).Magnitude

            if dist < closestDist then
                closestDist = dist
                closest = {sprinkler = sprinkler, position = pos}
            end
        end
    end

    if closest then
        Log("Found sprinkler at distance: " .. math.floor(closestDist), Colors.ACCENT)
    end

    return closest
end

-- ===========================
-- GENERATE PLANTING GRID
-- ===========================
local function GenerateGrid(centerPos, radius, spacing)
    local points = {}
    local halfSpacing = spacing / 2

    -- Hitung jumlah langkah dari center ke edge
    local steps = math.floor(radius / spacing) + 1

    for row = -steps, steps do
        local z = centerPos.Z + (row * spacing)
        local rowDist = math.abs(row * spacing)

        -- Checkerboard pattern untuk packing lebih rapat
        local colStart = (row % 2 == 0) and -steps or (steps > 0 and -steps + 1 or 0)
        local colEnd = (row % 2 == 0) and steps or (steps > 0 and steps - 1 or 0)
        local colStep = (row % 2 == 0) and 1 or -1

        for col = colStart, colEnd, colStep do
            local x = centerPos.X + (col * spacing)
            local distFromCenter = math.sqrt((x - centerPos.X)^2 + (z - centerPos.Z)^2)

            if distFromCenter <= radius then
                table.insert(points, Vector3.new(x, centerPos.Y, z))
            end
        end
    end

    -- Sort: yang terdekat dulu (lebih natural)
    table.sort(points, function(a, b)
        local distA = (a - centerPos).Magnitude
        local distB = (b - centerPos).Magnitude
        return distA < distB
    end)

    return points
end

-- ===========================
-- GUI CREATION
-- ===========================
local function CreateGUI()
    -- Cleanup existing
    local playerGui = LocalPlayer:WaitForChild("PlayerGui")
    if playerGui:FindFirstChild(GUI_NAME) then
        playerGui[GUI_NAME]:Destroy()
    end

    -- Main ScreenGui
    local gui = Instance.new("ScreenGui")
    gui.Name = GUI_NAME
    gui.ResetOnSpawn = false
    gui.Parent = playerGui

    -- Main Frame
    local main = Instance.new("Frame")
    main.Name = "MainFrame"
    main.Size = UDim2.new(0, 300, 0, 320)
    main.Position = UDim2.new(0.5, -150, 0.5, -160)
    main.BackgroundColor3 = Colors.BG_MAIN
    main.BorderSizePixel = 0
    main.Active = true
    main.Draggable = true
    main.Parent = gui
    Instance.new("UICorner", main).CornerRadius = UDim.new(0, 12)

    -- Header
    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 45)
    header.BackgroundColor3 = Colors.BG_SECONDARY
    header.BorderSizePixel = 0
    header.Parent = main
    Instance.new("UICorner", header).CornerRadius = UDim.new(0, 12)

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, -50, 1, 0)
    title.Position = UDim2.new(0, 15, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "🌱 Sprinkler Planter v2"
    title.TextColor3 = Colors.TEXT_PRIMARY
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = header

    local closeBtn = Instance.new("TextButton")
    closeBtn.Name = "CloseBtn"
    closeBtn.Size = UDim2.new(0, 40, 0, 40)
    closeBtn.Position = UDim2.new(1, -40, 0, 0)
    closeBtn.BackgroundTransparency = 1
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Colors.TEXT_SECONDARY
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 16
    closeBtn.Parent = header
    closeBtn.MouseButton1Click:Connect(function() gui:Destroy() end)
    closeBtn.MouseEnter:Connect(function() closeBtn.TextColor3 = Colors.ERROR end)
    closeBtn.MouseLeave:Connect(function() closeBtn.TextColor3 = Colors.TEXT_SECONDARY end)

    -- Stats Frame
    local stats = Instance.new("Frame")
    stats.Name = "Stats"
    stats.Size = UDim2.new(1, -20, 0, 50)
    stats.Position = UDim2.new(0, 10, 0, 55)
    stats.BackgroundColor3 = Colors.BG_SECONDARY
    stats.BorderSizePixel = 0
    stats.Parent = main
    Instance.new("UICorner", stats).CornerRadius = UDim.new(0, 8)

    local statsLayout = Instance.new("UIListLayout")
    statsLayout.FillDirection = Enum.FillDirection.Horizontal
    statsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    statsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    statsLayout.Padding = UDim.new(0, 20)
    statsLayout.Parent = stats

    local plantedLabel = Instance.new("TextLabel")
    plantedLabel.Name = "PlantedLabel"
    plantedLabel.Size = UDim2.new(0, 100, 1, 0)
    plantedLabel.BackgroundTransparency = 1
    plantedLabel.Text = "0 planted"
    plantedLabel.TextColor3 = Colors.ACCENT
    plantedLabel.Font = Enum.Font.GothamBold
    plantedLabel.TextSize = 14
    plantedLabel.Parent = stats

    local pointsLabel = Instance.new("TextLabel")
    pointsLabel.Name = "PointsLabel"
    pointsLabel.Size = UDim2.new(0, 80, 1, 0)
    pointsLabel.BackgroundTransparency = 1
    pointsLabel.Text = "0 pts"
    pointsLabel.TextColor3 = Colors.WARNING
    pointsLabel.Font = Enum.Font.GothamBold
    pointsLabel.TextSize = 14
    pointsLabel.Parent = stats

    -- Input Section
    local function CreateInput(label, default, y)
        local container = Instance.new("Frame")
        container.Name = label
        container.Size = UDim2.new(1, -20, 0, 40)
        container.Position = UDim2.new(0, 10, 0, y)
        container.BackgroundTransparency = 1
        container.Parent = main

        local lbl = Instance.new("TextLabel")
        lbl.Name = "Label"
        lbl.Size = UDim2.new(1, 0, 0, 16)
        lbl.BackgroundTransparency = 1
        lbl.Text = label
        lbl.TextColor3 = Colors.TEXT_SECONDARY
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 11
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = container

        local box = Instance.new("TextBox")
        box.Name = "Input"
        box.Size = UDim2.new(0, 80, 0, 24)
        box.Position = UDim2.new(1, -80, 0, 0)
        box.BackgroundColor3 = Colors.BG_ELEVATED
        box.TextColor3 = Colors.TEXT_PRIMARY
        box.Text = tostring(default)
        box.Font = Enum.Font.GothamBold
        box.TextSize = 12
        box.Text = "1"
        box.Parent = container
        Instance.new("UICorner", box).CornerRadius = UDim.new(0, 4)

        return box
    end

    local spacingInput = CreateInput("Jarak Tanam", CONFIG.SPACING, 115)
    local radiusInput = CreateInput("Radius", CONFIG.RADIUS, 160)
    local delayInput = CreateInput("Delay", CONFIG.DELAY, 205)

    spacingInput.Text = tostring(CONFIG.SPACING)
    radiusInput.Text = tostring(CONFIG.RADIUS)
    delayInput.Text = tostring(CONFIG.DELAY)

    -- Toggle Button
    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Name = "ToggleBtn"
    toggleBtn.Size = UDim2.new(1, -20, 0, 45)
    toggleBtn.Position = UDim2.new(0, 10, 1, -55)
    toggleBtn.BackgroundColor3 = Colors.ACCENT
    toggleBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
    toggleBtn.Text = "▶ START"
    toggleBtn.Font = Enum.Font.GothamBlack
    toggleBtn.TextSize = 13
    toggleBtn.Parent = main
    Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 8)

    -- Status
    local status = Instance.new("TextLabel")
    status.Name = "Status"
    status.Size = UDim2.new(1, -20, 0, 20)
    status.Position = UDim2.new(0, 10, 0, 250)
    status.BackgroundTransparency = 1
    status.Text = "Ready - Press START"
    status.TextColor3 = Colors.TEXT_SECONDARY
    status.Font = Enum.Font.Gotham
    status.TextSize = 10
    status.TextXAlignment = Enum.TextXAlignment.Center
    status.Parent = main

    return {
        gui = gui,
        main = main,
        toggleBtn = toggleBtn,
        status = status,
        plantedLabel = plantedLabel,
        pointsLabel = pointsLabel,
        spacingInput = spacingInput,
        radiusInput = radiusInput,
        delayInput = delayInput,
    }
end

-- ===========================
-- MAIN LOGIC
-- ===========================
local UI = CreateGUI()

local function UpdateStatus(text, color)
    UI.status.Text = text
    UI.status.TextColor3 = color or Colors.TEXT_SECONDARY
end

local function UpdateStats(planted, points)
    UI.plantedLabel.Text = planted .. " planted"
    UI.pointsLabel.Text = points .. " pts"
end

local function UpdateToggleButton(running)
    if running then
        UI.toggleBtn.Text = "⏹ STOP"
        UI.toggleBtn.BackgroundColor3 = Colors.ERROR
        UI.toggleBtn.TextColor3 = Colors.TEXT_PRIMARY
    else
        UI.toggleBtn.Text = "▶ START"
        UI.toggleBtn.BackgroundColor3 = Colors.ACCENT
        UI.toggleBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
    end
end

local function StartPlanting()
    if isRunning then return end
    isRunning = true

    -- Get settings
    local spacing = tonumber(UI.spacingInput.Text) or CONFIG.SPACING
    local radius = tonumber(UI.radiusInput.Text) or CONFIG.RADIUS
    local delay = tonumber(UI.delayInput.Text) or CONFIG.DELAY

    UpdateToggleButton(true)
    UpdateStatus("Finding sprinkler...", Colors.ACCENT)

    -- Find sprinkler
    local sprinklerData = FindSprinkler()
    if not sprinklerData then
        UpdateStatus("Sprinkler not found!", Colors.ERROR)
        isRunning = false
        UpdateToggleButton(false)
        return
    end

    -- Get ground level
    local centerPos = sprinklerData.position
    local groundY = GetGroundY(centerPos, {Character, sprinklerData.sprinkler})
    centerPos = Vector3.new(centerPos.X, groundY, centerPos.Z)

    -- Generate grid
    local gridPoints = GenerateGrid(centerPos, radius, spacing)
    Log("Generated " .. #gridPoints .. " planting points")

    if #gridPoints == 0 then
        UpdateStatus("No valid planting points!", Colors.ERROR)
        isRunning = false
        UpdateToggleButton(false)
        return
    end

    UpdateStatus("Planting " .. #gridPoints .. " points...", Colors.ACCENT)

    -- Planting loop
    task.spawn(function()
        local batchCount = 0
        local pointsGained = 0

        while isRunning do
            for i, pos in ipairs(gridPoints) do
                if not isRunning then break end

                -- Plant
                local success = PlantAt(pos)

                if success then
                    totalPlanted = totalPlanted + 1
                    batchCount = batchCount + 1
                    pointsGained = pointsGained + 1

                    -- Update UI periodically
                    if batchCount % 50 == 0 then
                        UpdateStats(totalPlanted, pointsGained)
                        UpdateStatus("Planting... " .. i .. "/" .. #gridPoints, Colors.ACCENT)
                    end

                    -- Batch system untuk menghindari lag
                    if delay <= 0 and batchCount % CONFIG.BATCH_SIZE == 0 then
                        RunService.Heartbeat:Wait()
                    elseif delay > 0 then
                        task.wait(delay)
                    end
                else
                    -- Skip failed points but continue
                    Log("Failed to plant at " .. i)
                end
            end

            -- Reset loop
            if isRunning then
                UpdateStatus("Round complete! Restarting...", Colors.WARNING)
                pointsGained = 0
                task.wait(0.1)
            end
        end

        -- Cleanup
        UpdateStatus("Stopped", Colors.TEXT_SECONDARY)
        UpdateToggleButton(false)
        isRunning = false
    end)
end

local function StopPlanting()
    if not isRunning then return end
    isRunning = false
    UpdateStatus("Stopping...", Colors.TEXT_SECONDARY)
end

-- ===========================
-- EVENT CONNECTIONS
-- ===========================
UI.toggleBtn.MouseButton1Click:Connect(function()
    if isRunning then
        StopPlanting()
    else
        StartPlanting()
    end
end)

-- ===========================
-- INIT
-- ===========================
Log("Sprinkler Planter v2 loaded!", Colors.ACCENT)
