if not game:IsLoaded() then game.Loaded:Wait() end

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local player = Players.LocalPlayer
local username = player.Name

-- === Executors: Detect HTTP function ===
local request = http_request or request or (syn and syn.request)
if not request then
    warn("❌ Your executor does not support http_request.")
    return
end

-- === Place IDs ===
local LOBBY_PLACE_ID = 116495829188952
local GAME_PLACE_ID = 70876832253163

-- === Storage Path ===
local CONFIG_FOLDER = "joki_config"
local SAVE_FILE = CONFIG_FOLDER .. "/bond_data.json"

local canSave = isfile and writefile and readfile and makefolder
if canSave and not isfolder(CONFIG_FOLDER) then pcall(makefolder, CONFIG_FOLDER) end

-- === Bond Count Reference ===
local success, bondPath = pcall(function()
    return player:WaitForChild("PlayerGui")
        :WaitForChild("BondDisplay")
        :WaitForChild("BondInfo")
        :WaitForChild("BondCount")
end)

if not success or not bondPath then
    warn("❌ Bond GUI not found.")
    return
end

local function parseBond(str)
    local t = tostring(str or "")
    local clean = t:gsub(",", ""):match("%d+")
    return tonumber(clean) or 0
end

-- === Load Saved Config ===
local savedBond, savedUrl = 0, ""
if canSave and isfile(SAVE_FILE) then
    local ok, result = pcall(function()
        return HttpService:JSONDecode(readfile(SAVE_FILE))
    end)
    if ok and result then
        savedBond = tonumber(result.saved) or 0
        savedUrl = tostring(result.proxy or "")
    end
end

local currentBond = parseBond(bondPath.Text)

-- === Function to Send to Proxy ===
local function sendToProxy()
    if savedUrl == "" then
        warn("[Bond Tracker] ❌ No proxy URL.")
        return
    end
    if savedUrl:sub(-1) == "/" then
        savedUrl = savedUrl:sub(1, -2)
    end

    currentBond = parseBond(bondPath.Text)
    local payload = {
        username = username,
        bonds = currentBond,
        placeId = tostring(game.PlaceId)
    }

    print("[Bond Tracker] 📡 Sending to:", savedUrl .. "/bond")
    print(HttpService:JSONEncode(payload))

    local success, err = pcall(function()
        request({
            Url = savedUrl .. "/bond",
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode(payload)
        })
    end)
    if not success then
        warn("❌ Failed to send:", err)
    end
end

-- === Automatically send on gameplay ===
if game.PlaceId == GAME_PLACE_ID then
    task.delay(1.5, sendToProxy)
    return -- No UI on gameplay
end

-- === Lobby: Idle alert ===
if game.PlaceId == LOBBY_PLACE_ID then
    task.delay(60, function()
        if game.PlaceId == LOBBY_PLACE_ID and savedUrl ~= "" then
            local payload = {
                username = username,
                alert = "lobby_idle"
            }
            print("⚠️ Sending lobby idle alert...")
            pcall(function()
                request({
                    Url = savedUrl .. "/bond",
                    Method = "POST",
                    Headers = { ["Content-Type"] = "application/json" },
                    Body = HttpService:JSONEncode(payload)
                })
            end)
        end
    end)
end

-- === UI ===
pcall(function() CoreGui:FindFirstChild("BondTrackerUI"):Destroy() end)

local gui = Instance.new("ScreenGui", CoreGui)
gui.Name = "BondTrackerUI"
gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
gui.ResetOnSpawn = false

local frame = Instance.new("Frame", gui)
frame.Size = UDim2.new(0, 340, 0, 210)
frame.Position = UDim2.new(0.5, -170, 0.5, -105)
frame.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
frame.BorderColor3 = Color3.fromRGB(85, 85, 105)
frame.BorderSizePixel = 2
frame.Active = true
frame.Draggable = true
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel", frame)
title.Size = UDim2.new(1, 0, 0, 28)
title.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
title.Text = "🔎 Bond Tracker (Dead Rails)"
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.SourceSansBold
title.TextSize = 16

