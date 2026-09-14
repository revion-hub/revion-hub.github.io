local request = (syn and syn.request) or (http and http.request) or http_request	
local HttpService = game:GetService("HttpService")
local TextInFile = "Revion"
local Discord_Invite = "S68ANu2MFe"
local FolderName = "Enhanced Software"
local Folder2 = "/Discord Invites"
local FileName = "/Enhanced Software.gg" 
if not isfolder(FolderName..Folder2) then
	makefolder(FolderName..Folder2)
end
if not isfile(FolderName..Folder2..FileName) then
	if request then
		request({
			Url = 'http://127.0.0.1:6463/rpc?v=1',
			Method = 'POST',
			Headers = {
				['Content-Type'] = 'application/json',
				Origin = 'https://discord.com'
			},
			Body = HttpService:JSONEncode({
				cmd = 'INVITE_BROWSER',
				nonce = HttpService:GenerateGUID(false),
				args = {code = Discord_Invite}
			})
		})
	end
	writefile(FolderName..Folder2..FileName, TextInFile)
end

--[[
    ██████╗ ███████╗██╗   ██╗██╗ ██████╗ ██╗   █╗
    ██╔══██╗██╔════╝██║   ██║██║██╔═══██╗████╗  ██║
    ██████╔╝█████╗  █║   █║████║   █║████╗ █║
    ██╔══██╗██╔══╝  ██╗ █╔╝██║██║   ██║██║╚██╗██║
    ██║  ██║███████╗ ████╔ ██║╚██████╔╝██║ ████║
    ╚═  ╚═╝╚══════╝  ╚═══╝  ═╝ ═════╝ ╚═╝  ╚═══╝
             dingus  ·  WindUI  ·  Revion
]]

local WindUI = loadstring(game:HttpGet(
	"https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"
	))()

--====================================================================
-- SERVICES & GUARDS
--====================================================================
local Players            = game:GetService("Players")
local RunService         = game:GetService("RunService")
local Workspace          = game:GetService("Workspace")
local Lighting           = game:GetService("Lighting")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local TweenService       = game:GetService("TweenService")
local TeleportService    = game:GetService("TeleportService")
local CoreGui            = game:GetService("CoreGui")
local UIS                = game:GetService("UserInputService")
local VirtualUser        = game:GetService("VirtualUser")
local StarterGui         = game:GetService("StarterGui")

local LocalPlayer        = Players.LocalPlayer
local Mouse              = LocalPlayer:GetMouse()

local PLACE_ID           = 13924946576  -- dingus

if game.PlaceId ~= PLACE_ID then
	StarterGui:SetCore("SendNotification", {
		Title    = "Revion Hub",
		Text     = "You are NOT in dingus.\nJoin dingus to use this script.",
		Duration = 6,
	})
end

--====================================================================
-- SETTINGS / STATE
--====================================================================
local Settings = {
	-- ESP
	ESP             = false,
	ESPNames        = true,
	ESPRoles        = true,
	ESPDistance     = true,
	Chams           = true,
	Tracers         = false,
	TracerHunterOnly= true,
	MaxDistance     = 900,
	FillTransparency= 0.55,
	ShowHunters     = true,
	ShowHiders      = true,
	ShowDead        = true,
	ShowUnknown     = true,
	NPCESP          = false,
	TaskESP         = false,

	-- Movement
	SpeedMultiplier = 0,     -- MOVE_SPEED_MODIFIER (the move-boost snippet)
	WalkSpeed       = 16,
	JumpPower       = 50,
	InfiniteJump    = false,
	Noclip          = false,
	Fly             = false,
	FlySpeed        = 90,

	-- Teleport
	CtrlClickTP     = false,
	TPMode          = "Instant",

	-- World / client
	FOV             = 80,
	Fullbright      = false,
	RemoveFog       = false,
	AntiBlind       = true,
	AntiAFK         = true,

	-- Tasks
	InstantInteract = false,
	InteractRange   = 14,

	-- Hub
	NotifyOnLoad    = true,
	AutoLoadConfig  = true,
}

local RoleColors = {
	Hunter  = Color3.fromRGB(255, 60,  60),
	Hider   = Color3.fromRGB(0,   255, 140),
	Dead    = Color3.fromRGB(150, 150, 150),
	Unknown = Color3.fromRGB(255, 255, 255),
	NPC     = Color3.fromRGB(255, 170, 0),
	Task    = Color3.fromRGB(180, 120, 255),
}

