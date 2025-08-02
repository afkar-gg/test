if not game:IsLoaded() then game.Loaded:Wait() end

local HttpService      = game:GetService("HttpService")
local Players          = game:GetService("Players")
local CoreGui          = game:GetService("CoreGui")
local TeleportService  = game:GetService("TeleportService")
local player           = Players.LocalPlayer

local request = http_request or (syn and syn.request) or request
if not request then
    warn("❌ This executor doesn't support HTTP requests.")
    return
end

-- Config
local folder = "joki_config"
local file   = folder .. "/proxy_url.json"
local canSave = writefile and readfile and isfile and makefolder
if canSave and not isfolder(folder) then pcall(makefolder, folder) end

local savedUrl = ""
if canSave and isfile(file) then
    local ok, result = pcall(readfile, file)
    if ok and result then
        local success, data = pcall(function() return HttpService:JSONDecode(result) end)
        if success and data and typeof(data) == "table" then
            savedUrl = data.proxy_url or ""
        end
    end
end

-- UI Setup
pcall(function() CoreGui:FindFirstChild("JokiUI"):Destroy() end)
local gui = Instance.new("ScreenGui", CoreGui); gui.Name = "JokiUI"; gui.ResetOnSpawn = false
local frame = Instance.new("Frame", gui); frame.Size = UDim2.new(0,360,0,260)
frame.Position = UDim2.new(0.5,-180,0.5,-120)
frame.BackgroundColor3 = Color3.fromRGB(35,35,45); frame.Active, frame.Draggable = true,true
Instance.new("UICorner", frame).CornerRadius = UDim.new(0,8)

local title = Instance.new("TextLabel", frame)
title.Size = UDim2.new(1,-30,0,30); title.Position = UDim2.new(0,10,0,0)
title.BackgroundTransparency = 1; title.Text = "Roblox Joki Panel (GAG) v2.3.0"
title.Font = Enum.Font.SourceSansBold; title.TextSize = 16; title.TextColor3 = Color3.new(1,1,1)
title.TextXAlignment = Enum.TextXAlignment.Left

local urlBox = Instance.new("TextBox", frame)
urlBox.Size = UDim2.new(0.9,0,0,30); urlBox.Position = UDim2.new(0.05,0,0,40)
urlBox.PlaceholderText = "Paste Proxy URL (https://...)"; urlBox.Text = savedUrl
urlBox.Font = Enum.Font.SourceSans; urlBox.TextSize = 14; urlBox.TextColor3 = Color3.new(1,1,1)
urlBox.BackgroundColor3 = Color3.fromRGB(25,25,35)
Instance.new("UICorner", urlBox).CornerRadius = UDim.new(0,4)
urlBox.FocusLost:Connect(function()
    if canSave then pcall(writefile, file, HttpService:JSONEncode({ proxy_url = urlBox.Text })) end
end)

local status = Instance.new("TextLabel", frame)
status.Size = UDim2.new(0.9,0,0,20); status.Position = UDim2.new(0.05,0,0,75)
status.BackgroundTransparency = 1; status.Text = ""; status.TextColor3 = Color3.new(1,1,1)
status.Font = Enum.Font.SourceSans; status.TextSize = 14

-- Buttons
local execBtn = Instance.new("TextButton", frame)
execBtn.Size = UDim2.new(0.42,0,0,34); execBtn.Position = UDim2.new(0.05,0,0,105)
execBtn.Text = "🚀 Send"; execBtn.Font = Enum.Font.SourceSansBold; execBtn.TextColor3 = Color3.new(1,1,1)
execBtn.BackgroundColor3 = Color3.fromRGB(88,101,242); Instance.new("UICorner", execBtn).CornerRadius = UDim.new(0,6)

local jobBtn = Instance.new("TextButton", frame)
jobBtn.Size = execBtn.Size; jobBtn.Position = UDim2.new(0.53,0,0,105)
jobBtn.Text = "🧩 Send Job ID"; jobBtn.Font = Enum.Font.SourceSansBold; jobBtn.TextColor3 = Color3.new(1,1,1)
jobBtn.BackgroundColor3 = Color3.fromRGB(52,152,219); Instance.new("UICorner", jobBtn).CornerRadius = UDim.new(0,6)

local uploadBtn = Instance.new("TextButton", frame)
uploadBtn.Size = execBtn.Size; uploadBtn.Position = UDim2.new(0.05,0,0,150)
uploadBtn.Text = "📤 Upload GAG Data"; uploadBtn.Font = Enum.Font.SourceSansBold
uploadBtn.TextColor3 = Color3.new(1,1,1); uploadBtn.BackgroundColor3 = Color3.fromRGB(34,197,94)
Instance.new("UICorner", uploadBtn).CornerRadius = UDim.new(0,6)

