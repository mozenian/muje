-- Grow a Garden 2 Auto Harvester & Seller by Antigravity (Optimized)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Networking = require(ReplicatedStorage.SharedModules.Networking)
local FruitVisualizer = require(LocalPlayer.PlayerScripts.Controllers.FruitVisualizerController)

-- UI Setup
local uiParent = game:GetService("CoreGui") or LocalPlayer:WaitForChild("PlayerGui")
if uiParent:FindFirstChild("GardenHarvesterSellerUI") then
	uiParent.GardenHarvesterSellerUI:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "GardenHarvesterSellerUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = uiParent

-- Main Window Frame
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 360, 0, 440)
MainFrame.Position = UDim2.new(0.1, 10, 0.15, 10)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 19, 26)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = false
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 12)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(36, 47, 65)
MainStroke.Thickness = 1.5
MainStroke.Parent = MainFrame

-- Drop Shadow
local DropShadow = Instance.new("ImageLabel")
DropShadow.Name = "DropShadow"
DropShadow.AnchorPoint = Vector2.new(0.5, 0.5)
DropShadow.Position = UDim2.new(0.5, 0, 0.5, 0)
DropShadow.Size = UDim2.new(1, 40, 1, 40)
DropShadow.BackgroundTransparency = 1
DropShadow.Image = "rbxassetid://6014261993"
DropShadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
DropShadow.ImageTransparency = 0.55
DropShadow.ScaleType = Enum.ScaleType.Slice
DropShadow.SliceCenter = Rect.new(49, 49, 450, 450)
DropShadow.ZIndex = 0
DropShadow.Parent = MainFrame

-- Fixed Dragging Logic (Only drag from Header)
local dragging = false
local dragStart, startPos

-- Header
local HeaderFrame = Instance.new("Frame")
HeaderFrame.Name = "HeaderFrame"
HeaderFrame.Size = UDim2.new(1, 0, 0, 48)
HeaderFrame.BackgroundColor3 = Color3.fromRGB(21, 27, 38)
HeaderFrame.BackgroundTransparency = 0
HeaderFrame.BorderSizePixel = 0
HeaderFrame.Parent = MainFrame

local HeaderCorner = Instance.new("UICorner")
HeaderCorner.CornerRadius = UDim.new(0, 12)
HeaderCorner.Parent = HeaderFrame

local HeaderCover = Instance.new("Frame")
HeaderCover.Name = "HeaderCover"
HeaderCover.Size = UDim2.new(1, 0, 0, 15)
HeaderCover.Position = UDim2.new(0, 0, 1, -15)
HeaderCover.BackgroundColor3 = Color3.fromRGB(21, 27, 38)
HeaderCover.BorderSizePixel = 0
HeaderCover.ZIndex = 0
HeaderCover.Parent = HeaderFrame

-- Title
local TitleLabel = Instance.new("TextLabel")
TitleLabel.Name = "TitleLabel"
TitleLabel.Size = UDim2.new(1, -100, 1, 0)
TitleLabel.Position = UDim2.new(0, 15, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "GARDEN HELPER MASTER"
TitleLabel.TextColor3 = Color3.fromRGB(241, 245, 249)
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 13
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = HeaderFrame

-- Minimize Button
local MinimizeBtn = Instance.new("TextButton")
MinimizeBtn.Name = "MinimizeBtn"
MinimizeBtn.Size = UDim2.new(0, 32, 0, 32)
MinimizeBtn.Position = UDim2.new(1, -80, 0.5, -16)
MinimizeBtn.BackgroundColor3 = Color3.fromRGB(31, 41, 55)
MinimizeBtn.Text = "-"
MinimizeBtn.TextColor3 = Color3.fromRGB(251, 191, 36)
MinimizeBtn.Font = Enum.Font.GothamBold
MinimizeBtn.TextSize = 18
MinimizeBtn.Parent = HeaderFrame

local MinimizeCorner = Instance.new("UICorner")
MinimizeCorner.CornerRadius = UDim.new(0, 8)
MinimizeCorner.Parent = MinimizeBtn

-- Close Button
local CloseBtn = Instance.new("TextButton")
CloseBtn.Name = "CloseBtn"
CloseBtn.Size = UDim2.new(0, 32, 0, 32)
CloseBtn.Position = UDim2.new(1, -40, 0.5, -16)
CloseBtn.BackgroundColor3 = Color3.fromRGB(31, 41, 55)
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(239, 68, 68)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 14
CloseBtn.Parent = HeaderFrame

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 8)
CloseCorner.Parent = CloseBtn

