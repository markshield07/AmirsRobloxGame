--[[
	CharacterData
	Defines all playable characters for The Strongest Battlegrounds.
	Based on One Punch Man anime — each character has:
	  - 4 base moves (E/R/T/G slots)
	  - Unique M1 speed
	  - Awakening mode with enhanced/new moves
	  - Passive abilities
]]

local CharacterData = {}

--------------------------------------------------------------------------------
-- THE STRONGEST HERO  (Saitama — balanced all-rounder, devastating power)
--------------------------------------------------------------------------------
CharacterData.StrongestHero = {
	DisplayName = "The Strongest Hero",
	Description = "A balanced fighter with devastating single-hit power. Simple but deadly.",
	Tier = "Free",
	Colors = {
		Primary = Color3.fromRGB(255, 220, 50),   -- yellow (cape/suit accent)
		Secondary = Color3.fromRGB(255, 255, 255), -- white
	},
	BodyColor = Color3.fromRGB(255, 220, 50),

	M1Speed = 0.35,    -- standard M1 speed (2nd fastest in game)

	Moves = {
		E = {
			Name = "Normal Punch",
			Description = "A basic close-range punch. Fast startup, moderate damage.",
			Cooldown = 6,
			Damage = 8,
			Range = 9,
			Knockback = 15,
			StartupFrames = 0.1,
		},
		R = {
			Name = "Consecutive Punches",
			Description = "Quick flurry of punches. Multi-hit, easy to combo into.",
			Cooldown = 10,
			Damage = 3,        -- per hit
			HitCount = 5,      -- 15 total
			Range = 8,
			Duration = 0.8,
		},
		T = {
			Name = "Shove",
			Description = "Knocks opponent back to create space. Fast, low damage.",
			Cooldown = 8,
			Damage = 5,
			Range = 7,
			Knockback = 35,
			BreaksBlock = false,
		},
		G = {
			Name = "Uppercut",
			Description = "Launches enemy skyward for follow-up aerials.",
			Cooldown = 12,
			Damage = 10,
			Range = 7,
			LaunchForce = 55,
		},
	},

	Awakening = {
		Name = "Serious Mode",
		Duration = 0,          -- lasts forever, but each move is single-use
		Moves = {
			E = {
				Name = "Death Counter",
				Description = "High-damage reversal. Punish any attack.",
				Cooldown = 0,   -- single use
				Damage = 25,
				IsCounter = true,
				CounterWindow = 1.0,
			},
			R = {
				Name = "Table Flip",
				Description = "Massive AoE knockback. Clears the field.",
				Cooldown = 0,
				Damage = 15,
				Radius = 18,
				Knockback = 50,
			},
			T = {
				Name = "Serious Punch",
				Description = "One-shot potential. Devastating single hit.",
				Cooldown = 0,
				Damage = 50,
				Range = 12,
				Knockback = 60,
				BreaksBlock = true,
			},
		},
	},
}

