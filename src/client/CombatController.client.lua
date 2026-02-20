--[[
	CombatController (Client)
	Handles player input and sends combat intentions to the server.
	Plays local VFX and sounds for immediate responsiveness.
	Listens for server VFX broadcasts to show other players' actions.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatConfig = require(Shared:WaitForChild("CombatConfig"))
local NinjaData = require(Shared:WaitForChild("NinjaData"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local CombatVFX = require(Shared:WaitForChild("CombatVFX"))
local SoundBank = require(Shared:WaitForChild("SoundBank"))

local player = Players.LocalPlayer
local mouse = player:GetMouse()

--------------------------------------------------------------------------------
-- LOCAL STATE
--------------------------------------------------------------------------------

local isBlocking = false
local lastDashTime = 0
local abilityCooldowns = { Q = 0, E = 0, R = 0, F = 0 }
local isInMatch = false

-- Track local player's ninja for VFX coloring
local myNinjaKey = "FlameShadow"
local myElement = "Fire"

-- M1 combo tracking (client-side for VFX only, server is authoritative)
local localComboIndex = 0
local lastLocalM1Time = 0

--------------------------------------------------------------------------------
-- HELPERS
--------------------------------------------------------------------------------

local function now()
	return os.clock()
end

local function getMoveDirection()
	local char = player.Character
	if not char then return Vector3.new(0, 0, -1) end
	local humanoid = char:FindFirstChild("Humanoid")
	if humanoid and humanoid.MoveDirection.Magnitude > 0 then
		return humanoid.MoveDirection
	end
	local root = char:FindFirstChild("HumanoidRootPart")
	if root then
		return root.CFrame.LookVector
	end
	return Vector3.new(0, 0, -1)
end

local function canUseAbility(slot)
	return now() >= abilityCooldowns[slot]
end

local function getMyCharacter()
	return player.Character
end

-- Resolve the character model for an acting player (handles both real + bots)
local function resolveCharacter(actionPlayer)
	if typeof(actionPlayer) == "Instance" and actionPlayer:IsA("Player") then
		return actionPlayer.Character
	end
	-- For bots, the actionPlayer might come through as a table-like reference
	-- but over remotes it arrives as nil/string. Bots are handled via workspace.
	return nil
end

--------------------------------------------------------------------------------
-- M1 ATTACK (Left Mouse Button / Touch Tap)
--------------------------------------------------------------------------------

local function onAttack()
	if not isInMatch then return end
	if isBlocking then return end

	Remotes.Combat.Attack:FireServer()

	-- Local VFX + sound for responsiveness (don't wait for server)
	local char = getMyCharacter()
	if char then
		-- Track combo client-side for VFX variety
		if now() - lastLocalM1Time > CombatConfig.M1.ComboResetTime then
			localComboIndex = 0
		end
		localComboIndex = localComboIndex + 1
		lastLocalM1Time = now()

		if localComboIndex > CombatConfig.M1.HitCount then
			localComboIndex = 1
		end

		CombatVFX.playM1Swing(char, localComboIndex, myElement)
		SoundBank:play("M1Swing" .. localComboIndex)
	end
end

mouse.Button1Down:Connect(onAttack)

-- Touch support
UserInputService.TouchTap:Connect(function(touchPositions, gameProcessed)
	if gameProcessed then return end
	onAttack()
end)

--------------------------------------------------------------------------------
-- BLOCK (Right Mouse Button — hold)
--------------------------------------------------------------------------------

mouse.Button2Down:Connect(function()
	if not isInMatch then return end
	isBlocking = true
	Remotes.Combat.Block:FireServer(true)

	-- Local block VFX
	local char = getMyCharacter()
	if char then
		CombatVFX.createBlockShield(char, myElement)
		SoundBank:play("BlockStart")
	end
end)

mouse.Button2Up:Connect(function()
	if isBlocking then
		isBlocking = false
		Remotes.Combat.Block:FireServer(false)

		-- Remove local block VFX
		local char = getMyCharacter()
		if char then
			CombatVFX.removeBlockShield(char)
		end
	end
end)

--------------------------------------------------------------------------------
-- ABILITIES (Q, E, R, F keys)
--------------------------------------------------------------------------------

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if not isInMatch then return end
	if isBlocking then return end

	local key = input.KeyCode

	-- Abilities
	local abilitySlot = nil
	if key == Enum.KeyCode.Q and canUseAbility("Q") then
		abilitySlot = "Q"
	elseif key == Enum.KeyCode.E and canUseAbility("E") then
		abilitySlot = "E"
	elseif key == Enum.KeyCode.R and canUseAbility("R") then
		abilitySlot = "R"
	elseif key == Enum.KeyCode.F and canUseAbility("F") then
		abilitySlot = "F"
	end

	if abilitySlot then
		Remotes.Combat.UseAbility:FireServer(abilitySlot)

		-- Local ability VFX + sound
		local char = getMyCharacter()
		if char then
			CombatVFX.playAbility(char, myNinjaKey, abilitySlot)
			local soundName = SoundBank:getAbilitySound(myNinjaKey, abilitySlot)
			if soundName then
				SoundBank:play(soundName)
			end
		end
		return
	end

	-- Dash (Spacebar or Left Shift)
	if key == Enum.KeyCode.LeftShift or key == Enum.KeyCode.Space then
		if now() - lastDashTime >= CombatConfig.Dash.Cooldown then
			lastDashTime = now()
			local direction = getMoveDirection()
			Remotes.Combat.Dash:FireServer(direction)

			-- Local dash VFX + sound
			local char = getMyCharacter()
			if char then
				CombatVFX.playDash(char, direction, myElement)
				SoundBank:play("DashWhoosh")
			end
		end
	end
end)

--------------------------------------------------------------------------------
-- SERVER EVENT LISTENERS
--------------------------------------------------------------------------------

-- Cooldown notification from server
Remotes.Combat.CooldownStart.OnClientEvent:Connect(function(slot, duration)
	abilityCooldowns[slot] = now() + duration
end)

-- Hit effect (damage numbers, particles, camera shake)
Remotes.Combat.HitEffect.OnClientEvent:Connect(function(hitPosition, damage, wasBlockBreak, attackerElement)
	if hitPosition then
		CombatVFX.playHitImpact(hitPosition, damage, attackerElement or "Fire", wasBlockBreak)

		-- Sound based on damage level
		if wasBlockBreak then
			SoundBank:playAtPosition("BlockBreak", hitPosition)
		elseif damage >= 15 then
			SoundBank:playAtPosition("HitHeavy", hitPosition)
		elseif damage >= 8 then
			SoundBank:playAtPosition("HitMedium", hitPosition)
		else
			SoundBank:playAtPosition("HitLight", hitPosition)
		end

		-- Camera shake if local player was hit
		local char = getMyCharacter()
		if char then
			local root = char:FindFirstChild("HumanoidRootPart")
			if root and (root.Position - hitPosition).Magnitude < 6 then
				local shakeIntensity = wasBlockBreak and 1.2 or (damage / 30)
				CombatVFX.cameraShake(shakeIntensity, 0.2)
			end
		end
	end
end)

-- Action VFX broadcast (for OTHER players' actions — skip own since we play locally)
Remotes.Combat.ActionVFX.OnClientEvent:Connect(function(actionPlayer, actionType, data)
	-- Skip own actions (already played locally for responsiveness)
	if actionPlayer == player then return end

	local char = resolveCharacter(actionPlayer)

	-- If the acting player isn't a standard Player (could be a bot character),
	-- search workspace for a model with a matching Name
	if not char and typeof(actionPlayer) ~= "Instance" then return end
	if not char then
		-- For real players who might not have loaded yet
		char = actionPlayer.Character
	end
	if not char then return end

	local ninjaKey = data and data.Ninja or "FlameShadow"
	local ninja = NinjaData.GetNinja(ninjaKey)
	local element = ninja and ninja.Element or "Fire"

	if actionType == "M1" then
		local comboIndex = data and data.ComboIndex or 1
		CombatVFX.playM1Swing(char, comboIndex, element)
		SoundBank:playOnPart("M1Swing" .. math.min(comboIndex, 4), char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart)

	elseif actionType == "Ability" then
		local slot = data and data.Slot or "Q"
		CombatVFX.playAbility(char, ninjaKey, slot)
		local soundName = SoundBank:getAbilitySound(ninjaKey, slot)
		if soundName then
			SoundBank:playOnPart(soundName, char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart)
		end

	elseif actionType == "Dash" then
		local direction = data and data.Direction or nil
		CombatVFX.playDash(char, direction, element)
		SoundBank:playOnPart("DashWhoosh", char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart)

	elseif actionType == "BlockStart" then
		CombatVFX.createBlockShield(char, element)
		SoundBank:playOnPart("BlockStart", char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart)

	elseif actionType == "BlockEnd" then
		CombatVFX.removeBlockShield(char)
	end
end)

--------------------------------------------------------------------------------
-- MATCH STATE
--------------------------------------------------------------------------------

-- Match found (includes our own ninja key as 3rd arg from MatchManager)
Remotes.Match.MatchFound.OnClientEvent:Connect(function(opponentName, opponentNinja, myNinja)
	isInMatch = true
	localComboIndex = 0
	lastLocalM1Time = 0

	-- Update local ninja tracking for VFX coloring
	if myNinja then
		myNinjaKey = myNinja
		local ninja = NinjaData.GetNinja(myNinja)
		if ninja then
			myElement = ninja.Element
		end
	end
end)

-- Round start countdown
Remotes.Match.RoundStart.OnClientEvent:Connect(function(roundNum, countdown)
	if countdown <= 0 then
		SoundBank:play("RoundStart")
	end
end)

-- Round end
Remotes.Match.RoundEnd.OnClientEvent:Connect(function(winnerName, score1, score2)
	local char = getMyCharacter()
	if char then
		CombatVFX.removeBlockShield(char)
	end
	isBlocking = false
end)

-- Match end
Remotes.Match.MatchEnd.OnClientEvent:Connect(function(winnerName, scores)
	isInMatch = false
	isBlocking = false
	localComboIndex = 0

	local char = getMyCharacter()
	if char then
		CombatVFX.removeBlockShield(char)
	end

	if winnerName == player.Name then
		SoundBank:play("MatchWin")
	else
		SoundBank:play("KO")
	end
end)

print("[CombatController] Loaded — VFX & Sound enabled")
