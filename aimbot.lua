local select = select
local pcall, getgenv, next, Vector2, mathclamp = pcall, getgenv, next, Vector2.new, math.clamp

local _mousemoverel = mousemoverel

local function doMouseMove(x, y)
    pcall(_mousemoverel, x, y)
end

pcall(function()
    if getgenv().Aimbot and getgenv().Aimbot.Functions then
        getgenv().Aimbot.Functions:Exit()
    end
end)

getgenv().Aimbot = getgenv().Aimbot or {}
local Environment = getgenv().Aimbot

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

local RequiredDistance, Typing, Running, Animation, ServiceConnections = 2000, false, false, nil, {}
local Shooting = false

Environment.Settings = {
    Enabled = false,
    TeamCheck = false,
    AliveCheck = false,
    WallCheck = false,
    ForceField_Check = false,
    Tool_Check = false,
    GodCheck = false,
    ReactionTime = 0,
    AimbotAutoSelect = false,
    ThirdPerson = false,
    ThirdPersonSensitivity = 3,
    TriggerKey = Enum.KeyCode.J,
    Toggle = false,
    LockPart = "Head",
    Invisible_Check = false,
    ClosestBodyPartAimbot = false,
    IsMainDead = false,
    AimbotFriendCheck = false,
    Sensitivity = 0,
    AutoFire = false,
    JumpOffset = false,
    JumpOffsetAmount = 0,
    JumpOffsetKey = Enum.KeyCode.G,
    SmoothX = 1.0,
    SmoothY = 1.5
}

Environment.FOVSettings = {
    Enabled = false,
    Visible = false,
    Amount = 90,
    Color = Color3.fromRGB(255, 255, 255),
    LockedColor = Color3.fromRGB(255, 70, 70),
    Transparency = 0.5,
    Sides = 60,
    Thickness = 1,
    Filled = false
}

Environment.FOVCircle = Environment.FOVCircle or Drawing.new("Circle")

-- Tracks which part we are actually aiming at without mutating LockPart setting
Environment.ActiveLockPart = nil

local PendingLocks = {}

local function CancelLock()
    Environment.Locked = nil
    Environment.ActiveLockPart = nil
    PendingLocks = {}
    if Animation then Animation:Cancel() end
    Environment.FOVCircle.Color = Environment.FOVSettings.Color
    if Shooting then
        mouse1release()
        Shooting = false
    end
end

local function IsInFOV(targetPosition)
    local mouseLocation = UserInputService:GetMouseLocation()
    local fovCircleRadius = Environment.FOVSettings.Amount
    return (targetPosition - mouseLocation).Magnitude <= fovCircleRadius
end

local function IsObstructed(target)
    if not Environment.Settings.WallCheck then
        return false
    end
    -- Use ActiveLockPart if closest body part mode is on, otherwise use the setting
    local partName = (Environment.Settings.ClosestBodyPartAimbot and Environment.ActiveLockPart)
        or Environment.Settings.LockPart
    local char = target.Character
    if not char then return false end
    local part = char:FindFirstChild(partName)
    if not part then return false end
    local parts = Camera:GetPartsObscuringTarget({part.Position}, {LocalPlayer.Character, char})
    return #parts > 0
end

local function HasForceField(target)
    if not Environment.Settings.ForceField_Check then
        return false
    end
    return target.Character:FindFirstChildOfClass("ForceField") ~= nil
end

local function IsHoldingTool()
    if not Environment.Settings.Tool_Check then
        return true
    end
    return LocalPlayer.Character:FindFirstChildOfClass("Tool") ~= nil
end

local function IsGodded(character)
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return true end
    if humanoid.MaxHealth == math.huge then return true end
    if humanoid.Health == math.huge then return true end
    if character:FindFirstChildOfClass("ForceField") then return true end
    if humanoid.Health >= humanoid.MaxHealth and humanoid.MaxHealth >= 1e10 then return true end
    return false
end

-- Returns the resolved part name for the current lock state
local function GetResolvedPartName()
    return (Environment.Settings.ClosestBodyPartAimbot and Environment.ActiveLockPart)
        or Environment.Settings.LockPart
end

