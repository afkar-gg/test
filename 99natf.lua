-- Diamond Tracker (executor) for "Diamonds" type
if not game:IsLoaded() then game.Loaded:Wait() end

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local username = player.Name

-- === Place IDs (keep as-is or replace with your game's IDs) ===
local LOBBY_PLACE_ID = 116495829188952
local GAME_PLACE_ID = 70876832253163

-- === Storage Path ===
local CONFIG_FOLDER = "joki_config"
local SAVE_FILE = CONFIG_FOLDER .. "/diamond_data.json"

-- === Setup Save
local canSave = isfile and writefile and readfile and makefolder
if canSave and not isfolder(CONFIG_FOLDER) then pcall(makefolder, CONFIG_FOLDER) end

-- === Diamond GUI lookup (tries multiple fallbacks) ===
local success, diamondPath = pcall(function()
	local pg = player:WaitForChild("PlayerGui")

	-- Explicit known path first
	if pg:FindFirstChild("DiamondDisplay") then
		local dd = pg:WaitForChild("DiamondDisplay")
		if dd:FindFirstChild("DiamondInfo") and dd.DiamondInfo:FindFirstChild("DiamondCount") then
			return dd.DiamondInfo.DiamondCount
		end
	end

	-- Fallback to BondDisplay for reuse in games that still use the same UI
	if pg:FindFirstChild("BondDisplay") then
		local bd = pg:WaitForChild("BondDisplay")
		if bd:FindFirstChild("BondInfo") and bd.BondInfo:FindFirstChild("BondCount") then
			return bd.BondInfo.BondCount
		end
	end

	-- Generic search: first TextLabel/TextBox with name hint
	for _, obj in ipairs(pg:GetDescendants()) do
		if (obj:IsA("TextLabel") or obj:IsA("TextBox")) then
			local n = obj.Name:lower()
			if n:find("diamond") or n:find("diamondcount") or n:find("count") or n:find("gem") then
				return obj
			end
		end
	end

	-- Last resort: any numeric-looking TextLabel near top-level UI
	for _, obj in ipairs(pg:GetDescendants()) do
		if (obj:IsA("TextLabel") or obj:IsA("TextBox")) and tostring(obj.Text):match("%d") then
			return obj
		end
	end

	return nil
end)

if not success or not diamondPath then
	warn("[Diamond Tracker] ❌ GUI path not found. Update lookup if UI names differ.")
	return
end

local function parseNumber(str)
	local clean = tostring(str or ""):gsub(",", ""):match("%d+")
	return tonumber(clean) or 0
end

-- === Load Config
local savedDiamond, savedUrl = 0, ""
if canSave and isfile(SAVE_FILE) then
	local ok, result = pcall(function()
		return HttpService:JSONDecode(readfile(SAVE_FILE))
	end)
	if ok and result then
		savedDiamond = tonumber(result.saved) or 0
		savedUrl = tostring(result.proxy or "")
	end
end

local currentDiamond = parseNumber(diamondPath.Text)

-- === Safe HTTP Request detection
local httpRequest = request or http_request or (syn and syn.request) or (http and http.request)
if not httpRequest then
	warn("[Diamond Tracker] ❌ HTTP request function not found in executor.")
	return
end

-- send /track to notify server we joined (keeps session alive)
local function sendTrack(callback)
	local ok, res = pcall(function()
		return httpRequest({
			Url = savedUrl .. "/track",
			Method = "POST",
			Headers = { ["Content-Type"] = "application/json" },
			Body = HttpService:JSONEncode({ username = username })
		})
	end)

	if ok and res and (res.StatusCode == 200 or res.StatusCode == 201) then
		print("[Diamond Tracker] ✅ /track success")
		if callback then task.delay(0.5, callback) end
	else
		warn("[Diamond Tracker] ❌ /track failed")
	end
end

local function sendToProxy()
	if savedUrl == "" then
		warn("[Diamond Tracker] ❌ No Proxy URL Set")
		return
	end

	currentDiamond = parseNumber(diamondPath.Text)
	print("[Diamond Tracker] ⏱ Sending diamonds:", currentDiamond)

	local body = {
		username = username,
		diamonds = currentDiamond,
		placeId = tostring(game.PlaceId)
	}
	local payload = HttpService:JSONEncode(body)

	local ok, res = pcall(function()
		return httpRequest({
			Url = savedUrl .. "/diamond",
			Method = "POST",
			Headers = { ["Content-Type"] = "application/json" },
			Body = payload
		})
	end)

	if ok and res and (res.StatusCode == 200 or res.StatusCode == 201) then
		print("[Diamond Tracker] ✅ Sent to Proxy:", payload)
	else
		warn("[Diamond Tracker] ❌ Failed to send:", res and res.StatusCode or "error")
		-- Retry once after 5 seconds
		task.delay(5, sendToProxy)
	end
end

-- Initial send after small delay to allow UI to initialize
task.delay(1.5, sendToProxy)

-- If in-game place, run periodic updates
if game.PlaceId == GAME_PLACE_ID then
	task.spawn(function()
		while true do
			task.wait(1) -- small tick
			currentDiamond = parseNumber(diamondPath.Text)
			sendToProxy()
			task.wait(240) -- 4 minutes between heavy cycles (keeps heartbeat)
			-- optional force respawn to avoid soft-locks in some executors
			if player and player.Character then
				pcall(function() player.Character:BreakJoints() end)
			end
		end
	end)
end

-- === Lobby timeout alert
if game.PlaceId == LOBBY_PLACE_ID then
	task.delay(60, function()
		if savedUrl and savedUrl ~= "" then
			local body = HttpService:JSONEncode({
				username = username,
				alert = "lobby_idle"
			})
			pcall(function()
				httpRequest({
					Url = savedUrl .. "/diamond",
					Method = "POST",
					Headers = { ["Content-Type"] = "application/json" },
					Body = body
				})
			end)
			print("[Diamond Tracker] ⚠️ Sent idle alert to proxy.")
		end
	end)
end

-- === UI (simple control panel)
pcall(function() CoreGui:FindFirstChild("DiamondTrackerUI"):Destroy() end)

local gui = Instance.new("ScreenGui", CoreGui)
gui.Name = "DiamondTrackerUI"
gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
gui.ResetOnSpawn = false

local frame = Instance.new("Frame", gui)
frame.Size = UDim2.new(0, 360, 0, 220)
frame.Position = UDim2.new(0.5, -180, 0.5, -110)
frame.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
frame.BorderColor3 = Color3.fromRGB(85, 85, 105)
frame.BorderSizePixel = 2
frame.Active = true
frame.Draggable = true
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel", frame)
title.Size = UDim2.new(1, 0, 0, 28)
title.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
title.Text = "🔎 Diamond Tracker (V1.0.0)"
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.SourceSansBold
title.TextSize = 16

local diamondLabel = Instance.new("TextLabel", frame)
diamondLabel.Position = UDim2.new(0, 0, 0, 36)
diamondLabel.Size = UDim2.new(1, 0, 0, 20)
diamondLabel.BackgroundTransparency = 1
diamondLabel.TextColor3 = Color3.new(1, 1, 1)
diamondLabel.Text = "💎 Current Diamonds: " .. currentDiamond
diamondLabel.Font = Enum.Font.SourceSans
diamondLabel.TextSize = 16

local diffLabel = Instance.new("TextLabel", frame)
diffLabel.Position = UDim2.new(0, 0, 0, 58)
diffLabel.Size = UDim2.new(1, 0, 0, 20)
diffLabel.BackgroundTransparency = 1
diffLabel.TextColor3 = Color3.new(1, 1, 1)
diffLabel.Text = "📈 Gained: " .. (currentDiamond - savedDiamond)
diffLabel.Font = Enum.Font.SourceSans
diffLabel.TextSize = 16

-- Proxy URL input
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

-- Events
urlBox:GetPropertyChangedSignal("Text"):Connect(function()
	savedUrl = urlBox.Text
	if canSave then
		pcall(writefile, SAVE_FILE, HttpService:JSONEncode({ saved = savedDiamond, proxy = savedUrl }))
	end
end)

sendBtn.MouseButton1Click:Connect(function()
	sendBtn.Text = "Sending..."
	sendTrack()
	task.delay(0.2, function() sendToProxy() end)
	task.delay(1.5, function() sendBtn.Text = "Send" end)
end)

resetBtn.MouseButton1Click:Connect(function()
	savedDiamond = currentDiamond
	if canSave then
		pcall(writefile, SAVE_FILE, HttpService:JSONEncode({ saved = savedDiamond, proxy = savedUrl }))
	end
end)

-- Live UI Update
task.spawn(function()
	while task.wait(1) do
		currentDiamond = parseNumber(diamondPath.Text)
		diamondLabel.Text = "💎 Current Diamonds: " .. currentDiamond
		diffLabel.Text = "📈 Gained: " .. (currentDiamond - savedDiamond)
	end
end)

-- Simple FPS counter (optional)
local fpsGui = Instance.new("ScreenGui", CoreGui)
fpsGui.Name = "FPSCounterUI"
local fpsLabel = Instance.new("TextLabel", fpsGui)
fpsLabel.Position = UDim2.new(1, -180, 0, 10)
fpsLabel.Size = UDim2.new(0, 160, 0, 40)
fpsLabel.BackgroundTransparency = 1
fpsLabel.TextSize = 32
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