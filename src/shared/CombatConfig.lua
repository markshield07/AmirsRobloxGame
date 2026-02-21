--[[
	CombatConfig
	Central configuration for The Strongest Battlegrounds replica.
	  - Free-for-all open-world combat
	  - 4-hit M1 combo with ragdoll finisher (character-specific speeds)
	  - Blocking (F key), Evasive dodge (Q key)
	  - Character moves (E/R/T keys), Awakening (G key)
	  - Health regeneration out of combat
	  - Perfect block → Critical Hit → Black Flash
]]

local CombatConfig = {}

-- Health
CombatConfig.MaxHealth = 100
CombatConfig.HealthRegen = {
	Rate = 2,                     -- HP per second when regenerating
	Delay = 5.0,                  -- seconds after last damage before regen starts
}

-- M1 Combo (base values — characters can override HitCooldown via M1Speed)
CombatConfig.M1 = {
	HitCount = 4,
	Damage = { 3, 3, 4, 4 },     -- 14 total per chain
	BaseHitCooldown = 0.35,       -- default swing speed (characters override)
	ComboResetTime = 1.0,
	HitRange = 8,
	HitWidth = 5,
	KnockbackForce = 35,
	RecoveryTime = 0.5,
	MissedFinisherStun = 0.6,
	CriticalDamage = 10,
	BlackFlashDamage = 18,
}

-- Hitstun
CombatConfig.Hitstun = {
	BaseDuration = 0.3,
	Deterioration = 0.04,
	MinDuration = 0.12,
}

-- Ragdoll
CombatConfig.Ragdoll = {
	Duration = 2.0,
	RecoveryImmunity = 0.5,
	DashCancelDelay = 0.2,
	GroundBounceForce = 15,
}

-- Block (F key — hold to block)
CombatConfig.Block = {
	DamageReduction = 0.70,
	StaminaDrainRate = 8,
	MoveSpeedMultiplier = 0.4,
	BlockBreakThreshold = 20,
	FrontalArc = 180,
}

-- Perfect Block
CombatConfig.PerfectBlock = {
	Window = 0.15,
	CriticalBuffDuration = 30.0,
}

-- Evasive (Q key — quick dodge/sidestep, like TSB)
CombatConfig.Evasive = {
	Distance = 10,
	Duration = 0.18,
	Cooldown = 3.5,
	IFrames = 0.15,               -- invulnerability during dodge
}

-- Dash (double-tap direction or shift+direction)
CombatConfig.Dash = {
	ForwardDistance = 18,
	ForwardDuration = 0.2,
	ForwardCooldown = 5.0,
	ForwardAttackDamage = 3,

	BackDistance = 16,
	BackDuration = 0.2,
	BackCooldown = 5.0,

	SideDistance = 12,
	SideDuration = 0.15,
	SideCooldown = 2.0,

	StaminaCost = 15,
}

-- Uppercut (hold jump during combo → 4th hit launches)
CombatConfig.Uppercut = {
	LaunchForce = 50,
	Damage = 4,
}

-- Downslam (airborne 4th hit)
CombatConfig.Downslam = {
	SlamForce = 40,
	Damage = 5,
	BreaksBlock = true,
}

-- Stamina
CombatConfig.Stamina = {
	Max = 100,
	RegenRate = 12,
	RegenDelay = 1.0,
}

-- Awakening (transformation system — TSB's signature mechanic)
CombatConfig.Awakening = {
	ChargeRequired = 100,
	ChargePerDamageDealt = 1.5,
	ChargePerDamageTaken = 0.8,
	Duration = 45,                -- seconds (0 = until depleted for some chars)
}

-- Respawn (free-for-all — no rounds, just respawn)
CombatConfig.Respawn = {
	Delay = 5.0,                  -- seconds before respawn
	SpawnProtection = 3.0,        -- invulnerability after respawn
}

-- Movement
CombatConfig.Movement = {
	WalkSpeed = 16,
	SprintSpeed = 24,
}

return CombatConfig
