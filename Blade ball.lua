-----------------------------------------------------------
-- auto parry,spam logic and other
-----------------------------------------------------------
if not game:HttpGet("https://raw.githubusercontent.com/MarchHubOnTopFr/Experimental/refs/heads/main/KillSwitch.lua") then return end
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = Character:FindFirstChildOfClass("Humanoid")
local Workspace = game:GetService("Workspace")
local ServerStatsItem = game:GetService("Stats").Network.ServerStatsItem
local Player = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Aerodynamic = false
local Aerodynamic_Time = tick()
local Last_Input = UserInputService:GetLastInputType()
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local Alive = workspace.Alive
local Vector2_Mouse_Location = nil
local Grab_Parry = nil
local pingBased = true
local Remotes = {}
local Parry_Key = nil
local Spamming = false
local SpamSpeed = 7
local InfinityD, TimeHoleD, SingularityD, SOFD, Abil, CDP, Phantom = false, false, false, false, false, false, false
local EffectClasses = {ParticleEmitter=true, Beam=true, Trail=true, Explosion=true}
local Connections_Manager = {}
local Parried = false
local Last_Parry = 0
local NoRender = nil
local Xurr = (0.7 + (8 - 1) * (0.35 / 99))
local Closest_Entity = nil
local strafeEnabled, autoClaimRewards, CameraFOVEnabled = false, false, false
local StrafeSpeed, CameraFOV = 36, 70

