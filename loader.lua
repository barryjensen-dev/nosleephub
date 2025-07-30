if _G.NoSleepHubLoaded then return end
_G.NoSleepHubLoaded = true

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local localPlayer = Players.LocalPlayer

local toggles = {
    ESP = false,
    Skeleton = false,
    Aimlock = false,
    BulletFix = false,
    DistanceLines = false,
    SilentAim = false,
    AutoReload = false,
    FastEquipSwap = false,
    NoSpread = false,
    Hitmarker = false,
    Crosshair = false,
    SpectatorList = false,
    PingDisplay = false,
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

    local dist = (rootPart.Position - localPlayer.Character.PrimaryPart.Position).Magnitude
    local size = 100 / math.clamp(dist, 10, 1000)
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
        if target then
            local origin
            if typeof(args[1]) == "Ray" then origin = args[1].Origin
            elseif typeof(args[1]) == "Vector3" then origin = args[1]
            elseif args[1] and typeof(args[1]) == "table" and args[1].Origin then origin = args[1].Origin
            else origin = nil end

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

-- Spectator GUI setup
local SpectatorGui = Instance.new("ScreenGui")
SpectatorGui.Name = "NoSleepSpectatorList"
SpectatorGui.Parent = localPlayer:WaitForChild("PlayerGui")

local SpectatorLabel = Instance.new("TextLabel")
SpectatorLabel.BackgroundColor3 = Color3.new(0, 0, 0)
SpectatorLabel.BackgroundTransparency = 0.5
SpectatorLabel.TextColor3 = Color3.new(1, 1, 1)
SpectatorLabel.Size = UDim2.new(0, 200, 0, 100)
SpectatorLabel.Position = UDim2.new(1, -210, 0, 10)
SpectatorLabel.Text = "Spectators:"
SpectatorLabel.TextWrapped = true
SpectatorLabel.Visible = toggles.SpectatorList
SpectatorLabel.Parent = SpectatorGui

local function updateSpectatorList()
    local text = "Spectators:\n"
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= localPlayer and pl.Character and pl.Character:FindFirstChild("Humanoid") and pl.Character.Humanoid.Health > 0 then
            local target = nil
            local cframe = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
            if cframe then
                local head = pl.Character:FindFirstChild("Head")
                if head then
                    -- If pl is looking at local player within some angle, count as spectator
                    local lookVector = (head.CFrame.LookVector)
                    local directionToLocal = (cframe.Position - head.Position).Unit
                    local dot = lookVector:Dot(directionToLocal)
                    if dot > 0.8 then
                        text = text .. pl.Name .. "\n"
                    end
                end
            end
        end
    end
    SpectatorLabel.Text = text
end

-- Ping display
local PingLabel = Instance.new("TextLabel")
PingLabel.BackgroundColor3 = Color3.new(0, 0, 0)
PingLabel.BackgroundTransparency = 0.5
PingLabel.TextColor3 = Color3.new(1, 1, 1)
PingLabel.Size = UDim2.new(0, 100, 0, 25)
PingLabel.Position = UDim2.new(0, 10, 1, -35)
PingLabel.Text = "Ping: 0 ms"
PingLabel.Parent = SpectatorGui
PingLabel.Visible = toggles.PingDisplay

RunService.Heartbeat:Connect(function()
    if toggles.PingDisplay then
        local ping = game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()
        PingLabel.Text = string.format("Ping: %d ms", ping)
    else
        PingLabel.Visible = false
    end
end)

local Window = Rayfield:CreateWindow({
    Name = "NoSleep Hub",
    LoadingTitle = "NoSleep Hub",
    LoadingSubtitle = "Loading...",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "NoSleepHubConfig",
        FileName = "Settings"
    },
    Discord = {
        Enabled = false,
        Invite = "YourDiscordCode",
        RememberJoins = true
    }
})

local tabESP = Window:CreateTab("ESP & Visuals")
local tabAim = Window:CreateTab("Aim & Bullet")
local tabMisc = Window:CreateTab("Misc")
local tabSettings = Window:CreateTab("Settings")

tabESP:CreateToggle({
    Name = "Enable ESP",
    CurrentValue = toggles.ESP,
    Flag = "ToggleESP",
    Callback = function(val)
        toggles.ESP = val
        if not val then
            cleanup(espBoxes)
            cleanup(skeletons)
            cleanup(distanceLines)
            cleanup(healthBars)
        end
    end,
})

