--[[
	SoundBank
	Central sound management for combat. Defines all sound IDs and provides
	a simple API to play sounds at positions or attached to characters.

	Sound IDs reference Roblox audio assets. Replace any ID that doesn't
	load with your own uploaded audio.

	Usage:
		local SoundBank = require(Shared.SoundBank)
		SoundBank:play("M1Swing1")                       -- at camera
		SoundBank:playAtPosition("HitImpact", position)  -- 3D positional
		SoundBank:playOnPart("DashWhoosh", rootPart)      -- attached to part
]]

local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local SoundBank = {}

--------------------------------------------------------------------------------
-- SOUND ID DEFINITIONS
-- Format: [SoundName] = { Id = "rbxassetid://...", Volume = 0-1, Pitch = 0.5-2 }
--
-- Replace IDs with your own uploads for best results. These are common
-- Roblox library sounds that should work out of the box.
--------------------------------------------------------------------------------

SoundBank.Sounds = {
	-- M1 Combo swings (4 variants for variety)
	M1Swing1 = { Id = "rbxassetid://12222216", Volume = 0.5, Pitch = 1.1 },
	M1Swing2 = { Id = "rbxassetid://12222216", Volume = 0.5, Pitch = 1.2 },
	M1Swing3 = { Id = "rbxassetid://12222216", Volume = 0.5, Pitch = 1.0 },
	M1Swing4 = { Id = "rbxassetid://12222216", Volume = 0.6, Pitch = 0.85 }, -- heavy hit, deeper

	-- Hit impacts
	HitLight    = { Id = "rbxassetid://12222225", Volume = 0.6, Pitch = 1.1 },
	HitMedium   = { Id = "rbxassetid://12222225", Volume = 0.7, Pitch = 1.0 },
	HitHeavy    = { Id = "rbxassetid://12222225", Volume = 0.8, Pitch = 0.8 },
	BlockBreak  = { Id = "rbxassetid://12222084", Volume = 0.7, Pitch = 1.2 },

	-- Block
	BlockStart  = { Id = "rbxassetid://12221984", Volume = 0.4, Pitch = 1.3 },
	BlockHit    = { Id = "rbxassetid://12221984", Volume = 0.5, Pitch = 0.9 },

	-- Dash
	DashWhoosh  = { Id = "rbxassetid://12222216", Volume = 0.4, Pitch = 1.4 },

	-- Fire abilities (FlameShadow)
	FireDash    = { Id = "rbxassetid://12222216", Volume = 0.6, Pitch = 0.9 },
	FireSlash   = { Id = "rbxassetid://12222216", Volume = 0.7, Pitch = 0.8 },
	FireBomb    = { Id = "rbxassetid://12222084", Volume = 0.5, Pitch = 1.0 },
	FireExplode = { Id = "rbxassetid://12222084", Volume = 0.8, Pitch = 0.7 },
	FireUlt     = { Id = "rbxassetid://12222084", Volume = 0.9, Pitch = 0.6 },

	-- Water abilities (MistBlade)
	WaterStep   = { Id = "rbxassetid://12222216", Volume = 0.5, Pitch = 1.5 },
	WaterSlice  = { Id = "rbxassetid://12222216", Volume = 0.6, Pitch = 1.2 },
	WaterMist   = { Id = "rbxassetid://12222216", Volume = 0.4, Pitch = 1.6 },
	WaterUlt    = { Id = "rbxassetid://12222084", Volume = 0.8, Pitch = 0.9 },

	-- Lightning abilities (StormFist)
	ThunderJab    = { Id = "rbxassetid://12222084", Volume = 0.6, Pitch = 1.3 },
	LightningBolt = { Id = "rbxassetid://12222084", Volume = 0.8, Pitch = 1.0 },
	StaticField   = { Id = "rbxassetid://12222084", Volume = 0.5, Pitch = 1.5 },
	StormUlt      = { Id = "rbxassetid://12222084", Volume = 1.0, Pitch = 0.6 },

	-- Shadow abilities (ShadowFang)
	ShadowStep    = { Id = "rbxassetid://12222216", Volume = 0.5, Pitch = 0.7 },
	DarkSpike     = { Id = "rbxassetid://12222225", Volume = 0.6, Pitch = 0.8 },
	CounterGuard  = { Id = "rbxassetid://12221984", Volume = 0.5, Pitch = 0.7 },
	ShadowUlt     = { Id = "rbxassetid://12222084", Volume = 0.9, Pitch = 0.5 },

	-- UI / Announcements
	RoundStart  = { Id = "rbxassetid://12222084", Volume = 0.5, Pitch = 1.0 },
	MatchWin    = { Id = "rbxassetid://12222084", Volume = 0.6, Pitch = 1.2 },
	KO          = { Id = "rbxassetid://12222084", Volume = 0.7, Pitch = 0.7 },
}

-- Ability sound mapping: [NinjaKey][Slot] = SoundBank key
SoundBank.AbilitySounds = {
	FlameShadow = { Q = "FireDash",   E = "FireSlash",   R = "FireBomb",    F = "FireUlt" },
	MistBlade   = { Q = "WaterStep",  E = "WaterSlice",  R = "WaterMist",   F = "WaterUlt" },
	StormFist   = { Q = "ThunderJab", E = "LightningBolt", R = "StaticField", F = "StormUlt" },
	ShadowFang  = { Q = "ShadowStep", E = "DarkSpike",   R = "CounterGuard", F = "ShadowUlt" },
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

-- Play a sound globally (non-positional, for local player feedback)
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

-- Play a sound at a world position (3D positional audio)
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

-- Play a sound attached to a Part (follows the part)
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

-- Get the ability sound name for a ninja + slot combo
function SoundBank:getAbilitySound(ninjaKey, slot)
	local ninjaMap = SoundBank.AbilitySounds[ninjaKey]
	if ninjaMap then
		return ninjaMap[slot]
	end
	return nil
end

return SoundBank
