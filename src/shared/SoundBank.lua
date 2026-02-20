--[[
	SoundBank
	TSB-style sound management. Progressive M1 impact weight,
	critical hit crack, perfect block cue, ragdoll thuds.
]]

local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local SoundBank = {}

--------------------------------------------------------------------------------
-- SOUND DEFINITIONS
--------------------------------------------------------------------------------

SoundBank.Sounds = {
	-- M1 Swing whooshes (increasing intensity per combo hit)
	M1Swing1 = { Id = "rbxassetid://12222216", Volume = 0.5, Pitch = 1.15 },
	M1Swing2 = { Id = "rbxassetid://12222216", Volume = 0.55, Pitch = 1.1 },
	M1Swing3 = { Id = "rbxassetid://12222216", Volume = 0.6, Pitch = 1.0 },
	M1Swing4 = { Id = "rbxassetid://12222216", Volume = 0.7, Pitch = 0.8 },  -- heavy finisher

	-- Hit impacts (progressive weight — light to heavy)
	HitLight    = { Id = "rbxassetid://12222225", Volume = 0.6, Pitch = 1.15 },
	HitMedium   = { Id = "rbxassetid://12222225", Volume = 0.7, Pitch = 1.0 },
	HitHeavy    = { Id = "rbxassetid://12222225", Volume = 0.85, Pitch = 0.75 },
	HitFinisher = { Id = "rbxassetid://12222225", Volume = 0.9, Pitch = 0.65 },  -- 4th hit slam

	-- Critical / Black Flash
	CriticalHit = { Id = "rbxassetid://12222084", Volume = 0.85, Pitch = 1.4 },  -- sharp crack
	BlackFlash  = { Id = "rbxassetid://12222084", Volume = 1.0, Pitch = 0.6 },   -- deep boom

	-- Perfect Block
	PerfectBlock = { Id = "rbxassetid://12221984", Volume = 0.6, Pitch = 1.8 },  -- bright ding
	BlockBreak   = { Id = "rbxassetid://12222084", Volume = 0.7, Pitch = 1.2 },

	-- Block
	BlockStart = { Id = "rbxassetid://12221984", Volume = 0.4, Pitch = 1.3 },
	BlockHit   = { Id = "rbxassetid://12221984", Volume = 0.5, Pitch = 0.9 },

	-- Dash
	DashWhoosh     = { Id = "rbxassetid://12222216", Volume = 0.45, Pitch = 1.4 },
	ForwardDash    = { Id = "rbxassetid://12222216", Volume = 0.55, Pitch = 1.1 },
	DashAttackHit  = { Id = "rbxassetid://12222225", Volume = 0.5, Pitch = 1.2 },

	-- Ragdoll
	RagdollImpact = { Id = "rbxassetid://12222225", Volume = 0.7, Pitch = 0.6 },  -- ground thud
	RagdollCancel = { Id = "rbxassetid://12222216", Volume = 0.4, Pitch = 1.6 },  -- recovery whoosh

	-- Uppercut / Downslam
	Uppercut    = { Id = "rbxassetid://12222216", Volume = 0.65, Pitch = 1.3 },
	Downslam    = { Id = "rbxassetid://12222225", Volume = 0.8, Pitch = 0.7 },

	-- Missed M1 (whiff)
	M1Miss = { Id = "rbxassetid://12222216", Volume = 0.3, Pitch = 1.5 },

	-- Fire abilities (FlameShadow)
	FireDash    = { Id = "rbxassetid://12222216", Volume = 0.6, Pitch = 0.9 },
	FireSlash   = { Id = "rbxassetid://12222216", Volume = 0.7, Pitch = 0.8 },
	FireBomb    = { Id = "rbxassetid://12222084", Volume = 0.5, Pitch = 1.0 },
	FireExplode = { Id = "rbxassetid://12222084", Volume = 0.8, Pitch = 0.7 },
	FireUlt     = { Id = "rbxassetid://12222084", Volume = 0.9, Pitch = 0.6 },

	-- Water abilities (MistBlade)
	WaterStep  = { Id = "rbxassetid://12222216", Volume = 0.5, Pitch = 1.5 },
	WaterSlice = { Id = "rbxassetid://12222216", Volume = 0.6, Pitch = 1.2 },
	WaterMist  = { Id = "rbxassetid://12222216", Volume = 0.4, Pitch = 1.6 },
	WaterUlt   = { Id = "rbxassetid://12222084", Volume = 0.8, Pitch = 0.9 },

	-- Lightning abilities (StormFist)
	ThunderJab    = { Id = "rbxassetid://12222084", Volume = 0.6, Pitch = 1.3 },
	LightningBolt = { Id = "rbxassetid://12222084", Volume = 0.8, Pitch = 1.0 },
	StaticField   = { Id = "rbxassetid://12222084", Volume = 0.5, Pitch = 1.5 },
	StormUlt      = { Id = "rbxassetid://12222084", Volume = 1.0, Pitch = 0.6 },

	-- Shadow abilities (ShadowFang)
	ShadowStep   = { Id = "rbxassetid://12222216", Volume = 0.5, Pitch = 0.7 },
	DarkSpike    = { Id = "rbxassetid://12222225", Volume = 0.6, Pitch = 0.8 },
	CounterGuard = { Id = "rbxassetid://12221984", Volume = 0.5, Pitch = 0.7 },
	ShadowUlt    = { Id = "rbxassetid://12222084", Volume = 0.9, Pitch = 0.5 },

	-- UI / Announcements
	RoundStart = { Id = "rbxassetid://12222084", Volume = 0.5, Pitch = 1.0 },
	MatchWin   = { Id = "rbxassetid://12222084", Volume = 0.6, Pitch = 1.2 },
	KO         = { Id = "rbxassetid://12222084", Volume = 0.7, Pitch = 0.7 },
}

