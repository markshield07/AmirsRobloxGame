--[[
	CombatHandler (Server)
	Authoritative combat logic — TSB-style mechanics.
	  - 4-hit M1 combo with ragdoll finisher
	  - Hitstun with deterioration per combo hit
	  - Perfect block → Critical Hit → Black Flash chain
	  - Directional dash system (forward attacks, side/back evasion)
	  - Uppercut (jump+combo) and Downslam (aerial finisher)
	  - Missed 4th hit punishes the attacker
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatConfig = require(Shared:WaitForChild("CombatConfig"))
local NinjaData = require(Shared:WaitForChild("NinjaData"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local CombatAPI = require(Shared:WaitForChild("CombatAPI"))

--------------------------------------------------------------------------------
-- PLAYER STATE TRACKING
--------------------------------------------------------------------------------

local playerStates = {} -- [Player or BotPlayer] = { ... }

local function createPlayerState(player, ninjaKey, matchId)
	local ninja = NinjaData.GetNinja(ninjaKey) or NinjaData.FlameShadow

	return {
		Ninja = ninjaKey,
		NinjaInfo = ninja,
		MatchId = matchId,

		Health = CombatConfig.MaxHealth,
		Stamina = CombatConfig.Stamina.Max,
		UltimateCharge = 0,

		ComboIndex = 0,
		LastM1Time = 0,
		ComboHitsLanded = 0,        -- consecutive hits landed (for hitstun deterioration)

		Cooldowns = { Q = 0, E = 0, R = 0, F = 0 },

		IsBlocking = false,
		BlockStartTime = 0,          -- when block was raised (for perfect block timing)
		IsDashing = false,
		IsUsingAbility = false,
		IsStunned = false,
		StunEndTime = 0,
		SpawnProtectionEnd = 0,

		-- Ragdoll state
		IsRagdolled = false,
		RagdollEndTime = 0,
		RagdollCancelReady = 0,      -- time after which dash-cancel is allowed

		-- Recovery immunity after ragdoll
		RecoveryImmunityEnd = 0,

		-- Critical/Black Flash state
		HasCritical = false,         -- next M1 will be a Critical Hit
		HasBlackFlash = false,       -- next M1 will be a Black Flash
		CriticalExpiry = 0,          -- critical state timeout

		-- Uppercut tracking
		IsHoldingJump = false,       -- client tells us if jump is held

		-- Dash cooldowns (separate for forward/back vs side)
		ForwardBackCooldownEnd = 0,
		SideCooldownEnd = 0,

		LastStaminaUse = 0,

		-- Wall combo tracking
		LastWallComboTime = 0,
	}
end

--------------------------------------------------------------------------------
-- HELPERS: Safe remote firing (skips bots)
--------------------------------------------------------------------------------

local function isBot(player)
	return typeof(player) == "table" and player.IsBot == true
end

local function safeFireClient(remote, player, ...)
	if isBot(player) then return end
	remote:FireClient(player, ...)
end

local function fireAllRealClients(remote, ...)
	for _, p in pairs(Players:GetPlayers()) do
		remote:FireClient(p, ...)
	end
end

--------------------------------------------------------------------------------
-- COMBAT API (registered on shared module)
--------------------------------------------------------------------------------

local function initPlayerCombat(player, ninjaKey, matchId)
	playerStates[player] = createPlayerState(player, ninjaKey, matchId)
	safeFireClient(Remotes.Combat.HealthUpdate, player, player, CombatConfig.MaxHealth, CombatConfig.MaxHealth)
	safeFireClient(Remotes.Combat.StaminaUpdate, player, CombatConfig.Stamina.Max, CombatConfig.Stamina.Max)
	safeFireClient(Remotes.Combat.UltimateUpdate, player, 0, CombatConfig.Ultimate.MaxCharge)
end

local function resetPlayerCombat(player)
	local state = playerStates[player]
	if not state then return end

	state.Health = CombatConfig.MaxHealth
	state.Stamina = CombatConfig.Stamina.Max
	state.UltimateCharge = 0
	state.ComboIndex = 0
	state.ComboHitsLanded = 0
	state.Cooldowns = { Q = 0, E = 0, R = 0, F = 0 }
	state.IsBlocking = false
	state.IsDashing = false
	state.IsUsingAbility = false
	state.IsStunned = false
	state.IsRagdolled = false
	state.RagdollEndTime = 0
	state.RecoveryImmunityEnd = 0
	state.HasCritical = false
	state.HasBlackFlash = false
	state.ForwardBackCooldownEnd = 0
	state.SideCooldownEnd = 0
	state.SpawnProtectionEnd = os.clock() + CombatConfig.Match.SpawnProtection

	safeFireClient(Remotes.Combat.HealthUpdate, player, player, CombatConfig.MaxHealth, CombatConfig.MaxHealth)
	safeFireClient(Remotes.Combat.StaminaUpdate, player, CombatConfig.Stamina.Max, CombatConfig.Stamina.Max)
	safeFireClient(Remotes.Combat.UltimateUpdate, player, 0, CombatConfig.Ultimate.MaxCharge)
end

local function removePlayerCombat(player)
	playerStates[player] = nil
end

local function setPlayerMatchId(player, matchId)
	local state = playerStates[player]
	if state then
		state.MatchId = matchId
	end
end

local function getPlayerState(player)
	return playerStates[player]
end

-- Register on CombatAPI
CombatAPI.InitPlayerCombat = initPlayerCombat
CombatAPI.ResetPlayerCombat = resetPlayerCombat
CombatAPI.RemovePlayerCombat = removePlayerCombat
CombatAPI.SetPlayerMatchId = setPlayerMatchId
CombatAPI.GetPlayerState = getPlayerState
CombatAPI.IsReady = true

--------------------------------------------------------------------------------
-- HELPERS
--------------------------------------------------------------------------------

local function now()
	return os.clock()
end

local function getState(player)
	return playerStates[player]
end

local function canAct(state)
	if not state then return false end
	if state.IsRagdolled and now() < state.RagdollEndTime then return false end
	if state.IsStunned and now() < state.StunEndTime then return false end
	if state.IsDashing then return false end
	if state.IsUsingAbility then return false end
	if now() < state.SpawnProtectionEnd then return false end
	return true
end

local function isAlive(state)
	return state and state.Health > 0
end

local function getOpponent(player)
	local myState = playerStates[player]
	if not myState then return nil end
	local myMatchId = myState.MatchId

	for otherPlayer, otherState in pairs(playerStates) do
		if otherPlayer ~= player and otherState.MatchId == myMatchId then
			return otherPlayer
		end
	end
	return nil
end

local function getRoot(player)
	local char = player.Character
	if not char then return nil end
	return char:FindFirstChild("HumanoidRootPart")
end

local function applyVelocityImpulse(rootPart, velocity, duration)
	local attachment = Instance.new("Attachment")
	attachment.Name = "ImpulseAttachment"
	attachment.Parent = rootPart

	local linearVelocity = Instance.new("LinearVelocity")
	linearVelocity.Attachment0 = attachment
	linearVelocity.VectorVelocity = velocity
	linearVelocity.MaxForce = 50000
	linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
	linearVelocity.Parent = rootPart

	task.delay(duration, function()
		if linearVelocity and linearVelocity.Parent then
			linearVelocity:Destroy()
		end
		if attachment and attachment.Parent then
			attachment:Destroy()
		end
	end)
end

local function isInRange(attacker, victim, range)
	local attackerRoot = getRoot(attacker)
	local victimRoot = getRoot(victim)
	if not attackerRoot or not victimRoot then return false end
	return (attackerRoot.Position - victimRoot.Position).Magnitude <= range
end

local function isInFrontalArc(attacker, victim)
	local attackerRoot = getRoot(attacker)
	local victimRoot = getRoot(victim)
	if not attackerRoot or not victimRoot then return true end

	local toAttacker = (attackerRoot.Position - victimRoot.Position).Unit
	local victimLook = victimRoot.CFrame.LookVector
	local dot = toAttacker:Dot(victimLook)
	local halfArc = math.rad(CombatConfig.Block.FrontalArc / 2)
	return dot >= math.cos(halfArc)
end

--------------------------------------------------------------------------------
-- HITSTUN
--------------------------------------------------------------------------------

local function applyHitstun(victim, comboHits)
	local victimState = getState(victim)
	if not victimState then return end
	if victimState.IsRagdolled then return end
	if now() < victimState.RecoveryImmunityEnd then return end

	local duration = math.max(
		CombatConfig.Hitstun.MinDuration,
		CombatConfig.Hitstun.BaseDuration - (comboHits - 1) * CombatConfig.Hitstun.Deterioration
	)

	victimState.IsStunned = true
	victimState.StunEndTime = now() + duration

	fireAllRealClients(Remotes.Combat.Hitstun, victim, duration)
end

--------------------------------------------------------------------------------
-- RAGDOLL
--------------------------------------------------------------------------------

local function applyRagdoll(victim, force, direction)
	local victimState = getState(victim)
	if not victimState then return end

	victimState.IsRagdolled = true
	victimState.IsStunned = false
	victimState.IsBlocking = false
	victimState.RagdollEndTime = now() + CombatConfig.Ragdoll.Duration
	victimState.RagdollCancelReady = now() + CombatConfig.Ragdoll.DashCancelDelay

	-- Apply knockback force
	local victimRoot = getRoot(victim)
	if victimRoot and direction then
		local kbVelocity = direction * force + Vector3.new(0, CombatConfig.Ragdoll.GroundBounceForce, 0)
		applyVelocityImpulse(victimRoot, kbVelocity, 0.3)
	end

	fireAllRealClients(Remotes.Combat.Ragdoll, victim, true, CombatConfig.Ragdoll.Duration)

	-- Auto-recover after duration
	task.delay(CombatConfig.Ragdoll.Duration, function()
		if victimState and victimState.IsRagdolled then
			victimState.IsRagdolled = false
			victimState.RecoveryImmunityEnd = now() + CombatConfig.Ragdoll.RecoveryImmunity
			-- Clear critical state on ragdoll recovery
			victimState.HasCritical = false
			victimState.HasBlackFlash = false
			fireAllRealClients(Remotes.Combat.Ragdoll, victim, false, 0)
		end
	end)
end

local function cancelRagdoll(player)
	local state = getState(player)
	if not state then return false end
	if not state.IsRagdolled then return false end
	if now() < state.RagdollCancelReady then return false end

	state.IsRagdolled = false
	state.RagdollEndTime = 0
	state.RecoveryImmunityEnd = now() + CombatConfig.Ragdoll.RecoveryImmunity
	state.HasCritical = false
	state.HasBlackFlash = false

	fireAllRealClients(Remotes.Combat.Ragdoll, player, false, 0)
	return true
end

--------------------------------------------------------------------------------
-- PERFECT BLOCK
--------------------------------------------------------------------------------

local function checkPerfectBlock(blocker, attacker)
	local blockerState = getState(blocker)
	if not blockerState then return false end
	if not blockerState.IsBlocking then return false end

	local timeSinceBlockStart = now() - blockerState.BlockStartTime
	if timeSinceBlockStart <= CombatConfig.PerfectBlock.Window then
		-- Perfect block succeeded!
		if blockerState.HasCritical then
			-- Already has critical → upgrade to Black Flash
			blockerState.HasBlackFlash = true
			blockerState.HasCritical = false
		else
			blockerState.HasCritical = true
		end
		blockerState.CriticalExpiry = now() + CombatConfig.PerfectBlock.CriticalBuffDuration

		fireAllRealClients(Remotes.Combat.PerfectBlock, blocker)
		return true
	end
	return false
end

--------------------------------------------------------------------------------
-- DAMAGE
--------------------------------------------------------------------------------

local function applyDamage(attacker, victim, rawDamage, breaksBlock, isCritical, isBlackFlash)
	local attackerState = getState(attacker)
	local victimState = getState(victim)
	if not attackerState or not victimState then return 0 end
	if not isAlive(victimState) then return 0 end
	if now() < victimState.SpawnProtectionEnd then return 0 end

	local actualDamage = rawDamage

	if victimState.IsBlocking and not breaksBlock then
		-- Check if attacker is in victim's frontal arc
		if isInFrontalArc(attacker, victim) then
			-- Check for perfect block
			if checkPerfectBlock(victim, attacker) then
				-- Perfect block: no damage, attacker recoils slightly
				fireAllRealClients(Remotes.Combat.HitEffect, getRoot(victim) and getRoot(victim).Position or Vector3.zero, 0, false, attackerState.NinjaInfo and attackerState.NinjaInfo.Element or "Fire")
				return 0
			end

			-- Normal block: reduce damage
			actualDamage = rawDamage * (1 - CombatConfig.Block.DamageReduction)
		end
		-- Attack from behind: full damage even when blocking
	elseif victimState.IsBlocking and breaksBlock then
		-- Block break
		victimState.IsBlocking = false
		victimState.IsStunned = true
		victimState.StunEndTime = now() + 0.5
		fireAllRealClients(Remotes.Combat.ActionVFX, victim, "BlockEnd", { Ninja = victimState.Ninja })
	end

	victimState.Health = math.max(0, victimState.Health - actualDamage)

	-- Ultimate charge
	attackerState.UltimateCharge = math.min(
		CombatConfig.Ultimate.MaxCharge,
		attackerState.UltimateCharge + actualDamage * CombatConfig.Ultimate.ChargePerDamageDealt
	)
	victimState.UltimateCharge = math.min(
		CombatConfig.Ultimate.MaxCharge,
		victimState.UltimateCharge + actualDamage * CombatConfig.Ultimate.ChargePerDamageTaken
	)

	-- Notify clients
	fireAllRealClients(Remotes.Combat.HealthUpdate, victim, victimState.Health, CombatConfig.MaxHealth)
	safeFireClient(Remotes.Combat.UltimateUpdate, attacker, attackerState.UltimateCharge, CombatConfig.Ultimate.MaxCharge)
	safeFireClient(Remotes.Combat.UltimateUpdate, victim, victimState.UltimateCharge, CombatConfig.Ultimate.MaxCharge)

	-- Hit effect
	local victimRoot = getRoot(victim)
	if victimRoot then
		local attackerElement = attackerState.NinjaInfo and attackerState.NinjaInfo.Element or "Fire"
		fireAllRealClients(Remotes.Combat.HitEffect, victimRoot.Position, actualDamage, breaksBlock, attackerElement, isCritical or false, isBlackFlash or false)
	end

	-- Hit-stop for meaty hits
	if actualDamage >= 4 or isCritical or isBlackFlash then
		local stopDuration = isBlackFlash and 0.12 or (isCritical and 0.08 or 0.04)
		fireAllRealClients(Remotes.Combat.HitStop, stopDuration)
	end

	-- Critical/Black Flash notification
	if isCritical then
		fireAllRealClients(Remotes.Combat.CriticalHit, attacker, "Critical")
	elseif isBlackFlash then
		fireAllRealClients(Remotes.Combat.CriticalHit, attacker, "BlackFlash")
	end

	-- Check for KO
	if victimState.Health <= 0 then
		local matchEndEvent = game:GetService("ServerScriptService"):FindFirstChild("MatchKOEvent", true)
		if matchEndEvent then
			matchEndEvent:Fire(attacker, victim)
		end
	end

	return actualDamage
end

local function applyKnockback(attacker, victim, force)
	local attackerRoot = getRoot(attacker)
	local victimRoot = getRoot(victim)
	if not attackerRoot or not victimRoot then return end

	local direction = (victimRoot.Position - attackerRoot.Position).Unit
	applyVelocityImpulse(victimRoot, direction * force + Vector3.new(0, force * 0.3, 0), 0.3)
end

--------------------------------------------------------------------------------
-- M1 ATTACK
--------------------------------------------------------------------------------

local function performAttack(player, isJumpHeld)
	local state = getState(player)
	if not canAct(state) then return end
	if not isAlive(state) then return end
	if state.IsBlocking then return end

	local currentTime = now()

	-- Reset combo after inactivity
	if currentTime - state.LastM1Time > CombatConfig.M1.ComboResetTime then
		state.ComboIndex = 0
		state.ComboHitsLanded = 0
	end
	if currentTime - state.LastM1Time < CombatConfig.M1.HitCooldown then return end

	state.ComboIndex = state.ComboIndex + 1
	state.LastM1Time = currentTime

	local hitIndex = state.ComboIndex
	local isFinisher = hitIndex >= CombatConfig.M1.HitCount

	-- Determine damage (critical / black flash overrides)
	local damage = CombatConfig.M1.Damage[hitIndex] or CombatConfig.M1.Damage[1]
	local isCritical = false
	local isBlackFlash = false

	if state.HasBlackFlash then
		damage = CombatConfig.M1.BlackFlashDamage
		isBlackFlash = true
		state.HasBlackFlash = false
		state.HasCritical = false
	elseif state.HasCritical and now() < state.CriticalExpiry then
		damage = CombatConfig.M1.CriticalDamage
		isCritical = true
		state.HasCritical = false
	end

	-- Check if player is airborne (for downslam)
	local playerRoot = getRoot(player)
	local isAirborne = false
	if playerRoot then
		-- Simple airborne check: raycast down
		local rayResult = workspace:Raycast(playerRoot.Position, Vector3.new(0, -4, 0))
		isAirborne = (rayResult == nil)
	end

	-- Determine finisher type
	local finisherType = "normal" -- normal 4th hit ragdoll
	if isFinisher then
		if isAirborne then
			finisherType = "downslam"
		elseif isJumpHeld then
			finisherType = "uppercut"
		end
	end

	local opponent = getOpponent(player)
	local hitLanded = false

	if opponent and isInRange(player, opponent, CombatConfig.M1.HitRange) then
		hitLanded = true
		state.ComboHitsLanded = state.ComboHitsLanded + 1

		if isFinisher then
			if finisherType == "downslam" then
				-- Downslam: goes through block, slams down
				local dmg = CombatConfig.Downslam.Damage
				if isCritical then dmg = CombatConfig.M1.CriticalDamage end
				if isBlackFlash then dmg = CombatConfig.M1.BlackFlashDamage end
				applyDamage(player, opponent, dmg, CombatConfig.Downslam.BreaksBlock, isCritical, isBlackFlash)

				local oppRoot = getRoot(opponent)
				if oppRoot then
					applyVelocityImpulse(oppRoot, Vector3.new(0, -CombatConfig.Downslam.SlamForce, 0), 0.25)
				end

				-- Ragdoll after slam
				local attackerRoot = getRoot(player)
				local dir = Vector3.new(0, -1, 0)
				if attackerRoot and oppRoot then
					dir = (oppRoot.Position - attackerRoot.Position).Unit
				end
				applyRagdoll(opponent, 10, dir)

			elseif finisherType == "uppercut" then
				-- Uppercut: launches opponent upward
				applyDamage(player, opponent, CombatConfig.Uppercut.Damage, false, isCritical, isBlackFlash)

				local oppRoot = getRoot(opponent)
				if oppRoot then
					local attackerRoot = getRoot(player)
					local horizontalDir = Vector3.new(0, 0, 0)
					if attackerRoot then
						horizontalDir = (oppRoot.Position - attackerRoot.Position).Unit * 5
					end
					applyVelocityImpulse(oppRoot, Vector3.new(horizontalDir.X, CombatConfig.Uppercut.LaunchForce, horizontalDir.Z), 0.3)
				end

				applyRagdoll(opponent, 5, Vector3.new(0, 1, 0))

			else
				-- Normal 4th hit: knockback + ragdoll
				applyDamage(player, opponent, damage, false, isCritical, isBlackFlash)

				local attackerRoot = getRoot(player)
				local oppRoot = getRoot(opponent)
				local dir = Vector3.new(0, 0, 1)
				if attackerRoot and oppRoot then
					dir = (oppRoot.Position - attackerRoot.Position).Unit
				end
				applyRagdoll(opponent, CombatConfig.M1.KnockbackForce, dir)
			end
		else
			-- Normal hit (1st, 2nd, 3rd): damage + hitstun
			applyDamage(player, opponent, damage, false, isCritical, isBlackFlash)
			applyHitstun(opponent, state.ComboHitsLanded)
		end
	end

	-- Determine VFX action type
	local vfxType = "M1"
	if isFinisher and finisherType == "uppercut" then
		vfxType = "Uppercut"
	elseif isFinisher and finisherType == "downslam" then
		vfxType = "Downslam"
	end

	-- Broadcast VFX
	fireAllRealClients(Remotes.Combat.ActionVFX, player, vfxType, {
		ComboIndex = hitIndex,
		Ninja = state.Ninja,
		HitLanded = hitLanded,
		IsCritical = isCritical,
		IsBlackFlash = isBlackFlash,
	})

	-- Finisher recovery
	if isFinisher then
		state.ComboIndex = 0
		state.ComboHitsLanded = 0

		if not hitLanded then
			-- MISSED 4th hit: attacker gets punished with stun
			state.IsStunned = true
			state.StunEndTime = now() + CombatConfig.M1.MissedFinisherStun
		else
			-- Normal recovery
			state.IsUsingAbility = true
			task.delay(CombatConfig.M1.RecoveryTime, function()
				if state then state.IsUsingAbility = false end
			end)
		end
	end
end

--------------------------------------------------------------------------------
-- BLOCK
--------------------------------------------------------------------------------

local function performBlock(player, blocking)
	local state = getState(player)
	if not state then return end
	if not isAlive(state) then return end

	if blocking then
		if not canAct(state) then return end
		state.IsBlocking = true
		state.BlockStartTime = now()
		state.ComboIndex = 0
		state.ComboHitsLanded = 0
		fireAllRealClients(Remotes.Combat.ActionVFX, player, "BlockStart", {
			Ninja = state.Ninja,
		})
	else
		state.IsBlocking = false
		fireAllRealClients(Remotes.Combat.ActionVFX, player, "BlockEnd", {
			Ninja = state.Ninja,
		})
	end
end

--------------------------------------------------------------------------------
-- DASH (TSB-style: direction-based, different cooldowns)
--------------------------------------------------------------------------------

local function performDash(player, direction, dashType)
	local state = getState(player)
	if not isAlive(state) then return end

	-- Allow dash to cancel ragdoll (side/back only)
	if state.IsRagdolled then
		if dashType == "side" or dashType == "back" then
			if cancelRagdoll(player) then
				-- Perform the dash after canceling
			else
				return
			end
		else
			return
		end
	end

	if not canAct(state) then return end
	if state.IsBlocking then return end
	if state.Stamina < CombatConfig.Dash.StaminaCost then return end

	-- Check cooldown based on dash type
	dashType = dashType or "forward"
	if dashType == "forward" or dashType == "back" then
		if now() < state.ForwardBackCooldownEnd then return end
	elseif dashType == "side" then
		if now() < state.SideCooldownEnd then return end
	end

	-- Consume stamina
	state.Stamina = state.Stamina - CombatConfig.Dash.StaminaCost
	state.LastStaminaUse = now()
	safeFireClient(Remotes.Combat.StaminaUpdate, player, state.Stamina, CombatConfig.Stamina.Max)

	-- Set cooldowns
	if dashType == "forward" or dashType == "back" then
		state.ForwardBackCooldownEnd = now() + CombatConfig.Dash.ForwardCooldown
	elseif dashType == "side" then
		state.SideCooldownEnd = now() + CombatConfig.Dash.SideCooldown
	end

	-- Get dash parameters
	local distance, duration
	if dashType == "forward" then
		distance = CombatConfig.Dash.ForwardDistance
		duration = CombatConfig.Dash.ForwardDuration
	elseif dashType == "back" then
		distance = CombatConfig.Dash.BackDistance
		duration = CombatConfig.Dash.BackDuration
	else
		distance = CombatConfig.Dash.SideDistance
		duration = CombatConfig.Dash.SideDuration
	end

	-- Broadcast VFX
	fireAllRealClients(Remotes.Combat.ActionVFX, player, "Dash", {
		Direction = typeof(direction) == "Vector3" and direction or nil,
		DashType = dashType,
		Ninja = state.Ninja,
	})

	-- Apply velocity
	state.IsDashing = true
	local root = getRoot(player)
	if root then
		local dashDir = typeof(direction) == "Vector3" and direction.Unit or root.CFrame.LookVector
		applyVelocityImpulse(root, dashDir * (distance / duration), duration)

		task.delay(duration, function()
			state.IsDashing = false

			-- Forward dash ends with an attack
			if dashType == "forward" then
				local opponent = getOpponent(player)
				if opponent and isInRange(player, opponent, CombatConfig.M1.HitRange) then
					applyDamage(player, opponent, CombatConfig.Dash.ForwardAttackDamage, false)
					fireAllRealClients(Remotes.Combat.ActionVFX, player, "ForwardDashAttack", {
						Ninja = state.Ninja,
					})
				end
			end
		end)
	else
		state.IsDashing = false
	end
end

--------------------------------------------------------------------------------
-- ABILITIES
--------------------------------------------------------------------------------

local function performAbility(player, slot)
	local state = getState(player)
	if not canAct(state) then return end
	if not isAlive(state) then return end
	if state.IsBlocking then return end
	if slot ~= "Q" and slot ~= "E" and slot ~= "R" and slot ~= "F" then return end

	if slot == "F" and state.UltimateCharge < CombatConfig.Ultimate.MaxCharge then return end
	if now() < state.Cooldowns[slot] then return end

	local ninjaInfo = state.NinjaInfo
	if not ninjaInfo then return end
	local ability = ninjaInfo.Abilities[slot]
	if not ability then return end

	local cooldown = ability.Cooldown or 0
	state.Cooldowns[slot] = now() + cooldown
	safeFireClient(Remotes.Combat.CooldownStart, player, slot, cooldown)

	if slot == "F" then
		state.UltimateCharge = 0
		safeFireClient(Remotes.Combat.UltimateUpdate, player, 0, CombatConfig.Ultimate.MaxCharge)
	end

	state.IsUsingAbility = true

	-- Broadcast ability VFX
	fireAllRealClients(Remotes.Combat.ActionVFX, player, "Ability", {
		Slot = slot,
		Ninja = state.Ninja,
	})

	local opponent = getOpponent(player)
	local damage = ability.Damage or 0
	local range = ability.Range or ability.DashDistance or ability.TeleportDistance or ability.MaxRange or 15
	local breaksBlock = ability.BreaksBlock or false

	if opponent and damage > 0 and isInRange(player, opponent, range) then
		applyDamage(player, opponent, damage, breaksBlock)
		if ability.LaunchForce then
			applyKnockback(player, opponent, ability.LaunchForce)
		end
		if ability.StunDuration then
			local opponentState = getState(opponent)
			if opponentState then
				opponentState.IsStunned = true
				opponentState.StunEndTime = now() + ability.StunDuration
			end
		end
	end

	task.delay(0.5, function()
		if state then state.IsUsingAbility = false end
	end)
end

-- Expose combat functions for bot AI
CombatAPI.BotAttack = function(botPlayer) performAttack(botPlayer, false) end
CombatAPI.BotBlock = performBlock
CombatAPI.BotDash = performDash
CombatAPI.BotUseAbility = performAbility

--------------------------------------------------------------------------------
-- REMOTE EVENT HANDLERS (real players only)
--------------------------------------------------------------------------------

Remotes.Combat.Attack.OnServerEvent:Connect(function(player, isJumpHeld)
	performAttack(player, isJumpHeld or false)
end)

Remotes.Combat.Block.OnServerEvent:Connect(function(player, blocking)
	performBlock(player, blocking)
end)

Remotes.Combat.Dash.OnServerEvent:Connect(function(player, direction, dashType)
	performDash(player, direction, dashType or "forward")
end)

Remotes.Combat.UseAbility.OnServerEvent:Connect(function(player, slot)
	performAbility(player, slot)
end)

--------------------------------------------------------------------------------
-- STAMINA REGENERATION & STATE CLEANUP
--------------------------------------------------------------------------------

game:GetService("RunService").Heartbeat:Connect(function(dt)
	local currentTime = now()

	for player, state in pairs(playerStates) do
		-- Cleanup disconnected players/dead bots
		if isBot(player) then
			if not player.Character or not player.Character.Parent then
				playerStates[player] = nil
				continue
			end
		else
			if not player.Parent then
				playerStates[player] = nil
				continue
			end
		end

		-- Stamina regen
		if not state.IsBlocking and not state.IsDashing then
			if currentTime - state.LastStaminaUse >= CombatConfig.Stamina.RegenDelay then
				if state.Stamina < CombatConfig.Stamina.Max then
					state.Stamina = math.min(
						CombatConfig.Stamina.Max,
						state.Stamina + CombatConfig.Stamina.RegenRate * dt
					)
					safeFireClient(Remotes.Combat.StaminaUpdate, player, state.Stamina, CombatConfig.Stamina.Max)
				end
			end
		end

		-- Block stamina drain
		if state.IsBlocking then
			state.Stamina = state.Stamina - CombatConfig.Block.StaminaDrainRate * dt
			state.LastStaminaUse = currentTime
			if state.Stamina <= 0 then
				state.Stamina = 0
				state.IsBlocking = false
				fireAllRealClients(Remotes.Combat.ActionVFX, player, "BlockEnd", { Ninja = state.Ninja })
			end
			safeFireClient(Remotes.Combat.StaminaUpdate, player, state.Stamina, CombatConfig.Stamina.Max)
		end

		-- Clear expired stun
		if state.IsStunned and currentTime >= state.StunEndTime then
			state.IsStunned = false
		end

		-- Clear expired critical state
		if (state.HasCritical or state.HasBlackFlash) and currentTime >= state.CriticalExpiry then
			state.HasCritical = false
			state.HasBlackFlash = false
		end
	end
end)

--------------------------------------------------------------------------------
-- CLEANUP
--------------------------------------------------------------------------------

Players.PlayerRemoving:Connect(function(player)
	playerStates[player] = nil
end)

print("[CombatHandler] Loaded — TSB-style combat (hitstun, ragdoll, perfect block, critical hits)")
