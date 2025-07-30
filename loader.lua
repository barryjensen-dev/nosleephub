if _G.NoSleepHubLoaded then return end
_G.NoSleepHubLoaded = true

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local localPlayer = Players.LocalPlayer

-- Toggles and default states
local toggles = {
    ESP = true,
    Skeleton = true,
    Aimlock = true,
    BulletFix = true,
    DistanceLines = true,
    SilentAim = true,
    AutoReload = false,
    FastEquipSwap = false,
    NoSpread = false,
    Hitmarker = true,
    Crosshair = true,
    SpectatorList = true,
    PingDisplay = true,
}

local keybinds = {
    ToggleUI = Enum.KeyCode.RightShift,
}

local boneSelection = "Head"
local aimSmoothness = 0.25
local fovRadius = 120
local fovColor = Color3.fromRGB(0, 255, 255)

local cachedClosestTarget = nil

-- Setup Rayfield UI
local Window = Rayfield:CreateWindow({
    Name = "NoSleep Hub",
    LoadingTitle = "NoSleep Hub",
    LoadingSubtitle = "by Barry Jensen",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "NoSleepHub",
        FileName = "Config",
    },
    Discord = {
        Enabled = false,
        Invite = "",
    },
    KeySystem = false,
})

local Tabs = {}

Tabs.Main = Window:CreateTab("Main")
Tabs.Settings = Window:CreateTab("Settings")
Tabs.Misc = Window:CreateTab("Misc")

-- UI Toggles
local uiToggles = {}

local function createToggle(name, description, default, callback)
    uiToggles[name] = Tabs.Main:CreateToggle({
        Name = name,
        CurrentValue = default,
        Flag = name,
        Description = description,
        Callback = function(val)
            toggles[name] = val
            callback(val)
        end,
    })
end

-- Create toggles for all features
createToggle("ESP", "Show ESP Boxes", toggles.ESP, function() end)
createToggle("Skeleton", "Show Skeleton Chams", toggles.Skeleton, function() end)
createToggle("Aimlock", "Enable Aimlock", toggles.Aimlock, function(val) fovCircle.Visible = val end)
createToggle("BulletFix", "Enable Bullet Correction", toggles.BulletFix, function() end)
createToggle("DistanceLines", "Show Distance Lines", toggles.DistanceLines, function() end)
createToggle("SilentAim", "Silent Aim (Experimental)", toggles.SilentAim, function() end)
createToggle("AutoReload", "Automatically Reload", toggles.AutoReload, function() end)
createToggle("FastEquipSwap", "Fast Equip Swap", toggles.FastEquipSwap, function() end)
createToggle("NoSpread", "Remove Weapon Spread", toggles.NoSpread, function() end)
createToggle("Hitmarker", "Play Hitmarker Sound", toggles.Hitmarker, function() end)
createToggle("Crosshair", "Show Custom Crosshair", toggles.Crosshair, function(val)
    for _, line in ipairs(crosshairLines) do
        line.Visible = val
    end
end)
createToggle("SpectatorList", "Show Spectator List", toggles.SpectatorList, function(val)
    SpectatorLabel.Visible = val
end)

-- Keybind for UI toggle
local keybindInput = Tabs.Settings:CreateKeybind({
    Name = "Toggle UI Keybind",
    CurrentKeybind = keybinds.ToggleUI,
    Flag = "ToggleUIKeybind",
    HoldToInteract = false,
    Default = keybinds.ToggleUI,
    Mode = "Toggle",
    Callback = function(key)
        keybinds.ToggleUI = key
    end,
})

-- Hide/Show UI with keybind
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == keybinds.ToggleUI then
        Window:Toggle()
    end
end)

-- ESP and visuals variables
local espBoxes, skeletons, distanceLines, healthBars = {}, {}, {}, {}

local function isWhitelisted(pl)
    return pl:IsFriendsWith(localPlayer.UserId)
end

local function playerColor(pl)
    if isWhitelisted(pl) then
        return Color3.fromRGB(0, 255, 0)
    elseif pl.Team == localPlayer.Team then
        return Color3.fromRGB(0, 0, 255)
    else
        return Color3.fromRGB(255, 0, 0)
    end
end

local function cleanup(tbl)
    for _, obj in pairs(tbl) do
        if obj and obj.Visible then obj.Visible = false end
        if obj and obj.Remove then
            pcall(function() obj:Remove() end)
        end
    end
    table.clear(tbl)