-- Header Drag Logic
HeaderFrame.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = MainFrame.Position
	end
end)

HeaderFrame.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = false
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		local delta = input.Position - dragStart
		MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
	end
end)

-- Minimize/Restore Logic
local isMinimized = false
local ContentFrame = nil

local function createContentFrame()
	ContentFrame = Instance.new("Frame")
	ContentFrame.Name = "ContentFrame"
	ContentFrame.Size = UDim2.new(1, -30, 1, -68)
	ContentFrame.Position = UDim2.new(0, 15, 0, 58)
	ContentFrame.BackgroundTransparency = 1
	ContentFrame.Parent = MainFrame

	local UIListLayout = Instance.new("UIListLayout")
	UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	UIListLayout.Padding = UDim.new(0, 10)
	UIListLayout.Parent = ContentFrame

	return ContentFrame
end

createContentFrame()

MinimizeBtn.MouseButton1Click:Connect(function()
	isMinimized = not isMinimized

	if isMinimized then
		if ContentFrame then
			ContentFrame.Visible = false
		end
		MainFrame.Size = UDim2.new(0, 360, 0, 48)
		MinimizeBtn.Text = "+"
		MinimizeBtn.TextColor3 = Color3.fromRGB(16, 185, 129)
	else
		if ContentFrame then
			ContentFrame.Visible = true
		end
		MainFrame.Size = UDim2.new(0, 360, 0, 440)
		MinimizeBtn.Text = "-"
		MinimizeBtn.TextColor3 = Color3.fromRGB(251, 191, 36)
	end
end)

CloseBtn.MouseButton1Click:Connect(function()
	ScreenGui:Destroy()
end)

ContentFrame = MainFrame:FindFirstChild("ContentFrame")

-- Config
local autoHarvestEnabled = false
local autoHarvestMode = "Any"
local autoHarvestThreshold = 0.0
local autoSellEnabled = false
local plantsHidden = false

local recentlyHarvested = setmetatable({}, {__mode = "k"})

local utilityTools = {
	["Basic Pot"] = true, ["Watering Can"] = true, ["Trowel"] = true,
	["Super Trowel"] = true, ["Golden Trowel"] = true,
	["Infinite Watering Can"] = true, ["Seed Bag"] = true,
}

local function isSellableFruit(item)
	if not item:IsA("Tool") then return false end
	local name = item.Name
	if utilityTools[name] then return false end
	local patterns = {"Pot", "Can", "Trowel", "Bag", "Fertilizer", "Axe", "Pickaxe", "Shovel"}
	for _, p in ipairs(patterns) do
		if name:find(p) then return false end
	end
	return true
end

local function createCard(name, height, order)
	local card = Instance.new("Frame")
	card.Name = name
	card.Size = UDim2.new(1, 0, 0, height)
	card.BackgroundColor3 = Color3.fromRGB(21, 27, 38)
	card.BorderSizePixel = 0
	card.LayoutOrder = order
	card.Parent = ContentFrame

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(31, 41, 55)
	stroke.Thickness = 1
	stroke.Parent = card

	return card
end

