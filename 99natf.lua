if not game:IsLoaded() then game.Loaded:Wait() end
-- Rainbow FPS Counter
local RunService = game:GetService("RunService")
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

-- FPS calculation
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