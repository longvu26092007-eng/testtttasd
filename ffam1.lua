--[[
    KATAKURI COORDINATOR CLIENT V5 - ROOM FIRST
    Standalone Cake Prince farm + 20-tab shared server coordination.

    Design goals:
      - Team is always Marines.
      - No quest taking.
      - Cake Prince only (no Dough King).
      - Qualified server = remaining <= 150, spawn-ready, BigMirror ready, or Cake Prince exists.
      - ROOM FIRST: shared rooms always beat Server Browser.
      - Each client retries each shared room at most 2 times before moving to the next room.
      - Server Browser max 100 pages; ONLY 4/5/6-player servers, priority 4 -> 5 -> 6.
      - All 20 tabs scout, but candidate claims stop duplicate scouting.
      - One state machine owns movement/combat/hop decisions.
]]

repeat task.wait(0.25) until game:IsLoaded()
    and game:GetService("Players").LocalPlayer
    and game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")

-- ============================================================================
-- [01] FIXED CONFIG
-- ============================================================================
-- Core Katakuri behavior is intentionally hard-coded so 20 tabs all run the
-- same coordination rules. The only external knobs left are:
--   getgenv().fragmenttarget
--   getgenv().race
local ENV = getgenv()

-- ============================================================================
-- [01A] FRAGMENT TARGET + RACE TARGET
-- ============================================================================
-- Example:
--   getgenv().fragmenttarget = 10000
--   getgenv().race = "Human"
--
-- Alias:
--   Rabbit/Mink, Shark/Fish/Fishman, Angel/Skypiea,
--   Human, Ghoul, Cyborg.
--
-- nil / "" / "off" = skip race gate.
-- When Fragment >= fragmenttarget AND race is correct:
--   <PlayerName>.txt = "Completed-fragment"
ENV.fragmenttarget = ENV.fragmenttarget
ENV.race = ENV.race

local RaceFeature = {
    Target = nil,
    Ready = true,
    DriverRunning = false,
    Completed = false,
    LastActionAt = 0,
    LastLogAt = 0,
    LastCheckAt = 0,
    CompletionFile = nil,
}

local RACE_ALIAS = {
    rabbit = "Mink", mink = "Mink",
    shark = "Fishman", fish = "Fishman", fishman = "Fishman",
    angel = "Skypiea", skypiea = "Skypiea",
    human = "Human", ghoul = "Ghoul", cyborg = "Cyborg",
}

local REROLLABLE_RACES = {
    Mink = true,
    Fishman = true,
    Skypiea = true,
    Human = true,
}

local Config = {
    Team = "Marines",

    -- Cake Prince.
    TotalRequired = 500,
    QualifiedRemaining = 150,
    ProgressPollInterval = 0.65,
    ProgressUnknownGrace = 3.0,

    -- Server Browser: fixed rules.
    BrowserMaxPages = 100,
    BrowserBatchSize = 20,
    BrowserBatchTimeout = 0.75,
    BrowserCacheSeconds = 1.0,
    CandidateLocalBlacklistSeconds = 90,

    -- Shared room joining.
    WSUrl = "ws://127.0.0.1:9877",
    RoomRequestInterval = 0.08,
    RoomReplyTimeout = 0.35,
    RoomHeartbeatInterval = 0.65,
    ClientHeartbeatInterval = 1.5,
    WSAckTimeout = 3.0,
    WSStaleSeconds = 20,
    ClaimReplyTimeout = 0.25,
    TeleportWaitSeconds = 3.5,

    -- Farm/combat.
    TweenSpeed = 340,
    MobHoverHeight = 20,
    BossHoverHeight = 25,
    BringRadius = 350,
    AttackRadius = 75,
    AttackInterval = 0.035,
    HoverFollowSharpness = 24,
    HoverSnapDistance = 6,
    BusoCheckInterval = 0.75,
    BusoRetryCooldown = 1.25,
    SpawnerCooldown = 1.0,
    MirrorTouchCooldown = 1.0,

    UIUpdateInterval = 0.45,
    Debug = false,
}

local ALLOWED_BROWSER_PLAYERS = {
    [4] = true,
    [5] = true,
    [6] = true,
}

-- ============================================================================
-- [02] SERVICES / CONSTANTS
-- ============================================================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local VirtualUser = game:GetService("VirtualUser")
local StarterGui = game:GetService("StarterGui")
local CoreGui = game:GetService("CoreGui")

local Player = Players.LocalPlayer
local COMMF_ = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CommF_")
local ServerBrowser = ReplicatedStorage:WaitForChild("__ServerBrowser")
local Enemies = workspace:WaitForChild("Enemies")

local CAKE_MOBS = {
    ["Cookie Crafter"] = true,
    ["Cake Guard"] = true,
    ["Baking Staff"] = true,
    ["Head Baker"] = true,
}

local SEA3_PLACE_IDS = {
    [7449423635] = true,
    [100117331123089] = true,
}

local function debugPrint(...)
    if Config.Debug then
        print("[KATAKURI]", ...)
    end
end

-- Forward declaration: Fragment/Race helpers below are defined before the
-- state table is constructed, but they must capture this local State.
local State

local function currentFragments()
    local ok, value = pcall(function()
        local data = Player:FindFirstChild("Data")
        local fragments = data and data:FindFirstChild("Fragments")
        return fragments and fragments.Value or nil
    end)
    value = ok and tonumber(value) or nil
    State.CurrentFragments = value or 0
    return value
end

local function currentRace()
    local ok, value = pcall(function()
        local data = Player:FindFirstChild("Data")
        local race = data and data:FindFirstChild("Race")
        return race and tostring(race.Value) or nil
    end)
    return ok and value or nil
end

local function resolveRaceTarget()
    local raw = ENV.race
    if raw == nil then
        RaceFeature.Target = nil
        RaceFeature.Ready = true
        State.RaceTarget = nil
        State.RaceReady = true
        return nil
    end

    local key = tostring(raw):lower():gsub("%s+", "")
    if key == "" or key == "off" or key == "false" then
        RaceFeature.Target = nil
        RaceFeature.Ready = true
        State.RaceTarget = nil
        State.RaceReady = true
        return nil
    end

    local target = RACE_ALIAS[key]
    if not target then
        warn("[KATAKURI][Race] race không hợp lệ: " .. tostring(raw) .. " -> bỏ qua race gate")
        RaceFeature.Target = nil
        RaceFeature.Ready = true
        State.RaceTarget = nil
        State.RaceReady = true
        return nil
    end

    RaceFeature.Target = target
    RaceFeature.Ready = currentRace() == target
    State.RaceTarget = target
    State.RaceReady = RaceFeature.Ready
    return target
end

local function tryWriteCompletedFragment()
    if RaceFeature.Completed then return true end

    local targetFragments = tonumber(ENV.fragmenttarget)
    State.FragmentTarget = targetFragments
    if not targetFragments or targetFragments <= 0 then
        return false
    end

    local fragments = currentFragments()
    if not fragments or fragments < targetFragments then
        return false
    end

    local raceTarget = resolveRaceTarget()
    local raceNow = currentRace()
    local raceReady = raceTarget == nil or raceNow == raceTarget
    RaceFeature.Ready = raceReady
    State.RaceReady = raceReady

    if not raceReady then
        return false
    end

    if type(writefile) ~= "function" then
        warn("[KATAKURI][Fragment] Executor không hỗ trợ writefile")
        return false
    end

    local fileName = tostring(Player.Name) .. ".txt"
    local ok, err = pcall(function()
        writefile(fileName, "Completed-fragment")
    end)

    if not ok then
        warn("[KATAKURI][Fragment] writefile lỗi: " .. tostring(err))
        return false
    end

    RaceFeature.Completed = true
    RaceFeature.CompletionFile = fileName
    State.CompletionWritten = true

    ENV.CompletedFragment = true
    ENV.CompletedFragmentFile = fileName
    ENV.CompletedFragmentRace = raceNow
    ENV.CompletedFragmentValue = fragments
    ENV.CompletedFragmentTarget = targetFragments

    warn(string.format(
        "[KATAKURI][Fragment] %s = Completed-fragment | Race=%s | Fragment=%d/%d",
        fileName,
        tostring(raceNow or "?"),
        fragments,
        targetFragments
    ))
    return true
end

