--====================================================
-- 🌋 CAO Hub - Mt. Daun | FINAL
-- by CAO — ✨ Made by CAO ✨
--====================================================

--======== Branding (popup + banner) ========--
local StarterGui = game:GetService("StarterGui")
pcall(function()
    StarterGui:SetCore("SendNotification", {
        Title = "CAO Hub",
        Text = "✨ Made by CAO ✨",
        Duration = 5
    })
end)

do
    local gui = Instance.new("ScreenGui")
    gui.Name = "CAO_Banner"
    gui.ResetOnSpawn = false
    gui.Parent = game.CoreGui
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0,250,0,50)
    lbl.Position = UDim2.new(0.5,-125,0.05,0)
    lbl.BackgroundTransparency = 0.3
    lbl.BackgroundColor3 = Color3.fromRGB(20,20,20)
    lbl.TextColor3 = Color3.fromRGB(255,215,0)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextScaled = true
    lbl.Text = "✨ Made by CAO ✨"
    lbl.Parent = gui
    local c = Instance.new("UICorner", lbl) c.CornerRadius = UDim.new(0,12)
    task.delay(5, function() if gui then gui:Destroy() end end)
end

--======== Services & Vars ========--
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")

local plr = Players.LocalPlayer
local char = plr.Character or plr.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart")

-- Mt. Daun place id (utama). Jika dev punya sub-place, tambahkan ke list ini.
local SUPPORTED_PLACES = {
    [7946839417] = true,
}

--======== File-system wrapper (Delta/some executors) ========--
local HAS_FS = (typeof(writefile)=="function" and typeof(readfile)=="function" and typeof(isfile)=="function")
local RAM_SLOTS = { slots = {} } -- fallback in-memory bila FS tidak tersedia
local SAVE_FILE = "CAOHub_MtDaun_Slots.json"

local function LoadAllSlots()
    if HAS_FS and isfile(SAVE_FILE) then
        local ok, data = pcall(readfile, SAVE_FILE)
        if ok and data then
            local ok2, decoded = pcall(HttpService.JSONDecode, HttpService, data)
            if ok2 and decoded then return decoded end
        end
    end
    return RAM_SLOTS -- fallback RAM
end

local function SaveAllSlots(data)
    if HAS_FS then
        local ok, encoded = pcall(HttpService.JSONEncode, HttpService, data)
        if ok then
            pcall(writefile, SAVE_FILE, encoded)
            return true
        end
    end
    -- fallback to RAM only
    RAM_SLOTS = data
    pcall(function() StarterGui:SetCore("SendNotification",{Title="CAO Hub",Text="Saved (session only: FS not available)",Duration=4}) end)
    return false
end

local function SavePath(path, slot, name)
    local data = LoadAllSlots()
    data.slots[tostring(slot)] = { name = name or ("Slot "..slot), path = path }
    SaveAllSlots(data)
    pcall(function()
        StarterGui:SetCore("SendNotification",{Title="CAO Hub",Text="Saved to "..data.slots[tostring(slot)].name.." ✅",Duration=3})
    end)
end

local function LoadPath(slot)
    local data = LoadAllSlots()
    local s = data.slots[tostring(slot)]
    if s then return s.path, s.name end
    return nil, nil
end

local function RenameSlot(slot, newName)
    local data = LoadAllSlots()
    if data.slots[tostring(slot)] then
        data.slots[tostring(slot)].name = newName
        SaveAllSlots(data)
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
    local data = LoadAllSlots()
    if data.slots[tostring(slot)] then
        data.slots[tostring(slot)] = nil
        SaveAllSlots(data)
        pcall(function()
            StarterGui:SetCore("SendNotification",{Title="CAO Hub",Text="Slot "..slot.." cleared 🗑️",Duration=3})
        end)
    end
end

local function GetSlotName(slot)
    local data = LoadAllSlots()
    local s = data.slots[tostring(slot)]
    return s and s.name or ("Slot "..slot)
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