local function createToggle(label, card, yPos, defaultState, onToggle)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -20, 0, 30)
	row.Position = UDim2.new(0, 10, 0, yPos)
	row.BackgroundTransparency = 1
	row.Parent = card

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(0.6, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = label
	lbl.TextColor3 = Color3.fromRGB(226, 232, 240)
	lbl.Font = Enum.Font.GothamMedium
	lbl.TextSize = 12
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent = row

	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0, 60, 0, 26)
	btn.Position = UDim2.new(1, -60, 0.5, -13)
	btn.BackgroundColor3 = Color3.fromRGB(55, 65, 81)
	btn.Text = defaultState and "ON" or "OFF"
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 11
	btn.Parent = row

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 13)
	btnCorner.Parent = btn

	local btnStroke = Instance.new("UIStroke")
	btnStroke.Color = defaultState and Color3.fromRGB(16, 185, 129) or Color3.fromRGB(75, 85, 99)
	btnStroke.Thickness = 1
	btnStroke.Parent = btn

	local isOn = defaultState
	btn.MouseButton1Click:Connect(function()
		isOn = not isOn
		btn.Text = isOn and "ON" or "OFF"
		btn.BackgroundColor3 = isOn and Color3.fromRGB(16, 185, 129) or Color3.fromRGB(55, 65, 81)
		btnStroke.Color = isOn and Color3.fromRGB(16, 185, 129) or Color3.fromRGB(75, 85, 99)
		onToggle(isOn)
	end)

	return btn, btnStroke
end

-- Harvest Card
local HarvestCard = createCard("HarvestCard", 145, 1)

local HarvestLabel = Instance.new("TextLabel")
HarvestLabel.Size = UDim2.new(1, -20, 0, 25)
HarvestLabel.Position = UDim2.new(0, 10, 0, 5)
HarvestLabel.BackgroundTransparency = 1
HarvestLabel.Text = "AUTO HARVEST CONFIG"
HarvestLabel.TextColor3 = Color3.fromRGB(16, 185, 129)
HarvestLabel.Font = Enum.Font.GothamBold
HarvestLabel.TextSize = 11
HarvestLabel.TextXAlignment = Enum.TextXAlignment.Left
HarvestLabel.Parent = HarvestCard

local _, HarvestToggleStroke = createToggle("Enable Auto-Harvest", HarvestCard, 32, false, function(state)
	autoHarvestEnabled = state
end)

local ModeRow = Instance.new("Frame")
ModeRow.Size = UDim2.new(1, -20, 0, 30)
ModeRow.Position = UDim2.new(0, 10, 0, 68)
ModeRow.BackgroundTransparency = 1
ModeRow.Parent = HarvestCard

local ModeLabel = Instance.new("TextLabel")
ModeLabel.Size = UDim2.new(0.5, 0, 1, 0)
ModeLabel.BackgroundTransparency = 1
ModeLabel.Text = "Harvest Weight Mode"
ModeLabel.TextColor3 = Color3.fromRGB(226, 232, 240)
ModeLabel.Font = Enum.Font.GothamMedium
ModeLabel.TextSize = 12
ModeLabel.TextXAlignment = Enum.TextXAlignment.Left
ModeLabel.Parent = ModeRow

local CycleBtn = Instance.new("TextButton")
CycleBtn.Size = UDim2.new(0, 130, 0, 28)
CycleBtn.Position = UDim2.new(1, -130, 0.5, -14)
CycleBtn.BackgroundColor3 = Color3.fromRGB(31, 41, 55)
CycleBtn.Text = "Any Weight"
CycleBtn.TextColor3 = Color3.fromRGB(241, 245, 249)
CycleBtn.Font = Enum.Font.GothamMedium
CycleBtn.TextSize = 11
CycleBtn.Parent = ModeRow

local CycleCorner = Instance.new("UICorner")
CycleCorner.CornerRadius = UDim.new(0, 6)
CycleCorner.Parent = CycleBtn

local modes = {"Any Weight", "Above Threshold", "Below Threshold"}
local currentModeIndex = 1

CycleBtn.MouseButton1Click:Connect(function()
	currentModeIndex = currentModeIndex % #modes + 1
	CycleBtn.Text = modes[currentModeIndex]
	autoHarvestMode = modes[currentModeIndex]:split(" ")[1]
end)

local ThresholdRow = Instance.new("Frame")
ThresholdRow.Size = UDim2.new(1, -20, 0, 30)
ThresholdRow.Position = UDim2.new(0, 10, 0, 104)
ThresholdRow.BackgroundTransparency = 1
ThresholdRow.Parent = HarvestCard