end

local function setupESP(pl)
    if espBoxes[pl] then return end
    espBoxes[pl] = {}
    for i = 1, 4 do
        local line = Drawing.new("Line")
        line.Thickness = 2
        line.Transparency = 1
        line.Visible = false
        table.insert(espBoxes[pl], line)
    end
end

local function setupSkeleton(pl)
    if skeletons[pl] then return end
    skeletons[pl] = {}
    for i = 1, 14 do
        local line = Drawing.new("Line")
        line.Thickness = 1
        line.Transparency = 1
        line.Visible = false
        table.insert(skeletons[pl], line)
    end
end

local function setupDistanceLine(pl)
    if distanceLines[pl] then return end
    local line = Drawing.new("Line")
    line.Thickness = 1
    line.Transparency = 1
    line.Color = Color3.fromRGB(255, 255, 255)
    line.Visible = false
    distanceLines[pl] = line
end

local function setupHealthBar(pl)
    if healthBars[pl] then return end
    local bar = Drawing.new("Square")
    bar.Filled = true
    bar.Thickness = 1
    bar.Transparency = 1
    bar.Visible = false
    healthBars[pl] = bar
end

local function setupVisuals(pl)
    if pl == localPlayer or isWhitelisted(pl) then return end
    setupESP(pl)
    setupSkeleton(pl)
    setupDistanceLine(pl)
    setupHealthBar(pl)
end

