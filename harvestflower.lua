-- Grow a Garden 2 Auto Harvester & Seller (Simple GUI + Mutation Filter)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local Networking = require(ReplicatedStorage.SharedModules.Networking)
local FruitVisualizer = require(LocalPlayer.PlayerScripts.Controllers.FruitVisualizerController)

-- UI Setup
local uiParent = nil
local success, err = pcall(function() uiParent = game:GetService("CoreGui") end)
if not success or not uiParent then uiParent = LocalPlayer:WaitForChild("PlayerGui") end

if uiParent:FindFirstChild("GardenHarvesterSellerUI") then
    uiParent.GardenHarvesterSellerUI:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "GardenHarvesterSellerUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = uiParent

-- ==========================================
-- SIMPLE UI DESIGN 
-- ==========================================
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 260, 0, 330) -- Sedikit diperpanjang untuk menu mutasi
MainFrame.Position = UDim2.new(0.1, 0, 0.2, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 24, 30)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 8)
UICorner.Parent = MainFrame

local UIStroke = Instance.new("UIStroke")
UIStroke.Color = Color3.fromRGB(40, 50, 65)
UIStroke.Thickness = 2
UIStroke.Parent = MainFrame

-- Dragging Logic
local dragging, dragInput, dragStart, startPosition
MainFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true; dragStart = input.Position; startPosition = MainFrame.Position
        input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
    end
end)
MainFrame.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end
end)
UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(startPosition.X.Scale, startPosition.X.Offset + delta.X, startPosition.Y.Scale, startPosition.Y.Offset + delta.Y)
    end
end)

local UIListLayout = Instance.new("UIListLayout")
UIListLayout.Padding = UDim.new(0, 6)
UIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
UIListLayout.Parent = MainFrame

-- Title & Close
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 35)
Header.BackgroundTransparency = 1
Header.Parent = MainFrame

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -40, 1, 0)
TitleLabel.Position = UDim2.new(0, 10, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "FLOWER GARDERNER"
TitleLabel.TextColor3 = Color3.fromRGB(16, 185, 129)
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 14
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = Header

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 25, 0, 25)
CloseBtn.Position = UDim2.new(1, -30, 0, 5)
CloseBtn.BackgroundColor3 = Color3.fromRGB(239, 68, 68)
CloseBtn.TextColor3 = Color3.fromRGB(255,255,255)
CloseBtn.Text = "X"
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.Parent = Header
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 5)
CloseBtn.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)

local function makeHoverable(btn, hoverBg, origBg, hoverStroke, origStroke)
    btn.MouseEnter:Connect(function()
        btn.BackgroundColor3 = hoverBg
        if hoverStroke and btn:FindFirstChildOfClass("UIStroke") then btn:FindFirstChildOfClass("UIStroke").Color = hoverStroke end
    end)
    btn.MouseLeave:Connect(function()
        btn.BackgroundColor3 = origBg
        if origStroke and btn:FindFirstChildOfClass("UIStroke") then btn:FindFirstChildOfClass("UIStroke").Color = origStroke end
    end)
end

local function createRow(labelText, btnText)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(0.9, 0, 0, 25)
    row.BackgroundTransparency = 1
    row.Parent = MainFrame
    
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.6, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = Color3.fromRGB(226, 232, 240)
    lbl.Text = labelText
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextSize = 12
    lbl.Parent = row
    
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.4, 0, 1, 0)
    btn.Position = UDim2.new(0.6, 0, 0, 0)
    btn.BackgroundColor3 = Color3.fromRGB(55, 65, 81)
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Text = btnText
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11
    btn.Parent = row
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
    
    local stroke = Instance.new("UIStroke", btn)
    stroke.Color = Color3.fromRGB(75, 85, 99)
    return btn, stroke, row
end

-- Creating UI Elements
local HarvestToggleBtn, HarvestToggleStroke = createRow("Auto Harvest", "OFF")
local CycleBtn, CycleStroke = createRow("Harvest Mode", "Any")
makeHoverable(CycleBtn, Color3.fromRGB(45, 55, 72), Color3.fromRGB(31, 41, 55), Color3.fromRGB(75, 85, 99), Color3.fromRGB(55, 65, 81))

