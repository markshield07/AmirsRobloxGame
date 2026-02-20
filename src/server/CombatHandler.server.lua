--[[
	CombatHandler (Server)
	Authoritative combat logic. The server decides all hits, damage, and cooldowns.
	Clients send input intentions; the server validates and applies them.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatConfig = require(Shared:WaitForChild("CombatConfig"))
local NinjaData = require(Shared:WaitForChild("NinjaData"))
local Remotes = require(Shared:WaitForChild("Remotes"))

--------------------------------------------------------------------------------
-- PLAYER STATE TRACKING
--------------------------------------------------------------------------------

-- Holds combat state for every player currently in a match
local playerStates = {} -- [Player] = { health, stamina, combo, cooldowns, ... }

-- Create a fresh combat state for a player
local function createPlayerState(player, ninjaKey)
	local ninja = NinjaData.GetNinja(ninjaKey) or NinjaData.FlameShadow

	return {
		Ninja = ninjaKey,
		NinjaInfo = ninja,

		-- Vitals
		Health = CombatConfig.MaxHealth,
		Stamina = CombatConfig.Stamina.Max,
		UltimateCharge = 0,

		-- M1 combo tracking
		ComboIndex = 0,             -- which hit we're on (0 = ready)
		LastM1Time = 0,

		-- Ability cooldowns: [abilitySlot] = time when usable again
		Cooldowns = { Q = 0, E = 0, R = 0, F = 0 },

		-- Status flags
		IsBlocking = false,
		IsDashing = false,
		IsUsingAbility = false,
		IsStunned = false,
		StunEndTime = 0,
		SpawnProtectionEnd = 0,

		-- Stamina regen tracking
		LastStaminaUse = 0,
	}
end

-- Public: initialize a player for combat
function InitPlayerCombat(player, ninjaKey)
	playerStates[player] = createPlayerState(player, ninjaKey)
	-- Send initial health/stamina to client
	Remotes.Combat.HealthUpdate:FireClient(player, player, CombatConfig.MaxHealth, CombatConfig.MaxHealth)
	Remotes.Combat.StaminaUpdate:FireClient(player, CombatConfig.Stamina.Max, CombatConfig.Stamina.Max)
	Remotes.Combat.UltimateUpdate:FireClient(player, 0, CombatConfig.Ultimate.MaxCharge)
end

-- Public: reset health/stamina for a new round (keep same ninja)
function ResetPlayerCombat(player)
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
	state.SpawnProtectionEnd = tick() + CombatConfig.Match.SpawnProtection

	Remotes.Combat.HealthUpdate:FireClient(player, player, CombatConfig.MaxHealth, CombatConfig.MaxHealth)
	Remotes.Combat.StaminaUpdate:FireClient(player, CombatConfig.Stamina.Max, CombatConfig.Stamina.Max)
	Remotes.Combat.UltimateUpdate:FireClient(player, 0, CombatConfig.Ultimate.MaxCharge)
end

function RemovePlayerCombat(player)
	playerStates[player] = nil
end

-- Make functions accessible to MatchManager via a shared table on the server
local CombatAPI = {
	InitPlayerCombat = InitPlayerCombat,
	ResetPlayerCombat = ResetPlayerCombat,
	RemovePlayerCombat = RemovePlayerCombat,
}

-- Store in a BindableEvent value so MatchManager can access it
local apiHolder = Instance.new("BindableEvent")
apiHolder.Name = "CombatAPI"
apiHolder.Parent = script
-- We'll use module-style access via _G for simplicity in V1
-- (In production, use a proper module loader)
_G.CombatAPI = CombatAPI

--------------------------------------------------------------------------------
-- HELPERS
--------------------------------------------------------------------------------

local function now()
	return tick()
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

-- Find opponent in the match (simple 2-player approach)
local function getOpponent(player)
	for otherPlayer, _ in pairs(playerStates) do
		if otherPlayer ~= player then
			return otherPlayer
		end
	end
	return nil
end

-- Apply damage to a player (server authoritative)
local function applyDamage(attacker, victim, rawDamage, breaksBlock)
	local attackerState = getState(attacker)
	local victimState = getState(victim)
	if not attackerState or not victimState then return 0 end
	if not isAlive(victimState) then return 0 end
	if now() < victimState.SpawnProtectionEnd then return 0 end

	local actualDamage = rawDamage

	-- Check block
	if victimState.IsBlocking then
		if breaksBlock then
			-- Block broken! Apply full damage and stun
			victimState.IsBlocking = false
			victimState.IsStunned = true
			victimState.StunEndTime = now() + 0.5
		else
			actualDamage = rawDamage * (1 - CombatConfig.Block.DamageReduction)
		end
	end

	-- Apply damage
	victimState.Health = math.max(0, victimState.Health - actualDamage)

	-- Charge ultimate for attacker
	attackerState.UltimateCharge = math.min(
		CombatConfig.Ultimate.MaxCharge,
		attackerState.UltimateCharge + actualDamage * CombatConfig.Ultimate.ChargePerDamageDealt
	)

	-- Charge ultimate for victim (getting hit also charges a bit)
	victimState.UltimateCharge = math.min(
		CombatConfig.Ultimate.MaxCharge,
		victimState.UltimateCharge + actualDamage * CombatConfig.Ultimate.ChargePerDamageTaken
	)

	-- Notify both players of health change
	for _, p in pairs(Players:GetPlayers()) do
		Remotes.Combat.HealthUpdate:FireClient(p, victim, victimState.Health, CombatConfig.MaxHealth)
	end
	Remotes.Combat.UltimateUpdate:FireClient(attacker, attackerState.UltimateCharge, CombatConfig.Ultimate.MaxCharge)
	Remotes.Combat.UltimateUpdate:FireClient(victim, victimState.UltimateCharge, CombatConfig.Ultimate.MaxCharge)

	-- Send hit effect to all clients
	local victimChar = victim.Character
	if victimChar then
		local hitPos = victimChar:FindFirstChild("HumanoidRootPart") and victimChar.HumanoidRootPart.Position
		for _, p in pairs(Players:GetPlayers()) do
			Remotes.Combat.HitEffect:FireClient(p, hitPos, actualDamage, breaksBlock)
		end
	end

	-- Check for KO
	if victimState.Health <= 0 then
		-- Fire a round end signal (MatchManager listens for this)
		local matchEndEvent = game:GetService("ServerScriptService"):FindFirstChild("MatchKOEvent", true)
		if matchEndEvent then
			matchEndEvent:Fire(attacker, victim)
		end
	end

	return actualDamage
end

-- Check if target is in range of attacker
local function isInRange(attacker, victim, range)
	local attackerChar = attacker.Character
	local victimChar = victim.Character
	if not attackerChar or not victimChar then return false end

	local attackerRoot = attackerChar:FindFirstChild("HumanoidRootPart")
	local victimRoot = victimChar:FindFirstChild("HumanoidRootPart")
	if not attackerRoot or not victimRoot then return false end

	local distance = (attackerRoot.Position - victimRoot.Position).Magnitude
	return distance <= range
end

-- Apply knockback to a character
local function applyKnockback(attacker, victim, force)
	local attackerChar = attacker.Character
	local victimChar = victim.Character
	if not attackerChar or not victimChar then return end

	local attackerRoot = attackerChar:FindFirstChild("HumanoidRootPart")
	local victimRoot = victimChar:FindFirstChild("HumanoidRootPart")
	if not attackerRoot or not victimRoot then return end

	local direction = (victimRoot.Position - attackerRoot.Position).Unit
	-- Apply a short velocity push
	local bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.Velocity = direction * force + Vector3.new(0, force * 0.3, 0)
	bodyVelocity.MaxForce = Vector3.new(50000, 50000, 50000)
	bodyVelocity.P = 10000
	bodyVelocity.Parent = victimRoot

	-- Clean up after a short time
	task.delay(0.3, function()
		if bodyVelocity and bodyVelocity.Parent then
			bodyVelocity:Destroy()
		end
	end)
end

--------------------------------------------------------------------------------
-- M1 ATTACK HANDLER
--------------------------------------------------------------------------------

Remotes.Combat.Attack.OnServerEvent:Connect(function(player)
	local state = getState(player)
	if not canAct(state) then return end
	if not isAlive(state) then return end
	if state.IsBlocking then return end

	local currentTime = now()

	-- Reset combo if too much time passed
	if currentTime - state.LastM1Time > CombatConfig.M1.ComboResetTime then
		state.ComboIndex = 0
	end

	-- Enforce hit cooldown
	if currentTime - state.LastM1Time < CombatConfig.M1.HitCooldown then
		return
	end

	-- Advance combo
	state.ComboIndex = state.ComboIndex + 1
	state.LastM1Time = currentTime

	local hitIndex = state.ComboIndex
	local damage = CombatConfig.M1.Damage[hitIndex] or CombatConfig.M1.Damage[1]

	-- Find opponent and check range
	local opponent = getOpponent(player)
	if opponent and isInRange(player, opponent, CombatConfig.M1.HitRange) then
		applyDamage(player, opponent, damage, false)

		-- Knockback on final hit
		if hitIndex >= CombatConfig.M1.HitCount then
			applyKnockback(player, opponent, CombatConfig.M1.KnockbackForce)
		end
	end

	-- Reset combo after full chain
	if hitIndex >= CombatConfig.M1.HitCount then
		state.ComboIndex = 0
		state.IsUsingAbility = true -- brief recovery
		task.delay(CombatConfig.M1.RecoveryTime, function()
			if state then
				state.IsUsingAbility = false
			end
		end)
	end
end)

--------------------------------------------------------------------------------
-- BLOCK HANDLER
--------------------------------------------------------------------------------

Remotes.Combat.Block.OnServerEvent:Connect(function(player, isBlocking)
	local state = getState(player)
	if not state then return end
	if not isAlive(state) then return end

	if isBlocking then
		if not canAct(state) then return end
		state.IsBlocking = true
		state.ComboIndex = 0 -- cancel combo
	else
		state.IsBlocking = false
	end
end)

--------------------------------------------------------------------------------
-- DASH HANDLER
--------------------------------------------------------------------------------

Remotes.Combat.Dash.OnServerEvent:Connect(function(player, direction)
	local state = getState(player)
	if not canAct(state) then return end
	if not isAlive(state) then return end
	if state.IsBlocking then return end

	-- Check stamina
	if state.Stamina < CombatConfig.Dash.StaminaCost then return end

	-- Check cooldown (use simple time tracking)
	-- We'll store dash cooldown in the state
	if state._dashCooldownEnd and now() < state._dashCooldownEnd then return end

	-- Consume stamina
	state.Stamina = state.Stamina - CombatConfig.Dash.StaminaCost
	state.LastStaminaUse = now()
	state._dashCooldownEnd = now() + CombatConfig.Dash.Cooldown

	Remotes.Combat.StaminaUpdate:FireClient(player, state.Stamina, CombatConfig.Stamina.Max)

	-- Apply dash movement on server
	state.IsDashing = true
	local char = player.Character
	if char then
		local root = char:FindFirstChild("HumanoidRootPart")
		if root then
			local dashDir = typeof(direction) == "Vector3" and direction.Unit or root.CFrame.LookVector
			local bodyVelocity = Instance.new("BodyVelocity")
			bodyVelocity.Velocity = dashDir * (CombatConfig.Dash.Distance / CombatConfig.Dash.Duration)
			bodyVelocity.MaxForce = Vector3.new(50000, 0, 50000)
			bodyVelocity.P = 10000
			bodyVelocity.Parent = root

			task.delay(CombatConfig.Dash.Duration, function()
				if bodyVelocity and bodyVelocity.Parent then
					bodyVelocity:Destroy()
				end
				state.IsDashing = false
			end)
		else
			state.IsDashing = false
		end
	else
		state.IsDashing = false
	end
end)

--------------------------------------------------------------------------------
-- ABILITY HANDLER
--------------------------------------------------------------------------------

Remotes.Combat.UseAbility.OnServerEvent:Connect(function(player, slot)
	local state = getState(player)
	if not canAct(state) then return end
	if not isAlive(state) then return end
	if state.IsBlocking then return end

	-- Validate slot
	if slot ~= "Q" and slot ~= "E" and slot ~= "R" and slot ~= "F" then return end

	-- Check ultimate meter for F
	if slot == "F" then
		if state.UltimateCharge < CombatConfig.Ultimate.MaxCharge then return end
	end

	-- Check cooldown
	if now() < state.Cooldowns[slot] then return end

	-- Get ability data
	local ninjaInfo = state.NinjaInfo
	if not ninjaInfo then return end
	local ability = ninjaInfo.Abilities[slot]
	if not ability then return end

	-- Set cooldown
	local cooldown = ability.Cooldown or 0
	state.Cooldowns[slot] = now() + cooldown
	Remotes.Combat.CooldownStart:FireClient(player, slot, cooldown)

	-- Consume ultimate charge for F
	if slot == "F" then
		state.UltimateCharge = 0
		Remotes.Combat.UltimateUpdate:FireClient(player, 0, CombatConfig.Ultimate.MaxCharge)
	end

	-- Mark as using ability briefly
	state.IsUsingAbility = true

	-- Find opponent
	local opponent = getOpponent(player)

	-- Execute ability logic based on type
	-- (This is simplified V1 — each ability just checks range and applies damage)
	local damage = ability.Damage or 0
	local range = ability.Range or ability.DashDistance or ability.TeleportDistance or ability.MaxRange or 15
	local breaksBlock = ability.BreaksBlock or false

	if opponent and damage > 0 and isInRange(player, opponent, range) then
		applyDamage(player, opponent, damage, breaksBlock)

		-- Apply knockback if ability has launch force
		if ability.LaunchForce then
			applyKnockback(player, opponent, ability.LaunchForce)
		end

		-- Apply stun if ability has stun
		if ability.StunDuration then
			local opponentState = getState(opponent)
			if opponentState then
				opponentState.IsStunned = true
				opponentState.StunEndTime = now() + ability.StunDuration
			end
		end
	end

	-- Recovery time (brief lockout after ability)
	local recoveryTime = 0.5
	task.delay(recoveryTime, function()
		if state then
			state.IsUsingAbility = false
		end
	end)
end)

--------------------------------------------------------------------------------
-- STAMINA REGENERATION (runs every frame via Heartbeat)
--------------------------------------------------------------------------------

game:GetService("RunService").Heartbeat:Connect(function(dt)
	local currentTime = now()

	for player, state in pairs(playerStates) do
		if not player.Parent then
			-- Player left, clean up
			playerStates[player] = nil
			continue
		end

		-- Regen stamina if not blocking/dashing and delay has passed
		if not state.IsBlocking and not state.IsDashing then
			if currentTime - state.LastStaminaUse >= CombatConfig.Stamina.RegenDelay then
				if state.Stamina < CombatConfig.Stamina.Max then
					state.Stamina = math.min(
						CombatConfig.Stamina.Max,
						state.Stamina + CombatConfig.Stamina.RegenRate * dt
					)
					Remotes.Combat.StaminaUpdate:FireClient(player, state.Stamina, CombatConfig.Stamina.Max)
				end
			end
		end

		-- Drain stamina while blocking
		if state.IsBlocking then
			state.Stamina = state.Stamina - CombatConfig.Block.StaminaDrainRate * dt
			state.LastStaminaUse = currentTime
			if state.Stamina <= 0 then
				state.Stamina = 0
				state.IsBlocking = false -- forced block break
			end
			Remotes.Combat.StaminaUpdate:FireClient(player, state.Stamina, CombatConfig.Stamina.Max)
		end

		-- Clear stun if expired
		if state.IsStunned and currentTime >= state.StunEndTime then
			state.IsStunned = false
		end
	end
end)

--------------------------------------------------------------------------------
-- CLEANUP ON PLAYER LEAVE
--------------------------------------------------------------------------------

Players.PlayerRemoving:Connect(function(player)
	playerStates[player] = nil
end)

print("[CombatHandler] Loaded")
