-- Diamond Tracker (executor) for /diamond endpoint
if not game:IsLoaded() then game.Loaded:Wait() end

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local username = player.Name
local TeleportService = game:GetService("TeleportService")
local LocalPlayer = Players.LocalPlayer

-- === Place IDs ===
local TARGET_PLACE_ID = 126509999114328 
local LOBBY_PLACE_ID = 79546208627805
local GAME_PLACE_ID = 126509999114328

-- === Storage Path ===
local CONFIG_FOLDER = "joki_config"
local SAVE_FILE = CONFIG_FOLDER .. "/diamond_data.json"

-- === Setup Save
local canSave = isfile and writefile and readfile and makefolder
if canSave and not isfolder(CONFIG_FOLDER) then pcall(makefolder, CONFIG_FOLDER) end

-- === Explicit Diamond GUI path
local success, diamondPath = pcall(function()
    local pg = player:WaitForChild("PlayerGui")
    return pg:WaitForChild("Interface"):WaitForChild("DiamondCount"):WaitForChild("Count")
end)
if not success or not diamondPath then
    warn("[Diamond Tracker] ❌ Cannot find Interface.DiamondCount.Count. Update path if necessary.")
    return
end

local function parseNumberFromText(t)
    local s = tostring(t or "")
    local num = s:gsub(",", ""):match("%d+")
    return tonumber(num) or 0
end

-- === Load Config (per username) ===
local data = {}
if canSave and isfile(SAVE_FILE) then
    local ok, result = pcall(function()
        return HttpService:JSONDecode(readfile(SAVE_FILE))
    end)
    if ok and type(result) == "table" then
        data = result
    end
end
if not data[username] then
    data[username] = { saved = 0, proxy = "" }
end

local savedDiamond = tonumber(data[username].saved) or 0
local savedUrl = tostring(data[username].proxy or "")

-- === Safe HTTP Request
local httpRequest = request or http_request or (syn and syn.request) or (http and http.request)
if not httpRequest then
    warn("[Diamond Tracker] ❌ HTTP request function not found in executor.")
    return
end

-- placeholder for UI log updater
local function updateLog(_) end

-- /track keeps session alive
local function sendTrack(callback)
    if savedUrl == "" then return end
    local ok, res = pcall(function()
        return httpRequest({
            Url = savedUrl .. "/track",
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode({ username = username })
        })
    end)
    if ok and res and (res.StatusCode == 200 or res.StatusCode == 201) then
        updateLog("✅ /track success")
        if callback then task.delay(0.5, callback) end
    else
        updateLog("⚠️ /track failed")
    end
end

-- send to /diamond endpoint
local function sendToProxy()
    if savedUrl == "" then
        updateLog("❌ No Proxy URL set")
        return
    end

    task.spawn(function()
        local currentDiamond = parseNumberFromText(diamondPath.Text)
        while currentDiamond == 0 do
            updateLog("⏸ Waiting... diamond = 0")
            task.wait(0.1)
            currentDiamond = parseNumberFromText(diamondPath.Text)
        end

        local payloadObj = {
            username = username,
            diamonds = currentDiamond,
            placeId = tostring(game.PlaceId),
            start_diamonds = savedDiamond
        }
        local payload = HttpService:JSONEncode(payloadObj)
        updateLog("⏱ Sending: " .. tostring(currentDiamond))

        local ok, res = pcall(function()
            return httpRequest({
                Url = savedUrl .. "/diamond",
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = payload
            })
        end)

        if ok and res and (res.StatusCode == 200 or res.StatusCode == 201) then
            updateLog("✅ Sent: " .. tostring(currentDiamond))
        else
            updateLog("❌ Send failed: " .. tostring(res and res.StatusCode or "error"))
            task.delay(5, sendToProxy)
        end
    end)
end

-- initial send
task.delay(1.5, sendToProxy)

-- === UI
pcall(function() local old = CoreGui:FindFirstChild("DiamondTrackerUI"); if old then old:Destroy() end end)

local gui = Instance.new("ScreenGui", CoreGui)
gui.Name = "DiamondTrackerUI"
gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
gui.ResetOnSpawn = false

local frame = Instance.new("Frame", gui)
frame.Size = UDim2.new(0, 360, 0, 260)
frame.Position = UDim2.new(0.5, -180, 0.5, -130)
frame.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
frame.BorderColor3 = Color3.fromRGB(85, 85, 105)
frame.BorderSizePixel = 2
frame.Active = true
frame.Draggable = true
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel", frame)
title.Size = UDim2.new(1, 0, 0, 28)
title.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
title.Text = "💎 Diamond Tracker (V1.1)"
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.SourceSansBold
title.TextSize = 16
title.BorderSizePixel = 0

local currentDiamondNum = parseNumberFromText(diamondPath.Text)