-- Auto-download GAG data if exists on server
do
    if savedUrl ~= "" then
        local ok,res = pcall(function()
            return request({Url = savedUrl.."/download-gag-data?username="..player.Name, Method="GET"})
        end)
        if ok and res and res.StatusCode == 200 then
            if canSave then
                if not isfolder("SpeedHubX") then makefolder("SpeedHubX") end
                writefile("SpeedHubX/Grow A Garden.json", res.Body)
            end
            status.Text = "✅ GAG data downloaded"
        else
            status.Text = "⚠️ No GAG data on server"
        end
    end
end

-- Button logic
jobBtn.MouseButton1Click:Connect(function()
    local proxy = urlBox.Text
    if proxy == "" then status.Text = "❌ URL missing"; return end
    local body = HttpService:JSONEncode({
        username = player.Name,
        placeId = tostring(game.PlaceId),
        jobId = tostring(game.JobId),
        join_url = proxy.."/join?place="..game.PlaceId.."&job="..game.JobId
    })
    local ok = pcall(function()
        request({Url = proxy.."/send-job", Method="POST", Headers={["Content-Type"]="application/json"}, Body=body})
    end)
    status.Text = ok and "✅ Job ID sent!" or "❌ Send failed"
end)

uploadBtn.MouseButton1Click:Connect(function()
    local proxy = urlBox.Text
    if proxy == "" then status.Text = "❌ URL missing"; return end
    local path = "SpeedHubX/Grow A Garden.json"
    if not isfile(path) then status.Text = "❌ GAG file missing"; return end
    local ok,content = pcall(readfile, path)
    if not ok then status.Text = "❌ Read failed"; return end
    local ok2,decoded = pcall(HttpService.JSONDecode, HttpService, content)
    if not ok2 then status.Text = "❌ JSON invalid"; return end
    local payload = HttpService:JSONEncode({ username = player.Name, data = decoded })
    local ok3 = pcall(function()
        request({Url = proxy.."/upload-gag-data", Method="POST", Headers={["Content-Type"]="application/json"}, Body=payload})
    end)
    status.Text = ok3 and "✅ GAG uploaded" or "❌ Upload failed"
end)

execBtn.MouseButton1Click:Connect(function()
    local proxy = urlBox.Text
    if proxy == "" then status.Text = "❌ Missing URL"; return end

    local checking, kicked = true, false
    local kickReason = "unknown"

    player.AncestryChanged:Connect(function(_, parent)
        if not parent then kicked = true; checking = false; kickReason = "Disconnected" end
    end)

    pcall(function()
        TeleportService.TeleportInitFailed:Connect(function(_, msg)
            kicked = true; checking = false; kickReason = "Teleport failed: " .. msg
        end)
    end)

    local ok, res = pcall(function()
        return request({
            Url = proxy.."/track",
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode({ username = player.Name })
        })
    end)
    if not ok or not res or res.StatusCode ~= 200 then status.Text = "❌ /track failed"; return end

    local data = HttpService:JSONDecode(res.Body)
    local endTime = tonumber(data.endTime)
    if not endTime then status.Text = "❌ No endTime"; return end

    status.Text = "✅ Session started"
    task.spawn(function()
        while checking and os.time() < math.floor(endTime / 1000) do
            local left = math.floor(endTime / 1000) - os.time()
            status.Text = string.format("⏳ %02d:%02d left", left // 60, left % 60)
            pcall(function()
                request({
                    Url = proxy.."/check",
                    Method = "POST",
                    Headers = {["Content-Type"] = "application/json"},
                    Body = HttpService:JSONEncode({ username = player.Name })
                })
            end)
            task.wait(5)
        end
        if kicked then
            status.Text = "🛑 Disconnected – notifying..."
            pcall(function()
                request({
                    Url = proxy.."/disconnected",
                    Method = "POST",
                    Headers = {["Content-Type"] = "application/json"},
                    Body = HttpService:JSONEncode({
                        username = player.Name,
                        reason = kickReason,
                        placeId = tostring(game.PlaceId)
                    })
                })
            end)
            task.wait(1)
            game:Shutdown()
        else
            pcall(function()
                request({
                    Url = proxy.."/complete",
                    Method = "POST",
                    Headers = {["Content-Type"] = "application/json"},
                    Body = HttpService:JSONEncode({ username = player.Name })
                })
            end)
            status.Text = "✅ Joki completed"
        end
    end)
end)