local function updateSkeleton(pl, character, color)
    local lines = skeletons[pl]
    if not lines then return end
    local parts = {
        Head = character:FindFirstChild("Head"),
        HumanoidRootPart = character:FindFirstChild("HumanoidRootPart"),
        UpperTorso = character:FindFirstChild("UpperTorso"),
        LowerTorso = character:FindFirstChild("LowerTorso"),
        LeftUpperArm = character:FindFirstChild("LeftUpperArm"),
        LeftLowerArm = character:FindFirstChild("LeftLowerArm"),
        LeftHand = character:FindFirstChild("LeftHand"),
        RightUpperArm = character:FindFirstChild("RightUpperArm"),
        RightLowerArm = character:FindFirstChild("RightLowerArm"),
        RightHand = character:FindFirstChild("RightHand"),
        LeftUpperLeg = character:FindFirstChild("LeftUpperLeg"),
        LeftLowerLeg = character:FindFirstChild("LeftLowerLeg"),
        LeftFoot = character:FindFirstChild("LeftFoot"),
        RightUpperLeg = character:FindFirstChild("RightUpperLeg"),
        RightLowerLeg = character:FindFirstChild("RightLowerLeg"),
        RightFoot = character:FindFirstChild("RightFoot"),
    }

    local pairsToDraw = {
        {"Head","UpperTorso"},{"UpperTorso","LowerTorso"},
        {"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},
        {"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},
        {"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},
        {"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"},
    }

    for i, pair in ipairs(pairsToDraw) do
        local p0, p1 = parts[pair[1]], parts[pair[2]]
        local line = lines[i]
        if p0 and p1 and line then
            local v0, on0 = Camera:WorldToViewportPoint(p0.Position)
            local v1, on1 = Camera:WorldToViewportPoint(p1.Position)
            if on0 and on1 then
                line.From = Vector2.new(v0.X, v0.Y)
                line.To = Vector2.new(v1.X, v1.Y)
                line.Color = color
                line.Visible = toggles.Skeleton and toggles.ESP
            else
                line.Visible = false
            end
        elseif line then
            line.Visible = false
        end
    end
end

local function updateESP(pl, character, color)
    local box = espBoxes[pl]
    if not box then return end

    local rootPart = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso")
    if not rootPart then
        for _, line in ipairs(box) do line.Visible = false end
        return
    end

    local size = 100 / math.clamp((rootPart.Position - localPlayer.Character.PrimaryPart.Position).Magnitude, 10, 1000)
    local half = size / 2

    local pos, onScreen = Camera:WorldToViewportPoint(rootPart.Position)
    if not onScreen then
        for _, line in ipairs(box) do line.Visible = false end
        return
    end

    local tl = Vector2.new(pos.X - half, pos.Y - size)
    local tr = Vector2.new(pos.X + half, pos.Y - size)
    local bl = Vector2.new(pos.X - half, pos.Y + size)
    local br = Vector2.new(pos.X + half, pos.Y + size)

    box[1].From, box[1].To = tl, tr
    box[2].From, box[2].To = tr, br
    box[3].From, box[3].To = br, bl
    box[4].From, box[4].To = bl, tl

    for _, line in ipairs(box) do
        line.Color = color
        line.Visible = toggles.ESP
    end
end

local function updateDistanceLine(pl, character, color)
    local line = distanceLines[pl]
    if not line then return end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then
        line.Visible = false
        return
    end

    local screenPos, onScreen = Camera:WorldToViewportPoint(rootPart.Position)
    if onScreen and toggles.DistanceLines then
        line.From = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
        line.To = Vector2.new(screenPos.X, screenPos.Y)
        line.Color = color
        line.Visible = true
    else
        line.Visible = false
    end
end

local function updateHealthBar(pl, character)
    local bar = healthBars[pl]
    if not bar then return end
    if not toggles.ESP then
        bar.Visible = false
        return
    end
    local hum = character:FindFirstChildOfClass("Humanoid")
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not hum or not rootPart then
        bar.Visible = false
        return
    end

    local screenPos, onScreen = Camera:WorldToViewportPoint(rootPart.Position + Vector3.new(0, 3, 0))
    if not onScreen then
        bar.Visible = false
        return
    end

    local healthPercent = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
    local barWidth = 50 * healthPercent

    bar.Position = Vector2.new(screenPos.X - 25, screenPos.Y)
    bar.Size = Vector2.new(barWidth, 5)
    bar.Color = Color3.new(1 - healthPercent, healthPercent, 0)
    bar.Visible = toggles.ESP
end

local function findClosestTarget()
    local center = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    local bestDist = math.huge
    local bestTarget = nil

    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= localPlayer and pl.Character and not isWhitelisted(pl) then
            local character = pl.Character
            local targetPart = character:FindFirstChild(boneSelection)
            if targetPart then
                local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
                if onScreen then
                    local dist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
                    if dist < bestDist and dist <= fovRadius then
                        bestDist = dist
                        bestTarget = targetPart
                    end
                end
            end
        end
    end
    return bestTarget
end

-- Fixed Bullet correction hook with robust error handling
local mt = getrawmetatable(game)
local origNamecall = mt.__namecall
setreadonly(mt, false)
local inCall = false

mt.__namecall = newcclosure(function(self, ...)
    if inCall then return origNamecall(self, ...) end
    inCall = true

    local method = getnamecallmethod()
    local args = {...}

    if toggles.BulletFix and (method == "Raycast" or method == "FindPartOnRayWithIgnoreList") then
        if args[1] then
            local argType = typeof(args[1])
            local origin = nil

            if argType == "Ray" and args[1].Origin then
                origin = args[1].Origin
            elseif argType == "Vector3" then
                origin = args[1]
            elseif argType == "Instance" and args[1].Origin then
                origin = args[1].Origin
            end

            if origin then
                local target = cachedClosestTarget
                if target then
                    local direction = (target.Position - origin).Unit * 1000
                    if method == "Raycast" then
                        args[2] = direction
                    else
                        args[1] = Ray.new(origin, direction)
                    end
                end
            end
        else
            -- args[1] missing or nil, skip modification
            inCall = false
            return origNamecall(self, ...)
        end
    elseif typeof(self) == "Instance" and self:IsA("RemoteEvent") then
        local target = cachedClosestTarget
        if target then
            for i, v in ipairs(args) do
                if typeof(v) == "Vector3" then
                    args[i] = target.Position
                elseif typeof(v) == "CFrame" then
                    args[i] = CFrame.new(target.Position)
                end
            end
        end
    end

    local result = nil
    local ok, err = pcall(function()
        result = origNamecall(self, unpack(args))
    end)

    inCall = false

    if not ok then
        warn("[NoSleepHub] __namecall error:", err)
        return nil
    end

    return result
end)

setreadonly(mt, true)

local function aimlockUpdate()
    if not toggles.Aimlock then return end
    local camCF = Camera.CFrame
    local target = cachedClosestTarget
    if target and target.Parent then
        Camera.CFrame = camCF:Lerp(CFrame.new(camCF.Position, target.Position), aimSmoothness)
    end
end

local hitSound = Instance.new("Sound")
hitSound.SoundId = "rbxassetid://9118824066"
hitSound.Volume = 0.5
hitSound.Parent = workspace

local function playHitmarker()
    if toggles.Hitmarker then
        pcall(function() hitSound:Play() end)
    end
end

local function listenToHits(pl)
    if pl == localPlayer then return end
    local char = pl.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    hum.HealthChanged:Connect(function(newHealth)
        if newHealth < hum.MaxHealth then
            playHitmarker()
        end
    end)
end

local function tryAutoReload()
    if not toggles.AutoReload then return end
    local char = localPlayer.Character
    if not char then return end
    local tool = char:FindFirstChildOfClass("Tool")
    if not tool then return end

    local ammoValue = tool:FindFirstChild("Ammo") or tool:FindFirstChild("CurrentAmmo")
    if ammoValue and ammoValue.Value <= 0 then
        local reloadEvent = tool:FindFirstChild("ReloadEvent") or tool:FindFirstChildWhichIsA("RemoteEvent")
        if reloadEvent and reloadEvent:IsA("RemoteEvent") then
            pcall(function() reloadEvent:FireServer() end)
        else
            pcall(function() tool:Activate() end)
        end
    end
end

local function fastEquipSwap()
    if not toggles.FastEquipSwap then return end
    local backpack = localPlayer:FindFirstChild("Backpack")
    local char = localPlayer.Character
    if not backpack or not char then return end

    local currentTool = char:FindFirstChildOfClass("Tool")
    if not currentTool then return end

    local foundCurrent = false
    local nextTool = nil
    for _, tool in ipairs(backpack:GetChildren()) do
        if tool:IsA("Tool") then
            if foundCurrent then
                nextTool = tool
                break
            elseif tool == currentTool then
                foundCurrent = true
            end
        end
    end

    if not nextTool then
        for _, tool in ipairs(backpack:GetChildren()) do
            if tool:IsA("Tool") then
                nextTool = tool
                break
            end
        end
    end

    if nextTool then
        pcall(function()
            currentTool.Parent = backpack
            nextTool.Parent = char
        end)
    end
end

local function patchNoSpread()
    if not toggles.NoSpread then return end
    -- Implementation depends on the game, so just a placeholder here
end

-- Crosshair drawing
local crosshairLines = {}
local crosshairSize = 10
local crosshairColor = Color3.fromRGB(0, 255, 255)

local function drawCrosshair()
    if #crosshairLines == 0 then
        for i = 1, 4 do
            local line = Drawing.new("Line")
            line.Thickness = 2
            line.Transparency = 1
            line.Color = crosshairColor
            line.Visible = false
            table.insert(crosshairLines, line)
        end
    end

    local centerX = Camera.ViewportSize.X / 2
    local centerY = Camera.ViewportSize.Y / 2

    crosshairLines[1].From = Vector2.new(centerX - crosshairSize, centerY)
    crosshairLines[1].To = Vector2.new(centerX - 2, centerY)

    crosshairLines[2].From = Vector2.new(centerX + 2, centerY)
    crosshairLines[2].To = Vector2.new(centerX + crosshairSize, centerY)

    crosshairLines[3].From = Vector2.new(centerX, centerY - crosshairSize)
    crosshairLines[3].To = Vector2.new(centerX, centerY - 2)

    crosshairLines[4].From = Vector2.new(centerX, centerY + 2)
    crosshairLines[4].To = Vector2.new(centerX, centerY + crosshairSize)

    for _, line in ipairs(crosshairLines) do
        line.Visible = toggles.Crosshair
    end
end

-- FOV Circle
local fovCircle = Drawing.new("Circle")
fovCircle.Radius = fovRadius
fovCircle.Color = fovColor
fovCircle.Thickness = 2
fovCircle.NumSides = 64
fovCircle.Filled = false
fovCircle.Transparency = 1
fovCircle.Visible = toggles.Aimlock

RunService.RenderStepped:Connect(function()
    fovCircle.Position = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
end)

-- Spectator list GUI
local SpectatorGui = Instance.new("ScreenGui")
SpectatorGui.Name = "NoSleepSpectators"
SpectatorGui.ResetOnSpawn = false
SpectatorGui.Parent = game.CoreGui

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

local function updateSpectators()
    if not toggles.SpectatorList then
        SpectatorLabel.Visible = false
        return
    end
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
    if #spectators == 0 then
        SpectatorLabel.Text = "Spectators:\nNone"
    else
        SpectatorLabel.Text = "Spectators:\n" .. table.concat(spectators, "\n")
    end
end

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

print("[NoSleep Hub] Loaded successfully.")
