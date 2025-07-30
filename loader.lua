-- Prevent multiple loads
if _G.NoSleepHubLoaded then return end
_G.NoSleepHubLoaded = true

-- Load Rayfield UI
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInput = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local localPlayer = Players.LocalPlayer

-- Config
local labelRenderDistance = 200
local aimSmoothness = 0.2

-- Drawing API check
local DrawingSupported = pcall(function()
    local l = Drawing.new("Line")
    l:Remove()
end)
if not DrawingSupported then
    warn("Drawing API unsupported.")
    return
end

-- Toggles and keybind settings
local toggles = { ESP = true, Skeleton = true, Aimlock = true, BulletFix = true, DistanceLines = true }
local keybinds = {
    ESP = Enum.KeyCode.F1,
    Skeleton = Enum.KeyCode.F2,
    Aimlock = Enum.KeyCode.F3,
    BulletFix = Enum.KeyCode.F4,
    DistanceLines = Enum.KeyCode.F5,
    ToggleUI = Enum.KeyCode.RightControl
}

local espBoxes, skeletons, distanceLines = {}, {}, {}

-- Friend whitelist detection
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

-- Drawing cleanup helper
local function cleanup(tbl)
    for _, obj in pairs(tbl) do
        if obj.Visible then obj.Visible = false end
        if obj.Destroy then obj:Destroy() end
    end
    table.clear(tbl)
end

-- ESP setup
local function setupESP(pl)
    espBoxes[pl] = {}
    for i = 1, 4 do
        local l = Drawing.new("Line")
        l.Thickness = 2 l.Transparency = 1 l.Visible = false
        table.insert(espBoxes[pl], l)
    end
end

-- Skeleton setup
local function setupSkeleton(pl)
    skeletons[pl] = {}
    for i = 1, 14 do
        local l = Drawing.new("Line")
        l.Thickness = 1 l.Transparency = 1 l.Visible = false
        table.insert(skeletons[pl], l)
    end
end

-- Distance line setup
local function setupDistanceLine(pl)
    local line = Drawing.new("Line")
    line.Thickness = 1
    line.Transparency = 1
    line.Color = Color3.fromRGB(255,255,255)
    line.Visible = false
    distanceLines[pl] = line
end

local function setupCharacter(pl)
    if pl == localPlayer or isWhitelisted(pl) then return end
    setupESP(pl)
    setupSkeleton(pl)
    setupDistanceLine(pl)
end

