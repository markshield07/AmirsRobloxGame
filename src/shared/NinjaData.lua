--[[
	NinjaData
	Defines every playable ninja: abilities, cooldowns, damage values.
	Add new ninjas by copying an existing entry and tweaking values.
]]

local NinjaData = {}

--------------------------------------------------------------------------------
-- FLAME SHADOW  (Fire Element — Aggressive / Combo pressure)
--------------------------------------------------------------------------------
NinjaData.FlameShadow = {
	DisplayName = "Flame Shadow",
	Element = "Fire",
	Colors = {
		Primary = Color3.fromRGB(255, 80, 20),   -- orange-red
		Secondary = Color3.fromRGB(255, 200, 50), -- flame yellow
	},

	Abilities = {
		Q = {
			Name = "Fire Dash",
			Description = "Quick dash forward with flame trail. Light damage.",
			Cooldown = 7,
			Damage = 10,
			DashDistance = 18,
			DashDuration = 0.25,
			TrailDuration = 0.5,
		},
		E = {
			Name = "Flame Slash",
			Description = "Wide arc slash that burns over time.",
			Cooldown = 11,
			Damage = 15,
			BurnDamage = 3,       -- damage per tick
			BurnTicks = 3,        -- number of ticks
			BurnInterval = 0.8,   -- seconds between ticks
			Range = 10,
			ArcAngle = 120,       -- degrees
		},
		R = {
			Name = "Inferno Trap",
			Description = "Throws fire bomb that explodes after 1.5 seconds.",
			Cooldown = 15,
			Damage = 22,
			ThrowRange = 25,
			ExplosionDelay = 1.5,
			ExplosionRadius = 8,
			BreaksBlock = true,
		},
		F = {
			Name = "Crimson Cyclone",
			Description = "Spinning flame attack that launches opponent.",
			Damage = 30,
			LaunchForce = 60,
			SpinDuration = 1.0,
			HitRadius = 10,
		},
	},
}

--------------------------------------------------------------------------------
-- MIST BLADE  (Water Element — Speed + Evasion)
--------------------------------------------------------------------------------
NinjaData.MistBlade = {
	DisplayName = "Mist Blade",
	Element = "Water",
	Colors = {
		Primary = Color3.fromRGB(30, 144, 255),  -- ocean blue
		Secondary = Color3.fromRGB(150, 220, 255), -- light cyan
	},

	Abilities = {
		Q = {
			Name = "Water Step",
			Description = "Short teleport dash.",
			Cooldown = 6,
			Damage = 0,          -- purely movement
			TeleportDistance = 20,
			IFrames = 0.3,       -- seconds of invulnerability during teleport
		},
		E = {
			Name = "Tidal Slice",
			Description = "Fast long-range wave slash.",
			Cooldown = 10,
			Damage = 14,
			Range = 22,
			ProjectileSpeed = 80,
			SliceWidth = 6,
		},
		R = {
			Name = "Mist Veil",
			Description = "Temporary blur effect, harder to hit.",
			Cooldown = 14,
			Damage = 0,
			Duration = 3.0,
			DodgeChance = 0.40,  -- 40% chance attacks miss
			MoveSpeedBoost = 1.3,
		},
		F = {
			Name = "Raging Current",
			Description = "Multi-hit dash combo.",
			Damage = 8,          -- per hit
			HitCount = 5,
			DashDistance = 25,
			DashDuration = 1.2,
		},
	},
}

--------------------------------------------------------------------------------
-- STORM FIST  (Lightning Element — Burst damage / Stun pressure)
--------------------------------------------------------------------------------
NinjaData.StormFist = {
	DisplayName = "Storm Fist",
	Element = "Lightning",
	Colors = {
		Primary = Color3.fromRGB(255, 230, 50),   -- electric yellow
		Secondary = Color3.fromRGB(100, 180, 255), -- electric blue
	},

	Abilities = {
		Q = {
			Name = "Thunder Jab",
			Description = "Fast stun strike.",
			Cooldown = 8,
			Damage = 8,
			StunDuration = 0.6,
			Range = 7,
		},
		E = {
			Name = "Lightning Strike",
			Description = "Call down bolt from sky (aimed skillshot).",
			Cooldown = 12,
			Damage = 20,
			AimTime = 0.8,       -- time to place targeting marker
			StrikeDelay = 0.5,   -- delay after placing marker
			StrikeRadius = 6,
			BreaksBlock = true,
		},
		R = {
			Name = "Static Field",
			Description = "Small AOE that slows opponent.",
			Cooldown = 14,
			Damage = 10,
			Radius = 12,
			SlowAmount = 0.5,    -- 50% move speed
			SlowDuration = 2.5,
			FieldDuration = 3.0,
		},
		F = {
			Name = "Storm Breaker",
			Description = "Massive slam + lightning explosion.",
			Damage = 35,
			SlamRange = 10,
			ExplosionRadius = 14,
			StunDuration = 1.0,
		},
	},
}

--------------------------------------------------------------------------------
-- SHADOW FANG  (Shadow Element — Counter / Mind games)
--------------------------------------------------------------------------------
NinjaData.ShadowFang = {
	DisplayName = "Shadow Fang",
	Element = "Shadow",
	Colors = {
		Primary = Color3.fromRGB(100, 50, 160),  -- dark purple
		Secondary = Color3.fromRGB(60, 60, 70),  -- dark grey
	},

	Abilities = {
		Q = {
			Name = "Shadow Step",
			Description = "Teleport behind opponent (short range).",
			Cooldown = 7,
			Damage = 0,
			TeleportBehind = true,
			MaxRange = 20,       -- must be within this range to teleport
			IFrames = 0.2,
		},
		E = {
			Name = "Dark Spike",
			Description = "Shadow spikes from ground.",
			Cooldown = 11,
			Damage = 16,
			Range = 18,
			SpikeWidth = 8,
			LaunchForce = 20,
		},
		R = {
			Name = "Counter Guard",
			Description = "Blocks next attack and auto-strikes back.",
			Cooldown = 16,
			CounterDamage = 18,
			CounterWindow = 1.5, -- seconds the counter is active
			CounterStun = 0.8,
		},
		F = {
			Name = "Nightfall Execution",
			Description = "Cinematic heavy strike finisher.",
			Damage = 32,
			DashRange = 12,
			CinematicDuration = 1.5, -- brief freeze-frame effect
		},
	},
}

-- Helper: get a ninja by key name
function NinjaData.GetNinja(name: string)
	return NinjaData[name]
end

-- Helper: list all ninja key names
function NinjaData.GetAllNinjaNames(): { string }
	local names = {}
	for key, value in pairs(NinjaData) do
		if type(value) == "table" and value.DisplayName then
			table.insert(names, key)
		end
	end
	return names
end

return NinjaData
