--[[
	CombatConfig
	Central configuration for all combat values.
	Tweak numbers here instead of digging through scripts.
]]

local CombatConfig = {}

-- Health
CombatConfig.MaxHealth = 100

-- M1 Combo
CombatConfig.M1 = {
	HitCount = 4,             -- number of hits in a full combo
	Damage = { 5, 5, 5, 8 }, -- damage per hit (4th hit is stronger)
	HitCooldown = 0.35,       -- seconds between each swing
	ComboResetTime = 1.0,     -- seconds of no clicking before combo resets
	HitRange = 8,             -- studs in front of player
	HitWidth = 5,             -- studs wide
	KnockbackForce = 30,      -- only on 4th hit
	RecoveryTime = 0.5,       -- pause after full 4-hit combo
}

-- Block
CombatConfig.Block = {
	DamageReduction = 0.70,   -- 70% damage blocked
	StaminaDrainRate = 8,     -- stamina per second while blocking
	MoveSpeedMultiplier = 0.4, -- 40% move speed while blocking
	BlockBreakThreshold = 20, -- heavy abilities above this damage break block
}

-- Dash
CombatConfig.Dash = {
	Distance = 20,            -- studs
	Duration = 0.2,           -- seconds
	Cooldown = 1.5,           -- seconds
	StaminaCost = 15,
}

-- Stamina
CombatConfig.Stamina = {
	Max = 100,
	RegenRate = 12,           -- per second (pauses during block/dash)
	RegenDelay = 1.0,         -- seconds after last stamina use before regen starts
}

-- Ultimate meter
CombatConfig.Ultimate = {
	MaxCharge = 100,
	ChargePerDamageDealt = 1.0, -- 1 charge per 1 damage dealt
	ChargePerDamageTaken = 0.5, -- also gain some charge when hit
}

-- Ability cooldown tiers (characters override specific values)
CombatConfig.CooldownTiers = {
	Quick = 7,    -- Q ability (6-8s)
	Medium = 11,  -- E ability (10-12s)
	Heavy = 15,   -- R ability (14-16s)
}

-- Match settings
CombatConfig.Match = {
	RoundsToWin = 2,          -- best of 3
	RoundTimeLimit = 150,     -- 2.5 minutes per round
	SpawnProtection = 2.0,    -- seconds of invulnerability at round start
	RoundEndFreeze = 3.0,     -- seconds frozen after a KO
	CountdownTime = 3,        -- "3, 2, 1, FIGHT!" countdown
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
