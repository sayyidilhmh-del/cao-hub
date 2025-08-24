--====================================================
-- 🌋 CAO Hub - Mt. Daun | BomBom Update (FINAL)
-- Base by CAO —  Made by CAO  | Update by BomBom
--====================================================

--======== Branding (popup + banner) ========--
local StarterGui = game:GetService("StarterGui")
pcall(function()
    StarterGui:SetCore("SendNotification", {
        Title = "CAO Hub",
        Text  = " Made by CAO ",
        Duration = 4
    })
    StarterGui:SetCore("SendNotification", {
        Title = "BomBom Update",
        Text  = "Made by BomBom",
        Duration = 5
    })
end)

do
    local gui = Instance.new("ScreenGui")
    gui.Name = "CAO_Banner"
    gui.ResetOnSpawn = false
    gui.Parent = game.CoreGui
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0,260,0,44)
    lbl.Position = UDim2.new(0.5,-130,0.05,0)
    lbl.BackgroundTransparency = 0.2
    lbl.BackgroundColor3 = Color3.fromRGB(18,18,18)
    lbl.TextColor3 = Color3.fromRGB(255,215,0)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextScaled = true
    lbl.Text = " Made by BomBom "
    lbl.Parent = gui
    local c = Instance.new("UICorner", lbl) c.CornerRadius = UDim.new(0,12)
    task.delay(5, function() if gui then gui:Destroy() end end)
end

--======== Services & Vars ========--
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local UIS = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local plr = Players.LocalPlayer
local char = plr.Character or plr.CharacterAdded:Wait()
local hum  = char:WaitForChild("Humanoid")
local hrp  = char:WaitForChild("HumanoidRootPart")

-- Mt. Daun place id
local SUPPORTED_PLACES = { [7946839417] = true }

--======== File-system wrapper (Delta/some executors) ========--
local HAS_FS = (typeof(writefile)=="function" and typeof(readfile)=="function" and typeof(isfile)=="function")
local SAVE_FILE = "CAOHub_MtDaun_Data.json" -- gabungan slots + teleports

-- default data structure
local DEFAULT_DATA = {
    slots = {},          -- path slots: ["1"]={name=..., path={...}}, etc.
    teleports = {}       -- saved teleports: array of {name=..., pos={X=,Y=,Z=}}
}

local MEMORY_DATA = HttpService:JSONDecode(HttpService:JSONEncode(DEFAULT_DATA)) -- deep copy

local function DeepCopy(tbl)
    return HttpService:JSONDecode(HttpService:JSONEncode(tbl))
end

local function LoadAllData()
    if HAS_FS and isfile(SAVE_FILE) then
        local ok, data = pcall(readfile, SAVE_FILE)
        if ok and data then
            local ok2, decoded = pcall(HttpService.JSONDecode, HttpService, data)
            if ok2 and decoded then
                -- merge missing fields
                for k,v in pairs(DEFAULT_DATA) do
                    if decoded[k]==nil then decoded[k] = DeepCopy(v) end
                end
                return decoded
            end
        end
    end
    return DeepCopy(MEMORY_DATA)
end

local function SaveAllData(data)
    if HAS_FS then
        local ok, encoded = pcall(HttpService.JSONEncode, HttpService, data)
        if ok then
            pcall(writefile, SAVE_FILE, encoded)
            return true
        end
    end
    -- fallback memory only
    MEMORY_DATA = DeepCopy(data)
    pcall(function()
        StarterGui:SetCore("SendNotification",{Title="CAO Hub",Text="Saved (session only: FS not available)",Duration=4})
    end)
    return false
end

--======== Original: Slot helpers (path save/load) ========--
local function SavePath(path, slot, name)
    local data = LoadAllData()
    data.slots[tostring(slot)] = { name = name or ("Slot "..slot), path = path }
    SaveAllData(data)
    pcall(function()
        StarterGui:SetCore("SendNotification",{Title="CAO Hub",Text="Saved to "..data.slots[tostring(slot)].name.." ✅",Duration=3})
    end)
end

local function LoadPath(slot)
    local data = LoadAllData()
    local s = data.slots[tostring(slot)]
    if s then return s.path, s.name end
    return nil, nil
end

