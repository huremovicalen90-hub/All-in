-- ============================================================
-- GoldFV3 - Booga Booga Reborn Edition (Enhanced & Beautified)
-- Original by iy_66 | Enhanced GUI & Bug Fixes
-- ============================================================
local Players = game:GetService('Players');
local RunService = game:GetService('RunService');
local HttpService = game:GetService('HttpService');
local UserInputService = game:GetService('UserInputService');
local VirtualInputManager = game:GetService('VirtualInputManager');
local TweenService = game:GetService('TweenService');
local Players = game:GetService('Players');
local LocalPlayer = Players.LocalPlayer

-- 🔐 UserId whitelist (BEST METHOD)
local Whitelist = {
    [2028943444] = true, -- your UserId
    [87654321] = false
}

if not Whitelist[LocalPlayer.UserId] then
    LocalPlayer:Kick("Your Are Not Whitelisted!☹️")
    return
end

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- 🔄 LOADING NOTIFICATION
Rayfield:Notify({
    Title = "NodeV1",
    Content = "Loading script...\nMade by iy_66",
    Duration = 6,
    Image = "gem"
})

-- ========== SERVICES ==========

local player = Players.LocalPlayer
local mouse = player:GetMouse()

-- ========== CONFIGURATION ==========
local CONFIG_FOLDER = "NodeV1"
local spots = {
    {name = "Spot 1", x = 0, y = 0, z = 0, set = false},
    {name = "Spot 2", x = 0, y = 0, z = 0, set = false},
    {name = "Spot 3", x = 0, y = 0, z = 0, set = false},
    {name = "Spot 4", x = 0, y = 0, z = 0, set = false}
}

local settings = {
    clickDelay = 1,
    tweenSpeed = 1,
    loopDelay = 1
}

local isLooping = false
local loopTask = nil
local currentSpot = 1
local selectedConfig = "Default"

-- ========== UTILITY FUNCTIONS ==========
local function safeCall(func, ...)
    local success, result = pcall(func, ...)
    return success, result
end

-- ========== CONFIG MANAGEMENT ==========
local function ensureConfigFolder()
    if not isfolder then return false end
    local success = pcall(function()
        if not isfolder(CONFIG_FOLDER) then
            makefolder(CONFIG_FOLDER)
        end
    end)
    return success
end

local function getConfigList()
    ensureConfigFolder()
    local configs = {}
    local success, files = pcall(function()
        return listfiles(CONFIG_FOLDER)
    end)
    if success and files then
        for _, file in ipairs(files) do
            local name = file:match("([^/\\]+)%.json$")
            if name then
                table.insert(configs, name)
            end
        end
    end
    if #configs == 0 then
        table.insert(configs, "Default")
    end
    return configs
end

local function saveConfigAs(configName)
    ensureConfigFolder()
    local data = {
        spots = spots,
        settings = settings
    }
    local success = pcall(function()
        writefile(CONFIG_FOLDER .. "/" .. configName .. ".json", HttpService:JSONEncode(data))
    end)
    if success then
        Rayfield:Notify({
            Title = "Config Saved",
            Content = "'" .. configName .. "' saved successfully!",
            Duration = 2.5,
            Image = "check-circle"
        })
        return true
    else
        Rayfield:Notify({
            Title = "Error",
            Content = "Failed to save config!",
            Duration = 2.5,
            Image = "alert-circle"
        })
        return false
    end
end

local function loadConfigByName(configName)
    ensureConfigFolder()
    local success, data = pcall(function()
        return readfile(CONFIG_FOLDER .. "/" .. configName .. ".json")
    end)
    if success and data then
        local decodeSuccess, decoded = pcall(function()
            return HttpService:JSONDecode(data)
        end)
        if decodeSuccess and decoded then
            for i = 1, 4 do
                if decoded.spots and decoded.spots[i] then
                    spots[i] = decoded.spots[i]
                end
            end
            if decoded.settings then
                settings = decoded.settings
            end
            selectedConfig = configName
            Rayfield:Notify({
                Title = "Config Loaded",
                Content = "'" .. configName .. "' loaded successfully!",
                Duration = 2.5,
                Image = "folder-open"
            })
            return true
        end
    end
    return false
