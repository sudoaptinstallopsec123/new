local TriggerBot = {}

TriggerBot.Settings = {
    Enabled        = false,
    TeamCheck      = false,
    AliveCheck     = true,
    InvisCheck     = true,
    GodCheck       = false,
    WallCheck      = true,
    FriendCheck    = false,
    ForceFieldCheck = false,
    ReactionTime   = 0,      -- seconds before clicking
    Delay          = 0.1,    -- seconds between clicks
    HoldTime       = 0.05,   -- how long to hold click (increase for auto guns)
    RaycastDistance = 500,
}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local lastShot = 0
local pendingShot = nil
local isShooting = false
local connection

local function isGodded(character)
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return true end
    if humanoid.MaxHealth == math.huge then return true end
    if humanoid.Health == math.huge then return true end
    if humanoid.MaxHealth >= 1e10 then return true end
    return false
end

local function isInvisible(character)
    local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
    if torso and torso.Transparency >= 0.99 then return true end
    local totalParts, invisParts = 0, 0
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            totalParts = totalParts + 1
            if part.Transparency >= 0.99 then
                invisParts = invisParts + 1
            end
        end
    end
    if totalParts > 0 and (invisParts / totalParts) >= 0.75 then return true end
    return false
end

local function isObstructed(character)
    if not TriggerBot.Settings.WallCheck then return false end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return false end
    local origin = Camera.CFrame.Position
    local target = rootPart.Position
    local ignoreList = { LocalPlayer.Character, character }
    local ray = Ray.new(origin, (target - origin).Unit * TriggerBot.Settings.RaycastDistance)
    local hit = workspace:FindPartOnRayWithIgnoreList(ray, ignoreList)
    return hit ~= nil
end

local function hasForceField(character)
    if not TriggerBot.Settings.ForceFieldCheck then return false end
    return character:FindFirstChildOfClass("ForceField") ~= nil
end

local function isValidTarget(player, character)
    if player == LocalPlayer then return false end
    if not character then return false end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return false end

    if TriggerBot.Settings.TeamCheck then
        if player.Team ~= nil and player.Team == LocalPlayer.Team then return false end
    end

    if TriggerBot.Settings.FriendCheck then
        if LocalPlayer:IsFriendsWith(player.UserId) then return false end
    end

    if TriggerBot.Settings.AliveCheck then
        if humanoid.Health <= 0 then return false end
    end

    if TriggerBot.Settings.InvisCheck then
        if isInvisible(character) then return false end
    end

    if TriggerBot.Settings.GodCheck then
        if isGodded(character) then return false end
    end

    if TriggerBot.Settings.ForceFieldCheck then
        if hasForceField(character) then return false end
    end

    if TriggerBot.Settings.WallCheck then
        if isObstructed(character) then return false end
    end

    return true
end

local function getPlayerFromRaycast()
    local mouseLocation = UserInputService:GetMouseLocation()
    local unitRay = Camera:ViewportPointToRay(mouseLocation.X, mouseLocation.Y)
    local ray = Ray.new(unitRay.Origin, unitRay.Direction * TriggerBot.Settings.RaycastDistance)
    local ignoreList = { LocalPlayer.Character }
    local hit = workspace:FindPartOnRayWithIgnoreList(ray, ignoreList)

    if hit then
        local character = hit:FindFirstAncestorWhichIsA("Model")
        if character then
            local player = Players:GetPlayerFromCharacter(character)
            if player and isValidTarget(player, character) then
                return player
            end
        end
    end

    return nil
end

local function doShot()
    if isShooting then return end
    isShooting = true
    mouse1press()
    task.delay(TriggerBot.Settings.HoldTime, function()
        mouse1release()
        isShooting = false
        lastShot = tick()
    end)
end

local function start()
    if connection then connection:Disconnect() end

    connection = RunService.Heartbeat:Connect(function()
        if not TriggerBot.Settings.Enabled then
            if isShooting then
                mouse1release()
                isShooting = false
            end
            return
        end

        local target = getPlayerFromRaycast()

        if target then
            local now = tick()

            -- respect delay between shots
            if (now - lastShot) < TriggerBot.Settings.Delay then return end

            if TriggerBot.Settings.ReactionTime > 0 then
                if not pendingShot then
                    pendingShot = now
                end

                if (now - pendingShot) >= TriggerBot.Settings.ReactionTime then
                    doShot()
                    pendingShot = nil
                end
            else
                doShot()
            end
        else
            -- no target, cancel pending and release if somehow still held
            pendingShot = nil
            if isShooting then
                mouse1release()
                isShooting = false
            end
        end
    end)
end

function TriggerBot:Start()
    start()
end

function TriggerBot:Stop()
    if connection then
        connection:Disconnect()
        connection = nil
    end
    pendingShot = nil
    isShooting = false
    mouse1release()
end

TriggerBot:Start()

return TriggerBot