--======== Scanner (cari checkpoint candidates) ========--
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

--======== Auto climb ========--
local function asVector3Maybe(v)
    if typeof(v) == "Vector3" then return v end
    if typeof(v) == "Instance" and v:IsA("BasePart") then return v.Position end
    if typeof(v) == "table" and v.X and v.Y and v.Z then return Vector3.new(v.X, v.Y, v.Z) end
    return nil
end

local function AutoClimb(points)
    for i,pt in ipairs(points) do
        local pos = asVector3Maybe(pt)
        if pos then
            safeTeleport(pos + Vector3.new(0,5,0))
            task.wait(0.5)
        end
    end
    pcall(function()
        StarterGui:SetCore("SendNotification",{Title="CAO Hub",Text="Summit Reached ✅",Duration=3})
    end)
end

--======== Manual record (distance-based sampling) ========--
local recording = false
local recordPath = {}
local lastRecorded = nil
local MIN_DIST = 20

RunService.Heartbeat:Connect(function()
    if recording and hrp then
        local pos = hrp.Position
        if not lastRecorded or (pos - lastRecorded).Magnitude >= MIN_DIST then
            table.insert(recordPath, {X=pos.X, Y=pos.Y, Z=pos.Z})
            lastRecorded = pos
        end
    end
end)

--======== GUI ========--
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

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "CAOHub"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = game.CoreGui

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0,300,0,330)
MainFrame.Position = UDim2.new(0.06,0,0.25,0)
MainFrame.BackgroundColor3 = Color3.fromRGB(20,20,20)
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui
local mfC = Instance.new("UICorner", MainFrame) mfC.CornerRadius = UDim.new(0,12)

local Header = Instance.new("TextLabel")
Header.Size = UDim2.new(1,0,0,40)
Header.BackgroundColor3 = Color3.fromRGB(35,35,35)
Header.Text = "🌋 CAO Hub - Mt. Daun"
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
TabFrame.Size = UDim2.new(0,90,1,-40)
TabFrame.Position = UDim2.new(0,0,0,40)
TabFrame.BackgroundColor3 = Color3.fromRGB(25,25,25)
TabFrame.Parent = MainFrame

local ContentFrame = Instance.new("Frame")
ContentFrame.Size = UDim2.new(1,-90,1,-40)
ContentFrame.Position = UDim2.new(0,90,0,40)
ContentFrame.BackgroundColor3 = Color3.fromRGB(30,30,30)
ContentFrame.Parent = MainFrame

local function clearContent()
    for _,ch in ipairs(ContentFrame:GetChildren()) do
        if ch:IsA("GuiObject") then ch:Destroy() end
    end
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

