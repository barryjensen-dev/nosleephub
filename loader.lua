if _G.NoSleepHubLoaded then return end
_G.NoSleepHubLoaded = true

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local localPlayer = Players.LocalPlayer

local toggles = {
    ESP = true,
    Skeleton = true,
    Aimlock = true,
    BulletFix = true,
    DistanceLines = true,
    SilentAim = true,
    Hitmarker = true,
    Crosshair = true,
    SpectatorList = true,
    PingDisplay = true
}

local keybinds = {
    ToggleUI = Enum.KeyCode.RightControl
}

-- Crosshair lines
local crosshairLines = {}

-- Spectator label setup
local SpectatorGui = Instance.new("ScreenGui")
SpectatorGui.Name = "NoSleepSpectators"
SpectatorGui.ResetOnSpawn = false
SpectatorGui.Parent = game:GetService("CoreGui")

local SpectatorLabel = Instance.new("TextLabel")
SpectatorLabel.Name = "SpectatorLabel"
SpectatorLabel.BackgroundTransparency = 0.4
SpectatorLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
SpectatorLabel.Position = UDim2.new(0.01, 0, 0.6, 0)
SpectatorLabel.Size = UDim2.new(0, 150, 0, 150)
SpectatorLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
SpectatorLabel.Font = Enum.Font.Code
SpectatorLabel.TextSize = 14
SpectatorLabel.TextWrapped = true
SpectatorLabel.Text = "Spectators:\nNone"
SpectatorLabel.Visible = toggles.SpectatorList
SpectatorLabel.Parent = SpectatorGui

-- Rayfield UI
local Window = Rayfield:CreateWindow({
    Name = "NoSleep Hub",
    LoadingTitle = "NoSleep Hub",
    LoadingSubtitle = "by Barry",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "NoSleepHub",
        FileName = "NoSleepHubConfig"
    },
    Discord = {
        Enabled = false,
        Invite = "", 
        RememberJoins = true 
    },
    KeySystem = false
})

local Tabs = {
    Main = Window:CreateTab("Main", 4483362458),
    Settings = Window:CreateTab("Settings", 4483362458)
}

local function createToggle(flag, name, default, callback)
    Tabs.Main:CreateToggle({
        Name = name,
        CurrentValue = default,
        Flag = flag,
        Callback = function(val)
            toggles[flag] = val
            if flag == "SpectatorList" and SpectatorLabel then
                SpectatorLabel.Visible = val
            elseif flag == "Crosshair" and crosshairLines and #crosshairLines > 0 then
                for _, line in ipairs(crosshairLines) do
                    line.Visible = val
                end
            elseif flag == "Aimlock" and fovCircle then
                fovCircle.Visible = val
            end
            if callback then callback(val) end
        end
    })
end

createToggle("ESP", "Enable ESP", toggles.ESP)
createToggle("Skeleton", "Enable Skeleton", toggles.Skeleton)
createToggle("Aimlock", "Enable Aimlock", toggles.Aimlock)
createToggle("BulletFix", "Bullet Correction", toggles.BulletFix)
createToggle("DistanceLines", "Distance Lines", toggles.DistanceLines)
createToggle("SilentAim", "Silent Aim", toggles.SilentAim)
createToggle("Hitmarker", "Hitmarker", toggles.Hitmarker)
createToggle("Crosshair", "Custom Crosshair", toggles.Crosshair)
createToggle("SpectatorList", "Spectator List", toggles.SpectatorList)
createToggle("PingDisplay", "Ping Display", toggles.PingDisplay)

-- UI Keybind
Tabs.Settings:CreateKeybind({
    Name = "Toggle UI Keybind",
    CurrentKeybind = keybinds.ToggleUI.Name,
    Default = keybinds.ToggleUI.Name,
    HoldToInteract = false,
    Mode = "Toggle",
    Flag = "ToggleUIKeybind",
    Callback = function(k)
        keybinds.ToggleUI = Enum.KeyCode[k] or keybinds.ToggleUI
    end
})

-- Placeholder visuals and loop handlers
local function findClosestTarget() return nil end
local function playerColor(plr) return Color3.fromRGB(255, 0, 0) end
local function updateESP(...) end
local function updateSkeleton(...) end
local function updateDistanceLine(...) end
local function updateHealthBar(...) end
local function setupVisuals(...) end
local function aimlockUpdate() end
local function tryAutoReload() end
local function fastEquipSwap() end
local function patchNoSpread() end
local function drawCrosshair() end
local function listenToHits(...) end

local fovCircle = Drawing.new("Circle")
fovCircle.Thickness = 2
fovCircle.Radius = 100
fovCircle.Color = Color3.fromRGB(255, 255, 255)
fovCircle.Visible = toggles.Aimlock

-- Spectator logic
local function updateSpectators()
    if not toggles.SpectatorList then
        if SpectatorLabel then SpectatorLabel.Visible = false end
        return
    end
    if SpectatorLabel then
        SpectatorLabel.Visible = true
        local spectators = {}
        for _, pl in pairs(Players:GetPlayers()) do
            if pl ~= localPlayer and pl.Character and pl.Character:FindFirstChild("Humanoid") and pl.Character.Humanoid.Health > 0 then
                local cam = pl.Character:FindFirstChild("Head")
                if cam then
                    local cameraFocus = Camera.Focus.Position
                    if (cam.Position - cameraFocus).Magnitude < 15 then
                        table.insert(spectators, pl.Name)
                    end
                end
            end
        end
        SpectatorLabel.Text = (#spectators == 0) and "Spectators:\nNone" or "Spectators:\n" .. table.concat(spectators, "\n")
    end
end

-- Input handler
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == keybinds.ToggleUI then
        for key, val in pairs(toggles) do
            toggles[key] = not val
        end
        if fovCircle then fovCircle.Visible = toggles.Aimlock end
        if crosshairLines and #crosshairLines > 0 then
            for _, line in ipairs(crosshairLines) do
                line.Visible = toggles.Crosshair
            end
        end
        if SpectatorLabel then
            SpectatorLabel.Visible = toggles.SpectatorList
        end
    end
end)

-- Main render loop
RunService.RenderStepped:Connect(function()
    cachedClosestTarget = findClosestTarget()
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl.Character and pl.Character:FindFirstChild("HumanoidRootPart") and pl ~= localPlayer then
            local col = playerColor(pl)
            updateESP(pl, pl.Character, col)
            updateSkeleton(pl, pl.Character, col)
            updateDistanceLine(pl, pl.Character, col)
            updateHealthBar(pl, pl.Character)
            setupVisuals(pl)
        end
    end
    aimlockUpdate()
    tryAutoReload()
    fastEquipSwap()
    patchNoSpread()
    drawCrosshair()
    updateSpectators()
end)

-- Initial setup
Players.PlayerAdded:Connect(function(pl)
    setupVisuals(pl)
    pl.CharacterAdded:Connect(function(char)
        setupVisuals(pl)
        listenToHits(pl)
    end)
end)

for _, pl in ipairs(Players:GetPlayers()) do
    setupVisuals(pl)
    if pl.Character then
        listenToHits(pl)
    end
end

print("[NoSleepHub] Loaded successfully.")