end

local function deleteConfig(configName)
    ensureConfigFolder()
    local success = pcall(function()
        delfile(CONFIG_FOLDER .. "/" .. configName .. ".json")
    end)
    if success then
        Rayfield:Notify({
            Title = "Config Deleted",
            Content = "'" .. configName .. "' removed!",
            Duration = 2.5,
            Image = "trash-2"
        })
        return true
    end
    return false
end

-- ========== TELEPORT FUNCTIONS ==========
local function getGroundPosition(pos)
    local rayOrigin = Vector3.new(pos.X, pos.Y + 50, pos.Z)
    local rayDirection = Vector3.new(0, -200, 0)

    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = {player.Character}

    local result = workspace:Raycast(rayOrigin, rayDirection, rayParams)
    if result then
        return result.Position + Vector3.new(0, 3, 0)
    end
    return Vector3.new(pos.X, pos.Y + 3, pos.Z)
end

local function smoothTeleport(position, speed)
    local char = player.Character
    if not char then return end
    local rootPart = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChild("Humanoid")
    if not rootPart or not humanoid then return end

    -- Get ground-level target position
    local targetPos = getGroundPosition(Vector3.new(position.x, position.y, position.z))
    local startPos = rootPart.Position
    local distance = (targetPos - startPos).Magnitude

    -- Anti-cheat bypass: use walking speed limit and smaller steps
    local maxSpeed = math.min(speed, 50)
    local stepSize = 15 -- studs per step
    local steps = math.ceil(distance / stepSize)

    if steps < 1 then steps = 1 end

    -- Disable physics interference
    pcall(function()
        rootPart.CanCollide = false
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part ~= rootPart then
                part.CanCollide = false
            end
        end
    end)

    -- Move in incremental steps to avoid teleport detection
    for i = 1, steps do
        if not isLooping and i > 1 then break end

        local alpha = i / steps
        local intermediatePos = startPos:Lerp(targetPos, alpha)

        -- Raycast to ground for each step
        local groundPos = getGroundPosition(intermediatePos)

        local stepDuration = (stepSize / maxSpeed)
        stepDuration = math.max(stepDuration, 0.1)

        local tweenInfo = TweenInfo.new(
            stepDuration,
            Enum.EasingStyle.Linear,
            Enum.EasingDirection.Out
        )

        local tween = TweenService:Create(rootPart, tweenInfo, {
            CFrame = CFrame.new(groundPos)
        })

        tween:Play()
        tween.Completed:Wait()

        -- Simulate walking to fool anti-cheat
        pcall(function()
            humanoid:ChangeState(Enum.HumanoidStateType.Running)
        end)

        task.wait(0.02)
    end

    -- Final ground snap
    local finalGround = getGroundPosition(targetPos)
    rootPart.CFrame = CFrame.new(finalGround)

    -- Re-enable collision
    pcall(function()
        rootPart.CanCollide = true
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = true
            end
        end
        humanoid:ChangeState(Enum.HumanoidStateType.Running)
    end)
end

-- ========== AUTO-CLICKER ==========
local autoClickTask = nil
local isAutoClicking = false

local function startAutoClick()
    if autoClickTask then
        pcall(function() task.cancel(autoClickTask) end)
    end
    isAutoClicking = true

    autoClickTask = task.spawn(function()
        local viewport = workspace.CurrentCamera.ViewportSize
        local centerX = viewport.X / 2
        local centerY = viewport.Y / 2

        while isAutoClicking do
            pcall(function()
                VirtualInputManager:SendMouseButtonEvent(centerX, centerY, 0, true, game, 0)
                task.wait(0.05)
                VirtualInputManager:SendMouseButtonEvent(centerX, centerY, 0, false, game, 0)
            end)
            task.wait(settings.clickDelay)
        end
    end)