local bondLabel = Instance.new("TextLabel", frame)
bondLabel.Position = UDim2.new(0, 0, 0, 35)
bondLabel.Size = UDim2.new(1, 0, 0, 20)
bondLabel.BackgroundTransparency = 1
bondLabel.TextColor3 = Color3.new(1, 1, 1)
bondLabel.Text = "💰 Current Bonds: " .. currentBond
bondLabel.Font = Enum.Font.SourceSans
bondLabel.TextSize = 16

local diffLabel = Instance.new("TextLabel", frame)
diffLabel.Position = UDim2.new(0, 0, 0, 58)
diffLabel.Size = UDim2.new(1, 0, 0, 20)
diffLabel.BackgroundTransparency = 1
diffLabel.TextColor3 = Color3.new(1, 1, 1)
diffLabel.Text = "📈 Gained: " .. (currentBond - savedBond)
diffLabel.Font = Enum.Font.SourceSans
diffLabel.TextSize = 16

-- === Proxy URL Input ===
local urlBox = Instance.new("TextBox", frame)
urlBox.Position = UDim2.new(0.05, 0, 0, 85)
urlBox.Size = UDim2.new(0.9, 0, 0, 26)
urlBox.Text = savedUrl
urlBox.PlaceholderText = "https://your.proxy.url"
urlBox.TextColor3 = Color3.new(1, 1, 1)
urlBox.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
urlBox.BorderColor3 = Color3.fromRGB(85, 85, 105)
urlBox.Font = Enum.Font.SourceSans
urlBox.TextSize = 14
urlBox.ClearTextOnFocus = false
Instance.new("UICorner", urlBox).CornerRadius = UDim.new(0, 4)

-- === Buttons ===
local sendBtn = Instance.new("TextButton", frame)
sendBtn.Position = UDim2.new(0.1, 0, 0, 120)
sendBtn.Size = UDim2.new(0.35, 0, 0, 36)
sendBtn.Text = "Send"
sendBtn.Font = Enum.Font.SourceSansBold
sendBtn.TextColor3 = Color3.new(1, 1, 1)
sendBtn.BackgroundColor3 = Color3.fromRGB(88, 101, 242)
Instance.new("UICorner", sendBtn).CornerRadius = UDim.new(0, 6)

local resetBtn = Instance.new("TextButton", frame)
resetBtn.Position = UDim2.new(0.55, 0, 0, 120)
resetBtn.Size = UDim2.new(0.35, 0, 0, 36)
resetBtn.Text = "Reset"
resetBtn.Font = Enum.Font.SourceSansBold
resetBtn.TextColor3 = Color3.new(1, 1, 1)
resetBtn.BackgroundColor3 = Color3.fromRGB(231, 76, 60)
Instance.new("UICorner", resetBtn).CornerRadius = UDim.new(0, 6)

-- === Event Listeners ===
urlBox:GetPropertyChangedSignal("Text"):Connect(function()
    savedUrl = urlBox.Text
    if canSave then
        pcall(writefile, SAVE_FILE, HttpService:JSONEncode({ saved = savedBond, proxy = savedUrl }))
    end
end)

sendBtn.MouseButton1Click:Connect(function()
    sendBtn.Text = "Sending..."
    sendToProxy()
    task.delay(2, function() sendBtn.Text = "Send" end)
end)

resetBtn.MouseButton1Click:Connect(function()
    savedBond = parseBond(bondPath.Text)
    if canSave then
        pcall(writefile, SAVE_FILE, HttpService:JSONEncode({ saved = savedBond, proxy = savedUrl }))
    end
end)

task.spawn(function()
    while task.wait(1) do
        currentBond = parseBond(bondPath.Text)
        bondLabel.Text = "💰 Current Bonds: " .. currentBond
        diffLabel.Text = "📈 Gained: " .. (currentBond - savedBond)
    end
end)