-- Ability sound mapping
SoundBank.AbilitySounds = {
	FlameShadow = { Q = "FireDash",   E = "FireSlash",   R = "FireBomb",    F = "FireUlt" },
	MistBlade   = { Q = "WaterStep",  E = "WaterSlice",  R = "WaterMist",   F = "WaterUlt" },
	StormFist   = { Q = "ThunderJab", E = "LightningBolt", R = "StaticField", F = "StormUlt" },
	ShadowFang  = { Q = "ShadowStep", E = "DarkSpike",   R = "CounterGuard", F = "ShadowUlt" },
}

-- Hit sound for each combo index (escalating weight)
SoundBank.M1HitSounds = {
	[1] = "HitLight",
	[2] = "HitMedium",
	[3] = "HitMedium",
	[4] = "HitFinisher",
}

--------------------------------------------------------------------------------
-- PLAYBACK FUNCTIONS
--------------------------------------------------------------------------------

local function createSound(soundName)
	local data = SoundBank.Sounds[soundName]
	if not data then return nil end

	local sound = Instance.new("Sound")
	sound.SoundId = data.Id
	sound.Volume = data.Volume or 0.5
	sound.PlaybackSpeed = data.Pitch or 1.0
	sound.RollOffMaxDistance = 80
	sound.RollOffMinDistance = 10
	return sound
end

function SoundBank:play(soundName)
	local sound = createSound(soundName)
	if not sound then return end

	sound.Parent = SoundService
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	Debris:AddItem(sound, 5)
end

function SoundBank:playAtPosition(soundName, position)
	local sound = createSound(soundName)
	if not sound then return end

	local holder = Instance.new("Part")
	holder.Name = "SoundHolder"
	holder.Anchored = true
	holder.CanCollide = false
	holder.Transparency = 1
	holder.Size = Vector3.new(0.1, 0.1, 0.1)
	holder.Position = position
	holder.Parent = workspace

	sound.Parent = holder
	sound:Play()
	Debris:AddItem(holder, 5)
end

function SoundBank:playOnPart(soundName, part)
	if not part or not part.Parent then return end
	local sound = createSound(soundName)
	if not sound then return end

	sound.Parent = part
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	Debris:AddItem(sound, 5)
end

function SoundBank:getAbilitySound(ninjaKey, slot)
	local ninjaMap = SoundBank.AbilitySounds[ninjaKey]
	if ninjaMap then
		return ninjaMap[slot]
	end
	return nil
end

-- Get the hit impact sound for a specific combo index
function SoundBank:getM1HitSound(comboIndex)
	return SoundBank.M1HitSounds[comboIndex] or "HitLight"
end

return SoundBank