end

local function stopAutoClick()
    isAutoClicking = false
    if autoClickTask then
        pcall(function() task.cancel(autoClickTask) end)
        autoClickTask = nil
    end
end

-- ========== FARM LOOP ==========
local function stopFarmLoop()
    isLooping = false
    stopAutoClick()
    if loopTask then
        pcall(function() task.cancel(loopTask) end)
        loopTask = nil
    end
end

local function startFarmLoop()
    if loopTask then
        pcall(function() task.cancel(loopTask) end)
    end
    isLooping = true

    loopTask = task.spawn(function()
        while isLooping do
            if spots[currentSpot] and spots[currentSpot].set then
                smoothTeleport(spots[currentSpot], settings.tweenSpeed)
                startAutoClick()
                Rayfield:Notify({
                    Title = "Farming",
                    Content = "Working at " .. spots[currentSpot].name,
                    Duration = 2,
                    Image = "zap"
                })
                task.wait(settings.loopDelay)
                stopAutoClick()
            end
            currentSpot = currentSpot + 1
            if currentSpot > 4 then currentSpot = 1 end
        end
    end)
end

-- ========== CLEANUP FUNCTION ==========
local function cleanupScript()
    stopFarmLoop()
    stopAutoClick()
end

-- ========== RAYFIELD GUI (BEAUTIFIED) ==========
local Window = Rayfield:CreateWindow({
    Name = " NodeV1 Booga Booga Reborn",
    Icon = "gem",
    LoadingTitle = "NodeV1",
    LoadingSubtitle = "Enhanced Edition by iy_66",
    Theme = "Default",
    DisableRayfieldPrompts = false,
    DisableBuildWarnings = false,
    ConfigurationSaving = {
        Enabled = false,
        FolderName = nil,
        FileName = "NodeV1"
    },
    Discord = {
        Enabled = false,
        Invite = "",
        RememberJoins = true
    },
    KeySystem = false
})

-- ========== TAB: TELEPORT SPOTS ==========
local SpotsTab = Window:CreateTab("Teleport", "map-pin")

SpotsTab:CreateSection("Quick Teleport")

-- Tween Speed Slider
local TweenSpeedSlider = SpotsTab:CreateSlider({
    Name = "Movement Speed-set to 10",
    Range = {1, 15},
    Increment = 0.5,
    Suffix = " studs/s",
    CurrentValue = settings.tweenSpeed,
    Flag = "TweenSpeed",
    Callback = function(Value)
        settings.tweenSpeed = Value
    end
})

SpotsTab:CreateDivider()

-- Spot Teleport Buttons
for i = 1, 4 do
    SpotsTab:CreateButton({
        Name = "Go to " .. spots[i].name .. (spots[i].set and " [SET]" or " [NOT SET]"),
        Callback = function()
            if spots[i].set then
                stopAutoClick()
                smoothTeleport(spots[i], settings.tweenSpeed)
                Rayfield:Notify({
                    Title = "Teleported",
                    Content = "Arrived at " .. spots[i].name,
                    Duration = 2,
                    Image = "navigation"
                })
            else
                Rayfield:Notify({
                    Title = "Error",
                    Content = "Set " .. spots[i].name .. " position first!",
                    Duration = 2,
                    Image = "x-circle"
                })
            end
        end
    })
end

-- ========== TAB: SET SPOTS ==========
local SetSpotsTab = Window:CreateTab("Set Spots", "crosshair")

SetSpotsTab:CreateSection("Current Position")

local PosLabel = SetSpotsTab:CreateLabel("Position: Loading...")

