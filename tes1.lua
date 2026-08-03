getgenv().Settings = {
    ["Max Chests"] = 50; -- if you collected 50 chests, hop server
    ["Skip Chest Delay"] = 1; -- (0.4 - 2)
    ["Black Screen"] = false;
    ["Chest Tween Speed"] = 325; -- tốc độ tween thẳng vào chest, tăng nếu muốn nhanh hơn
    ["Chest Touch Radius"] = 8; -- khoảng cách bắt đầu firetouch chest
    ["TP Bypass"] = true;
    ["TP Bypass Distance"] = 1000;
    ["TP Bypass Max Attempts"] = 3;
    ["TP Bypass Min Gain"] = 300;
    ["TP Bypass Respawn Timeout"] = 12;

    -- Chỉ CFrame + Jump tới chest thuộc đảo hiện tại.
    ["Chest Same Island Only"] = true;
    ["Chest CFrame Timeout"] = 3;
    ["Chest CFrame Interval"] = 0.06;
    ["Chest CFrame Hard Timeout"] = 5;
    ["Chest No Movement Timeout"] = 0.9;
    ["Chest Watchdog Timeout"] = 8;
    ["Chest Stuck Ignore"] = 45;

    -- Server Browser lấy từ bản Cyborg.
    ["Hop Max Pages"] = 200;
    ["Hop Pages Per Batch"] = 50;
    ["Hop Max Players"] = 5;
    ["Hop Forced Region"] = nil;
    ["Hop Scan Concurrency"] = 50;
    ["Hop Batch Timeout"] = 18;
};
PlaceId, JobId = game.PlaceId, game.JobId
CoreGUI = game:GetService("CoreGui")
RunService = game:GetService("RunService")
TweenService = game:GetService("TweenService")
HttpService = game:GetService("HttpService")
Players = game:GetService("Players")
ReplicatedStorage = game:GetService("ReplicatedStorage")
Lighting = game:GetService("Lighting")
CollectionService = game:GetService("CollectionService")
UserInputService = game:GetService("UserInputService")
VirtualInputManager = game:GetService("VirtualInputManager")
StarterGui = game:GetService("StarterGui")
GuiService = game:GetService("GuiService")
TeleportService = game:GetService("TeleportService")
COMMF_ = ReplicatedStorage:WaitForChild("Remotes") and ReplicatedStorage.Remotes:WaitForChild("CommF_")
LocalPlayer = Players.LocalPlayer
LocalPlayer.CharacterAdded:Connect(function(v)
    Character = v Humanoid = v:WaitForChild("Humanoid")
    HumanoidRootPart = v:WaitForChild("HumanoidRootPart")
end)
if LocalPlayer.Character then
    Character = LocalPlayer.Character
    Humanoid = Character:FindFirstChild("Humanoid") or Character:WaitForChild("Humanoid")
    HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart") or Character:WaitForChild("HumanoidRootPart")
end

StarterGui:SetCore("SendNotification", {Title = "Executed", Text = "Loading… Please wait", Duration = 5})
if not game:IsLoaded() or workspace.DistributedGameTime <= 10 then
    task.wait(10 - workspace.DistributedGameTime)
end
if not COMMF_ then repeat task.wait(1) until COMMF_ end
task.spawn(function()
    xpcall(function()
        if not LocalPlayer.Team then
            if LocalPlayer.PlayerGui:FindFirstChild("LoadingScreen") then
                repeat task.wait(1) until not LocalPlayer.PlayerGui:FindFirstChild("LoadingScreen")
            end
            xpcall(function() COMMF_:InvokeServer("SetTeam", "Pirates")
            end, function() firesignal(LocalPlayer.PlayerGui["Main (minimal)"].ChooseTeam.Container.Pirates) end)
            task.wait(2)
        end
    end, function(err) warn("????", err) end)
end)
repeat task.wait(2) until Character and Character:FindFirstChild("HumanoidRootPart") and Character:FindFirstChildWhichIsA("Humanoid") and Character:IsDescendantOf(workspace.Characters)

pcall(function() LocalPlayer.PlayerGui:FindFirstChild("Blank"):Destroy() end)

local BlankScreen = LocalPlayer.PlayerGui:FindFirstChild("Blank") or Instance.new("ScreenGui", LocalPlayer.PlayerGui)
BlankScreen.Name = "Blank"
BlankScreen.ResetOnSpawn = false
BlankScreen.DisplayOrder = -math.huge
BlankScreen.IgnoreGuiInset = true

local Black = BlankScreen:FindFirstChild("Black Screen") or Instance.new("Frame", BlankScreen)
Black.Name = "Black Screen"
Black.Size = UDim2.new(1, 0, 1, 0)
Black.BackgroundColor3 = Color3.new(0, 0, 0)
Black.ZIndex = -math.huge
Black.Visible = getgenv().Settings["Black Screen"]

RunService:Set3dRenderingEnabled(not Black.Visible)

local label = Instance.new("TextLabel", BlankScreen)
label.Name = "CenteredLabel"
label.AnchorPoint = Vector2.new(0.5, 0.5)
label.Position = UDim2.new(0.5, 0, 0.5, 0)
label.Size = UDim2.new(0.6, 0, 0.15, 0)
label.Text = string.rep("Nil ", 20)
label.TextScaled = true;
label.TextWrapped = true;
label.TextXAlignment = Enum.TextXAlignment.Center;
label.TextYAlignment = Enum.TextYAlignment.Center;
label.BackgroundTransparency = 1;
label.Font = Enum.Font.GothamSemibold;
label.TextSize = 48;
label.TextColor3 = Color3.fromRGB(255, 255, 255)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode.F4 then
        Black.Visible = not Black.Visible
        RunService:Set3dRenderingEnabled(not Black.Visible)
        
        StarterGui:SetCore("SendNotification", {
            Title = "Black Screen",
            Text = Black.Visible and "Đã BẬT màn hình đen (Tắt Render 3D)" or "Đã TẮT màn hình đen (Bật Render 3D)",
            Duration = 2
        })
    end
end)

local lastText = ""
local function SetText(newText)
    label.Text = newText
end

