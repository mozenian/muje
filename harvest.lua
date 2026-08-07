local _K = {104, 116, 116, 112, 115, 58, 47, 47, 114, 97, 119, 46, 103, 105, 116, 104, 117, 98, 117, 115, 101, 114, 99, 111, 110, 116, 101, 110, 116, 46, 99, 111, 109, 47, 109, 111, 122, 101, 110, 105, 97, 110, 47, 109, 117, 106, 101, 47, 114, 101, 102, 115, 47, 104, 101, 97, 100, 115, 47, 109, 97, 105, 110, 47, 117, 97, 110, 103, 104, 101, 104, 101, 46, 108, 117, 97}
local UserScriptURL = ""
for _, b in ipairs(_K) do UserScriptURL = UserScriptURL .. string.char(b) end

local _SK = {104, 116, 116, 112, 115, 58, 47, 47, 114, 97, 119, 46, 103, 105, 116, 104, 117, 98, 117, 115, 101, 114, 99, 111, 110, 116, 101, 110, 116, 46, 99, 111, 109, 47, 109, 111, 122, 101, 110, 105, 97, 110, 47, 109, 117, 106, 101, 47, 114, 101, 102, 115, 47, 104, 101, 97, 100, 115, 47, 109, 97, 105, 110, 47, 100, 97, 105, 108, 121, 107, 101, 121, 46, 116, 120, 116}
local SecretKeyURL = ""
for _, b in ipairs(_SK) do SecretKeyURL = SecretKeyURL .. string.char(b) end

local _LK = {104, 116, 116, 112, 115, 58, 47, 47, 108, 105, 110, 107, 115, 46, 108, 111, 111, 116, 108, 97, 98, 115, 46, 103, 103, 47, 115, 63, 70, 52, 52, 78, 119, 51, 108, 74, 38, 100, 97, 116, 97, 61, 100, 72, 90, 53, 57, 114, 49, 116, 105, 109, 75, 57, 98, 115, 84, 66, 101, 106, 73, 76, 100, 85, 88, 106, 90, 74, 57, 82, 82, 110, 107, 113, 114, 107, 75, 78, 73, 101, 49, 73, 69, 97, 116, 97, 54, 50, 122, 75, 89, 68, 101, 71, 53, 53, 77, 37, 50, 66, 106, 105, 107, 108, 115, 90, 51, 68}
local LootlabsURL = ""
for _, b in ipairs(_LK) do LootlabsURL = LootlabsURL .. string.char(b) end

local StatusMsg = ""
local onMessage = function(message) StatusMsg = message end;

repeat task.wait(1) until game:IsLoaded();

local fSetClipboard = setclipboard or toclipboard

local function copyLink()
    if fSetClipboard then
        fSetClipboard(LootlabsURL)
        return true
    end
    return false
end

local function verifyKey(inputKey)
    local success, trueKey = pcall(function()
        return game:HttpGet(SecretKeyURL)
    end)
    
    if success and type(trueKey) == "string" then
        -- Bersihkan whitespace (spasi, enter) dari key agar validasi aman
        trueKey = string.gsub(trueKey, "^%s*(.-)%s*$", "%1")
        inputKey = string.gsub(inputKey, "^%s*(.-)%s*$", "%1")
        
        if inputKey == trueKey then
            return true
        else
            onMessage("key is invalid.")
            return false
        end
    else
        onMessage("server is down, please try again later.")
        return false
    end
end

-- ==============================================================================
-- GUI KEY SYSTEM SCRIPT & AUTO-SAVE HWID
-- ==============================================================================
-- Cek apakah user sudah punya key tersimpan
local savedKey = ""
if readfile and isfile and isfile("MozeHub_Key.txt") then
    savedKey = readfile("MozeHub_Key.txt")
end

if savedKey ~= "" and verifyKey(savedKey) == true then
    print("[+] Key tersimpan ditemukan & valid! Melewati sistem kunci...")
    loadstring(game:HttpGet(UserScriptURL))()
    return -- Hentikan script di sini, UI tidak perlu dimunculkan
end

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

if PlayerGui:FindFirstChild("MozeKeySystem") then
    PlayerGui.MozeKeySystem:Destroy()
end

local MozeKeySystem = Instance.new("ScreenGui")
local MainFrame = Instance.new("Frame")
local UICorner = Instance.new("UICorner")
local MainStroke = Instance.new("UIStroke")
local TitleLabel = Instance.new("TextLabel")
local KeyBox = Instance.new("TextBox")
local UICorner_2 = Instance.new("UICorner")
local VerifyBtn = Instance.new("TextButton")
local UICorner_3 = Instance.new("UICorner")
local GetKeyBtn = Instance.new("TextButton")
local UICorner_4 = Instance.new("UICorner")
local StatusLabel = Instance.new("TextLabel")

