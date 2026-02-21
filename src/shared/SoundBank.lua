--[[
	SoundBank
	TSB-style sound management. Progressive M1 impact weight,
	critical hit crack, perfect block cue, ragdoll thuds,
	character ability sounds, evasive/awakening cues.
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
	M1Swing4 = { Id = "rbxassetid://12222216", Volume = 0.7, Pitch = 0.8 },

	-- Hit impacts (progressive weight)
	HitLight    = { Id = "rbxassetid://12222225", Volume = 0.6, Pitch = 1.15 },
	HitMedium   = { Id = "rbxassetid://12222225", Volume = 0.7, Pitch = 1.0 },
	HitHeavy    = { Id = "rbxassetid://12222225", Volume = 0.85, Pitch = 0.75 },
	HitFinisher = { Id = "rbxassetid://12222225", Volume = 0.9, Pitch = 0.65 },

	-- Critical / Black Flash
	CriticalHit = { Id = "rbxassetid://12222084", Volume = 0.85, Pitch = 1.4 },
	BlackFlash  = { Id = "rbxassetid://12222084", Volume = 1.0, Pitch = 0.6 },

	-- Perfect Block
	PerfectBlock = { Id = "rbxassetid://12221984", Volume = 0.6, Pitch = 1.8 },
	BlockBreak   = { Id = "rbxassetid://12222084", Volume = 0.7, Pitch = 1.2 },

	-- Block
	BlockStart = { Id = "rbxassetid://12221984", Volume = 0.4, Pitch = 1.3 },
	BlockHit   = { Id = "rbxassetid://12221984", Volume = 0.5, Pitch = 0.9 },

	-- Dash
	DashWhoosh     = { Id = "rbxassetid://12222216", Volume = 0.45, Pitch = 1.4 },
	ForwardDash    = { Id = "rbxassetid://12222216", Volume = 0.55, Pitch = 1.1 },
	DashAttackHit  = { Id = "rbxassetid://12222225", Volume = 0.5, Pitch = 1.2 },

	-- Evasive
	EvasiveDodge = { Id = "rbxassetid://12222216", Volume = 0.5, Pitch = 1.5 },

	-- Ragdoll
	RagdollImpact = { Id = "rbxassetid://12222225", Volume = 0.7, Pitch = 0.6 },
	RagdollCancel = { Id = "rbxassetid://12222216", Volume = 0.4, Pitch = 1.6 },

	-- Uppercut / Downslam
	Uppercut    = { Id = "rbxassetid://12222216", Volume = 0.65, Pitch = 1.3 },
	Downslam    = { Id = "rbxassetid://12222225", Volume = 0.8, Pitch = 0.7 },

	-- Missed M1 (whiff)
	M1Miss = { Id = "rbxassetid://12222216", Volume = 0.3, Pitch = 1.5 },

	-- Awakening
	AwakeningActivate   = { Id = "rbxassetid://12222084", Volume = 0.9, Pitch = 0.7 },
	AwakeningDeactivate = { Id = "rbxassetid://12222084", Volume = 0.5, Pitch = 1.2 },

	-- Sprint
	SprintStart = { Id = "rbxassetid://12222216", Volume = 0.3, Pitch = 1.3 },

	-- Character ability sounds — generic categories
	AbilityPunch    = { Id = "rbxassetid://12222225", Volume = 0.6, Pitch = 1.0 },
	AbilitySlash    = { Id = "rbxassetid://12222216", Volume = 0.6, Pitch = 0.9 },
	AbilityBlast    = { Id = "rbxassetid://12222084", Volume = 0.7, Pitch = 1.0 },
	AbilityGrab     = { Id = "rbxassetid://12222225", Volume = 0.7, Pitch = 0.85 },
	AbilityCounter  = { Id = "rbxassetid://12221984", Volume = 0.5, Pitch = 0.8 },
	AbilityMultiHit = { Id = "rbxassetid://12222225", Volume = 0.6, Pitch = 1.1 },
	AbilityHeavy    = { Id = "rbxassetid://12222084", Volume = 0.8, Pitch = 0.7 },
	AbilityUltimate = { Id = "rbxassetid://12222084", Volume = 0.9, Pitch = 0.6 },

	-- UI / Announcements
	KO         = { Id = "rbxassetid://12222084", Volume = 0.7, Pitch = 0.7 },
	Respawn    = { Id = "rbxassetid://12222084", Volume = 0.5, Pitch = 1.0 },
	CharSelect = { Id = "rbxassetid://12221984", Volume = 0.4, Pitch = 1.5 },
}

-- Character ability sound mapping (E/R/T/G slots → sound keys)
SoundBank.AbilitySounds = {
	StrongestHero = {
		E = "AbilityPunch",
		R = "AbilityMultiHit",
		T = "AbilityPunch",
		G = "AbilityHeavy",
	},
	HeroHunter = {
		E = "AbilityPunch",
		R = "AbilityCounter",
		T = "AbilityGrab",
		G = "AbilityHeavy",
	},
	DestructiveCyborg = {
		E = "AbilityBlast",
		R = "AbilityMultiHit",
		T = "AbilityHeavy",
		G = "AbilityUltimate",
	},
	DeadlyNinja = {
		E = "AbilitySlash",
		R = "AbilityMultiHit",
		T = "AbilityBlast",
		G = "AbilityUltimate",
	},
	BladeMaster = {
		E = "AbilitySlash",
		R = "AbilitySlash",
		T = "AbilityCounter",
		G = "AbilityUltimate",
	},
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

function SoundBank:getAbilitySound(characterKey, slot)
	local charMap = SoundBank.AbilitySounds[characterKey]
	if charMap then
		return charMap[slot]
	end
	return nil
end

function SoundBank:getM1HitSound(comboIndex)
	return SoundBank.M1HitSounds[comboIndex] or "HitLight"
end

return SoundBank