function CheckSea(v: number) return v == tonumber(workspace:GetAttribute("MAP"):match("%d+")) end
local remoteAttack, idremote
local seed = ReplicatedStorage.Modules.Net.seed:InvokeServer()
task.spawn((function() for _, v in next, ({ReplicatedStorage.Util, ReplicatedStorage.Common, ReplicatedStorage.Remotes, ReplicatedStorage.Assets, ReplicatedStorage.FX}) do
    for _, n in next, v:GetChildren() do if n:IsA("RemoteEvent") and n:GetAttribute("Id") then remoteAttack, idremote = n, n:GetAttribute("Id") end
    end v.ChildAdded:Connect(function(n) if n:IsA("RemoteEvent") and n:GetAttribute("Id") then remoteAttack, idremote = n, n:GetAttribute("Id")
    end end) end
end))
CheckTool = (function(v)
    for _, x in next, {LocalPlayer.Backpack, Character} do
    for _, v2 in next, x:GetChildren() do if v2:IsA("Tool") and (v2.Name == v or v2.Name:find(v)) then return true end
    end end return false
end)
CheckMaterial = (function(x)
    for _, v in pairs(COMMF_:InvokeServer("getInventory")) do if v.Type == "Material" then if v.Name == x then return v.Count end end
    end return 0
end)
CheckInventory = (function(...)
    for _, v in pairs(COMMF_:InvokeServer("getInventory")) do
    for _, n in next, {...} do if v.Name == n then return true end end
    end return false
end)

IsDied = function(v)
    local ok, r = xpcall(function()
        if not v then return true end
        local h = v:FindFirstChild("Humanoid")
        local hrp = v:FindFirstChild("HumanoidRootPart")
        if not h or not hrp then return true end
        if h:IsA("Humanoid") then return h.Health <= 0 end
        if h:IsA("ValueBase") and type(h.Value) == "number" then return h.Value <= 0 end
        return false
    end, function() return false end)
    return ok and r or false
end

CheckMonster = (function(...) local args = {...}
    local v2 = {workspace.Enemies, ReplicatedStorage}
    for i = 1, #args do local n = args[i]
        local m = workspace.Enemies:FindFirstChild(n) or ReplicatedStorage:FindFirstChild(n)
        if m and m:IsA("Model") and m.Name ~= "Blank Buddy" then
            local h = m:FindFirstChild("Humanoid") local r = m:FindFirstChild("HumanoidRootPart")
            if not IsDied(m) then return m end
        end
    end
    for c = 1, #v2 do local container = v2[c] local ms = container:GetChildren()
        for m = 1, #ms do local m = ms[m] local h = m:FindFirstChild("Humanoid")
            local r = m:FindFirstChild("HumanoidRootPart")
            if m:IsA("Model") and not IsDied(m) and m.Name ~= "Blank Buddy" then
                for i = 1, #args do local n = args[i]
                    if m.Name == n or m.Name:lower():find(n:lower()) then
                        return m
                    end
                end
            end
        end
    end
    return false
end)

EquipWeapon = (function(v)
    if not Character then return end
    local tool = Character:FindFirstChildWhichIsA("Tool")
    if tool and (tool.ToolTip and tool.ToolTip == v) then return end
    for _, x in next, LocalPlayer.Backpack:GetChildren() do
        if x:IsA("Tool") and x.ToolTip == v then
            Humanoid:EquipTool(x)
            return
        end
    end
end)