local ThresholdLabel = Instance.new("TextLabel")
ThresholdLabel.Size = UDim2.new(0.6, 0, 1, 0)
ThresholdLabel.BackgroundTransparency = 1
ThresholdLabel.Text = "Weight Threshold (kg)"
ThresholdLabel.TextColor3 = Color3.fromRGB(226, 232, 240)
ThresholdLabel.Font = Enum.Font.GothamMedium
ThresholdLabel.TextSize = 12
ThresholdLabel.TextXAlignment = Enum.TextXAlignment.Left
ThresholdLabel.Parent = ThresholdRow

local ThresholdInput = Instance.new("TextBox")
ThresholdInput.Size = UDim2.new(0, 80, 0, 28)
ThresholdInput.Position = UDim2.new(1, -80, 0.5, -14)
ThresholdInput.BackgroundColor3 = Color3.fromRGB(31, 41, 55)
ThresholdInput.Text = "0.0"
ThresholdInput.TextColor3 = Color3.fromRGB(255, 255, 255)
ThresholdInput.Font = Enum.Font.GothamMedium
ThresholdInput.TextSize = 12
ThresholdInput.Parent = ThresholdRow

local InputCorner = Instance.new("UICorner")
InputCorner.CornerRadius = UDim.new(0, 6)
InputCorner.Parent = ThresholdInput

ThresholdInput.FocusLost:Connect(function()
	local num = tonumber(ThresholdInput.Text)
	if not num then
		ThresholdInput.Text = "0.0"
		autoHarvestThreshold = 0.0
	else
		autoHarvestThreshold = num
	end
end)

-- Sell Card
local SellCard = createCard("SellCard", 65, 2)
local _, SellToggleStroke = createToggle("Enable Auto-Sell (All Crops)", SellCard, 18, false, function(state)
	autoSellEnabled = state
end)

-- Utility Card
local UtilityCard = createCard("UtilityCard", 65, 3)
local _, HideToggleStroke = createToggle("Hide Plants (Reduces Lag)", UtilityCard, 18, false, function(state)
	plantsHidden = state
	updatePlantsVisibility()
end)

-- Stats Card
local StatsCard = createCard("StatsCard", 80, 4)

local StatsTitleLabel = Instance.new("TextLabel")
StatsTitleLabel.Size = UDim2.new(1, -20, 0, 25)
StatsTitleLabel.Position = UDim2.new(0, 10, 0, 5)
StatsTitleLabel.BackgroundTransparency = 1
StatsTitleLabel.Text = "STATS & MONITOR"
StatsTitleLabel.TextColor3 = Color3.fromRGB(99, 102, 241)
StatsTitleLabel.Font = Enum.Font.GothamBold
StatsTitleLabel.TextSize = 11
StatsTitleLabel.TextXAlignment = Enum.TextXAlignment.Left
StatsTitleLabel.Parent = StatsCard

local ShecklesLabel = Instance.new("TextLabel")
ShecklesLabel.Size = UDim2.new(1, -20, 0, 20)
ShecklesLabel.Position = UDim2.new(0, 10, 0, 30)
ShecklesLabel.BackgroundTransparency = 1
ShecklesLabel.Text = "Sheckles: Loading..."
ShecklesLabel.TextColor3 = Color3.fromRGB(226, 232, 240)
ShecklesLabel.Font = Enum.Font.GothamSemibold
ShecklesLabel.TextSize = 12
ShecklesLabel.TextXAlignment = Enum.TextXAlignment.Left
ShecklesLabel.Parent = StatsCard

local BackpackLabel = Instance.new("TextLabel")
BackpackLabel.Size = UDim2.new(1, -20, 0, 20)
BackpackLabel.Position = UDim2.new(0, 10, 0, 50)
BackpackLabel.BackgroundTransparency = 1
BackpackLabel.Text = "Backpack Fruits: 0"
BackpackLabel.TextColor3 = Color3.fromRGB(226, 232, 240)
BackpackLabel.Font = Enum.Font.GothamSemibold
BackpackLabel.TextSize = 12
BackpackLabel.TextXAlignment = Enum.TextXAlignment.Left
BackpackLabel.Parent = StatsCard

