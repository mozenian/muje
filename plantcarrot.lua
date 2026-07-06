getgenv().WisHUBCarrotConfig = {
	AutoPlant = true,
	PlantSeed = "Mega",
	AutoKick = true,

	AutoHarvest = true,
	HarvestBelowKg = 60,

	AutoSell = true,
	AutoSprinkler = true,
	HidePlantsExceptCarrot = true,
	Rollback = getgenv().WisHUBCarrotDisableRollbackNextRun ~= true,
	AutoRejoin = true,
	RejoinSeed = "Auto",
	RejoinCheckInterval = 3,
	RejoinDelay = 8,
	RelogIfLoadingStuck = true,
	LoadingStuckDelay = 35,
	LoadingStuckRelogDelay = 2,
	Speed = 0.1,

	Sprinklers = {
		["Super Sprinkler"] = true,
		["Common Sprinkler"] = true,
		["Uncommon Sprinkler"] = true,
		["Rare Sprinkler"] = true,
		["Legendary Sprinkler"] = true,
	},
}

getgenv().WisHUBCarrotDisableRollbackNextRun = false

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local player = Players.LocalPlayer
local remote = ReplicatedStorage.SharedModules.Packet.RemoteEvent

local Env = (type(getgenv) == "function" and getgenv()) or _G
Env.WisHUBCarrotRunId = (tonumber(Env.WisHUBCarrotRunId) or 0) + 1
local RUN_ID = Env.WisHUBCarrotRunId

local Config = Env.WisHUBCarrotConfig
	or rawget(_G, "WisHUBCarrotConfig")
	or {}

local function isCurrentRun()
	return Env.WisHUBCarrotRunId == RUN_ID
end

local CONFIG_SPRINKLER_NAMES = {
	"Common Sprinkler",
	"Uncommon Sprinkler",
	"Rare Sprinkler",
	"Legendary Sprinkler",
	"Super Sprinkler",
}

local function cfgValue(key, default)
	local value = Config and Config[key]
	if value == nil then
		return default
	end
	return value
end

local function cfgBool(key, default)
	local value = cfgValue(key, default)
	if type(value) == "string" then
		value = value:lower()
		if value == "true" or value == "yes" or value == "on" or value == "1" then
			return true
		end
		if value == "false" or value == "no" or value == "off" or value == "0" then
			return false
		end
	end
	return value == true
end

local function cfgNumber(key, default, minValue, maxValue)
	local value = tonumber(cfgValue(key, default)) or default
	if minValue and value < minValue then
		value = minValue
	end
	if maxValue and value > maxValue then
		value = maxValue
	end
	return value
end

local function cfgString(key, default)
	local value = cfgValue(key, default)
	if value == nil then
		return default
	end
	return tostring(value)
end

local function cfgSelectedSprinklers()
	if not cfgBool("AutoSprinkler", false) then
		return {}
	end

	local selected = {}
	local sprinklerConfig = type(Config.Sprinklers) == "table" and Config.Sprinklers or {}
	for _, sprinklerName in ipairs(CONFIG_SPRINKLER_NAMES) do
		local enabled = sprinklerConfig[sprinklerName]
		if enabled == nil then
			enabled = Config[sprinklerName]
		end
		if enabled == true then
			table.insert(selected, sprinklerName)
		end
	end

	if #selected == 0 then
		table.insert(selected, "Super Sprinkler")
	end
	return selected
end

local state = {
	autoHarvestCarrot = cfgBool("AutoHarvest", false),
	autoPlantCarrot = cfgBool("AutoPlant", false),
	autoSellAll = cfgBool("AutoSell", false),
	hideNonCarrotVisuals = cfgBool("HidePlantsExceptCarrot", cfgBool("HideNonCarrotVisuals", false)),
	harvestKg = cfgNumber("HarvestBelowKg", 0, 0),
	farmSpeed = cfgNumber("Speed", 0.2, 0.1, 1),
	selectedPlantSeed = cfgString("PlantSeed", "Carrot"),
	selectedSprinklers = cfgSelectedSprinklers(),
	hideNonCarrotConnections = {},
	hiddenNonCarrotVisuals = {},
}

local function tracebackMessage(message)
	if type(debug) == "table" and type(debug.traceback) == "function" then
		return debug.traceback(message, 2)
	end
	return message
end

local function safeSpawn(label, fn)
	task.spawn(function()
		local ok, err = xpcall(fn, tracebackMessage)
		if not ok then
			warn("[WisHUB Carrot " .. tostring(label) .. "] " .. tostring(err))
		end
	end)
end


local packetCache = {}
local packetNames = {
	collectfruit = { "CollectFruit" },
	plantseed = { "PlantSeed" },
	sellall = { "SellAll", "SellInventory" },
	placesprinkler = { "PlaceSprinkler" },
}

local function getPacketIdByNames(names)
	local cacheKey = table.concat(names, "|")
	if packetCache[cacheKey] then
		return packetCache[cacheKey]
	end

	for _, name in ipairs(names) do
		local id = remote:GetAttribute(name)
		if type(id) == "number" then
			packetCache[cacheKey] = id
			return id
		end
	end

	for attr, id in pairs(remote:GetAttributes()) do
		if type(id) == "number" then
			for _, name in ipairs(names) do
				if string.lower(attr):find(string.lower(name), 1, true) then
					packetCache[cacheKey] = id
					return id
				end
			end
		end
	end
end

local function packetIdToString(id)
	return string.char(id % 256) .. string.char(math.floor(id / 256))
end

local function getCharacter()
	return player.Character or workspace:FindFirstChild(player.Name)
end

local function findChildOfClass(parent, className, recursive)
	if not parent then
		return nil
	end

	if type(parent.FindFirstChildOfClass) == "function" then
		local ok, child = pcall(function()
			return parent:FindFirstChildOfClass(className)
		end)
		if ok and child then
			return child
		end
	end

	if type(parent.FindFirstChildWhichIsA) == "function" then
		local ok, child = pcall(function()
			return parent:FindFirstChildWhichIsA(className, recursive == true)
		end)
		if ok and child then
			return child
		end
	end

	local ok, children = pcall(function()
		return recursive and parent:GetDescendants() or parent:GetChildren()
	end)
	if not ok or not children then
		return nil
	end

	for _, child in ipairs(children) do
		if child and child.IsA and child:IsA(className) then
			return child
		end
	end
end

local function getMyPlot()
	local gardens = workspace:FindFirstChild("Gardens")
	if not gardens then
		return nil
	end

	for _, plot in ipairs(gardens:GetChildren()) do
		if plot:GetAttribute("Owner") == player.Name or plot:GetAttribute("OwnerUserId") == player.UserId then
			return plot
		end
	end
end

local function getPlantAreas()
	local plot = getMyPlot()
	local visual = plot and plot:FindFirstChild("Visual")
	if not visual then
		return {}
	end

	local areas = {}
	for _, obj in ipairs(visual:GetChildren()) do
		if obj:IsA("BasePart") and obj.Name:match("^PlantAreaColumn") then
			table.insert(areas, obj)
		end
	end

	table.sort(areas, function(a, b)
		return a.Name < b.Name
	end)

	return areas
end

local function isCarrotName(name)
	return tostring(name or ""):lower():find("carrot", 1, true) ~= nil
end

