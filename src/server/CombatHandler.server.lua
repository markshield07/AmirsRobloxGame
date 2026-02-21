--[[
	CombatHandler (Server)
	Authoritative combat logic for The Strongest Battlegrounds.
	  - Free-for-all (no match IDs, any player can hit any player)
	  - 4-hit M1 combo with ragdoll finisher
	  - Character moves (E/R/T/G) with unique effects
	  - Evasive dodge (Q) with i-frames
	  - Directional dash, blocking (F), perfect block chain
	  - Health regen out of combat
	  - Awakening transformation
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatConfig = require(Shared:WaitForChild("CombatConfig"))
local CharacterData = require(Shared:WaitForChild("CharacterData"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local CombatAPI = require(Shared:WaitForChild("CombatAPI"))

local KOEvent = Instance.new("BindableEvent")
KOEvent.Name = "KOEvent"
KOEvent.Parent = ReplicatedStorage

--------------------------------------------------------------------------------
-- PLAYER STATE
--------------------------------------------------------------------------------

local playerStates = {}

local function createState(characterKey)
	local charData = CharacterData.GetCharacter(characterKey) or CharacterData.StrongestHero
	return {
		CharacterKey = characterKey,
		CharData = charData,
		Health = CombatConfig.MaxHealth,
		Stamina = CombatConfig.Stamina.Max,
		LastStaminaUse = 0,
		ComboIndex = 0,
		ComboHitsLanded = 0,
		LastAttackTime = 0,
		IsAttacking = false,
		IsBlocking = false,
		BlockStartTime = 0,
		IsRagdolled = false,
		RagdollEndTime = 0,
		RagdollCancelReady = 0,
		RecoveryImmunityEnd = 0,
		HasCritical = false,
		HasBlackFlash = false,
		CriticalExpiry = 0,
		HitstunEnd = 0,
		EvasiveCooldownEnd = 0,
		IsInvulnerable = false,
		InvulnerableEnd = 0,
		ForwardBackCooldownEnd = 0,
		SideCooldownEnd = 0,
		MoveCooldowns = { E = 0, R = 0, T = 0, G = 0 },
		AwakeningCharge = 0,
		IsAwakened = false,
		AwakeningEndTime = 0,
		LastDamageTime = 0,
		SpawnProtectionEnd = 0,
	}
end

--------------------------------------------------------------------------------
-- HELPERS
--------------------------------------------------------------------------------

local function now()
	return os.clock()
end

local function getRoot(playerOrBot)
	local char = playerOrBot.Character
	if not char then return nil end
	return char:FindFirstChild("HumanoidRootPart")
end

local function isInFrontalArc(blockerRoot, attackerRoot)
	local toAttacker = (attackerRoot.Position - blockerRoot.Position)
	toAttacker = Vector3.new(toAttacker.X, 0, toAttacker.Z)
	if toAttacker.Magnitude < 0.1 then return true end
	local lookDir = Vector3.new(blockerRoot.CFrame.LookVector.X, 0, blockerRoot.CFrame.LookVector.Z).Unit
	local dot = lookDir:Dot(toAttacker.Unit)
	return dot >= math.cos(math.rad(CombatConfig.Block.FrontalArc / 2))
end

local function fireToPlayer(remote, player, ...)
	if player.IsBot then return end
	remote:FireClient(player, ...)
end

--------------------------------------------------------------------------------
-- STAMINA / UI
--------------------------------------------------------------------------------

local function drainStamina(state, amount)
	state.Stamina = math.max(0, state.Stamina - amount)
	state.LastStaminaUse = now()
end

local function addStamina(state, amount)
	state.Stamina = math.min(CombatConfig.Stamina.Max, state.Stamina + amount)
end

local function updateHealthUI(player, state)
	Remotes.Combat.HealthUpdate:FireAllClients(player, state.Health, CombatConfig.MaxHealth)
end

local function updateStaminaUI(player, state)
	fireToPlayer(Remotes.Combat.StaminaUpdate, player, state.Stamina, CombatConfig.Stamina.Max)
end

local function updateAwakeningUI(player, state)
	fireToPlayer(Remotes.Combat.AwakeningUpdate, player, state.AwakeningCharge, CombatConfig.Awakening.ChargeRequired)
end

--------------------------------------------------------------------------------
-- KNOCKBACK
--------------------------------------------------------------------------------

local function applyKnockback(targetRoot, direction, force)
	local existing = targetRoot:FindFirstChild("CombatKnockback")
	if existing then existing:Destroy() end

	local lv = Instance.new("LinearVelocity")
	lv.Name = "CombatKnockback"
	lv.MaxForce = 50000
	lv.VectorVelocity = direction * force + Vector3.new(0, force * 0.3, 0)
	lv.RelativeTo = Enum.ActuatorRelativeTo.World

	local attach = targetRoot:FindFirstChild("RootAttachment")
	if not attach then
		attach = Instance.new("Attachment")
		attach.Name = "RootAttachment"
		attach.Parent = targetRoot
	end
	lv.Attachment0 = attach
	lv.Parent = targetRoot

	task.delay(0.15, function()
		if lv and lv.Parent then lv:Destroy() end
	end)
end

--------------------------------------------------------------------------------
-- HITSTUN / RAGDOLL
--------------------------------------------------------------------------------

local function applyHitstun(player, state, comboHit)
	local duration = CombatConfig.Hitstun.BaseDuration - (comboHit - 1) * CombatConfig.Hitstun.Deterioration
	duration = math.max(CombatConfig.Hitstun.MinDuration, duration)
	state.HitstunEnd = now() + duration
	fireToPlayer(Remotes.Combat.Hitstun, player, duration)
end

local function applyRagdoll(player, state)
	state.IsRagdolled = true
	state.RagdollEndTime = now() + CombatConfig.Ragdoll.Duration
	state.RagdollCancelReady = now() + CombatConfig.Ragdoll.DashCancelDelay
	state.IsBlocking = false

	local root = getRoot(player)
	if root then
		applyKnockback(root, Vector3.new(0, 1, 0), CombatConfig.Ragdoll.GroundBounceForce)
	end

	Remotes.Combat.Ragdoll:FireAllClients(player, true, CombatConfig.Ragdoll.Duration)
end

local function cancelRagdoll(player, state)
	state.IsRagdolled = false
	state.RagdollEndTime = 0
	state.RecoveryImmunityEnd = now() + CombatConfig.Ragdoll.RecoveryImmunity
	Remotes.Combat.Ragdoll:FireAllClients(player, false, 0)
end

--------------------------------------------------------------------------------
-- PERFECT BLOCK
--------------------------------------------------------------------------------

local function checkPerfectBlock(blocker, blockerState)
	local timeSinceBlock = now() - blockerState.BlockStartTime
	if timeSinceBlock <= CombatConfig.PerfectBlock.Window then
		if blockerState.HasCritical then
			blockerState.HasBlackFlash = true
			blockerState.HasCritical = false
		else
			blockerState.HasCritical = true
			blockerState.CriticalExpiry = now() + CombatConfig.PerfectBlock.CriticalBuffDuration
		end
		Remotes.Combat.PerfectBlock:FireAllClients(blocker)
		return true
	end
	return false
end

--------------------------------------------------------------------------------
-- DAMAGE
--------------------------------------------------------------------------------

local function applyDamage(attacker, victim, baseDamage, attackerState, victimState, isAbility)
	local attackerRoot = getRoot(attacker)
	local victimRoot = getRoot(victim)
	if not attackerRoot or not victimRoot then return 0 end

	if now() < victimState.SpawnProtectionEnd then return 0 end
	if victimState.IsInvulnerable and now() < victimState.InvulnerableEnd then return 0 end

	local damage = baseDamage
	local wasBlockBreak = false
	local isCritical = false
	local isBlackFlash = false

	-- Critical / Black Flash
	if attackerState.HasBlackFlash and not isAbility then
		damage = CombatConfig.M1.BlackFlashDamage
		isBlackFlash = true
		attackerState.HasBlackFlash = false
		attackerState.HasCritical = false
		Remotes.Combat.CriticalHit:FireAllClients(attacker, "BlackFlash")
	elseif attackerState.HasCritical and not isAbility then
		damage = CombatConfig.M1.CriticalDamage
		isCritical = true
		attackerState.HasCritical = false
		Remotes.Combat.CriticalHit:FireAllClients(attacker, "Critical")
	end

	-- Block check
	if victimState.IsBlocking and not victimState.IsRagdolled then
		if isInFrontalArc(victimRoot, attackerRoot) then
			if checkPerfectBlock(victim, victimState) then
				damage = 0
			else
				local blockDamage = isAbility and damage or (damage * (1 - CombatConfig.Block.DamageReduction))
				if isAbility and damage >= CombatConfig.Block.BlockBreakThreshold then
					wasBlockBreak = true
					victimState.IsBlocking = false
				end
				damage = blockDamage
			end
		end
	end

	damage = math.floor(damage + 0.5)
	if damage <= 0 and not (victimState.IsBlocking and isInFrontalArc(victimRoot, attackerRoot)) then
		damage = 1
	end

	victimState.Health = math.max(0, victimState.Health - damage)
	victimState.LastDamageTime = now()

	-- Awakening charge
	attackerState.AwakeningCharge = math.min(
		CombatConfig.Awakening.ChargeRequired,
		attackerState.AwakeningCharge + damage * CombatConfig.Awakening.ChargePerDamageDealt
	)
	victimState.AwakeningCharge = math.min(
		CombatConfig.Awakening.ChargeRequired,
		victimState.AwakeningCharge + damage * CombatConfig.Awakening.ChargePerDamageTaken
	)

	updateHealthUI(victim, victimState)
	updateAwakeningUI(attacker, attackerState)
	updateAwakeningUI(victim, victimState)

	-- VFX
	local hitPos = victimRoot.Position
	Remotes.Combat.HitEffect:FireAllClients(hitPos, damage, wasBlockBreak, attackerState.CharData.Colors.Primary, isCritical, isBlackFlash)

	local hitStopDuration = 0.04
	if isBlackFlash then hitStopDuration = 0.12
	elseif isCritical then hitStopDuration = 0.08
	elseif damage >= 8 then hitStopDuration = 0.06 end
	Remotes.Combat.HitStop:FireAllClients(hitStopDuration)

	if victimState.Health <= 0 then
		KOEvent:Fire(attacker, victim)
	end

	return damage
end

--------------------------------------------------------------------------------
-- M1 ATTACK
--------------------------------------------------------------------------------

local function performAttack(player, state, isJumpHeld)
	local currentTime = now()
	if state.IsBlocking or state.IsRagdolled or state.IsAttacking then return end
	if currentTime < state.HitstunEnd then return end

	local hitCooldown = state.CharData.M1Speed or CombatConfig.M1.BaseHitCooldown
	if state.IsAwakened and state.CharData.Awakening and state.CharData.Awakening.M1SpeedMultiplier then
		hitCooldown = hitCooldown * state.CharData.Awakening.M1SpeedMultiplier
	end
	if currentTime - state.LastAttackTime < hitCooldown then return end

	if currentTime - state.LastAttackTime > CombatConfig.M1.ComboResetTime then
		state.ComboIndex = 0
		state.ComboHitsLanded = 0
	end

	state.ComboIndex = state.ComboIndex + 1
	if state.ComboIndex > CombatConfig.M1.HitCount then
		state.ComboIndex = 1
		state.ComboHitsLanded = 0
	end

	state.LastAttackTime = currentTime
	state.IsAttacking = true

	local root = getRoot(player)
	if not root then state.IsAttacking = false return end

	local lookDir = root.CFrame.LookVector
	local damage = CombatConfig.M1.Damage[state.ComboIndex] or 3
	local hitSomething = false
	local isFinisher = state.ComboIndex >= CombatConfig.M1.HitCount
	local isUppercut = isFinisher and isJumpHeld
	local isDownslam = isFinisher and root.Position.Y > 5

	local actionType = "M1"
	if isUppercut then actionType = "Uppercut"; damage = CombatConfig.Uppercut.Damage
	elseif isDownslam then actionType = "Downslam"; damage = CombatConfig.Downslam.Damage end

	Remotes.Combat.ActionVFX:FireAllClients(player, actionType, {
		CharKey = state.CharacterKey, ComboIndex = state.ComboIndex,
	})

	for otherPlayer, otherState in pairs(playerStates) do
		if otherPlayer == player then continue end
		local otherRoot = getRoot(otherPlayer)
		if not otherRoot then continue end
		if (otherRoot.Position - root.Position).Magnitude > CombatConfig.M1.HitRange then continue end
		local toTarget = (otherRoot.Position - root.Position).Unit
		if lookDir:Dot(toTarget) < 0.3 then continue end

		local dealt = applyDamage(player, otherPlayer, damage, state, otherState, false)
		if dealt > 0 then
			hitSomething = true
			state.ComboHitsLanded = state.ComboHitsLanded + 1
			applyHitstun(otherPlayer, otherState, state.ComboHitsLanded)

			local kbDir = (otherRoot.Position - root.Position)
			kbDir = Vector3.new(kbDir.X, 0, kbDir.Z)
			if kbDir.Magnitude < 0.1 then kbDir = lookDir end
			kbDir = kbDir.Unit

			if isUppercut then
				applyKnockback(otherRoot, Vector3.new(0, 1, 0), CombatConfig.Uppercut.LaunchForce)
			elseif isDownslam then
				applyKnockback(otherRoot, Vector3.new(0, -1, 0), CombatConfig.Downslam.SlamForce)
			elseif isFinisher then
				applyKnockback(otherRoot, kbDir, CombatConfig.M1.KnockbackForce)
			else
				applyKnockback(otherRoot, kbDir, 8)
			end

			if isFinisher and otherState.Health > 0 then
				applyRagdoll(otherPlayer, otherState)
			end
		end
		break
	end

	if isFinisher and not hitSomething then
		state.HitstunEnd = currentTime + CombatConfig.M1.MissedFinisherStun
	end
	if isFinisher then state.ComboIndex = 0; state.ComboHitsLanded = 0 end
	state.IsAttacking = false
end

--------------------------------------------------------------------------------
-- USE MOVE (E/R/T/G)
--------------------------------------------------------------------------------

local function performMove(player, state, slot)
	local currentTime = now()
	if state.IsBlocking or state.IsRagdolled then return end
	if currentTime < state.HitstunEnd then return end
	if currentTime < state.MoveCooldowns[slot] then return end

	local moveSet = state.CharData.Moves
	if state.IsAwakened and state.CharData.Awakening and state.CharData.Awakening.Moves and state.CharData.Awakening.Moves[slot] then
		moveSet = state.CharData.Awakening.Moves
	end
	local move = moveSet and moveSet[slot]
	if not move then return end

	if move.Cooldown == 0 and state.MoveCooldowns[slot] > 0 then return end

	local staminaCost = 15
	if state.Stamina < staminaCost then return end
	drainStamina(state, staminaCost)
	updateStaminaUI(player, state)

	state.MoveCooldowns[slot] = move.Cooldown > 0 and (currentTime + move.Cooldown) or math.huge
	fireToPlayer(Remotes.Combat.CooldownStart, player, slot, move.Cooldown)

	Remotes.Combat.ActionVFX:FireAllClients(player, "Move", {
		CharKey = state.CharacterKey, Slot = slot, MoveName = move.Name,
	})

	local root = getRoot(player)
	if not root then return end

	local lookDir = root.CFrame.LookVector
	local range = move.Range or CombatConfig.M1.HitRange
	local totalDamage = move.Damage or 0
	local hitCount = move.HitCount or 1
	local dmgMultiplier = (state.IsAwakened and state.CharData.Awakening and state.CharData.Awakening.DamageMultiplier) or 1

	for otherPlayer, otherState in pairs(playerStates) do
		if otherPlayer == player then continue end
		local otherRoot = getRoot(otherPlayer)
		if not otherRoot then continue end
		if (otherRoot.Position - root.Position).Magnitude > range then continue end
		if lookDir:Dot((otherRoot.Position - root.Position).Unit) < 0.0 then continue end

		local damagePerHit = math.floor(totalDamage * dmgMultiplier / hitCount + 0.5)

		if hitCount > 1 then
			for hit = 1, hitCount do
				task.delay((hit - 1) * (move.Duration or 0.5) / hitCount, function()
					if not playerStates[otherPlayer] then return end
					applyDamage(player, otherPlayer, damagePerHit, state, otherState, true)
				end)
			end
		else
			applyDamage(player, otherPlayer, damagePerHit, state, otherState, true)
		end

		if move.Knockback and move.Knockback > 0 then
			local kbDir = (otherRoot.Position - root.Position)
			kbDir = Vector3.new(kbDir.X, 0, kbDir.Z)
			if kbDir.Magnitude < 0.1 then kbDir = lookDir end
			applyKnockback(otherRoot, kbDir.Unit, move.Knockback)
		end

		if move.LaunchForce then
			local dir = move.LaunchForce > 0 and Vector3.new(0, 1, 0) or Vector3.new(0, -1, 0)
			applyKnockback(otherRoot, dir, math.abs(move.LaunchForce))
		end

		if move.BreaksBlock and otherState.IsBlocking then
			otherState.IsBlocking = false
		end

		if not move.Radius then break end
	end
end

--------------------------------------------------------------------------------
-- BLOCK / EVASIVE / DASH
--------------------------------------------------------------------------------

local function setBlocking(player, state, blocking)
	if state.IsRagdolled then return end
	state.IsBlocking = blocking
	if blocking then
		state.BlockStartTime = now()
		Remotes.Combat.ActionVFX:FireAllClients(player, "BlockStart", { CharKey = state.CharacterKey })
	else
		Remotes.Combat.ActionVFX:FireAllClients(player, "BlockEnd", { CharKey = state.CharacterKey })
	end
end

local function performEvasive(player, state, direction)
	local currentTime = now()
	if currentTime < state.EvasiveCooldownEnd then return end
	if state.IsBlocking then return end
	if state.Stamina < 10 then return end

	if state.IsRagdolled then
		if currentTime < state.RagdollCancelReady then return end
		cancelRagdoll(player, state)
	end

	drainStamina(state, 10)
	updateStaminaUI(player, state)
	state.EvasiveCooldownEnd = currentTime + CombatConfig.Evasive.Cooldown
	state.IsInvulnerable = true
	state.InvulnerableEnd = currentTime + CombatConfig.Evasive.IFrames

	local root = getRoot(player)
	if root then
		local evasiveDir = direction or root.CFrame.RightVector
		evasiveDir = Vector3.new(evasiveDir.X, 0, evasiveDir.Z)
		if evasiveDir.Magnitude < 0.1 then evasiveDir = root.CFrame.RightVector end
		applyKnockback(root, evasiveDir.Unit, CombatConfig.Evasive.Distance / CombatConfig.Evasive.Duration)
	end

	Remotes.Combat.ActionVFX:FireAllClients(player, "Evasive", {
		CharKey = state.CharacterKey, Direction = direction,
	})
	fireToPlayer(Remotes.Combat.CooldownStart, player, "Q", CombatConfig.Evasive.Cooldown)
end

local function performDash(player, state, direction, dashType)
	local currentTime = now()
	if state.IsBlocking then return end
	dashType = dashType or "forward"

	if state.IsRagdolled then
		if (dashType == "side" or dashType == "back") and currentTime >= state.RagdollCancelReady then
			cancelRagdoll(player, state)
		end
		return
	end

	if dashType == "forward" or dashType == "back" then
		if currentTime < state.ForwardBackCooldownEnd then return end
		state.ForwardBackCooldownEnd = currentTime + CombatConfig.Dash.ForwardCooldown
	else
		if currentTime < state.SideCooldownEnd then return end
		state.SideCooldownEnd = currentTime + CombatConfig.Dash.SideCooldown
	end

	if state.Stamina < CombatConfig.Dash.StaminaCost then return end
	drainStamina(state, CombatConfig.Dash.StaminaCost)
	updateStaminaUI(player, state)

	local root = getRoot(player)
	if root then
		local dashDir = direction and Vector3.new(direction.X, 0, direction.Z).Unit or root.CFrame.LookVector
		local dist, dur
		if dashType == "forward" then dist, dur = CombatConfig.Dash.ForwardDistance, CombatConfig.Dash.ForwardDuration
		elseif dashType == "back" then dist, dur = CombatConfig.Dash.BackDistance, CombatConfig.Dash.BackDuration
		else dist, dur = CombatConfig.Dash.SideDistance, CombatConfig.Dash.SideDuration end
		applyKnockback(root, dashDir, dist / dur)

		if dashType == "forward" then
			task.delay(dur, function()
				if not playerStates[player] then return end
				local fwdRoot = getRoot(player)
				if not fwdRoot then return end
				for otherPlayer, otherState in pairs(playerStates) do
					if otherPlayer == player then continue end
					local otherRoot = getRoot(otherPlayer)
					if not otherRoot then continue end
					if (otherRoot.Position - fwdRoot.Position).Magnitude > CombatConfig.M1.HitRange then continue end
					applyDamage(player, otherPlayer, CombatConfig.Dash.ForwardAttackDamage, state, otherState, false)
					applyKnockback(otherRoot, fwdRoot.CFrame.LookVector, 12)
					break
				end
				Remotes.Combat.ActionVFX:FireAllClients(player, "ForwardDashAttack", { CharKey = state.CharacterKey })
			end)
		end
	end

	Remotes.Combat.ActionVFX:FireAllClients(player, "Dash", {
		CharKey = state.CharacterKey, Direction = direction, DashType = dashType,
	})
end

--------------------------------------------------------------------------------
-- AWAKENING
--------------------------------------------------------------------------------

local function activateAwakening(player, state)
	if state.IsAwakened then return end
	if state.AwakeningCharge < CombatConfig.Awakening.ChargeRequired then return end

	state.IsAwakened = true
	state.AwakeningCharge = 0

	local duration = (state.CharData.Awakening and state.CharData.Awakening.Duration) or CombatConfig.Awakening.Duration
	state.AwakeningEndTime = duration > 0 and (now() + duration) or math.huge

	if state.CharData.Awakening and state.CharData.Awakening.CooldownReset then
		for slot, _ in pairs(state.MoveCooldowns) do state.MoveCooldowns[slot] = 0 end
	end

	local char = player.Character
	if char then
		local humanoid = char:FindFirstChild("Humanoid")
		if humanoid and state.CharData.Awakening and state.CharData.Awakening.SpeedMultiplier then
			humanoid.WalkSpeed = CombatConfig.Movement.WalkSpeed * state.CharData.Awakening.SpeedMultiplier
		end
	end

	updateAwakeningUI(player, state)
	Remotes.Combat.AwakeningState:FireAllClients(player, true, state.CharData.Awakening and state.CharData.Awakening.Name or "Awakened")
end

local function deactivateAwakening(player, state)
	if not state.IsAwakened then return end
	state.IsAwakened = false
	state.AwakeningEndTime = 0

	for slot, _ in pairs(state.MoveCooldowns) do
		if state.MoveCooldowns[slot] == math.huge then state.MoveCooldowns[slot] = 0 end
	end

	local char = player.Character
	if char then
		local humanoid = char:FindFirstChild("Humanoid")
		if humanoid then humanoid.WalkSpeed = CombatConfig.Movement.WalkSpeed end
	end

	Remotes.Combat.AwakeningState:FireAllClients(player, false, "")
end

--------------------------------------------------------------------------------
-- SPRINT
--------------------------------------------------------------------------------

local function setSprinting(player, state, sprinting)
	local char = player.Character
	if not char then return end
	local humanoid = char:FindFirstChild("Humanoid")
	if not humanoid then return end

	local baseSpeed = sprinting and CombatConfig.Movement.SprintSpeed or CombatConfig.Movement.WalkSpeed
	local multiplier = (state.IsAwakened and state.CharData.Awakening and state.CharData.Awakening.SpeedMultiplier) or 1
	humanoid.WalkSpeed = baseSpeed * multiplier
end

--------------------------------------------------------------------------------
-- INIT / RESET / REMOVE
--------------------------------------------------------------------------------

local function initPlayerCombat(player, characterKey)
	local state = createState(characterKey)
	playerStates[player] = state

	local char = player.Character
	if char then
		local humanoid = char:FindFirstChild("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = CombatConfig.Movement.WalkSpeed
			humanoid.MaxHealth = CombatConfig.MaxHealth
			humanoid.Health = CombatConfig.MaxHealth
		end
	end

	state.SpawnProtectionEnd = now() + CombatConfig.Respawn.SpawnProtection
	updateHealthUI(player, state)
	updateStaminaUI(player, state)
	updateAwakeningUI(player, state)
end

local function resetPlayerCombat(player)
	local state = playerStates[player]
	if not state then return end

	state.Health = CombatConfig.MaxHealth
	state.Stamina = CombatConfig.Stamina.Max
	state.ComboIndex = 0
	state.ComboHitsLanded = 0
	state.IsBlocking = false
	state.IsRagdolled = false
	state.HasCritical = false
	state.HasBlackFlash = false
	state.HitstunEnd = 0
	state.IsInvulnerable = false
	state.IsAttacking = false
	state.SpawnProtectionEnd = now() + CombatConfig.Respawn.SpawnProtection
	state.AwakeningCharge = 0
	if state.IsAwakened then deactivateAwakening(player, state) end
	for slot, _ in pairs(state.MoveCooldowns) do state.MoveCooldowns[slot] = 0 end

	updateHealthUI(player, state)
	updateStaminaUI(player, state)
	updateAwakeningUI(player, state)
end

local function removePlayerCombat(player)
	playerStates[player] = nil
end

--------------------------------------------------------------------------------
-- REMOTE HANDLERS
--------------------------------------------------------------------------------

Remotes.Combat.Attack.OnServerEvent:Connect(function(player, isJumpHeld)
	local state = playerStates[player]
	if state then performAttack(player, state, isJumpHeld == true) end
end)

Remotes.Combat.UseMove.OnServerEvent:Connect(function(player, slot)
	local state = playerStates[player]
	if not state then return end
	if slot ~= "E" and slot ~= "R" and slot ~= "T" and slot ~= "G" then return end
	performMove(player, state, slot)
end)

Remotes.Combat.Block.OnServerEvent:Connect(function(player, blocking)
	local state = playerStates[player]
	if state then setBlocking(player, state, blocking == true) end
end)

Remotes.Combat.Evasive.OnServerEvent:Connect(function(player, direction)
	local state = playerStates[player]
	if state then performEvasive(player, state, direction) end
end)

Remotes.Combat.Dash.OnServerEvent:Connect(function(player, direction, dashType)
	local state = playerStates[player]
	if state then performDash(player, state, direction, dashType) end
end)

Remotes.Combat.Awakening.OnServerEvent:Connect(function(player)
	local state = playerStates[player]
	if state then activateAwakening(player, state) end
end)

Remotes.Combat.Sprint.OnServerEvent:Connect(function(player, sprinting)
	local state = playerStates[player]
	if state then setSprinting(player, state, sprinting == true) end
end)

--------------------------------------------------------------------------------
-- HEARTBEAT
--------------------------------------------------------------------------------

RunService.Heartbeat:Connect(function(dt)
	local currentTime = now()
	for player, state in pairs(playerStates) do
		-- Stamina regen
		if currentTime - state.LastStaminaUse > CombatConfig.Stamina.RegenDelay then
			if state.Stamina < CombatConfig.Stamina.Max and not state.IsBlocking then
				addStamina(state, CombatConfig.Stamina.RegenRate * dt)
				updateStaminaUI(player, state)
			end
		end

		-- Block drain
		if state.IsBlocking then
			drainStamina(state, CombatConfig.Block.StaminaDrainRate * dt)
			updateStaminaUI(player, state)
			if state.Stamina <= 0 then setBlocking(player, state, false) end
		end

		-- Health regen
		if state.Health < CombatConfig.MaxHealth and state.Health > 0 then
			if currentTime - state.LastDamageTime > CombatConfig.HealthRegen.Delay then
				state.Health = math.min(CombatConfig.MaxHealth, state.Health + CombatConfig.HealthRegen.Rate * dt)
				updateHealthUI(player, state)
			end
		end

		-- Ragdoll timeout
		if state.IsRagdolled and currentTime >= state.RagdollEndTime then
			cancelRagdoll(player, state)
		end

		-- I-frame expiry
		if state.IsInvulnerable and currentTime >= state.InvulnerableEnd then
			state.IsInvulnerable = false
		end

		-- Critical expiry
		if state.HasCritical and currentTime >= state.CriticalExpiry then
			state.HasCritical = false
			state.HasBlackFlash = false
		end

		-- Awakening timeout
		if state.IsAwakened and state.AwakeningEndTime ~= math.huge and currentTime >= state.AwakeningEndTime then
			deactivateAwakening(player, state)
		end
	end
end)

--------------------------------------------------------------------------------
-- API
--------------------------------------------------------------------------------

CombatAPI.InitPlayerCombat = initPlayerCombat
CombatAPI.ResetPlayerCombat = resetPlayerCombat
CombatAPI.RemovePlayerCombat = removePlayerCombat
CombatAPI.GetPlayerState = function(player) return playerStates[player] end

CombatAPI.BotAttack = function(bot) local s = playerStates[bot]; if s then performAttack(bot, s, false) end end
CombatAPI.BotUseMove = function(bot, slot) local s = playerStates[bot]; if s then performMove(bot, s, slot) end end
CombatAPI.BotBlock = function(bot, b) local s = playerStates[bot]; if s then setBlocking(bot, s, b) end end
CombatAPI.BotDash = function(bot, dir, t) local s = playerStates[bot]; if s then performDash(bot, s, dir, t) end end
CombatAPI.BotEvasive = function(bot, dir) local s = playerStates[bot]; if s then performEvasive(bot, s, dir) end end

CombatAPI.MarkReady()

print("[CombatHandler] Loaded - TSB free-for-all combat")
