getgenv().Settings = {
    ["Max Chests"] = 50; -- if you collected 50 chests, hop server
    ["Skip Chest Delay"] = 1; -- (0.4 - 2)
    ["Black Screen"] = false;
    ["Chest CFrame Timeout"] = 3; -- tối đa bao nhiêu giây xử lý một chest
    ["Chest CFrame Interval"] = 0.05; -- nhịp CFrame + Jump + firetouch
    ["Chest Touch Radius"] = 10; -- bán kính xác nhận trước khi firetouch
    ["TP Bypass"] = true;
    ["TP Bypass Distance"] = 1000;
    ["TP Bypass Max Attempts"] = 3;
    ["TP Bypass Min Gain"] = 300;
    ["TP Bypass Respawn Timeout"] = 12;
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

function IfTableHaveIndex(j)
    for _ in j do
        return true
    end
end

local LastServersDataPulled, CachedServers
function GetServers()
    if LastServersDataPulled then
        if os.time() - LastServersDataPulled < 60 then
            return CachedServers
        end
    end

    for i = 1, 100, 1 do
        local data = ReplicatedStorage:WaitForChild("__ServerBrowser"):InvokeServer(i)
        if IfTableHaveIndex(data) then
            LastServersDataPulled = os.time()
            CachedServers = data
            return data
        end
    end
end

HopServer = function(MaxPlayers, ForcedRegion)
    MaxPlayers = MaxPlayers or 5
    SetText("Fetching Server...")
    local Servers = GetServers()
    local ArrayServers = {}

    for i, v in next, Servers do
        if v.Count <= MaxPlayers then
            table.insert(ArrayServers, {
                JobId = i,
                Players = v.Count,
                LastUpdate = v.__LastUpdate,
                Region = v.Region
            })
        end
    end
    SetText(#ArrayServers, 'servers received')
    local ServerData
    for i = 1, #ArrayServers do
        while task.wait(1) do
            local Index = math.random(1, #ArrayServers)
            ServerData = ArrayServers[Index]
            if ServerData then
                if not ForcedRegion or ServerData.Regoin == ForcedRegion then
                    SetText("Found Server:", ServerData.JobId, 'Player Count:', ServerData.Players, "Region:", ServerData.Region)
                    break
                end
            end
        end

        print('Teleporting to', ServerData.JobId, '...')
        ReplicatedStorage:WaitForChild("__ServerBrowser"):InvokeServer('teleport', ServerData.JobId)
    end
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
    Spawns = {},
    Cache = {
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

local ChestBypassCachePath = "chest_bypass_spawns_sea" .. tostring(ChestBypassSeaIndex) .. ".json"

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
    ChestBypassState.Spawns = {}
    for name, data in pairs(ChestBypassState.Cache.Spawns or {}) do
        if type(data) == "table" and data[1] and data[2] and data[3] then
            ChestBypassState.Spawns[#ChestBypassState.Spawns + 1] = {
                Name = tostring(name),
                Position = Vector3.new(data[1], data[2], data[3]),
            }
        end
    end
    ChestBypassState.SpawnBuilt = #ChestBypassState.Spawns > 0
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
    if not ok or type(data) ~= "table" or type(data.Spawns) ~= "table" then
        return false
    end
    data.Locations = type(data.Locations) == "table" and data.Locations or {}
    ChestBypassState.Cache = data
    return ChestBypassRebuild()
end

local function ChestBypassSaveCache()
    if not ChestBypassCanUseFiles() then
        return false
    end
    return pcall(function()
        writefile(ChestBypassCachePath, HttpService:JSONEncode(ChestBypassState.Cache))
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
        return object:GetModelCFrame().Position
    end)
    return ok and position or nil
end

local function ChestBypassBuildData(force)
    if ChestBypassState.SpawnBuilt and not force then
        return true
    end
    if not force and ChestBypassLoadCache() then
        return true
    end
    local origin = workspace:FindFirstChild("_WorldOrigin")
    local spawnsFolder = origin and origin:FindFirstChild("PlayerSpawns")
    local locationsFolder = origin and origin:FindFirstChild("Locations")
    if not spawnsFolder then
        return ChestBypassState.SpawnBuilt
    end
    local changed = false
    for _, folder in ipairs(spawnsFolder:GetChildren()) do
        for _, spawnObject in ipairs(folder:GetChildren()) do
            local position = ChestBypassGetObjectPosition(spawnObject)
            if position then
                local old = ChestBypassState.Cache.Spawns[spawnObject.Name]
                if not old
                    or math.abs((tonumber(old[1]) or 0) - position.X) > 1
                    or math.abs((tonumber(old[2]) or 0) - position.Y) > 1
                    or math.abs((tonumber(old[3]) or 0) - position.Z) > 1 then
                    ChestBypassState.Cache.Spawns[spawnObject.Name] = {
                        position.X, position.Y, position.Z,
                    }
                    changed = true
                end
            end
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
                ChestBypassState.Cache.Locations[location.Name] = {
                    location.Position.X, location.Position.Y, location.Position.Z, radius,
                }
            end
        end
    end
    ChestBypassRebuild()
    if changed then
        ChestBypassSaveCache()
    end
    return ChestBypassState.SpawnBuilt
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
    for _ = 1, 40 do
        if ChestBypassBuildData(true) then
            break
        end
        task.wait(0.5)
    end
end)


local function CFrameJumpChest(chest)
    if not chest or not chest:IsA("BasePart") or not chest.Parent or not chest.CanTouch then
        return false
    end

    -- Dừng mọi tween đang chạy trước khi CFrame thẳng vào chest.
    Tween(false)

    local timeout = tonumber(getgenv().Settings["Chest CFrame Timeout"]) or 3
    local interval = tonumber(getgenv().Settings["Chest CFrame Interval"]) or 0.05
    local touchRadius = tonumber(getgenv().Settings["Chest Touch Radius"]) or 10
    local skipDelay = tonumber(getgenv().Settings["Skip Chest Delay"]) or 1
    timeout = math.clamp(timeout, 1, 10)
    interval = math.clamp(interval, 0.02, 0.25)
    skipDelay = math.clamp(skipDelay, 0.4, timeout)

    local startedAt = os.clock()
    local touched = false

    repeat
        local char, humanoid, root = ChestBypassGetCharacter(1)
        if not char or not humanoid or not root or humanoid.Health <= 0 then
            return false
        end
        if not chest or not chest.Parent or not chest.CanTouch then
            break
        end

        humanoid.Sit = false

        -- 1) CFrame/TP thẳng toàn bộ nhân vật đến chest.
        local moved = pcall(function()
            if char.PrimaryPart then
                char:SetPrimaryPartCFrame(chest.CFrame)
            else
                root.CFrame = chest.CFrame
            end
        end)
        if not moved then
            pcall(function()
                char:PivotTo(chest.CFrame)
            end)
        end

        -- 2) Ép trạng thái nhảy giống logic Lua chest cũ.
        pcall(function()
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end)
        pcall(function()
            root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        end)

        task.wait()

        -- 3) Firetouch sau khi đã CFrame và bấm nhảy.
        if chest and chest.Parent and chest.CanTouch
            and (root.Position - chest.Position).Magnitude <= touchRadius then
            touched = true
            pcall(function()
                firetouchinterest(chest, root, 0)
                task.wait(0.03)
                firetouchinterest(chest, root, 1)
            end)
        end

        if CheckTool("Fist of Darkness") then
            break
        end

        -- Giữ hành vi skip chest cũ để chest ghost không làm vòng farm kẹt mãi.
        if touched and chest and chest.Parent and chest.CanTouch
            and os.clock() - startedAt >= skipDelay then
            chest.CanTouch = false
            break
        end

        task.wait(interval)
    until not chest
        or not chest.Parent
        or not chest.CanTouch
        or IsDied(LocalPlayer.Character)
        or CheckTool("Fist of Darkness")
        or os.clock() - startedAt >= timeout

    -- Thử chạm lần cuối nếu chest vẫn còn hoạt động.
    local _, humanoid, root = ChestBypassGetCharacter(1)
    if chest and chest.Parent and chest.CanTouch and humanoid and humanoid.Health > 0 and root then
        pcall(function()
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            firetouchinterest(chest, root, 0)
            task.wait(0.05)
            firetouchinterest(chest, root, 1)
        end)
        task.wait(0.1)
    end

    if chest and chest.Parent and chest.CanTouch and touched then
        chest.CanTouch = false
    end

    return true
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

