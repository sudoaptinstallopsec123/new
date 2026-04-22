local select = select
local pcall, getgenv, next, Vector2, mathclamp = pcall, getgenv, next, Vector2.new, math.clamp

-- keep mousemoverel as the global, don't reassign it
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
    ReactionTime = 0,  -- in seconds, 0 = instant
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
    JumpOffsetKey = Enum.KeyCode.G
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

local function CancelLock()
    Environment.Locked = nil
    PendingLocks = {}       -- add this
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
    local targetPosition = target.Character[Environment.Settings.LockPart].Position
    local parts = Camera:GetPartsObscuringTarget({targetPosition}, {LocalPlayer.Character, target.Character})
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

local PendingLocks = {}

local function IsGodded(character)
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return true end
    if humanoid.MaxHealth == math.huge then return true end
    if humanoid.Health == math.huge then return true end
    -- check for forcefield
    if character:FindFirstChildOfClass("ForceField") then return true end
    -- check if taking no damage (health locked at max)
    if humanoid.Health >= humanoid.MaxHealth and humanoid.MaxHealth > 0 then
        -- could be full health legitimately, so only skip if maxhealth is suspiciously high
        if humanoid.MaxHealth >= 1e10 then return true end
    end
    return false
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
                    if Environment.Settings.GodCheck and IsGodded(character) then continue end  -- add this

                    local lockPartPosition = character[Environment.Settings.LockPart].Position
                    local Vector, OnScreen = Camera:WorldToViewportPoint(lockPartPosition)
                    local Distance = (Vector2(UserInputService:GetMouseLocation().X, UserInputService:GetMouseLocation().Y) - Vector2(Vector.X, Vector.Y)).Magnitude

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
                for _, part in ipairs(closestPlayer.Character:GetChildren()) do
                    if part:IsA("BasePart") then
                        local distance = (part.Position - Mouse.Hit.p).Magnitude
                        if distance < closestPartDistance then
                            closestPart = part
                            closestPartDistance = distance
                        end
                    end
                end
            else
                closestPart = closestPlayer.Character:FindFirstChild(Environment.Settings.LockPart)
                closestPartDistance = closestDistance
            end

                        if closestPart then
                RequiredDistance = closestPartDistance
                Environment.Settings.LockPart = closestPart.Name
                        
                if Environment.Settings.ReactionTime > 0 then
                    -- check if we already have a pending lock for this player
                    if not PendingLocks[closestPlayer] then
                        PendingLocks[closestPlayer] = {
                            time    = tick(),
                            part    = closestPart.Name,
                            player  = closestPlayer,
                        }
                    end
                
                    -- check if reaction time has passed
                    local pending = PendingLocks[closestPlayer]
                    if pending and (tick() - pending.time) >= Environment.Settings.ReactionTime then
                        Environment.Locked = closestPlayer
                        Environment.Settings.LockPart = pending.part
                        PendingLocks[closestPlayer] = nil
                    end
                else
                    Environment.Locked = closestPlayer
                    PendingLocks = {}
                end
            end
        end
    else
        local lockPartPosition = Environment.Locked.Character[Environment.Settings.LockPart].Position
        if Environment.Settings.WallCheck and IsObstructed(Environment.Locked) then
            CancelLock()
        elseif (Vector2(UserInputService:GetMouseLocation().X, UserInputService:GetMouseLocation().Y) - Vector2(Camera:WorldToViewportPoint(lockPartPosition).X, Camera:WorldToViewportPoint(lockPartPosition).Y)).Magnitude > RequiredDistance then
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
        if Environment.FOVSettings.Enabled and Environment.Settings.Enabled then
            local mouseLocation = UserInputService_GetMouseLocation(UserInputService)
            local fovCircle = Environment.FOVCircle
            fovCircle.Radius = Environment.FOVSettings.Amount
            fovCircle.Thickness = Environment.FOVSettings.Thickness
            fovCircle.Filled = Environment.FOVSettings.Filled
            fovCircle.NumSides = Environment.FOVSettings.Sides
            fovCircle.Color = Environment.FOVSettings.Color
            fovCircle.Transparency = Environment.FOVSettings.Transparency
            fovCircle.Visible = Environment.FOVSettings.Visible
            fovCircle.Position = Vector2(mouseLocation.X, mouseLocation.Y)
        else
            Environment.FOVCircle.Visible = false
        end -- closes FOVSettings if

        if (Running or Environment.Settings.AimbotAutoSelect) and Environment.Settings.Enabled then
            if IsHoldingTool() then
                if Environment.Settings.IsMainDead then
                    local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                    if humanoid and humanoid.Health <= 0 then
                        CancelLock()
                        return
                    end
                end -- closes IsMainDead if

                GetClosestPlayer()

                if Environment.Locked then
                    local lockPartPosition = Environment.Locked.Character[Environment.Settings.LockPart].Position

                    if Environment.Settings.JumpOffset then
                        lockPartPosition = lockPartPosition + Vector3.new(0, Environment.Settings.JumpOffsetAmount, 0)
                    end -- closes JumpOffset if

                    if Environment.Settings.ThirdPerson then
                        Environment.Settings.ThirdPersonSensitivity = mathclamp(Environment.Settings.ThirdPersonSensitivity, 0.1, 5)
                        local vec = Camera_WorldToViewportPoint(Camera, lockPartPosition)
                        local mouseLocation = UserInputService_GetMouseLocation(UserInputService)
                        local dx = vec.X - mouseLocation.X
                        local dy = vec.Y - mouseLocation.Y
                        local smoothFactor = mathclamp(Environment.Settings.ThirdPersonSensitivity / 10, 0.01, 1)
                        local smoothX = dx * smoothFactor
                        local smoothY = dy * smoothFactor
                        if math.abs(dx) > 0.5 or math.abs(dy) > 0.5 then
                            doMouseMove(smoothX, smoothY)
                        end -- closes abs if
                    else
                        if Environment.Settings.Sensitivity > 0 then
                            Animation = TweenService:Create(Camera, TweenInfo.new(Environment.Settings.Sensitivity, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {CFrame = CFrame.new(Camera.CFrame.Position, lockPartPosition)})
                            Animation:Play()
                        else
                            Camera.CFrame = CFrame.new(Camera.CFrame.Position, lockPartPosition)
                        end -- closes Sensitivity if
                    end -- closes ThirdPerson if

                    Environment.FOVCircle.Color = Environment.FOVSettings.LockedColor

                    if Environment.Settings.AutoFire then
                        if not Shooting then
                            mouse1press()
                            Shooting = true
                        end -- closes not Shooting if
                    end -- closes AutoFire if
                else
                    if Shooting then
                        mouse1release()
                        Shooting = false
                    end -- closes Shooting if
                end -- closes Environment.Locked if
            end -- closes IsHoldingTool if
        end -- closes Running if
    end) -- closes RenderStepped

    ServiceConnections.InputBeganConnection = UserInputService.InputBegan:Connect(function(Input)
        if not Typing then
            local triggerKey = Environment.Settings.TriggerKey
            local isMatch = false

            if typeof(triggerKey) == "EnumItem" then
                if triggerKey.EnumType == Enum.KeyCode then
                    isMatch = Input.KeyCode == triggerKey
                elseif triggerKey.EnumType == Enum.UserInputType then
                    isMatch = Input.UserInputType == triggerKey
                        and Input.UserInputType ~= Enum.UserInputType.Unknown
                end
            end -- closes typeof if

            if isMatch then
                if Environment.Settings.Toggle then
                    Running = not Running
                    if not Running then CancelLock() end
                else
                    Running = true
                end
            end -- closes isMatch if

            if Input.KeyCode == Environment.Settings.JumpOffsetKey then
                Environment.Settings.JumpOffset = true
            end
        end
    end) -- closes InputBegan

    ServiceConnections.InputEndedConnection = UserInputService.InputEnded:Connect(function(Input)
        if not Typing then
            local triggerKey = Environment.Settings.TriggerKey
            local isMatch = false

            if typeof(triggerKey) == "EnumItem" then
                if triggerKey.EnumType == Enum.KeyCode then
                    isMatch = Input.KeyCode == triggerKey
                elseif triggerKey.EnumType == Enum.UserInputType then
                    isMatch = Input.UserInputType == triggerKey
                        and Input.UserInputType ~= Enum.UserInputType.Unknown
                end
            end -- closes typeof if

            if isMatch and not Environment.Settings.Toggle then
                Running = false
                CancelLock()
            end

            if Input.KeyCode == Environment.Settings.JumpOffsetKey then
                Environment.Settings.JumpOffset = false
            end
        end
    end) -- closes InputEnded
end -- closes Load()


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