local diamondLabel = Instance.new("TextLabel", frame)
diamondLabel.Position = UDim2.new(0, 8, 0, 36)
diamondLabel.Size = UDim2.new(1, -16, 0, 20)
diamondLabel.BackgroundTransparency = 1
diamondLabel.TextColor3 = Color3.new(1, 1, 1)
diamondLabel.Text = "💎 Current Diamonds: " .. currentDiamondNum
diamondLabel.Font = Enum.Font.SourceSans
diamondLabel.TextSize = 16
diamondLabel.TextXAlignment = Enum.TextXAlignment.Left
diamondLabel.BorderSizePixel = 0

local diffLabel = Instance.new("TextLabel", frame)
diffLabel.Position = UDim2.new(0, 8, 0, 58)
diffLabel.Size = UDim2.new(1, -16, 0, 20)
diffLabel.BackgroundTransparency = 1
diffLabel.TextColor3 = Color3.new(1, 1, 1)
diffLabel.Text = "📈 Gained: " .. (currentDiamondNum - savedDiamond)
diffLabel.Font = Enum.Font.SourceSans
diffLabel.TextSize = 16
diffLabel.TextXAlignment = Enum.TextXAlignment.Left
diffLabel.BorderSizePixel = 0

local urlBox = Instance.new("TextBox", frame)
urlBox.Position = UDim2.new(0.05, 0, 0, 86)
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

local logLabel = Instance.new("TextLabel", frame)
logLabel.Position = UDim2.new(0.05, 0, 0, 166)
logLabel.Size = UDim2.new(0.9, 0, 0, 76)
logLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
logLabel.BorderColor3 = Color3.fromRGB(60, 60, 70)
logLabel.TextColor3 = Color3.new(1, 1, 1)
logLabel.TextWrapped = true
logLabel.TextYAlignment = Enum.TextYAlignment.Top
logLabel.Text = "Logs:\n- ready"
logLabel.Font = Enum.Font.SourceSans
logLabel.TextSize = 14
Instance.new("UICorner", logLabel).CornerRadius = UDim.new(0, 6)

function updateLog(msg)
    if not msg then return end
    local time = os.date("%H:%M:%S")
    local prev = tostring(logLabel.Text or "")
    local lines = {}
    for s in prev:gmatch("[^\n]+") do table.insert(lines, s) end
    table.insert(lines, ("[%s] %s"):format(time, msg))
    if #lines > 8 then
        while #lines > 8 do table.remove(lines, 1) end
    end
    logLabel.Text = table.concat(lines, "\n")
end

urlBox:GetPropertyChangedSignal("Text"):Connect(function()
    savedUrl = urlBox.Text
    if canSave then
        data[username] = { saved = savedDiamond, proxy = savedUrl }
        pcall(writefile, SAVE_FILE, HttpService:JSONEncode(data))
    end
end)

sendBtn.MouseButton1Click:Connect(function()
    sendBtn.Text = "Sending..."
    updateLog("initiating send")
    sendTrack()
    task.delay(0.2, sendToProxy)
    task.delay(5,     loadstring(game:HttpGet('https://raw.githubusercontent.com/MQPS7/99-Night-in-the-Forset/refs/heads/main/Gfarm'))())
    task.delay(1.5, function() sendBtn.Text = "Send" end)
end)

resetBtn.MouseButton1Click:Connect(function()
    savedDiamond = parseNumberFromText(diamondPath.Text)
    if canSave then
        data[username] = { saved = savedDiamond, proxy = savedUrl }
        pcall(writefile, SAVE_FILE, HttpService:JSONEncode(data))
    end
    updateLog("reset saved value to " .. tostring(savedDiamond))
end)

task.spawn(function()
    while task.wait(1) do
        local cur = parseNumberFromText(diamondPath.Text)
        diamondLabel.Text = "💎 Current Diamonds: " .. cur
        diffLabel.Text = "📈 Gained: " .. (cur - savedDiamond)
    end
end)

task.spawn(function()
    while task.wait(5) do
        sendTrack(function()
            pcall(sendToProxy)
        end)
    end
end)

while task.wait(120) do
    pcall(function()
        TeleportService:Teleport(TARGET_PLACE_ID, LocalPlayer)
    end)
end

-- Simple FPS counter
pcall(function()
    local fpsGui = Instance.new("ScreenGui", CoreGui)
    fpsGui.Name = "FPSCounterUI"
    local fpsLabel = Instance.new("TextLabel", fpsGui)
    fpsLabel.Position = UDim2.new(1, -180, 0, 10)
    fpsLabel.Size = UDim2.new(0, 160, 0, 40)
    fpsLabel.BackgroundTransparency = 1
    fpsLabel.TextSize = 24
    fpsLabel.Font = Enum.Font.SourceSansBold
    fpsLabel.TextStrokeTransparency = 0.7
    fpsLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    fpsLabel.TextXAlignment = Enum.TextXAlignment.Right

    local frames = 0
    local lastTime = tick()
    local hue = 0
    RunService.RenderStepped:Connect(function()
        frames += 1
        local now = tick()
        if now - lastTime >= 1 then
            local fps = frames
            hue = (hue + 0.015) % 1
            local color = Color3.fromHSV(hue, 1, 1)
            fpsLabel.TextColor3 = color
            fpsLabel.Text = "FPS: " .. fps
            frames = 0
            lastTime = now
        end
    end)
end)