--------------------------------------------------------------------------------
-- HERO HUNTER  (Garou — grab-based offense, counters, armor)
--------------------------------------------------------------------------------
CharacterData.HeroHunter = {
	DisplayName = "Hero Hunter",
	Description = "Grab-based offense with precise counters. Armor on most moves.",
	Tier = "Free",
	Colors = {
		Primary = Color3.fromRGB(200, 50, 50),    -- red/dark
		Secondary = Color3.fromRGB(80, 80, 90),    -- dark grey
	},
	BodyColor = Color3.fromRGB(200, 50, 50),

	M1Speed = 0.38,    -- slightly slower but hits harder

	Moves = {
		E = {
			Name = "Flowing Water Fist",
			Description = "Close-range combo. Has armor during startup.",
			Cooldown = 7,
			Damage = 10,
			Range = 8,
			HasArmor = true,
			Knockback = 10,
		},
		R = {
			Name = "Prey's Peril",
			Description = "Counter move. Deflects attacks or knocks opponents away.",
			Cooldown = 9,
			Damage = 12,
			IsCounter = true,
			CounterWindow = 1.2,
			Knockback = 25,
		},
		T = {
			Name = "Water Stream Rock Smashing Fist",
			Description = "Grab + rapid hits. Uncounterable.",
			Cooldown = 12,
			Damage = 4,
			HitCount = 4,      -- 16 total
			Range = 7,
			IsGrab = true,
			Duration = 1.0,
		},
		G = {
			Name = "Cross Fang Dragon Slayer",
			Description = "Massive burst combo. High damage finisher.",
			Cooldown = 15,
			Damage = 22,
			Range = 9,
			Knockback = 40,
			BreaksBlock = true,
		},
	},

	Awakening = {
		Name = "Monster Form",
		Duration = 40,
		DamageMultiplier = 1.3,
		SpeedMultiplier = 1.15,
		Moves = {
			E = {
				Name = "Monster Calamity Fist",
				Description = "Enhanced version. Bigger range, more damage.",
				Cooldown = 6,
				Damage = 15,
				Range = 10,
				HasArmor = true,
			},
			R = {
				Name = "God Slayer Fist",
				Description = "Unblockable grab attack.",
				Cooldown = 10,
				Damage = 20,
				Range = 8,
				IsGrab = true,
				BreaksBlock = true,
			},
		},
	},
}

--------------------------------------------------------------------------------
-- DESTRUCTIVE CYBORG  (Genos — mid-range, explosives, high damage output)
--------------------------------------------------------------------------------
CharacterData.DestructiveCyborg = {
	DisplayName = "Destructive Cyborg",
	Description = "Mid-range explosive fighter. Highest raw damage output.",
	Tier = "Free",
	Colors = {
		Primary = Color3.fromRGB(255, 180, 30),   -- orange/gold
		Secondary = Color3.fromRGB(40, 40, 45),    -- black metal
	},
	BodyColor = Color3.fromRGB(255, 180, 30),

	M1Speed = 0.32,    -- fastest M1 in game

	Moves = {
		E = {
			Name = "Incinerate",
			Description = "Fire blast projectile. Good range, moderate damage.",
			Cooldown = 7,
			Damage = 12,
			Range = 25,
			ProjectileSpeed = 80,
			IsProjectile = true,
		},
		R = {
			Name = "Machine Gun Blows",
			Description = "Rapid-fire punches. High damage, close range.",
			Cooldown = 10,
			Damage = 3,
			HitCount = 6,      -- 18 total
			Range = 8,
			Duration = 0.9,
		},
		T = {
			Name = "Rocket Stomp",
			Description = "Aerial stomp that creates shockwave. AoE damage.",
			Cooldown = 12,
			Damage = 14,
			Radius = 10,
			LaunchForce = -40,   -- slams down
			BreaksBlock = true,
		},
		G = {
			Name = "Full Power Incineration",
			Description = "Massive beam attack. Devastating range and damage.",
			Cooldown = 18,
			Damage = 30,
			Range = 35,
			IsProjectile = true,
			ProjectileWidth = 8,
			Duration = 1.5,
		},
	},

	Awakening = {
		Name = "10 Second Mode",
		Duration = 10,             -- short but powerful
		DamageMultiplier = 1.5,
		SpeedMultiplier = 1.3,
		CooldownReset = true,      -- all cooldowns reset on activation
	},
}