local function raceDriverStep()
    local target = resolveRaceTarget()
    if not target then
        return true
    end

    local raceNow = currentRace()
    if raceNow == target then
        RaceFeature.Ready = true
        State.RaceReady = true
        return true
    end

    RaceFeature.Ready = false
    State.RaceReady = false

    local now = os.clock()
    if now - RaceFeature.LastActionAt < 3 then
        return false
    end

    local fragments = currentFragments() or 0

    if REROLLABLE_RACES[target] then
        if fragments < 2500 then
            if now - RaceFeature.LastLogAt >= 5 then
                RaceFeature.LastLogAt = now
                debugPrint(
                    "Race waiting fragments:",
                    tostring(raceNow),
                    "->",
                    target,
                    fragments .. "/2500"
                )
            end
            return false
        end

        RaceFeature.LastActionAt = now
        pcall(function()
            COMMF_:InvokeServer("BlackbeardReward", "Reroll", "1")
        end)
        pcall(function()
            COMMF_:InvokeServer("BlackbeardReward", "Reroll", "2")
        end)
        return false
    end

    RaceFeature.LastActionAt = now

    if target == "Ghoul" then
        pcall(function()
            COMMF_:InvokeServer("Ectoplasm", "BuyCheck", 4)
        end)
        task.wait(0.35)
        pcall(function()
            COMMF_:InvokeServer("Ectoplasm", "Change", 4)
        end)
    elseif target == "Cyborg" then
        pcall(function()
            COMMF_:InvokeServer("CyborgTrainer", "Buy")
        end)
    end

    return false
end

-- Stop older execution cleanly if re-executed.
if type(ENV.__KATAKURI_COORDINATOR_STOP) == "function" then
    pcall(ENV.__KATAKURI_COORDINATOR_STOP)
end

State = {
    Running = true,
    Phase = "BOOT",
    Status = "Starting...",
    Extra = "",

    Character = nil,
    Humanoid = nil,
    Root = nil,

    Progress = nil,
    ProgressRaw = nil,
    LastProgressAt = 0,
    UnknownSince = nil,

    InQualifiedRoom = false,
    QualifiedSince = nil,
    BossWasSeen = false,
    LastSpawnerAt = 0,
    LastMirrorTouchAt = 0,

    WS = nil,
    WSConnected = false,
    WSReady = false,
    WSConnectedAt = 0,
    LastWSRxAt = 0,
    CoordinatorClients = 0,
    CoordinatorRooms = 0,
    LastRoomRequestAt = 0,
    LastRoomHeartbeatAt = 0,
    LastClientHeartbeatAt = 0,
    PendingAssignment = nil,
    RoomHint = false,
    RoomRequestNoRoom = false,
    RoomRequestResolvedAt = 0,
    SharedJoinFailures = 0,
    ForceLeaveRoom = false,
    ClaimReplies = {},
    RequestCounter = 0,

    TeleportTarget = nil,
    TeleportReservationId = nil,
    TeleportFailed = nil,

    BrowserCacheAt = 0,
    BrowserCache = nil,
    Hopping = false,

    LastBadReportJob = nil,
    LastBadReportAt = 0,
    LastError = "",

    CurrentFragments = 0,
    FragmentTarget = tonumber(ENV.fragmenttarget),
    RaceTarget = nil,
    RaceReady = true,
    CompletionWritten = false,
}

ENV.__KATAKURI_COORDINATOR_STOP = function()
    State.Running = false
end

resolveRaceTarget()

-- Race + Fragment background driver.
-- Nó chỉ quản lý race/fragment marker, không giành movement/combat của Katakuri.
task.spawn(function()
    while State.Running do
        local ok, err = pcall(function()
            currentFragments()
            raceDriverStep()
            tryWriteCompletedFragment()
        end)
        if not ok then
            debugPrint("Fragment/Race driver error:", err)
        end
        task.wait(0.75)
    end
end)

local function setStatus(status, phase, extra)
    if phase then State.Phase = phase end
    State.Status = tostring(status or "")
    State.Extra = tostring(extra or "")
end

-- ============================================================================
-- [03] CHARACTER / TEAM
-- ============================================================================
local function bindCharacter(character)
    State.Character = character
    State.Humanoid = character:WaitForChild("Humanoid", 10)
    State.Root = character:WaitForChild("HumanoidRootPart", 10)
end

if Player.Character then
    task.spawn(bindCharacter, Player.Character)
end
Player.CharacterAdded:Connect(bindCharacter)

local function currentTeamName()
    return Player.Team and tostring(Player.Team.Name) or "NONE"
end

local function clickMarineTeamButton()
    local pg = Player:FindFirstChildOfClass("PlayerGui")
    if not pg then return false end

    local main = pg:FindFirstChild("Main (minimal)") or pg:FindFirstChild("Main")
    local choose = main and main:FindFirstChild("ChooseTeam", true)
    local container = choose and choose:FindFirstChild("Container")
    local marines = container and container:FindFirstChild("Marines")
    if not marines then return false end

    for _, obj in ipairs(marines:GetDescendants()) do
        if obj:IsA("GuiButton") then
            local ok = pcall(function()
                if type(firesignal) == "function" then
                    firesignal(obj.Activated)
                else
                    obj:Activate()
                end
            end)
            if ok then return true end
        end
    end
    return false
end

local function ensureMarines()
    if currentTeamName() == Config.Team then return true end

    setStatus("Choosing Marines...", "TEAM")
    for _ = 1, 20 do
        if not State.Running then return false end
        if currentTeamName() == Config.Team then return true end

        pcall(function()
            COMMF_:InvokeServer("SetTeam", Config.Team)
        end)
        task.wait(0.35)

        if currentTeamName() == Config.Team then return true end
        pcall(clickMarineTeamButton)
        task.wait(0.35)
    end
    return currentTeamName() == Config.Team
end

local function isSea3()
    if SEA3_PLACE_IDS[game.PlaceId] then return true end
    local map = workspace:GetAttribute("MAP")
    return tostring(map or ""):lower():find("sea3", 1, true) ~= nil
        or tostring(map or ""):match("3") ~= nil
end

-- ============================================================================
-- [04] LIGHTWEIGHT UI
-- ============================================================================
local UI = {}

local function uiParent()
    local ok, parent = pcall(function()
        if type(gethui) == "function" then return gethui() end
        return CoreGui
    end)
    return ok and parent or Player:WaitForChild("PlayerGui")
end

local function createUI()
    local parent = uiParent()
    pcall(function()
        local old = parent:FindFirstChild("KatakuriCoordinatorUI")
        if old then old:Destroy() end
    end)

    local gui = Instance.new("ScreenGui")
    gui.Name = "KatakuriCoordinatorUI"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 50
    gui.Parent = parent

    local frame = Instance.new("Frame")
    frame.Name = "Main"
    frame.Position = UDim2.fromOffset(18, 110)
    frame.Size = UDim2.fromOffset(360, 320)
    frame.BackgroundColor3 = Color3.fromRGB(16, 17, 21)
    frame.BackgroundTransparency = 0.05
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.Draggable = true
    frame.Parent = gui
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 1.5
    stroke.Color = Color3.fromRGB(100, 130, 255)
    stroke.Parent = frame

    local title = Instance.new("TextLabel")
    title.Position = UDim2.fromOffset(12, 8)
    title.Size = UDim2.new(1, -52, 0, 26)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 16
    title.TextColor3 = Color3.fromRGB(180, 195, 255)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Text = "KATAKURI COORDINATOR"
    title.Parent = frame

    local minimize = Instance.new("TextButton")
    minimize.Position = UDim2.new(1, -40, 0, 7)
    minimize.Size = UDim2.fromOffset(30, 26)
    minimize.BackgroundColor3 = Color3.fromRGB(35, 37, 44)
    minimize.BorderSizePixel = 0
    minimize.Font = Enum.Font.GothamBold
    minimize.Text = "—"
    minimize.TextSize = 16
    minimize.TextColor3 = Color3.fromRGB(235, 235, 240)
    minimize.Parent = frame
    Instance.new("UICorner", minimize).CornerRadius = UDim.new(0, 6)

    local content = Instance.new("Frame")
    content.Position = UDim2.fromOffset(10, 42)
    content.Size = UDim2.new(1, -20, 1, -52)
    content.BackgroundTransparency = 1
    content.Parent = frame

    local labels = {}
    local names = {"Player", "Team", "State", "Server", "Progress", "Fragment", "Race", "Coordinator", "Room", "Status"}
    for i, name in ipairs(names) do
        local l = Instance.new("TextLabel")
        l.Name = name
        l.Position = UDim2.fromOffset(0, (i - 1) * 25)
        l.Size = UDim2.new(1, 0, 0, name == "Status" and 40 or 23)
        l.BackgroundTransparency = name == "Status" and 0.15 or 1
        l.BackgroundColor3 = Color3.fromRGB(30, 31, 37)
        l.BorderSizePixel = 0
        l.Font = Enum.Font.GothamSemibold
        l.TextSize = name == "Status" and 12 or 13
        l.TextColor3 = Color3.fromRGB(225, 225, 232)
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.TextYAlignment = Enum.TextYAlignment.Center
        l.TextWrapped = true
        l.Text = name .. ": ..."
        l.Parent = content
        if name == "Status" then
            Instance.new("UICorner", l).CornerRadius = UDim.new(0, 6)
            local pad = Instance.new("UIPadding")
            pad.PaddingLeft = UDim.new(0, 7)
            pad.PaddingRight = UDim.new(0, 7)
            pad.Parent = l
        end
        labels[name] = l
    end

    local minimized = false
    minimize.MouseButton1Click:Connect(function()
        minimized = not minimized
        content.Visible = not minimized
        frame.Size = minimized and UDim2.fromOffset(360, 42) or UDim2.fromOffset(360, 320)
        minimize.Text = minimized and "+" or "—"
    end)

    UI.Gui = gui
    UI.Frame = frame
    UI.Labels = labels