task.spawn(function()
    while task.wait(0.5) do
        local char = player.Character
        if char then
            local root = char:FindFirstChild("HumanoidRootPart")
            if root then
                local p = root.Position
                PosLabel:Set(string.format("X: %.0f | Y: %.0f | Z: %.0f", p.X, p.Y, p.Z))
            end
        end
    end
end)

SetSpotsTab:CreateSection("Save Positions")

for i = 1, 4 do
    SetSpotsTab:CreateButton({
        Name = "Save Current Position as " .. spots[i].name,
        Callback = function()
            local char = player.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                local pos = char.HumanoidRootPart.Position
                spots[i].x = pos.X
                spots[i].y = pos.Y
                spots[i].z = pos.Z
                spots[i].set = true
                Rayfield:Notify({
                    Title = "Position Saved",
                    Content = spots[i].name .. " has been set!",
                    Duration = 2,
                    Image = "check"
                })
                saveConfigAs(selectedConfig)
            end
        end
    })
end

SetSpotsTab:CreateDivider()

SetSpotsTab:CreateButton({
    Name = "Clear All Spots",
    Callback = function()
        for i = 1, 4 do
            spots[i].x = 0
            spots[i].y = 0
            spots[i].z = 0
            spots[i].set = false
        end
        Rayfield:Notify({
            Title = "Cleared",
            Content = "All spot positions have been reset!",
            Duration = 2,
            Image = "refresh-cw"
        })
    end
})

-- ========== TAB: FARM CONTROL ==========
local FarmTab = Window:CreateTab("Auto Farm", "repeat")

FarmTab:CreateSection("Farm Settings")

local FarmToggle = FarmTab:CreateToggle({
    Name = "Enable Auto Farm",
    CurrentValue = false,
    Flag = "AutoFarm",
    Callback = function(Value)
        if Value then
            local anySet = false
            for i = 1, 4 do
                if spots[i].set then
                    anySet = true
                    break
                end
            end
            if anySet then
                startFarmLoop()
                Rayfield:Notify({
                    Title = "Auto Farm",
                    Content = "Farming has started!",
                    Duration = 2,
                    Image = "play"
                })
            else
                FarmToggle:Set(false)
                Rayfield:Notify({
                    Title = "Error",
                    Content = "Set at least one spot first!",
                    Duration = 2,
                    Image = "x-circle"
                })
            end
        else
            stopFarmLoop()
            Rayfield:Notify({
                Title = "Auto Farm",
                Content = "Farming has stopped!",
                Duration = 2,
                Image = "pause"
            })
        end
    end
})

FarmTab:CreateDivider()

local FarmTimeSlider = FarmTab:CreateSlider({
    Name = "Time Per Spot-Set to 2.5",
    Range = {1, 15},
    Increment = 0.5,
    Suffix = " sec",
    CurrentValue = settings.loopDelay,
    Flag = "FarmTime",
    Callback = function(Value)
        settings.loopDelay = Value
    end
})

local ClickDelaySlider = FarmTab:CreateSlider({
    Name = "Click Delay-Set to 0.05",
    Range = {0.05, 1},
    Increment = 0.05,
    Suffix = " sec",
    CurrentValue = settings.clickDelay,
    Flag = "ClickDelay",
    Callback = function(Value)
        settings.clickDelay = Value
    end
})

-- ========== TAB: SETTINGS ==========
local SettingsTab = Window:CreateTab("Settings", "settings")

SettingsTab:CreateSection("Configuration")

local CurrentConfigLabel = SettingsTab:CreateLabel("Config: " .. selectedConfig)

local newConfigName = "Default"
local ConfigNameInput = SettingsTab:CreateInput({
    Name = "New Config Name",
    PlaceholderText = "Enter a name...",
    RemoveTextAfterFocusLost = false,
    Callback = function(Text)
        newConfigName = Text
    end
})

local ConfigDropdown
local function refreshConfigDropdown()
    local configs = getConfigList()
    if ConfigDropdown then
        ConfigDropdown:Refresh(configs)
        ConfigDropdown:Set(selectedConfig)
    end