--------------------------------------------------------------------------------
-- DEADLY NINJA  (Sonic — speed, teleportation, hit-and-run)
--------------------------------------------------------------------------------
CharacterData.DeadlyNinja = {
	DisplayName = "Deadly Ninja",
	Description = "Lightning-fast with teleportation. Low defense, extreme speed.",
	Tier = "Free",
	Colors = {
		Primary = Color3.fromRGB(80, 50, 160),     -- purple
		Secondary = Color3.fromRGB(200, 200, 210),  -- silver
	},
	BodyColor = Color3.fromRGB(80, 50, 160),

	M1Speed = 0.30,    -- fastest M1 speed in the game

	Moves = {
		E = {
			Name = "Wind Blade Kick",
			Description = "Quick dashing kick. Teleports behind on hit.",
			Cooldown = 6,
			Damage = 8,
			Range = 15,
			TeleportBehind = true,
			DashDistance = 15,
		},
		R = {
			Name = "Ten Shadows Burial",
			Description = "Creates afterimages that attack from all sides.",
			Cooldown = 11,
			Damage = 5,
			HitCount = 3,      -- 15 total
			Range = 10,
			Duration = 0.8,
		},
		T = {
			Name = "Hail of Carnage",
			Description = "Throws barrage of kunai. Mid-range poke.",
			Cooldown = 9,
			Damage = 2,
			HitCount = 6,      -- 12 total
			Range = 20,
			IsProjectile = true,
			Duration = 0.6,
		},
		G = {
			Name = "Ultimate Sonic Speed",
			Description = "Vanishes and delivers rapid multi-hit combo.",
			Cooldown = 16,
			Damage = 4,
			HitCount = 7,      -- 28 total
			Range = 12,
			Duration = 1.2,
			TeleportBehind = true,
		},
	},

	Awakening = {
		Name = "Speed-o'-Sound",
		Duration = 35,
		SpeedMultiplier = 1.5,
		M1SpeedMultiplier = 0.75,   -- even faster M1s
	},
}

--------------------------------------------------------------------------------
-- BLADE MASTER  (Atomic Samurai — sword combat, precision, counters)
--------------------------------------------------------------------------------
CharacterData.BladeMaster = {
	DisplayName = "Blade Master",
	Description = "Precise sword combat with devastating counter mechanics.",
	Tier = "Free",
	Colors = {
		Primary = Color3.fromRGB(180, 180, 190),   -- silver blade
		Secondary = Color3.fromRGB(50, 120, 50),    -- green gi
	},
	BodyColor = Color3.fromRGB(50, 120, 50),

	M1Speed = 0.33,

	Moves = {
		E = {
			Name = "Quick Slice",
			Description = "Fast single-target slash. Low cooldown.",
			Cooldown = 5,
			Damage = 9,
			Range = 10,
			Knockback = 8,
		},
		R = {
			Name = "Atmos Cleave",
			Description = "AoE ground slash. Hits everyone in front.",
			Cooldown = 10,
			Damage = 14,
			Range = 12,
			ArcAngle = 120,
		},
		T = {
			Name = "Split Second Counter",
			Description = "Counter stance. Punishes any attack with devastating slash.",
			Cooldown = 14,
			Damage = 18,
			IsCounter = true,
			CounterWindow = 1.0,
			Knockback = 30,
		},
		G = {
			Name = "Atomic Slash",
			Description = "Hundreds of slashes in an instant. Massive damage.",
			Cooldown = 18,
			Damage = 35,
			Range = 12,
			Duration = 1.5,
			BreaksBlock = true,
		},
	},

	Awakening = {
		Name = "Focused Atomic Slash",
		Duration = 30,
		DamageMultiplier = 1.2,
	},
}

-- Helper: get a character by key name
function CharacterData.GetCharacter(name: string)
	return CharacterData[name]
end

-- Helper: list all character key names
function CharacterData.GetAllCharacterNames(): { string }
	local names = {}
	for key, value in pairs(CharacterData) do
		if type(value) == "table" and value.DisplayName then
			table.insert(names, key)
		end
	end
	return names
end

-- Helper: list free characters
function CharacterData.GetFreeCharacters(): { string }
	local names = {}
	for key, value in pairs(CharacterData) do
		if type(value) == "table" and value.Tier == "Free" then
			table.insert(names, key)
		end
	end
	return names
end

return CharacterData