local function GetNearestChest()
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
            if not ignoredUntil or now >= ignoredUntil then
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
            local chest, distance = GetNearestChest()
            if not chest then
                break
            end
            local threshold = tonumber(getgenv().Settings["TP Bypass Distance"]) or 1000
            if getgenv().Settings["TP Bypass"] ~= false and distance >= threshold then
                SetText(
                    "Collect Chests | TP Bypass\nDistance: "
                    .. math.floor(distance)
                    .. " | "
                    .. all
                    .. "/"
                    .. getgenv().Settings["Max Chests"]
                )
                ChestBypassTo(chest.CFrame)
                char, hum, root = ChestBypassGetCharacter(5)
            end
            if CheckTool("Fist of Darkness") or CheckMonster("Darkbeard") then
                break
            end
            if chest and chest.Parent and chest.CanTouch and char and hum and hum.Health > 0 and root then
                local newDistance = (chest.Position - root.Position).Magnitude
                SetText(
                    "Collect Chests | CFrame + Jump: "
                    .. sessionCount
                    .. "/"
                    .. all
                    .. "/"
                    .. getgenv().Settings["Max Chests"]
                    .. " Chests\nDistance: "
                    .. math.floor(newDistance)
                )
                local attempted = CFrameJumpChest(chest)
                if attempted and (not chest.Parent or not chest.CanTouch) then
                    sessionCount += 1
                    all += 1
                    IgnoredChests[chest] = nil
                else
                    IgnoredChests[chest] = os.clock() + 8
                end
            else
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