end

ConfigDropdown = SettingsTab:CreateDropdown({
    Name = "Select Config",
    Options = getConfigList(),
    CurrentOption = {selectedConfig},
    MultipleOptions = false,
    Flag = "ConfigDropdown",
    Callback = function(Options)
        if Options[1] then
            selectedConfig = Options[1]
            CurrentConfigLabel:Set("Config: " .. selectedConfig)
        end
    end
})

SettingsTab:CreateButton({
    Name = "Save Config",
    Callback = function()
        local nameToSave = (newConfigName ~= "" and newConfigName) or selectedConfig
        if saveConfigAs(nameToSave) then
            selectedConfig = nameToSave
            CurrentConfigLabel:Set("Config: " .. selectedConfig)
            refreshConfigDropdown()
        end
    end
})

SettingsTab:CreateButton({
    Name = "Load Config",
    Callback = function()
        if loadConfigByName(selectedConfig) then
            CurrentConfigLabel:Set("Config: " .. selectedConfig)
            TweenSpeedSlider:Set(settings.tweenSpeed)
            FarmTimeSlider:Set(settings.loopDelay)
            ClickDelaySlider:Set(settings.clickDelay)
        end
    end
})

SettingsTab:CreateButton({
    Name = "Delete Config",
    Callback = function()
        if selectedConfig == "Default" then
            Rayfield:Notify({
                Title = "Error",
                Content = "Cannot delete Default config!",
                Duration = 2,
                Image = "alert-circle"
            })
            return
        end
        if deleteConfig(selectedConfig) then
            selectedConfig = "Default"
            CurrentConfigLabel:Set("Config: " .. selectedConfig)
            refreshConfigDropdown()
        end
    end
})

SettingsTab:CreateSection("Player Info")

local HealthLabel = SettingsTab:CreateLabel("Health: Loading...")

task.spawn(function()
    while task.wait(0.5) do
        local char = player.Character
        if char then
            local humanoid = char:FindFirstChild("Humanoid")
            if humanoid then
                HealthLabel:Set("Health: " .. math.floor(humanoid.Health) .. " / " .. math.floor(humanoid.MaxHealth))
            end
        end
    end
end)

SettingsTab:CreateSection("Script Controls")

SettingsTab:CreateButton({
    Name = "Destroy GUI",
    Callback = function()
        cleanupScript()
        Rayfield:Destroy()
    end
})

SettingsTab:CreateButton({
    Name = "Unload Script",
    Callback = function()
        cleanupScript()

        -- Destroy floating GUI
        local floatingGui = player:FindFirstChild("PlayerGui") and player.PlayerGui:FindFirstChild("GoldFV3FloatBtn")
        if floatingGui then
            floatingGui:Destroy()
        end

        -- Destroy Rayfield GUI
        Rayfield:Destroy()

        Rayfield:Notify({
            Title = "Script Unloaded",
            Content = "|NodeV1 by iy_66| has been unloaded!",
            Duration = 3,
            Image = "log-out"
        })

        -- Clear all script variables
        spots = nil
        settings = nil
        isLooping = nil
        loopTask = nil
        currentSpot = nil
        selectedConfig = nil

        print("========================================")
        print("  |NodeV1 by iy_66| has been unloaded!")
        print("========================================")
    end
})

-- ========== FLOATING TOGGLE BUTTON (BEAUTIFIED) ==========
local FloatingGui = Instance.new("ScreenGui")
FloatingGui.Name = "GoldFV3FloatBtn"
FloatingGui.ResetOnSpawn = false
FloatingGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
FloatingGui.Parent = player:WaitForChild("PlayerGui")

-- Main button frame
local ButtonFrame = Instance.new("Frame")
ButtonFrame.Size = UDim2.new(0, 90, 0, 44)
ButtonFrame.Position = UDim2.new(1, -110, 0, 20)
ButtonFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
ButtonFrame.BorderSizePixel = 0
ButtonFrame.Parent = FloatingGui

