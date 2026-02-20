--[[
	CombatConfig
	Central configuration for all combat values.
	Mirrors The Strongest Battlegrounds combat feel:
	  - 4-hit M1 combo with ragdoll finisher
	  - Hitstun with deterioration
	  - Perfect block → Critical Hit → Black Flash
	  - Directional dash system (Q + WASD)
	  - Uppercut / Downslam variants
]]

local CombatConfig = {}

-- Health
CombatConfig.MaxHealth = 100

-- M1 Combo (TSB-style: 3, 3, 4, 4 = 14 total per chain)
CombatConfig.M1 = {
	HitCount = 4,
	Damage = { 3, 3, 4, 4 },
	HitCooldown = 0.35,           -- seconds between swings
	ComboResetTime = 1.0,         -- seconds idle before combo resets
	HitRange = 8,                 -- studs in front of player
	HitWidth = 5,                 -- studs wide
	KnockbackForce = 35,          -- 4th hit sends opponent flying
	RecoveryTime = 0.5,           -- pause after full 4-hit combo
	MissedFinisherStun = 0.6,     -- stun duration if 4th hit MISSES (punishment)
	CriticalDamage = 10,          -- damage for a Critical Hit (after perfect block)
	BlackFlashDamage = 18,        -- damage for a Black Flash (2nd perfect block chain)
}

-- Hitstun (each M1 hit briefly locks the opponent)
CombatConfig.Hitstun = {
	BaseDuration = 0.3,           -- base hitstun on hit 1
	Deterioration = 0.04,         -- reduce hitstun per consecutive hit in combo
	MinDuration = 0.12,           -- minimum hitstun even at long combos
}

-- Ragdoll (4th hit finisher sends opponent into ragdoll state)
CombatConfig.Ragdoll = {
	Duration = 2.0,               -- total ragdoll time
	RecoveryImmunity = 0.5,       -- stun immunity after getting up
	DashCancelDelay = 0.2,        -- can't dash-cancel for first 0.2s
	GroundBounceForce = 15,       -- small upward force on ragdoll
}

-- Block
CombatConfig.Block = {
	DamageReduction = 0.70,       -- 70% damage blocked
	StaminaDrainRate = 8,         -- stamina per second while blocking
	MoveSpeedMultiplier = 0.4,    -- 40% move speed while blocking
	BlockBreakThreshold = 20,     -- abilities above this break block
	FrontalArc = 180,             -- degrees of frontal coverage
}

-- Perfect Block (time block start within this window of an incoming hit)
CombatConfig.PerfectBlock = {
	Window = 0.15,                -- seconds to time the block
	CriticalBuffDuration = 30.0,  -- critical state lasts until ragdolled (or this timeout)
}

-- Dash (TSB-style: Q + direction, different CDs per type)
CombatConfig.Dash = {
	ForwardDistance = 18,          -- studs (~4.5 tiles)
	ForwardDuration = 0.2,
	ForwardCooldown = 5.0,        -- shared with back dash
	ForwardAttackDamage = 3,      -- forward dash ends with a hit

	BackDistance = 16,
	BackDuration = 0.2,
	BackCooldown = 5.0,           -- shared with forward dash

	SideDistance = 12,             -- slightly less than forward
	SideDuration = 0.15,
	SideCooldown = 2.0,           -- independent, much more spammable

	StaminaCost = 15,
}

-- Uppercut (hold jump during combo → 4th hit launches upward)
CombatConfig.Uppercut = {
	LaunchForce = 50,             -- upward launch power
	Damage = 4,                   -- same as normal 4th hit
}

-- Downslam (airborne 4th hit → slams opponent down, goes through block)
CombatConfig.Downslam = {
	SlamForce = 40,               -- downward slam power
	Damage = 5,                   -- slightly stronger
	BreaksBlock = true,           -- goes through block
}

-- Wall Combo (4th hit into wall → dash for bonus damage)
CombatConfig.WallCombo = {
	BonusDamage = 12,
	DashWindow = 0.4,             -- seconds after wall impact to trigger
	Cooldown = 6.0,
}

-- Stamina
CombatConfig.Stamina = {
	Max = 100,
	RegenRate = 12,               -- per second
	RegenDelay = 1.0,             -- pause after last stamina use
}

-- Ultimate meter (Awakening charge)
CombatConfig.Ultimate = {
	MaxCharge = 100,
	ChargePerDamageDealt = 1.0,
	ChargePerDamageTaken = 0.5,
}

-- Ability cooldown tiers (characters override specific values)
CombatConfig.CooldownTiers = {
	Quick = 7,
	Medium = 11,
	Heavy = 15,
}

-- Match settings
CombatConfig.Match = {
	RoundsToWin = 2,
	RoundTimeLimit = 150,
	SpawnProtection = 2.0,
	RoundEndFreeze = 3.0,
	CountdownTime = 3,
}

-- Ranking
CombatConfig.Ranking = {
	StartingElo = 1000,
	WinBase = 25,
	LossBase = 20,
	Tiers = {
		{ Name = "Bronze",      MinElo = 0 },
		{ Name = "Silver",      MinElo = 1100 },
		{ Name = "Gold",        MinElo = 1250 },
		{ Name = "Platinum",    MinElo = 1400 },
		{ Name = "Diamond",     MinElo = 1600 },
		{ Name = "Master",      MinElo = 1850 },
		{ Name = "Grand Ninja", MinElo = 2100 },
	},
}

return CombatConfig