-- Threshold TextBox
local ThresholdRow = Instance.new("Frame")
ThresholdRow.Size = UDim2.new(0.9, 0, 0, 25)
ThresholdRow.BackgroundTransparency = 1
ThresholdRow.Parent = MainFrame
local tLbl = Instance.new("TextLabel", ThresholdRow)
tLbl.Size = UDim2.new(0.6, 0, 1, 0)
tLbl.BackgroundTransparency = 1
tLbl.TextColor3 = Color3.fromRGB(226, 232, 240)
tLbl.Text = "Threshold (kg)"
tLbl.TextXAlignment = Enum.TextXAlignment.Left
tLbl.Font = Enum.Font.GothamMedium
tLbl.TextSize = 12
local ThresholdInput = Instance.new("TextBox", ThresholdRow)
ThresholdInput.Size = UDim2.new(0.4, 0, 1, 0)
ThresholdInput.Position = UDim2.new(0.6, 0, 0, 0)
ThresholdInput.BackgroundColor3 = Color3.fromRGB(31, 41, 55)
ThresholdInput.TextColor3 = Color3.fromRGB(255,255,255)
ThresholdInput.Text = "0.0"
ThresholdInput.Font = Enum.Font.GothamMedium
ThresholdInput.TextSize = 12
Instance.new("UICorner", ThresholdInput).CornerRadius = UDim.new(0, 4)
Instance.new("UIStroke", ThresholdInput).Color = Color3.fromRGB(55, 65, 81)

-- Mutation Filter TextBox (FITUR BARU)
local MutRow = Instance.new("Frame")
MutRow.Size = UDim2.new(0.9, 0, 0, 25)
MutRow.BackgroundTransparency = 1
MutRow.Parent = MainFrame
local mLbl = Instance.new("TextLabel", MutRow)
mLbl.Size = UDim2.new(0.55, 0, 1, 0)
mLbl.BackgroundTransparency = 1
mLbl.TextColor3 = Color3.fromRGB(226, 232, 240)
mLbl.Text = "Mutasi Target"
mLbl.TextXAlignment = Enum.TextXAlignment.Left
mLbl.Font = Enum.Font.GothamMedium
mLbl.TextSize = 12
local MutInput = Instance.new("TextBox", MutRow)
MutInput.Size = UDim2.new(0.45, 0, 1, 0)
MutInput.Position = UDim2.new(0.55, 0, 0, 0)
MutInput.BackgroundColor3 = Color3.fromRGB(31, 41, 55)
MutInput.TextColor3 = Color3.fromRGB(245, 158, 11) -- Warna emas biar kelihatan beda
MutInput.Text = "Any"
MutInput.Font = Enum.Font.GothamMedium
MutInput.TextSize = 12
Instance.new("UICorner", MutInput).CornerRadius = UDim.new(0, 4)
Instance.new("UIStroke", MutInput).Color = Color3.fromRGB(55, 65, 81)

local SellToggleBtn, SellToggleStroke = createRow("Auto Sell (All)", "OFF")
local HideToggleBtn, HideToggleStroke = createRow("Hide Plants", "OFF")

-- Stats Labels
local Divider = Instance.new("Frame")
Divider.Size = UDim2.new(0.9, 0, 0, 1)
Divider.BackgroundColor3 = Color3.fromRGB(75, 85, 99)
Divider.BorderSizePixel = 0
Divider.Parent = MainFrame

local ShecklesLabel = Instance.new("TextLabel")
ShecklesLabel.Size = UDim2.new(0.9, 0, 0, 15)
ShecklesLabel.BackgroundTransparency = 1
ShecklesLabel.TextColor3 = Color3.fromRGB(99, 102, 241)
ShecklesLabel.Text = "Sheckles: Loading..."
ShecklesLabel.TextXAlignment = Enum.TextXAlignment.Left
ShecklesLabel.Font = Enum.Font.GothamBold
ShecklesLabel.TextSize = 12
ShecklesLabel.Parent = MainFrame

local BackpackLabel = Instance.new("TextLabel")
BackpackLabel.Size = UDim2.new(0.9, 0, 0, 15)
BackpackLabel.BackgroundTransparency = 1
BackpackLabel.TextColor3 = Color3.fromRGB(226, 232, 240)
BackpackLabel.Text = "Backpack Fruits: 0/100"
BackpackLabel.TextXAlignment = Enum.TextXAlignment.Left
BackpackLabel.Font = Enum.Font.GothamSemibold
BackpackLabel.TextSize = 12
BackpackLabel.Parent = MainFrame

-- ==========================================
-- LOGIKA UTAMA & SISTEM MUTASI
-- ==========================================

local autoHarvestEnabled = false
local autoHarvestMode = "Any"
local autoHarvestThreshold = 0.0
local autoHarvestMutation = "Any" -- Variabel Filter Mutasi
local autoSellEnabled = false
local plantsHidden = false

local originalTransparencies = setmetatable({}, {__mode = "k"})
local recentlyHarvested = setmetatable({}, {__mode = "k"})

local utilityTools = {
    ["Basic Pot"] = true, ["Watering Can"] = true, ["Trowel"] = true,
    ["Super Trowel"] = true, ["Golden Trowel"] = true, ["Infinite Watering Can"] = true,
    ["Seed Bag"] = true,
}