local ButtonCorner = Instance.new("UICorner")
ButtonCorner.CornerRadius = UDim.new(0, 12)
ButtonCorner.Parent = ButtonFrame

local ButtonStroke = Instance.new("UIStroke")
ButtonStroke.Color = Color3.fromRGB(80, 80, 100)
ButtonStroke.Thickness = 2
ButtonStroke.Parent = ButtonFrame

-- Status indicator
local StatusDot = Instance.new("Frame")
StatusDot.Size = UDim2.new(0, 12, 0, 12)
StatusDot.Position = UDim2.new(0, 12, 0.5, -6)
StatusDot.BackgroundColor3 = Color3.fromRGB(220, 80, 80)
StatusDot.BorderSizePixel = 0
StatusDot.Parent = ButtonFrame

local DotCorner = Instance.new("UICorner")
DotCorner.CornerRadius = UDim.new(1, 0)
DotCorner.Parent = StatusDot

-- Button text
local ButtonText = Instance.new("TextLabel")
ButtonText.Size = UDim2.new(1, -35, 1, 0)
ButtonText.Position = UDim2.new(0, 30, 0, 0)
ButtonText.BackgroundTransparency = 1
ButtonText.Text = "OFF"
ButtonText.TextColor3 = Color3.fromRGB(255, 255, 255)
ButtonText.Font = Enum.Font.GothamBold
ButtonText.TextSize = 16
ButtonText.TextXAlignment = Enum.TextXAlignment.Left
ButtonText.Parent = ButtonFrame

-- Clickable button overlay
local FloatingButton = Instance.new("TextButton")
FloatingButton.Size = UDim2.new(1, 0, 1, 0)
FloatingButton.BackgroundTransparency = 1
FloatingButton.Text = ""
FloatingButton.Parent = ButtonFrame

-- Make draggable
local dragging = false
local dragInput, dragStart, startPos

FloatingButton.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = ButtonFrame.Position

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

FloatingButton.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        ButtonFrame.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end
end)

-- Click functionality
FloatingButton.MouseButton1Click:Connect(function()
    if isLooping then
        stopFarmLoop()
        FarmToggle:Set(false)
    else
        local anySet = false
        for i = 1, 4 do
            if spots[i].set then
                anySet = true
                break
            end
        end
        if anySet then
            startFarmLoop()
            FarmToggle:Set(true)
        else
            Rayfield:Notify({
                Title = "Error",
                Content = "Set spots first!",
                Duration = 2,
                Image = "alert-circle"
            })
        end
    end
end)

-- Update floating button state with smooth color transitions
task.spawn(function()
    while FloatingGui and FloatingGui.Parent do
        task.wait(0.3)
        if isLooping then
            ButtonText.Text = "ON"
            TweenService:Create(StatusDot, TweenInfo.new(0.3), {
                BackgroundColor3 = Color3.fromRGB(80, 200, 120)
            }):Play()
            TweenService:Create(ButtonStroke, TweenInfo.new(0.3), {
                Color = Color3.fromRGB(80, 200, 120)
            }):Play()
        else
            ButtonText.Text = "OFF"
            TweenService:Create(StatusDot, TweenInfo.new(0.3), {
                BackgroundColor3 = Color3.fromRGB(220, 80, 80)
            }):Play()
            TweenService:Create(ButtonStroke, TweenInfo.new(0.3), {
                Color = Color3.fromRGB(80, 80, 100)
            }):Play()
        end
    end
end)

-- ========== INITIALIZATION ==========
ensureConfigFolder()
if not loadConfigByName("Default") then
    saveConfigAs("Default")
end

Rayfield:Notify({
    Title = "NodeV1 Loaded",
    Content = "Booga Booga Reborn Edition - Enhanced GUI",
    Duration = 8,
    Image = "gem"
})

