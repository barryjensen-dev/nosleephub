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

local cachedClosestTarget = nil

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

-- Bullet correction hook with error handling and strict type checks
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
        local target = cachedClosestTarget
        if target and target.Parent then
            local origin
            local arg1 = args[1]

            if typeof(arg1) == "Ray" then
                origin = arg1.Origin
            elseif typeof(arg1) == "Vector3" then
                origin = arg1
            elseif typeof(arg1) == "table" and arg1.Origin and typeof(arg1.Origin) == "Vector3" then
                origin = arg1.Origin
            else
                origin = nil
            end

            if origin then
                local direction = (target.Position - origin).Unit * 1000
                if method == "Raycast" then
                    args[2] = direction
                else
                    args[1] = Ray.new(origin, direction)
                end
            end
        end
    elseif typeof(self) == "Instance" and self:IsA("RemoteEvent") then
        local target = cachedClosestTarget
        if target and target.Parent then
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
        currentTool.Parent = backpack
        nextTool.Parent = char
    end
end

local function patchNoSpread()
    if not toggles.NoSpread then return end
    local tool = localPlayer.Character and localPlayer.Character:FindFirstChildOfClass("Tool")
    if not tool then return end
    if tool:FindFirstChild("Spread") then
        tool.Spread.Value = 0
    end
    if tool:FindFirstChild("Accuracy") then
        tool.Accuracy.Value = 1
    end
end

local fovCircle = Drawing.new("Circle")
fovCircle.Position = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
fovCircle.Radius = fovRadius
fovCircle.Color = fovColor
fovCircle.Thickness = 2
fovCircle.NumSides = 64
fovCircle.Filled = false
fovCircle.Visible = toggles.Aimlock

local crosshairLines = {}
for i = 1, 4 do
    local line = Drawing.new("Line")
    line.Color = fovColor
    line.Thickness = 2
    line.Transparency = 1
    line.Visible = toggles.Crosshair
    table.insert(crosshairLines, line)
end

local function drawCrosshair()
    if not toggles.Crosshair then
        for _, line in ipairs(crosshairLines) do line.Visible = false end
        return
    end
    local cx, cy = Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2
    local size = 8

    crosshairLines[1].From = Vector2.new(cx - size, cy)
    crosshairLines[1].To = Vector2.new(cx + size, cy)

    crosshairLines[2].From = Vector2.new(cx, cy - size)
    crosshairLines[2].To = Vector2.new(cx, cy + size)

    crosshairLines[3].From = Vector2.new(cx - size/2, cy - size/2)
    crosshairLines[3].To = Vector2.new(cx + size/2, cy + size/2)

    crosshairLines[4].From = Vector2.new(cx - size/2, cy + size/2)
    crosshairLines[4].To = Vector2.new(cx + size/2, cy - size/2)

    for _, line in ipairs(crosshairLines) do
        line.Color = fovColor
        line.Visible = true
    end
end

local SpectatorGui = Instance.new("ScreenGui")
SpectatorGui.Name = "NoSleepSpectatorList"
SpectatorGui.Parent = localPlayer:WaitForChild("PlayerGui")

local SpectatorLabel = Instance.new("TextLabel")
SpectatorLabel.BackgroundColor3 = Color3.new(0, 0, 0)
SpectatorLabel.BackgroundTransparency = 0.5
SpectatorLabel.TextColor3 = Color3.new(1, 1, 1)
SpectatorLabel.Size = UDim2.new(0, 200, 0, 100)
SpectatorLabel.Position = UDim2.new(1, -210, 0, 10)
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
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= localPlayer and pl.Character and pl.Character:FindFirstChild("Humanoid") then
            local targetHumanoid = pl.Character:FindFirstChild("Humanoid")
            local targetHumanoidRootPart = pl.Character:FindFirstChild("HumanoidRootPart")
            if targetHumanoid and targetHumanoidRootPart then
                -- Checking if pl is spectating localPlayer by looking for Humanoid's cameraSubject or similar methods
                if targetHumanoid.CameraSubject and targetHumanoid.CameraSubject == localPlayer.Character.Humanoid then
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

local PingLabel = Instance.new("TextLabel")
PingLabel.BackgroundColor3 = Color3.new(0, 0, 0)
PingLabel.BackgroundTransparency = 0.5
PingLabel.TextColor3 = Color3.new(1, 1, 1)
PingLabel.Size = UDim2.new(0, 100, 0, 30)
PingLabel.Position = UDim2.new(0, 10, 0, 10)
PingLabel.Text = "Ping: ..."
PingLabel.Visible = toggles.PingDisplay
PingLabel.Parent = SpectatorGui

local function updatePing()
    if not toggles.PingDisplay then
        PingLabel.Visible = false
        return
    end
    PingLabel.Visible = true
    local ping = math.floor(game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue())
    PingLabel.Text = "Ping: " .. tostring(ping) .. " ms"