local function isSellableFruit(item)
    if not item:IsA("Tool") then return false end
    local name = item.Name
    if utilityTools[name] then return false end
    if name:find("Pot") or name:find("Can") or name:find("Trowel") or name:find("Bag") then return false end
    if name:find("Fertilizer") or name:find("Axe") or name:find("Pickaxe") or name:find("Shovel") then return false end
    return true
end

local function getMyPlot()
    for _, plot in ipairs(workspace.Gardens:GetChildren()) do
        if plot:GetAttribute("Owner") == LocalPlayer.Name or plot:GetAttribute("OwnerUserId") == LocalPlayer.UserId then
            return plot
        end
    end
    return nil
end

local modes = {"Any Weight", "Above Threshold", "Below Threshold"}
local currentModeIndex = 1

CycleBtn.MouseButton1Click:Connect(function()
    currentModeIndex = currentModeIndex % #modes + 1
    local mName = modes[currentModeIndex]
    autoHarvestMode = mName:split(" ")[1]
    CycleBtn.Text = mName
end)

HarvestToggleBtn.MouseButton1Click:Connect(function()
    autoHarvestEnabled = not autoHarvestEnabled
    if autoHarvestEnabled then
        HarvestToggleBtn.BackgroundColor3 = Color3.fromRGB(16, 185, 129)
        HarvestToggleBtn.Text = "ON"
    else
        HarvestToggleBtn.BackgroundColor3 = Color3.fromRGB(55, 65, 81)
        HarvestToggleBtn.Text = "OFF"
    end
end)

SellToggleBtn.MouseButton1Click:Connect(function()
    autoSellEnabled = not autoSellEnabled
    if autoSellEnabled then
        SellToggleBtn.BackgroundColor3 = Color3.fromRGB(245, 158, 11)
        SellToggleBtn.Text = "ON"
    else
        SellToggleBtn.BackgroundColor3 = Color3.fromRGB(55, 65, 81)
        SellToggleBtn.Text = "OFF"
    end
end)

-- Hide Plants Logic
local removeLabels = false
local function hideDescendant(desc)
    if desc:IsA("BasePart") or desc:IsA("Decal") or desc:IsA("Texture") then
        if not originalTransparencies[desc] then originalTransparencies[desc] = desc.Transparency end
        desc.Transparency = 1
    elseif desc:IsA("BillboardGui") or desc:IsA("SurfaceGui") or desc:IsA("ParticleEmitter") then
        desc.Enabled = false
    end
end

local function restoreDescendant(desc)
    if desc:IsA("BasePart") or desc:IsA("Decal") or desc:IsA("Texture") then
        desc.Transparency = originalTransparencies[desc] or 0
    elseif desc:IsA("ParticleEmitter") then
        desc.Enabled = true
    elseif desc:IsA("BillboardGui") or desc:IsA("SurfaceGui") then
        desc.Enabled = not removeLabels
    end
end

local function updatePlantsVisibility()
    for _, plot in ipairs(workspace.Gardens:GetChildren()) do
        local plants = plot:FindFirstChild("Plants")
        if plants then
            for _, desc in ipairs(plants:GetDescendants()) do
                if plantsHidden then hideDescendant(desc) else restoreDescendant(desc) end
            end
        end
    end
end

HideToggleBtn.MouseButton1Click:Connect(function()
    plantsHidden = not plantsHidden
    if plantsHidden then
        removeLabels = true; HideToggleBtn.BackgroundColor3 = Color3.fromRGB(142, 68, 173); HideToggleBtn.Text = "HIDDEN"
    else
        removeLabels = true; HideToggleBtn.BackgroundColor3 = Color3.fromRGB(55, 65, 81); HideToggleBtn.Text = "VISIBLE"
    end
    updatePlantsVisibility()
end)

ThresholdInput:GetPropertyChangedSignal("Text"):Connect(function()
    local cleanText = ThresholdInput.Text:gsub("[^%d%.]", "")
    local num = tonumber(cleanText)
    autoHarvestThreshold = num and num or 0.0
end)

-- Menyimpan Filter Mutasi saat diketik
MutInput:GetPropertyChangedSignal("Text"):Connect(function()
    autoHarvestMutation = MutInput.Text
end)