local function GetClosestPlayer()
    if not Environment.Locked then
        RequiredDistance = (Environment.FOVSettings.Enabled and Environment.FOVSettings.Amount or 2000)

        local closestPlayer = nil
        local closestDistance = math.huge

        for _, v in next, Players:GetPlayers() do
            if v ~= LocalPlayer then
                local character = v.Character
                if character and character:FindFirstChild(Environment.Settings.LockPart) and character:FindFirstChildOfClass("Humanoid") then
                    if Environment.Settings.TeamCheck and v.Team == LocalPlayer.Team then continue end
                    if Environment.Settings.AimbotFriendCheck and LocalPlayer:IsFriendsWith(v.UserId) then continue end
                    if Environment.Settings.AliveCheck and character:FindFirstChildOfClass("Humanoid").Health <= 0 then continue end
                    if Environment.Settings.Invisible_Check and character.Head and character.Head.Transparency == 1 then continue end
                    if Environment.Settings.ForceField_Check and HasForceField(v) then continue end
                    if Environment.Settings.GodCheck and IsGodded(character) then continue end

                    local lockPartPosition = character[Environment.Settings.LockPart].Position
                    local Vector, OnScreen = Camera:WorldToViewportPoint(lockPartPosition)
                    local mousePos = UserInputService:GetMouseLocation()
                    local Distance = (Vector2(mousePos.X, mousePos.Y) - Vector2(Vector.X, Vector.Y)).Magnitude

                    if Distance < closestDistance and OnScreen and (not Environment.Settings.WallCheck or not IsObstructed(v)) then
                        if not Environment.FOVSettings.Enabled or IsInFOV(Vector2(Vector.X, Vector.Y)) then
                            closestPlayer = v
                            closestDistance = Distance
                        end
                    end
                end
            end
        end

        if closestPlayer then
            local closestPart = nil
            local closestPartDistance = math.huge

            if Environment.Settings.ClosestBodyPartAimbot then
                local mousePos = Vector2(UserInputService:GetMouseLocation().X, UserInputService:GetMouseLocation().Y)

                for _, part in ipairs(closestPlayer.Character:GetDescendants()) do
                    if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                        local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
                        if onScreen then
                            local distance = (mousePos - Vector2(screenPos.X, screenPos.Y)).Magnitude
                            if distance < closestPartDistance then
                                closestPart = part
                                closestPartDistance = distance
                            end
                        end
                    end
                end

                -- Fallback if nothing found
                if not closestPart then
                    closestPart = closestPlayer.Character:FindFirstChild("HumanoidRootPart")
                        or closestPlayer.Character:FindFirstChild("Torso")
                    closestPartDistance = closestDistance
                end
            else
                closestPart = closestPlayer.Character:FindFirstChild(Environment.Settings.LockPart)
                closestPartDistance = closestDistance
            end

            if closestPart then
                RequiredDistance = closestPartDistance

                -- Store the target part name separately; do NOT overwrite LockPart setting
                local targetPartName = closestPart.Name

                if Environment.Settings.ReactionTime > 0 then
                    if not PendingLocks[closestPlayer] then
                        PendingLocks[closestPlayer] = {
                            time   = tick(),
                            part   = targetPartName,
                            player = closestPlayer,
                        }
                    end

                    local pending = PendingLocks[closestPlayer]
                    if pending and (tick() - pending.time) >= Environment.Settings.ReactionTime then
                        Environment.Locked = closestPlayer
                        Environment.ActiveLockPart = pending.part
                        PendingLocks[closestPlayer] = nil
                    end
                else
                    Environment.Locked = closestPlayer
                    Environment.ActiveLockPart = targetPartName
                    PendingLocks = {}
                end
            end
        end

    else
        -- Already locked — validate the lock is still valid
        local resolvedPart = GetResolvedPartName()
        local lockedChar = Environment.Locked.Character
        local lockPartObj = lockedChar and lockedChar:FindFirstChild(resolvedPart)

        if not lockPartObj then
            CancelLock()
            return
        end

        local lockPartPosition = lockPartObj.Position
        local mousePos = UserInputService:GetMouseLocation()
        local screenPos = Camera:WorldToViewportPoint(lockPartPosition)

        if Environment.Settings.WallCheck and IsObstructed(Environment.Locked) then
            CancelLock()
        elseif (Vector2(mousePos.X, mousePos.Y) - Vector2(screenPos.X, screenPos.Y)).Magnitude > RequiredDistance then
            CancelLock()
        end
    end
end

ServiceConnections.TypingStartedConnection = UserInputService.TextBoxFocused:Connect(function()
    Typing = true
end)

ServiceConnections.TypingEndedConnection = UserInputService.TextBoxFocusReleased:Connect(function()
    Typing = false
end)

