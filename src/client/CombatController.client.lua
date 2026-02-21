--[[
	CombatController (Client)
	TSB-style input handling:
	  - M1 attack (left click)
	  - Block (F key hold)
	  - Evasive dodge (Q key)
	  - Moves (E/R/T keys)
	  - Awakening (G key)
	  - Sprint (shift hold)
	  - Dash (shift + direction)
	  - Ragdoll cancel (Q while ragdolled)
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatConfig = require(Shared:WaitForChild("CombatConfig"))
local CharacterData = require(Shared:WaitForChild("CharacterData"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local CombatVFX = require(Shared:WaitForChild("CombatVFX"))
local SoundBank = require(Shared:WaitForChild("SoundBank"))

local player = Players.LocalPlayer
local mouse = player:GetMouse()

--------------------------------------------------------------------------------
-- LOCAL STATE
--------------------------------------------------------------------------------

local isBlocking = false
local isRagdolled = false
local isSprinting = false
local isInArena = false

local myCharacterKey = "StrongestHero"
local myCharData = CharacterData.StrongestHero

-- M1 combo (client-side for VFX only)
local localComboIndex = 0
local lastLocalM1Time = 0

-- Cooldowns (mirrored locally)
local evasiveCooldownEnd = 0
local forwardBackCooldownEnd = 0
local sideCooldownEnd = 0
local moveCooldowns = { E = 0, R = 0, T = 0, G = 0 }

-- Jump tracking
local isJumpHeld = false

-- Movement keys
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

local function getDashType()
	local w = keysHeld[Enum.KeyCode.W]
	local s = keysHeld[Enum.KeyCode.S]
	local a = keysHeld[Enum.KeyCode.A]
	local d = keysHeld[Enum.KeyCode.D]

	if s and not w then return "back" end
	if (a or d) and not w and not s then return "side" end
	return "forward"
end

local function getDashDirection(dashType)
	local char = player.Character
	if not char then return Vector3.new(0, 0, -1) end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return Vector3.new(0, 0, -1) end

	local camera = workspace.CurrentCamera
	local camLook = camera and camera.CFrame.LookVector or root.CFrame.LookVector
	local forward = Vector3.new(camLook.X, 0, camLook.Z).Unit
	local right = forward:Cross(Vector3.new(0, 1, 0)).Unit

	if dashType == "forward" then return forward
	elseif dashType == "back" then return -forward
	elseif dashType == "side" then
		if keysHeld[Enum.KeyCode.A] then return right
		elseif keysHeld[Enum.KeyCode.D] then return -right end
		return right
	end
	return forward
end

local function getEvasiveDirection()
	local char = player.Character
	if not char then return Vector3.new(1, 0, 0) end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return Vector3.new(1, 0, 0) end

	local camera = workspace.CurrentCamera
	local camLook = camera and camera.CFrame.LookVector or root.CFrame.LookVector
	local forward = Vector3.new(camLook.X, 0, camLook.Z).Unit
	local right = forward:Cross(Vector3.new(0, 1, 0)).Unit

	-- Dodge in movement direction if moving, otherwise sidestep right
	if keysHeld[Enum.KeyCode.A] then return right
	elseif keysHeld[Enum.KeyCode.D] then return -right
	elseif keysHeld[Enum.KeyCode.S] then return -forward
	elseif keysHeld[Enum.KeyCode.W] then return forward end
	return right
end

--------------------------------------------------------------------------------
-- M1 ATTACK (Left Mouse Button)
--------------------------------------------------------------------------------

local function onAttack()
	if not isInArena then return end
	if isBlocking then return end
	if isRagdolled then return end

	Remotes.Combat.Attack:FireServer(isJumpHeld)

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

		if localComboIndex >= CombatConfig.M1.HitCount and isJumpHeld then
			CombatVFX.playUppercut(char, myCharData.Colors.Primary)
			SoundBank:play("Uppercut")
		else
			CombatVFX.playM1Swing(char, localComboIndex, myCharData.Colors.Primary)
			SoundBank:play("M1Swing" .. math.min(localComboIndex, 4))
		end
	end
end

mouse.Button1Down:Connect(onAttack)

UserInputService.TouchTap:Connect(function(_, gameProcessed)
	if gameProcessed then return end
	onAttack()
end)

--------------------------------------------------------------------------------
-- INPUT HANDLING
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

	if not isInArena then return end

	-- F: Block
	if input.KeyCode == Enum.KeyCode.F then
		if isRagdolled then return end
		isBlocking = true
		Remotes.Combat.Block:FireServer(true)

		local char = getMyCharacter()
		if char then
			CombatVFX.createBlockShield(char, myCharData.Colors.Primary)
			SoundBank:play("BlockStart")
		end
		return
	end

	-- Q: Evasive dodge
	if input.KeyCode == Enum.KeyCode.Q then
		if isRagdolled then
			-- Ragdoll cancel
			local direction = getEvasiveDirection()
			Remotes.Combat.Evasive:FireServer(direction)

			local char = getMyCharacter()
			if char then
				CombatVFX.playRagdollCancel(char)
				SoundBank:play("RagdollCancel")
			end
			isRagdolled = false
			return
		end

		if isBlocking then return end
		if now() < evasiveCooldownEnd then return end

		evasiveCooldownEnd = now() + CombatConfig.Evasive.Cooldown
		local direction = getEvasiveDirection()
		Remotes.Combat.Evasive:FireServer(direction)

		local char = getMyCharacter()
		if char then
			CombatVFX.playDash(char, direction, myCharData.Colors.Primary, "side")
			SoundBank:play("DashWhoosh")
		end
		return
	end

	-- Shift: Sprint / Dash
	if input.KeyCode == Enum.KeyCode.LeftShift then
		if isBlocking or isRagdolled then return end

		-- If holding a direction, do a dash
		local anyMovement = keysHeld[Enum.KeyCode.W] or keysHeld[Enum.KeyCode.S]
			or keysHeld[Enum.KeyCode.A] or keysHeld[Enum.KeyCode.D]

		if anyMovement then
			local dashType = getDashType()
			local canDash = false

			if dashType == "forward" or dashType == "back" then
				canDash = now() >= forwardBackCooldownEnd
				if canDash then
					forwardBackCooldownEnd = now() + CombatConfig.Dash.ForwardCooldown
				end
			else
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
					CombatVFX.playDash(char, direction, myCharData.Colors.Primary, dashType)
					SoundBank:play(dashType == "forward" and "ForwardDash" or "DashWhoosh")
				end
			end
		else
			-- Sprint
			isSprinting = true
			Remotes.Combat.Sprint:FireServer(true)
		end
		return
	end

	-- G: Awakening
	if input.KeyCode == Enum.KeyCode.G then
		if isBlocking or isRagdolled then return end
		Remotes.Combat.Awakening:FireServer()
		return
	end

	-- E/R/T: Character moves
	if isBlocking or isRagdolled then return end

	local moveSlot = nil
	if input.KeyCode == Enum.KeyCode.E and now() >= moveCooldowns.E then
		moveSlot = "E"
	elseif input.KeyCode == Enum.KeyCode.R and now() >= moveCooldowns.R then
		moveSlot = "R"
	elseif input.KeyCode == Enum.KeyCode.T and now() >= moveCooldowns.T then
		moveSlot = "T"
	end

	if moveSlot then
		Remotes.Combat.UseMove:FireServer(moveSlot)

		local char = getMyCharacter()
		if char then
			CombatVFX.playAbility(char, myCharacterKey, moveSlot)
			local soundName = SoundBank:getAbilitySound(myCharacterKey, moveSlot)
			if soundName then SoundBank:play(soundName) end
		end
	end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
	-- Track movement key releases
	if keysHeld[input.KeyCode] ~= nil then
		keysHeld[input.KeyCode] = false
	end

	if input.KeyCode == Enum.KeyCode.Space then
		isJumpHeld = false
	end

	-- F release: stop blocking
	if input.KeyCode == Enum.KeyCode.F then
		if isBlocking then
			isBlocking = false
			Remotes.Combat.Block:FireServer(false)
			local char = getMyCharacter()
			if char then CombatVFX.removeBlockShield(char) end
		end
	end

	-- Shift release: stop sprinting
	if input.KeyCode == Enum.KeyCode.LeftShift then
		if isSprinting then
			isSprinting = false
			Remotes.Combat.Sprint:FireServer(false)
		end
	end
end)

--------------------------------------------------------------------------------
-- SERVER EVENT LISTENERS
--------------------------------------------------------------------------------

-- Cooldown notification
Remotes.Combat.CooldownStart.OnClientEvent:Connect(function(slot, duration)
	if slot == "Q" then
		evasiveCooldownEnd = now() + duration
	elseif moveCooldowns[slot] then
		moveCooldowns[slot] = now() + duration
	end
end)

-- Hit effect
Remotes.Combat.HitEffect.OnClientEvent:Connect(function(hitPosition, damage, wasBlockBreak, attackerColor, isCritical, isBlackFlash)
	if hitPosition then
		CombatVFX.playHitImpact(hitPosition, damage, attackerColor, wasBlockBreak, isCritical, isBlackFlash)

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

		-- Directional shake if local player was hit
		local char = getMyCharacter()
		if char then
			local root = char:FindFirstChild("HumanoidRootPart")
			if root and (root.Position - hitPosition).Magnitude < 6 then
				local intensity = isBlackFlash and 2.0 or (isCritical and 1.5 or math.max(0.2, damage / 20))
				local attackDir = (hitPosition - root.Position)
				if attackDir.Magnitude > 0.1 then
					CombatVFX.directionalShake(intensity, 0.25, attackDir.Unit)
				else
					CombatVFX.cameraShake(intensity, 0.2)
				end
			end
		end
	end
end)

-- Hit-stop
Remotes.Combat.HitStop.OnClientEvent:Connect(function(duration)
	CombatVFX.playHitStop(duration or 0.04)
end)

-- Ragdoll
Remotes.Combat.Ragdoll.OnClientEvent:Connect(function(victim, ragdolled)
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
	end
	if blockerChar then
		CombatVFX.playPerfectBlock(blockerChar, myCharData.Colors.Primary)
	end
end)

-- Critical hit / Black flash
Remotes.Combat.CriticalHit.OnClientEvent:Connect(function(attacker, hitType)
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

-- Awakening state
Remotes.Combat.AwakeningState.OnClientEvent:Connect(function(targetPlayer, activated, awakeningName)
	if targetPlayer == player then
		if activated then
			SoundBank:play("RoundStart") -- reuse as awakening sound
		end
	end

	local char = nil
	if typeof(targetPlayer) == "Instance" and targetPlayer:IsA("Player") then
		char = targetPlayer.Character
	end
	if char then
		if activated then
			CombatVFX.impactShockwave(char:FindFirstChild("HumanoidRootPart") and char.HumanoidRootPart.Position or Vector3.new(0, 0, 0), Color3.fromRGB(255, 215, 0), 20)
		end
	end
end)

-- Action VFX broadcast (other players' actions)
Remotes.Combat.ActionVFX.OnClientEvent:Connect(function(actionPlayer, actionType, data)
	if actionPlayer == player then return end

	local char = nil
	if typeof(actionPlayer) == "Instance" and actionPlayer:IsA("Player") then
		char = actionPlayer.Character
	end
	if not char then return end

	local charKey = data and data.CharKey or "StrongestHero"
	local charInfo = CharacterData.GetCharacter(charKey)
	local color = charInfo and charInfo.Colors.Primary or Color3.new(1, 1, 1)

	if actionType == "M1" then
		local comboIndex = data and data.ComboIndex or 1
		CombatVFX.playM1Swing(char, comboIndex, color)
		SoundBank:playOnPart("M1Swing" .. math.min(comboIndex, 4), char:FindFirstChild("HumanoidRootPart"))
	elseif actionType == "Uppercut" then
		CombatVFX.playUppercut(char, color)
		SoundBank:playOnPart("Uppercut", char:FindFirstChild("HumanoidRootPart"))
	elseif actionType == "Downslam" then
		CombatVFX.playDownslam(char, color)
		SoundBank:playOnPart("Downslam", char:FindFirstChild("HumanoidRootPart"))
	elseif actionType == "ForwardDashAttack" then
		CombatVFX.playForwardDashAttack(char, color)
		SoundBank:playOnPart("DashAttackHit", char:FindFirstChild("HumanoidRootPart"))
	elseif actionType == "Move" then
		local slot = data and data.Slot or "E"
		CombatVFX.playAbility(char, charKey, slot)
	elseif actionType == "Evasive" or actionType == "Dash" then
		local direction = data and data.Direction
		local dashType = data and data.DashType or "side"
		CombatVFX.playDash(char, direction, color, dashType)
		SoundBank:playOnPart("DashWhoosh", char:FindFirstChild("HumanoidRootPart"))
	elseif actionType == "BlockStart" then
		CombatVFX.createBlockShield(char, color)
	elseif actionType == "BlockEnd" then
		CombatVFX.removeBlockShield(char)
	end
end)

--------------------------------------------------------------------------------
-- GAME STATE
--------------------------------------------------------------------------------

Remotes.Game.CharacterConfirmed.OnClientEvent:Connect(function(characterKey)
	myCharacterKey = characterKey
	myCharData = CharacterData.GetCharacter(characterKey) or CharacterData.StrongestHero
	isInArena = true
	isRagdolled = false
	localComboIndex = 0
	lastLocalM1Time = 0
end)

Remotes.Game.Respawned.OnClientEvent:Connect(function()
	isRagdolled = false
	isBlocking = false
	localComboIndex = 0
	evasiveCooldownEnd = 0
	forwardBackCooldownEnd = 0
	sideCooldownEnd = 0
end)

print("[CombatController] Loaded - TSB controls (F block, Q evasive, E/R/T moves, G awakening)")