tabESP:CreateToggle({
    Name = "Skeleton ESP",
    CurrentValue = toggles.Skeleton,
    Flag = "ToggleSkeleton",
    Callback = function(val)
        toggles.Skeleton = val
    end,
})

tabESP:CreateToggle({
    Name = "Distance Lines",
    CurrentValue = toggles.DistanceLines,
    Flag = "ToggleDistLines",
    Callback = function(val)
        toggles.DistanceLines = val
    end,
})

tabESP:CreateToggle({
    Name = "Show Health Bars",
    CurrentValue = true,
    Flag = "ToggleHealthBars",
    Callback = function(val)
    end,
})

tabAim:CreateToggle({
    Name = "Enable Aimlock",
    CurrentValue = toggles.Aimlock,
    Flag = "ToggleAimlock",
    Callback = function(val)
        toggles.Aimlock = val
        fovCircle.Visible = val
        drawCrosshair()
    end,
})

tabAim:CreateSlider({
    Name = "Aim Smoothness",
    Range = {0, 1},
    Increment = 0.01,
    CurrentValue = aimSmoothness,
    Flag = "AimSmoothness",
    Callback = function(val)
        aimSmoothness = val
    end,
})

tabAim:CreateToggle({
    Name = "Enable Bullet Correction",
    CurrentValue = toggles.BulletFix,
    Flag = "ToggleBulletFix",
    Callback = function(val)
        toggles.BulletFix = val
    end,
})

tabMisc:CreateToggle({
    Name = "Show Crosshair",
    CurrentValue = toggles.Crosshair,
    Flag = "ToggleCrosshair",
    Callback = function(val)
        toggles.Crosshair = val
        drawCrosshair()
    end,
})

tabMisc:CreateToggle({
    Name = "Enable Hitmarker",
    CurrentValue = toggles.Hitmarker,
    Flag = "ToggleHitmarker",
    Callback = function(val)
        toggles.Hitmarker = val
    end,
})

tabMisc:CreateToggle({
    Name = "Spectator List",
    CurrentValue = toggles.SpectatorList,
    Flag = "ToggleSpectatorList",
    Callback = function(val)
        toggles.SpectatorList = val
        SpectatorLabel.Visible = val
    end,
})

tabMisc:CreateToggle({
    Name = "Show Ping",
    CurrentValue = toggles.PingDisplay,
    Flag = "TogglePing",
    Callback = function(val)
        toggles.PingDisplay = val
        PingLabel.Visible = val
    end,
})

tabSettings:CreateKeybind({
    Name = "Toggle UI",
    CurrentKeybind = keybinds.ToggleUI.Name,
    Flag = "KeybindToggleUI",
    Hold = false,
    Callback = function(key)
        keybinds.ToggleUI = Enum.KeyCode[key]
        Window:Toggle()
    end,
})

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == keybinds.ToggleUI then
        Window:Toggle()
    end
end)

RunService.RenderStepped:Connect(function()
    if not localPlayer.Character or not localPlayer.Character:FindFirstChild("HumanoidRootPart") then return end

    cachedClosestTarget = findClosestTarget()
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl.Character and pl.Character:FindFirstChild("HumanoidRootPart") and pl ~= localPlayer then
            setupVisuals(pl)
            local color = playerColor(pl)
            updateESP(pl, pl.Character, color)
            updateSkeleton(pl, pl.Character, color)
            updateDistanceLine(pl, pl.Character, color)
            updateHealthBar(pl, pl.Character)
        else
            cleanup(espBoxes)
            cleanup(skeletons)
            cleanup(distanceLines)
            cleanup(healthBars)
        end
    end

    aimlockUpdate()

    fovCircle.Position = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    fovCircle.Visible = toggles.Aimlock

    drawCrosshair()

    if toggles.SpectatorList then
        pcall(updateSpectatorList)
    end

    tryAutoReload()
    fastEquipSwap()
    patchNoSpread()
end)

Players.PlayerAdded:Connect(function(pl)
    pl.CharacterAdded:Connect(function(char)
        listenToHits(pl)
    end)
end)
for _, pl in ipairs(Players:GetPlayers()) do
    listenToHits(pl)
end

print("[NoSleep Hub] Loaded successfully!")
