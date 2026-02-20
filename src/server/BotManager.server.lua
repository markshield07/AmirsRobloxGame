--[[
	BotManager (Server)
	Spawns NPC bot characters and runs simple AI for practice mode.
	The bot uses the same combat system as real players via BotPlayer wrapper.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatConfig = require(Shared:WaitForChild("CombatConfig"))
local NinjaData = require(Shared:WaitForChild("NinjaData"))
local CombatAPI = require(Shared:WaitForChild("CombatAPI"))
local BotPlayer = require(Shared:WaitForChild("BotPlayer"))

--------------------------------------------------------------------------------
-- BOT CHARACTER CREATION
--------------------------------------------------------------------------------

-- Create a minimal R6 character rig for the bot
local function createBotCharacter(name, ninjaKey)
	local ninja = NinjaData.GetNinja(ninjaKey) or NinjaData.FlameShadow
	local color = ninja.Colors.Primary

	local model = Instance.new("Model")
	model.Name = name

	-- HumanoidRootPart (required for combat — hit detection, position, knockback)
	local rootPart = Instance.new("Part")
	rootPart.Name = "HumanoidRootPart"
	rootPart.Size = Vector3.new(2, 2, 1)
	rootPart.Transparency = 1
	rootPart.Anchored = false
	rootPart.CanCollide = false
	rootPart.Parent = model

	-- Torso
	local torso = Instance.new("Part")
	torso.Name = "Torso"
	torso.Size = Vector3.new(2, 2, 1)
	torso.Color = color
	torso.Material = Enum.Material.SmoothPlastic
	torso.Anchored = false
	torso.CanCollide = true
	torso.Parent = model

	-- Weld torso to root
	local torsoWeld = Instance.new("Weld")
	torsoWeld.Part0 = rootPart
	torsoWeld.Part1 = torso
	torsoWeld.C0 = CFrame.new(0, 0, 0)
	torsoWeld.Parent = rootPart

	-- Head
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(1.5, 1.5, 1.5)
	head.Color = Color3.fromRGB(245, 205, 170) -- skin tone
	head.Material = Enum.Material.SmoothPlastic
	head.Anchored = false
	head.CanCollide = false
	head.Parent = model

	local headWeld = Instance.new("Weld")
	headWeld.Part0 = torso
	headWeld.Part1 = head
	headWeld.C0 = CFrame.new(0, 1.5, 0)
	headWeld.Parent = torso

	-- Left Arm
	local leftArm = Instance.new("Part")
	leftArm.Name = "Left Arm"
	leftArm.Size = Vector3.new(1, 2, 1)
	leftArm.Color = color
	leftArm.Material = Enum.Material.SmoothPlastic
	leftArm.Anchored = false
	leftArm.CanCollide = false
	leftArm.Parent = model

	local leftArmWeld = Instance.new("Weld")
	leftArmWeld.Part0 = torso
	leftArmWeld.Part1 = leftArm
	leftArmWeld.C0 = CFrame.new(-1.5, 0, 0)
	leftArmWeld.Parent = torso

	-- Right Arm
	local rightArm = Instance.new("Part")
	rightArm.Name = "Right Arm"
	rightArm.Size = Vector3.new(1, 2, 1)
	rightArm.Color = color
	rightArm.Material = Enum.Material.SmoothPlastic
	rightArm.Anchored = false
	rightArm.CanCollide = false
	rightArm.Parent = model

	local rightArmWeld = Instance.new("Weld")
	rightArmWeld.Part0 = torso
	rightArmWeld.Part1 = rightArm
	rightArmWeld.C0 = CFrame.new(1.5, 0, 0)
	rightArmWeld.Parent = torso

	-- Left Leg
	local leftLeg = Instance.new("Part")
	leftLeg.Name = "Left Leg"
	leftLeg.Size = Vector3.new(1, 2, 1)
	leftLeg.Color = Color3.fromRGB(40, 40, 50)
	leftLeg.Material = Enum.Material.SmoothPlastic
	leftLeg.Anchored = false
	leftLeg.CanCollide = false
	leftLeg.Parent = model

	local leftLegWeld = Instance.new("Weld")
	leftLegWeld.Part0 = torso
	leftLegWeld.Part1 = leftLeg
	leftLegWeld.C0 = CFrame.new(-0.5, -2, 0)
	leftLegWeld.Parent = torso

	-- Right Leg
	local rightLeg = Instance.new("Part")
	rightLeg.Name = "Right Leg"
	rightLeg.Size = Vector3.new(1, 2, 1)
	rightLeg.Color = Color3.fromRGB(40, 40, 50)
	rightLeg.Material = Enum.Material.SmoothPlastic
	rightLeg.Anchored = false
	rightLeg.CanCollide = false
	rightLeg.Parent = model

	local rightLegWeld = Instance.new("Weld")
	rightLegWeld.Part0 = torso
	rightLegWeld.Part1 = rightLeg
	rightLegWeld.C0 = CFrame.new(0.5, -2, 0)
	rightLegWeld.Parent = torso

	-- Humanoid (needed for the character to function)
	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = CombatConfig.MaxHealth
	humanoid.Health = CombatConfig.MaxHealth
	humanoid.WalkSpeed = 16
	humanoid.Parent = model

	-- Name tag above head
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "NameTag"
	billboard.Size = UDim2.new(0, 100, 0, 30)
	billboard.StudsOffset = Vector3.new(0, 2.5, 0)
	billboard.Adornee = head
	billboard.AlwaysOnTop = true
	billboard.Parent = head

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 1, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = name
	nameLabel.TextColor3 = color
	nameLabel.TextStrokeTransparency = 0.3
	nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Parent = billboard

	-- Set PrimaryPart
	model.PrimaryPart = rootPart

	return model
end

--------------------------------------------------------------------------------
-- BOT AI
--------------------------------------------------------------------------------

local activeBots = {} -- [botPlayer] = { state data for AI }

local function startBotAI(botPlayer, humanPlayer)
	local aiState = {
		Bot = botPlayer,
		Target = humanPlayer,
		NextActionTime = os.clock() + 1.5, -- wait before first action
		CurrentAction = "idle",
		ActionEndTime = 0,
		MoveDirection = 0, -- -1 = left, 0 = none, 1 = right
		NextMoveChange = 0,
	}
	activeBots[botPlayer] = aiState
end

local function stopBotAI(botPlayer)
	activeBots[botPlayer] = nil
end

-- AI decision-making (called each frame)
local function updateBotAI(aiState, dt)
	local bot = aiState.Bot
	local target = aiState.Target
	local currentTime = os.clock()

	-- Get positions
	local botChar = bot.Character
	local targetChar = target.Character
	if not botChar or not targetChar then return end

	local botRoot = botChar:FindFirstChild("HumanoidRootPart")
	local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
	if not botRoot or not targetRoot then return end

	local distance = (botRoot.Position - targetRoot.Position).Magnitude

	-- Face the player
	local lookDir = (targetRoot.Position - botRoot.Position)
	lookDir = Vector3.new(lookDir.X, 0, lookDir.Z)
	if lookDir.Magnitude > 0.1 then
		botRoot.CFrame = CFrame.new(botRoot.Position, botRoot.Position + lookDir.Unit)
	end

	-- Move towards player if too far, strafe if close
	local humanoid = botChar:FindFirstChild("Humanoid")
	if humanoid then
		if distance > 12 then
			-- Walk towards player
			humanoid:MoveTo(targetRoot.Position)
		elseif distance > 6 then
			-- Close range — sometimes strafe, sometimes approach
			if currentTime > aiState.NextMoveChange then
				aiState.MoveDirection = math.random(-1, 1)
				aiState.NextMoveChange = currentTime + math.random() * 1.5 + 0.5
			end

			if aiState.MoveDirection ~= 0 then
				local rightDir = botRoot.CFrame.RightVector * aiState.MoveDirection
				humanoid:MoveTo(botRoot.Position + rightDir * 5 + lookDir.Unit * 2)
			else
				humanoid:MoveTo(targetRoot.Position)
			end
		else
			-- Very close — hold position or back up slightly
			if currentTime > aiState.NextMoveChange then
				aiState.MoveDirection = math.random(-1, 1)
				aiState.NextMoveChange = currentTime + math.random() * 1 + 0.3
			end
			local rightDir = botRoot.CFrame.RightVector * aiState.MoveDirection
			humanoid:MoveTo(botRoot.Position + rightDir * 3)
		end
	end

	-- Combat actions (only when action timer is ready)
	if currentTime < aiState.NextActionTime then return end

	-- Get bot's combat state from CombatAPI
	local combatState = CombatAPI.GetPlayerState and CombatAPI.GetPlayerState(bot)

	-- Check if bot is ragdolled — try to dash-cancel
	if combatState and combatState.IsRagdolled then
		if currentTime > (combatState.RagdollCancelReady or 0) then
			-- Side/back dash to cancel ragdoll
			local sideDir = botRoot.CFrame.RightVector * (math.random() > 0.5 and 1 or -1)
			CombatAPI.BotDash(bot, sideDir, "side")
			aiState.NextActionTime = currentTime + 0.5
		end
		return
	end

	-- Decide action based on distance and randomness
	local action = math.random(1, 100)

	if distance <= CombatConfig.M1.HitRange then
		-- In melee range
		if action <= 50 then
			-- M1 attack (most common in melee)
			CombatAPI.BotAttack(bot)
			aiState.NextActionTime = currentTime + CombatConfig.M1.HitCooldown + 0.05
		elseif action <= 62 then
			-- Use E ability
			CombatAPI.BotUseAbility(bot, "E")
			aiState.NextActionTime = currentTime + 1.2
		elseif action <= 72 then
			-- Block briefly (sometimes timing it well → perfect block)
			CombatAPI.BotBlock(bot, true)
			aiState.NextActionTime = currentTime + 0.3
			task.delay(math.random() * 0.6 + 0.3, function()
				CombatAPI.BotBlock(bot, false)
			end)
		elseif action <= 80 then
			-- Use R ability
			CombatAPI.BotUseAbility(bot, "R")
			aiState.NextActionTime = currentTime + 1.5
		elseif action <= 88 then
			-- Side dash (evasion)
			local sideDir = botRoot.CFrame.RightVector * (math.random() > 0.5 and 1 or -1)
			CombatAPI.BotDash(bot, sideDir, "side")
			aiState.NextActionTime = currentTime + 0.4
		else
			-- Try ultimate if charged
			CombatAPI.BotUseAbility(bot, "F")
			aiState.NextActionTime = currentTime + 1.5
		end
	elseif distance <= 20 then
		-- Medium range — approach or use ranged abilities
		if action <= 35 then
			-- Forward dash (closes gap + attacks)
			local dashDir = (targetRoot.Position - botRoot.Position).Unit
			CombatAPI.BotDash(bot, dashDir, "forward")
			aiState.NextActionTime = currentTime + 0.6
		elseif action <= 55 then
			-- Use E (usually ranged)
			CombatAPI.BotUseAbility(bot, "E")
			aiState.NextActionTime = currentTime + 1.2
		elseif action <= 70 then
			-- Close the gap (just wait, movement handles it)
			aiState.NextActionTime = currentTime + 0.3
		else
			-- Use Q (gap closer ability)
			CombatAPI.BotUseAbility(bot, "Q")
			aiState.NextActionTime = currentTime + 0.8
		end
	else
		-- Far range — close distance
		-- Sometimes forward dash
		if action <= 30 then
			local dashDir = (targetRoot.Position - botRoot.Position).Unit
			CombatAPI.BotDash(bot, dashDir, "forward")
			aiState.NextActionTime = currentTime + 0.6
		else
			aiState.NextActionTime = currentTime + 0.3
		end
	end
end

-- Run AI every frame
RunService.Heartbeat:Connect(function(dt)
	for botPlayer, aiState in pairs(activeBots) do
		-- Check if bot is still alive
		if not botPlayer.Character or not botPlayer.Character:FindFirstChild("HumanoidRootPart") then
			continue
		end
		updateBotAI(aiState, dt)
	end
end)

--------------------------------------------------------------------------------
-- BOT MANAGER API (exposed via CombatAPI for MatchManager)
--------------------------------------------------------------------------------

-- Spawn a bot and return the BotPlayer wrapper
local function spawnBot(ninjaKey, position)
	local ninja = NinjaData.GetNinja(ninjaKey) or NinjaData.FlameShadow
	local botName = ninja.DisplayName .. " (Bot)"

	-- Create the character model
	local character = createBotCharacter(botName, ninjaKey)
	character.Parent = game:GetService("Workspace")

	-- Position the character
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = CFrame.new(position)
	end

	-- Create the BotPlayer wrapper
	local botPlayer = BotPlayer.new(botName, character)

	return botPlayer
end

local function destroyBot(botPlayer)
	stopBotAI(botPlayer)
	if botPlayer.Character then
		botPlayer.Character:Destroy()
		botPlayer.Character = nil
	end
	botPlayer.Parent = nil
end

-- Register bot functions on CombatAPI so MatchManager can use them
CombatAPI.SpawnBot = spawnBot
CombatAPI.DestroyBot = destroyBot
CombatAPI.StartBotAI = startBotAI
CombatAPI.StopBotAI = stopBotAI

print("[BotManager] Loaded")