local function Load()
    local UserInputService_GetMouseLocation = UserInputService.GetMouseLocation
    local Camera_WorldToViewportPoint = Camera.WorldToViewportPoint
    local mathclamp = math.clamp

    ServiceConnections.RenderSteppedConnection = RunService.RenderStepped:Connect(function()
        -- FOV circle
        if Environment.FOVSettings.Enabled then
            local mouseLocation = UserInputService_GetMouseLocation(UserInputService)
            local fovCircle = Environment.FOVCircle
            fovCircle.Radius = Environment.FOVSettings.Amount
            fovCircle.Thickness = Environment.FOVSettings.Thickness
            fovCircle.Filled = Environment.FOVSettings.Filled
            fovCircle.NumSides = Environment.FOVSettings.Sides
            fovCircle.Color = Environment.Locked and Environment.FOVSettings.LockedColor or Environment.FOVSettings.Color
            fovCircle.Transparency = Environment.FOVSettings.Transparency
            fovCircle.Visible = Environment.FOVSettings.Visible
            fovCircle.Position = Vector2(mouseLocation.X, mouseLocation.Y)
        else
            Environment.FOVCircle.Visible = false
        end

        -- Aimbot only runs when Running is true (trigger key held/toggled)
        if Running and (Environment.Settings.Enabled or Environment.Settings.AimbotAutoSelect) then
            if IsHoldingTool() then
                if Environment.Settings.IsMainDead then
                    local humanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                    if humanoid and humanoid.Health <= 0 then
                        CancelLock()
                        return
                    end
                end

                GetClosestPlayer()

                if Environment.Locked then
                    -- Resolve which part to aim at this frame
                    local resolvedPart = GetResolvedPartName()
                    local lockedChar = Environment.Locked.Character
                    local lockPartObj = lockedChar and lockedChar:FindFirstChild(resolvedPart)

                    if not lockPartObj then
                        CancelLock()
                        return
                    end

                    local lockPartPosition = lockPartObj.Position

                    if Environment.Settings.JumpOffset then
                        lockPartPosition = lockPartPosition + Vector3.new(0, Environment.Settings.JumpOffsetAmount, 0)
                    end

                    if Environment.Settings.ThirdPerson then
                        Environment.Settings.ThirdPersonSensitivity = mathclamp(Environment.Settings.ThirdPersonSensitivity, 0.1, 5)
                        local vec = Camera_WorldToViewportPoint(Camera, lockPartPosition)
                        local mouseLocation = UserInputService_GetMouseLocation(UserInputService)

                        local dx = vec.X - mouseLocation.X
                        local dy = vec.Y - mouseLocation.Y

                        local baseFactor = mathclamp(Environment.Settings.ThirdPersonSensitivity / 10, 0.01, 1)

                        obj_lastDY = obj_lastDY or dy
                        local dyDelta = math.abs(dy - obj_lastDY)
                        obj_lastDY = dy

                        local verticalMotion = mathclamp(dyDelta / 10, 0, 1)
                        local smoothX = baseFactor
                        local smoothY = baseFactor + (verticalMotion * (1 - baseFactor))

                        local moveX = dx * smoothX
                        local moveY = dy * smoothY

                        if math.abs(dx) > 0.5 or math.abs(dy) > 0.5 then
                            doMouseMove(moveX, moveY)
                        end

                    else
                        if Environment.Settings.Sensitivity > 0 then
                            Animation = TweenService:Create(Camera, TweenInfo.new(Environment.Settings.Sensitivity, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {CFrame = CFrame.new(Camera.CFrame.Position, lockPartPosition)})
                            Animation:Play()
                        else
                            Camera.CFrame = CFrame.new(Camera.CFrame.Position, lockPartPosition)
                        end
                    end

                    Environment.FOVCircle.Color = Environment.FOVSettings.LockedColor

                    if Environment.Settings.AutoFire then
                        if not Shooting then
                            mouse1press()
                            Shooting = true
                        end
                    end
                else
                    if Shooting then
                        mouse1release()
                        Shooting = false
                    end
                end
            end
        end
    end)

    ServiceConnections.InputBeganConnection = UserInputService.InputBegan:Connect(function(Input)
        if not Typing then
            local triggerKey = Environment.Settings.TriggerKey
            local isMatch = false

            if typeof(triggerKey) == "EnumItem" then
                if triggerKey.EnumType == Enum.KeyCode then
                    isMatch = Input.KeyCode == triggerKey
                else
                    isMatch = Input.UserInputType == triggerKey
                end
            end

            if isMatch then
                if Environment.Settings.Toggle then
                    Running = not Running
                    if not Running then CancelLock() end
                else
                    Running = true
                end
            end

            if Input.KeyCode == Environment.Settings.JumpOffsetKey then
                Environment.Settings.JumpOffset = true
            end
        end
    end)

    ServiceConnections.InputEndedConnection = UserInputService.InputEnded:Connect(function(Input)
        if not Typing then
            local triggerKey = Environment.Settings.TriggerKey
            local isMatch = false

            if typeof(triggerKey) == "EnumItem" then
                if triggerKey.EnumType == Enum.KeyCode then
                    isMatch = Input.KeyCode == triggerKey
                else
                    isMatch = Input.UserInputType == triggerKey
                end
            end

            if isMatch and not Environment.Settings.Toggle then
                Running = false
                CancelLock()
            end

            if Input.KeyCode == Environment.Settings.JumpOffsetKey then
                Environment.Settings.JumpOffset = false
            end
        end
    end)
end

Environment.Functions = {}

function Environment.Functions:Exit()
    for _, connection in next, ServiceConnections do
        connection:Disconnect()
    end
    if Animation then Animation:Cancel() end
    if Environment.FOVCircle then Environment.FOVCircle:Remove() end
    if Shooting then
        mouse1release()
        Shooting = false
    end
end

Load()
