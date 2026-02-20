--[[
	CombatHandler (Server)
	Authoritative combat logic. The server decides all hits, damage, and cooldowns.
	Clients send input intentions; the server validates and applies them.
	Supports both real players and BotPlayer NPCs.
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

		Cooldowns = { Q = 0, E = 0, R = 0, F = 0 },

		IsBlocking = false,
		IsDashing = false,
		IsUsingAbility = false,
		IsStunned = false,
		StunEndTime = 0,
		SpawnProtectionEnd = 0,

		LastStaminaUse = 0,
	}
end

--------------------------------------------------------------------------------
-- HELPERS: Safe remote firing (skips bots)
--------------------------------------------------------------------------------

local function isBot(player)
	return player and player.IsBot == true
end

local function safeFireClient(remote, player, ...)
	if isBot(player) then return end
	remote:FireClient(player, ...)
end

-- Fire to all real players in the game
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
	state.Cooldowns = { Q = 0, E = 0, R = 0, F = 0 }
	state.IsBlocking = false
	state.IsDashing = false
	state.IsUsingAbility = false
	state.IsStunned = false
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

local function applyDamage(attacker, victim, rawDamage, breaksBlock)
	local attackerState = getState(attacker)
	local victimState = getState(victim)
	if not attackerState or not victimState then return 0 end
	if not isAlive(victimState) then return 0 end
	if now() < victimState.SpawnProtectionEnd then return 0 end

	local actualDamage = rawDamage

	if victimState.IsBlocking then
		if breaksBlock then
			victimState.IsBlocking = false
			victimState.IsStunned = true
			victimState.StunEndTime = now() + 0.5
		else
			actualDamage = rawDamage * (1 - CombatConfig.Block.DamageReduction)
		end
	end

	victimState.Health = math.max(0, victimState.Health - actualDamage)

	attackerState.UltimateCharge = math.min(
		CombatConfig.Ultimate.MaxCharge,
		attackerState.UltimateCharge + actualDamage * CombatConfig.Ultimate.ChargePerDamageDealt
	)
	victimState.UltimateCharge = math.min(
		CombatConfig.Ultimate.MaxCharge,
		victimState.UltimateCharge + actualDamage * CombatConfig.Ultimate.ChargePerDamageTaken
	)

	-- Notify all real clients of health change
	fireAllRealClients(Remotes.Combat.HealthUpdate, victim, victimState.Health, CombatConfig.MaxHealth)
	safeFireClient(Remotes.Combat.UltimateUpdate, attacker, attackerState.UltimateCharge, CombatConfig.Ultimate.MaxCharge)
	safeFireClient(Remotes.Combat.UltimateUpdate, victim, victimState.UltimateCharge, CombatConfig.Ultimate.MaxCharge)

	-- Hit effect to all real clients
	local victimChar = victim.Character
	if victimChar then
		local hitRoot = victimChar:FindFirstChild("HumanoidRootPart")
		if hitRoot then
			fireAllRealClients(Remotes.Combat.HitEffect, hitRoot.Position, actualDamage, breaksBlock)
		end
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

local function isInRange(attacker, victim, range)
	local attackerChar = attacker.Character
	local victimChar = victim.Character
	if not attackerChar or not victimChar then return false end

	local attackerRoot = attackerChar:FindFirstChild("HumanoidRootPart")
	local victimRoot = victimChar:FindFirstChild("HumanoidRootPart")
	if not attackerRoot or not victimRoot then return false end

	return (attackerRoot.Position - victimRoot.Position).Magnitude <= range
end

local function applyKnockback(attacker, victim, force)
	local attackerChar = attacker.Character
	local victimChar = victim.Character
	if not attackerChar or not victimChar then return end

	local attackerRoot = attackerChar:FindFirstChild("HumanoidRootPart")
	local victimRoot = victimChar:FindFirstChild("HumanoidRootPart")
	if not attackerRoot or not victimRoot then return end

	local direction = (victimRoot.Position - attackerRoot.Position).Unit
	applyVelocityImpulse(victimRoot, direction * force + Vector3.new(0, force * 0.3, 0), 0.3)
end

--------------------------------------------------------------------------------
-- SHARED COMBAT LOGIC (used by both real players and bots)
--------------------------------------------------------------------------------

local function performAttack(player)
	local state = getState(player)
	if not canAct(state) then return end
	if not isAlive(state) then return end
	if state.IsBlocking then return end

	local currentTime = now()

	if currentTime - state.LastM1Time > CombatConfig.M1.ComboResetTime then
		state.ComboIndex = 0
	end
	if currentTime - state.LastM1Time < CombatConfig.M1.HitCooldown then return end

	state.ComboIndex = state.ComboIndex + 1
	state.LastM1Time = currentTime

	local hitIndex = state.ComboIndex
	local damage = CombatConfig.M1.Damage[hitIndex] or CombatConfig.M1.Damage[1]

	local opponent = getOpponent(player)
	if opponent and isInRange(player, opponent, CombatConfig.M1.HitRange) then
		applyDamage(player, opponent, damage, false)
		if hitIndex >= CombatConfig.M1.HitCount then
			applyKnockback(player, opponent, CombatConfig.M1.KnockbackForce)
		end
	end

	if hitIndex >= CombatConfig.M1.HitCount then
		state.ComboIndex = 0
		state.IsUsingAbility = true
		task.delay(CombatConfig.M1.RecoveryTime, function()
			if state then state.IsUsingAbility = false end
		end)
	end
end

local function performBlock(player, blocking)
	local state = getState(player)
	if not state then return end
	if not isAlive(state) then return end

	if blocking then
		if not canAct(state) then return end
		state.IsBlocking = true
		state.ComboIndex = 0
	else
		state.IsBlocking = false
	end
end

local function performDash(player, direction)
	local state = getState(player)
	if not canAct(state) then return end
	if not isAlive(state) then return end
	if state.IsBlocking then return end
	if state.Stamina < CombatConfig.Dash.StaminaCost then return end
	if state._dashCooldownEnd and now() < state._dashCooldownEnd then return end

	state.Stamina = state.Stamina - CombatConfig.Dash.StaminaCost
	state.LastStaminaUse = now()
	state._dashCooldownEnd = now() + CombatConfig.Dash.Cooldown
	safeFireClient(Remotes.Combat.StaminaUpdate, player, state.Stamina, CombatConfig.Stamina.Max)

	state.IsDashing = true
	local char = player.Character
	if char then
		local root = char:FindFirstChild("HumanoidRootPart")
		if root then
			local dashDir = typeof(direction) == "Vector3" and direction.Unit or root.CFrame.LookVector
			applyVelocityImpulse(root, dashDir * (CombatConfig.Dash.Distance / CombatConfig.Dash.Duration), CombatConfig.Dash.Duration)
			task.delay(CombatConfig.Dash.Duration, function()
				state.IsDashing = false
			end)
		else
			state.IsDashing = false
		end
	else
		state.IsDashing = false
	end
end

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
CombatAPI.BotAttack = performAttack
CombatAPI.BotBlock = performBlock
CombatAPI.BotDash = performDash
CombatAPI.BotUseAbility = performAbility

--------------------------------------------------------------------------------
-- REMOTE EVENT HANDLERS (real players only)
--------------------------------------------------------------------------------

Remotes.Combat.Attack.OnServerEvent:Connect(function(player)
	performAttack(player)
end)

Remotes.Combat.Block.OnServerEvent:Connect(function(player, blocking)
	performBlock(player, blocking)
end)

Remotes.Combat.Dash.OnServerEvent:Connect(function(player, direction)
	performDash(player, direction)
end)

Remotes.Combat.UseAbility.OnServerEvent:Connect(function(player, slot)
	performAbility(player, slot)
end)

--------------------------------------------------------------------------------
-- STAMINA REGENERATION
--------------------------------------------------------------------------------

game:GetService("RunService").Heartbeat:Connect(function(dt)
	local currentTime = now()

	for player, state in pairs(playerStates) do
		-- For real players, check if still connected; for bots, check character exists
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

		if state.IsBlocking then
			state.Stamina = state.Stamina - CombatConfig.Block.StaminaDrainRate * dt
			state.LastStaminaUse = currentTime
			if state.Stamina <= 0 then
				state.Stamina = 0
				state.IsBlocking = false
			end
			safeFireClient(Remotes.Combat.StaminaUpdate, player, state.Stamina, CombatConfig.Stamina.Max)
		end

		if state.IsStunned and currentTime >= state.StunEndTime then
			state.IsStunned = false
		end
	end
end)

--------------------------------------------------------------------------------
-- CLEANUP
--------------------------------------------------------------------------------

Players.PlayerRemoving:Connect(function(player)
	playerStates[player] = nil
end)

print("[CombatHandler] Loaded and registered CombatAPI (with bot support)")