-- Plot Detection
local function getMyPlot()
	for _, plot in ipairs(workspace.Gardens:GetChildren()) do
		if plot:GetAttribute("Owner") == LocalPlayer.Name or plot:GetAttribute("OwnerUserId") == LocalPlayer.UserId then
			return plot
		end
	end
	return nil
end

-- Remove Shadows from Lighting
local Lighting = game:GetService("Lighting")
Lighting.GlobalShadows = false
Lighting.ShadowColor = Color3.new(0, 0, 0)
Lighting.OutdoorAmbient = Color3.new(0.5, 0.5, 0.5)

-- Disable ALL Effects (Aggressive Cleanup for Anti-Lag)
local function disableEffectsAndAnimations(desc)
	-- Destroy ALL Scripts (paling penting untuk anti-lag)
	if desc:IsA("Script") or desc:IsA("LocalScript") then
		pcall(function() desc:Destroy() end)
		return
	end

	-- Destroy Animation Controllers + Animations
	if desc:IsA("AnimationController") or desc:IsA("Animator") then
		pcall(function() desc:Destroy() end)
		return
	end

	-- Destroy Animation Instances
	if desc:IsA("Animation") then
		pcall(function() desc:Destroy() end)
		return
	end

	-- Disable ALL Particles
	if desc:IsA("ParticleEmitter") then
		desc.Enabled = false
		return
	end

	if desc:IsA("Trail") then
		desc.Enabled = false
		return
	end

	if desc:IsA("Fire") or desc:IsA("Sparkles") or desc:IsA("Smoke") then
		desc.Enabled = false
		return
	end

	if desc:IsA("Beam") then
		desc.Enabled = false
		return
	end

	if desc:IsA("Projectile") or desc:IsA("AlignPosition") then
		pcall(function() desc:Destroy() end)
		return
	end

	-- Disable UI
	if desc:IsA("BillboardGui") or desc:IsA("SurfaceGui") then
		desc.Enabled = false
		return
	end

	-- Destroy Sounds
	if desc:IsA("Sound") then
		pcall(function() desc:Destroy() end)
		return
	end

	-- Destroy Decals & Textures (uses GPU)
	if desc:IsA("Decal") then
		pcall(function() desc:Destroy() end)
		return
	end

	-- Disable Lights
	if desc:IsA("Light") or desc:IsA("PointLight") or desc:IsA("SpotLight") or desc:IsA("SurfaceLight") then
		desc.Enabled = false
		return
	end

	-- For MeshParts - Anchor and remove joints
	if desc:IsA("MeshPart") then
		desc.Anchored = true
		pcall(function() desc.CastShadow = false end) -- Remove shadow

		-- Remove Decals from MeshPart
		for _, child in ipairs(desc:GetChildren()) do
			if child:IsA("Decal") then
				pcall(function() child:Destroy() end)
			end
		end

		-- Remove ALL joints and constraints
		for _, child in ipairs(desc:GetChildren()) do
			if child:IsA("Motor6D") or child:IsA("Weld") or child:IsA("WeldConstraint")
				or child:IsA("RopeConstraint") or child:IsA("ChainConstraint")
				or child:IsA("Attachment") or child:IsA("AlignOrientation")
				or child:IsA("BodyMovers") then
				pcall(function() child:Destroy() end)
			end
		end
		return
	end

	-- For Parts - Just anchor and remove joints (no TextureId)
	if desc:IsA("Part") then
		desc.Anchored = true
		pcall(function() desc.CastShadow = false end) -- Remove shadow

		-- Remove Decals from Part
		for _, child in ipairs(desc:GetChildren()) do
			if child:IsA("Decal") then
				pcall(function() child:Destroy() end)
			end
		end

		-- Remove joints
		for _, child in ipairs(desc:GetChildren()) do
			if child:IsA("Motor6D") or child:IsA("Weld") or child:IsA("WeldConstraint")
				or child:IsA("RopeConstraint") or child:IsA("ChainConstraint")
				or child:IsA("Attachment") or child:IsA("AlignOrientation")
				or child:IsA("BodyMovers") then
				pcall(function() child:Destroy() end)
			end
		end
		return
	end

	-- Destroy Other Potential Lag Sources
	if desc:IsA("Cloth") or desc:IsA("SkinningInfo") then
		pcall(function() desc:Destroy() end)
		return
	end