end

-- Create UI window and toggles using Rayfield

local uiWindow = Rayfield:CreateWindow({
    Name = "NoSleep Hub",
    LoadingTitle = "NoSleep Hub",
    LoadingSubtitle = "Loading...",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "NoSleepHubConfigs",
        FileName = "Config",
    },
    Discord = {
        Enabled = true,
        Invite = "yourdiscordinvite",
        RememberJoins = true,
    }
})

local function safeToggleCallback(toggleName, callback)
    return function(value)
        if toggles == nil then return end
        toggles[toggleName] = value
        if callback then
            local ok, err = pcall(callback, value)
            if not ok then
                warn("[NoSleepHub] Toggle callback error: " .. tostring(err))
            end
        end
    end
end

uiWindow:CreateToggle({
    Name = "ESP",
    CurrentValue = toggles.ESP,
    Flag = "ESP_Toggle",
    Callback = safeToggleCallback("ESP")
})

uiWindow:CreateToggle({
    Name = "Skeleton Chams",
    CurrentValue = toggles.Skeleton,
    Flag = "Skeleton_Toggle",
    Callback = safeToggleCallback("Skeleton")
})

uiWindow:CreateToggle({
    Name = "Aimlock",
    CurrentValue = toggles.Aimlock,
    Flag = "Aimlock_Toggle",
    Callback = safeToggleCallback("Aimlock")
})

uiWindow:CreateToggle({
    Name = "Bullet Correction",
    CurrentValue = toggles.BulletFix,
    Flag = "BulletFix_Toggle",
    Callback = safeToggleCallback("BulletFix")
})

uiWindow:CreateToggle({
    Name = "Distance Lines",
    CurrentValue = toggles.DistanceLines,
    Flag = "DistanceLines_Toggle",
    Callback = safeToggleCallback("DistanceLines")
})

uiWindow:CreateToggle({
    Name = "Crosshair",
    CurrentValue = toggles.Crosshair,
    Flag = "Crosshair_Toggle",
    Callback = function(value)
        toggles.Crosshair = value
        for _, line in ipairs(crosshairLines) do
            line.Visible = value
        end
    end,
})

uiWindow:CreateToggle({
    Name = "Spectator List",
    CurrentValue = toggles.SpectatorList,
    Flag = "Spectator_Toggle",
    Callback = safeToggleCallback("SpectatorList", function(value)
        SpectatorLabel.Visible = value
    end)
})

uiWindow:CreateToggle({
    Name = "Ping Display",
    CurrentValue = toggles.PingDisplay,
    Flag = "Ping_Toggle",
    Callback = safeToggleCallback("PingDisplay", function(value)
        PingLabel.Visible = value
    end)
})

uiWindow:CreateToggle({
    Name = "Auto Reload",
    CurrentValue = toggles.AutoReload,
    Flag = "AutoReload_Toggle",
    Callback = safeToggleCallback("AutoReload")
})

uiWindow:CreateToggle({
    Name = "Fast Equip Swap",
    CurrentValue = toggles.FastEquipSwap,
    Flag = "FastEquipSwap_Toggle",
    Callback = safeToggleCallback("FastEquipSwap")
})

uiWindow:CreateToggle({
    Name = "No Spread",
    CurrentValue = toggles.NoSpread,
    Flag = "NoSpread_Toggle",
    Callback = safeToggleCallback("NoSpread")
})

uiWindow:CreateToggle({
    Name = "Hitmarker",
    CurrentValue = toggles.Hitmarker,
    Flag = "Hitmarker_Toggle",
    Callback = safeToggleCallback("Hitmarker")
})

uiWindow:BindKey({
    Name = "Toggle UI",
    Default = keybinds.ToggleUI,
    Flag = "ToggleUI_Bind",
    Callback = function()
        uiWindow:Toggle()
    end,
})

-- Main loop

RunService.RenderStepped:Connect(function()
    cachedClosestTarget = findClosestTarget()

    for _, pl in ipairs(Players:GetPlayers()) do
        if pl.Character and pl.Character:FindFirstChild("HumanoidRootPart") and pl ~= localPlayer and not isWhitelisted(pl) then
            setupVisuals(pl)
            local color = playerColor(pl)
            updateESP(pl, pl.Character, color)
            updateSkeleton(pl, pl.Character, color)
            updateDistanceLine(pl, pl.Character, color)
            updateHealthBar(pl, pl.Character)
        end
    end

    aimlockUpdate()
    tryAutoReload()
    patchNoSpread()
    fastEquipSwap()
    drawCrosshair()
    updateSpectators()
    updatePing()
end)

for _, pl in ipairs(Players:GetPlayers()) do
    listenToHits(pl)
end

Players.PlayerAdded:Connect(function(pl)
    listenToHits(pl)
end)