end

createUI()

task.spawn(function()
    while State.Running do
        pcall(function()
            if not UI.Gui or not UI.Gui.Parent then createUI() end
            local labels = UI.Labels
            local progress = State.Progress
            local remainingText = progress and progress.known
                and (progress.ready and "READY" or tostring(progress.remaining))
                or "?"
            local killedText = progress and progress.known and tostring(progress.killed or "?") or "?"

            labels.Player.Text = "Player: " .. Player.Name
            labels.Team.Text = "Team: " .. currentTeamName() .. " (forced Marines)"
            labels.State.Text = "State: " .. State.Phase
            labels.Server.Text = string.format("Server: %d/%d | %s", #Players:GetPlayers(), Players.MaxPlayers, string.sub(game.JobId, 1, 10))
            labels.Progress.Text = string.format("Progress: remaining=%s | killed=%s/%d", remainingText, killedText, Config.TotalRequired)

            local fragNow = currentFragments() or 0
            local fragTarget = tonumber(ENV.fragmenttarget)
            labels.Fragment.Text = fragTarget and fragTarget > 0
                and string.format("Fragment: %d/%d%s", fragNow, fragTarget, State.CompletionWritten and " | COMPLETED" or "")
                or string.format("Fragment: %d | target=OFF", fragNow)

            local raceNow = currentRace() or "?"
            local raceTarget = State.RaceTarget
            labels.Race.Text = raceTarget
                and string.format("Race: %s -> %s | %s", raceNow, raceTarget, State.RaceReady and "READY" or "CHANGING")
                or string.format("Race: %s | target=OFF", raceNow)

            labels.Coordinator.Text = string.format(
                "WS: %s | clients=%d | rooms=%d",
                State.WSReady and "READY" or (State.WSConnected and "CONNECTING" or "OFF"),
                State.CoordinatorClients,
                State.CoordinatorRooms
            )
            labels.Room.Text = "Room: " .. (State.InQualifiedRoom and "OPEN <=150 / SHARING" or "SCOUT")
            labels.Status.Text = "Status: " .. State.Status .. (State.Extra ~= "" and ("\n" .. State.Extra) or "")
        end)
        task.wait(Config.UIUpdateInterval)
    end
end)

-- ============================================================================
-- [05] MOVEMENT CONTROLLER - one Heartbeat / stable hover
-- ============================================================================
-- MOVE/HOLD are used for static navigation points.
-- FOLLOW is used for mobs/bosses and remains active even after arriving, so
-- gravity can never pull the character down between state-machine ticks.
local Movement = {
    Proxy = nil,
    Tween = nil,
    Mode = "IDLE", -- IDLE | MOVE | HOLD | FOLLOW
    Target = nil,
    FollowPart = nil,
    FollowOffset = CFrame.new(),
    Speed = Config.TweenSpeed,
    LastRetargetAt = 0,
}

local function ensureProxy()
    if Movement.Proxy and Movement.Proxy.Parent then return Movement.Proxy end
    local p = Instance.new("Part")
    p.Name = "KatakuriMoveProxy"
    p.Anchored = true
    p.CanCollide = false
    p.CanTouch = false
    p.CanQuery = false
    p.Transparency = 1
    p.Size = Vector3.new(2, 2, 2)
    p.Parent = workspace
    Movement.Proxy = p
    return p
end

local function cancelTweenOnly()
    if Movement.Tween then
        pcall(function() Movement.Tween:Cancel() end)
        Movement.Tween = nil
    end
end

function Movement.cancel()
    Movement.Mode = "IDLE"
    Movement.Target = nil
    Movement.FollowPart = nil
    cancelTweenOnly()
end

function Movement.holdAt(targetCFrame)
    if typeof(targetCFrame) ~= "CFrame" then return false end
    cancelTweenOnly()
    Movement.Mode = "HOLD"
    Movement.Target = targetCFrame
    Movement.FollowPart = nil
    return true
end

function Movement.followPart(part, offsetCFrame, speed)
    if not part or not part:IsA("BasePart") or not part.Parent then
        Movement.cancel()
        return false
    end
    cancelTweenOnly()
    Movement.Mode = "FOLLOW"
    Movement.FollowPart = part
    Movement.FollowOffset = typeof(offsetCFrame) == "CFrame" and offsetCFrame or CFrame.new()
    Movement.Speed = tonumber(speed) or Config.TweenSpeed
    Movement.Target = nil
    return true
end

function Movement.moveTo(targetCFrame, speed)
    local root = State.Root
    local hum = State.Humanoid
    if not root or not hum or hum.Health <= 0 or typeof(targetCFrame) ~= "CFrame" then return false end

    hum.Sit = false
    local dist = (root.Position - targetCFrame.Position).Magnitude
    if dist <= Config.HoverSnapDistance then
        Movement.holdAt(targetCFrame)
        return true
    end

    local now = os.clock()
    if Movement.Mode == "MOVE" and Movement.Target then
        local targetDelta = (Movement.Target.Position - targetCFrame.Position).Magnitude
        if targetDelta < 10 and now - Movement.LastRetargetAt < 0.20 then
            return false
        end
    end

    local proxy = ensureProxy()
    cancelTweenOnly()
    proxy.CFrame = root.CFrame
    Movement.Target = targetCFrame
    Movement.FollowPart = nil
    Movement.Mode = "MOVE"
    Movement.Speed = tonumber(speed) or Config.TweenSpeed
    Movement.LastRetargetAt = now

    local travel = math.max(dist / Movement.Speed, 0.03)
    Movement.Tween = TweenService:Create(
        proxy,
        TweenInfo.new(travel, Enum.EasingStyle.Linear),
        {CFrame = targetCFrame}
    )
    Movement.Tween:Play()
    return false
end

local function stableRootSet(root, hum, targetCFrame)
    hum.Sit = false
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
    root.CFrame = targetCFrame
end

RunService.Heartbeat:Connect(function(dt)
    if not State.Running or Movement.Mode == "IDLE" then return end

    local root = State.Root
    local hum = State.Humanoid
    if not root or not hum or hum.Health <= 0 then
        Movement.cancel()
        return
    end

    if Movement.Mode == "MOVE" then
        local proxy = Movement.Proxy
        if not proxy or not proxy.Parent then
            Movement.cancel()
            return
        end
        pcall(stableRootSet, root, hum, proxy.CFrame)
        return
    end

    if Movement.Mode == "HOLD" then
        if typeof(Movement.Target) ~= "CFrame" then
            Movement.cancel()
            return
        end
        pcall(stableRootSet, root, hum, Movement.Target)
        return
    end

    if Movement.Mode == "FOLLOW" then
        local part = Movement.FollowPart
        if not part or not part.Parent then
            Movement.cancel()
            return
        end

        local desired = part.CFrame * Movement.FollowOffset
        local dist = (root.Position - desired.Position).Magnitude
        local targetCFrame

        if dist > 30 then
            -- Capped linear catch-up avoids a hard snap from far away.
            local maxStep = math.max(1, Movement.Speed * math.max(dt, 1 / 240))
            local alpha = math.clamp(maxStep / math.max(dist, 0.001), 0, 1)
            targetCFrame = root.CFrame:Lerp(desired, alpha)
        else
            -- High-frequency damped follow. It continuously holds Y, eliminating
            -- the old "arrive -> cancel tween -> gravity drop -> retween" jitter.
            local alpha = math.clamp(
                1 - math.exp(-Config.HoverFollowSharpness * math.max(dt, 1 / 240)),
                0,
                1
            )
            if dist <= Config.HoverSnapDistance then
                alpha = math.max(alpha, 0.82)
            end
            targetCFrame = root.CFrame:Lerp(desired, alpha)
        end

        pcall(stableRootSet, root, hum, targetCFrame)
    end
end)

-- ============================================================================
-- [06] CAKE PROGRESS / BOSS DETECTION
-- ============================================================================
local function getCakeMap()
    local map = workspace:FindFirstChild("Map")
    return map and map:FindFirstChild("CakeLoaf")
end

local function getMirrorParts()
    local cake = getCakeMap()
    local mirror = cake and cake:FindFirstChild("BigMirror")
    if not mirror then return nil, nil end
    return mirror:FindFirstChild("Main"), mirror:FindFirstChild("Other")
end

local function findCakePrince(container)
    if not container then return nil end
    for _, obj in ipairs(container:GetChildren()) do
        if obj:IsA("Model") and string.find(string.lower(obj.Name), "cake prince", 1, true) then
            local hum = obj:FindFirstChildOfClass("Humanoid")
            local root = obj:FindFirstChild("HumanoidRootPart")
            if root and (not hum or hum.Health > 0) then
                return obj
            end
        end
    end
    return nil
end

local function activeCakePrince()
    return findCakePrince(Enemies)
end

local function storedCakePrince()
    return findCakePrince(ReplicatedStorage)
end

local function mirrorOpen()
    local _, other = getMirrorParts()
    if not other or not other:IsA("BasePart") then return false end
    return other.Transparency == 0
end

local function queryProgress(force)
    local now = os.clock()
    if not force and State.Progress and now - State.LastProgressAt < Config.ProgressPollInterval then
        return State.Progress
    end

    State.LastProgressAt = now

    -- Strong visual/model evidence wins even if the remote is temporarily noisy.
    local bossActive = activeCakePrince()
    local bossStored = storedCakePrince()
    local mirrorReady = mirrorOpen()

    local ok, raw = pcall(function()
        return COMMF_:InvokeServer("CakePrinceSpawner")
    end)

    local result = {
        known = false,
        ready = false,
        remaining = nil,
        killed = nil,
        raw = raw,
        evidence = nil,
    }

    if bossActive or bossStored then
        result.known = true
        result.ready = true
        result.remaining = 0
        result.killed = Config.TotalRequired
        result.evidence = bossActive and "boss_active" or "boss_stored"
    elseif mirrorReady then
        -- Several source variants use an open BigMirror as the "Cake Prince can
        -- spawn / is spawning" state. Treat that server as qualified immediately.
        result.known = true
        result.ready = true
        result.remaining = 0
        result.killed = Config.TotalRequired
        result.evidence = "mirror_ready"
    elseif ok then
        local rawString = raw ~= nil and tostring(raw) or nil
        local number = rawString and tonumber(string.match(rawString, "%d+")) or nil

        if number then
            number = math.clamp(number, 0, Config.TotalRequired)
            result.known = true
            result.remaining = number
            result.killed = Config.TotalRequired - number
            result.ready = number <= 0
            result.evidence = result.ready and "remote_zero" or "remote_remaining"
        elseif rawString and rawString ~= "" then
            -- Existing Katakuri sources interpret CakePrinceSpawner responses
            -- with no numeric "remaining" value as spawn-ready.
            result.known = true
            result.ready = true
            result.remaining = 0
            result.killed = Config.TotalRequired
            result.evidence = "remote_spawn_ready"
        end
    end

    State.Progress = result
    State.ProgressRaw = raw
    if result.known then
        State.UnknownSince = nil
    elseif not State.UnknownSince then
        State.UnknownSince = now
    end
    return result
end

local function currentBossState(progress)
    if activeCakePrince() or storedCakePrince() then return "BOSS" end
    if progress and progress.known and progress.ready then return "READY" end
    if progress and progress.known and progress.remaining and progress.remaining <= Config.QualifiedRemaining then
        return "FARMING"
    end
    return "NONE"
end

local function isQualified(progress)
    if activeCakePrince() or storedCakePrince() then return true end
    if not progress or not progress.known then return false end
    return progress.ready or (progress.remaining and progress.remaining <= Config.QualifiedRemaining)
end

-- ============================================================================
-- [07] COMBAT - scoped only to Cake mobs / Cake Prince
-- ============================================================================
local Attack = {
    RemoteAttack = nil,
    RemoteAttackId = nil,
    Seed = nil,
    RegisterAttack = nil,
    RegisterHit = nil,
    LastAttackAt = 0,
    LastKenAt = 0,
    LastBusoAt = 0,
}

local function refreshAttackNet()
    pcall(function()
        local modules = ReplicatedStorage:FindFirstChild("Modules")
        local net = modules and modules:FindFirstChild("Net")
        if not net then return end
        Attack.RegisterAttack = net:FindFirstChild("RE/RegisterAttack")
        Attack.RegisterHit = net:FindFirstChild("RE/RegisterHit")
        local seedRemote = net:FindFirstChild("seed")
        if seedRemote and not Attack.Seed then
            Attack.Seed = seedRemote:InvokeServer()
        end
    end)
end

refreshAttackNet()

task.spawn(function()
    local containers = {
        ReplicatedStorage:FindFirstChild("Util"),
        ReplicatedStorage:FindFirstChild("Common"),
        ReplicatedStorage:FindFirstChild("Remotes"),
        ReplicatedStorage:FindFirstChild("Assets"),
        ReplicatedStorage:FindFirstChild("FX"),
    }
    for _, folder in ipairs(containers) do
        if folder then
            for _, obj in ipairs(folder:GetChildren()) do
                if obj:IsA("RemoteEvent") and obj:GetAttribute("Id") then
                    Attack.RemoteAttack = obj
                    Attack.RemoteAttackId = obj:GetAttribute("Id")
                end
            end
            folder.ChildAdded:Connect(function(obj)
                if obj:IsA("RemoteEvent") and obj:GetAttribute("Id") then
                    Attack.RemoteAttack = obj
                    Attack.RemoteAttackId = obj:GetAttribute("Id")
                end
            end)
        end
    end
end)

local function equipMelee()
    local character = State.Character
    local hum = State.Humanoid
    if not character or not hum then return false end

    local current = character:FindFirstChildOfClass("Tool")
    if current and tostring(current.ToolTip) == "Melee" then return true end

    for _, tool in ipairs(Player.Backpack:GetChildren()) do
        if tool:IsA("Tool") and tostring(tool.ToolTip) == "Melee" then
            pcall(function() hum:EquipTool(tool) end)
            return true
        end
    end
    return current ~= nil
end

local function aliveModel(model)
    if not model or not model.Parent then return false end
    local hum = model:FindFirstChildOfClass("Humanoid")
    local root = model:FindFirstChild("HumanoidRootPart")
    return hum and root and hum.Health > 0
end

local function fastAttackModels(models)
    if os.clock() - Attack.LastAttackAt < Config.AttackInterval then return end
    if not State.Root or not State.Humanoid or State.Humanoid.Health <= 0 then return end
    if not State.Character or not State.Character:FindFirstChildOfClass("Tool") then return end

    local valid = {}
    for _, model in ipairs(models or {}) do
        if aliveModel(model) then
            local root = model.HumanoidRootPart
            if (root.Position - State.Root.Position).Magnitude <= Config.AttackRadius then
                valid[#valid + 1] = model
            end
        end
    end
    if #valid == 0 then return end

    local payload = {[2] = {}}
    for _, model in ipairs(valid) do
        local part = model:FindFirstChild("Head") or model:FindFirstChild("HumanoidRootPart")
        if part then
            payload[1] = payload[1] or part
            payload[2][#payload[2] + 1] = {model, part}
        end
    end
    if not payload[1] then return end

    pcall(function()
        if not Attack.RegisterAttack or not Attack.RegisterHit then
            refreshAttackNet()
        end
        if Attack.RegisterAttack then Attack.RegisterAttack:FireServer() end
        if Attack.RegisterHit then Attack.RegisterHit:FireServer(unpack(payload)) end
    end)

    pcall(function()
        if Attack.RemoteAttack and Attack.RemoteAttackId and Attack.Seed then
            Attack.RemoteAttack:FireServer(
                string.gsub("RE/RegisterHit", ".", function(c)
                    return string.char(bit32.bxor(string.byte(c), math.floor(workspace:GetServerTimeNow() / 10 % 10) + 1))
                end),
                bit32.bxor(Attack.RemoteAttackId + 909090, Attack.Seed * 2),
                unpack(payload)
            )
        end
    end)

    Attack.LastAttackAt = os.clock()
end

local function cakeMobList()
    local list = {}
    for _, mob in ipairs(Enemies:GetChildren()) do
        if CAKE_MOBS[mob.Name] and aliveModel(mob) then
            list[#list + 1] = mob
        end
    end
    return list
end

local function nearestCakeMob()
    local root = State.Root
    if not root then return nil end
    local best, bestDist
    for _, mob in ipairs(cakeMobList()) do
        local d = (mob.HumanoidRootPart.Position - root.Position).Magnitude
        if not bestDist or d < bestDist then
            best, bestDist = mob, d
        end
    end
    return best, bestDist
end

local function bringCakeMobs(anchorMob)
    if not aliveModel(anchorMob) then return end

    local anchorRoot = anchorMob:FindFirstChild("HumanoidRootPart")
    local anchorHum = anchorMob:FindFirstChildOfClass("Humanoid")
    if not anchorRoot or not anchorHum then return end
    local anchorCFrame = anchorRoot.CFrame

    pcall(function() setscriptable(Player, "SimulationRadius", true) end)
    pcall(function() sethiddenproperty(Player, "SimulationRadius", math.huge) end)

    -- Keep the selected anchor mob exactly where it already is. The previous
    -- implementation could offset the anchor itself every tick, causing the
    -- whole pack (and the player following it) to drift/jitter.
    pcall(function()
        anchorRoot.AssemblyLinearVelocity = Vector3.zero
        anchorRoot.AssemblyAngularVelocity = Vector3.zero
        anchorRoot.CanCollide = false
        anchorRoot.Size = Vector3.new(55, 55, 55)
        anchorHum.WalkSpeed = 0
        anchorHum.JumpPower = 0
    end)

    local index = 0
    for _, mob in ipairs(cakeMobList()) do
        if mob ~= anchorMob then
            local root = mob:FindFirstChild("HumanoidRootPart")
            local hum = mob:FindFirstChildOfClass("Humanoid")
            if root and hum and (root.Position - anchorCFrame.Position).Magnitude <= Config.BringRadius then
                local owns = true
                if type(isnetworkowner) == "function" then
                    local ok, result = pcall(isnetworkowner, root)
                    owns = ok and result or false
                end

                if owns then
                    index += 1
                    local column = ((index - 1) % 3) - 1
                    local row = math.floor((index - 1) / 3) + 1
                    local offset = CFrame.new(column * 2.2, 0, row * 2.2)

                    pcall(function()
                        root.AssemblyLinearVelocity = Vector3.zero
                        root.AssemblyAngularVelocity = Vector3.zero
                        root.CanCollide = false
                        root.Size = Vector3.new(55, 55, 55)
                        hum.WalkSpeed = 0
                        hum.JumpPower = 0
                        root.CFrame = anchorCFrame * offset
                    end)
                end
            end
        end
    end
end

local function farmCakeMobStep(progress)
    local mob = nearestCakeMob()
    if not mob then
        setStatus("Waiting Cake mobs...", "FARM_MOBS", progress and progress.remaining and ("remaining=" .. progress.remaining) or "")
        local cake = getCakeMap()
        local respawn = cake and cake:FindFirstChild("RespawnPart")
        if respawn and respawn:IsA("BasePart") then
            Movement.moveTo(respawn.CFrame * CFrame.new(0, 15, 0))
        else
            Movement.moveTo(CFrame.new(-2100, 85, -12130))
        end
        return
    end

    bringCakeMobs(mob)
    equipMelee()
    Movement.followPart(
        mob.HumanoidRootPart,
        CFrame.new(0, Config.MobHoverHeight, 0),
        Config.TweenSpeed
    )

    if os.clock() - Attack.LastKenAt >= 10 then
        Attack.LastKenAt = os.clock()
        pcall(function() ReplicatedStorage.Remotes.CommE:FireServer("Ken", true) end)
    end

    setStatus(
        "Farming " .. mob.Name,
        "FARM_MOBS",
        string.format("remaining=%s | killed=%s/%d", tostring(progress.remaining), tostring(progress.killed), Config.TotalRequired)
    )
end

local function touchMirror()
    if os.clock() - State.LastMirrorTouchAt < Config.MirrorTouchCooldown then return end
    local root = State.Root
    local main = getMirrorParts()
    if not root or not main or not main:IsA("BasePart") then return end

    State.LastMirrorTouchAt = os.clock()
    Movement.moveTo(main.CFrame * CFrame.new(0, 4, 0))
    if (root.Position - main.Position).Magnitude <= 15 and type(firetouchinterest) == "function" then
        pcall(function()
            firetouchinterest(root, main, 0)
            task.wait(0.08)
            firetouchinterest(root, main, 1)
        end)
    end
end

local function spawnCakePrinceStep()
    setStatus("Spawning Cake Prince...", "SPAWN_BOSS")
    if os.clock() - State.LastSpawnerAt >= Config.SpawnerCooldown then
        State.LastSpawnerAt = os.clock()
        pcall(function() COMMF_:InvokeServer("CakePrinceSpawner", true) end)
    end
    touchMirror()
end

local function killCakePrinceStep()
    local boss = activeCakePrince()
    if not boss then
        local stored = storedCakePrince()
        if stored then
            setStatus("Cake Prince detected - entering mirror...", "ENTER_BOSS")
            touchMirror()
        else
            setStatus("Waiting Cake Prince model...", "WAIT_BOSS")
            touchMirror()
        end
        return
    end

    -- The Ghoul/Cyborg source enters BigMirror before attacking Cake Prince.
    -- Keep that gate so movement never races the dimension transition.
    if tostring(Player:GetAttribute("CurrentLocation") or "") ~= "Dimensional Shift" then
        local mirrorMain = getMirrorParts()
        if mirrorMain then
            setStatus("Cake Prince active - entering Dimensional Shift", "ENTER_BOSS")
            touchMirror()
            return
        end
    end

    State.BossWasSeen = true
    equipMelee()
    local root = boss:FindFirstChild("HumanoidRootPart")
    if root then
        Movement.followPart(
            root,
            CFrame.new(0, Config.BossHoverHeight, 0),
            Config.TweenSpeed
        )
    end
    setStatus("Killing Cake Prince", "KILL_BOSS", boss:FindFirstChildOfClass("Humanoid") and ("HP=" .. math.floor(boss.Humanoid.Health)) or "")
end


-- One dedicated fast-attack loop. Attack cadence no longer depends on the
-- slower progress/state-machine loop, and only one loop owns hit remotes.
task.spawn(function()
    while State.Running do
        local phase = State.Phase
        if phase == "FARM_MOBS" then
            equipMelee()
            fastAttackModels(cakeMobList())
        elseif phase == "KILL_BOSS" then
            local boss = activeCakePrince()
            if boss then
                equipMelee()
                fastAttackModels({boss})
            end
        end
        task.wait(Config.AttackInterval)
    end
end)

-- Auto Buso is always enforced, including after respawn/teleport.
-- Reference behavior from the Ghoul/Cyborg source: invoke "Buso" whenever
-- HasBuso is missing. A short cooldown prevents remote spam on 20 tabs.
local function ensureBuso()
    local character = State.Character
    local hum = State.Humanoid
    if not character or not hum or hum.Health <= 0 then return false end
    if character:FindFirstChild("HasBuso") then return true end

    local now = os.clock()
    if now - Attack.LastBusoAt < Config.BusoRetryCooldown then return false end
    Attack.LastBusoAt = now
    pcall(function()
        COMMF_:InvokeServer("Buso")
    end)
    return character:FindFirstChild("HasBuso") ~= nil
end

task.spawn(function()
    while State.Running do
        ensureBuso()
        task.wait(Config.BusoCheckInterval)
    end
end)

-- ============================================================================
-- [08] VISITED SERVER CACHE (per account, persists across teleports)
-- ============================================================================
local VISITED_FILE = "KatakuriVisited_" .. tostring(Player.UserId) .. ".json"
local Visited = {}

local function loadVisited()
    if type(isfile) ~= "function" or type(readfile) ~= "function" then return end
    if not isfile(VISITED_FILE) then return end
    local ok, decoded = pcall(function()
        return HttpService:JSONDecode(readfile(VISITED_FILE))
    end)
    if ok and type(decoded) == "table" then Visited = decoded end
end

local function saveVisited()
    if type(writefile) ~= "function" then return end
    pcall(function() writefile(VISITED_FILE, HttpService:JSONEncode(Visited)) end)
end

local function cleanupVisited()
    local now = os.time()
    local changed = false
    for jobId, expiresAt in pairs(Visited) do
        if tonumber(expiresAt) == nil or tonumber(expiresAt) <= now then
            Visited[jobId] = nil
            changed = true
        end
    end
    if changed then saveVisited() end
end

local function blockJob(jobId, seconds)
    if type(jobId) ~= "string" or jobId == "" then return end
    Visited[jobId] = os.time() + (tonumber(seconds) or Config.CandidateLocalBlacklistSeconds)
    saveVisited()
end

local function jobBlocked(jobId)
    if type(jobId) ~= "string" or jobId == "" or jobId == game.JobId then return true end
    local expires = tonumber(Visited[jobId])
    if not expires then return false end
    if expires <= os.time() then
        Visited[jobId] = nil
        return false
    end
    return true
end

loadVisited()
cleanupVisited()

-- ============================================================================
-- [09] WEBSOCKET COORDINATOR CLIENT
-- ============================================================================
local function getWebSocketConnector()
    if type(ENV.WebSocket) == "table" and type(ENV.WebSocket.connect) == "function" then return ENV.WebSocket.connect end
    if type(ENV.websocket) == "table" and type(ENV.websocket.connect) == "function" then return ENV.websocket.connect end
    if type(ENV.syn) == "table" and type(ENV.syn.websocket) == "table" and type(ENV.syn.websocket.connect) == "function" then return ENV.syn.websocket.connect end
    if type(WebSocket) == "table" and type(WebSocket.connect) == "function" then return WebSocket.connect end
    return nil
end

local function wsSend(payload)
    local socket = State.WS
    if not socket or not State.WSConnected then return false end
    local encoded = HttpService:JSONEncode(payload)
    local ok = pcall(function()
        if type(socket.Send) == "function" then
            socket:Send(encoded)
        elseif type(socket.send) == "function" then
            socket:send(encoded)
        else
            error("WebSocket send method unavailable")
        end
    end)
    if not ok then
        State.WSConnected = false
        State.WSReady = false
    end
    return ok
end

local function nextRequestId(prefix)
    State.RequestCounter += 1
    return string.format("%s:%d:%d:%d", prefix or "r", Player.UserId, os.time(), State.RequestCounter)
end

local function clientMeta(messageType)
    return {
        type = messageType,
        version = 5,
        player = Player.Name,
        userId = Player.UserId,
        placeId = game.PlaceId,
        jobId = game.JobId,
        playerCount = #Players:GetPlayers(),
        maxPlayers = Players.MaxPlayers,
        state = State.Phase,
        qualified = State.InQualifiedRoom,
    }
end

local function sendHello()
    return wsSend(clientMeta("hello"))
end

local function sendClientStatus()
    local data = clientMeta("client_status")
    data.qualified = State.InQualifiedRoom
    data.status = State.Status
    return wsSend(data)
end

local function publishRoom(progress)
    if not State.WSConnected then return false end
    local bossState = currentBossState(progress)
    if bossState == "NONE" then return false end

    local remaining = progress and progress.known and progress.remaining or 0
    return wsSend({
        type = "room_update",
        player = Player.Name,
        userId = Player.UserId,
        placeId = game.PlaceId,
        jobId = game.JobId,
        playerCount = #Players:GetPlayers(),
        maxPlayers = Players.MaxPlayers,
        remaining = tonumber(remaining) or 0,
        killed = Config.TotalRequired - (tonumber(remaining) or 0),
        bossState = bossState,
        qualifiedRemaining = Config.QualifiedRemaining,
        qualified = true,
        sentAt = os.time(),
    })
end

local function closeRoom(reason)
    if State.WSConnected then
        wsSend({
            type = "room_close",
            player = Player.Name,
            userId = Player.UserId,
            placeId = game.PlaceId,
            jobId = game.JobId,
            reason = tostring(reason or "closed"),
        })
    end
end

local function reportCurrentBad(progress, reason)
    local now = os.clock()
    if State.LastBadReportJob == game.JobId and now - State.LastBadReportAt < 10 then return end
    State.LastBadReportJob = game.JobId
    State.LastBadReportAt = now

    wsSend({
        type = "candidate_bad",
        player = Player.Name,
        userId = Player.UserId,
        placeId = game.PlaceId,
        jobId = game.JobId,
        playerCount = #Players:GetPlayers(),
        maxPlayers = Players.MaxPlayers,
        remaining = progress and progress.remaining or nil,
        reason = tostring(reason or "not_qualified"),
    })
end

local function requestSharedRoom(force)
    local now = os.clock()
    if not force and now - State.LastRoomRequestAt < Config.RoomRequestInterval then return false end
    State.LastRoomRequestAt = now
    State.RoomHint = false
    State.RoomRequestNoRoom = false
    State.RoomRequestResolvedAt = 0
    return wsSend({
        type = "request_room",
        requestId = nextRequestId("room"),
        player = Player.Name,
        userId = Player.UserId,
        placeId = game.PlaceId,
        jobId = game.JobId,
        playerCount = #Players:GetPlayers(),
        maxPlayers = Players.MaxPlayers,
        state = State.Phase,
        qualified = false,
    })
end

local function claimCandidate(jobId, playerCount)
    if not State.WSConnected then return true, "offline" end
    local requestId = nextRequestId("claim")
    State.ClaimReplies[requestId] = nil

    if not wsSend({
        type = "candidate_claim",
        requestId = requestId,
        player = Player.Name,
        userId = Player.UserId,
        placeId = game.PlaceId,
        currentJobId = game.JobId,
        jobId = jobId,
        playerCount = playerCount,
    }) then
        return true, "send_failed"
    end

    local deadline = os.clock() + Config.ClaimReplyTimeout
    while State.Running and os.clock() < deadline do
        if State.PendingAssignment then return false, "room_assignment" end
        local reply = State.ClaimReplies[requestId]
        if reply then
            State.ClaimReplies[requestId] = nil
            return reply.granted == true, tostring(reply.reason or "")
        end
        task.wait(0.03)
    end
    State.ClaimReplies[requestId] = nil
    return true, "claim_timeout"
end

local function assignmentFailed(reason)
    if State.WSConnected and State.TeleportReservationId then
        wsSend({
            type = "assignment_failed",
            reservationId = State.TeleportReservationId,
            player = Player.Name,
            userId = Player.UserId,
            jobId = State.TeleportTarget,
            reason = tostring(reason or "teleport_failed"),
        })
    end
end

local function handleWebSocketMessage(message)
    local ok, data = pcall(function() return HttpService:JSONDecode(message) end)
    if not ok or type(data) ~= "table" then return end

    State.LastWSRxAt = os.clock()
    if data.type == "welcome" or data.type == "hello_ack" or data.type == "coordinator_stats" then
        State.WSReady = true
    end

    if data.type == "ping" then
        wsSend({type = "pong", time = os.time(), player = Player.Name, userId = Player.UserId, jobId = game.JobId})
        return
    end

    if data.type == "coordinator_stats" then
        State.CoordinatorClients = tonumber(data.clients) or 0
        State.CoordinatorRooms = tonumber(data.rooms) or 0
        return
    end

    if data.type == "hello_ack" then
        State.WSReady = true
        State.LastWSRxAt = os.clock()
        State.CoordinatorClients = tonumber(data.clients) or State.CoordinatorClients
        State.CoordinatorRooms = tonumber(data.rooms) or State.CoordinatorRooms
        -- Immediately ask for a room after handshake; don't wait for scoutStep.
        if not State.InQualifiedRoom then
            requestSharedRoom(true)
        end
        return
    end

    if data.type == "room_hint" then
        if not State.InQualifiedRoom and tostring(data.jobId or "") ~= game.JobId then
            State.RoomHint = true
            -- A shared good room always beats continuing browser work.
            requestSharedRoom(true)
        end
        return
    end

    if data.type == "room_assignment" then
        if tonumber(data.placeId) ~= game.PlaceId then return end
        if State.InQualifiedRoom then return end
        if type(data.jobId) ~= "string" or data.jobId == "" or data.jobId == game.JobId then return end
        State.RoomRequestNoRoom = false
        State.RoomRequestResolvedAt = os.clock()
        State.PendingAssignment = data
        return
    end

    if data.type == "no_room" then
        State.RoomRequestNoRoom = true
        State.RoomRequestResolvedAt = os.clock()
        return
    end

    if data.type == "room_closed" then
        if tostring(data.jobId or "") == game.JobId and State.InQualifiedRoom then
            State.ForceLeaveRoom = true
        end
        return
    end

    if data.type == "candidate_claim_result" and type(data.requestId) == "string" then
        State.ClaimReplies[data.requestId] = data
        return
    end
end

local function bindSocketEvent(socket, eventName, callback)
    local ok, signal = pcall(function() return socket[eventName] end)
    if not ok or signal == nil then return false end

    -- Executors expose WebSocket events as RBXScriptSignal, userdata proxies,
    -- or custom signal tables. Do not restrict by typeof/type.
    local connected = pcall(function()
        local connect = signal.Connect or signal.connect
        if type(connect) ~= "function" then
            error("event has no Connect/connect")
        end
        connect(signal, callback)
    end)
    return connected
end

local function connectWebSocket()
    if not Config.EnableWebSocket then return false end
    local connector = getWebSocketConnector()
    if not connector then
        State.LastError = "Executor has no WebSocket connector"
        return false
    end

    local ok, socket = pcall(connector, Config.WSUrl)
    if not ok or not socket then return false end

    State.WS = socket
    State.WSConnected = true
    State.WSReady = false
    State.WSConnectedAt = os.clock()
    State.LastWSRxAt = 0

    local messageBound = bindSocketEvent(socket, "OnMessage", handleWebSocketMessage)
    if not messageBound then
        messageBound = bindSocketEvent(socket, "Message", handleWebSocketMessage)
    end
    if not messageBound then
        State.LastError = "WebSocket connected but inbound event could not be bound"
        State.WSConnected = false
        State.WSReady = false
        pcall(function()
            if type(socket.Close) == "function" then socket:Close() end
            if type(socket.close) == "function" then socket:close() end
        end)
        return false
    end

    local function onClose()
        if State.WS == socket then
            State.WS = nil
            State.WSConnected = false
            State.WSReady = false
        end
    end
    if not bindSocketEvent(socket, "OnClose", onClose) then
        bindSocketEvent(socket, "Closed", onClose)
    end

    sendHello()
    return true
end

task.spawn(function()
    while State.Running and Config.EnableWebSocket do
        if not State.WSConnected or not State.WS then
            State.WS = nil
            State.WSConnected = false
            State.WSReady = false
            connectWebSocket()
            task.wait(State.WSConnected and 1 or 3)
        else
            local now = os.clock()

            -- Connected socket but no inbound events usually means the executor's
            -- signal binding is incompatible or the socket is stale. Reconnect
            -- instead of showing WS=ON while never receiving shared-room data.
            local ackTimedOut = (not State.WSReady)
                and State.WSConnectedAt > 0
                and (now - State.WSConnectedAt >= Config.WSAckTimeout)
            local rxStale = State.WSReady
                and State.LastWSRxAt > 0
                and (now - State.LastWSRxAt >= Config.WSStaleSeconds)

            if ackTimedOut or rxStale then
                State.LastError = ackTimedOut and "WebSocket hello_ack timeout" or "WebSocket receive stale"
                local staleSocket = State.WS
                State.WS = nil
                State.WSConnected = false
                State.WSReady = false
                pcall(function()
                    if staleSocket and type(staleSocket.Close) == "function" then staleSocket:Close() end
                    if staleSocket and type(staleSocket.close) == "function" then staleSocket:close() end
                end)
                task.wait(0.25)
            else
                if now - State.LastClientHeartbeatAt >= Config.ClientHeartbeatInterval then
                    State.LastClientHeartbeatAt = now
                    sendHello()
                    sendClientStatus()
                end
                task.wait(0.25)
            end
        end
    end
end)

-- ============================================================================
-- [10] TELEPORT / SERVER BROWSER
-- ============================================================================
TeleportService.TeleportInitFailed:Connect(function(_, result, message, _, options)
    local failedJob = options and options.ServerInstanceId or State.TeleportTarget
    State.TeleportFailed = {
        jobId = failedJob,
        result = tostring(result),
        message = tostring(message or ""),
    }
    debugPrint("TeleportInitFailed", State.TeleportFailed.result, State.TeleportFailed.message, failedJob)
end)

local function teleportToJob(jobId, reservationId, source)
    if type(jobId) ~= "string" or jobId == "" or jobId == game.JobId then return false end
    State.TeleportTarget = jobId
    State.TeleportReservationId = reservationId
    State.TeleportFailed = nil
    blockJob(jobId, Config.CandidateLocalBlacklistSeconds)

    setStatus("Joining server...", source or "JOINING", "JobId=" .. string.sub(jobId, 1, 12))
    local ok = pcall(function()
        ServerBrowser:InvokeServer("teleport", jobId)
    end)
    if not ok then
        assignmentFailed("invoke_failed")
        State.TeleportTarget = nil
        State.TeleportReservationId = nil
        return false
    end

    local deadline = os.clock() + Config.TeleportWaitSeconds
    while State.Running and os.clock() < deadline do
        if State.TeleportFailed then
            local failure = State.TeleportFailed
            assignmentFailed(failure.result .. ":" .. failure.message)
            State.TeleportTarget = nil
            State.TeleportReservationId = nil
            State.TeleportFailed = nil
            return false
        end
        task.wait(0.15)
    end

    -- If still running in the old server, consider it a failed/ignored teleport.
    assignmentFailed("teleport_timeout")
    State.TeleportTarget = nil
    State.TeleportReservationId = nil
    return false
end

local function processPendingAssignment()
    local assignment = State.PendingAssignment
    if not assignment or State.InQualifiedRoom then return false end
    State.PendingAssignment = nil

    local jobId = tostring(assignment.jobId or "")
    if jobId == "" or jobId == game.JobId then return false end

    local playerCount = tonumber(assignment.playerCount) or 0
    local maxPlayers = tonumber(assignment.maxPlayers) or Players.MaxPlayers
    local attempt = tonumber(assignment.attempt) or 1
    local maxAttempts = tonumber(assignment.maxAttempts) or 2

    if playerCount >= maxPlayers then
        State.TeleportReservationId = tostring(assignment.reservationId or "")
        State.TeleportTarget = jobId
        assignmentFailed("room_reported_full")
        State.TeleportReservationId = nil
        State.TeleportTarget = nil
        State.SharedJoinFailures += 1
        setStatus(
            "Shared room full - trying another room",
            "SCOUT",
            string.format("attempt=%d/%d | %s", attempt, maxAttempts, string.sub(jobId, 1, 12))
        )
        return false
    end

    State.Hopping = true
    Movement.cancel()
    setStatus(
        "Joining shared room...",
        "JOIN_SHARED_ROOM",
        string.format("attempt=%d/%d | players=%d/%d | %s", attempt, maxAttempts, playerCount, maxPlayers, string.sub(jobId, 1, 12))
    )

    local ok = teleportToJob(jobId, tostring(assignment.reservationId or ""), "JOIN_SHARED_ROOM")
    State.Hopping = false

    if not ok then
        State.SharedJoinFailures += 1
        -- Important: move back to SCOUT before asking the coordinator again.
        -- The server tracks failures per player+room:
        -- attempt #1 -> same room is offered once more
        -- attempt #2 -> that room is skipped and the next room is offered
        setStatus(
            "Shared join failed - retrying room pool",
            "SCOUT",
            string.format("failed attempt=%d/%d | %s", attempt, maxAttempts, string.sub(jobId, 1, 12))
        )
    end

    return ok
end

local Browser = {}

local function candidateTieScore(jobId)
    -- Stable per-account permutation inside the same player-count group.
    -- This keeps priority 4 -> 5 -> 6 while spreading 20 tabs across JobIds.
    local h = Player.UserId % 2147483647
    for i = 1, #jobId do
        h = (h * 33 + string.byte(jobId, i)) % 2147483647
    end
    return h
end

local function sortCandidates(candidates)
    table.sort(candidates, function(a, b)
        if a.players ~= b.players then
            return a.players < b.players -- 4 first, then 5, then 6.
        end
        if a.tie ~= b.tie then
            return a.tie < b.tie
        end
        return a.jobId < b.jobId
    end)
    return candidates
end

function Browser.scan()
    local now = os.clock()
    if State.BrowserCache and now - State.BrowserCacheAt < Config.BrowserCacheSeconds then
        return sortCandidates(State.BrowserCache)
    end

    setStatus(
        "Scanning 100 pages...",
        "SCANNING",
        "ONLY 4/5/6 players | priority 4 > 5 > 6"
    )

    local found = {}
    local seen = {}
    local startOffset = Player.UserId % Config.BrowserMaxPages
    local scanned = 0
    local count4 = 0
    local count5 = 0
    local count6 = 0

    local function processPageData(data)
        if type(data) ~= "table" then return end
        for jobId, info in pairs(data) do
            local count = type(info) == "table" and tonumber(info.Count) or nil
            if type(jobId) == "string"
                and not seen[jobId]
                and count
                and ALLOWED_BROWSER_PLAYERS[count] == true
                and not jobBlocked(jobId)
            then
                seen[jobId] = true
                if count == 4 then count4 += 1
                elseif count == 5 then count5 += 1
                elseif count == 6 then count6 += 1
                end

                found[#found + 1] = {
                    jobId = jobId,
                    players = count,
                    region = info.Region,
                    lastUpdate = info.__LastUpdate,
                    tie = candidateTieScore(jobId),
                }
            end
        end
    end

    -- Up to 20 ServerBrowser pages are requested concurrently.
    -- We still have a HARD 100-page ceiling.
    -- A shared room immediately interrupts this scan.
    -- Early exit is allowed only when we already found several BEST (4-player)
    -- candidates; otherwise keep scanning so 4-player servers are not missed.
    for batchStart = 1, Config.BrowserMaxPages, Config.BrowserBatchSize do
        if not State.Running or State.PendingAssignment or State.RoomHint then break end

        local batchEnd = math.min(Config.BrowserMaxPages, batchStart + Config.BrowserBatchSize - 1)
        local results = {}
        local pending = 0

        for step = batchStart, batchEnd do
            pending += 1
            local capturedStep = step
            local page = ((startOffset + capturedStep - 1) % Config.BrowserMaxPages) + 1

            task.spawn(function()
                local ok, data = pcall(function()
                    return ServerBrowser:InvokeServer(page)
                end)
                results[capturedStep] = ok and data or false
                pending -= 1
            end)
        end

        local deadline = os.clock() + Config.BrowserBatchTimeout
        while State.Running
            and pending > 0
            and os.clock() < deadline
            and not State.PendingAssignment
            and not State.RoomHint
        do
            task.wait()
        end

        if State.PendingAssignment or State.RoomHint then break end

        for step = batchStart, batchEnd do
            scanned += 1
            processPageData(results[step])
        end

        setStatus(
            "Scanning 100 pages...",
            "SCANNING",
            string.format(
                "pages=%d/100 | 4p=%d | 5p=%d | 6p=%d",
                scanned, count4, count5, count6
            )
        )

        -- Enough perfect 4-player targets: hop now instead of wasting more time.
        if count4 >= 6 then
            break
        end

        task.wait()
    end

    sortCandidates(found)
    State.BrowserCacheAt = os.clock()
    State.BrowserCache = found
    return found
end

function Browser.hopCandidate()
    if State.Hopping then return false end
    State.Hopping = true
    Movement.cancel()

    -- Small de-correlation across 20 tabs.
    local stagger = (Player.UserId % 20) * 0.02
    if stagger > 0 then task.wait(stagger) end

    local candidates = Browser.scan()

    for _, candidate in ipairs(candidates) do
        if not State.Running then break end

        -- ROOM FIRST: stop browser immediately if any shared room appears.
        if State.PendingAssignment or State.RoomHint then
            State.Hopping = false
            return false
        end

        if not jobBlocked(candidate.jobId) then
            local granted, reason = claimCandidate(candidate.jobId, candidate.players)

            if reason == "room_assignment" then
                State.Hopping = false
                return false
            end

            if reason == "room" then
                State.RoomHint = true
                requestSharedRoom(true)
                State.Hopping = false
                return false
            elseif not granted and reason == "bad" then
                blockJob(candidate.jobId, 45)
            elseif not granted and reason == "claimed" then
                blockJob(candidate.jobId, 8)
            end

            if granted then
                setStatus(
                    "Hopping candidate...",
                    "HOP_CANDIDATE",
                    string.format(
                        "priority=%dp | %s",
                        candidate.players,
                        string.sub(candidate.jobId, 1, 12)
                    )
                )

                local ok = teleportToJob(candidate.jobId, nil, "HOP_CANDIDATE")
                if ok then
                    State.Hopping = false
                    return true
                end
            end
        end
    end

    State.BrowserCache = nil
    State.Hopping = false
    setStatus("No usable 4/5/6 candidate - rescanning", "SCOUT")
    task.wait(0.25)
    return false
end

-- ============================================================================
-- [11] ANTI-IDLE / CLEANUP
-- ============================================================================
Player.Idled:Connect(function()
    pcall(function()
        VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
        task.wait(0.5)
        VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
    end)
end)

-- ============================================================================
-- [12] MAIN STATE MACHINE
-- ============================================================================
local function waitForCharacter()
    while State.Running do
        if State.Character and State.Root and State.Humanoid and State.Humanoid.Health > 0 then return true end
        setStatus("Waiting character...", "CHARACTER")
        task.wait(0.5)
    end
    return false
end

local function handleQualifiedRoom(progress)
    if not State.InQualifiedRoom then
        State.InQualifiedRoom = true
        State.QualifiedSince = os.clock()
        State.LastBadReportJob = nil
        debugPrint("Qualified room", game.JobId, progress and progress.remaining)
    end

    if os.clock() - State.LastRoomHeartbeatAt >= Config.RoomHeartbeatInterval then
        State.LastRoomHeartbeatAt = os.clock()
        publishRoom(progress)
    end

    local active = activeCakePrince()
    local stored = storedCakePrince()
    if active or stored then
        killCakePrinceStep()
        return
    end

    if progress and progress.known and progress.ready then
        spawnCakePrinceStep()
        return
    end

    if progress and progress.known and progress.remaining and progress.remaining <= Config.QualifiedRemaining then
        farmCakeMobStep(progress)
        return
    end

    setStatus("Qualified room - refreshing state...", "ROOM_SYNC")
end

local function leaveQualifiedRoom(reason)
    Movement.cancel()
    closeRoom(reason)
    State.InQualifiedRoom = false
    State.QualifiedSince = nil
    State.BossWasSeen = false
    State.ForceLeaveRoom = false
    State.BrowserCache = nil
    setStatus("Cake cycle ended - scouting again", "SCOUT", tostring(reason or "cycle_reset"))
    task.wait(0.4)
end

local function trySharedRoomsBeforeBrowser()
    if not State.WSConnected or not State.WSReady then
        return false
    end

    -- Server controls the exact 2-attempt-per-room rule.
    -- Client keeps asking until:
    --   1) teleport succeeds (the old process disappears),
    --   2) coordinator says no_room,
    --   3) WS becomes unavailable.
    --
    -- Guard prevents a pathological local-server loop, but is deliberately
    -- much higher than the expected number of rooms.
    for _ = 1, 48 do
        if not State.Running or State.InQualifiedRoom then return false end

        if State.PendingAssignment then
            if processPendingAssignment() then
                return true
            end
            -- Failed attempt: ask again immediately. The coordinator will
            -- offer the SAME room for attempt #2, then move to the next room.
            task.wait(0.03)
        end

        State.RoomRequestNoRoom = false
        requestSharedRoom(true)

        local deadline = os.clock() + Config.RoomReplyTimeout
        while State.Running
            and os.clock() < deadline
            and State.WSConnected
            and not State.PendingAssignment
            and not State.RoomRequestNoRoom
        do
            task.wait(0.02)
        end

        if State.PendingAssignment then
            if processPendingAssignment() then
                return true
            end
            task.wait(0.03)
        elseif State.RoomRequestNoRoom then
            return false
        else
            -- No reply quickly enough: fail open to Server Browser.
            return false
        end
    end

    return false
end

local function scoutStep(progress)
    State.InQualifiedRoom = false
    Movement.cancel()

    if progress and progress.known and progress.remaining and progress.remaining > Config.QualifiedRemaining then
        reportCurrentBad(progress, "remaining_too_high")
        setStatus(
            "Server not qualified",
            "SCOUT",
            string.format("remaining=%d > 150 | ROOM FIRST", progress.remaining)
        )
    elseif not progress or not progress.known then
        setStatus("Progress unknown - ROOM FIRST", "CHECK_PROGRESS")
    end

    -- Highest priority: exhaust currently opened shared rooms.
    if trySharedRoomsBeforeBrowser() then
        return
    end

    -- No usable shared room after the coordinator's 2-attempt-per-room policy.
    -- Only now do we scan/hop a fresh 4/5/6-player server.
    Browser.hopCandidate()
end

-- Initial boot.
ensureMarines()
waitForCharacter()

while State.Running do
    local ok, err = xpcall(function()
        if not ensureMarines() then
            setStatus("Unable to choose Marines; retrying", "TEAM")
            task.wait(1)
            return
        end

        if not waitForCharacter() then return end

        if not isSea3() then
            setStatus("Traveling to Sea 3...", "TRAVEL_SEA3")
            pcall(function() COMMF_:InvokeServer("TravelZou") end)
            task.wait(5)
            return
        end

        if State.PendingAssignment and not State.InQualifiedRoom then
            processPendingAssignment()
            task.wait(0.1)
            return
        end

        local progress = queryProgress(true)
        local qualified = isQualified(progress)

        if State.ForceLeaveRoom then
            leaveQualifiedRoom("coordinator_room_closed")
            return
        end

        if qualified then
            handleQualifiedRoom(progress)
            task.wait(0.10)
            return
        end

        if State.InQualifiedRoom then
            -- Strong evidence of a new 500-kill cycle means Cake Prince died / room cycle reset.
            if progress and progress.known and progress.remaining and progress.remaining > Config.QualifiedRemaining then
                leaveQualifiedRoom(State.BossWasSeen and "boss_dead_cycle_reset" or "cycle_reset")
                return
            end

            -- Unknown responses get a grace window so a transient remote failure does not blow up a good room.
            if State.UnknownSince and os.clock() - State.UnknownSince <= Config.ProgressUnknownGrace then
                setStatus("Qualified room - progress transiently unknown", "ROOM_SYNC")
                task.wait(0.25)
                return
            end

            leaveQualifiedRoom("qualification_lost")
            return
        end

        scoutStep(progress)
    end, function(e)
        return debug.traceback(tostring(e), 2)
    end)

    if not ok then
        State.LastError = tostring(err)
        setStatus("Recovered from error", "ERROR", string.sub(tostring(err), 1, 180))
        debugPrint(err)
        Movement.cancel()
        task.wait(1)
    end
end

Movement.cancel()
closeRoom("client_stopped")
pcall(function()
    if Movement.Proxy then Movement.Proxy:Destroy() end
end)