local Conns = {}
local function bind(signal, fn)
	local c = signal:Connect(fn)
	Conns[#Conns + 1] = c
	return c
end

--====================================================================
-- HELPERS
--====================================================================
local function getChar()
	return LocalPlayer.Character
end

local function getLocals()
	local char = getChar()
	if not char then return nil, nil, nil end
	local hum  = char:FindFirstChildOfClass("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart")
	return char, hum, root
end

local function notify(title, content, icon)
	WindUI:Notify({ Title = title, Content = content, Icon = icon, Duration = 4 })
end

local function attachPart(inst)
	if not inst then return nil end
	if inst:IsA("BasePart") then return inst end
	if inst:IsA("Model") then
		return inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart")
	end
	return nil
end

--====================================================================
-- ROLE DETECTION (attributes -> leaderstats -> team -> tools)
--====================================================================
local manualRoles = {}

local HUNTER_KEYS = { "hunter", "seeker", "it", "killer", "chaser", "murderer" }
local HIDER_KEYS  = { "hider", "survivor", "innocent", "civilian", "runner", "prey" }
local DEAD_KEYS   = { "dead", "ghost", "spectator", "corpse", "eliminated", "out" }

local function matchRoleString(raw)
	if raw == nil then return nil end
	local n = tostring(raw):lower()
	for _, k in ipairs(HUNTER_KEYS) do if n:find(k, 1, true) then return "Hunter" end end
	for _, k in ipairs(DEAD_KEYS)   do if n:find(k, 1, true) then return "Dead"   end end
	for _, k in ipairs(HIDER_KEYS)  do if n:find(k, 1, true) then return "Hider"  end end
	return nil
end

local function scanForRole(inst)
	if not inst then return nil end

	for _, attr in ipairs({ "Role", "role", "Team", "team", "Job", "job", "Side", "side", "Alignment", "State", "Status" }) do
		local ok, v = pcall(function() return inst:GetAttribute(attr) end)
		if ok and v ~= nil then
			local r = matchRoleString(v)
			if r then return r end
		end
	end

	for _, attr in ipairs({ "IsHunter", "Hunter", "IsSeeker", "Seeker" }) do
		local ok, v = pcall(function() return inst:GetAttribute(attr) end)
		if ok and v == true then return "Hunter" end
	end
	for _, attr in ipairs({ "IsDead", "Dead", "IsEliminated" }) do
		local ok, v = pcall(function() return inst:GetAttribute(attr) end)
		if ok and v == true then return "Dead" end
	end
	for _, attr in ipairs({ "IsHider", "Hider", "IsInnocent" }) do
		local ok, v = pcall(function() return inst:GetAttribute(attr) end)
		if ok and v == true then return "Hider" end
	end
	return nil
end

local function getRole(plr)
	if plr == LocalPlayer then return nil end
	if manualRoles[plr] then return manualRoles[plr] end

	local char = plr.Character

	local r = scanForRole(plr) or scanForRole(char)
	if char then
		r = r or scanForRole(char:FindFirstChildOfClass("Humanoid"))
	end
	if r then return r end

	-- humanoid state / death
	if char then
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health <= 0 then return "Dead" end
	end

	-- leaderstats values
	local ls = plr:FindFirstChild("leaderstats")
	if ls then
		for _, v in ipairs(ls:GetChildren()) do
			local n = v.Name:lower()
			if n:find("role") or n:find("team") or n:find("status") or n:find("state") then
				local r2 = matchRoleString(v.Value) or scanForRole(v)
				if r2 then return r2 end
			end
		end
	end

	-- team
	if plr.Team then
		local r3 = matchRoleString(plr.Team.Name)
		if r3 then return r3 end
	end

	-- tools (hunter usually carries a weapon / gun)
	local function toolScan(container)
		if not container then return nil end
		for _, t in ipairs(container:GetChildren()) do
			if t:IsA("Tool") then
				local n = t.Name:lower()
				for _, k in ipairs({ "gun", "pistol", "revolver", "knife", "bat", "sword", "weapon",
					"tranq", "blaster", "shotgun", "hunter" }) do
					if n:find(k, 1, true) then return "Hunter" end
				end
			end
		end
		return nil
	end
	if char then r = toolScan(char) end
	r = r or toolScan(plr:FindFirstChild("Backpack"))
	if r then return r end

	return "Unknown"
end

local function shouldShow(role)
	if role == "Hunter"  then return Settings.ShowHunters end
	if role == "Hider"   then return Settings.ShowHiders  end
	if role == "Dead"    then return Settings.ShowDead    end
	return Settings.ShowUnknown
end

local function getNearestByRole(role, maxDist)
	local _, _, root = getLocals()
	if not root then return nil, nil end
	local best, bestD = nil, maxDist or math.huge
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LocalPlayer and (role == nil or getRole(p) == role) then
			local c = p.Character
			local t = c and c:FindFirstChild("HumanoidRootPart")
			if t then
				local d = (root.Position - t.Position).Magnitude
				if d < bestD then best, bestD = p, d end
			end
		end
	end
	return best, bestD
end

local function getNearestNPC(maxDist)
	local _, _, root = getLocals()
	if not root then return nil end
	local best, bestD = nil, maxDist or math.huge
	for _, v in ipairs(Workspace:GetDescendants()) do
		if v:IsA("Model") and v:FindFirstChildOfClass("Humanoid") then
			if not Players:GetPlayerFromCharacter(v) then
				local part = attachPart(v)
				if part then
					local d = (part.Position - root.Position).Magnitude
					if d < bestD then best, bestD = v, d end
				end
			end
		end
	end
	return best
end

--====================================================================
-- ESP ENGINE
--====================================================================
local espObjects = {}
local tracers    = {}

local hasDrawing = false
pcall(function() hasDrawing = (typeof(Drawing) == "table" or typeof(Drawing) == "userdata") end)

local function makeHighlight(adornee, color, fillTransparency)
	local hl = Instance.new("Highlight")
	hl.Name = "RevionESP"
	hl.Adornee = adornee
	hl.FillColor = color
	hl.FillTransparency = fillTransparency or 0.55
	hl.OutlineColor = color
	hl.OutlineTransparency = 0
	pcall(function() hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop end)
	hl.Parent = adornee
	return hl
end

local function makeTag(part, color)
	local bbg = Instance.new("BillboardGui")
	bbg.Name = "RevionTag"
	bbg.Size = UDim2.new(0, 220, 0, 56)
	bbg.StudsOffset = Vector3.new(0, 2.9, 0)
	bbg.AlwaysOnTop = true
	bbg.MaxDistance = Settings.MaxDistance
	bbg.Adornee = part
	bbg.Parent = part

	local arrow = Instance.new("TextLabel")
	arrow.Size = UDim2.new(1, 0, 0, 26)
	arrow.Position = UDim2.new(0, 0, 0, -26)
	arrow.BackgroundTransparency = 1
	arrow.Text = "▼"
	arrow.TextColor3 = RoleColors.Hunter
	arrow.TextStrokeTransparency = 0
	arrow.Font = Enum.Font.GothamBold
	arrow.TextSize = 26
	arrow.Visible = false
	arrow.Parent = bbg

	local roleLabel = Instance.new("TextLabel")
	roleLabel.Size = UDim2.new(1, 0, 0, 26)
	roleLabel.BackgroundTransparency = 1
	roleLabel.TextColor3 = color
	roleLabel.Font = Enum.Font.GothamBold
	roleLabel.TextSize = 15
	roleLabel.TextStrokeTransparency = 0
	roleLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	roleLabel.Text = ""
	roleLabel.Parent = bbg

	local infoLabel = Instance.new("TextLabel")
	infoLabel.Size = UDim2.new(1, 0, 0, 24)
	infoLabel.Position = UDim2.new(0, 0, 0, 26)
	infoLabel.BackgroundTransparency = 1
	infoLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	infoLabel.Font = Enum.Font.Gotham
	infoLabel.TextSize = 13
	infoLabel.TextStrokeTransparency = 0.4
	infoLabel.Text = ""
	infoLabel.Parent = bbg

	return { gui = bbg, role = roleLabel, info = infoLabel, arrow = arrow }
end

local function makeSimpleTag(part, text, color)
	local bbg = Instance.new("BillboardGui")
	bbg.Name = "RevionTag"
	bbg.Size = UDim2.new(0, 140, 0, 22)
	bbg.StudsOffset = Vector3.new(0, 1.8, 0)
	bbg.AlwaysOnTop = true
	bbg.MaxDistance = Settings.MaxDistance
	bbg.Adornee = part
	bbg.Parent = part

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = text
	lbl.TextColor3 = color
	lbl.Font = Enum.Font.GothamBold
	lbl.TextSize = 13
	lbl.TextStrokeTransparency = 0.2
	lbl.Parent = bbg

	return { gui = bbg, label = lbl }
end

local function destroyESPEntry(obj)
	if not obj then return end
	if obj.highlight then obj.highlight:Destroy() end
	if obj.tag and obj.tag.gui then obj.tag.gui:Destroy() end
	if obj.tag and obj.tag.label then obj.tag.label:Destroy() end
end

local function removeESP(plr)
	local obj = espObjects[plr]
	if obj then
		destroyESPEntry(obj)
		espObjects[plr] = nil
	end
	local line = tracers[plr]
	if line then line.Visible = false end
end

local function clearESP()
	for plr, obj in pairs(espObjects) do
		destroyESPEntry(obj)
		espObjects[plr] = nil
	end
	for _, line in pairs(tracers) do line.Visible = false end
end

local function getTracer(plr)
	if not hasDrawing then return nil end
	local line = tracers[plr]
	if line then return line end
	local ok, newLine = pcall(function() return Drawing.new("Line") end)
	if ok and newLine then
		newLine.Thickness = 1.6
		newLine.Transparency = 0.35
		newLine.Visible = false
		tracers[plr] = newLine
		return newLine
	end
	return nil
end

local function updatePlayerESP(plr, role, dist)
	local char = plr.Character
	if not char then removeESP(plr) return end

	local color = RoleColors[role] or RoleColors.Unknown
	local obj = espObjects[plr]

	if not obj or obj.char ~= char then
		removeESP(plr)
		obj = { char = char }
		obj.highlight = makeHighlight(char, color, Settings.FillTransparency)
		local head = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
		if Settings.ESPNames and head then
			obj.tag = makeTag(head, color)
		end
		espObjects[plr] = obj
	else
		obj.highlight.Enabled = Settings.Chams
		obj.highlight.FillColor = color
		obj.highlight.OutlineColor = color
		obj.highlight.FillTransparency = Settings.FillTransparency
	end

	local tag = obj.tag
	if tag then
		tag.gui.MaxDistance = Settings.MaxDistance
		tag.gui.Enabled = Settings.ESPNames
		tag.role.TextColor3 = color
		tag.role.Text = Settings.ESPRoles and string.upper(role) or ""
		local bits = {}
		if Settings.ESPNames then bits[#bits + 1] = plr.DisplayName end
		if Settings.ESPDistance then bits[#bits + 1] = string.format("[%dm]", math.floor(dist)) end
		tag.info.Text = table.concat(bits, "  ")
		tag.arrow.Visible = (role == "Hunter") and Settings.TracerHunterOnly
	end
end

local function updateTracers()
	local cam = Workspace.CurrentCamera
	if not Settings.ESP or not Settings.Tracers or not hasDrawing or not cam then
		for _, line in pairs(tracers) do line.Visible = false end
		return
	end

	local vp = cam.ViewportSize
	local origin = Vector2.new(vp.X / 2, vp.Y)

	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LocalPlayer then
			local line = getTracer(plr)
			if line then
				local role = getRole(plr)
				local char = plr.Character
				local root = char and char:FindFirstChild("HumanoidRootPart")
				local visible = false
				if root and shouldShow(role) and (not Settings.TracerHunterOnly or role == "Hunter") then
					local sp, onScreen = cam:WorldToViewportPoint(root.Position)
					if onScreen then
						local c = RoleColors[role] or RoleColors.Unknown
						line.From = origin
						line.To = Vector2.new(sp.X, sp.Y)
						line.Color = c
						visible = true
					end
				end
				line.Visible = visible
			end
		end
	end
end

bind(RunService.Heartbeat, function()
	if not Settings.ESP then
		if next(espObjects) then clearESP() end
		return
	end

	local _, _, myRoot = getLocals()

	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LocalPlayer then
			local role = getRole(plr)
			local char = plr.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			local dist = 0
			if root and myRoot then
				dist = (root.Position - myRoot.Position).Magnitude
			end
			if char and root and shouldShow(role) and dist <= Settings.MaxDistance then
				updatePlayerESP(plr, role, dist)
			else
				removeESP(plr)
			end
		end
	end
end)

bind(RunService.RenderStepped, function()
	updateTracers()
end)

bind(Players.PlayerRemoving, function(plr)
	removeESP(plr)
	manualRoles[plr] = nil
	local line = tracers[plr]
	if line then
		pcall(function() line:Remove() end)
		pcall(function() line:Destroy() end)
		tracers[plr] = nil
	end
end)

--====================================================================
-- NPC ESP
--====================================================================
local npcESP = {}

local function clearNPCESP()
	for model, obj in pairs(npcESP) do
		destroyESPEntry(obj)
		npcESP[model] = nil
	end
end

local lastNPCScan = 0
local function updateNPCESP(now)
	if not Settings.NPCESP then
		if next(npcESP) then clearNPCESP() end
		return
	end

	for model, obj in pairs(npcESP) do
		if not model.Parent or not model:FindFirstChildOfClass("Humanoid") then
			destroyESPEntry(obj)
			npcESP[model] = nil
		end
	end

	if now - lastNPCScan < 4 then return end
	lastNPCScan = now

	for _, v in ipairs(Workspace:GetDescendants()) do
		if v:IsA("Model") and v:FindFirstChildOfClass("Humanoid")
			and not Players:GetPlayerFromCharacter(v) and not npcESP[v] then
			local hl = makeHighlight(v, RoleColors.NPC, 0.7)
			local part = attachPart(v)
			local tag = part and makeSimpleTag(part, "NPC", RoleColors.NPC) or nil
			npcESP[v] = { highlight = hl, tag = tag }
		end
	end
end

--====================================================================
-- PROMPT CACHE  (tasks / interactables)
--====================================================================
local promptCache   = {}
local lastPromptScan = 0

local function refreshPrompts(now, force)
	if not force and now - lastPromptScan < 2 then return end
	lastPromptScan = now
	local list = {}
	for _, d in ipairs(Workspace:GetDescendants()) do
		if d:IsA("ProximityPrompt") then list[#list + 1] = d end
	end
	promptCache = list
end

local taskESP = {}

local function clearTaskESP()
	for prompt, obj in pairs(taskESP) do
		destroyESPEntry(obj)
		taskESP[prompt] = nil
	end
end

local function updateTaskESP(now)
	if not Settings.TaskESP then
		if next(taskESP) then clearTaskESP() end
		return
	end

	for prompt, obj in pairs(taskESP) do
		if not prompt.Parent or not obj.adornee or not obj.adornee.Parent then
			destroyESPEntry(obj)
			taskESP[prompt] = nil
		end
	end

	refreshPrompts(now)

	for _, prompt in ipairs(promptCache) do
		if not taskESP[prompt] then
			local adornee = attachPart(prompt.Parent)
			if adornee then
				local hl = makeHighlight(adornee, RoleColors.Task, 0.5)
				local tag = makeSimpleTag(adornee, "TASK", RoleColors.Task)
				taskESP[prompt] = { highlight = hl, tag = tag, adornee = adornee }
			end
		end
	end
end

local function nearestTask()
	local _, _, root = getLocals()
	if not root then return nil end
	refreshPrompts(tick(), true)
	local best, bestD = nil, math.huge
	for _, prompt in ipairs(promptCache) do
		local part = attachPart(prompt.Parent)
		if part then
			local d = (part.Position - root.Position).Magnitude
			if d < bestD then best, bestD = part, d end
		end
	end
	return best
end

--====================================================================
-- INSTANT INTERACT  /  TASK AUTO
--====================================================================
local lastInteract = 0

local function interactAll()
	refreshPrompts(tick(), true)
	local _, _, root = getLocals()
	if not root then return 0 end
	local count = 0
	for _, prompt in ipairs(promptCache) do
		local part = attachPart(prompt.Parent)
		if part and (part.Position - root.Position).Magnitude <= Settings.InteractRange then
			pcall(function() prompt.HoldDuration = 0 end)
			pcall(function() prompt.RequiresLineOfSight = false end)
			pcall(function() fireproximityprompt(prompt) end)
			count += 1
		end
	end
	return count
end

local function instantInteractLoop(now)
	if not Settings.InstantInteract then return end
	if now - lastInteract < 0.15 then return end
	lastInteract = now
	interactAll()
end

--====================================================================
-- MOVEMENT  (Speed boost snippet, JumpPower, Noclip, Fly, InfJump)
--====================================================================
local MOVE_SPEED_MODIFIER = 0

local function applyMoveBoost(character, dt)
	if MOVE_SPEED_MODIFIER <= 0 then
		return
	end
	if not character then
		return
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		return
	end

	local moveDirection = humanoid.MoveDirection
	if moveDirection.Magnitude < 0.1 then
		return
	end

	-- Extra translation in the direction you're moving, based on your WalkSpeed
	local stepDistance = humanoid.WalkSpeed * MOVE_SPEED_MODIFIER * dt
	if stepDistance <= 0 then
		return
	end

	root.CFrame = root.CFrame + moveDirection * stepDistance
end

bind(RunService.RenderStepped, function(dt)
	MOVE_SPEED_MODIFIER = Settings.SpeedMultiplier
	applyMoveBoost(LocalPlayer.Character, dt)
end)

local function applyWalk()
	local _, hum = getLocals()
	if hum then hum.WalkSpeed = Settings.WalkSpeed end
end

local function applyJump()
	local _, hum = getLocals()
	if hum then
		pcall(function() hum.UseJumpPower = true end)
		hum.JumpPower = Settings.JumpPower
	end
end

bind(LocalPlayer.CharacterAdded, function()
	task.wait(0.25)
	applyWalk()
	applyJump()
end)

local function forceNoClip()
	local char = getChar()
	if not char then return end
	for _, part in ipairs(char:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CanCollide = false
		end
	end
end

bind(RunService.Heartbeat, function()
	local _, hum, root = getLocals()
	if not root then return end

	if Settings.Noclip then forceNoClip() end

	if Settings.InfiniteJump and hum and not hum.Sit then
		if root.AssemblyLinearVelocity.Y < 0 then
			hum:ChangeState(Enum.HumanoidStateType.Jumping)
			root.AssemblyLinearVelocity = Vector3.new(
				root.AssemblyLinearVelocity.X, 100, root.AssemblyLinearVelocity.Z)
		end
	end

	if Settings.Fly then
		local moveDir = Vector3.zero
		if UIS:IsKeyDown(Enum.KeyCode.W) then moveDir += Vector3.new(0, 0, -1) end
		if UIS:IsKeyDown(Enum.KeyCode.S) then moveDir += Vector3.new(0, 0, 1) end
		if UIS:IsKeyDown(Enum.KeyCode.A) then moveDir += Vector3.new(-1, 0, 0) end
		if UIS:IsKeyDown(Enum.KeyCode.D) then moveDir += Vector3.new(1, 0, 0) end
		if UIS:IsKeyDown(Enum.KeyCode.Space) then moveDir += Vector3.new(0, 1, 0) end
		if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then moveDir += Vector3.new(0, -1, 0) end
		if moveDir.Magnitude > 0 then
			root.AssemblyLinearVelocity = moveDir.Unit * Settings.FlySpeed
		else
			root.AssemblyLinearVelocity = Vector3.zero
		end
	end
end)

--====================================================================
-- CAMERA FOV / LIGHTING / ANTI-BLIND / FOG
--====================================================================
bind(RunService.RenderStepped, function()
	local cam = Workspace.CurrentCamera
	if cam and cam.FieldOfView ~= Settings.FOV then
		cam.FieldOfView = Settings.FOV
	end
end)

local originalLighting = {
	Brightness         = Lighting.Brightness,
	ClockTime          = Lighting.ClockTime,
	Ambient            = Lighting.Ambient,
	OutdoorAmbient     = Lighting.OutdoorAmbient,
	GlobalShadows      = Lighting.GlobalShadows,
	FogStart           = Lighting.FogStart,
	FogEnd             = Lighting.FogEnd,
	FogColor           = Lighting.FogColor,
	ExposureCompensation = Lighting.ExposureCompensation,
}

local function restoreLighting()
	Lighting.Brightness           = originalLighting.Brightness
	Lighting.ClockTime            = originalLighting.ClockTime
	Lighting.Ambient              = originalLighting.Ambient
	Lighting.OutdoorAmbient       = originalLighting.OutdoorAmbient
	Lighting.GlobalShadows        = originalLighting.GlobalShadows
	Lighting.FogStart             = originalLighting.FogStart
	Lighting.FogEnd               = originalLighting.FogEnd
	Lighting.FogColor             = originalLighting.FogColor
	Lighting.ExposureCompensation = originalLighting.ExposureCompensation
end

local function applyLighting()
	if Settings.Fullbright then
		Lighting.Brightness           = 3
		Lighting.ClockTime            = 14
		Lighting.Ambient              = Color3.fromRGB(178, 178, 178)
		Lighting.OutdoorAmbient       = Color3.fromRGB(178, 178, 178)
		Lighting.GlobalShadows        = false
		Lighting.ExposureCompensation = 0.2
	else
		Lighting.Brightness           = originalLighting.Brightness
		Lighting.ClockTime            = originalLighting.ClockTime
		Lighting.Ambient              = originalLighting.Ambient
		Lighting.OutdoorAmbient       = originalLighting.OutdoorAmbient
		Lighting.GlobalShadows        = originalLighting.GlobalShadows
		Lighting.ExposureCompensation = originalLighting.ExposureCompensation
	end

	if Settings.RemoveFog then
		Lighting.FogStart = 1e6
		Lighting.FogEnd   = 1e6
	else
		Lighting.FogStart = originalLighting.FogStart
		Lighting.FogEnd   = originalLighting.FogEnd
		Lighting.FogColor = originalLighting.FogColor
	end
end

local function antiBlind()
	if not Settings.AntiBlind then return end
	local targets = { Lighting, Workspace.CurrentCamera }
	for _, container in ipairs(targets) do
		if container then
			for _, fx in ipairs(container:GetChildren()) do
				if fx:IsA("BlurEffect") then
					fx.Size = 0
					fx.Enabled = false
				elseif fx:IsA("ColorCorrectionEffect") then
					fx.Contrast   = 0
					fx.Saturation = 0
					fx.Brightness = 0
					fx.TintColor  = Color3.new(1, 1, 1)
					fx.Enabled    = false
				elseif fx:IsA("DepthOfFieldEffect") then
					fx.Enabled = false
				end
			end
		end
	end
end

local lastWorldTick = 0
bind(RunService.Heartbeat, function(now)
	if now - lastWorldTick < 0.4 then return end
	lastWorldTick = now
	applyLighting()
	antiBlind()
	updateNPCESP(now)
	updateTaskESP(now)
	instantInteractLoop(now)
end)

--====================================================================
-- ANTI-AFK
--====================================================================
bind(LocalPlayer.Idled, function()
	if not Settings.AntiAFK then return end
	VirtualUser:CaptureController()
	VirtualUser:ClickButton2(Vector2.new())
end)

--====================================================================
-- TELEPORT  (CTRL + Click, shortcuts, saved position)
--====================================================================
local savedPosition = nil

local function teleportTo(position)
	local _, hum, root = getLocals()
	if not root then return end

	if Settings.Noclip then forceNoClip() end

	if Settings.TPMode == "Tween" then
		local dist = (root.Position - position).Magnitude
		local duration = math.clamp(dist / 90, 0.1, 2)
		local tween = TweenService:Create(root,
			TweenInfo.new(duration, Enum.EasingStyle.Linear),
			{ CFrame = CFrame.new(position) })
		tween:Play()
	else
		if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
		root.CFrame = CFrame.new(position)
	end
end

local function teleportToPlayer(plr)
	if not plr or not plr.Character then
		notify("Revion", "No target found.", "solar:danger-bold")
		return
	end
	local target = plr.Character:FindFirstChild("HumanoidRootPart")
	if not target then return end
	teleportTo((target.CFrame * CFrame.new(0, 2, 0)).Position)
	notify("Revion", "Teleported to " .. plr.DisplayName, "solar:map-point-wave-bold")
end

bind(UIS.InputBegan, function(input, gameProcessed)
	if gameProcessed then return end
	if not Settings.CtrlClickTP then return end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
	if UIS:GetFocusedTextBox() then return end
	if not (UIS:IsKeyDown(Enum.KeyCode.LeftControl) or UIS:IsKeyDown(Enum.KeyCode.RightControl)) then return end

	local _, _, root = getLocals()
	if not root then return end
	local hit = Mouse.Hit
	if hit then
		teleportTo(hit.Position + Vector3.new(0, 3, 0))
	end
end)

--====================================================================
-- MISC ACTIONS (reset, rejoin, server hop, unload)
--====================================================================
local function resetCharacter()
	local char, hum = getLocals()
	if char then
		pcall(function() char:BreakJoints() end)
		if hum then pcall(function() hum.Health = 0 end) end
	end
end

local function rejoinServer()
	pcall(function()
		TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
	end)
end

local function serverHop()
	local req = (syn and syn.request) or (http and http.request) or http_request
		or (fluxus and fluxus.request)
	if not req then
		notify("Revion", "Your executor has no request function.", "solar:danger-bold")
		return
	end

	local ok, res = pcall(function()
		return req({
			Url = string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100", PLACE_ID),
			Method = "GET",
		})
	end)

	if not ok or not res or not res.Body then
		notify("Revion", "Server list request failed.", "solar:danger-bold")
		return
	end

	local decoded = HttpService:JSONDecode(res.Body)
	local candidates = {}
	for _, server in ipairs(decoded.data or {}) do
		if server.id ~= game.JobId and (server.playing or 0) < (server.maxPlayers or 0) then
			candidates[#candidates + 1] = server.id
		end
	end

	if #candidates == 0 then
		notify("Revion", "No joinable servers found.", "solar:danger-bold")
		return
	end

	local jobId = candidates[math.random(1, #candidates)]
	notify("Revion", "Hopping servers...", "solar:planet-bold")
	pcall(function()
		TeleportService:TeleportToPlaceInstance(PLACE_ID, jobId, LocalPlayer)
	end)
end

local unloaded = false
local function unload()
	if unloaded then return end
	unloaded = true

	for _, c in ipairs(Conns) do
		pcall(function() c:Disconnect() end)
	end

	clearESP()
	clearNPCESP()
	clearTaskESP()

	for _, line in pairs(tracers) do
		pcall(function() line:Remove() end)
		pcall(function() line:Destroy() end)
	end
	tracers = {}

	local char, hum = getLocals()
	if char then
		for _, part in ipairs(char:GetDescendants()) do
			if part:IsA("BasePart") then part.CanCollide = true end
		end
	end
	if hum then
		hum.WalkSpeed = 16
		hum.JumpPower = 50
	end

	restoreLighting()

	pcall(function() Window:Destroy() end)
	pcall(function() Window:Close() end)
	pcall(function() WindUI:Destroy() end)

	notify("Revion", "Script unloaded. Re-execute to reload.", "solar:power-bold")
end

--====================================================================
-- WINDOW
--====================================================================
local Window = WindUI:CreateWindow({
	Title     = "Revion Hub · dingus",
	Icon      = "rbxassetid://135461141179064",
	Author    = "Revion",
	Theme     = "Dark",
	Folder    = "RevionHub",
	Size      = UDim2.fromOffset(620, 500),
	MinSize   = Vector2.new(580, 380),
	MaxSize   = Vector2.new(880, 580),
	ToggleKey = Enum.KeyCode.RightShift,
	HideSearchBar = false,
})

local MainTab     = Window:Tab({ Title = "Main",      Icon = "solar:home-2-bold" })
local VisionTab   = Window:Tab({ Title = "Visuals",   Icon = "solar:eye-bold" })
local TPTab       = Window:Tab({ Title = "Teleport",  Icon = "solar:map-point-wave-bold" })
local TaskTab     = Window:Tab({ Title = "Tasks",     Icon = "solar:clipboard-check-bold" })
local SettingsTab = Window:Tab({ Title = "Settings",  Icon = "solar:settings-bold" })

--====================================================================
-- UI: MAIN TAB
--====================================================================
MainTab:Toggle({
	Title    = "Player ESP",
	Desc     = "Role-coloured chams + tags on every player",
	Value    = false,
	Callback = function(v) Settings.ESP = v end,
})
MainTab:Space()

MainTab:Toggle({ Title = "Show Names",    Value = true,  Callback = function(v) Settings.ESPNames = v end })
MainTab:Toggle({ Title = "Show Roles",    Value = true,  Callback = function(v) Settings.ESPRoles = v end })
MainTab:Toggle({ Title = "Show Distance", Value = true,  Callback = function(v) Settings.ESPDistance = v end })
MainTab:Toggle({ Title = "Chams (Fill)",  Value = true,  Callback = function(v) Settings.Chams = v end })
MainTab:Space()

MainTab:Toggle({ Title = "Hunters (Red)",   Value = true, Callback = function(v) Settings.ShowHunters = v end })
MainTab:Toggle({ Title = "Hiders (Green)",  Value = true, Callback = function(v) Settings.ShowHiders = v end })
MainTab:Toggle({ Title = "Dead (Grey)",     Value = true, Callback = function(v) Settings.ShowDead = v end })
MainTab:Toggle({ Title = "Unknown (White)", Value = true, Callback = function(v) Settings.ShowUnknown = v end })
MainTab:Space()

MainTab:Slider({
	Title = "Speed Boost Multiplier",
	Desc  = "Extra movement in your move direction (0 = off)",
	Step  = 0.1,
	Value = { Min = 0, Max = 5, Default = 0 },
	Callback = function(v) Settings.SpeedMultiplier = v end,
})
MainTab:Slider({
	Title = "Walk Speed",
	Step  = 1,
	Value = { Min = 8, Max = 300, Default = 16 },
	Callback = function(v) Settings.WalkSpeed = v; applyWalk() end,
})
MainTab:Slider({
	Title = "Jump Power",
	Step  = 1,
	Value = { Min = 30, Max = 400, Default = 50 },
	Callback = function(v) Settings.JumpPower = v; applyJump() end,
})
MainTab:Slider({
	Title = "Fly Speed",
	Step  = 1,
	Value = { Min = 20, Max = 400, Default = 90 },
	Callback = function(v) Settings.FlySpeed = v end,
})
MainTab:Space()

MainTab:Toggle({ Title = "Infinite Jump", Value = false, Callback = function(v) Settings.InfiniteJump = v end })
MainTab:Toggle({ Title = "Noclip",        Value = false, Callback = function(v) Settings.Noclip = v end })
MainTab:Toggle({ Title = "Fly Mode",      Value = false, Callback = function(v) Settings.Fly = v end })
MainTab:Space()

MainTab:Toggle({
	Title    = "CTRL + Click Teleport",
	Desc     = "Hold CTRL and left-click to teleport there",
	Value    = false,
	Callback = function(v) Settings.CtrlClickTP = v end,
})
MainTab:Dropdown({
	Title  = "Teleport Style",
	Values = { "Instant", "Tween" },
	Value  = "Instant",
	Callback = function(v) Settings.TPMode = v end,
})
MainTab:Space()

MainTab:Button({
	Title    = "Mark Nearest Player As Hunter",
	Icon     = "solar:target-bold",
	Callback = function()
		local plr = getNearestByRole(nil, 5000)
		if plr then
			manualRoles[plr] = "Hunter"
			notify("Revion", plr.DisplayName .. " marked as Hunter.", "solar:target-bold")
		else
			notify("Revion", "No players found.", "solar:danger-bold")
		end
	end,
})
MainTab:Button({
	Title    = "Clear Manual Role Marks",
	Icon     = "solar:refresh-bold",
	Callback = function()
		table.clear(manualRoles)
		notify("Revion", "Manual marks cleared.", "solar:refresh-bold")
	end,
})

--====================================================================
-- UI: VISUALS TAB
--====================================================================
VisionTab:Slider({
	Title    = "ESP Max Distance",
	Step     = 50,
	Value    = { Min = 100, Max = 5000, Default = 900 },
	Callback = function(v) Settings.MaxDistance = v end,
})
VisionTab:Slider({
	Title = "ESP Fill Transparency",
	Step  = 0.05,
	Value = { Min = 0, Max = 1, Default = 0.55 },
	Callback = function(v) Settings.FillTransparency = v end,
})
VisionTab:Slider({
	Title    = "Camera FOV",
	Step     = 1,
	Value    = { Min = 40, Max = 140, Default = 80 },
	Callback = function(v) Settings.FOV = v end,
})
VisionTab:Space()

VisionTab:Toggle({ Title = "Tracers",              Desc = "Line from your screen to each player",
	Value = false, Callback = function(v) Settings.Tracers = v end })
VisionTab:Toggle({ Title = "Tracer: Hunter Only",  Value = true,
	Callback = function(v) Settings.TracerHunterOnly = v end })
VisionTab:Toggle({ Title = "Hunter Arrow Marker",  Desc = "Big ▼ over the hunter's head",
	Value = true, Callback = function(v) Settings.TracerHunterOnly = v end })
VisionTab:Space()

VisionTab:Toggle({ Title = "NPC ESP", Desc = "Highlight every NPC (great for blending in)",
	Value = false, Callback = function(v) Settings.NPCESP = v end })
VisionTab:Space()

VisionTab:Toggle({ Title = "Fullbright",  Value = false, Callback = function(v) Settings.Fullbright = v end })
VisionTab:Toggle({ Title = "Remove Fog",  Value = false, Callback = function(v) Settings.RemoveFog = v end })
VisionTab:Toggle({ Title = "Anti-Blind",  Desc = "Kills blur / colour-correction blindness effects",
	Value = true, Callback = function(v) Settings.AntiBlind = v end })
VisionTab:Space()

VisionTab:Button({
	Title    = "Clear All ESP Objects",
	Icon     = "solar:trash-bin-trash-bold",
	Callback = function()
		clearESP(); clearNPCESP(); clearTaskESP()
		notify("Revion", "Cleared all ESP objects.", "solar:trash-bin-trash-bold")
	end,
})

--====================================================================
-- UI: TELEPORT TAB
--====================================================================
TPTab:Toggle({
	Title    = "CTRL + Click Teleport",
	Desc     = "Hold CTRL and left-click anywhere",
	Value    = false,
	Callback = function(v) Settings.CtrlClickTP = v end,
})
TPTab:Dropdown({
	Title  = "Teleport Style",
	Values = { "Instant", "Tween" },
	Value  = "Instant",
	Callback = function(v) Settings.TPMode = v end,
})
TPTab:Space()

TPTab:Button({
	Title    = "Teleport To Hunter",
	Icon     = "solar:target-bold",
	Callback = function()
		local plr = getNearestByRole("Hunter", 5000)
		if plr then teleportToPlayer(plr)
		else notify("Revion", "No hunter detected — mark one manually in Main.", "solar:danger-bold") end
	end,
})
TPTab:Button({
	Title    = "Teleport To Nearest Hider",
	Icon     = "solar:user-bold",
	Callback = function()
		local plr = getNearestByRole("Hider", 5000)
		if plr then teleportToPlayer(plr)
		else notify("Revion", "No hider detected.", "solar:danger-bold") end
	end,
})
TPTab:Button({
	Title    = "Teleport To Nearest Player",
	Icon     = "solar:users-group-rounded-bold",
	Callback = function()
		local plr = getNearestByRole(nil, 5000)
		if plr then teleportToPlayer(plr)
		else notify("Revion", "Nobody to teleport to.", "solar:danger-bold") end
	end,
})
TPTab:Button({
	Title    = "Teleport To Random Player",
	Icon     = "solar:shuffle-bold",
	Callback = function()
		local list = {}
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= LocalPlayer and p.Character then list[#list + 1] = p end
		end
		if #list > 0 then teleportToPlayer(list[math.random(1, #list)])
		else notify("Revion", "Nobody to teleport to.", "solar:danger-bold") end
	end,
})
TPTab:Space()

TPTab:Button({
	Title    = "Save Current Position",
	Icon     = "solar:bookmark-bold",
	Callback = function()
		local _, _, root = getLocals()
		if root then
			savedPosition = root.Position
			notify("Revion", "Position saved.", "solar:bookmark-bold")
		end
	end,
})
TPTab:Button({
	Title    = "Return To Saved Position",
	Icon     = "solar:undo-left-bold",
	Callback = function()
		if savedPosition then teleportTo(savedPosition)
		else notify("Revion", "No saved position yet.", "solar:danger-bold") end
	end,
})

--====================================================================
-- UI: TASKS TAB
--====================================================================
TaskTab:Toggle({
	Title    = "Task ESP",
	Desc     = "Highlight every ProximityPrompt (tasks / interactables)",
	Value    = false,
	Callback = function(v) Settings.TaskESP = v end,
})
TaskTab:Toggle({
	Title    = "Instant Interact",
	Desc     = "Auto-fire nearby prompts (instant task completion)",
	Value    = false,
	Callback = function(v) Settings.InstantInteract = v end,
})
TaskTab:Slider({
	Title    = "Interact Range",
	Step     = 1,
	Value    = { Min = 5, Max = 60, Default = 14 },
	Callback = function(v) Settings.InteractRange = v end,
})
TaskTab:Space()

TaskTab:Button({
	Title    = "Interact With All Tasks In Range (Once)",
	Icon     = "solar:bolt-bold",
	Callback = function()
		local n = interactAll()
		notify("Revion", string.format("Fired %d prompt(s).", n), "solar:bolt-bold")
	end,
})
TaskTab:Button({
	Title    = "Teleport To Nearest Task",
	Icon     = "solar:map-arrow-square-bold",
	Callback = function()
		local part = nearestTask()
		if part then teleportTo((part.CFrame * CFrame.new(0, 3, 0)).Position)
		else notify("Revion", "No tasks found.", "solar:danger-bold") end
	end,
})
TaskTab:Button({
	Title    = "Teleport To Nearest NPC",
	Icon     = "solar:user-speak-bold",
	Callback = function()
		local npc = getNearestNPC(5000)
		local part = npc and attachPart(npc)
		if part then teleportTo((part.CFrame * CFrame.new(0, 3, 0)).Position)
		else notify("Revion", "No NPCs found.", "solar:danger-bold") end
	end,
})
TaskTab:Space()

TaskTab:Button({
	Title    = "Reset Character",
	Icon     = "solar:restart-bold",
	Callback = resetCharacter,
})

--====================================================================
-- UI: SETTINGS TAB
--====================================================================
SettingsTab:Keybind({
	Title    = "UI Toggle Key",
	Desc     = "Press to open / close the hub",
	Value    = "RightShift",
	Callback = function(k)
		pcall(function() Window:SetToggleKey(Enum.KeyCode[k]) end)
	end,
})
SettingsTab:Dropdown({
	Title  = "Theme",
	Values = { "Dark", "Light", "Rose", "Plant", "Indigo", "Sky", "Violet", "Amber" },
	Value  = "Dark",
	Callback = function(theme)
		pcall(function() WindUI:SetTheme(theme) end)
	end,
})
SettingsTab:Space()

SettingsTab:Toggle({ Title = "Anti-AFK", Value = true, Callback = function(v) Settings.AntiAFK = v end })
SettingsTab:Toggle({ Title = "Notify On Load", Value = true, Callback = function(v) Settings.NotifyOnLoad = v end })
SettingsTab:Toggle({ Title = "Auto-Load Config On Start", Value = true,
	Callback = function(v) Settings.AutoLoadConfig = v end })
SettingsTab:Space()

SettingsTab:Button({
	Title    = "Save Config",
	Icon     = "solar:download-minimalistic-bold",
	Callback = function()
		pcall(function() Window.ConfigManager:Config("RevionHub"):Save() end)
		notify("Revion", "Config saved.", "solar:download-minimalistic-bold")
	end,
})
SettingsTab:Button({
	Title    = "Load Config",
	Icon     = "solar:upload-minimalistic-bold",
	Callback = function()
		pcall(function() Window.ConfigManager:Config("RevionHub"):Load() end)
		notify("Revion", "Config loaded.", "solar:upload-minimalistic-bold")
	end,
})
SettingsTab:Space()

SettingsTab:Button({
	Title    = "Debug: Print Detected Roles",
	Desc     = "Writes each player's detected role to the console (F9)",
	Icon     = "solar:bug-bold",
	Callback = function()
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= LocalPlayer then
				print(string.format("[Revion] %s -> %s", p.Name, getRole(p)))
			end
		end
		notify("Revion", "Roles printed to console (F9).", "solar:bug-bold")
	end,
})
SettingsTab:Button({
	Title    = "Copy Discord Invite",
	Icon     = "solar:link-bold",
	Callback = function()
		pcall(function() setclipboard("discord.gg/" .. Discord_Invite) end)
		notify("Revion", "Invite copied: discord.gg/" .. Discord_Invite, "solar:link-bold")
	end,
})
SettingsTab:Space()

SettingsTab:Button({
	Title    = "Rejoin Server",
	Icon     = "solar:refresh-circle-bold",
	Callback = rejoinServer,
})
SettingsTab:Button({
	Title    = "Server Hop",
	Icon     = "solar:planet-bold",
	Callback = serverHop,
})
SettingsTab:Space()

SettingsTab:Button({
	Title    = "Unload Revion Hub",
	Icon     = "solar:power-bold",
	Callback = unload,
})

--====================================================================
-- BOOT
--====================================================================
applyWalk()
applyJump()
applyLighting()

task.spawn(function()
	task.wait(1)
	if Settings.AutoLoadConfig then
		pcall(function() Window.ConfigManager:Config("RevionHub"):Load() end)
	end
end)

if Settings.NotifyOnLoad then
	WindUI:Notify({
		Title    = "Revion Hub Loaded",
		Content  = "Welcome to dingus. Toggle the UI with RightShift.",
		Icon     = "solar:eye-bold",
		Duration = 5,
	})
end

WindUI:Notify({
	Title    = "Join our Discord!",
	Content  = "Invite link set to clipboard",
	Icon     = "solar:link-bold",
	Duration = 10,
})

pcall(function() setclipboard("discord.gg/" .. Discord_Invite) end)