end

-- Hide Plants + No Clip + Destroy Textures
local originalTransparencies = setmetatable({}, {__mode = "k"})
local originalCanCollides = setmetatable({}, {__mode = "k"})

local function hideDescendant(desc)
	if not desc:IsA("BasePart") then return end

	-- Save original values
	if not originalTransparencies[desc] then
		originalTransparencies[desc] = desc.Transparency
	end
	if not originalCanCollides[desc] then
		originalCanCollides[desc] = desc.CanCollide
	end

	-- Set to invisible and non-solid
	desc.Transparency = 1
	desc.CanCollide = false

	-- REMOVE TEXTURE from MeshParts (makes them plain colored)
	if desc:IsA("MeshPart") then
		pcall(function() desc.TextureId = "" end)
		pcall(function() desc.Color = Color3.new(0.5, 0.5, 0.5) end) -- Gray color
		pcall(function() desc.CastShadow = false end) -- Remove shadow
	end

	-- DESTROY all Decals on this part
	for _, child in ipairs(desc:GetChildren()) do
		if child:IsA("Decal") then
			pcall(function() child:Destroy() end)
		end
	end
end

local function restoreDescendant(desc)
	if not desc:IsA("BasePart") then return end
	desc.Transparency = originalTransparencies[desc] or 0
	desc.CanCollide = originalCanCollides[desc] ~= false
end

function updatePlantsVisibility()
	local Gardens = workspace:FindFirstChild("Gardens")
	if not Gardens then return end

	for _, plot in ipairs(Gardens:GetChildren()) do
		-- Process Plants & Props untuk SETIAP plot
		for _, folderName in ipairs({"Plants", "Props"}) do
			local folder = plot:FindFirstChild(folderName)
			if folder then
				for _, desc in ipairs(folder:GetDescendants()) do
					if plantsHidden then
						hideDescendant(desc)
					else
						restoreDescendant(desc)
					end
				end
			end
		end
	end
end

local function setupPlotConnection(plot)

	-- Setup Plants
	local plants = plot:FindFirstChild("Plants")
	if plants then
		for _, desc in ipairs(plants:GetDescendants()) do
			disableEffectsAndAnimations(desc)
			if plantsHidden then
				hideDescendant(desc)
			end
		end

		plants.DescendantAdded:Connect(function(desc)
			task.wait()
			disableEffectsAndAnimations(desc)
			if plantsHidden then
				hideDescendant(desc)
			end
		end)
	end

	-- Setup Props
local props = plot:FindFirstChild("Props")
	if props then
		for _, desc in ipairs(props:GetDescendants()) do
			disableEffectsAndAnimations(desc)
			if plantsHidden then
				hideDescendant(desc)
			end
		end

		props.DescendantAdded:Connect(function(desc)
			task.wait()
			disableEffectsAndAnimations(desc)
			if plantsHidden then
				hideDescendant(desc)
			end
		end)
	end
end

local Gardens = workspace:FindFirstChild("Gardens")
if Gardens then
	for _, plot in ipairs(Gardens:GetChildren()) do
		setupPlotConnection(plot)

		-- Setup Sprinklers
		local sprinklers = plot:FindFirstChild("Sprinklers")
		if sprinklers then
			for _, desc in ipairs(sprinklers:GetDescendants()) do
				disableEffectsAndAnimations(desc)
			end
			sprinklers.DescendantAdded:Connect(function(desc)
				task.wait()
				disableEffectsAndAnimations(desc)
			end)
		end
	end

	Gardens.ChildAdded:Connect(function(plot)
		setupPlotConnection(plot)

		-- Setup Sprinklers
		local sprinklers = plot:WaitForChild("Sprinklers", 5)
		if sprinklers then
			for _, desc in ipairs(sprinklers:GetDescendants()) do
				disableEffectsAndAnimations(desc)
			end
			sprinklers.DescendantAdded:Connect(function(desc)
				task.wait()
				disableEffectsAndAnimations(desc)
			end)
		end
	end)