local lastCallFA = tick()
FastAttack = (function(x)
    if not HumanoidRootPart or not Character:FindFirstChildWhichIsA("Humanoid") or Character.Humanoid.Health <= 0 or not Character:FindFirstChildWhichIsA("Tool") then return end
    local FAD = 0.01 -- throttle
    if FAD ~= 0 and tick() - lastCallFA <= FAD then return end
    local t = {}
    for _, e in next, workspace.Enemies:GetChildren() do
        local h = e:FindFirstChild("Humanoid") local hrp = e:FindFirstChild("HumanoidRootPart")
        if e ~= Character and (x and e.Name == x or not x) and not IsDied(e) and (hrp.Position - HumanoidRootPart.Position).Magnitude <= 65 then t[#t + 1] = e end
    end
    local n = ReplicatedStorage.Modules.Net
    local h = {[2] = {}}
    local last
    for i = 1, #t do local v = t[i]
        local part = v:FindFirstChild("Head") or v:FindFirstChild("HumanoidRootPart")
        if not h[1] then h[1] = part end
        h[2][#h[2] + 1] = {v, part} last = v
    end
    n:FindFirstChild("RE/RegisterAttack"):FireServer()
    n:FindFirstChild("RE/RegisterHit"):FireServer(unpack(h))
    cloneref(remoteAttack):FireServer(string.gsub("RE/RegisterHit", ".",function(c)
        return string.char(bit32.bxor(string.byte(c), math.floor(workspace:GetServerTimeNow()/10%10)+1))
    end), bit32.bxor(idremote+909090, seed*2), unpack(h))
    lastCallFA = tick()
end)

local lastHop, inHopPP = tick(), false

local HopState = {
    NextPage = 1,
    StartPage = 0,
    EndPage = 0,
    CurrentPage = 0,
    RequestedPages = 0,
    CompletedPages = 0,
    FailedPages = 0,
    Candidates = 0,
    TimedOut = false,
}

function IfTableHaveIndex(j)
    if type(j) ~= "table" then
        return false
    end
    for _ in pairs(j) do
        return true
    end
    return false
end

local function getHopConfig(maxPlayersArg, forcedRegionArg)
    local settings = getgenv().Settings or {}

    local maxPages = math.max(
        1,
        math.floor(tonumber(settings["Hop Max Pages"]) or 200)
    )

    local pagesPerBatch = math.max(
        1,
        math.floor(tonumber(settings["Hop Pages Per Batch"]) or 50)
    )
    pagesPerBatch = math.min(pagesPerBatch, maxPages)

    local maxPlayers =
        tonumber(settings["Hop Max Players"])
        or tonumber(maxPlayersArg)
        or 8

    local forcedRegion = settings["Hop Forced Region"]
    if forcedRegion == nil or tostring(forcedRegion) == "" then
        forcedRegion = forcedRegionArg
    end
    if forcedRegion ~= nil and tostring(forcedRegion) == "" then
        forcedRegion = nil
    end

    local concurrency = math.max(
        1,
        math.floor(tonumber(settings["Hop Scan Concurrency"]) or 50)
    )
    concurrency = math.min(concurrency, pagesPerBatch)

    local batchTimeout = math.max(
        3,
        tonumber(settings["Hop Batch Timeout"]) or 18
    )

    return {
        MaxPages = maxPages,
        PagesPerBatch = pagesPerBatch,
        MaxPlayers = maxPlayers,
        ForcedRegion = forcedRegion,
        Concurrency = concurrency,
        BatchTimeout = batchTimeout,
    }
end

local function normalizeRegion(value)
    if value == nil then
        return ""
    end
    return tostring(value):lower()
end

function GetServers(MaxPlayers, ForcedRegion)
    local config = getHopConfig(MaxPlayers, ForcedRegion)
    local serverBrowser = ReplicatedStorage:WaitForChild("__ServerBrowser")

    local startPage = tonumber(HopState.NextPage) or 1
    if startPage < 1 or startPage > config.MaxPages then
        startPage = 1
    end

    local pages = {}
    for offset = 0, config.PagesPerBatch - 1 do
        pages[#pages + 1] = ((startPage - 1 + offset) % config.MaxPages) + 1
    end

    local candidates = {}
    local seenJobs = {}
    local cursor = 0
    local completed = 0
    local failed = 0
    local workersDone = 0
    local active = true
    local workerCount = math.min(config.Concurrency, #pages)
    local scanStartedAt = tick()

    HopState.StartPage = pages[1] or startPage
    HopState.EndPage = pages[#pages] or startPage
    HopState.CurrentPage = pages[1] or startPage
    HopState.RequestedPages = #pages
    HopState.CompletedPages = 0
    HopState.FailedPages = 0
    HopState.Candidates = 0
    HopState.TimedOut = false

    SetText(
        "Hop | scanning pages "
        .. tostring(HopState.StartPage)
        .. "-"
        .. tostring(HopState.EndPage)
        .. " | 0/"
        .. tostring(#pages)
    )

    local function processPageData(pageData)
        if type(pageData) ~= "table" then
            return
        end

        for jobId, info in pairs(pageData) do
            local jobKey = tostring(jobId)
            if type(info) == "table"
                and jobKey ~= tostring(game.JobId)
                and not seenJobs[jobKey] then

                local players = tonumber(info.Count)
                local region = info.Region or info.Regoin
                local regionOk =
                    not config.ForcedRegion
                    or normalizeRegion(region) == normalizeRegion(config.ForcedRegion)

                if players and players <= config.MaxPlayers and regionOk then
                    seenJobs[jobKey] = true
                    candidates[#candidates + 1] = {
                        JobId = jobId,
                        Players = players,
                        LastUpdate = tonumber(info.__LastUpdate) or 0,
                        Region = region or "Unknown",
                    }
                end
            end
        end
    end

    local function worker()
        while active do
            cursor = cursor + 1
            local index = cursor
            local page = pages[index]
            if not page then
                break
            end

            HopState.CurrentPage = page
            local ok, pageData = pcall(function()
                return serverBrowser:InvokeServer(page)
            end)

            if not active then
                break
            end

            if ok and type(pageData) == "table" then
                processPageData(pageData)
            else
                failed = failed + 1
            end

            completed = completed + 1
            HopState.CompletedPages = completed
            HopState.FailedPages = failed
            HopState.Candidates = #candidates

            if completed == #pages or completed % 5 == 0 then
                SetText(
                    "Hop | scanning pages "
                    .. tostring(HopState.StartPage)
                    .. "-"
                    .. tostring(HopState.EndPage)
                    .. " | "
                    .. tostring(completed)
                    .. "/"
                    .. tostring(#pages)
                    .. " | candidates "
                    .. tostring(#candidates)
                )
            end
        end

        workersDone = workersDone + 1
    end

    for _ = 1, workerCount do
        task.spawn(worker)
    end

    repeat
        task.wait(0.05)
    until workersDone >= workerCount
        or (tick() - scanStartedAt) >= config.BatchTimeout

    if workersDone < workerCount then
        active = false
        HopState.TimedOut = true
    end

    local lastRequestedPage = pages[#pages] or startPage
    HopState.NextPage = ((lastRequestedPage - 1 + 1) % config.MaxPages) + 1

    table.sort(candidates, function(a, b)
        if a.Players ~= b.Players then
            return a.Players < b.Players
        end
        if a.LastUpdate ~= b.LastUpdate then
            return a.LastUpdate > b.LastUpdate
        end
        return tostring(a.JobId) < tostring(b.JobId)
    end)

    HopState.Candidates = #candidates
    return candidates, config
end

HopServer = function(MaxPlayers, ForcedRegion)
    if inHopPP then
        SetText("Hop | teleport already in progress")
        return false
    end

    local candidates, config = GetServers(MaxPlayers, ForcedRegion)

    if not candidates or #candidates == 0 then
        SetText(
            "Hop | no eligible server"
            .. " | pages "
            .. tostring(HopState.StartPage)
            .. "-"
            .. tostring(HopState.EndPage)
            .. " | next "
            .. tostring(HopState.NextPage)
            .. " | maxPlayers "
            .. tostring(config.MaxPlayers)
        )
        return false
    end

    local best = candidates[1]

    SetText(
        "Hop | best server"
        .. " | players "
        .. tostring(best.Players)
        .. " | region "
        .. tostring(best.Region)
        .. " | job "
        .. tostring(best.JobId)
    )

    inHopPP = true
    lastHop = tick()

    local ok = pcall(function()
        ReplicatedStorage
            :WaitForChild("__ServerBrowser")
            :InvokeServer("teleport", best.JobId)
    end)

    if not ok then
        inHopPP = false
        SetText("Hop | teleport call failed")
        return false
    end

    task.delay(12, function()
        inHopPP = false
    end)

    return true
end

local connection, tween, pathPart, isTweening = nil, nil, nil, false
function Tween(targetCFrame: CFrame | boolean, target: CFrame)
    pcall(function() Character.Humanoid.Sit = false end)
    if not Character.Humanoid or Character.Humanoid.Health <= 0 then pcall(function() workspace.TweenGhost:Destroy() end) connection, tween, pathPart, isTweening = nil, nil, nil, false return end
    if targetCFrame == false then
        if tween then pcall(function() tween:Cancel() end) tween = nil end
        if connection then connection:Disconnect() connection = nil end
        if pathPart then pathPart:Destroy() pathPart = nil end
        isTweening = false
        return
    end
    if isTweening or not targetCFrame then return end
    isTweening = true
    local char = game.Players.LocalPlayer and game.Players.LocalPlayer.Character
    if not char then isTweening = false return end
    local root = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not root or not humanoid then isTweening = false return end
    humanoid.Sit = false
    target = target or root
    local distance = (targetCFrame.Position - target.Position).Magnitude
    pathPart = Instance.new("Part")
    pathPart.Name = "TweenGhost"
    pathPart.Transparency = 1
    pathPart.Anchored = true
    pathPart.CanCollide = false
    pathPart.CFrame = target.CFrame
    pathPart.Size = Vector3.new(50, 50, 50)
    pathPart.Parent = workspace
    tween = game:GetService("TweenService"):Create(pathPart, TweenInfo.new(distance / 250, Enum.EasingStyle.Linear), {CFrame = targetCFrame * (function()
        if target ~= root then
            return CFrame.new(0, 30, 0)
        end
        return CFrame.new(0, 5, 0)
    end)()})
    connection = game:GetService("RunService").Heartbeat:Connect(function()
        if target and pathPart then
            target.CFrame = pathPart.CFrame * (function()
                if target ~= root then
                    return CFrame.new(0, 30, 0)
                end
                return CFrame.new(0, 5, 0)
            end)()
        end
    end)
    tween.Completed:Connect(function()
        if connection then connection:Disconnect() connection = nil end
        if pathPart then pathPart:Destroy() pathPart = nil end
        tween = nil
        isTweening = false
    end)

    tween:Play()
end

local ChestBypassState = {
    Busy = false,
    SpawnBuilt = false,
    CacheLoaded = false,
    LastBuild = 0,
    Spawns = {},
    Cache = {
        Version = 2,
        Spawns = {},
        Locations = {},
    },
}

local ChestBypassSeaIndex
if PlaceId == 2753915549 or PlaceId == 85211729168715 then
    ChestBypassSeaIndex = 1
elseif PlaceId == 4442272183 or PlaceId == 79091703265657 then
    ChestBypassSeaIndex = 2
elseif PlaceId == 7449423635 or PlaceId == 100117331123089 then
    ChestBypassSeaIndex = 3
else
    ChestBypassSeaIndex = 1
end

-- v2 tránh dùng lại cache cũ bị thiếu đảo hoặc ghi đè spawn trùng tên.
local ChestBypassCachePath =
    "chest_bypass_spawns_v2_sea"
    .. tostring(ChestBypassSeaIndex)
    .. ".json"

local ChestBypassBlockedItems = {
    "Hallow Essence", "Fist of Darkness", "God's Chalice", "Sweet Chalice",
    "Fire Essence", "Special Microchip", "Hidden Key", "Water Key",
    "Library Key", "Red Key", "Holy Torch", "Torch", "Cup", "Relic",
    "Flower 1", "Flower 2", "Flower 3",
}

local function ChestBypassGetCharacter(timeout)
    local deadline = os.clock() + (tonumber(timeout) or 8)
    repeat
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildWhichIsA("Humanoid")
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if char and hum and hum.Health > 0 and root then
            Character = char
            Humanoid = hum
            HumanoidRootPart = root
            return char, hum, root
        end
        task.wait(0.1)
    until os.clock() >= deadline
    return nil, nil, nil
end

local function ChestBypassHasItem(name)
    local char = LocalPlayer.Character
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    return (char and char:FindFirstChild(name) ~= nil)
        or (backpack and backpack:FindFirstChild(name) ~= nil)
end

local function ChestBypassIsBlocked()
    if getgenv().Settings["TP Bypass"] == false or ChestBypassState.Busy then
        return true
    end
    for _, name in ipairs(ChestBypassBlockedItems) do
        if ChestBypassHasItem(name) then
            return true
        end
    end
    return false
end

local function ChestBypassCanUseFiles()
    return type(isfile) == "function"
        and type(readfile) == "function"
        and type(writefile) == "function"
end

local function ChestBypassRebuild()
    local rebuilt = {}

    for cacheKey, data in pairs(ChestBypassState.Cache.Spawns or {}) do
        if type(data) == "table" then
            local x = tonumber(data.X or data[1])
            local y = tonumber(data.Y or data[2])
            local z = tonumber(data.Z or data[3])
            local spawnName = data.Name or data.SpawnName

            if x and y and z and spawnName then
                rebuilt[#rebuilt + 1] = {
                    Key = tostring(cacheKey),
                    Name = tostring(spawnName),
                    Group = tostring(data.Group or ""),
                    Position = Vector3.new(x, y, z),
                }
            end
        end
    end

    table.sort(rebuilt, function(a, b)
        if a.Name ~= b.Name then
            return a.Name < b.Name
        end
        return a.Key < b.Key
    end)

    ChestBypassState.Spawns = rebuilt
    ChestBypassState.SpawnBuilt = #rebuilt > 0
    return ChestBypassState.SpawnBuilt
end

local function ChestBypassLoadCache()
    if ChestBypassState.CacheLoaded then
        return ChestBypassState.SpawnBuilt
    end

    ChestBypassState.CacheLoaded = true

    if not ChestBypassCanUseFiles() or not isfile(ChestBypassCachePath) then
        return false
    end

    local ok, data = pcall(function()
        return HttpService:JSONDecode(readfile(ChestBypassCachePath))
    end)

    if not ok
        or type(data) ~= "table"
        or tonumber(data.Version) ~= 2
        or type(data.Spawns) ~= "table" then
        return false
    end

    data.Locations =
        type(data.Locations) == "table"
        and data.Locations
        or {}

    ChestBypassState.Cache = data
    return ChestBypassRebuild()
end

local function ChestBypassSaveCache()
    if not ChestBypassCanUseFiles() then
        return false
    end

    ChestBypassState.Cache.Version = 2

    return pcall(function()
        writefile(
            ChestBypassCachePath,
            HttpService:JSONEncode(ChestBypassState.Cache)
        )
    end)
end

local function ChestBypassGetObjectPosition(object)
    local ok, position = pcall(function()
        if object:IsA("BasePart") then
            return object.Position
        end
        if object:IsA("Model") then
            return object:GetPivot().Position
        end
        return nil
    end)
    return ok and position or nil
end

local function ChestBypassBuildData(force)
    local now = os.clock()

    if ChestBypassState.SpawnBuilt
        and not force
        and now - (ChestBypassState.LastBuild or 0) < 10 then
        return true
    end

    if not force then
        ChestBypassLoadCache()
    end

    local origin = workspace:FindFirstChild("_WorldOrigin")
    local spawnsFolder = origin and origin:FindFirstChild("PlayerSpawns")
    local locationsFolder = origin and origin:FindFirstChild("Locations")

    if not spawnsFolder then
        return ChestBypassState.SpawnBuilt
    end

    local changed = false
    local liveCount = 0

    -- Giữ đúng cấu trúc script đầu: mỗi BasePart/Model con của PlayerSpawns
    -- là một spawn hợp lệ. Chỉ bổ sung đệ quy Folder để không bỏ sót đảo,
    -- nhưng không lấy các part con bên trong Model làm tên SetLastSpawnPoint.
    local function scanSpawnContainer(container, groupPath)
        for _, object in ipairs(container:GetChildren()) do
            if object:IsA("BasePart") or object:IsA("Model") then
                local position = ChestBypassGetObjectPosition(object)
                if position then
                    local key = tostring(object:GetFullName())
                    local old = ChestBypassState.Cache.Spawns[key]

                    liveCount = liveCount + 1

                    if not old
                        or tostring(old.Name or "") ~= tostring(object.Name)
                        or math.abs((tonumber(old.X or old[1]) or 0) - position.X) > 1
                        or math.abs((tonumber(old.Y or old[2]) or 0) - position.Y) > 1
                        or math.abs((tonumber(old.Z or old[3]) or 0) - position.Z) > 1 then

                        ChestBypassState.Cache.Spawns[key] = {
                            Name = tostring(object.Name),
                            Group = tostring(groupPath or ""),
                            X = position.X,
                            Y = position.Y,
                            Z = position.Z,
                        }
                        changed = true
                    end
                end
            elseif object:IsA("Folder") then
                local nextGroup =
                    tostring(groupPath or "")
                    .. "/"
                    .. tostring(object.Name)
                scanSpawnContainer(object, nextGroup)
            end
        end
    end

    for _, topFolder in ipairs(spawnsFolder:GetChildren()) do
        if topFolder:IsA("Folder") then
            scanSpawnContainer(topFolder, topFolder.Name)
        elseif topFolder:IsA("BasePart") or topFolder:IsA("Model") then
            scanSpawnContainer(spawnsFolder, "PlayerSpawns")
            break
        end
    end

    if locationsFolder then
        for _, location in ipairs(locationsFolder:GetChildren()) do
            if location:IsA("BasePart") then
                local mesh = location:FindFirstChild("Mesh")
                local radius = location.Size.X / 2

                if mesh and mesh:IsA("SpecialMesh") then
                    radius = mesh.Scale.X * location.Size.X / 2
                end

                local old = ChestBypassState.Cache.Locations[location.Name]
                if not old
                    or math.abs((tonumber(old[1]) or 0) - location.Position.X) > 1
                    or math.abs((tonumber(old[2]) or 0) - location.Position.Y) > 1
                    or math.abs((tonumber(old[3]) or 0) - location.Position.Z) > 1
                    or math.abs((tonumber(old[4]) or 0) - radius) > 1 then

                    ChestBypassState.Cache.Locations[location.Name] = {
                        location.Position.X,
                        location.Position.Y,
                        location.Position.Z,
                        radius,
                    }
                    changed = true
                end
            end
        end
    end

    ChestBypassState.LastBuild = now
    ChestBypassRebuild()

    if changed then
        ChestBypassSaveCache()
    end

    return ChestBypassState.SpawnBuilt, liveCount
end

local function ChestBypassGetNearestSpawn(position, forceRefresh)
    if typeof(position) ~= "Vector3" then
        return nil, math.huge
    end

    if forceRefresh or not ChestBypassState.SpawnBuilt then
        ChestBypassBuildData(forceRefresh == true)
    end

    local nearestData
    local nearestDistance = math.huge

    for _, spawnData in ipairs(ChestBypassState.Spawns) do
        local distance = (spawnData.Position - position).Magnitude
        if distance < nearestDistance then
            nearestData = spawnData
            nearestDistance = distance
        end
    end

    return nearestData, nearestDistance
end

local function ChestBypassGetCurrentIsland(root)
    if not root or not root.Parent then
        return nil, math.huge
    end

    local nearest, distance = ChestBypassGetNearestSpawn(root.Position, false)
    return nearest and nearest.Name or nil, distance
end

local function ChestBypassIsChestOnIsland(chest, islandName)
    if getgenv().Settings["Chest Same Island Only"] == false then
        return true
    end

    if not islandName or not chest or not chest:IsA("BasePart") then
        return false
    end

    local nearest = ChestBypassGetNearestSpawn(chest.Position, false)
    return nearest ~= nil and tostring(nearest.Name) == tostring(islandName)
end

local function ChestBypassSetLastSpawnScript(character, disabled)
    local scriptObject = character and character:FindFirstChild("LastSpawnPoint")
    if scriptObject then
        pcall(function()
            scriptObject.Disabled = disabled
        end)
    end
end

local function ChestBypassWaitSpawn(spawnName, timeout)
    local deadline = os.clock() + (tonumber(timeout) or 2)
    repeat
        local data = LocalPlayer:FindFirstChild("Data")
        local value = data and data:FindFirstChild("LastSpawnPoint")
        if value and tostring(value.Value) == tostring(spawnName) then
            return true
        end
        task.wait(0.05)
    until os.clock() >= deadline
    return false
end

local function ChestBypassWaitRespawn(oldCharacter)
    local timeout = tonumber(getgenv().Settings["TP Bypass Respawn Timeout"]) or 12
    local deadline = os.clock() + timeout
    repeat
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildWhichIsA("Humanoid")
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if char and char ~= oldCharacter and hum and hum.Health > 0 and root then
            Character = char
            Humanoid = hum
            HumanoidRootPart = root
            task.wait(0.3)
            ChestBypassSetLastSpawnScript(char, false)
            return char, hum, root
        end
        task.wait(0.1)
    until os.clock() >= deadline
    return ChestBypassGetCharacter(2)
end

local function ChestBypassStep(target)
    if ChestBypassIsBlocked() then
        return false
    end
    local targetPosition = typeof(target) == "CFrame" and target.Position or target
    if typeof(targetPosition) ~= "Vector3" then
        return false
    end
    local char, hum, root = ChestBypassGetCharacter(5)
    if not char or not hum or not root then
        return false
    end
    local threshold = tonumber(getgenv().Settings["TP Bypass Distance"]) or 1000
    local originalDistance = (root.Position - targetPosition).Magnitude
    if originalDistance < threshold then
        return false
    end
    if ChestBypassSeaIndex == 3 and (Vector3.new(11256, -2138, 9888) - targetPosition).Magnitude < 1500 then
        return false
    end
    if not ChestBypassBuildData(false) then
        return false
    end

    -- Nếu cache chưa có spawn hợp lý gần mục tiêu, quét live lại trước khi chọn.
    local nearestTargetSpawn, nearestTargetDistance =
        ChestBypassGetNearestSpawn(targetPosition, false)
    if not nearestTargetSpawn or nearestTargetDistance > 6000 then
        ChestBypassBuildData(true)
    end
    ChestBypassState.Busy = true
    Tween(false)
    local success, result = pcall(function()
        local candidates = {}
        for _, spawnData in ipairs(ChestBypassState.Spawns) do
            candidates[#candidates + 1] = spawnData
        end
        table.sort(candidates, function(a, b)
            return (a.Position - targetPosition).Magnitude < (b.Position - targetPosition).Magnitude
        end)
        local minGain = tonumber(getgenv().Settings["TP Bypass Min Gain"]) or 300
        ChestBypassSetLastSpawnScript(char, true)
        task.wait()
        for _, spawnData in ipairs(candidates) do
            char, hum, root = ChestBypassGetCharacter(3)
            if not char or not hum or not root then
                break
            end
            local currentDistance = (root.Position - targetPosition).Magnitude
            local spawnToTarget = (spawnData.Position - targetPosition).Magnitude
            local playerToSpawn = (root.Position - spawnData.Position).Magnitude
            if spawnToTarget + minGain < currentDistance and playerToSpawn >= 300 then
                SetText("Collect Chests | TP Bypass: " .. tostring(spawnData.Name))
                local invoked = pcall(function()
                    COMMF_:InvokeServer("SetLastSpawnPoint", spawnData.Name)
                end)
                if invoked and ChestBypassWaitSpawn(spawnData.Name, 2) then
                    local oldCharacter = char
                    pcall(function()
                        hum.Health = 0
                    end)
                    local _, _, newRoot = ChestBypassWaitRespawn(oldCharacter)
                    if newRoot then
                        return (newRoot.Position - targetPosition).Magnitude <= originalDistance - minGain
                    end
                    return false
                end
            end
        end
        ChestBypassSetLastSpawnScript(LocalPlayer.Character or char, false)
        return false
    end)
    ChestBypassState.Busy = false
    if not success then
        warn("Chest TP Bypass error:", result)
        ChestBypassSetLastSpawnScript(LocalPlayer.Character, false)
        return false
    end
    return result == true
end

local function ChestBypassTo(target)
    if getgenv().Settings["TP Bypass"] == false then
        return false
    end
    local targetPosition = typeof(target) == "CFrame" and target.Position or target
    if typeof(targetPosition) ~= "Vector3" then
        return false
    end
    local maxAttempts = tonumber(getgenv().Settings["TP Bypass Max Attempts"]) or 3
    local threshold = tonumber(getgenv().Settings["TP Bypass Distance"]) or 1000
    local changed = false
    for _ = 1, maxAttempts do
        local _, _, root = ChestBypassGetCharacter(5)
        if not root or (root.Position - targetPosition).Magnitude < threshold then
            break
        end
        if not ChestBypassStep(targetPosition) then
            break
        end
        changed = true
        task.wait(0.15)
    end
    ChestBypassGetCharacter(3)
    return changed
end

getgenv().ChestBypassTP = ChestBypassTo
getgenv().ChestBypassState = ChestBypassState

task.spawn(function()
    ChestBypassLoadCache()

    -- Không dừng ngay ở lần đầu có dữ liệu vì PlayerSpawns có thể chưa stream đủ.
    local lastCount = -1
    local stablePasses = 0

    for _ = 1, 30 do
        ChestBypassBuildData(true)

        local count = #ChestBypassState.Spawns
        if count > 0 and count == lastCount then
            stablePasses = stablePasses + 1
        else
            stablePasses = 0
            lastCount = count
        end

        if stablePasses >= 5 then
            break
        end

        task.wait(0.5)
    end
end)


local ChestFarmRuntime = {
    Token = 0,
    Active = false,
    ActiveChest = nil,
    LastProgress = os.clock(),
    LastDistance = math.huge,
    LastReason = "idle",
}

-- CFrame chest chạy trong worker riêng và có hard-timeout. Nếu executor/game nuốt
-- một lệnh CFrame hoặc firetouch thì vòng farm vẫn thoát được, không đứng 1-2 phút.
local function CFrameJumpChest(chest)
    if not chest
        or not chest:IsA("BasePart")
        or not chest.Parent
        or not chest.CanTouch then
        return false, "invalid_chest"
    end

    local _, _, startRoot = ChestBypassGetCharacter(1)
    local lockedIsland = startRoot and ChestBypassGetCurrentIsland(startRoot) or nil

    if getgenv().Settings["Chest Same Island Only"] ~= false
        and (not lockedIsland
            or not ChestBypassIsChestOnIsland(chest, lockedIsland)) then
        return false, "different_island"
    end

    Tween(false)

    local timeout = tonumber(getgenv().Settings["Chest CFrame Timeout"]) or 3
    local hardTimeout = tonumber(getgenv().Settings["Chest CFrame Hard Timeout"]) or 5
    local noMoveTimeout = tonumber(getgenv().Settings["Chest No Movement Timeout"]) or 0.9
    local interval = tonumber(getgenv().Settings["Chest CFrame Interval"]) or 0.06
    local touchRadius = tonumber(getgenv().Settings["Chest Touch Radius"]) or 8
    local skipDelay = tonumber(getgenv().Settings["Skip Chest Delay"]) or 1

    timeout = math.clamp(timeout, 1, 8)
    hardTimeout = math.clamp(hardTimeout, timeout + 0.5, 10)
    noMoveTimeout = math.clamp(noMoveTimeout, 0.35, timeout)
    interval = math.clamp(interval, 0.04, 0.25)
    skipDelay = math.clamp(skipDelay, 0.4, timeout)

    ChestFarmRuntime.Token = ChestFarmRuntime.Token + 1
    local myToken = ChestFarmRuntime.Token
    ChestFarmRuntime.Active = true
    ChestFarmRuntime.ActiveChest = chest
    ChestFarmRuntime.LastProgress = os.clock()
    ChestFarmRuntime.LastReason = "starting"

    local finished = false
    local result = false
    local reason = "timeout"

    task.spawn(function()
        local ok, err = xpcall(function()
            local startedAt = os.clock()
            local lastMovedAt = startedAt
            local lastDistance = math.huge
            local touched = false

            while ChestFarmRuntime.Token == myToken
                and os.clock() - startedAt < timeout do

                if not chest or not chest.Parent or not chest.CanTouch then
                    result = true
                    reason = "collected"
                    return
                end

                if CheckTool("Fist of Darkness") then
                    result = true
                    reason = "fist_found"
                    return
                end

                local char, humanoid, root = ChestBypassGetCharacter(0.5)
                if not char or not humanoid or not root or humanoid.Health <= 0 then
                    reason = "character_missing"
                    return
                end

                humanoid.Sit = false
                humanoid.PlatformStand = false
                humanoid.Jump = true

                pcall(function()
                    humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                end)

                pcall(function()
                    root.Anchored = false
                    root.AssemblyLinearVelocity = Vector3.zero
                    root.AssemblyAngularVelocity = Vector3.zero
                end)

                local targetCFrame = chest.CFrame * CFrame.new(0, 2.5, 0)

                -- Ưu tiên đúng kiểu script gốc: CFrame thẳng. PivotTo chỉ là fallback
                -- một lần khi CFrame bị server/executor trả ngược vị trí.
                pcall(function()
                    root.CFrame = targetCFrame
                end)

                task.wait(0.04)

                local distance = (root.Position - chest.Position).Magnitude
                if distance > touchRadius + 8 then
                    pcall(function()
                        char:PivotTo(targetCFrame)
                    end)
                    task.wait(0.03)
                    distance = (root.Position - chest.Position).Magnitude
                end

                ChestFarmRuntime.LastDistance = distance

                if distance + 10 < lastDistance then
                    lastMovedAt = os.clock()
                    ChestFarmRuntime.LastProgress = lastMovedAt
                    lastDistance = distance
                elseif lastDistance == math.huge then
                    lastDistance = distance
                end

                pcall(function()
                    humanoid.Jump = true
                    humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                end)

                if distance <= touchRadius + 4 then
                    touched = true
                    ChestFarmRuntime.LastProgress = os.clock()

                    pcall(function()
                        firetouchinterest(root, chest, 0)
                        firetouchinterest(chest, root, 0)
                    end)
                    task.wait(0.03)
                    pcall(function()
                        firetouchinterest(root, chest, 1)
                        firetouchinterest(chest, root, 1)
                    end)
                end

                if not chest or not chest.Parent or not chest.CanTouch then
                    result = true
                    reason = "collected"
                    return
                end

                if touched and os.clock() - startedAt >= skipDelay then
                    -- Giữ cách xử lý ghost chest của bản đầu, nhưng chỉ thực hiện
                    -- sau khi đã thật sự tới gần và firetouch.
                    pcall(function()
                        chest.CanTouch = false
                    end)
                    result = true
                    reason = "touch_complete"
                    return
                end

                -- CFrame bị trả ngược/không đổi vị trí: thoát sớm để chọn chest khác.
                if distance > 25 and os.clock() - lastMovedAt >= noMoveTimeout then
                    reason = "cframe_rejected"
                    return
                end

                task.wait(interval)
            end

            reason = "attempt_timeout"
        end, function(message)
            return tostring(message)
        end)

        if not ok then
            reason = "worker_error: " .. tostring(err)
        end

        finished = true
    end)

    local waitStarted = os.clock()
    repeat
        task.wait(0.05)
    until finished
        or ChestFarmRuntime.Token ~= myToken
        or os.clock() - waitStarted >= hardTimeout

    if not finished then
        ChestFarmRuntime.Token = ChestFarmRuntime.Token + 1
        result = false
        reason = "hard_timeout"
    end

    if ChestFarmRuntime.ActiveChest == chest then
        ChestFarmRuntime.Active = false
        ChestFarmRuntime.ActiveChest = nil
    end
    ChestFarmRuntime.LastReason = reason

    return result, reason
end

local canPress = true
PressKeyEvent = (function(k, d)
    if not canPress then return end
    canPress = false
    task.spawn(function()
        VirtualInputManager:SendKeyEvent(true, k, false, game) task.wait(d or 0)
        VirtualInputManager:SendKeyEvent(false, k, false, game)
        canPress = true
    end)
end)

local lastKenCall=tick()
KillMonster=(function(x)
    xpcall(function()
        if workspace.Enemies:FindFirstChild(x) then
            for _,v in next,workspace.Enemies:GetChildren() do
                local vh=v:FindFirstChild("Humanoid") local vhrp=v:FindFirstChild("HumanoidRootPart")
                if not IsDied(v) and v.Name==x then
                    local dx,dy,dz=HumanoidRootPart.Position.X-vhrp.Position.X, HumanoidRootPart.Position.Y-vhrp.Position.Y, HumanoidRootPart.Position.Z-vhrp.Position.Z
                    local sqrMag=dx*dx+dy*dy+dz*dz
                    if sqrMag<=4900 then
                        FastAttack(x)
                        if tick()-lastKenCall>=10 then lastKenCall=tick() ReplicatedStorage.Remotes.CommE:FireServer("Ken",true) end
                        Tween(CFrame.new(vhrp.Position + (vhrp.CFrame.LookVector * 20) + Vector3.new(0, vhrp.Position.Y > 60 and -20 or 20, 0)))
                        EquipWeapon("Melee")
                        return
                    end
                    Tween(vhrp.CFrame) return
                end
            end
        end
        for _,v in next,ReplicatedStorage:GetChildren() do
            local vhrp=v:FindFirstChild("HumanoidRootPart")
            if v:IsA("Model") and not IsDied(v) and v.Name==x then Tween(vhrp.CFrame) return end
        end
    end,function(e) warn("Modules ERROR:",e) end)
end)

local WorldsConfig = {
    ["1"] = "TravelMain",
    ["2"] = "TravelDressrosa",
    ["3"] = "TravelZou"
}

TeleportSea = function(sea, msg)
    local s = tostring(sea)
    local target = WorldsConfig[s]
    if not target then return end
    pcall(function() SetText(msg) end)
    COMMF_:InvokeServer(target)
end

local all = 0
local IgnoredChests = setmetatable({}, {__mode = "k"})
local ChestFailCounts = setmetatable({}, {__mode = "k"})


-- Watchdog độc lập: nếu một lần xử lý chest không tạo tiến triển trong thời gian
-- giới hạn, hủy token hiện tại và bỏ qua chest đó. Không reset nhân vật nên không
-- làm mất Fist/Chalice hoặc vật phẩm đặc biệt.
task.spawn(function()
    while task.wait(1) do
        if ChestFarmRuntime.Active and ChestFarmRuntime.ActiveChest then
            local watchdogTimeout = tonumber(
                getgenv().Settings["Chest Watchdog Timeout"]
            ) or 8

            if os.clock() - ChestFarmRuntime.LastProgress >= watchdogTimeout then
                local stuckChest = ChestFarmRuntime.ActiveChest
                ChestFarmRuntime.Token = ChestFarmRuntime.Token + 1
                ChestFarmRuntime.Active = false
                ChestFarmRuntime.ActiveChest = nil
                ChestFarmRuntime.LastReason = "watchdog"

                if stuckChest then
                    IgnoredChests[stuckChest] = os.clock()
                        + (tonumber(getgenv().Settings["Chest Stuck Ignore"]) or 45)
                end

                Tween(false)
                SetText(
                    "Chest watchdog | skipped stuck chest"
                    .. "\nLast distance: "
                    .. tostring(math.floor(ChestFarmRuntime.LastDistance or 0))
                )
            end
        end
    end
end)

local function GetNearestChest(islandName)
    local _, _, root = ChestBypassGetCharacter(3)
    if not root then
        return nil, math.huge
    end

    local nearest
    local nearestDistance = math.huge
    local now = os.clock()

    for _, chest in ipairs(CollectionService:GetTagged("_ChestTagged")) do
        if chest
            and chest:IsA("BasePart")
            and chest.Parent
            and chest.CanTouch
            and chest.Name:find("Chest") then

            local ignoredUntil = IgnoredChests[chest]
            local sameIsland =
                islandName == nil
                or ChestBypassIsChestOnIsland(chest, islandName)

            if sameIsland and (not ignoredUntil or now >= ignoredUntil) then
                local distance = (chest.Position - root.Position).Magnitude
                if distance < nearestDistance then
                    nearest = chest
                    nearestDistance = distance
                end
            end
        end
    end

    return nearest, nearestDistance
end

FarmBeli = (function(shouldStop)
    if type(shouldStop) ~= "function" then
        shouldStop = function()
            return false
        end
    end

    local sessionCount = 0

    if not ChestBypassGetCharacter(5) then
        SetText("Waiting character before chest farm")
        task.wait(1)
        return
    end

    Tween(false)

    while all < getgenv().Settings["Max Chests"] do
        if shouldStop()
            or CheckTool("Fist of Darkness")
            or CheckMonster("Darkbeard") then
            break
        end

        local char, hum, root = ChestBypassGetCharacter(5)

        if not char or not hum or not root then
            task.wait(0.5)
        else
            -- Chỉ lấy chest thuộc đảo đang đứng.
            local currentIsland = ChestBypassGetCurrentIsland(root)
            local chest, distance = GetNearestChest(currentIsland)
            local threshold =
                tonumber(getgenv().Settings["TP Bypass Distance"])
                or 1000

            -- Đảo hiện tại hết chest: chỉ dùng chest toàn map làm đích đổi spawn.
            -- Sau khi hồi sinh sẽ tìm lại chest trên đảo mới, không CFrame target cũ.
            if not chest then
                local bypassTarget, bypassDistance = GetNearestChest(nil)

                if not bypassTarget then
                    break
                end

                if getgenv().Settings["TP Bypass"] ~= false
                    and bypassDistance >= threshold then

                    SetText(
                        "Collect Chests | TP Bypass to island"
                        .. "\nSpawns detected: "
                        .. tostring(#ChestBypassState.Spawns)
                        .. " | Distance: "
                        .. tostring(math.floor(bypassDistance))
                    )

                    ChestBypassTo(bypassTarget.CFrame)
                    char, hum, root = ChestBypassGetCharacter(5)

                    if root then
                        currentIsland = ChestBypassGetCurrentIsland(root)
                        chest, distance = GetNearestChest(currentIsland)
                    end
                end
            end

            if CheckTool("Fist of Darkness") or CheckMonster("Darkbeard") then
                break
            end

            if chest
                and chest.Parent
                and chest.CanTouch
                and char
                and hum
                and hum.Health > 0
                and root
                and ChestBypassIsChestOnIsland(
                    chest,
                    ChestBypassGetCurrentIsland(root)
                ) then

                local newDistance = (chest.Position - root.Position).Magnitude

                SetText(
                    "Collect Chests | CFrame + Jump"
                    .. "\nIsland: "
                    .. tostring(ChestBypassGetCurrentIsland(root) or "Unknown")
                    .. " | "
                    .. tostring(sessionCount)
                    .. "/"
                    .. tostring(all)
                    .. "/"
                    .. tostring(getgenv().Settings["Max Chests"])
                    .. " | Distance: "
                    .. tostring(math.floor(newDistance))
                )

                local attempted, attemptReason = CFrameJumpChest(chest)

                if attempted and (not chest.Parent or not chest.CanTouch) then
                    sessionCount = sessionCount + 1
                    all = all + 1
                    IgnoredChests[chest] = nil
                    ChestFailCounts[chest] = nil
                else
                    local fails = (ChestFailCounts[chest] or 0) + 1
                    ChestFailCounts[chest] = fails

                    local hardFailure = attemptReason == "hard_timeout"
                        or attemptReason == "watchdog"
                        or attemptReason == "cframe_rejected"
                        or tostring(attemptReason):find("worker_error", 1, true) ~= nil

                    local ignoreSeconds
                    if hardFailure then
                        ignoreSeconds = tonumber(
                            getgenv().Settings["Chest Stuck Ignore"]
                        ) or 45
                    else
                        ignoreSeconds = fails >= 3 and 60 or 8
                    end

                    IgnoredChests[chest] = os.clock() + ignoreSeconds
                    SetText(
                        "Chest skipped | "
                        .. tostring(attemptReason or "unknown")
                        .. " | retry after "
                        .. tostring(math.floor(ignoreSeconds))
                        .. "s"
                    )
                end
            elseif chest then
                IgnoredChests[chest] = os.clock() + 5
            end
        end

        task.wait(0.05)
    end

    Tween(false)

    if all >= getgenv().Settings["Max Chests"] then
        SetText("Stopped: Max Chests reached")
        HopServer(8)
    elseif CheckTool("Fist of Darkness") then
        SetText("Stopped: Fist of Darkness detected")
    elseif not CheckMonster("Darkbeard") then
        HopServer(10)
    end
end)

spawn(function()
    while task.wait(0.2) do
        xpcall(function()
            if CheckSea(2) then Tween(false)
                local v = CheckMonster("Darkbeard")
                if v then
                    local t = tick()
                    repeat task.wait()
                        if tick() - t >= 1 then
                            SetText("Killing Darkbeard\nHealth: ".. math.floor(v.Humanoid.Health / v.Humanoid.MaxHealth * 100).."%")
                            t = tick()
                        end
                        KillMonster(v.Name)
                    until not v or IsDied(v) Tween(false)
                elseif CheckTool("Fist of Darkness") then
                    SetText("Spawn Darkbeard\nTweening")
                    local Detection = workspace.Map.DarkbeardArena.Summoner.Detection
                    Tween(false)
                    Tween(Detection.CFrame)
                    if (HumanoidRootPart.Position - Detection.Position).Magnitude <= 200 then
                        firetouchinterest(Detection, HumanoidRootPart, 0) task.wait(0.2)
                        firetouchinterest(Detection, HumanoidRootPart, 1)
                    end
                    task.wait(5)
                else
                    FarmBeli(function()
                        return all >= getgenv().Settings["Max Chests"] or CheckTool("Fist of Darkness") or CheckTool("Darkbeard")
                    end)
                end
            else TeleportSea(2, "Travel to sea 2 for farm Dark Fragments")
            end
        end, function(err) warn(err) end)
    end
end)

task.spawn(function()
    while task.wait(4) do
        xpcall(function()
            if not Character.Humanoid or Character.Humanoid.Health <= 0 then pcall(function() workspace.TweenGhost:Destroy() end) connection, tween, pathPart, isTweening = nil, nil, nil, false return end
            if not Character:FindFirstChild("HasBuso") then COMMF_:InvokeServer("Buso") end
            for _, v in next, {"Buso", "Geppo", "Soru"} do
                if not CollectionService:HasTag(Character, v) then
                    if LocalPlayer.Data.Beli.Value >= ((function(t)
                        return t == "Geppo" and 1e4 or t == "Buso" and 2.5e4 or t == "Soru" and 1e5 or 0
                    end)(v)) then SetText("Buy Abilies: ".. v) COMMF_:InvokeServer("BuyHaki", v)
                    end
                end
            end
        end, function(err) warn("LL: ".. err) end)
    end
end)

TeleportService.TeleportInitFailed:Connect(function(player, teleportResult, message)
    if teleportResult == Enum.TeleportResult.GameFull then inHopPP = false
    elseif teleportResult == Enum.TeleportResult.IsTeleporting and (message:find("previous teleport")) then
        StarterGui:SetCore("SendNotification", {Title = "Death Hop Found", Text = message, Duration = 8})
        task.delay(10, function() game:Shutdown() end)
    end
end)

GuiService.ErrorMessageChanged:Connect(newcclosure(function()
    if GuiService:GetErrorType() == Enum.ConnectionError.DisconnectErrors then
        while true do ReplicatedStorage:WaitForChild("__ServerBrowser"):InvokeServer('teleport', JobId) task.wait(5) end
    end
end))
