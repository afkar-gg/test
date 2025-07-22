if not game:IsLoaded() then game.Loaded:Wait() end

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local player = Players.LocalPlayer
local username = player.Name

-- === Place IDs ===
local LOBBY_PLACE_ID = 116495829188952
local GAME_PLACE_ID = 70876832253163

-- === Storage Path ===
local CONFIG_FOLDER = "joki_config"
local SAVE_FILE = CONFIG_FOLDER .. "/bond_data.json"

-- === Setup Save
local canSave = isfile and writefile and readfile and makefolder
if canSave and not isfolder(CONFIG_FOLDER) then pcall(makefolder, CONFIG_FOLDER) end

-- === Bond Reference
local success, bondPath = pcall(function()
	return player:WaitForChild("PlayerGui")
		:WaitForChild("BondDisplay")
		:WaitForChild("BondInfo")
		:WaitForChild("BondCount")
end)

if not success or not bondPath then
	warn("[Bond Tracker] ❌ GUI path not found.")
	return
end

local function parseBond(str)
	local clean = tostring(str or ""):gsub(",", ""):match("%d+")
	return tonumber(clean) or 0
end

-- === Load Config
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

-- === Safe HTTP Request
local httpRequest = request or http_request or (syn and syn.request)
if not httpRequest then
	warn("[Bond Tracker] ❌ HTTP request function not found in executor.")
	return
end

local function sendTrack()
	local response
	local success, err = pcall(function()
		response = request({
			Url = savedUrl .. "/track",
			Method = "POST",
			Headers = {["Content-Type"] = "application/json"},
			Body = HttpService:JSONEncode({ username = username })
		})
	end)

	if success and response and response.StatusCode == 200 then
		print("✅ /track called successfully.")
	else
		warn("❌ Failed to call /track", err or response.StatusCode)
	end
end

local function sendToProxy()
  if savedUrl == "" then
    warn("[Bond Tracker] ❌ No Proxy URL Set")
    return
  end

  currentBond = parseBond(bondPath.Text)
  print("[Bond Tracker] ⏱ Sending bond:", currentBond)

  local body = {
    username = username,
    bonds = currentBond,
    placeId = tostring(game.PlaceId)
  }

  local payload = HttpService:JSONEncode(body)

  local success, res = pcall(function()
    return httpRequest({
      Url = savedUrl .. "/bond",
      Method = "POST",
      Headers = { ["Content-Type"] = "application/json" },
      Body = payload
    })
  end)

  if success and res and res.StatusCode == 200 then
    print("[Bond Tracker] ✅ Sent to Proxy:", payload)
  else
    warn("[Bond Tracker] ❌ Failed to send:", res and res.StatusCode or "error")
    -- Retry once after 5 seconds
    task.delay(5, sendToProxy)
  end
end

task.delay(1.5, sendToProxy)

if game.PlaceId == GAME_PLACE_ID then
    task.spawn(function()
        while true do
            task.wait(1) -- Sends update every 1 seconds
            currentBond = parseBond(bondPath.Text)
            sendToProxy()
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
					Url = savedUrl .. "/bond",
					Method = "POST",
					Headers = { ["Content-Type"] = "application/json" },
					Body = body
				})
			end)
			print("[Bond Tracker] ⚠️ Sent idle alert to proxy.")
		end
	end)
end

-- === UI
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

-- Proxy URL
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

-- Buttons
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

-- Event Handlers
urlBox:GetPropertyChangedSignal("Text"):Connect(function()
	savedUrl = urlBox.Text
	if canSave then
		pcall(writefile, SAVE_FILE, HttpService:JSONEncode({ saved = savedBond, proxy = savedUrl }))
	end
end)

sendBtn.MouseButton1Click:Connect(function()
	sendBtn.Text = "Sending..."

	sendTrack()

	task.delay(0.2, function()
		sendToProxy()
	end)

	task.delay(1.5, function()
		sendBtn.Text = "Send"
	end)
end)

resetBtn.MouseButton1Click:Connect(function()
	savedBond = currentBond
	if canSave then
		pcall(writefile, SAVE_FILE, HttpService:JSONEncode({ saved = savedBond, proxy = savedUrl }))
	end
end)

-- Live UI Update
task.spawn(function()
	while task.wait(1) do
		currentBond = parseBond(bondPath.Text)
		bondLabel.Text = "💰 Current Bonds: " .. currentBond
		diffLabel.Text = "📈 Gained: " .. (currentBond - savedBond)
	end
end)