local function getObjectName(obj)
	if not obj then
		return nil
	end

	for _, attr in ipairs({ "PlantName", "SeedName", "CorePartName", "FruitName", "Fruit" }) do
		local value = obj:GetAttribute(attr)
		if type(value) == "string" and value ~= "" then
			return value
		end
	end

	local current = obj.Parent
	while current do
		for _, attr in ipairs({ "PlantName", "SeedName", "CorePartName", "FruitName", "Fruit" }) do
			local value = current:GetAttribute(attr)
			if type(value) == "string" and value ~= "" then
				return value
			end
		end
		current = current.Parent
	end

	return obj.Name
end

local function isCarrotObject(obj)
	return isCarrotName(getObjectName(obj)) or isCarrotName(obj and obj.Name)
end

local function findAncestorAttribute(obj, attr)
	local current = obj
	while current do
		local value = current:GetAttribute(attr)
		if value ~= nil then
			return value
		end
		current = current.Parent
	end
end

local function readNumber(obj, attrs, includeAncestor)
	for _, attr in ipairs(attrs) do
		local value = obj and obj:GetAttribute(attr)
		if value ~= nil then
			if type(value) == "number" then
				return value
			end
			local number = tonumber(tostring(value):match("[%d%.]+"))
			if number then
				return number
			end
		end
	end

	if includeAncestor then
		for _, attr in ipairs(attrs) do
			local value = findAncestorAttribute(obj, attr)
			if value ~= nil then
				if type(value) == "number" then
					return value
				end
				local number = tonumber(tostring(value):match("[%d%.]+"))
				if number then
					return number
				end
			end
		end
	end
end

local carrotBaseWeight
local function getCarrotBaseWeight()
	if carrotBaseWeight ~= nil then
		return carrotBaseWeight or nil
	end

	local fruits = ReplicatedStorage:FindFirstChild("PlantGenerationModules")
		and ReplicatedStorage.PlantGenerationModules:FindFirstChild("Fruits")
	local module = fruits and fruits:FindFirstChild("Carrot")

	if module and module:IsA("ModuleScript") then
		local ok, data = pcall(require, module)
		local base = ok and type(data) == "table" and data.GrowData and tonumber(data.GrowData.BaseWeight)
		if base and base > 0 then
			carrotBaseWeight = base
			return base
		end
	end

	carrotBaseWeight = false
end

local fruitBaseWeightCache = {}
local function getFruitBaseWeightByName(fruitName)
	fruitName = tostring(fruitName or "")
	if fruitName == "" then
		return nil
	end

	if fruitBaseWeightCache[fruitName] ~= nil then
		return fruitBaseWeightCache[fruitName] or nil
	end

	local fruits = ReplicatedStorage:FindFirstChild("PlantGenerationModules")
		and ReplicatedStorage.PlantGenerationModules:FindFirstChild("Fruits")
	local module = fruits and fruits:FindFirstChild(fruitName)
	if module and module:IsA("ModuleScript") then
		local ok, data = pcall(require, module)
		local base = ok and type(data) == "table" and data.GrowData and tonumber(data.GrowData.BaseWeight)
		if base and base > 0 then
			fruitBaseWeightCache[fruitName] = base
			return base
		end
	end

	fruitBaseWeightCache[fruitName] = false
end

local CARROT_WEIGHT_MULTIPLIER = 0.534

local function getObjectKg(obj)
	if not obj then
		return 0
	end

	-- Try direct weight attributes first
	local direct = readNumber(obj, { "Weight", "WeightKG", "KG" }, true)
	if direct then
		return direct
	end

	-- Try SizeMulti attributes
	local sizeMulti = readNumber(obj, { "SizeMulti", "SizeMultiplier" }, true)
	if sizeMulti then
		local fruitName = getObjectName(obj)
		local base = fruitName and getFruitBaseWeightByName(fruitName)
		if base then
			return base * sizeMulti
		end
		return sizeMulti
	end

	-- For single harvest plants (like Carrot), calculate weight from Part2.Size.Y
	-- Formula: weight = Part2.Size.Y * 0.534
	local plantName = getObjectName(obj)
	if plantName and plantName:lower():find("carrot") then
		-- Find Part2 (main carrot body)
		local part2 = obj:FindFirstChild("2")
		if part2 and part2:IsA("BasePart") then
			return part2.Size.Y * CARROT_WEIGHT_MULTIPLIER
		end
		-- Try finding in descendants
		for _, child in ipairs(obj:GetDescendants()) do
			if child:IsA("BasePart") and child.Name == "2" then
				return child.Size.Y * CARROT_WEIGHT_MULTIPLIER
			end
		end
	end

	return 0
end

local function isReady(obj)
	local age = tonumber(obj and obj:GetAttribute("Age")) or 0
	local maxAge = tonumber(obj and obj:GetAttribute("MaxAge")) or 0
	local ready = obj and obj:GetAttribute("PlantGrowthReady")

	return ready == true or (maxAge > 0 and age >= maxAge)
end

local function getFruitId(obj)
	return obj:GetAttribute("FruitId")
		or obj:GetAttribute("FruitID")
		or obj:GetAttribute("FruitUUID")
		or obj:GetAttribute("UUID")
		or obj:GetAttribute("Id")
		or obj:GetAttribute("ID")
end

local collectRemote
local collectRemoteChecked = false
local function getCollectRemote()
	if collectRemoteChecked then
		return collectRemote
	end
	collectRemoteChecked = true

	local ok, networking = pcall(function()
		return require(ReplicatedStorage.SharedModules.Networking)
	end)

	if ok and networking and networking.Garden and networking.Garden.CollectFruit then
		collectRemote = networking.Garden.CollectFruit
	end

	return collectRemote
end

local function fireCollect(plantId, fruitId)
	if not plantId then
		return false
	end

	plantId = tostring(plantId)
	fruitId = fruitId ~= nil and tostring(fruitId) or ""

	local collect = getCollectRemote()
	local okCollect = collect and pcall(function()
		collect:Fire(plantId, fruitId)
	end)
	if okCollect then
		return true
	end

	local id = getPacketIdByNames(packetNames.collectfruit)
	if not id then
		return false
	end

	local packetId = packetIdToString(id)
	if fruitId ~= "" then
		remote:FireServer(buffer.fromstring(packetId .. "$" .. plantId .. "$" .. fruitId))
	else
		remote:FireServer(buffer.fromstring(packetId .. "$" .. plantId .. "\x00"))
	end

	return true
end

local function isSeedTool(tool, seedName)
	if not tool or not tool:IsA("Tool") then
		return false
	end
	if tool:GetAttribute("MainCategory") ~= "Seed" then
		return false
	end

	local realName = tool:GetAttribute("SeedTool") or tool.Name
	return realName == seedName
end

local function findSeedTool(seedName)
	local char = getCharacter()
	local backpack = player:FindFirstChild("Backpack")

	for _, container in ipairs({ char, backpack }) do
		if container then
			for _, tool in ipairs(container:GetChildren()) do
				if isSeedTool(tool, seedName) then
					return tool, container == char
				end
			end
		end
	end
end