------ Tab: Mt. Daun ------
local function buildMtDaunTab()
    local n1, n2, n3 = GetSlotName(1), GetSlotName(2), GetSlotName(3)

    makeButton(ContentFrame,"Auto Scan & Climb",1,function()
        local cps = scanCheckpoints()
        if #cps > 0 then
            AutoClimb(cps)
        else
            pcall(function()
                StarterGui:SetCore("SendNotification",{Title="CAO Hub",Text="No checkpoints found ❌",Duration=3})
            end)
        end
    end)

    makeButton(ContentFrame,"Start / Stop Record",2,function()
        recording = not recording
        if recording then
            recordPath = {}
            lastRecorded = nil
            pcall(function() StarterGui:SetCore("SendNotification",{Title="CAO Hub",Text="Recording Started 🎥",Duration=3}) end)
        else
            if #recordPath == 0 then
                pcall(function() StarterGui:SetCore("SendNotification",{Title="CAO Hub",Text="No points recorded ❌",Duration=3}) end)
            else
                pcall(function() StarterGui:SetCore("SendNotification",{Title="CAO Hub",Text="Recording Stopped ("..tostring(#recordPath).." pts)",Duration=3}) end)
            end
        end
    end)

    makeButton(ContentFrame,"Replay Current/Loaded Path",3,function()
        local path = (#recordPath > 0) and recordPath or nil
        if not path then
            local saved,_ = LoadPath(1) -- coba default slot 1 kalau ga ada path aktif
            path = saved
        end
        if path and #path > 0 then
            AutoClimb(path)
        else
            pcall(function() StarterGui:SetCore("SendNotification",{Title="CAO Hub",Text="No path to replay ❌",Duration=3}) end)
        end
    end)

    -- Save/Load 3 Slot
    makeButton(ContentFrame,"Save to "..n1,4,function()
        if #recordPath > 0 then SavePath(recordPath,1,n1) else pcall(function()
            StarterGui:SetCore("SendNotification",{Title="CAO Hub",Text="Record path first ❌",Duration=3}) end)
        end
        clearContent(); buildMtDaunTab()
    end)
    makeButton(ContentFrame,"Save to "..n2,5,function()
        if #recordPath > 0 then SavePath(recordPath,2,n2) else pcall(function()
            StarterGui:SetCore("SendNotification",{Title="CAO Hub",Text="Record path first ❌",Duration=3}) end)
        end
        clearContent(); buildMtDaunTab()
    end)
    makeButton(ContentFrame,"Save to "..n3,6,function()
        if #recordPath > 0 then SavePath(recordPath,3,n3) else pcall(function()
            StarterGui:SetCore("SendNotification",{Title="CAO Hub",Text="Record path first ❌",Duration=3}) end)
        end
        clearContent(); buildMtDaunTab()
    end)

    makeButton(ContentFrame,"Load & Replay "..n1,7,function()
        local saved,name = LoadPath(1)
        if saved then pcall(function() StarterGui:SetCore("SendNotification",{Title="CAO Hub",Text="Loaded "..name.." ✅",Duration=3}) end); AutoClimb(saved)
        else pcall(function() StarterGui:SetCore("SendNotification",{Title="CAO Hub",Text=n1.." empty ❌",Duration=3}) end) end
    end)
    makeButton(ContentFrame,"Load & Replay "..n2,8,function()
        local saved,name = LoadPath(2)
        if saved then pcall(function() StarterGui:SetCore("SendNotification",{Title="CAO Hub",Text="Loaded "..name.." ✅",Duration=3}) end); AutoClimb(saved)
        else pcall(function() StarterGui:SetCore("SendNotification",{Title="CAO Hub",Text=n2.." empty ❌",Duration=3}) end) end
    end)
    makeButton(ContentFrame,"Load & Replay "..n3,9,function()
        local saved,name = LoadPath(3)
        if saved then pcall(function() StarterGui:SetCore("SendNotification",{Title="CAO Hub",Text="Loaded "..name.." ✅",Duration=3}) end); AutoClimb(saved)
        else pcall(function() StarterGui:SetCore("SendNotification",{Title="CAO Hub",Text=n3.." empty ❌",Duration=3}) end) end
    end)
end

------ Tab: Manage Slots ------
local function makeRenameBox(slot, yOrder)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1,-20,0,35)
    frame.Position = UDim2.new(0,10,0,(yOrder-1)*45+10)
    frame.BackgroundColor3 = Color3.fromRGB(45,45,45)
    frame.Parent = ContentFrame
    local fc = Instance.new("UICorner", frame) fc.CornerRadius = UDim.new(0,8)

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1,-110,1,-10)
    box.Position = UDim2.new(0,10,0,5)
    box.BackgroundColor3 = Color3.fromRGB(60,60,60)
    box.TextColor3 = Color3.fromRGB(255,255,255)
    box.PlaceholderText = "Rename "..GetSlotName(slot)
    box.Font = Enum.Font.Gotham
    box.TextSize = 14
    box.Parent = frame
    local bc = Instance.new("UICorner", box) bc.CornerRadius = UDim.new(0,6)

    local saveBtn = Instance.new("TextButton")
    saveBtn.Size = UDim2.new(0,90,1,-10)
    saveBtn.Position = UDim2.new(1,-95,0,5)
    saveBtn.BackgroundColor3 = Color3.fromRGB(75,75,75)
    saveBtn.TextColor3 = Color3.fromRGB(255,255,255)
    saveBtn.Font = Enum.Font.GothamBold
    saveBtn.TextSize = 14
    saveBtn.Text = "Save"
    saveBtn.Parent = frame
    local sc = Instance.new("UICorner", saveBtn) sc.CornerRadius = UDim.new(0,6)

    saveBtn.MouseButton1Click:Connect(function()
        local txt = (box.Text or ""):gsub("^%s+",""):gsub("%s+$","")
        if txt ~= "" then
            RenameSlot(slot, txt)
            clearContent()
            buildManageTab()
        end
    end)