local function RenameSlot(slot, newName)
    local data = LoadAllData()
    if data.slots[tostring(slot)] then
        data.slots[tostring(slot)].name = newName
        SaveAllData(data)
        pcall(function()
            StarterGui:SetCore("SendNotification",{Title="CAO Hub",Text="Slot "..slot.." renamed to "..newName.." ✅",Duration=3})
        end)
    else
        pcall(function()
            StarterGui:SetCore("SendNotification",{Title="CAO Hub",Text="Slot "..slot.." empty ❌",Duration=3})
        end)
    end
end

local function DeleteSlot(slot)
    local data = LoadAllData()
    if data.slots[tostring(slot)] then
        data.slots[tostring(slot)] = nil
        SaveAllData(data)
        pcall(function()
            StarterGui:SetCore("SendNotification",{Title="CAO Hub",Text="Slot "..slot.." cleared 🗑️",Duration=3})
        end)
    end
end

local function GetSlotName(slot)
    local data = LoadAllData()
    local s = data.slots[tostring(slot)]
    return s and s.name or ("Slot "..slot)
end

--======== Teleport persistence ========--
local function GetTeleports()
    local data = LoadAllData()
    return data.teleports or {}
end

local function AddTeleport(name, vec3)
    local data = LoadAllData()
    data.teleports = data.teleports or {}
    table.insert(data.teleports, { name = name or ("Loc "..tostring(#data.teleports+1)), pos = {X=vec3.X, Y=vec3.Y, Z=vec3.Z} })
    SaveAllData(data)
    pcall(function() StarterGui:SetCore("SendNotification",{Title="Teleport",Text="Saved \""..(name or "Loc").."\" ✅",Duration=3}) end)
end

local function RemoveTeleport(index)
    local data = LoadAllData()
    local tp = data.teleports or {}
    if tp[index] then
        local nm = tp[index].name or ("Loc "..index)
        table.remove(tp, index)
        SaveAllData(data)
        pcall(function() StarterGui:SetCore("SendNotification",{Title="Teleport",Text="Deleted \""..nm.."\" 🗑️",Duration=3}) end)
    end
end

--======== Movement core ========--
local function humanDelay()
    task.wait(math.random(10,30)/100) -- 0.10s–0.30s
end

local function safeTeleport(targetPos)
    local dist = (hrp.Position - targetPos).Magnitude
    if dist > 60 then
        local steps = math.clamp(math.floor(dist/30), 3, 120)
        for i=1, steps do
            humanDelay()
            hrp.CFrame = hrp.CFrame:Lerp(CFrame.new(targetPos), i/steps)
            RunService.Heartbeat:Wait()
        end
    else
        humanDelay()
        hrp.CFrame = CFrame.new(targetPos)
    end
end

--======== Scanner (checkpoints) ========--
local CANDIDATE_NAMES = {"checkpoint","flag","summit","trigger","stage"}
local function isCandidate(part)
    local name = string.lower(part.Name)
    for _,kw in ipairs(CANDIDATE_NAMES) do
        if string.find(name, kw) then return true end
    end
    if part.Transparency == 1 and part.CanCollide == false then
        return true
    end
    return false
end

local function scanCheckpoints()
    local found = {}
    for _,obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") then
            local ok = false
            local s, r = pcall(isCandidate, obj)
            ok = (s and r) or false
            if ok then table.insert(found, obj) end
        end
    end
    table.sort(found, function(a,b) return a.Position.Y < b.Position.Y end)
    return found
end

--======== Auto climb & record/replay (original) ========--
local function asVector3Maybe(v)
    if typeof(v) == "Vector3" then return v end
    if typeof(v) == "Instance" and v:IsA("BasePart") then return v.Position end
    if typeof(v) == "table" and v.X and v.Y and v.Z then return Vector3.new(v.X, v.Y, v.Z) end
    return nil
end

local function AutoClimb(points)
    for _,pt in ipairs(points) do
        local pos = asVector3Maybe(pt)
        if pos then
            safeTeleport(pos + Vector3.new(0,5,0))
            task.wait(0.35)
        end
    end
    pcall(function()
        StarterGui:SetCore("SendNotification",{Title="CAO Hub",Text="Summit Reached ✅",Duration=3})
    end)
end

-- distance-based recorder (lightweight)
local recording = false
local recordPath = {}
local lastRecorded = nil
local MIN_DIST = 20

if _G.__cao_record_conn then _G.__cao_record_conn:Disconnect() end
_G.__cao_record_conn = RunService.Heartbeat:Connect(function()
    if recording and hrp then
        local pos = hrp.Position
        if not lastRecorded or (pos - lastRecorded).Magnitude >= MIN_DIST then
            table.insert(recordPath, {X=pos.X, Y=pos.Y, Z=pos.Z})
            lastRecorded = pos
        end
    end
end)

--======== Quality-of-life: Movement tweaks (Main tab) ========--
local normalSpeed, normalJump = 16, 50
local maxSafeSpeed, maxSafeJump = 32, 75

local noclipEnabled, infJumpEnabled, antiFall = false, false, false
local noclipConn, infJumpConn, fallConn

local function setNoclip(state)
    noclipEnabled = state
    if state then
        if noclipConn then noclipConn:Disconnect() end
        noclipConn = RunService.Stepped:Connect(function()
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = false end
            end
        end)
    else
        if noclipConn then noclipConn:Disconnect() end
    end
end

local function setInfJump(state)
    infJumpEnabled = state
    if state then
        if infJumpConn then infJumpConn:Disconnect() end
        infJumpConn = UIS.JumpRequest:Connect(function()
            if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
        end)
    else
        if infJumpConn then infJumpConn:Disconnect() end
    end
end

local function setAntiFall(state)
    antiFall = state
    if fallConn then fallConn:Disconnect() fallConn=nil end
    if state then
        fallConn = hum.StateChanged:Connect(function(_, new)
            if new == Enum.HumanoidStateType.Freefall then
                pcall(function()
                    hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown,false)
                    hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll,false)
                end)
            end
        end)
    else
        pcall(function()
            hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown,true)
            hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll,true)
        end)
    end