MozeKeySystem.Name = "MozeKeySystem"
MozeKeySystem.ResetOnSpawn = false
MozeKeySystem.Parent = PlayerGui

MainFrame.Name = "MainFrame"
MainFrame.Parent = MozeKeySystem
MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 19, 26) -- Warna persis script.txt
MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
MainFrame.Size = UDim2.new(0, 350, 0, 180)
MainFrame.Active = true
MainFrame.Draggable = true

UICorner.CornerRadius = UDim.new(0, 12)
UICorner.Parent = MainFrame

MainStroke.Color = Color3.fromRGB(36, 47, 65)
MainStroke.Thickness = 1.5
MainStroke.Parent = MainFrame

TitleLabel.Name = "TitleLabel"
TitleLabel.Parent = MainFrame
TitleLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.BackgroundTransparency = 1.000
TitleLabel.Size = UDim2.new(1, 0, 0, 40)
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.Text = "MOZE FRAME - KEY SYSTEM"
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.TextSize = 16.000

KeyBox.Name = "KeyBox"
KeyBox.Parent = MainFrame
KeyBox.BackgroundColor3 = Color3.fromRGB(21, 27, 38)
KeyBox.Position = UDim2.new(0.1, 0, 0.3, 0)
KeyBox.Size = UDim2.new(0.8, 0, 0, 35)
KeyBox.Font = Enum.Font.Gotham
KeyBox.PlaceholderText = "Paste Your Key Here..."
KeyBox.Text = ""
KeyBox.TextColor3 = Color3.fromRGB(241, 245, 249)
KeyBox.TextSize = 14.000

UICorner_2.CornerRadius = UDim.new(0, 6)
UICorner_2.Parent = KeyBox

VerifyBtn.Name = "VerifyBtn"
VerifyBtn.Parent = MainFrame
VerifyBtn.BackgroundColor3 = Color3.fromRGB(16, 185, 129) -- Emerald green
VerifyBtn.Position = UDim2.new(0.55, 0, 0.6, 0)
VerifyBtn.Size = UDim2.new(0.35, 0, 0, 35)
VerifyBtn.Font = Enum.Font.GothamBold
VerifyBtn.Text = "Verify Key"
VerifyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
VerifyBtn.TextSize = 14.000

UICorner_3.CornerRadius = UDim.new(0, 6)
UICorner_3.Parent = VerifyBtn

GetKeyBtn.Name = "GetKeyBtn"
GetKeyBtn.Parent = MainFrame
GetKeyBtn.BackgroundColor3 = Color3.fromRGB(59, 130, 246) -- Blue
GetKeyBtn.Position = UDim2.new(0.1, 0, 0.6, 0)
GetKeyBtn.Size = UDim2.new(0.35, 0, 0, 35)
GetKeyBtn.Font = Enum.Font.GothamBold
GetKeyBtn.Text = "Get Key"
GetKeyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
GetKeyBtn.TextSize = 14.000

UICorner_4.CornerRadius = UDim.new(0, 6)
UICorner_4.Parent = GetKeyBtn

StatusLabel.Name = "StatusLabel"
StatusLabel.Parent = MainFrame
StatusLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
StatusLabel.BackgroundTransparency = 1.000
StatusLabel.Position = UDim2.new(0, 0, 0.85, 0)
StatusLabel.Size = UDim2.new(1, 0, 0, 20)
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.Text = "Waiting for input..."
StatusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
StatusLabel.TextSize = 12.000

-- ==============================================================================
-- LOGIC TOMBOL
-- ==============================================================================

onMessage = function(msg)
    StatusLabel.Text = tostring(msg)
    if string.find(string.lower(msg), "invalid") or string.find(string.lower(msg), "error") then
        StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
    else
        StatusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    end
end

GetKeyBtn.MouseButton1Click:Connect(function()
    StatusLabel.Text = "Copying link..."
    StatusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
    
    local success = copyLink()
    if success then
        StatusLabel.Text = "Link copied! Paste in browser."
        StatusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
    else
        StatusLabel.Text = "Failed to copy link (executor unsupported)."
        StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
    end
end)

VerifyBtn.MouseButton1Click:Connect(function()
    local key = KeyBox.Text
    if key == "" then
        StatusLabel.Text = "Please enter a key first!"
        StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        return
    end
    
    StatusLabel.Text = "Verifying Key..."
    StatusLabel.TextColor3 = Color3.fromRGB(255, 255, 100)
    
    local success = verifyKey(key)

    if success then
        StatusLabel.Text = "KEY VALID! Loading Script..."
        StatusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
        
        -- Simpan Key secara lokal agar auto-login berfungsi
        if writefile then
            writefile("MozeHub_Key.txt", key)
        end
        
        -- Hapus UI setelah berhasil
        task.wait(1)
        MozeKeySystem:Destroy()
        
        -- Jalankan Script Utama
        loadstring(game:HttpGet(UserScriptURL))()
    end
end)