end

function buildManageTab()
    makeButton(ContentFrame, "View Slot 1: "..GetSlotName(1), 1, function()
        local d = LoadAllSlots().slots["1"]
        local msg = d and ("Name: "..d.name..", Points: "..#(d.path or {})) or "Empty ❌"
        pcall(function() StarterGui:SetCore("SendNotification",{Title="Slot 1",Text=msg,Duration=3}) end)
    end)
    makeRenameBox(1,2)
    makeButton(ContentFrame, "Delete Slot 1", 3, function() DeleteSlot(1); clearContent(); buildManageTab() end)

    makeButton(ContentFrame, "View Slot 2: "..GetSlotName(2), 4, function()
        local d = LoadAllSlots().slots["2"]
        local msg = d and ("Name: "..d.name..", Points: "..#(d.path or {})) or "Empty ❌"
        pcall(function() StarterGui:SetCore("SendNotification",{Title="Slot 2",Text=msg,Duration=3}) end)
    end)
    makeRenameBox(2,5)
    makeButton(ContentFrame, "Delete Slot 2", 6, function() DeleteSlot(2); clearContent(); buildManageTab() end)

    makeButton(ContentFrame, "View Slot 3: "..GetSlotName(3), 7, function()
        local d = LoadAllSlots().slots["3"]
        local msg = d and ("Name: "..d.name..", Points: "..#(d.path or {})) or "Empty ❌"
        pcall(function() StarterGui:SetCore("SendNotification",{Title="Slot 3",Text=msg,Duration=3}) end)
    end)
    makeRenameBox(3,8)
    makeButton(ContentFrame, "Delete Slot 3", 9, function() DeleteSlot(3); clearContent(); buildManageTab() end)
end

-- tabs
makeTab("Mt.Daun",1, buildMtDaunTab)
makeTab("Manage",2, buildManageTab)
makeTab("About",3, function()
    makeButton(ContentFrame,"CAO Hub v1.0",1,function() end).Text = "Made with ❤️ by CAO"
    makeButton(ContentFrame,"Supported",2,function() end).Text = "Mt. Daun 🌋 (PlaceId: 7946839417)"
    local fs = HAS_FS and "Yes" or "No"
    makeButton(ContentFrame,"File Save",3,function() end).Text = "FS Available: "..fs
end)

-- default open
buildMtDaunTab()

-- Minimize
local minimized = false
MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
        TabFrame.Visible = false
        ContentFrame.Visible = false
        MainFrame.Size = UDim2.new(0,300,0,40)
        MinBtn.Text = "+"
    else
        TabFrame.Visible = true
        ContentFrame.Visible = true
        MainFrame.Size = UDim2.new(0,300,0,330)
        MinBtn.Text = "-"
    end
end)

-- Only notify if not Mt. Daun
if not SUPPORTED_PLACES[game.PlaceId] then
    pcall(function()
        StarterGui:SetCore("SendNotification",{Title="CAO Hub",Text="Not Mt. Daun map (features may not apply)",Duration=5})
    end)
end