end

--======== ESP (distance-limited, colored by distance) ========--
local espEnabled = false
local espDistance = 100
local espFolder = Instance.new("Folder", game.CoreGui)
espFolder.Name = "CAO_ESP"

local function ensureESPFor(pl)
    if pl == plr then return end
    if not pl.Character or not pl.Character:FindFirstChild("Head") then return end
    if espFolder:FindFirstChild(pl.Name) then return end

    local bb = Instance.new("BillboardGui")
    bb.Name = pl.Name
    bb.Adornee = pl.Character.Head
    bb.Size = UDim2.new(0,110,0,24)
    bb.AlwaysOnTop = true
    bb.StudsOffset = Vector3.new(0,3,0)
    bb.Parent = espFolder

    local tl = Instance.new("TextLabel", bb)
    tl.Size = UDim2.new(1,0,1,0)
    tl.BackgroundTransparency = 1
    tl.Font = Enum.Font.GothamBold
    tl.TextScaled = true
    tl.TextStrokeTransparency = 0.5
    tl.TextColor3 = Color3.fromRGB(255,0,0)
    tl.Text = pl.Name
end

local function removeESPFor(pl)
    local n = espFolder:FindFirstChild(pl.Name)
    if n then n:Destroy() end
end

if _G.__cao_esp_loop then _G.__cao_esp_loop:Disconnect() end
_G.__cao_esp_loop = RunService.RenderStepped:Connect(function()
    if not espEnabled then
        espFolder:ClearAllChildren()
        return
    end
    if not (plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")) then return end
    local myPos = plr.Character.HumanoidRootPart.Position

    for _,p in ipairs(Players:GetPlayers()) do
        if p ~= plr and p.Character and p.Character:FindFirstChild("HumanoidRootPart") and p.Character:FindFirstChild("Head") then
            local dist = (p.Character.HumanoidRootPart.Position - myPos).Magnitude
            local node = espFolder:FindFirstChild(p.Name)
            if dist <= espDistance then
                if not node then ensureESPFor(p); node = espFolder:FindFirstChild(p.Name) end
                if node then
                    node.Enabled = true
                    local tl = node:FindFirstChildOfClass("TextLabel")
                    if tl then
                        if dist < 35 then tl.TextColor3 = Color3.fromRGB(0,255,0)       -- dekat
                        elseif dist < 70 then tl.TextColor3 = Color3.fromRGB(255,255,0) -- sedang
                        else tl.TextColor3 = Color3.fromRGB(255,80,80) end              -- jauh
                        tl.Text = string.format("%s [%.0f]", p.Name, dist)
                    end
                    node.Adornee = p.Character.Head
                end
            else
                if node then node.Enabled = false end
            end
        else
            removeESPFor(p)
        end
    end
end)

Players.PlayerRemoving:Connect(function(p) removeESPFor(p) end)
Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function() if espEnabled then task.wait(1) ensureESPFor(p) end end)
end)