task.spawn(function()
    while true do
        task.wait(1)
        if not ScreenGui.Parent then break end
        local shecklesVal = LocalPlayer:FindFirstChild("leaderstats") and LocalPlayer.leaderstats:FindFirstChild("Sheckles")
        ShecklesLabel.Text = shecklesVal and "Sheckles: " .. tostring(shecklesVal.Value):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "") or "Sheckles: N/A"
        
        local currentFruits = 0
        for _, item in ipairs(LocalPlayer.Backpack:GetChildren()) do if isSellableFruit(item) then currentFruits = currentFruits + 1 end end
        if LocalPlayer.Character then for _, item in ipairs(LocalPlayer.Character:GetChildren()) do if isSellableFruit(item) then currentFruits = currentFruits + 1 end end end
        BackpackLabel.Text = "Backpack Fruits: " .. tostring(currentFruits)
    end
end)

-- Auto Harvest Loop (Ditambah Sistem Pengecekan Mutasi)
task.spawn(function()
    while true do
        task.wait(0.01)
        if not ScreenGui.Parent then break end
        
        if autoHarvestEnabled then
            local Plot = getMyPlot()
            local Plants = Plot and Plot:FindFirstChild("Plants")
            if Plants then
                for _, plant in ipairs(Plants:GetChildren()) do
                    if not autoHarvestEnabled then break end
                    local fruitsFolder = plant:FindFirstChild("Fruits")
                    if fruitsFolder then
                        for _, fruitModel in ipairs(fruitsFolder:GetChildren()) do
                            local harvestPart = fruitModel:FindFirstChild("HarvestPart")
                            local prompt = harvestPart and harvestPart:FindFirstChild("HarvestPrompt")
                            
                            if prompt and prompt:IsA("ProximityPrompt") then
                                local lastHarvest = recentlyHarvested[prompt]
                                if not lastHarvest or (os.clock() - lastHarvest) > 2 then
                                    local weight = FruitVisualizer:CalculateFruitWeight(fruitModel) or 0
                                    
                                    -- 1. CEK SYARAT BERAT (WEIGHT)
                                    local shouldHarvest = false
                                    if autoHarvestMode == "Any" then shouldHarvest = true
                                    elseif autoHarvestMode == "Above" and weight >= autoHarvestThreshold then shouldHarvest = true
                                    elseif autoHarvestMode == "Below" and weight <= autoHarvestThreshold then shouldHarvest = true end
                                    
                                    -- 2. CEK SYARAT MUTASI (MUTATION)
                                    local passesMutation = false
                                    local targetMut = string.lower(autoHarvestMutation)
                                    
                                    if targetMut == "any" or targetMut == "" then
                                        passesMutation = true
                                    else
                                        local mutAttr = fruitModel:GetAttribute("Mutation")
                                        local mutStr = type(mutAttr) == "string" and string.lower(mutAttr) or "none"
                                        local fruitName = string.lower(fruitModel.Name)
                                        
                                        if targetMut == "none" then
                                            -- Jika minta buah biasa, pastikan tidak ada kata mutasi di attribut/namanya
                                            if mutStr == "none" and not string.find(fruitName, "bloodlite") and not string.find(fruitName, "lightning") and not string.find(fruitName, "radioactive") then
                                                passesMutation = true
                                            end
                                        else
                                            -- Jika nyari mutasi spesifik (misal ketik "bloodlite")
                                            if string.find(mutStr, targetMut) or string.find(fruitName, targetMut) then
                                                passesMutation = true
                                            end
                                        end
                                    end
                                    
                                    -- JIKA KEDUANYA SESUAI, BARU PANEN
                                    if shouldHarvest and passesMutation then
                                        recentlyHarvested[prompt] = os.clock()
                                        pcall(fireproximityprompt, prompt)
                                        task.wait(0.01) 
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end)

-- Auto Sell Loop
task.spawn(function()
    while true do
        task.wait(0,1)
        if not ScreenGui.Parent then break end
        
        if autoSellEnabled then
            local fruits = {}
            for _, item in ipairs(LocalPlayer.Backpack:GetChildren()) do if isSellableFruit(item) then table.insert(fruits, item) end end
            if LocalPlayer.Character then for _, item in ipairs(LocalPlayer.Character:GetChildren()) do if isSellableFruit(item) then table.insert(fruits, item) end end end
            
            if #fruits > 0 then
                pcall(function() Networking.NPCS.SellAll:Fire() end)
                task.wait(0.1)
                
                local stillHasFruits = false
                for _, item in ipairs(LocalPlayer.Backpack:GetChildren()) do if isSellableFruit(item) then stillHasFruits = true break end end
                
                if stillHasFruits then
                    for _, tool in ipairs(fruits) do
                        if not autoSellEnabled then break end
                        local id = tool:GetAttribute("Id")
                        if id and tool.Parent then
                            pcall(function() Networking.NPCS.SellFruit:Fire(id) end)
                            task.wait(0.1)
                        end
                    end
                end
            end
        end
    end
end)