local function equipSeed(seedName)
	local char = getCharacter()
	local hum = findChildOfClass(char, "Humanoid")
	local tool, equipped = findSeedTool(seedName)

	if not char or not hum or not tool then
		return nil
	end
	if equipped then
		return tool
	end

	if type(hum.EquipTool) == "function" then
		pcall(function()
			hum:EquipTool(tool)
		end)
	else
		pcall(function()
			tool.Parent = char
		end)
	end
	task.wait()

	local newTool, isEquipped = findSeedTool(seedName)
	return isEquipped and newTool or nil
end

local function firePlant(seedName, pos, toolOverride)
	local tool = toolOverride or findSeedTool(seedName)
	local id = getPacketIdByNames(packetNames.plantseed)
	if not tool or not id or not pos then
		return false
	end

	local buf = buffer.create(15 + #seedName)
	buffer.writeu16(buf, 0, id)
	buffer.writef32(buf, 2, pos.X)
	buffer.writef32(buf, 6, pos.Y)
	buffer.writef32(buf, 10, pos.Z)
	buffer.writeu8(buf, 14, #seedName)
	buffer.writestring(buf, 15, seedName)
	remote:FireServer(buf, { tool })
	return true
end

local turboCount = 0
local function turboYield(interval)
	interval = interval or 25
	turboCount += 1
	if turboCount % interval == 0 then
		task.wait()
	end
end

local function fireSellAll()
	local id = getPacketIdByNames(packetNames.sellall)
	if not id then
		return false
	end

	remote:FireServer(buffer.fromstring(packetIdToString(id) .. string.char(25)))
	return true
end

local function startSellAll()
	safeSpawn("sell", function()
		while isCurrentRun() and state.autoSellAll do
			fireSellAll()
			task.wait(0.1)
		end
	end)
end

local SPRINKLER_NAMES = {
	"Common Sprinkler",
	"Uncommon Sprinkler",
	"Rare Sprinkler",
	"Legendary Sprinkler",
	"Super Sprinkler",
}

local SPRINKLER_RADIUS_FALLBACK = {
	["Common Sprinkler"] = 20,
	["Uncommon Sprinkler"] = 25,
	["Rare Sprinkler"] = 30,
	["Legendary Sprinkler"] = 40,
	["Super Sprinkler"] = 55,
}

local SPRINKLER_RANGE_ATTRS = {
	"Radius",
	"Range",
	"Studs",
	"Coverage",
	"CoverageRadius",
	"SprinklerRadius",
	"EffectRadius",
	"AreaRadius",
	"WaterRadius",
	"MaxDistance",
}

local SPRINKLER_CLUSTER_OFFSETS = {
	Vector3.new(0, 0, 0),
	Vector3.new(3, 0, 0),
	Vector3.new(-3, 0, 0),
	Vector3.new(0, 0, 3),
	Vector3.new(0, 0, -3),
}

local PLANT_SEED_OPTIONS = { "Carrot", "Mega" }
local SPRINKLER_CLUSTER_MATCH_DISTANCE = 5
local SPRINKLER_ANCHOR_COUNT = 1
local SPRINKLER_PLACE_RETRY_DELAY = 2.5
local SPRINKLER_MAINTENANCE_INTERVAL = 1
local HARVEST_BRUTE_PASSES = 5
local HARVEST_BRUTE_RETRIES = 3
local HARVEST_YIELD_INTERVAL = 70
local HARVEST_MAX_FIRES_PER_CYCLE = 120
local PLANT_AREA_RANDOM_FACTOR = 0.49
local PLANT_ANCHOR_RANDOM_FACTOR = 0.44
local PLANT_SPRINKLER_ATTEMPTS = 24
local PLANT_POSITION_CACHE_SECONDS = 2
local PLANT_NEAREST_SAMPLE_LIMIT = 70
local PLANT_SPRINKLER_MIN_RADIUS_FACTOR = 0.035
local PLANT_SPRINKLER_MAX_RADIUS_FACTOR = 0.52
local PLANT_NEAR_SPRINKLER_MIN_DISTANCE = 1.25
local PLANT_NEAR_SPRINKLER_MAX_DISTANCE = 5.5
local PLANT_SPRINKLER_MAX_DISTANCE_CAP = 26
local PLANT_SPRINKLER_EDGE_MARGIN = 12
local PLANT_DEFAULT_SPACING = 5.5
local PLANT_SEED_SPACING = {
	Carrot = 5.5,
	Mega = 5.5,
}

local sprinklerRuntime = {
	Seen = {},
	Waiting = {},
	Placing = false,
	Anchors = {},
	PlantReady = false,
	LastMaintenance = 0,
}

local function getRootPosition()
	local char = getCharacter()
	local root = char and char:FindFirstChild("HumanoidRootPart")
	return root and root.Position or nil
end

local function getPlotId()
	local plot = getMyPlot()
	return plot and tonumber(plot.Name:match("%d+"))
end

local function getSprinklerFolder()
	local plot = getMyPlot()
	return plot and plot:FindFirstChild("Sprinklers")
end

local sprinklerDataLoaded = false
local sprinklerDataByName = {}

local function loadSprinklerData()
	if sprinklerDataLoaded then
		return sprinklerDataByName
	end

	sprinklerDataLoaded = true
	local sharedModules = ReplicatedStorage:FindFirstChild("SharedModules")
	local sprinklerData = sharedModules and sharedModules:FindFirstChild("SprinklerData")
	if not sprinklerData then
		return sprinklerDataByName
	end

	local ok, data = pcall(require, sprinklerData)
	if not ok or type(data) ~= "table" then
		return sprinklerDataByName
	end

	for _, info in pairs(data) do
		if type(info) == "table" and type(info.SprinklerName) == "string" then
			sprinklerDataByName[info.SprinklerName] = info
		end
	end

	return sprinklerDataByName
end

local function getNumberAttribute(obj, names)
	if not obj then
		return nil
	end

	for _, name in ipairs(names) do
		local value = obj:GetAttribute(name)
		if type(value) == "number" then
			return value
		end
		if type(value) == "string" then
			local number = tonumber(value)
			if number then
				return number
			end
		end
	end
end

local function readSprinklerRadiusFromInstance(obj)
	local radius = getNumberAttribute(obj, SPRINKLER_RANGE_ATTRS)
	if radius then
		return radius
	end

	for _, child in ipairs(obj:GetDescendants()) do
		radius = getNumberAttribute(child, SPRINKLER_RANGE_ATTRS)
		if radius then
			return radius
		end

		local lowerName = child.Name:lower()
		if child:IsA("NumberValue") or child:IsA("IntValue") then
			if lowerName:find("radius", 1, true) or lowerName:find("range", 1, true) or lowerName:find("stud", 1, true) then
				return tonumber(child.Value)
			end
		elseif child:IsA("BasePart") and (lowerName:find("radius", 1, true) or lowerName:find("range", 1, true)) then
			return math.max(child.Size.X, child.Size.Z) * 0.5
		end
	end
end

local function getSprinklerRadius(sprinklerName, obj)
	local data = loadSprinklerData()[sprinklerName]
	local radius = data and tonumber(data.Radius)
	if not radius and obj then
		radius = readSprinklerRadiusFromInstance(obj)
	end

	return math.max(tonumber(radius) or SPRINKLER_RADIUS_FALLBACK[sprinklerName] or 20, 1)
end

local function getInstancePosition(obj)
	if not obj then
		return nil
	end

	if obj:IsA("BasePart") then
		return obj.Position
	end

	if obj:IsA("Model") then
		if obj.PrimaryPart then
			return obj.PrimaryPart.Position
		end

		local ok, pivot = pcall(function()
			return obj:GetPivot()
		end)
		if ok and pivot then
			return pivot.Position
		end
	end

	local root = obj:FindFirstChild("Root", true)
	if root and root:IsA("BasePart") then
		return root.Position
	end

	local part = findChildOfClass(obj, "BasePart", true)
	return part and part.Position or nil
end

local function getKnownSprinklerName(name)
	name = tostring(name or "")
	for _, sprinklerName in ipairs(SPRINKLER_NAMES) do
		if name == sprinklerName then
			return sprinklerName
		end
	end
end

local function getInstanceSprinklerName(obj)
	if not obj then
		return nil
	end

	local sprinklerName = obj:GetAttribute("SprinklerName") or obj:GetAttribute("Sprinkler")
	if type(sprinklerName) == "string" and sprinklerName ~= "" then
		return sprinklerName
	end

	return getKnownSprinklerName(obj.Name)
end

local function addPlacedSprinkler(placed, seen, obj)
	local sprinklerName = getInstanceSprinklerName(obj)
	if not sprinklerName then
		return
	end

	local position = getInstancePosition(obj)
	if not position then
		return
	end

	local key = sprinklerName .. "|" .. tostring(math.floor(position.X * 10 + 0.5)) .. "|" .. tostring(math.floor(position.Z * 10 + 0.5))
	if seen[key] then
		return
	end
	seen[key] = true

	table.insert(placed, {
		Name = sprinklerName,
		Object = obj,
		Position = position,
		Radius = getSprinklerRadius(sprinklerName, obj),
	})
end

local function getPlacedSprinklers()
	local plot = getMyPlot()
	local folder = getSprinklerFolder()
	local placed = {}
	local seen = {}
	if not plot and not folder then
		return placed
	end

	local roots = {}
	if folder then
		table.insert(roots, folder)
	end
	if plot then
		table.insert(roots, plot)
	end

	for _, root in ipairs(roots) do
		addPlacedSprinkler(placed, seen, root)
		for _, obj in ipairs(root:GetChildren()) do
			addPlacedSprinkler(placed, seen, obj)
		end
		for _, obj in ipairs(root:GetDescendants()) do
			addPlacedSprinkler(placed, seen, obj)
		end
	end

	table.sort(placed, function(a, b)
		return a.Radius > b.Radius
	end)

	return placed
end

local function distanceXZ(a, b)
	local dx = a.X - b.X
	local dz = a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

local function getAreaCenterPosition(area)
	return area.CFrame:PointToWorldSpace(Vector3.new(0, 0, 0))
end

local function isPositionInsideArea(position, area)
	local localPosition = area.CFrame:PointToObjectSpace(position)
	return math.abs(localPosition.X) <= area.Size.X * 0.5 and math.abs(localPosition.Z) <= area.Size.Z * 0.5
end

local function getSprinklerOffset(index)
	return SPRINKLER_CLUSTER_OFFSETS[index] or Vector3.new((index - 1) * 0.5, 0, 0)
end

local function getSprinklerPlacePosition(anchor, sprinklerIndex)
	return anchor + getSprinklerOffset(sprinklerIndex)
end

local function findPlacedSprinklerNear(sprinklerName, position, maxDistance)
	if not position then
		return nil
	end

	for _, sprinkler in ipairs(getPlacedSprinklers()) do
		if sprinkler.Name == sprinklerName and distanceXZ(sprinkler.Position, position) <= maxDistance then
			return sprinkler.Object
		end
	end
end

local function getExistingSprinklerClusters()
	local clusters = {}
	for _, sprinkler in ipairs(getPlacedSprinklers()) do
		local matched = nil
		for _, cluster in ipairs(clusters) do
			if distanceXZ(cluster.Position, sprinkler.Position) <= SPRINKLER_CLUSTER_MATCH_DISTANCE then
				matched = cluster
				break
			end
		end

		if matched then
			matched.Count += 1
			matched.Position = Vector3.new(
				(matched.Position.X * (matched.Count - 1) + sprinkler.Position.X) / matched.Count,
				sprinkler.Position.Y,
				(matched.Position.Z * (matched.Count - 1) + sprinkler.Position.Z) / matched.Count
			)
		else
			table.insert(clusters, {
				Position = sprinkler.Position,
				Count = 1,
			})
		end
	end

	return clusters
end

local function ensureSprinklerAnchors()
	local areas = getPlantAreas()
	if #sprinklerRuntime.Anchors > 0 then
		return sprinklerRuntime.Anchors
	end

	local clusters = getExistingSprinklerClusters()
	for _, area in ipairs(areas) do
		if #sprinklerRuntime.Anchors >= SPRINKLER_ANCHOR_COUNT then
			break
		end

		local bestCluster = nil
		for _, cluster in ipairs(clusters) do
			if isPositionInsideArea(cluster.Position, area) and (not bestCluster or cluster.Count > bestCluster.Count) then
				bestCluster = cluster
			end
		end

		table.insert(sprinklerRuntime.Anchors, {
			Position = bestCluster and bestCluster.Position or getAreaCenterPosition(area),
			AreaName = area.Name,
			FromExisting = bestCluster ~= nil,
		})
	end

	for _, cluster in ipairs(clusters) do
		if #sprinklerRuntime.Anchors >= SPRINKLER_ANCHOR_COUNT then
			break
		end

		local alreadyUsed = false
		for _, anchor in ipairs(sprinklerRuntime.Anchors) do
			if distanceXZ(anchor.Position, cluster.Position) <= SPRINKLER_CLUSTER_MATCH_DISTANCE then
				alreadyUsed = true
				break
			end
		end

		if not alreadyUsed then
			table.insert(sprinklerRuntime.Anchors, {
				Position = cluster.Position,
				FromExisting = true,
			})
		end
	end

	while #sprinklerRuntime.Anchors < SPRINKLER_ANCHOR_COUNT and #areas > 0 do
		local area = areas[((#sprinklerRuntime.Anchors) % #areas) + 1]
		table.insert(sprinklerRuntime.Anchors, {
			Position = getAreaCenterPosition(area),
			AreaName = area.Name,
		})
	end

	local rootPosition = getRootPosition()
	while #sprinklerRuntime.Anchors < SPRINKLER_ANCHOR_COUNT and rootPosition do
		table.insert(sprinklerRuntime.Anchors, {
			Position = rootPosition,
			AreaName = "Player",
		})
	end

	while #sprinklerRuntime.Anchors > SPRINKLER_ANCHOR_COUNT do
		table.remove(sprinklerRuntime.Anchors)
	end

	return sprinklerRuntime.Anchors
end

local function resetPlantSetup()
	sprinklerRuntime.Seen = {}
	sprinklerRuntime.Waiting = {}
	sprinklerRuntime.Placing = false
	sprinklerRuntime.PlantReady = false
	sprinklerRuntime.LastMaintenance = 0

	local anchors = sprinklerRuntime.Anchors
	sprinklerRuntime.Anchors = {}
	if type(anchors) == "table" then
		for i = 1, math.min(#anchors, SPRINKLER_ANCHOR_COUNT) do
			table.insert(sprinklerRuntime.Anchors, {
				Position = anchors[i].Position,
				AreaName = anchors[i].AreaName,
				FromExisting = anchors[i].FromExisting,
			})
		end
	end
end

local function findSprinklerTool(sprinklerName)
	for _, container in ipairs({ getCharacter(), player:FindFirstChild("Backpack") }) do
		if container then
			for _, tool in ipairs(container:GetChildren()) do
				if tool:IsA("Tool") and (tool:GetAttribute("Sprinkler") == sprinklerName or tool.Name == sprinklerName) then
					local count = tonumber(tool:GetAttribute("Count"))
					if count == nil or count > 0 then
						return tool
					end
				end
			end
		end
	end
end

local function equipTool(tool)
	local char = getCharacter()
	local hum = findChildOfClass(char, "Humanoid")
	if not char or not hum or not tool then
		return false
	end
	if tool.Parent == char then
		return true
	end

	if type(hum.EquipTool) == "function" then
		pcall(function()
			hum:EquipTool(tool)
		end)
	else
		pcall(function()
			tool.Parent = char
		end)
	end
	task.wait()
	return tool.Parent == char
end

local function firePlaceSprinkler(tool, sprinklerName, position)
	local id = getPacketIdByNames(packetNames.placesprinkler)
	local plotId = getPlotId()
	if not id or not plotId or not tool or not position then
		return false
	end
	if not equipTool(tool) then
		return false
	end

	local buf = buffer.create(16 + #sprinklerName)
	buffer.writeu16(buf, 0, id)
	buffer.writef32(buf, 2, position.X)
	buffer.writef32(buf, 6, position.Y)
	buffer.writef32(buf, 10, position.Z)
	buffer.writeu8(buf, 14, #sprinklerName)
	buffer.writestring(buf, 15, sprinklerName)
	buffer.writeu8(buf, 15 + #sprinklerName, plotId)
	remote:FireServer(buf, { tool })
	return true
end

local function isSprinklerSelected(sprinklerName)
	local selected = state.selectedSprinklers
	if not selected or #selected == 0 then
		return false
	end
	-- Check if "All" is in selection
	for _, s in ipairs(selected) do
		if tostring(s):lower() == "all" then
			return true
		end
	end
	-- Check if sprinkler name is in selection
	for _, s in ipairs(selected) do
		if s == sprinklerName then
			return true
		end
	end
	return false
end

local function getPlantableSprinklers()
	local placed = {}
	for _, sprinkler in ipairs(getPlacedSprinklers()) do
		if isSprinklerSelected(sprinkler.Name) then
			table.insert(placed, sprinkler)
		end
	end
	return placed
end

local function placeMissingSprinklersOnce()
	if not cfgBool("AutoSprinkler", false) then
		return #getPlacedSprinklers()
	end
	if sprinklerRuntime.Placing then
		return #getPlacedSprinklers()
	end

	sprinklerRuntime.Placing = true
	local anchors = ensureSprinklerAnchors()
	local now = os.clock()
	for anchorIndex, anchor in ipairs(anchors) do
		for sprinklerIndex, sprinklerName in ipairs(SPRINKLER_NAMES) do
			if not state.autoPlantCarrot then
				break
			end

			-- Skip if sprinkler not selected
			if not isSprinklerSelected(sprinklerName) then
				continue
			end

			local position = getSprinklerPlacePosition(anchor.Position, sprinklerIndex)
			local waitKey = tostring(anchorIndex) .. "|" .. sprinklerName
			local placed = findPlacedSprinklerNear(sprinklerName, position, SPRINKLER_CLUSTER_MATCH_DISTANCE)
			if placed then
				sprinklerRuntime.Seen[waitKey] = placed
				sprinklerRuntime.Waiting[waitKey] = nil
			elseif not sprinklerRuntime.Waiting[waitKey] or (now - sprinklerRuntime.Waiting[waitKey]) >= SPRINKLER_PLACE_RETRY_DELAY then
				sprinklerRuntime.Seen[waitKey] = nil

				local tool = findSprinklerTool(sprinklerName)
				if tool and firePlaceSprinkler(tool, sprinklerName, position) then
					sprinklerRuntime.Waiting[waitKey] = os.clock()
					task.wait(0.1)
				end
			end
		end
	end

	sprinklerRuntime.Placing = false
	return #getPlacedSprinklers()
end

local function countMissingAvailableSprinklers()
	if not cfgBool("AutoSprinkler", false) then
		return 0
	end
	local missing = 0
	for anchorIndex, anchor in ipairs(ensureSprinklerAnchors()) do
		for sprinklerIndex, sprinklerName in ipairs(SPRINKLER_NAMES) do
			-- Skip if sprinkler not selected
			if not isSprinklerSelected(sprinklerName) then
				continue
			end

			local position = getSprinklerPlacePosition(anchor.Position, sprinklerIndex)
			local placed = findPlacedSprinklerNear(sprinklerName, position, SPRINKLER_CLUSTER_MATCH_DISTANCE)
			if not placed and findSprinklerTool(sprinklerName) then
				missing += 1
			end
		end
	end

	return missing
end

local function setupSprinklersForPlant()
	local now = os.clock()
	if sprinklerRuntime.PlantReady and (now - sprinklerRuntime.LastMaintenance) < SPRINKLER_MAINTENANCE_INTERVAL then
		return true
	end

	placeMissingSprinklersOnce()
	sprinklerRuntime.PlantReady = #getPlantableSprinklers() > 0 and countMissingAvailableSprinklers() == 0
	sprinklerRuntime.LastMaintenance = now
	return sprinklerRuntime.PlantReady
end

local function harvestCarrotsOnce()
	local plot = getMyPlot()
	local plants = plot and plot:FindFirstChild("Plants")
	if not plants then
		return 0
	end

	local fired = 0
	local harvestKg = tonumber(state.harvestKg) or 0
	local farmSpeed = math.max(0.1, math.min(1, tonumber(state.farmSpeed) or 0.1))
	local farmPower = 1.1 - farmSpeed
	local harvestPasses = math.max(1, math.floor(HARVEST_BRUTE_PASSES * farmPower + 0.5))
	local harvestRetries = math.max(1, math.floor(HARVEST_BRUTE_RETRIES * farmPower + 0.5))
	local yieldInterval = math.max(25, math.floor(HARVEST_YIELD_INTERVAL * farmPower + 0.5))
	local maxFires = math.max(12, math.floor(HARVEST_MAX_FIRES_PER_CYCLE * farmPower + 0.5))
	local plantChildren = plants:GetChildren()

	for _ = 1, harvestPasses do
		for _, plant in ipairs(plantChildren) do
			if not state.autoHarvestCarrot then
				return fired
			end

			if plant:IsA("Model") then
				local plantId = plant:GetAttribute("PlantId") or plant:GetAttribute("PlantID")
				local fruits = plant:FindFirstChild("Fruits")
				if not plantId then
					continue
				end

				if fruits then
					for _, fruit in ipairs(fruits:GetChildren()) do
						if not state.autoHarvestCarrot then
							return fired
						end

						local fruitId = getFruitId(fruit)
						local kg = getObjectKg(fruit)

						local skipKg = harvestKg > 0 and kg > 0 and kg >= harvestKg
						if fruitId and not skipKg then
							for _ = 1, harvestRetries do
								if fireCollect(plantId, fruitId) then
									fired += 1
									turboYield(yieldInterval)
									if fired >= maxFires then
										return fired
									end
								end
							end
						end
					end
				else
					local kg = getObjectKg(plant)

					local skipKg = harvestKg > 0 and kg > 0 and kg >= harvestKg
					if plantId and not skipKg then
						for _ = 1, harvestRetries do
							if fireCollect(plantId, "") then
								fired += 1
								turboYield(yieldInterval)
								if fired >= maxFires then
									return fired
								end
							end
						end
					end
				end
			end
		end
	end

	return fired
end

local function startHarvestCarrot()
	safeSpawn("harvest", function()
		while isCurrentRun() and state.autoHarvestCarrot do
			harvestCarrotsOnce()
			local farmSpeed = math.max(0.1, math.min(1, tonumber(state.farmSpeed) or 0.1))
			task.wait(math.max(0.008, farmSpeed * 0.055))
		end
	end)
end

local function getPlantSpacing(seedName)
	return PLANT_SEED_SPACING[tostring(seedName or "")] or PLANT_DEFAULT_SPACING
end

local plantPositionCache = {
	Time = 0,
	Positions = {},
}

local function getExistingPlantPositions()
	local now = os.clock()
	if (now - plantPositionCache.Time) < PLANT_POSITION_CACHE_SECONDS and type(plantPositionCache.Positions) == "table" then
		return plantPositionCache.Positions
	end

	local plot = getMyPlot()
	local plants = plot and plot:FindFirstChild("Plants")
	local positions = {}
	if not plants then
		plantPositionCache.Time = now
		plantPositionCache.Positions = positions
		return positions
	end

	for _, plant in ipairs(plants:GetChildren()) do
		local position = getInstancePosition(plant)
		if position then
			table.insert(positions, position)
		end
	end
	plantPositionCache.Time = now
	plantPositionCache.Positions = positions
	return positions
end

local function getNearestPlantDistance(position, plantPositions)
	local nearest = math.huge
	local count = #plantPositions
	local step = 1
	if count > PLANT_NEAREST_SAMPLE_LIMIT then
		step = math.max(1, math.floor(count / PLANT_NEAREST_SAMPLE_LIMIT))
	end
	for index = 1, count, step do
		local plantPosition = plantPositions[index]
		local distance = distanceXZ(position, plantPosition)
		if distance < nearest then
			nearest = distance
			if nearest <= 1 then
				return nearest
			end
		end
	end
	return nearest
end

local function getSprinklerPlantMaxDistance(sprinklerRadius)
	sprinklerRadius = math.max(tonumber(sprinklerRadius) or PLANT_NEAR_SPRINKLER_MAX_DISTANCE, 1)
	local edgeSafe = math.max(PLANT_NEAR_SPRINKLER_MAX_DISTANCE, sprinklerRadius - PLANT_SPRINKLER_EDGE_MARGIN)
	local scaled = math.max(PLANT_NEAR_SPRINKLER_MAX_DISTANCE, sprinklerRadius * PLANT_SPRINKLER_MAX_RADIUS_FACTOR)
	return math.min(edgeSafe, scaled, PLANT_SPRINKLER_MAX_DISTANCE_CAP)
end

local function getActiveSprinklerRadius(anchor)
	local radius = 0
	for _, sprinkler in ipairs(getPlantableSprinklers()) do
		local sprinklerRadius = tonumber(sprinkler.Radius) or 0
		local sameCluster = not anchor or distanceXZ(sprinkler.Position, anchor.Position) <= math.max(sprinklerRadius, SPRINKLER_CLUSTER_MATCH_DISTANCE)
		if sameCluster then
			radius = math.max(radius, sprinklerRadius)
		end
	end

	if radius > 0 then
		return radius
	end

	for _, sprinklerName in ipairs(SPRINKLER_NAMES) do
		if isSprinklerSelected(sprinklerName) then
			radius = math.max(radius, getSprinklerRadius(sprinklerName))
		end
	end

	return math.max(radius, PLANT_NEAR_SPRINKLER_MAX_DISTANCE)
end

local function getRandomSprinklerPosition(seedName, plantPositions)
	local areas = getPlantAreas()
	if #areas == 0 then
		return nil
	end

	local sprinklers = getPlantableSprinklers()
	if #sprinklers == 0 then
		return nil
	end

	plantPositions = plantPositions or getExistingPlantPositions()
	local spacing = getPlantSpacing(seedName)
	local bestPosition = nil
	local bestScore = -math.huge
	local farmSpeed = math.max(0.1, math.min(1, tonumber(state.farmSpeed) or 0.1))
	local attempts = math.max(8, math.floor(PLANT_SPRINKLER_ATTEMPTS * (1.1 - farmSpeed) + 0.5))

	for _ = 1, attempts do
		local sprinkler = sprinklers[math.random(1, #sprinklers)]
		local angle = math.random() * math.pi * 2
		local sprinklerRadius = tonumber(sprinkler.Radius) or getSprinklerRadius(sprinkler.Name, sprinkler.Object)
		local minDistance = math.max(PLANT_NEAR_SPRINKLER_MIN_DISTANCE, sprinklerRadius * PLANT_SPRINKLER_MIN_RADIUS_FACTOR)
		local maxDistance = math.max(minDistance, getSprinklerPlantMaxDistance(sprinklerRadius))
		local distance = minDistance + math.sqrt(math.random()) * (maxDistance - minDistance)
		local position = sprinkler.Position + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)

		for _, area in ipairs(areas) do
			if isPositionInsideArea(position, area) then
				local nearest = getNearestPlantDistance(position, plantPositions)
				local spacingScore = math.min(nearest, spacing * 3)
				local spreadScore = maxDistance > 0 and (distance / maxDistance) * spacing * 0.35 or 0
				local score = spacingScore + spreadScore
				if nearest >= spacing then
					score += spacing
				end
				if score > bestScore then
					bestScore = score
					bestPosition = position
				end
				break
			end
		end
	end

	return bestPosition
end

local function getSelectedPlantPosition(seedName, plantPositions)
	return getRandomSprinklerPosition(seedName, plantPositions)
end

local function getSelectedPlantSeed()
	local selected = tostring(state.selectedPlantSeed or "Carrot")
	for _, seedName in ipairs(PLANT_SEED_OPTIONS) do
		if selected == seedName then
			return seedName
		end
	end
	return "Carrot"
end

local function plantCarrotsOnce()
	if not setupSprinklersForPlant() then
		return 0
	end

	local seedName = getSelectedPlantSeed()
	local seedTool = equipSeed(seedName)
	if not seedTool then
		return 0
	end

	local fired = 0
	local farmSpeed = math.max(0.1, math.min(1, tonumber(state.farmSpeed) or 0.1))
	local plantBurst = math.max(1, math.floor(1 + (1.1 - farmSpeed) * 2))
	local plantPositions = getExistingPlantPositions()

	for _ = 1, plantBurst do
		if not state.autoPlantCarrot then
			break
		end
		if not seedTool.Parent then
			seedTool = findSeedTool(seedName)
			if not seedTool then
				break
			end
		end

		-- Get random position around sprinkler (no teleport)
		local position = getSelectedPlantPosition(seedName, plantPositions)
		if not position then
			break
		end
		if firePlant(seedName, position, seedTool) then
			fired += 1
			table.insert(plantPositions, position)
			turboYield(80)
		end
	end

	return fired
end

local function startPlantCarrot()
	safeSpawn("plant", function()
		while isCurrentRun() and state.autoPlantCarrot do
			plantCarrotsOnce()
			local farmSpeed = math.max(0.1, math.min(1, tonumber(state.farmSpeed) or 0.1))
			task.wait(math.max(0.03, farmSpeed * 0.12))
		end
	end)
end

local setHideNonCarrotVisuals
do
	local pendingRoots = {}
	local carrotRootCache = {}

	local function clearHideNonCarrotConnections()
		for _, connection in ipairs(state.hideNonCarrotConnections or {}) do
			if connection then
				pcall(function()
					connection:Disconnect()
				end)
			end
		end
		state.hideNonCarrotConnections = {}
	end

	local function restoreHiddenNonCarrotVisuals()
		for obj, saved in pairs(state.hiddenNonCarrotVisuals or {}) do
			if obj and obj.Parent and type(saved) == "table" then
				pcall(function()
					obj[saved.Property] = saved.Value
				end)
			end
		end
		state.hiddenNonCarrotVisuals = {}
	end

	local function restorePlantVisuals(root)
		if not root then
			return
		end
		for obj, saved in pairs(state.hiddenNonCarrotVisuals or {}) do
			if obj and obj.Parent and type(saved) == "table" and (obj == root or obj:IsDescendantOf(root)) then
				pcall(function()
					obj[saved.Property] = saved.Value
				end)
				state.hiddenNonCarrotVisuals[obj] = nil
			end
		end
	end

	local function rememberAndSetVisual(obj, property, value)
		state.hiddenNonCarrotVisuals = state.hiddenNonCarrotVisuals or {}
		if not state.hiddenNonCarrotVisuals[obj] then
			local ok, current = pcall(function()
				return obj[property]
			end)
			if ok then
				state.hiddenNonCarrotVisuals[obj] = {
					Property = property,
					Value = current,
				}
			end
		end
		pcall(function()
			obj[property] = value
		end)
	end

	local function hideVisualObject(obj)
		if obj:IsA("ProximityPrompt") or obj:IsA("BillboardGui") or obj:IsA("SurfaceGui") then
			return
		end
		if obj:IsA("BasePart") then
			rememberAndSetVisual(obj, "LocalTransparencyModifier", 1)
			pcall(function()
				obj.CastShadow = false
			end)
		elseif obj:IsA("Decal") or obj:IsA("Texture") then
			rememberAndSetVisual(obj, "Transparency", 1)
		elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then
			rememberAndSetVisual(obj, "Enabled", false)
		elseif obj:IsA("PointLight") or obj:IsA("SurfaceLight") or obj:IsA("SpotLight") or obj:IsA("Highlight") then
			rememberAndSetVisual(obj, "Enabled", false)
		end
	end

	local function getPlantVisualRoot(obj)
		local current = obj
		while current do
			if current.Parent and current.Parent.Name == "Plants" then
				return current
			end
			current = current.Parent
		end
	end

	local function isCarrotPlantRoot(root)
		if carrotRootCache[root] then
			return true
		end
		if isCarrotObject(root) then
			carrotRootCache[root] = true
			return true
		end

		local checked = 0
		for _, obj in ipairs(root:GetDescendants()) do
			if isCarrotObject(obj) then
				carrotRootCache[root] = true
				return true
			end
			checked += 1
			if checked % 120 == 0 then
				task.wait()
			end
		end
		return false
	end

	local function hideNonCarrotPlant(root)
		if not root then
			return
		end
		if isCarrotPlantRoot(root) then
			restorePlantVisuals(root)
			return
		end
		hideVisualObject(root)
		local processed = 0
		for _, obj in ipairs(root:GetDescendants()) do
			if not state.hideNonCarrotVisuals then
				return
			end
			hideVisualObject(obj)
			processed += 1
			if processed % 120 == 0 then
				task.wait()
			end
		end
	end

	local function queueHidePlantRoot(root)
		if not root or pendingRoots[root] then
			return
		end
		pendingRoots[root] = true
		task.defer(function()
			pendingRoots[root] = nil
			if state.hideNonCarrotVisuals then
				hideNonCarrotPlant(root)
			end
		end)
	end

	local function applyHideNonCarrotVisuals()
		local plot = getMyPlot()
		local plants = plot and plot:FindFirstChild("Plants")
		if not plants then
			return
		end

		local processed = 0
		for _, plant in ipairs(plants:GetChildren()) do
			if not state.hideNonCarrotVisuals then
				return
			end
			hideNonCarrotPlant(plant)
			processed += 1
			if processed % 12 == 0 then
				task.wait()
			end
		end
	end

	local function watchNonCarrotPlants()
		local plot = getMyPlot()
		local plants = plot and plot:FindFirstChild("Plants")
		if not plants then
			return
		end

		table.insert(state.hideNonCarrotConnections, plants.ChildAdded:Connect(function(plant)
			if state.hideNonCarrotVisuals then
				queueHidePlantRoot(plant)
			end
		end))
		table.insert(state.hideNonCarrotConnections, plants.DescendantAdded:Connect(function(obj)
			if not state.hideNonCarrotVisuals then
				return
			end
			queueHidePlantRoot(getPlantVisualRoot(obj))
		end))
	end

	setHideNonCarrotVisuals = function(enabled)
		state.hideNonCarrotVisuals = enabled == true
		clearHideNonCarrotConnections()

		if not state.hideNonCarrotVisuals then
			restoreHiddenNonCarrotVisuals()
			return
		end

		watchNonCarrotPlants()
		safeSpawn("hide", function()
			while isCurrentRun() and state.hideNonCarrotVisuals do
				applyHideNonCarrotVisuals()
				task.wait(3)
			end
		end)
	end
end

local rollbackActive = false

local function fireRollbackOnce()
	local packetRemote = ReplicatedStorage.SharedModules.Packet.RemoteEvent
	if not packetRemote then
		return false
	end
	local payload = string.char(0x3A, 0xF7)
	packetRemote:FireServer(payload)
	packetRemote:FireServer(54, "\xEF\xBF")
	packetRemote:FireServer(54, ":\xF7")
	rollbackActive = true
	return true
end

local function disableRollbackOnce(force)
	if not force and not rollbackActive then
		return false
	end
	local packetRemote = ReplicatedStorage.SharedModules.Packet.RemoteEvent
	if not packetRemote then
		return false
	end
	packetRemote:FireServer(54, "")
	packetRemote:FireServer(54, string.char(0x20))
	packetRemote:FireServer(54)
	packetRemote:FireServer(20, "")
	rollbackActive = false
	return true
end

local function getRejoinSeedName()
	local seedName = cfgString("RejoinSeed", "Auto")
	if seedName == "" or seedName:lower() == "auto" then
		seedName = state.selectedPlantSeed
	end
	return tostring(seedName or "Carrot")
end

local function getSeedToolCount(tool)
	if not tool then
		return 0
	end
	for _, attr in ipairs({ "Count", "Amount", "Stack", "Quantity" }) do
		local value = tool:GetAttribute(attr)
		if value ~= nil then
			local number = tonumber(value)
			if number ~= nil then
				return number
			end
		end
	end
	local textCount = tostring(tool.Name or ""):match("[xX]%s*(%d+)")
		or tostring(tool.Name or ""):match("%[(%d+)%]")
	return tonumber(textCount)
end

local function isSeedInventoryEmpty(seedName)
	local tool = findSeedTool(seedName)
	if not tool then
		return true
	end
	local count = getSeedToolCount(tool)
	return count ~= nil and count <= 0
end

local function carrotMatchesWantedKg(obj, targetKg)
	if not obj or not isCarrotObject(obj) then
		return false
	end
	if targetKg <= 0 then
		return true
	end
	local kg = getObjectKg(obj)
	return kg > 0 and kg >= targetKg
end

local function gardenHasWantedCarrot()
	local plot = getMyPlot()
	local plants = plot and plot:FindFirstChild("Plants")
	if not plants then
		return false
	end

	local targetKg = tonumber(state.harvestKg) or 0
	local checked = 0
	for _, plant in ipairs(plants:GetChildren()) do
		if carrotMatchesWantedKg(plant, targetKg) then
			return true, getObjectKg(plant)
		end

		local fruits = plant:FindFirstChild("Fruits")
		if fruits then
			for _, fruit in ipairs(fruits:GetChildren()) do
				if carrotMatchesWantedKg(fruit, targetKg) then
					return true, getObjectKg(fruit)
				end
			end
		end

		for _, obj in ipairs(plant:GetDescendants()) do
			if carrotMatchesWantedKg(obj, targetKg) then
				return true, getObjectKg(obj)
			end
			checked += 1
			if checked % 150 == 0 then
				task.wait()
			end
		end
	end

	return false
end

local function rejoinGame()
	TeleportService:Teleport(game.PlaceId, player)
end

local function queueRollbackOffNextRun()
	local queue = queue_on_teleport
		or (syn and syn.queue_on_teleport)
		or (fluxus and fluxus.queue_on_teleport)
		or (KRNL_LOADED and queue_on_teleport)
	if type(queue) == "function" then
		pcall(function()
			queue("getgenv().WisHUBCarrotDisableRollbackNextRun = true")
		end)
	end
end

local function playerGuiHasControllerLoading()
	local playerGui = player:FindFirstChild("PlayerGui")
	if not playerGui then
		return true
	end

	local checked = 0
	for _, obj in ipairs(playerGui:GetDescendants()) do
		if obj:IsA("TextLabel") or obj:IsA("TextButton") then
			local text = tostring(obj.Text or ""):lower()
			if text:find("initializing controllers", 1, true)
				or (text:find("controller", 1, true) and text:find("loading", 1, true)) then
				return true
			end
		end

		checked += 1
		if checked % 200 == 0 then
			task.wait()
		end
		if checked >= 1200 then
			break
		end
	end

	return false
end

local function hasLoadingStuckSignal()
	if playerGuiHasControllerLoading() then
		return true
	end
	if not player:FindFirstChild("HideCollectProximityPrompts") then
		return true
	end
	return false
end

local loadingStuckRelogStarted = false
local function startLoadingStuckRelogWatchdog()
	if not cfgBool("RelogIfLoadingStuck", false) then
		return
	end

	safeSpawn("loading-stuck-relog", function()
		task.wait(cfgNumber("LoadingStuckDelay", 35, 5))
		if not isCurrentRun() or loadingStuckRelogStarted then
			return
		end
		if not hasLoadingStuckSignal() then
			return
		end

		loadingStuckRelogStarted = true
		if type(Config) == "table" then
			Config.Rollback = false
		end
		Env.WisHUBCarrotDisableRollbackNextRun = true
		queueRollbackOffNextRun()
		disableRollbackOnce(true)
		task.wait(cfgNumber("LoadingStuckRelogDelay", 2, 0))
		if isCurrentRun() then
			rejoinGame()
		end
	end)
end

local function startRollbackRejoinMonitor()
	if not cfgBool("AutoRejoin", false) then
		return
	end

	safeSpawn("rejoin", function()
		task.wait(cfgNumber("RejoinDelay", 8, 0))
		while isCurrentRun() and cfgBool("AutoRejoin", false) do
			local seedName = getRejoinSeedName()
			if isSeedInventoryEmpty(seedName) then
				if gardenHasWantedCarrot() then
					disableRollbackOnce()
					return
				end
				rejoinGame()
				return
			end
			task.wait(cfgNumber("RejoinCheckInterval", 3, 1))
		end
	end)
end

local function applyNoUiConfig()
	state.autoPlantCarrot = cfgBool("AutoPlant", state.autoPlantCarrot)
	state.autoHarvestCarrot = cfgBool("AutoHarvest", state.autoHarvestCarrot)
	state.autoSellAll = cfgBool("AutoSell", state.autoSellAll)
	state.hideNonCarrotVisuals = cfgBool("HidePlantsExceptCarrot", state.hideNonCarrotVisuals)
	state.harvestKg = cfgNumber("HarvestBelowKg", state.harvestKg, 0)
	state.farmSpeed = cfgNumber("Speed", state.farmSpeed, 0.1, 1)
	state.selectedPlantSeed = cfgString("PlantSeed", state.selectedPlantSeed)
	state.selectedSprinklers = cfgSelectedSprinklers()
	state.autoKick = cfgBool("AutoKick", true)
end

local function startTargetMonitor()
	safeSpawn("target-monitor", function()
		while isCurrentRun() do
			local targetKg = tonumber(state.harvestKg) or 0
			
			if targetKg > 0 then
				local hasTarget, foundKg = gardenHasWantedCarrot() 
				
				if hasTarget then
					-- 1. Matikan SEMUA otomatisasi agar script berhenti beraktivitas
					state.autoPlantCarrot = false 
					state.autoHarvestCarrot = false
					state.autoSellAll = false
					
					-- 2. Batalkan rollback (tambahkan parameter 'true' untuk force)
					disableRollbackOnce(true) 
					
					-- 3. Perpanjang jeda menjadi 6 detik agar server benar-benar menyimpan data tanaman
					task.wait(9) 
					
					-- 4. Eksekusi Kick
					if state.autoKick then
						local kgFormat = string.format("%.2f", foundKg)
						player:Kick("Congrast you got " .. kgFormat .. " kg carrot in your garden")
					end
					
					break 
				end
			end
			
			task.wait(2)
		end
	end)
end
local function boot()
	applyNoUiConfig()
	startLoadingStuckRelogWatchdog()

	if state.hideNonCarrotVisuals then
		setHideNonCarrotVisuals(true)
	end

	if cfgBool("Rollback", false) then
		fireRollbackOnce()
	end
	startRollbackRejoinMonitor()

	if state.autoSellAll then
		startSellAll()
	end

	if state.autoHarvestCarrot then
		startHarvestCarrot()
	end

	if state.autoPlantCarrot then
		resetPlantSetup()
		startPlantCarrot()
	end

	startTargetMonitor()
end

local ok, err = xpcall(boot, function(message)
	if type(debug) == "table" and type(debug.traceback) == "function" then
		return debug.traceback(message, 2)
	end
	return message
end)
if not ok then
	warn("[WisHUB Carrot Core] " .. tostring(err))
end