--======== GUI ========--
if game.CoreGui:FindFirstChild("CAOHub_BomBom") then game.CoreGui.CAOHub_BomBom:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "CAOHub_BomBom"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = game.CoreGui

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0,340,0,380)
MainFrame.Position = UDim2.new(0.06,0,0.2,0)
MainFrame.BackgroundColor3 = Color3.fromRGB(20,20,20)
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui
local mfC = Instance.new("UICorner", MainFrame) mfC.CornerRadius = UDim.new(0,12)

local Header = Instance.new("TextLabel")
Header.Size = UDim2.new(1,0,0,40)
Header.BackgroundColor3 = Color3.fromRGB(35,35,35)
Header.Text = "🌋 CAO Hub — BomBom Update"
Header.Font = Enum.Font.GothamBold
Header.TextColor3 = Color3.fromRGB(255,255,255)
Header.TextSize = 16
Header.Parent = MainFrame
local hc = Instance.new("UICorner", Header) hc.CornerRadius = UDim.new(0,12)

local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0,40,1,0)
MinBtn.Position = UDim2.new(1,-45,0,0)
MinBtn.BackgroundTransparency = 1
MinBtn.Text = "-"
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextColor3 = Color3.fromRGB(255,255,255)
MinBtn.TextSize = 18
MinBtn.Parent = Header

local TabFrame = Instance.new("Frame")
TabFrame.Size = UDim2.new(0,110,1,-40)
TabFrame.Position = UDim2.new(0,0,0,40)
TabFrame.BackgroundColor3 = Color3.fromRGB(25,25,25)
TabFrame.Parent = MainFrame

local ContentFrame = Instance.new("Frame")
ContentFrame.Size = UDim2.new(1,-110,1,-40)
ContentFrame.Position = UDim2.new(0,110,0,40)
ContentFrame.BackgroundColor3 = Color3.fromRGB(30,30,30)
ContentFrame.Parent = MainFrame

local function clearContent()
    for _,ch in ipairs(ContentFrame:GetChildren()) do
        if ch:IsA("GuiObject") then ch:Destroy() end
    end
end

local function makeButton(parent, text, yOrder, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1,-20,0,35)
    btn.Position = UDim2.new(0,10,0,(yOrder-1)*45+10)
    btn.BackgroundColor3 = Color3.fromRGB(50,50,50)
    btn.TextColor3 = Color3.fromRGB(255,255,255)
    btn.Text = text
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 14
    btn.Parent = parent
    local c = Instance.new("UICorner", btn) c.CornerRadius = UDim.new(0,8)
    btn.MouseEnter:Connect(function() btn.BackgroundColor3 = Color3.fromRGB(80,80,80) end)
    btn.MouseLeave:Connect(function() btn.BackgroundColor3 = Color3.fromRGB(50,50,50) end)
    btn.MouseButton1Click:Connect(callback)
    return btn
end

local function makeBox(parent, placeholder, yOrder, defaultText, onCommit)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1,-20,0,35)
    frame.Position = UDim2.new(0,10,0,(yOrder-1)*45+10)
    frame.BackgroundColor3 = Color3.fromRGB(45,45,45)
    frame.Parent = parent
    local fc = Instance.new("UICorner", frame) fc.CornerRadius = UDim.new(0,8)

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1,-10,1,-10)
    box.Position = UDim2.new(0,5,0,5)
    box.BackgroundColor3 = Color3.fromRGB(60,60,60)
    box.TextColor3 = Color3.fromRGB(255,255,255)
    box.PlaceholderText = placeholder
    box.Text = defaultText or ""
    box.Font = Enum.Font.Gotham
    box.TextSize = 14
    box.Parent = frame
    local bc = Instance.new("UICorner", box) bc.CornerRadius = UDim.new(0,6)

    box.FocusLost:Connect(function(enter)
        if enter and onCommit then onCommit(box.Text) end
    end)
    return box