-- Skeleton update
local function updateSkeleton(pl, character, color)
    local lines = skeletons[pl]
    if not lines then return end
    local parts = {
        Head = character:FindFirstChild("Head"),
        UpperTorso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso"),
        LowerTorso = character:FindFirstChild("LowerTorso") or character:FindFirstChild("Torso"),
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
        RightFoot = character:FindFirstChild("RightFoot")
    }
    local pairs = {
        {"Head","UpperTorso"},{"UpperTorso","LowerTorso"},
        {"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},
        {"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},
        {"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},
        {"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"}
    }
    for i, pair in ipairs(pairs) do
        local p0, p1 = parts[pair[1]], parts[pair[2]]
        local ln = lines[i]
        if p0 and p1 and ln then
            local v0, on0 = Camera:WorldToViewportPoint(p0.Position)
            local v1, on1 = Camera:WorldToViewportPoint(p1.Position)
            if on0 and on1 then
                ln.From = Vector2.new(v0.X, v0.Y)
                ln.To = Vector2.new(v1.X, v1.Y)
                ln.Color = color
                ln.Visible = true
            else
                ln.Visible = false
            end
        elseif ln then
            ln.Visible = false
        end
    end
end

-- Cached closest head for bullet correction
local cachedClosestHead = nil
RunService.RenderStepped:Connect(function()
    local center = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    local best, bestDist = nil, math.huge
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= localPlayer and pl.Character and not isWhitelisted(pl) then
            local head = pl.Character:FindFirstChild("Head")
            if head then
                local pos, on = Camera:WorldToViewportPoint(head.Position)
                if on then
                    local dist = (Vector2.new(pos.X, pos.Y) - center).Magnitude
                    if dist < bestDist then best, bestDist = head, dist end
                end
            end
        end
    end
    cachedClosestHead = best
end)

-- Bullet redirection hook
local mt = getrawmetatable(game)
setreadonly(mt, false)
local orig = mt.__namecall
local inCall = false
mt.__namecall = newcclosure(function(self, ...)
    if inCall then return orig(self, ...) end
    inCall = true
    local method = getnamecallmethod()
    local args = {...}
    if toggles.BulletFix then
        if method == "Raycast" or method == "FindPartOnRayWithIgnoreList" then
            local closest = cachedClosestHead
            if closest then
                local origin
                if typeof(args[1]) == "Ray" then origin = args[1].Origin
                elseif typeof(args[1]) == "Vector3" then origin = args[1]
                elseif args[1] and args[1].Origin then origin = args[1].Origin
                elseif args[1] and args[1].OriginPosition then origin = args[1].OriginPosition end
                if origin then
                    local dir = (closest.Position - origin).Unit * 1000
                    if method == "Raycast" then args[2] = dir
                    else args[1] = Ray.new(origin, dir) end
                end
            end
        elseif typeof(self) == "Instance" and self:IsA("RemoteEvent") then
            local closest = cachedClosestHead
            if closest then
                for i, v in ipairs(args) do
                    if typeof(v) == "Vector3" then args[i] = closest.Position
                    elseif typeof(v) == "CFrame" then args[i] = CFrame.new(closest.Position) end
                end
            end
        end
    end
    local result = orig(self, unpack(args))
    inCall = false
    return result
end)
setreadonly(mt, true)

-- Throttled rendering (~30 FPS)
local last = 0
RunService.RenderStepped:Connect(function(dt)
    last += dt
    if last < 0.033 then return end
    last = 0
    local lp = localPlayer.Character
    if not (lp and lp.PrimaryPart) then return end

    local center = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    local bestHead, bestDist = nil, math.huge

    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= localPlayer and pl.Character and not isWhitelisted(pl) then
            local head = pl.Character:FindFirstChild("Head")
            if head then
                local dist = (head.Position - lp.PrimaryPart.Position).Magnitude
                if dist <= labelRenderDistance then
                    local pos, on = Camera:WorldToViewportPoint(head.Position)
                    if on then
                        local col = playerColor(pl)

                        -- ESP Boxes
                        if toggles.ESP and espBoxes[pl] then
                            local size = 100 / dist
                            local half = size/2
                            local tl = Vector2.new(pos.X-half, pos.Y-size)
                            local tr = tl + Vector2.new(size, 0)
                            local bl = tl + Vector2.new(0, size*2)
                            local br = tr + Vector2.new(0, size*2)
                            local box = espBoxes[pl]
                            box[1].From, box[1].To = tl, tr
                            box[2].From, box[2].To = tr, br
                            box[3].From, box[3].To = br, bl
                            box[4].From, box[4].To = bl, tl
                            for _, l in ipairs(box) do
                                l.Color = col
                                l.Visible = true
                            end
                        end

                        -- Skeleton
                        if toggles.Skeleton then updateSkeleton(pl, pl.Character, col) end

                        -- Distance lines
                        if toggles.DistanceLines and distanceLines[pl] then
                            local line = distanceLines[pl]
                            local screenPos, onScreen = Camera:WorldToViewportPoint(pl.Character.HumanoidRootPart.Position)
                            if onScreen then
                                line.From = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
                                line.To = Vector2.new(screenPos.X, screenPos.Y)
                                line.Color = col
                                line.Visible = true
                            else
                                line.Visible = false
                            end
                        end
                    end
                end
                local pos, on = Camera:WorldToViewportPoint(head.Position)
                if on then
                    local d = (Vector2.new(pos.X, pos.Y) - center).Magnitude
                    if d < bestDist then bestHead, bestDist = head, d end
                end
            end
        end
    end

    -- Hide visuals for whitelisted or missing players
    for pl, box in pairs(espBoxes) do
        if not pl.Character or isWhitelisted(pl) then
            for _, l in ipairs(box) do l.Visible = false end
        end
    end
    for pl, lines in pairs(skeletons) do
        if not pl.Character or isWhitelisted(pl) then
            for _, l in ipairs(lines) do l.Visible = false end
        end
    end
    for pl, line in pairs(distanceLines) do
        if not pl.Character or isWhitelisted(pl) then
            line.Visible = false
        end
    end

    -- Aimlock
    if toggles.Aimlock and bestHead then
        local cam = Camera.CFrame
        Camera.CFrame = cam:Lerp(CFrame.new(cam.Position, bestHead.Position), aimSmoothness)
    end
end)

-- Player connect/disconnect handling
Players.PlayerAdded:Connect(function(pl)
    pl.CharacterAdded:Connect(function() setupCharacter(pl) end)
end)
Players.PlayerRemoving:Connect(function(pl)
    cleanup(skeletons[pl] or {})
    cleanup(espBoxes[pl] or {})
    if distanceLines[pl] then
        distanceLines[pl].Visible = false
        distanceLines[pl]:Destroy()
        distanceLines[pl] = nil
    end
    skeletons[pl], espBoxes[pl] = nil, nil
end)
for _, pl in ipairs(Players:GetPlayers()) do setupCharacter(pl) end

-- ===== Rayfield UI Integration =====

local Window = Rayfield:CreateWindow({
    Name = "NoSleep Hub - ESP & Aim",
    LoadingTitle = "NoSleep Hub",
    LoadingSubtitle = "by You",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "NoSleepHubConfig",
        FileName = "Config"
    },
    Discord = { Enabled = false, Invite = "", RememberJoins = true },
    KeySystem = false,
})

-- Visuals tab toggles
local VisualsTab = Window:CreateTab("Visuals")

local espToggleUI = VisualsTab:CreateToggle({
    Name = "ESP",
    CurrentValue = toggles.ESP,
    Flag = "ESP_Toggle",
    Callback = function(val) toggles.ESP = val end
})

local skeletonToggleUI = VisualsTab:CreateToggle({
    Name = "Skeleton",
    CurrentValue = toggles.Skeleton,
    Flag = "Skeleton_Toggle",
    Callback = function(val) toggles.Skeleton = val end
})

local aimlockToggleUI = VisualsTab:CreateToggle({
    Name = "Aimlock",
    CurrentValue = toggles.Aimlock,
    Flag = "Aimlock_Toggle",
    Callback = function(val) toggles.Aimlock = val end
})

local bulletFixToggleUI = VisualsTab:CreateToggle({
    Name = "Bullet Correction",
    CurrentValue = toggles.BulletFix,
    Flag = "BulletFix_Toggle",
    Callback = function(val) toggles.BulletFix = val end
})

local distanceLinesToggleUI = VisualsTab:CreateToggle({
    Name = "Distance Lines",
    CurrentValue = toggles.DistanceLines,
    Flag = "DistanceLines_Toggle",
    Callback = function(val) toggles.DistanceLines = val end
})

-- Keybinds tab
local KeybindsTab = Window:CreateTab("Keybinds")

local espKeybindUI = KeybindsTab:CreateKeybind({
    Name = "Toggle ESP",
    CurrentKeybind = keybinds.ESP,
    Hold = false,
    Flag = "ESP_Keybind",
    Callback = function(k) keybinds.ESP = k end
})

local skeletonKeybindUI = KeybindsTab:CreateKeybind({
    Name = "Toggle Skeleton",
    CurrentKeybind = keybinds.Skeleton,
    Hold = false,
    Flag = "Skeleton_Keybind",
    Callback = function(k) keybinds.Skeleton = k end
})

local aimlockKeybindUI = KeybindsTab:CreateKeybind({
    Name = "Toggle Aimlock",
    CurrentKeybind = keybinds.Aimlock,
    Hold = false,
    Flag = "Aimlock_Keybind",
    Callback = function(k) keybinds.Aimlock = k end
})

local bulletFixKeybindUI = KeybindsTab:CreateKeybind({
    Name = "Toggle Bullet Correction",
    CurrentKeybind = keybinds.BulletFix,
    Hold = false,
    Flag = "BulletFix_Keybind",
    Callback = function(k) keybinds.BulletFix = k end
})

local distanceLinesKeybindUI = KeybindsTab:CreateKeybind({
    Name = "Toggle Distance Lines",
    CurrentKeybind = keybinds.DistanceLines,
    Hold = false,
    Flag = "DistanceLines_Keybind",
    Callback = function(k) keybinds.DistanceLines = k end
})

local toggleUIKeybindUI = KeybindsTab:CreateKeybind({
    Name = "Toggle UI Visibility",
    CurrentKeybind = keybinds.ToggleUI,
    Hold = false,
    Flag = "ToggleUI_Keybind",
    Callback = function(k) keybinds.ToggleUI = k end
})

-- Hotkey input handler, safe flag checks
UserInput.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed or input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    for name, key in pairs(keybinds) do
        if input.KeyCode == key then
            if name == "ToggleUI" then
                Window:Toggle()
            else
                toggles[name] = not toggles[name]
                local flagName = name .. "_Toggle"
                local flag = Rayfield.Flags[flagName]
                if flag then
                    flag:Set(toggles[name])
                else
                    warn("Flag not found for: " .. flagName)
                end
            end
        end
    end
end)
