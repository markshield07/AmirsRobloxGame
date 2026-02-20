--[[
	CombatController (Client)
	TSB-style input handling:
	  - M1 attack with jump-held tracking (for uppercut)
	  - Q + WASD directional dashes (forward/back share CD, side is independent)
	  - Ragdoll cancel (side/back dash while ragdolled)
	  - Perfect block visual/audio feedback
	  - Critical/Black Flash VFX + sounds
	  - Hit-stop freeze frames
	  - Directional screen shake
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
local isInMatch = false
local isRagdolled = false

-- Ninja tracking
local myNinjaKey = "FlameShadow"
local myElement = "Fire"

-- M1 combo tracking (client-side for VFX only)
local localComboIndex = 0
local lastLocalM1Time = 0

-- Dash cooldowns (mirrored locally for responsiveness)
local forwardBackCooldownEnd = 0
local sideCooldownEnd = 0

-- Ability cooldowns
local abilityCooldowns = { Q = 0, E = 0, R = 0, F = 0 }

-- Jump tracking (for uppercut detection)
local isJumpHeld = false

-- Movement key tracking (for dash direction)
local keysHeld = {
	[Enum.KeyCode.W] = false,
	[Enum.KeyCode.A] = false,
	[Enum.KeyCode.S] = false,
	[Enum.KeyCode.D] = false,
}

--------------------------------------------------------------------------------
-- HELPERS
--------------------------------------------------------------------------------

local function now()
	return os.clock()
end

local function getMyCharacter()
	return player.Character
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

-- Determine dash type from currently held movement keys
local function getDashType()
	local w = keysHeld[Enum.KeyCode.W]
	local s = keysHeld[Enum.KeyCode.S]
	local a = keysHeld[Enum.KeyCode.A]
	local d = keysHeld[Enum.KeyCode.D]

	if s and not w then return "back" end
	if (a or d) and not w and not s then return "side" end
	-- Default to forward (W held, or no keys, or W + side)
	return "forward"
end

-- Get dash direction vector based on dash type
local function getDashDirection(dashType)
	local char = player.Character
	if not char then return Vector3.new(0, 0, -1) end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return Vector3.new(0, 0, -1) end

	local camera = workspace.CurrentCamera
	local camLook = camera and camera.CFrame.LookVector or root.CFrame.LookVector
	-- Flatten to horizontal
	local forward = Vector3.new(camLook.X, 0, camLook.Z).Unit
	local right = forward:Cross(Vector3.new(0, 1, 0)).Unit

	if dashType == "forward" then
		return forward
	elseif dashType == "back" then
		return -forward
	elseif dashType == "side" then
		if keysHeld[Enum.KeyCode.A] then
			return right  -- left from camera perspective = right cross product
		elseif keysHeld[Enum.KeyCode.D] then
			return -right
		end
		-- Default side: use move direction
		local moveDir = getMoveDirection()
		if moveDir.Magnitude > 0 then return moveDir end
		return right
	end

	return forward
end

-- Resolve character model for other players (handles bot references)
local function resolveCharacter(actionPlayer)
	if typeof(actionPlayer) == "Instance" and actionPlayer:IsA("Player") then
		return actionPlayer.Character
	end
	return nil
end

--------------------------------------------------------------------------------
-- M1 ATTACK (Left Mouse Button / Touch Tap)
--------------------------------------------------------------------------------

local function onAttack()
	if not isInMatch then return end
	if isBlocking then return end
	if isRagdolled then return end

	-- Send attack + jump state to server
	Remotes.Combat.Attack:FireServer(isJumpHeld)

	-- Local VFX + sound for responsiveness
	local char = getMyCharacter()
	if char then
		if now() - lastLocalM1Time > CombatConfig.M1.ComboResetTime then
			localComboIndex = 0
		end
		localComboIndex = localComboIndex + 1
		lastLocalM1Time = now()

		if localComboIndex > CombatConfig.M1.HitCount then
			localComboIndex = 1
		end

		-- Check for uppercut/downslam at finisher
		if localComboIndex >= CombatConfig.M1.HitCount then
			if isJumpHeld then
				CombatVFX.playUppercut(char, myElement)
				SoundBank:play("Uppercut")
			else
				CombatVFX.playM1Swing(char, localComboIndex, myElement)
				SoundBank:play("M1Swing" .. localComboIndex)
			end
		else
			CombatVFX.playM1Swing(char, localComboIndex, myElement)
			SoundBank:play("M1Swing" .. localComboIndex)
		end
	end
end

mouse.Button1Down:Connect(onAttack)

UserInputService.TouchTap:Connect(function(touchPositions, gameProcessed)
	if gameProcessed then return end
	onAttack()
end)

--------------------------------------------------------------------------------
-- BLOCK (Right Mouse Button — hold)
--------------------------------------------------------------------------------

mouse.Button2Down:Connect(function()
	if not isInMatch then return end
	if isRagdolled then return end
	isBlocking = true
	Remotes.Combat.Block:FireServer(true)

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

		local char = getMyCharacter()
		if char then
			CombatVFX.removeBlockShield(char)
		end
	end
end)

--------------------------------------------------------------------------------
-- INPUT TRACKING (movement keys + jump)
--------------------------------------------------------------------------------

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	-- Track movement keys
	if keysHeld[input.KeyCode] ~= nil then
		keysHeld[input.KeyCode] = true
	end

	-- Track jump
	if input.KeyCode == Enum.KeyCode.Space then
		isJumpHeld = true
	end

	if not isInMatch then return end

	-- DASH: Q + direction
	if input.KeyCode == Enum.KeyCode.Q then
		local dashType = getDashType()

		-- Ragdoll cancel: side/back dash while ragdolled
		if isRagdolled then
			if dashType == "side" or dashType == "back" then
				local direction = getDashDirection(dashType)
				Remotes.Combat.Dash:FireServer(direction, dashType)

				local char = getMyCharacter()
				if char then
					CombatVFX.playRagdollCancel(char)
					CombatVFX.playDash(char, direction, myElement, dashType)
					SoundBank:play("RagdollCancel")
				end
				isRagdolled = false
			end
			return
		end

		if isBlocking then return end

		-- Check local cooldown
		local canDash = false
		if dashType == "forward" or dashType == "back" then
			canDash = now() >= forwardBackCooldownEnd
			if canDash then
				forwardBackCooldownEnd = now() + CombatConfig.Dash.ForwardCooldown
			end
		elseif dashType == "side" then
			canDash = now() >= sideCooldownEnd
			if canDash then
				sideCooldownEnd = now() + CombatConfig.Dash.SideCooldown
			end
		end

		if canDash then
			local direction = getDashDirection(dashType)
			Remotes.Combat.Dash:FireServer(direction, dashType)

			local char = getMyCharacter()
			if char then
				CombatVFX.playDash(char, direction, myElement, dashType)
				if dashType == "forward" then
					SoundBank:play("ForwardDash")
				else
					SoundBank:play("DashWhoosh")
				end
			end
		end
		return
	end

	-- ABILITIES: E, R, F
	if isBlocking then return end
	if isRagdolled then return end

	local abilitySlot = nil
	if input.KeyCode == Enum.KeyCode.E and canUseAbility("E") then
		abilitySlot = "E"
	elseif input.KeyCode == Enum.KeyCode.R and canUseAbility("R") then
		abilitySlot = "R"
	elseif input.KeyCode == Enum.KeyCode.F and canUseAbility("F") then
		abilitySlot = "F"
	end

	if abilitySlot then
		Remotes.Combat.UseAbility:FireServer(abilitySlot)

		local char = getMyCharacter()
		if char then
			CombatVFX.playAbility(char, myNinjaKey, abilitySlot)
			local soundName = SoundBank:getAbilitySound(myNinjaKey, abilitySlot)
			if soundName then
				SoundBank:play(soundName)
			end
		end
	end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
	-- Track movement key releases
	if keysHeld[input.KeyCode] ~= nil then
		keysHeld[input.KeyCode] = false
	end

	-- Track jump release
	if input.KeyCode == Enum.KeyCode.Space then
		isJumpHeld = false
	end
end)

--------------------------------------------------------------------------------
-- SERVER EVENT LISTENERS
--------------------------------------------------------------------------------

-- Cooldown notification
Remotes.Combat.CooldownStart.OnClientEvent:Connect(function(slot, duration)
	abilityCooldowns[slot] = now() + duration
end)

-- Hit effect (damage numbers, particles, camera shake)
Remotes.Combat.HitEffect.OnClientEvent:Connect(function(hitPosition, damage, wasBlockBreak, attackerElement, isCritical, isBlackFlash)
	if hitPosition then
		CombatVFX.playHitImpact(hitPosition, damage, attackerElement or "Fire", wasBlockBreak, isCritical, isBlackFlash)

		-- Sound based on damage / type
		if isBlackFlash then
			SoundBank:playAtPosition("BlackFlash", hitPosition)
		elseif isCritical then
			SoundBank:playAtPosition("CriticalHit", hitPosition)
		elseif wasBlockBreak then
			SoundBank:playAtPosition("BlockBreak", hitPosition)
		elseif damage >= 8 then
			SoundBank:playAtPosition("HitHeavy", hitPosition)
		elseif damage >= 4 then
			SoundBank:playAtPosition("HitMedium", hitPosition)
		else
			SoundBank:playAtPosition("HitLight", hitPosition)
		end

		-- Directional screen shake if local player was hit
		local char = getMyCharacter()
		if char then
			local root = char:FindFirstChild("HumanoidRootPart")
			if root and (root.Position - hitPosition).Magnitude < 6 then
				local shakeIntensity
				if isBlackFlash then
					shakeIntensity = 2.0
				elseif isCritical then
					shakeIntensity = 1.5
				elseif wasBlockBreak then
					shakeIntensity = 1.2
				else
					shakeIntensity = math.max(0.2, damage / 20)
				end

				-- Directional shake toward attacker
				local attackDir = (hitPosition - root.Position)
				if attackDir.Magnitude > 0.1 then
					CombatVFX.directionalShake(shakeIntensity, 0.25, attackDir.Unit)
				else
					CombatVFX.cameraShake(shakeIntensity, 0.2)
				end
			end
		end
	end
end)

-- Hit-stop freeze frame
Remotes.Combat.HitStop.OnClientEvent:Connect(function(duration)
	CombatVFX.playHitStop(duration or 0.04)
end)

-- Ragdoll state
Remotes.Combat.Ragdoll.OnClientEvent:Connect(function(victim, ragdolled, duration)
	-- Track if WE are ragdolled
	if victim == player then
		isRagdolled = ragdolled

		if ragdolled then
			isBlocking = false
			local char = getMyCharacter()
			if char then
				CombatVFX.removeBlockShield(char)
				CombatVFX.playRagdollStart(char)
				SoundBank:play("RagdollImpact")
			end
		end
	else
		-- Other player ragdolled: show VFX on their character
		local victimChar = nil
		if typeof(victim) == "Instance" and victim:IsA("Player") then
			victimChar = victim.Character
		end
		if victimChar then
			if ragdolled then
				CombatVFX.playRagdollStart(victimChar)
			else
				CombatVFX.playRagdollCancel(victimChar)
			end
		end
	end
end)

-- Perfect block
Remotes.Combat.PerfectBlock.OnClientEvent:Connect(function(blocker)
	local blockerChar = nil
	if blocker == player then
		blockerChar = getMyCharacter()
		SoundBank:play("PerfectBlock")
	elseif typeof(blocker) == "Instance" and blocker:IsA("Player") then
		blockerChar = blocker.Character
		if blockerChar then
			local root = blockerChar:FindFirstChild("HumanoidRootPart")
			if root then
				SoundBank:playAtPosition("PerfectBlock", root.Position)
			end
		end
	end

	if blockerChar then
		CombatVFX.playPerfectBlock(blockerChar, myElement)
	end
end)

-- Critical hit / Black flash
Remotes.Combat.CriticalHit.OnClientEvent:Connect(function(attacker, hitType)
	-- Visual indicator on the attacker's character
	local char = nil
	if attacker == player then
		char = getMyCharacter()
	elseif typeof(attacker) == "Instance" and attacker:IsA("Player") then
		char = attacker.Character
	end

	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end

	if hitType == "BlackFlash" then
		CombatVFX.playBlackFlash(root.Position + root.CFrame.LookVector * 3)
	elseif hitType == "Critical" then
		CombatVFX.playCriticalHit(root.Position + root.CFrame.LookVector * 3)
	end
end)

-- Action VFX broadcast (for OTHER players' actions)
Remotes.Combat.ActionVFX.OnClientEvent:Connect(function(actionPlayer, actionType, data)
	if actionPlayer == player then return end

	local char = resolveCharacter(actionPlayer)
	if not char and typeof(actionPlayer) ~= "Instance" then return end
	if not char then
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

	elseif actionType == "Uppercut" then
		CombatVFX.playUppercut(char, element)
		SoundBank:playOnPart("Uppercut", char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart)

	elseif actionType == "Downslam" then
		CombatVFX.playDownslam(char, element)
		SoundBank:playOnPart("Downslam", char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart)

	elseif actionType == "ForwardDashAttack" then
		CombatVFX.playForwardDashAttack(char, element)
		SoundBank:playOnPart("DashAttackHit", char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart)

	elseif actionType == "Ability" then
		local slot = data and data.Slot or "Q"
		CombatVFX.playAbility(char, ninjaKey, slot)
		local soundName = SoundBank:getAbilitySound(ninjaKey, slot)
		if soundName then
			SoundBank:playOnPart(soundName, char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart)
		end

	elseif actionType == "Dash" then
		local direction = data and data.Direction or nil
		local dashType = data and data.DashType or "forward"
		CombatVFX.playDash(char, direction, element, dashType)
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

Remotes.Match.MatchFound.OnClientEvent:Connect(function(opponentName, opponentNinja, myNinja)
	isInMatch = true
	isRagdolled = false
	localComboIndex = 0
	lastLocalM1Time = 0
	forwardBackCooldownEnd = 0
	sideCooldownEnd = 0

	if myNinja then
		myNinjaKey = myNinja
		local ninja = NinjaData.GetNinja(myNinja)
		if ninja then
			myElement = ninja.Element
		end
	end
end)

Remotes.Match.RoundStart.OnClientEvent:Connect(function(roundNum, countdown)
	isRagdolled = false
	if countdown <= 0 then
		SoundBank:play("RoundStart")
	end
end)

Remotes.Match.RoundEnd.OnClientEvent:Connect(function(winnerName, score1, score2)
	local char = getMyCharacter()
	if char then
		CombatVFX.removeBlockShield(char)
	end
	isBlocking = false
	isRagdolled = false
end)

Remotes.Match.MatchEnd.OnClientEvent:Connect(function(winnerName, scores)
	isInMatch = false
	isBlocking = false
	isRagdolled = false
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

print("[CombatController] Loaded — TSB-style input (Q-dash, perfect block, uppercut/downslam)")