end

local function makeTab(text, order, onClick)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1,0,0,35)
    b.Position = UDim2.new(0,0,0,(order-1)*40+5)
    b.BackgroundColor3 = Color3.fromRGB(40,40,40)
    b.TextColor3 = Color3.fromRGB(255,255,255)
    b.Text = text
    b.Font = Enum.Font.GothamBold
    b.TextSize = 14
    b.Parent = TabFrame
    local bc = Instance.new("UICorner", b) bc.CornerRadius = UDim.new(0,8)
    b.MouseEnter:Connect(function() b.BackgroundColor3 = Color3.fromRGB(70,70,70) end)
    b.MouseLeave:Connect(function() b.BackgroundColor3 = Color3.fromRGB(40,40,40) end)
    b.MouseButton1Click:Connect(function()
        clearContent()
        onClick()
    end)
    return b
end

--======== Tabs ========--
-- 1) Main: speed/jump/noclip/inf jump/anti-fall
local function buildMainTab()
    local curWS = hum and hum.WalkSpeed or 16
    local curJP = hum and hum.JumpPower or 50

    makeButton(ContentFrame,"Speed: "..math.floor(curWS).." (tap to reset)",1,function()
        if hum then hum.WalkSpeed = normalSpeed end
        pcall(function() StarterGui:SetCore("SendNotification",{Title="Speed",Text="Reset to "..normalSpeed,Duration=2}) end)
        clearContent(); buildMainTab()
    end)
    makeBox(ContentFrame,"Set WalkSpeed (warn > "..maxSafeSpeed..")",2,"",function(txt)
        local v=tonumber(txt)
        if v then
            if hum then hum.WalkSpeed=v end
            if v>maxSafeSpeed then pcall(function() StarterGui:SetCore("SendNotification",{Title="⚠️ Warning",Text="Speed tinggi: "..v,Duration=4}) end) end
            clearContent(); buildMainTab()
        end
    end)

    makeButton(ContentFrame,"JumpPower: "..math.floor(curJP).." (tap to reset)",3,function()
        if hum then hum.JumpPower = normalJump end
        pcall(function() StarterGui:SetCore("SendNotification",{Title="Jump",Text="Reset to "..normalJump,Duration=2}) end)
        clearContent(); buildMainTab()
    end)
    makeBox(ContentFrame,"Set JumpPower (warn > "..maxSafeJump..")",4,"",function(txt)
        local v=tonumber(txt)
        if v then
            if hum then hum.JumpPower=v end
            if v>maxSafeJump then pcall(function() StarterGui:SetCore("SendNotification",{Title="⚠️ Warning",Text="Jump tinggi: "..v,Duration=4}) end) end
            clearContent(); buildMainTab()
        end
    end)

    makeButton(ContentFrame,"Noclip: "..tostring(noclipEnabled),5,function()
        setNoclip(not noclipEnabled); clearContent(); buildMainTab()
    end)
    makeButton(ContentFrame,"Infinity Jump (Mobile): "..tostring(infJumpEnabled),6,function()
        setInfJump(not infJumpEnabled); clearContent(); buildMainTab()
    end)
    makeButton(ContentFrame,"Anti Fall Damage: "..tostring(antiFall),7,function()
        setAntiFall(not antiFall); clearContent(); buildMainTab()
    end)
end

