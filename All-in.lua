-- ============================================================
-- NxReborn - Booga Booga Reborn Edition (Enhanced & Beautified)
-- Original by iy_66 and nxploit | Enhanced GUI & Bug Fixes
-- Converted to Fluent UI Library
-- ============================================================
local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local HttpService = game:GetService('HttpService')
local UserInputService = game:GetService('UserInputService')
local VirtualInputManager = game:GetService('VirtualInputManager')
local TweenService = game:GetService('TweenService')
local LocalPlayer = Players.LocalPlayer

-- UserId whitelist
local Whitelist = {
    [2028943444] = true,
    [7319862934] = true
}

if not Whitelist[LocalPlayer.UserId] then
    LocalPlayer:Kick("You Are Not Whitelisted!")
    return
end

-- Load Fluent UI
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

-- ========== SERVICES ==========
local player = Players.LocalPlayer
local mouse = player:GetMouse()

-- ========== CONFIGURATION ==========
local CONFIG_FOLDER = "NxReborn"
local spots = {
    {name = "Spot 1", x = 960, y = -3, z = -1394, set = true},
    {name = "Spot 2", x = 941, y = -3, z = -1436, set = true},
    {name = "Spot 3", x = 923, y = -3, z = -1391, set = true},
    {name = "Spot 4", x = 917, y = -3, z = -1422, set = true},
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

-- Auto Eat variables
local isAutoEating = false
local autoEatConnection = nil
local selectedFood = "Berry"
local hungerThreshold = 85 -- Eat when hunger drops below this percentage

-- Script state variables
local scriptLoaded = true
local guiVisible = true
local FluentGui = nil -- Will store reference to Fluent's ScreenGui

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
        Fluent:Notify({
            Title = "Config Saved",
            Content = "'" .. configName .. "' saved successfully!",
            Duration = 2.5
        })
        return true
    else
        Fluent:Notify({
            Title = "Error",
            Content = "Failed to save config!",
            Duration = 2.5
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
            Fluent:Notify({
                Title = "Config Loaded",
                Content = "'" .. configName .. "' loaded successfully!",
                Duration = 2.5
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
        Fluent:Notify({
            Title = "Config Deleted",
            Content = "'" .. configName .. "' removed!",
            Duration = 2.5
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

    local targetPos = getGroundPosition(Vector3.new(position.x, position.y, position.z))
    local startPos = rootPart.Position
    local distance = (targetPos - startPos).Magnitude

    local maxSpeed = math.min(speed, 50)
    local stepSize = 30
    local steps = math.ceil(distance / stepSize)

    if steps < 1 then steps = 1 end

    pcall(function()
        rootPart.CanCollide = false
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part ~= rootPart then
                part.CanCollide = false
            end
        end
    end)

    for i = 1, steps do
        if not isLooping and i > 1 then break end

        local alpha = i / steps
        local intermediatePos = startPos:Lerp(targetPos, alpha)
        local groundPos = getGroundPosition(intermediatePos)

        local stepDuration = math.max((stepSize / maxSpeed), 0.1)

        local tweenInfo = TweenInfo.new(stepDuration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
        local tween = TweenService:Create(rootPart, tweenInfo, {CFrame = CFrame.new(groundPos)})

        tween:Play()
        tween.Completed:Wait()

        pcall(function()
            humanoid:ChangeState(Enum.HumanoidStateType.Running)
        end)

        task.wait(0.02)
    end

    local finalGround = getGroundPosition(targetPos)
    rootPart.CFrame = CFrame.new(finalGround)

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
                Fluent:Notify({
                    Title = "Farming",
                    Content = "Working at " .. spots[currentSpot].name,
                    Duration = 2
                })
                task.wait(settings.loopDelay)
                stopAutoClick()
            end
            currentSpot = currentSpot + 1
            if currentSpot > 4 then currentSpot = 1 end
        end
    end)
end

-- ========== AUTO EAT FUNCTIONS (HUNGER BAR BASED) ==========
local function eatFood(foodName)
    pcall(function()
        local foods = {
            Lemon = player.PlayerGui.MainGui.RightPanel.Inventory.List:FindFirstChild("Lemon"),
            Bloodfruit = player.PlayerGui.MainGui.RightPanel.Inventory.List:FindFirstChild("Bloodfruit"),
            Berry = player.PlayerGui.MainGui.RightPanel.Inventory.List:FindFirstChild("Berry")
        }

        local food = foods[foodName]
        if food then
            local foodSlot = food.LayoutOrder
            local input = {0, 50, foodSlot, 0}
            local str = {}
            for _, b in ipairs(input) do
                table.insert(str, string.char(b))
            end
            local result = table.concat(str)
            local args = {buffer.fromstring(result)}
            game:GetService("ReplicatedStorage"):WaitForChild("ByteNetReliable"):FireServer(unpack(args))
        end
    end)
end

local function getHungerPercentage()
    local hunger = nil
    pcall(function()
        local hungerLabel = player.PlayerGui.MainGui.Panels.Stats.Bars.Hunger.ValueLabel
        if hungerLabel then
            hunger = tonumber(hungerLabel.Text)
        end
    end)
    return hunger
end

local function startAutoEat()
    if autoEatConnection then
        autoEatConnection:Disconnect()
    end
    isAutoEating = true

    -- Use Heartbeat to continuously check hunger
    autoEatConnection = RunService.Heartbeat:Connect(function()
        if not isAutoEating then return end

        local hunger = getHungerPercentage()
        if hunger and hunger < hungerThreshold then
            eatFood(selectedFood)
        end
    end)
end

local function stopAutoEat()
    isAutoEating = false
    if autoEatConnection then
        autoEatConnection:Disconnect()
        autoEatConnection = nil
    end
end

local function cleanupScript()
    stopFarmLoop()
    stopAutoClick()
    stopAutoEat()
end

-- ========== FLUENT UI GUI ==========
local Window = Fluent:CreateWindow({
    Title = "NxReborn - Booga Booga Reborn",
    SubTitle = "by iy_66 and nxploit",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

Fluent:Notify({
    Title = "NxReborn",
    Content = "Loading script...\nMade by iy_66 and nxploit",
    Duration = 5
})

-- Get reference to Fluent's ScreenGui for toggle functionality
task.spawn(function()
    task.wait(1)
    local playerGui = player:WaitForChild("PlayerGui")
    for _, gui in pairs(playerGui:GetChildren()) do
        if gui:IsA("ScreenGui") and gui.Name ~= "NxRebornFloatBtn" and gui.Name ~= "NxRebornToggleBtn" then
            -- Check for Fluent UI structure
            local isFluentGui = gui:FindFirstChild("Holder")
                or gui:FindFirstChild("Main")
                or (gui:FindFirstChildOfClass("Frame") and gui:FindFirstChild("UICorner", true))
            if isFluentGui then
                FluentGui = gui
                print("NxReborn: Found Fluent GUI - " .. gui.Name)
                break
            end
        end
    end

    -- Fallback: if still not found, get the most recent ScreenGui that isn't ours
    if not FluentGui then
        for _, gui in pairs(playerGui:GetChildren()) do
            if gui:IsA("ScreenGui") and gui.Name ~= "NxRebornFloatBtn" and gui.Name ~= "NxRebornToggleBtn" then
                FluentGui = gui
                print("NxReborn: Using fallback GUI - " .. gui.Name)
                break
            end
        end
    end
end)

-- ========== TAB: TELEPORT ==========
local TeleportTab = Window:AddTab({Title = "Teleport", Icon = "map-pin"})

local TeleportSection = TeleportTab:AddSection("Quick Teleport")

local TweenSpeedSlider = TeleportTab:AddSlider("TweenSpeed", {
    Title = "Movement Speed",
    Description = "Set to 10 recommended",
    Default = settings.tweenSpeed,
    Min = 1,
    Max = 30,
    Rounding = 1,
    Callback = function(Value)
        settings.tweenSpeed = Value
    end
})

for i = 1, 4 do
    TeleportTab:AddButton({
        Title = "Go to " .. spots[i].name,
        Description = spots[i].set and "Position is SET" or "Position NOT SET",
        Callback = function()
            if spots[i].set then
                stopAutoClick()
                smoothTeleport(spots[i], settings.tweenSpeed)
                Fluent:Notify({
                    Title = "Teleported",
                    Content = "Arrived at " .. spots[i].name,
                    Duration = 2
                })
            else
                Fluent:Notify({
                    Title = "Error",
                    Content = "Set " .. spots[i].name .. " position first!",
                    Duration = 2
                })
            end
        end
    })
end

-- ========== TAB: SET SPOTS ==========
local SetSpotsTab = Window:AddTab({Title = "Set Spots", Icon = "crosshair"})

local PositionParagraph = SetSpotsTab:AddParagraph({
    Title = "Current Position",
    Content = "Loading..."
})

task.spawn(function()
    while task.wait(0.5) do
        if not scriptLoaded then break end
        pcall(function()
            local char = player.Character
            if char then
                local root = char:FindFirstChild("HumanoidRootPart")
                if root then
                    local p = root.Position
                    PositionParagraph:SetDesc(string.format("X: %.0f | Y: %.0f | Z: %.0f", p.X, p.Y, p.Z))
                end
            end
        end)
    end
end)

for i = 1, 4 do
    SetSpotsTab:AddButton({
        Title = "Save Position as " .. spots[i].name,
        Description = "Save your current location",
        Callback = function()
            local char = player.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                local pos = char.HumanoidRootPart.Position
                spots[i].x = pos.X
                spots[i].y = pos.Y
                spots[i].z = pos.Z
                spots[i].set = true
                Fluent:Notify({
                    Title = "Position Saved",
                    Content = spots[i].name .. " has been set!",
                    Duration = 2
                })
                saveConfigAs(selectedConfig)
            end
        end
    })
end

SetSpotsTab:AddButton({
    Title = "Clear All Spots",
    Description = "Reset all saved positions",
    Callback = function()
        for i = 1, 4 do
            spots[i].x = 0
            spots[i].y = 0
            spots[i].z = 0
            spots[i].set = false
        end
        Fluent:Notify({
            Title = "Cleared",
            Content = "All spot positions have been reset!",
            Duration = 2
        })
    end
})

-- ========== TAB: AUTO FARM ==========
local FarmTab = Window:AddTab({Title = "Auto Farm", Icon = "repeat"})

local FarmToggle = FarmTab:AddToggle("AutoFarm", {
    Title = "Enable Auto Farm",
    Default = false,
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
                Fluent:Notify({
                    Title = "Auto Farm",
                    Content = "Farming has started!",
                    Duration = 2
                })
            else
                FarmToggle:SetValue(false)
                Fluent:Notify({
                    Title = "Error",
                    Content = "Set at least one spot first!",
                    Duration = 2
                })
            end
        else
            stopFarmLoop()
            Fluent:Notify({
                Title = "Auto Farm",
                Content = "Farming has stopped!",
                Duration = 2
            })
        end
    end
})

local FarmTimeSlider = FarmTab:AddSlider("FarmTime", {
    Title = "Time Per Spot",
    Description = "Set to 2.5 recommended",
    Default = settings.loopDelay,
    Min = 1,
    Max = 15,
    Rounding = 1,
    Callback = function(Value)
        settings.loopDelay = Value
    end
})

local ClickDelaySlider = FarmTab:AddSlider("ClickDelay", {
    Title = "Click Delay",
    Description = "Set to 0.05 recommended",
    Default = settings.clickDelay,
    Min = 0.05,
    Max = 1,
    Rounding = 2,
    Callback = function(Value)
        settings.clickDelay = Value
    end
})

-- ========== TAB: AUTO EAT (HUNGER BAR BASED) ==========
local AutoEatTab = Window:AddTab({Title = "Auto Eat", Icon = "utensils"})

local FoodDropdown = AutoEatTab:AddDropdown("FoodSelect", {
    Title = "Select Food",
    Description = "Choose which food to auto eat",
    Values = {"Berry", "Bloodfruit", "Lemon"},
    Default = "Berry",
    Multi = false,
    Callback = function(Value)
        selectedFood = Value
        Fluent:Notify({
            Title = "Food Selected",
            Content = "Auto eat will use: " .. Value,
            Duration = 2
        })
    end
})

local HungerThresholdSlider = AutoEatTab:AddSlider("HungerThreshold", {
    Title = "Hunger Threshold (%)",
    Description = "Eat when hunger drops below this value",
    Default = 80,
    Min = 10,
    Max = 95,
    Rounding = 0,
    Callback = function(Value)
        hungerThreshold = Value
        Fluent:Notify({
            Title = "Threshold Updated",
            Content = "Will eat when hunger < " .. Value .. "%",
            Duration = 2
        })
    end
})

local HungerParagraph = AutoEatTab:AddParagraph({
    Title = "Current Hunger",
    Content = "Loading..."
})

-- Update hunger display
task.spawn(function()
    while task.wait(0.5) do
        if not scriptLoaded then break end
        pcall(function()
            local hunger = getHungerPercentage()
            if hunger then
                HungerParagraph:SetDesc("Hunger: " .. hunger .. "% | Threshold: " .. hungerThreshold .. "%")
            else
                HungerParagraph:SetDesc("Unable to read hunger")
            end
        end)
    end
end)

local AutoEatToggle = AutoEatTab:AddToggle("AutoEat", {
    Title = "Enable Auto Eat",
    Description = "Automatically eat when hunger drops below threshold",
    Default = false,
    Callback = function(Value)
        if Value then
            startAutoEat()
            Fluent:Notify({
                Title = "Auto Eat",
                Content = "Will eat " .. selectedFood .. " when hunger < " .. hungerThreshold .. "%",
                Duration = 2
            })
        else
            stopAutoEat()
            Fluent:Notify({
                Title = "Auto Eat",
                Content = "Auto eat has stopped!",
                Duration = 2
            })
        end
    end
})

AutoEatTab:AddButton({
    Title = "Eat Once",
    Description = "Eat selected food once",
    Callback = function()
        eatFood(selectedFood)
        Fluent:Notify({
            Title = "Food Eaten",
            Content = "Ate " .. selectedFood,
            Duration = 1
        })
    end
})

-- ========== TAB: SETTINGS ==========
local SettingsTab = Window:AddTab({Title = "Settings", Icon = "settings"})

local ConfigInput = SettingsTab:AddInput("ConfigName", {
    Title = "Config Name",
    Default = "Default",
    Placeholder = "Enter config name...",
    Numeric = false,
    Finished = false,
    Callback = function(Value)
        selectedConfig = Value
    end
})

SettingsTab:AddButton({
    Title = "Save Config",
    Description = "Save current settings",
    Callback = function()
        saveConfigAs(selectedConfig)
    end
})

SettingsTab:AddButton({
    Title = "Load Config",
    Description = "Load saved settings",
    Callback = function()
        loadConfigByName(selectedConfig)
    end
})

SettingsTab:AddButton({
    Title = "Delete Config",
    Description = "Remove saved config",
    Callback = function()
        if selectedConfig == "Default" then
            Fluent:Notify({
                Title = "Error",
                Content = "Cannot delete Default config!",
                Duration = 2
            })
            return
        end
        deleteConfig(selectedConfig)
    end
})

local HealthParagraph = SettingsTab:AddParagraph({
    Title = "Player Health",
    Content = "Loading..."
})

task.spawn(function()
    while task.wait(0.5) do
        if not scriptLoaded then break end
        pcall(function()
            local char = player.Character
            if char then
                local humanoid = char:FindFirstChild("Humanoid")
                if humanoid then
                    HealthParagraph:SetDesc("Health: " .. math.floor(humanoid.Health) .. " / " .. math.floor(humanoid.MaxHealth))
                end
            end
        end)
    end
end)

SettingsTab:AddButton({
    Title = "Destroy GUI",
    Description = "Close the interface",
    Callback = function()
        cleanupScript()
        Window:Destroy()
    end
})

-- ========== UNLOAD SCRIPT BUTTON ==========
SettingsTab:AddButton({
    Title = "Unload Script",
    Description = "Completely unload and remove the script",
    Callback = function()
        Fluent:Notify({
            Title = "Unloading",
            Content = "Script is being unloaded...",
            Duration = 2
        })

        -- Stop all running tasks
        scriptLoaded = false
        cleanupScript()

        -- Small delay to show notification
        task.wait(0.5)

        -- Destroy all GUIs
        pcall(function()
            Window:Destroy()
        end)

        -- Remove floating GUIs
        pcall(function()
            local playerGui = player:FindFirstChild("PlayerGui")
            if playerGui then
                local floatingGui = playerGui:FindFirstChild("NxRebornFloatBtn")
                if floatingGui then
                    floatingGui:Destroy()
                end
                local toggleGui = playerGui:FindFirstChild("NxRebornToggleBtn")
                if toggleGui then
                    toggleGui:Destroy()
                end
            end
        end)
    end
})


-- ========== FLOATING TOGGLE BUTTON (FARM ON/OFF) - IMPROVED DESIGN ==========
local FloatingGui = Instance.new("ScreenGui")
FloatingGui.Name = "NxRebornFloatBtn"
FloatingGui.ResetOnSpawn = false
FloatingGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
FloatingGui.Parent = player:WaitForChild("PlayerGui")

-- Main container with shadow
local ButtonShadow = Instance.new("Frame")
ButtonShadow.Size = UDim2.new(0, 120, 0, 50)
ButtonShadow.Position = UDim2.new(1, -140, 0, 20)
ButtonShadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
ButtonShadow.BackgroundTransparency = 0.7
ButtonShadow.BorderSizePixel = 0
ButtonShadow.Parent = FloatingGui

local ShadowCorner = Instance.new("UICorner")
ShadowCorner.CornerRadius = UDim.new(0, 16)
ShadowCorner.Parent = ButtonShadow

local ButtonFrame = Instance.new("Frame")
ButtonFrame.Size = UDim2.new(0, 116, 0, 46)
ButtonFrame.Position = UDim2.new(0, 2, 0, 2)
ButtonFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
ButtonFrame.BorderSizePixel = 0
ButtonFrame.Parent = ButtonShadow

local ButtonCorner = Instance.new("UICorner")
ButtonCorner.CornerRadius = UDim.new(0, 14)
ButtonCorner.Parent = ButtonFrame

-- Gradient overlay
local ButtonGradient = Instance.new("UIGradient")
ButtonGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(45, 45, 60)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(25, 25, 35))
})
ButtonGradient.Rotation = 90
ButtonGradient.Parent = ButtonFrame

local ButtonStroke = Instance.new("UIStroke")
ButtonStroke.Color = Color3.fromRGB(255, 80, 80)
ButtonStroke.Thickness = 2
ButtonStroke.Transparency = 0.3
ButtonStroke.Parent = ButtonFrame

-- Toggle switch background
local SwitchBg = Instance.new("Frame")
SwitchBg.Size = UDim2.new(0, 44, 0, 24)
SwitchBg.Position = UDim2.new(0, 10, 0.5, -12)
SwitchBg.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
SwitchBg.BorderSizePixel = 0
SwitchBg.Parent = ButtonFrame

local SwitchBgCorner = Instance.new("UICorner")
SwitchBgCorner.CornerRadius = UDim.new(1, 0)
SwitchBgCorner.Parent = SwitchBg

-- Toggle switch knob
local SwitchKnob = Instance.new("Frame")
SwitchKnob.Size = UDim2.new(0, 20, 0, 20)
SwitchKnob.Position = UDim2.new(0, 2, 0.5, -10)
SwitchKnob.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
SwitchKnob.BorderSizePixel = 0
SwitchKnob.Parent = SwitchBg

local KnobCorner = Instance.new("UICorner")
KnobCorner.CornerRadius = UDim.new(1, 0)
KnobCorner.Parent = SwitchKnob

-- Knob glow effect
local KnobGlow = Instance.new("UIStroke")
KnobGlow.Color = Color3.fromRGB(255, 100, 100)
KnobGlow.Thickness = 2
KnobGlow.Transparency = 0.5
KnobGlow.Parent = SwitchKnob

-- Status text
local ButtonText = Instance.new("TextLabel")
ButtonText.Size = UDim2.new(0, 50, 1, 0)
ButtonText.Position = UDim2.new(0, 58, 0, 0)
ButtonText.BackgroundTransparency = 1
ButtonText.Text = "OFF"
ButtonText.TextColor3 = Color3.fromRGB(255, 100, 100)
ButtonText.Font = Enum.Font.GothamBlack
ButtonText.TextSize = 16
ButtonText.TextXAlignment = Enum.TextXAlignment.Left
ButtonText.Parent = ButtonFrame

-- Invisible button for interaction
local FloatingButton = Instance.new("TextButton")
FloatingButton.Size = UDim2.new(1, 0, 1, 0)
FloatingButton.BackgroundTransparency = 1
FloatingButton.Text = ""
FloatingButton.Parent = ButtonShadow

-- Improved Draggable with drag detection
local dragging, dragInput, dragStart, startPos = false, nil, nil, nil
local dragMoved = false

FloatingButton.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragMoved = false
        dragStart = input.Position
        startPos = ButtonShadow.Position
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
        if delta.Magnitude > 5 then
            dragMoved = true
        end
        ButtonShadow.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

FloatingButton.MouseButton1Click:Connect(function()
    if isLooping then
        stopFarmLoop()
        FarmToggle:SetValue(false)
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
            FarmToggle:SetValue(true)
        else
            Fluent:Notify({
                Title = "Error",
                Content = "Set spots first!",
                Duration = 2
            })
        end
    end
end)

-- Update floating button state with smooth animations
task.spawn(function()
    while FloatingGui and FloatingGui.Parent do
        task.wait(0.3)
        if not scriptLoaded then break end
        if isLooping then
            -- ON state - Green
            ButtonText.Text = "ON"
            TweenService:Create(ButtonText, TweenInfo.new(0.3), {TextColor3 = Color3.fromRGB(100, 255, 150)}):Play()
            TweenService:Create(SwitchBg, TweenInfo.new(0.3), {BackgroundColor3 = Color3.fromRGB(40, 120, 80)}):Play()
            TweenService:Create(SwitchKnob, TweenInfo.new(0.3, Enum.EasingStyle.Back), {Position = UDim2.new(0, 22, 0.5, -10), BackgroundColor3 = Color3.fromRGB(100, 255, 150)}):Play()
            TweenService:Create(KnobGlow, TweenInfo.new(0.3), {Color = Color3.fromRGB(100, 255, 150)}):Play()
            TweenService:Create(ButtonStroke, TweenInfo.new(0.3), {Color = Color3.fromRGB(100, 255, 150)}):Play()
        else
            -- OFF state - Red
            ButtonText.Text = "OFF"
            TweenService:Create(ButtonText, TweenInfo.new(0.3), {TextColor3 = Color3.fromRGB(255, 100, 100)}):Play()
            TweenService:Create(SwitchBg, TweenInfo.new(0.3), {BackgroundColor3 = Color3.fromRGB(60, 60, 70)}):Play()
            TweenService:Create(SwitchKnob, TweenInfo.new(0.3, Enum.EasingStyle.Back), {Position = UDim2.new(0, 2, 0.5, -10), BackgroundColor3 = Color3.fromRGB(255, 100, 100)}):Play()
            TweenService:Create(KnobGlow, TweenInfo.new(0.3), {Color = Color3.fromRGB(255, 100, 100)}):Play()
            TweenService:Create(ButtonStroke, TweenInfo.new(0.3), {Color = Color3.fromRGB(255, 80, 80)}):Play()
        end
    end
end)


-- ========== MOBILE GUI TOGGLE BUTTON (OPEN/CLOSE GUI) ==========
local ToggleGui = Instance.new("ScreenGui")
ToggleGui.Name = "NxRebornToggleBtn"
ToggleGui.ResetOnSpawn = false
ToggleGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ToggleGui.Parent = player:WaitForChild("PlayerGui")

local ToggleFrame = Instance.new("Frame")
ToggleFrame.Size = UDim2.new(0, 50, 0, 50)
ToggleFrame.Position = UDim2.new(0, 20, 0.5, -25)
ToggleFrame.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
ToggleFrame.BorderSizePixel = 0
ToggleFrame.Parent = ToggleGui

local ToggleCorner = Instance.new("UICorner")
ToggleCorner.CornerRadius = UDim.new(0, 25)
ToggleCorner.Parent = ToggleFrame

local ToggleStroke = Instance.new("UIStroke")
ToggleStroke.Color = Color3.fromRGB(100, 100, 140)
ToggleStroke.Thickness = 2
ToggleStroke.Parent = ToggleFrame

-- Icon for toggle button (menu icon)
local ToggleIcon = Instance.new("TextLabel")
ToggleIcon.Size = UDim2.new(1, 0, 1, 0)
ToggleIcon.BackgroundTransparency = 1
ToggleIcon.Text = "NX"
ToggleIcon.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleIcon.Font = Enum.Font.GothamBold
ToggleIcon.TextSize = 18
ToggleIcon.Parent = ToggleFrame

local ToggleButton = Instance.new("TextButton")
ToggleButton.Size = UDim2.new(1, 0, 1, 0)
ToggleButton.BackgroundTransparency = 1
ToggleButton.Text = ""
ToggleButton.Parent = ToggleFrame

-- Draggable for toggle button
local toggleDragging, toggleDragInput, toggleDragStart, toggleStartPos = false, nil, nil, nil

ToggleButton.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        toggleDragging = true
        toggleDragStart = input.Position
        toggleStartPos = ToggleFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                toggleDragging = false
            end
        end)
    end
end)

ToggleButton.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        toggleDragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == toggleDragInput and toggleDragging then
        local delta = input.Position - toggleDragStart
        ToggleFrame.Position = UDim2.new(toggleStartPos.X.Scale, toggleStartPos.X.Offset + delta.X, toggleStartPos.Y.Scale, toggleStartPos.Y.Offset + delta.Y)
    end
end)

-- Toggle GUI visibility on click
ToggleButton.MouseButton1Click:Connect(function()
    -- Simulate Left Control key press to toggle Fluent GUI
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.LeftControl, false, game)
        task.wait(0.05)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.LeftControl, false, game)
    end)

    guiVisible = not guiVisible

    if guiVisible then
        ToggleIcon.Text = "NX"
        TweenService:Create(ToggleFrame, TweenInfo.new(0.3), {BackgroundColor3 = Color3.fromRGB(45, 45, 60)}):Play()
        TweenService:Create(ToggleStroke, TweenInfo.new(0.3), {Color = Color3.fromRGB(100, 100, 140)}):Play()
    else
        ToggleIcon.Text = "NX"
        TweenService:Create(ToggleFrame, TweenInfo.new(0.3), {BackgroundColor3 = Color3.fromRGB(60, 60, 80)}):Play()
        TweenService:Create(ToggleStroke, TweenInfo.new(0.3), {Color = Color3.fromRGB(80, 180, 120)}):Play()
    end
end)

-- Add visual pulse effect to make toggle button noticeable
task.spawn(function()
    while ToggleGui and ToggleGui.Parent do
        task.wait(2)
        if not scriptLoaded then break end
        if not guiVisible then
            -- Pulse effect when GUI is hidden to remind user
            TweenService:Create(ToggleFrame, TweenInfo.new(0.5), {Size = UDim2.new(0, 55, 0, 55)}):Play()
            task.wait(0.5)
            TweenService:Create(ToggleFrame, TweenInfo.new(0.5), {Size = UDim2.new(0, 50, 0, 50)}):Play()
        end
    end
end)


-- ========== INITIALIZATION ==========
ensureConfigFolder()
if not loadConfigByName("Default") then
    saveConfigAs("Default")
end

Fluent:Notify({
    Title = "NxReborn Loaded",
    Content = "Booga Booga Reborn Edition - Fluent UI\nTap NX button to toggle GUI",
    Duration = 5
})