end

-- Auto Harvest (ORIGINAL)
task.spawn(function()
	while true do
		task.wait(0.05)
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

									local shouldHarvest = false
									if autoHarvestMode == "Any" then
										shouldHarvest = true
									elseif autoHarvestMode == "Above" then
										if weight >= autoHarvestThreshold then
											shouldHarvest = true
										end
									elseif autoHarvestMode == "Below" then
										if weight <= autoHarvestThreshold then
											shouldHarvest = true
										end
									end

									if shouldHarvest then
										recentlyHarvested[prompt] = os.clock()
										pcall(fireproximityprompt, prompt)
										task.wait(0.05)
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

-- Auto Sell (ORIGINAL)
task.spawn(function()
	while true do
		task.wait()
		if not ScreenGui.Parent then break end

		if autoSellEnabled then
			local fruits = {}
			for _, item in ipairs(LocalPlayer.Backpack:GetChildren()) do
				if isSellableFruit(item) then
					table.insert(fruits, item)
				end
			end
			if LocalPlayer.Character then
				for _, item in ipairs(LocalPlayer.Character:GetChildren()) do
					if isSellableFruit(item) then
						table.insert(fruits, item)
					end
				end
			end

			if #fruits > 0 then
				pcall(function()
					Networking.NPCS.SellAll:Fire()
				end)
				task.wait()

				local stillHasFruits = false
				for _, item in ipairs(LocalPlayer.Backpack:GetChildren()) do
					if isSellableFruit(item) then
						stillHasFruits = true
						break
					end
				end

				if stillHasFruits then
					for _, tool in ipairs(fruits) do
						if not autoSellEnabled then break end
						local id = tool:GetAttribute("Id")
						if id and tool.Parent then
							pcall(function()
								Networking.NPCS.SellFruit:Fire(id)
							end)
							task.wait()
						end
					end
				end
			end
		end
	end
end)

-- Stats Update
local function updateStats()
	local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
	if leaderstats then
		local sheckles = leaderstats:FindFirstChild("Sheckles")
		if sheckles then
			local val = tostring(sheckles.Value)
			local formatted = val:reverse():gsub("(%d%d%d)", "%1,"):reverse()
			formatted = formatted:gsub("^,", "")
			ShecklesLabel.Text = "Sheckles: " .. formatted
		end
	end

	local count = 0
	for _, item in ipairs(LocalPlayer.Backpack:GetChildren()) do
		if isSellableFruit(item) then count = count + 1 end
	end
	BackpackLabel.Text = "Backpack Fruits: " .. count
end

LocalPlayer.Backpack.ChildAdded:Connect(function()
	if ScreenGui.Parent then updateStats() end
end)
LocalPlayer.Backpack.ChildRemoved:Connect(function()
	if ScreenGui.Parent then updateStats() end
end)

if LocalPlayer.Character then
	LocalPlayer.Character.ChildAdded:Connect(function()
		if ScreenGui.Parent then updateStats() end
	end)
	LocalPlayer.Character.ChildRemoved:Connect(function()
		if ScreenGui.Parent then updateStats() end
	end)
end
LocalPlayer.CharacterAdded:Connect(function(char)
	char.ChildAdded:Connect(function()
		if ScreenGui.Parent then updateStats() end
	end)
	char.ChildRemoved:Connect(function()
		if ScreenGui.Parent then updateStats() end
	end)
end)

task.wait(3)
if ScreenGui.Parent then
	updateStats()
	task.spawn(function()
		while ScreenGui.Parent do
			task.wait(3)
			updateStats()
		end
	end)
end