-- 2) Replay: original record/replay + auto-scan + slots
local function buildReplayTab()
    makeButton(ContentFrame,"Auto Scan & Climb",1,function()
        local cps = scanCheckpoints()
        if #cps>0 then AutoClimb(cps)
        else pcall(function() StarterGui:SetCore("SendNotification",{Title="CAO Hub",Text="No checkpoints found ❌",Duration=3}) end) end
    end)

    makeButton(ContentFrame, recording and "Stop Record" or "Start Record",2,function()
        recording = not recording
        if recording then
            recordPath = {}
            lastRecorded = nil
            pcall(function() StarterGui:SetCore("SendNotification",{Title="Record",Text="Recording Started 🎥",Duration=3}) end)
        else
            local n = #recordPath
            pcall(function() StarterGui:SetCore("SendNotification",{Title="Record",Text="Stopped ("..n.." pts)",Duration=3}) end)
        end
        clearContent(); buildReplayTab()
    end)

    makeButton(ContentFrame,"Replay Current/Loaded Path",3,function()
        local path = (#recordPath>0) and recordPath or nil
        if not path then
            local saved,_ = LoadPath(1)
            path = saved
        end
        if path and #path>0 then AutoClimb(path)
        else pcall(function() StarterGui:SetCore("SendNotification",{Title="Replay",Text="No path to replay ❌",Duration=3}) end) end
    end)

    local n1,n2,n3 = GetSlotName(1),GetSlotName(2),GetSlotName(3)
    makeButton(ContentFrame,"Save to "..n1,4,function()
        if #recordPath>0 then SavePath(recordPath,1,n1)
        else pcall(function() StarterGui:SetCore("SendNotification",{Title="Save",Text="Record path first ❌",Duration=3}) end) end
        clearContent(); buildReplayTab()
    end)
    makeButton(ContentFrame,"Save to "..n2,5,function()
        if #recordPath>0 then SavePath(recordPath,2,n2)
        else pcall(function() StarterGui:SetCore("SendNotification",{Title="Save",Text="Record path first ❌",Duration=3}) end) end
        clearContent(); buildReplayTab()
    end)
    makeButton(ContentFrame,"Save to "..n3,6,function()
        if #recordPath>0 then SavePath(recordPath,3,n3)
        else pcall(function() StarterGui:SetCore("SendNotification",{Title="Save",Text="Record path first ❌",Duration=3}) end) end
        clearContent(); buildReplayTab()
    end)

    makeButton(ContentFrame,"Load & Replay "..n1,7,function()
        local saved,name = LoadPath(1)
        if saved then pcall(function() StarterGui:SetCore("SendNotification",{Title="Load",Text="Loaded "..name.." ✅",Duration=3}) end); AutoClimb(saved)
        else pcall(function() StarterGui:SetCore("SendNotification",{Title="Load",Text=n1.." empty ❌",Duration=3}) end) end
    end)
    makeButton(ContentFrame,"Load & Replay "..n2,8,function()
        local saved,name = LoadPath(2)
        if saved then pcall(function() StarterGui:SetCore("SendNotification",{Title="Load",Text="Loaded "..name.." ✅",Duration=3}) end); AutoClimb(saved)
        else pcall(function() StarterGui:SetCore("SendNotification",{Title="Load",Text=n2.." empty ❌",Duration=3}) end) end
    end)
    makeButton(ContentFrame,"Load & Replay "..n3,9,function()
        local saved,name = LoadPath(3)
        if saved then pcall(function() StarterGui:SetCore("SendNotification",{Title="Load",Text="Loaded "..name.." ✅",Duration=3}) end); AutoClimb(saved)
        else pcall(function() StarterGui:SetCore("SendNotification",{Title="Load",Text=n3.." empty ❌",Duration=3}) end) end
    end)
end

-- 3) Teleport: saved custom coords (persistent)
local function buildTeleportTab()
    local y = 1
    -- Input boxes
    local nameBox = makeBox(ContentFrame,"Name (mis: Spawn Atas)",y,"",nil) y=y+1
    local xBox    = makeBox(ContentFrame,"X",y,"",nil) y=y+1
    local yBox    = makeBox(ContentFrame,"Y",y,"",nil) y=y+1
    local zBox    = makeBox(ContentFrame,"Z",y,"",nil) y=y+1

    makeButton(ContentFrame,"➕ Save Teleport",y,function()
        local n = (nameBox.Text or ""):gsub("^%s+",""):gsub("%s+$","")
        local vx = tonumber(xBox.Text) or hrp.Position.X
        local vy = tonumber(yBox.Text) or hrp.Position.Y
        local vz = tonumber(zBox.Text) or hrp.Position.Z
        if n=="" then n = ("Loc "..os.time()) end
        AddTeleport(n, Vector3.new(vx,vy,vz))
        clearContent(); buildTeleportTab()
    end); y=y+1

    -- List saved teleports
    local tps = GetTeleports()
    if #tps==0 then
        makeButton(ContentFrame,"(Belum ada teleport tersimpan)",y,function() end).AutoButtonColor=false
    else
        for i,tp in ipairs(tps) do
            local label = string.format("• %s  (%.0f, %.0f, %.0f)", tp.name, tp.pos.X, tp.pos.Y, tp.pos.Z)
            makeButton(ContentFrame,label,y,function()
                safeTeleport(Vector3.new(tp.pos.X,tp.pos.Y,tp.pos.Z))
            end)
            y=y+1
            makeButton(ContentFrame,"   🗑️ Hapus \""..tp.name.."\"",y,function()
                RemoveTeleport(i)
                clearContent(); buildTeleportTab()
            end)
            y=y+1
        end
    end