task.spawn(function()
    for _, Value in pairs(getgc()) do
        if ((type(Value) == "function") and islclosure(Value)) then
            if debug.getupvalues(Value) then
                local Protos = debug.getprotos(Value)
                local Upvalues = debug.getupvalues(Value)
                local Constants = debug.getconstants(Value)
                if ((#Protos == 4) and (#Upvalues == 24) and (#Constants == 104)) then
                    Remotes[debug.getupvalue(Value, 16)] = debug.getconstant(Value, 62)
                    Parry_Key = debug.getupvalue(Value, 17)
                    Remotes[debug.getupvalue(Value, 18)] = debug.getconstant(Value, 64)
                    Remotes[debug.getupvalue(Value, 19)] = debug.getconstant(Value, 65)
                    break
                end
            end
        end
    end
end)

local EmotesFolder = ReplicatedStorage:WaitForChild("Misc"):WaitForChild("Emotes")
local Animation = {
    storage = {},
    current = nil,
    track = nil
}

for _, anim in pairs(EmotesFolder:GetChildren()) do
    if anim:IsA("Animation") then
        local emoteName = anim:GetAttribute("EmoteName")
        if emoteName then
            Animation.storage[emoteName] = anim
        end
    end
end

local Emotes_Data = table.create(#Animation.storage)
for emoteName in pairs(Animation.storage) do
    table.insert(Emotes_Data, emoteName)
end
table.sort(Emotes_Data)
selected_animation = Emotes_Data[1]

local Key = Parry_Key
local Parries = 0

local StarX = {}

StarX.Parry_Anim = function()
    local Parry_Animation = game:GetService("ReplicatedStorage").Shared.SwordAPI.Collection.Default:FindFirstChild("GrabParry")
    local Current_Sword = Player.Character:GetAttribute("CurrentlyEquippedSword")
    
    if not Current_Sword then
        return
    end
    
    if not Parry_Animation then
        return
    end
    
    local Sword_Data = game:GetService("ReplicatedStorage").Shared.ReplicatedInstances.Swords.GetSword:Invoke(Current_Sword)
    
    if (not Sword_Data or not Sword_Data['AnimationType']) then
        return
    end
    
    for _, object in pairs(game:GetService("ReplicatedStorage").Shared.SwordAPI.Collection:GetChildren()) do
        if (object.Name == Sword_Data['AnimationType']) then
            if (object:FindFirstChild("GrabParry") or object:FindFirstChild("Grab")) then
                local sword_animation_type = "GrabParry"
                if object:FindFirstChild("Grab") then
                    sword_animation_type = "Grab"
                end
                Parry_Animation = object[sword_animation_type]
            end
        end
    end
    
    Grab_Parry = Player.Character.Humanoid.Animator:LoadAnimation(Parry_Animation)
    Grab_Parry:Play()
end

StarX.Play_Anim = function(v)
    local Animations = Animation.storage[v]
    
    if not Animations then
        return false
    end
    
    local Animator = Player.Character.Humanoid.Animator
    
    if Animation.track then
        Animation.track:Stop()
    end
    
    Animation.track = Animator:LoadAnimation(Animations)
    Animation.track:Play()
    Animation.current = v
end

StarX.FetchBalls = function()
    local folder = workspace:FindFirstChild(workspace.Alive:FindFirstChild(tostring(Player)) and "Balls" or "TrainingBalls")
    if not folder then return {} end

    local balls = {}
    for _, ball in ipairs(folder:GetChildren()) do
        if ball:GetAttribute("realBall") then
            ball.CanCollide = false
            balls[#balls + 1] = ball
        end
    end
    return balls
end

StarX.FetchBall = function()
    local folder = workspace:FindFirstChild(workspace.Alive:FindFirstChild(tostring(Player)) and "Balls" or "TrainingBalls")
    if not folder then return end

    for _, ball in ipairs(folder:GetChildren()) do
        if ball:GetAttribute("realBall") then
            ball.CanCollide = false
            return ball
        end
    end
end

StarX.Parry_Data = function()
    local cam, char = workspace.CurrentCamera, Player.Character
    if not cam then return {0, CFrame.new(), {}, {0, 0}} end
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return {0, CFrame.new(), {}, {0, 0}} end

    local ccf, cpos, look, right, up = cam.CFrame, cam.CFrame.Position, cam.CFrame.LookVector, cam.CFrame.RightVector, cam.CFrame.UpVector
    local vs = cam.ViewportSize
    local mouse = (Last_Input == Enum.UserInputType.MouseButton1 or Last_Input == Enum.UserInputType.MouseButton2 or Last_Input == Enum.UserInputType.Keyboard)
        and UserInputService:GetMouseLocation() or Vector2.new(vs.X * 0.5, vs.Y * 0.5)
    Vector2_Mouse_Location = {mouse.X, mouse.Y}

    local events = {}
    for _, v in ipairs(workspace.Alive:GetChildren()) do
        local pp = v.PrimaryPart
        if pp then events[tostring(v)] = cam:WorldToScreenPoint(pp.Position) end
    end

    local dirCF
    if Selected_Parry_Type == "Straight" then
        local closest, dist, mv = nil, math.huge, Vector2.new(mouse.X, mouse.Y)
        for _, v in ipairs(workspace.Alive:GetChildren()) do
            if v ~= char and v.PrimaryPart then
                local pos, onScreen = cam:WorldToScreenPoint(v.PrimaryPart.Position)
                if onScreen then
                    local d = (mv - Vector2.new(pos.X, pos.Y)).Magnitude
                    if d < dist then dist, closest = d, v end
                end
            end
        end
        local target = closest or StarX.Get_Closest()
        dirCF = CFrame.new(hrp.Position, (target and target.PrimaryPart and target.PrimaryPart.Position) or (hrp.Position + look * 100))
    else
        local dirs = {
            Custom = ccf,
            Random = CFrame.new(cpos, Vector3.new(math.random(-3e3, 3e3), math.random(-3e3, 3e3), math.random(-3e3, 3e3))),
            Backwards = CFrame.new(cpos, cpos - look * 1e3),
            Up = CFrame.new(cpos, cpos + up * 1e3),
            Right = CFrame.new(cpos, cpos + right * 1e3),
            Left = CFrame.new(cpos, cpos - right * 1e3)
        }
        dirCF = dirs[Selected_Parry_Type] or ccf
    end

    return {0, dirCF, events, Vector2_Mouse_Location}
end

StarX.Parry = function()
    local data = StarX.Parry_Data()
    for r, a in pairs(Remotes) do
        r:FireServer(a, Key, data[1], data[2], data[3], data[4])
    end
    if Parries > 7 then return false end
    Parries += 1
    task.delay(0.6, function() if Parries > 0 then Parries -= 1 end end)
end

local Runtime = workspace:FindFirstChild("Runtime")
local Tornado_Time = tick()
local LR, VelHist, LastWarp, LastCurve = 0, {}, tick(), tick()

StarX.Lerp = function(a, b, t) return a + (b - a) * t end

local Angle = function(a, b) return math.deg(math.acos(math.clamp(a:Dot(b), -1, 1))) end

function StarX.Curved()
    local b = StarX.FetchBall()
    if not b or not b:FindFirstChild('zoomies') then return false end
    
    local z, v = b.zoomies, b.zoomies.VectorVelocity
    local s, d = v.Magnitude, v.Unit
    local r = Player.Character and Player.Character.PrimaryPart
    if not r then return false end
    
    local p, bp = r.Position, b.Position
    local dir, dist = (p - bp).Unit, (p - bp).Magnitude
    local dot = dir:Dot(d)
    local ping = ServerStatsItem["Data Ping"]:GetValue()
    
    if ping > 150 then 
        ping *= 1.1 
    elseif ping > 200 then 
        ping *= 1.25 
    end
    
    table.insert(VelHist, v)
    if #VelHist > 4 then table.remove(VelHist, 1) end
    
    local rt = dist / s - ping / 985
    local dT = 15 - math.min(dist / 1000, 15) + math.min(s / 100, 40)
    
    if b:FindFirstChild("AeroDynamicSlashVFX") then
        Debris:AddItem(b.AeroDynamicSlashVFX, 0)
        Tornado_Time = tick()
    end
    
    if Runtime:FindFirstChild("Tornado") and (tick() - Tornado_Time) < ((Runtime.Tornado:GetAttribute("TornadoTime") or 1) + 0.314159) then
        return true
    end
    
    if s > 160 and rt > ping / 9.85 then
        local adjust = s < 300 and 15 or s < 600 and 16 or s < 1000 and 17 or s < 1500 and 19 or 20
        dT = math.max(dT - adjust, adjust)
    end
    
    if dist < dT then return false end
    
    local curve_time = s < 300 and rt / 1.2 or s < 450 and rt / 1.21 or s < 600 and rt / 1.335 or rt / 1.5
    if (tick() - LastCurve) < curve_time then return true end
    
    local dth = 0.485 - ping / 985
    local diff = dir:Dot((d - v.Unit).Unit)
    if (dot - diff) < dth then return true end
    
    local rad = math.deg(math.asin(math.clamp(dot, -1, 1)))
    LR = StarX.Lerp(LR, rad, 0.8)
    
    local warp_time = s < 300 and rt / 1.185 or rt / 1.5
    local warp_thres = s < 300 and 0.0205 or 0.018
    if LR < warp_thres then LastWarp = tick() end
    if (tick() - LastWarp) < warp_time then return true end
    
    if #VelHist == 4 then
        local dv = function(i) return dir:Dot((d - VelHist[i].Unit).Unit) end
        if dot - dv(1) < dth or dot - dv(2) < dth then return true end
    end
    
    local hp = Vector3.new(p.X - bp.X, 0, p.Z - bp.Z).Unit
    local bd = Vector3.new(d.X, 0, d.Z).Unit
    if hp.Magnitude > 0 and bd.Magnitude > 0 then
        local back = math.deg(math.acos(math.clamp((-hp):Dot(bd), -1, 1)))
        if back < 90 - ping / 25 then return true end
    end
    
    return dot < dth
end

StarX.Get_Closest = function()
    local Max_Distance = math.huge
    for _, Entity in pairs(workspace.Alive:GetChildren()) do
        if (tostring(Entity) ~= tostring(Player)) then
            local Distance = Player:DistanceFromCharacter(Entity.PrimaryPart.Position)
            if (Distance < Max_Distance) then
                Max_Distance = Distance
                Closest_Entity = Entity
            end
        end
    end
    return Closest_Entity
end

StarX.Entity_Properties = function(self)
    StarX.Get_Closest()
    if not Closest_Entity then
        return false
    end
    
    local Entity_Velocity = Closest_Entity.PrimaryPart.Velocity
    local Entity_Direction = (Player.Character.PrimaryPart.Position - Closest_Entity.PrimaryPart.Position).Unit
    local Entity_Distance = (Player.Character.PrimaryPart.Position - Closest_Entity.PrimaryPart.Position).Magnitude
    
    return {
        Velocity = Entity_Velocity,
        Direction = Entity_Direction,
        Distance = Entity_Distance
    }
end

StarX.Ball_Properties = function(self)
    local Ball = StarX.FetchBall()
    local Ball_Velocity = Vector3.zero
    local Ball_Origin = Ball
    local Ball_Direction = (Player.Character.PrimaryPart.Position - Ball_Origin.Position).Unit
    local Ball_Distance = (Player.Character.PrimaryPart.Position - Ball.Position).Magnitude
    local Ball_Dot = Ball_Direction:Dot(Ball_Velocity.Unit)
    
    return {
        Velocity = Ball_Velocity,
        Direction = Ball_Direction,
        Distance = Ball_Distance,
        Dot = Ball_Dot
    }
end

local visualizerEnabled = false
local visualizer = Instance.new("Part")
visualizer.Shape = Enum.PartType.Ball
visualizer.Anchored = true
visualizer.CanCollide = false
visualizer.Material = Enum.Material.ForceField
visualizer.Transparency = 0.5
visualizer.Parent = Workspace
visualizer.Size = Vector3.zero
visualizer.CastShadow = false

local Sound_Effect = true
local sound_effect_type = "DC_15X"
local CustomId = ""
local sound_assets = {
    DC_15X = 'rbxassetid://936447863',
    Neverlose = 'rbxassetid://8679627751',
    Minecraft = 'rbxassetid://8766809464',
    MinecraftHit2 = 'rbxassetid://8458185621',
    TeamfortressBonk = 'rbxassetid://8255306220',
    TeamfortressBell = 'rbxassetid://2868331684',
    Custom = 'empty'
}

local SlashesNet = ReplicatedStorage:WaitForChild("Packages")._Index:FindFirstChild("sleitnick_net@0.1.0")
local SlashesRemote = SlashesNet and SlashesNet:FindFirstChild("net"):FindFirstChild("RE/SlashesOfFuryActivate")
local IsSlashesPending = false
local SlashesParryCount = 0
local SlashesActive = false

if SlashesRemote then
    SlashesRemote.OnClientEvent:Connect(function()
        if SOFD then
            IsSlashesPending = true
        end
    end)
end

local mode = "Blatant"

local function StartSlashesParry()
    if SlashesActive then return end
    SlashesActive = true
    SlashesParryCount = 0
    task.wait(0.3)
    
    task.spawn(function()
        local lastParryTime = tick()
        while SlashesParryCount < 35 do
            local currentTime = tick()
            local delay = 0.1
            
            if mode == "Blatant" then
                delay = 0.043
            elseif mode == "Legit" then
                delay = math.random(100, 450) / 1000
            end
            
            if currentTime - lastParryTime >= delay then
                StarX.Parry()
                SlashesParryCount += 1
                lastParryTime = currentTime
            end
            
            task.wait()
        end
        
        Parries = 0
        task.wait(0.15)
        SlashesActive = false
    end)
end

local Use_Ability = ReplicatedStorage.Remotes.AbilityButtonPress
local Phantom = false
local hotbar = Player:FindFirstChild("PlayerGui") and Player.PlayerGui:FindFirstChild("Hotbar")
local ParryCD = hotbar and hotbar:FindFirstChild("Block") and hotbar.Block:FindFirstChild("UIGradient")
local AbilityCD = hotbar and hotbar:FindFirstChild("Ability") and hotbar.Ability:FindFirstChild("UIGradient")
local Ability = Player.Character.Abilities

local function isCooldownInEffect1(uigradient)
    return uigradient.Offset.Y < 0.4
end

local function isCooldownInEffect2(uigradient)
    return uigradient.Offset.Y == 0.5
end

local function cooldownProtection()
    if not CDP or not Alive:FindFirstChild(tostring(Player)) then return false end
    
    if isCooldownInEffect1(ParryCD) then
        game:GetService("ReplicatedStorage").Remotes.AbilityButtonPress:Fire()
        return true
    end
    
    return false
end

local function AutoAbility()
    if not Abil or not Alive:FindFirstChild(tostring(Player)) then return false end
    
    if isCooldownInEffect2(AbilityCD) then
        if Ability["Raging Deflection"].Enabled or 
           Ability["Rapture"].Enabled or 
           Ability["Calming Deflection"].Enabled or 
           Ability["Aerodynamic Slash"].Enabled or 
           Ability["Fracture"].Enabled or 
           Ability["Death Slash"].Enabled or 
           Ability["Flash Counter"].Enabled then
            Parried = true
            game:GetService("ReplicatedStorage").Remotes.AbilityButtonPress:Fire()
            task.wait(2.432)
            game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("DeathSlashShootActivation"):FireServer(true)
            return true
        end
    end
    
    return false
end

local enabled = false
local swordName = ""
print = function(...) end

local p = game:GetService("Players").LocalPlayer
local rs = game:GetService("ReplicatedStorage")
local swords = require(rs:WaitForChild("Shared", 9e9):WaitForChild("ReplicatedInstances", 9e9):WaitForChild("Swords", 9e9))
local ctrl, playFx, lastParry = nil, nil, 0

local function getSlash(name)
    local s = swords:GetSword(name)
    return (s and s.SlashName) or "SlashEffect"
end

local slash = getSlash(swordName)

local function setSword()
    if not enabled then return end
    slash = getSlash(swordName)
    setupvalue(rawget(swords, "EquipSwordTo"), 2, false)
    swords:EquipSwordTo(p.Character, swordName)
    ctrl:SetSword(swordName)
end

while task.wait() and not ctrl do
    for _, v in getconnections(rs.Remotes.FireSwordInfo.OnClientEvent) do
        if v.Function and islclosure(v.Function) then
            local u = getupvalues(v.Function)
            if #u == 1 and type(u[1]) == "table" then
                ctrl = u[1]
                break
            end
        end
    end
end

local parryConnA, parryConnB
while task.wait() and not parryConnA do
    for _, v in getconnections(rs.Remotes.ParrySuccessAll.OnClientEvent) do
        if v.Function and getinfo(v.Function).name == "parrySuccessAll" then
            parryConnA, playFx = v, v.Function
            v:Disable()
            break
        end
    end
end

while task.wait() and not parryConnB do
    for _, v in getconnections(rs.Remotes.ParrySuccessClient.Event) do
        if v.Function and getinfo(v.Function).name == "parrySuccessAll" then
            parryConnB = v
            v:Disable()
            break
        end
    end
end

rs.Remotes.ParrySuccessAll.OnClientEvent:Connect(function(...)
    setthreadidentity(2)
    local args = {...}
    if tostring(args[4]) ~= p.Name then
        lastParry = tick()
    elseif enabled then
        args[1] = slash
        args[3] = swordName
    end
    return playFx(unpack(args))
end)

task.spawn(function()
    while task.wait(1) do
        if enabled and swordName ~= "" then
            local c = p.Character or p.CharacterAdded:Wait()
            if p:GetAttribute("CurrentlyEquippedSword") ~= swordName or not c:FindFirstChild(swordName) then
                setSword()
            end
            for _, m in pairs(c:GetChildren()) do
                if m:IsA("Model") and m.Name ~= swordName then
                    m:Destroy()
                end
                task.wait()
            end
        end
    end
end)

local Infinity_Ball = false

ReplicatedStorage.Remotes.InfinityBall.OnClientEvent:Connect(function(a, b)
    if b then
        Infinity_Ball = true
    else
        Infinity_Ball = false
    end
end)

local Config = {
    ap = true,
    as = true,
    v = true,
    cp = "Straight",
    pa = 80,
    sof = true,
    sofm = "Blatant",
    s = true,
    th = false,
    i = true,
    p = true,
    aa = false,
    cdp = false,
    sc = false,
    sci = "",
    hs = false,
    hst = "DC_15X",
    hsc = "",
    e = false,
    et = Emotes_Data[1],
    acr = true,
    ws = false,
    wss = 36,
    f = false,
    fc = 70,
    bt = false,
    bmh = 0,
    beh = 0,
    pt = false,
    pmh = 0,
    peh = 0,
    ae = false,
    nr = false,
    sb = false,
    sbt = "Default",
}

local CONFIG_PATH = "StarX.json"

local function SaveConfig()
    writefile(CONFIG_PATH, game:GetService("HttpService"):JSONEncode(Config))
end

local function LoadConfig()
    if isfile(CONFIG_PATH) then
        local success, data = pcall(function()
            return game:GetService("HttpService"):JSONDecode(readfile(CONFIG_PATH))
        end)
        if success and typeof(data) == "table" then
            for k, v in pairs(data) do
                Config[k] = v
            end
        end
    end
end
-----------------------------------------------------------
-- gui helpers
-----------------------------------------------------------
local Players          = game:GetService("Players")
local LocalPlayer      = Players.LocalPlayer
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local Workspace        = game:GetService("Workspace")
local ReplicatedStore  = game:GetService("ReplicatedStorage")
local VirtualInput     = game:GetService("VirtualInputManager")
local Debris           = game:GetService("Debris")
local Stats            = game:GetService("Stats")
local CoreGui         = game:GetService("CoreGui")

local clientCharacter  = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local clientHumanoid   = clientCharacter:FindFirstChildOfClass("Humanoid")
local AliveGroup       = Workspace:FindFirstChild("Alive")

local lastInputType    = UserInputService:GetLastInputType()
local currentMousePos  = nil
local parryAnimation   = nil
local Remotes          = {}
local Parry_Key        = nil

-- Global flags
getgenv().SingularityActive = false
getgenv().AerodynamicActive = false
getgenv().AerodynamicTime = 0
getgenv().DeathSlashActive = false
getgenv().DeathSlashTime = 0
getgenv().DeathSlashParryCount = 0
getgenv().AerodynamicDetectionEnabled = false
getgenv().DeathSlashDetectionEnabled = false

local lastSpamTime = 0
local lastParryTime = 0
local parryCooldown = 0.01
local connManager = {}
local Parries = 0
local parryFlag = false
local selectedParryMode = "Custom"
local spamThreshold = 0.01
local spamSpeed = 10
local Spamming = false
local Closest_Entity = nil
local ServerStatsItem = Stats.Network.ServerStatsItem
local Alive = Workspace.Alive
local activeMethod = "Remote"

-- Manual Spam
local manualSpamEnabled = false
local spamming = false
local spamRate = 0.005

-----------------------------------------------------------
-- Remote Lookup
-----------------------------------------------------------
task.spawn(function()
    for _, Value in getgc() do
        if type(Value) == 'function' and islclosure(Value) then
            local Protos = debug.getprotos(Value)
            local Upvalues = debug.getupvalues(Value)
            local Constants = debug.getconstants(Value)
            if #Protos == 4 and #Upvalues == 24 and #Constants >= 102 then
                local c62 = Constants[62]
                local c64 = Constants[64]
                local c65 = Constants[65]
                Remotes[debug.getupvalue(Value, 16)] = c62
                Parry_Key = debug.getupvalue(Value, 17)
                Remotes[debug.getupvalue(Value, 18)] = c64
                Remotes[debug.getupvalue(Value, 19)] = c65
                break
            end
        end
    end
    if not Parry_Key or next(Remotes) == nil then
        warn("[Key Finder] Failed to find remotes or parry key. Falling back to Keypress method.")
        activeMethod = "F Key"
    end
end)

-----------------------------------------------------------
-- Tween and Animation Helpers
-----------------------------------------------------------
local function executeTween(target, info, props)
    local tw = TweenService:Create(target, info, props)
    tw:Play()
    task.wait(info.Time)
    Debris:AddItem(tw, 0)
    tw:Destroy()
end

-----------------------------------------------------------
-- Animation Management
-----------------------------------------------------------
local AnimStorage = { list = {}, current = nil, track = nil }
for _, anim in pairs(ReplicatedStore.Misc.Emotes:GetChildren()) do
    if anim:IsA("Animation") and anim:GetAttribute("EmoteName") then
        AnimStorage.list[anim:GetAttribute("EmoteName")] = anim
    end
end
local animNames = {}
for name in pairs(AnimStorage.list) do
    table.insert(animNames, name)
end
table.sort(animNames)

-----------------------------------------------------------
-- LOAD EXTERNAL LIBRARY AND SETUP UI TABS
-----------------------------------------------------------
local function loadExternalLib(url)
    local success, lib = pcall(function() return loadstring(game:HttpGet(url))() end)
    if not success then
        warn("Failed to load library from " .. url)
        return nil
    end
    return lib
end

local externalLib = loadExternalLib("https://pastefy.app/FpmJXl1J/raw")
local mainLib = externalLib.__init()
-- CREATE TABS
local mainTab   = mainLib.create_tab("Main")
local visualTab   = mainLib.create_tab("Visual")
-----------------------------------------------------------
-- MAIN TAB SETUP
-----------------------------------------------------------
mainTab.create_title({ name = "Combat", section = "left" })
mainTab.create_description_toggle({
  name = "Auto Parry",
  description = "Automatically parries incoming balls",
  flag = "pr",
  enabled = true,
  section = "left",
  callback = function(state)
         Config.ap = state
        if state then
            print("[ Debug ] Auto Parry Enabled")
            local Stats, tostringPlayer = game:GetService("Stats"), tostring(Player)
            Connections_Manager["Auto Parry"] = RunService.PreSimulation:Connect(function()
                local char, gui = Player.Character, Player:FindFirstChild("PlayerGui")
                StarX.Get_Closest()
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if not char or not hrp then warn("[ Debug ] No HumanoidRootPart") return end
                if hrp:FindFirstChild("SingularityCape") and SingularityD then return end
                local hotbar = gui and gui:FindFirstChild("Hotbar")
                local balls, oneBall = StarX.FetchBalls(), StarX.FetchBall()
                local oneTarget = oneBall and oneBall:GetAttribute("target")
                local ab = char:FindFirstChild("Abilities")
                local ui = hotbar and hotbar:FindFirstChild("Ability") and hotbar.Ability:FindFirstChild("Duration")
                local inf = ab and ab:FindFirstChild("Infinity")
                local th = ab and ab:FindFirstChild("Time Hole")
                local statsPing = Stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 10
                statsPing = statsPing > 200 and statsPing * 1.25 or statsPing > 150 and statsPing * 1.1 or statsPing
                
                for _, ball in pairs(balls) do
                    local zoom = ball and ball:FindFirstChild("zoomies")
                    if not zoom then continue end
                    ball:GetAttributeChangedSignal("target"):Once(function() Parried = false end)
                    if Parried then return end
                    local target = ball:GetAttribute("target")
                    local pos, vel = ball.Position, zoom.VectorVelocity
                    local dist, spd = (hrp.Position - pos).Magnitude, vel.Magnitude
                    
                    if target == tostringPlayer and Aerodynamic and (tick() - Aerodynamic_Time) > 0.6 then
                        Aerodynamic_Time, Aerodynamic = tick(), false
                        return
                    end
                    
                    if oneTarget == tostringPlayer and StarX.Curved() then return end
                    if Spamming then return end
                    
                    local future = pos + vel * (statsPing / 1000)
                    if oneTarget == tostringPlayer and (hrp.Position - future).Unit:Dot(vel.Unit) < 0 then return end
                    
                    if ui and ui.Visible then
                        if (inf and inf.Enabled and Infinity_Ball and InfinityD) or (th and th.Enabled and TimeHoleD) then return end
                    end
                    
                    if Phantom and char:GetAttribute("Parrying") and PhantomD then
                        CAS:BindAction("BlockPlayerMovement", BlockMovement, false, Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D, Enum.UserInputType.Touch)
                        local hum = char.Humanoid
                        hum.WalkSpeed = 36
                        hum:MoveTo(pos)
                        task.spawn(function()
                            while Phantom do 
                                if hum.WalkSpeed ~= 36 then 
                                    hum.WalkSpeed = 36 
                                end 
                                task.wait() 
                            end
                        end)
                        ball:GetAttributeChangedSignal("target"):Once(function()
                            CAS:UnbindAction("BlockPlayerMovement")
                            Phantom = false
                            hum:MoveTo(hrp.Position)
                            hum.WalkSpeed = 10
                            task.delay(3, function() hum.WalkSpeed = 36 end)
                        end)
                    end
                    
                    local divisor = (2.4 + math.min(math.max(spd - 9.5, 0), 820) * 0.002) * Xurr
                    local acc = statsPing + math.max(spd / divisor, 9.5)
                    
                    if target == tostringPlayer and dist <= acc then
                        if AutoAbility() then return end
                        if SOFD and IsSlashesPending then 
                            IsSlashesPending = false 
                            StartSlashesParry() 
                        end
                        if cooldownProtection() then return end
                        if not SlashesActive then StarX.Parry() end
                        Parried = true
                    end
                    
                    local t = tick()
                    repeat RunService.PreSimulation:Wait() until tick() - t >= 1 or not Parried
                    Parried = false
                end
            end)
        else
            local con = Connections_Manager["Auto Parry"]
            if con then 
                con:Disconnect() 
                Connections_Manager["Auto Parry"] = nil 
                print("[ Debug ] Auto Parry Disabled") 
            end
        end
  end
})
mainTab.create_description_toggle({
  name = "Auto Spam",
  description = "Spam Automatically",
  flag = "pr",
  enabled = true,
  section = "left",
  callback = function(state)
        Config.as = state
        if state then
            if not Connections_Manager["SpamHandler"] then
                Connections_Manager["SpamHandler"] = RunService.PreSimulation:Connect(function(deltaTime)
                    local Ball = StarX.FetchBall()
                    if not Ball or not Ball:FindFirstChild("zoomies") then 
                        Spamming = false 
                        return 
                    end
                    
                    local Root = Character and Character:FindFirstChild("HumanoidRootPart")
                    if not Root then 
                        Spamming = false 
                        return 
                    end
                    
                    if not Closest_Entity or not Closest_Entity.PrimaryPart then 
                        Spamming = false 
                        return 
                    end
                    
                    local Ping = ServerStatsItem["Data Ping"]:GetValue()
                    Ping = Ping > 200 and Ping * 1.35 or (Ping > 150 and Ping * 1.1 or Ping)
                    
                    local FPS = 1 / deltaTime
                    local AdjustRate = math.max((math.max(Ping, 150) / 150) * (60 / FPS), 0.7)
                    local BallVel = Ball.AssemblyLinearVelocity.Magnitude
                    local SpamDist = math.max((AdjustRate * 10) + math.min(BallVel / 6, 95), 17)
                    
                    local RootPos = Root.Position
                    local BallPos = Ball.Position
                    local TargetPos = Closest_Entity.PrimaryPart.Position
                    
                    local DistToBall = (RootPos - BallPos).Magnitude
                    local DistToTarget = (RootPos - TargetPos).Magnitude
                    
                    if DistToBall > SpamDist * 0.77 or DistToTarget > SpamDist then
                        Spamming = false
                        return
                    end
                    
                    Spamming = Parries > 1
                    if Spamming then StarX.Parry() end
                end)
            end
        else
            if Connections_Manager["SpamHandler"] then
                Connections_Manager["SpamHandler"]:Disconnect()
                Connections_Manager["SpamHandler"] = nil
            end
            Spamming = false
        end
  end
})
mainTab.create_description_toggle({
  name = "Visualizer",
  description = "Visualize Parry Range",
  flag = "pr",
  enabled = true,
  section = "left",
  callback = function(state)
        Config.v = state
        if state then
            print("[ Debug ] Visualizer Enabled")
            visualizerEnabled = true
            Connections_Manager["Visualizer"] = RunService.RenderStepped:Connect(function()
                if not visualizerEnabled then
                    return
                end
                
                local char = Player.Character or Player.CharacterAdded:Wait()
                local primaryPart = char and char.PrimaryPart
                local ball = StarX.FetchBall()
                
                if not (primaryPart and ball) then
                    visualizer.Size = Vector3.zero
                    return
                end
                
                local t = tick() % 5 / 5
                local color = Color3.fromHSV(t, 1, 1)
                local target = ball:GetAttribute("target")
                local isTargetingPlayer = target == LocalPlayer.Name
                local velocity = (ball and ball.Velocity.Magnitude) or 0
                local radius = Spamming and 35 or math.clamp((velocity / 2.4) + 10, 15, 200)
                
                visualizer.Size = Vector3.new(radius, radius, radius)
                visualizer.CFrame = primaryPart.CFrame
                visualizer.Color = Spamming and color or (isTargetingPlayer and Color3.fromRGB(255, 0, 0)) or Color3.fromRGB(255, 255, 255)
            end)
        else
            print("[ Debug ] Visualizer Disabled")
            visualizerEnabled = false
            if Connections_Manager["Visualizer"] then
                Connections_Manager["Visualizer"]:Disconnect()
                Connections_Manager["Visualizer"] = nil
            end
            visualizer.Size = Vector3.zero
        end
  end
})
mainTab.create_dropdown({
  name = "Curve Position",
  flag = "porn",
  section = "left",
  option = "Straight",
  options = {"Custom", "Random", "Straight", "Up", "Backwards", "Right", "Left"},
  callback = function(value)
         Config.cp = value 
        Selected_Parry_Type = value 
  end
})
visualTab.create_title({ name = "auto things", section = "left" })
visualTab.create_description_toggle({
  name = "Slash Of Fury",
  description = "Parry Exactly 35x On Activate",
  flag = "pr",
  enabled = true,
  section = "left",
  callback = function(state)
        Config.sof = state
        SOFD = state
  end})
visualTab.create_dropdown({
  name = "Slash Of Fury Mode",
  flag = "po",
  section = "left",
  option = "Blatant",
  options = {"Legit", "Blatant"},
  callback = function(value)
        Config.sofm = value 
        mode = value 
  end
})
visualTab.create_description_toggle({
  name = "Singularity",
  description = "Stop Parrying On Singularity",
  flag = "pwerrr",
  enabled = true,
  section = "left",
    Callback = function(state)
        Config.s = state
        SingularityD = state
  end})
  visualTab.create_description_toggle({
  name = "Aero Dynamic Slash",
  description = "Delay Parrying For A While Until Complete",
  flag = "pwerrrr",
  enabled = true,
  section = "left",
    Callback = function(state)
  end})
  visualTab.create_description_toggle({
  name = "Infinity",
  description = "Stop Parrying On Infinity",
  flag = "pwerrrrr",
  enabled = true,
  section = "left",
    Callback = function(state)
        Config.i = state
        InfinityD = state
  end})
  visualTab.create_description_toggle({
  name = "Time Hole",
  description = "Stop Parrying On Time Hole (?)",
  flag = "pweerr",
  enabled = true,
  section = "left",
    Callback = function(state)
        Config.th = state
        TimeHoleD = state
  end})
  visualTab.create_description_toggle({
  name = "Phantom",
  description = "Prevent Early Parry (?)",
  flag = "pweeerr",
  enabled = true,
  section = "left",
    Callback = function(state)
        Config.p = state
        PhantomD = state
  end})
  visualTab.create_description_toggle({
  name = "Cd Protect",
  description = "If Miss Parry Will Use Ability",
  flag = "pwerr",
  enabled = true,
  section = "left",
    Callback = function(state)
        Config.cdp = state
        CDP = state
  end})