end

-- 4) ESP: toggle + distance input
local function buildESPTab()
    makeButton(ContentFrame,"ESP: "..tostring(espEnabled),1,function()
        espEnabled = not espEnabled
        pcall(function() StarterGui:SetCore("SendNotification",{Title="ESP",Text=espEnabled and "ON" or "OFF",Duration=3}) end)
        clearContent(); buildESPTab()
    end)
    makeBox(ContentFrame,"ESP Max Distance",2,tostring(espDistance),function(txt)
        local v=tonumber(txt); if v then espDistance=math.clamp(v,10,1000) end
        clearContent(); buildESPTab()
    end)
end

-- 5) Manage: slot rename/delete + info
local function buildManageTab()
    local function slotInfo(idx, yOrder)
        makeButton(ContentFrame,"View Slot "..idx..": "..GetSlotName(idx),yOrder,function()
            local d = LoadAllData().slots[tostring(idx)]
            local msg = d and ("Name: "..d.name..", Points: "..#(d.path or {})) or "Empty ❌"
            pcall(function() StarterGui:SetCore("SendNotification",{Title="Slot "..idx,Text=msg,Duration=3}) end)
        end)
        makeBox(ContentFrame,"Rename "..GetSlotName(idx),yOrder+1,"",function(txt)
            local t = (txt or ""):gsub("^%s+",""):gsub("%s+$","")
            if t~="" then RenameSlot(idx, t); clearContent(); buildManageTab() end
        end)
        makeButton(ContentFrame,"Delete Slot "..idx,yOrder+2,function() DeleteSlot(idx); clearContent(); buildManageTab() end)
    end
    slotInfo(1,1)
    slotInfo(2,4)
    slotInfo(3,7)
end

-- 6) About
local function buildAboutTab()
    makeButton(ContentFrame,"CAO Hub v1.0 + BomBom Update",1,function() end).AutoButtonColor=false
    makeButton(ContentFrame,"Supported: Mt. Daun 🌋 (PlaceId: 7946839417)",2,function() end).AutoButtonColor=false
    local fs = HAS_FS and "Yes" or "No"
    makeButton(ContentFrame,"File Save Available: "..fs,3,function() end).AutoButtonColor=false
    makeButton(ContentFrame,"Thanks: CAO • BomBom",4,function() end).AutoButtonColor=false
end

-- Register tabs (urutan yang mudah diakses)
makeTab("Main",1, buildMainTab)
makeTab("Replay",2, buildReplayTab)
makeTab("Teleport",3, buildTeleportTab)
makeTab("ESP",4, buildESPTab)
makeTab("Manage",5, buildManageTab)
makeTab("About",6, buildAboutTab)

-- default open
buildMainTab()

-- Minimize
local minimized = false
MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
        TabFrame.Visible = false
        ContentFrame.Visible = false
        MainFrame.Size = UDim2.new(0,340,0,40)
        MinBtn.Text = "+"
    else
        TabFrame.Visible = true
        ContentFrame.Visible = true
        MainFrame.Size = UDim2.new(0,340,0,380)
        MinBtn.Text = "-"
    end
end)

-- Only notify if not Mt. Daun
if not SUPPORTED_PLACES[game.PlaceId] then
    pcall(function()
        StarterGui:SetCore("SendNotification",{Title="CAO Hub",Text="Not Mt. Daun map (features may not apply)",Duration=5})
    end)
end
