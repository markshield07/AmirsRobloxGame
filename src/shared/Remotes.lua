--[[
	Remotes
	All RemoteEvents / RemoteFunctions for The Strongest Battlegrounds.
	TSB-style: free-for-all combat, character abilities, awakening, respawn.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = {}

local function getOrCreateFolder(name: string): Folder
	local folder = ReplicatedStorage:FindFirstChild(name)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = ReplicatedStorage
	end
	return folder
end

local function getOrCreateRemote(folder: Folder, name: string): RemoteEvent
	local remote = folder:FindFirstChild(name)
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
	end
	return remote
end

--------------------------------------------------------------------------------
-- COMBAT REMOTES
--------------------------------------------------------------------------------
local combatFolder = getOrCreateFolder("CombatRemotes")

Remotes.Combat = {
	-- Client -> Server: M1 attack (isJumpHeld)
	Attack        = getOrCreateRemote(combatFolder, "Attack"),
	-- Client -> Server: use character move (slot: E/R/T/G)
	UseMove       = getOrCreateRemote(combatFolder, "UseMove"),
	-- Client -> Server: block start/stop
	Block         = getOrCreateRemote(combatFolder, "Block"),
	-- Client -> Server: evasive dodge (direction)
	Evasive       = getOrCreateRemote(combatFolder, "Evasive"),
	-- Client -> Server: dash (direction, type)
	Dash          = getOrCreateRemote(combatFolder, "Dash"),
	-- Client -> Server: activate awakening
	Awakening     = getOrCreateRemote(combatFolder, "Awakening"),
	-- Client -> Server: sprint toggle
	Sprint        = getOrCreateRemote(combatFolder, "Sprint"),

	-- Server -> Client: hit effect at position
	HitEffect     = getOrCreateRemote(combatFolder, "HitEffect"),
	-- Server -> Client: health update
	HealthUpdate  = getOrCreateRemote(combatFolder, "HealthUpdate"),
	-- Server -> Client: stamina update
	StaminaUpdate = getOrCreateRemote(combatFolder, "StaminaUpdate"),
	-- Server -> Client: awakening meter update
	AwakeningUpdate = getOrCreateRemote(combatFolder, "AwakeningUpdate"),
	-- Server -> Client: move cooldown started
	CooldownStart = getOrCreateRemote(combatFolder, "CooldownStart"),
	-- Server -> All: broadcast combat VFX
	ActionVFX     = getOrCreateRemote(combatFolder, "ActionVFX"),

	-- Server -> Client: ragdoll state
	Ragdoll       = getOrCreateRemote(combatFolder, "Ragdoll"),
	-- Server -> Client: hitstun applied
	Hitstun       = getOrCreateRemote(combatFolder, "Hitstun"),
	-- Server -> Client: perfect block
	PerfectBlock  = getOrCreateRemote(combatFolder, "PerfectBlock"),
	-- Server -> Client: critical/black flash hit
	CriticalHit   = getOrCreateRemote(combatFolder, "CriticalHit"),
	-- Server -> Client: hit-stop freeze frame
	HitStop       = getOrCreateRemote(combatFolder, "HitStop"),
	-- Server -> Client: awakening activated/ended
	AwakeningState = getOrCreateRemote(combatFolder, "AwakeningState"),
}

--------------------------------------------------------------------------------
-- GAME REMOTES (free-for-all game flow)
--------------------------------------------------------------------------------
local gameFolder = getOrCreateFolder("GameRemotes")

Remotes.Game = {
	-- Client -> Server: select character
	SelectCharacter = getOrCreateRemote(gameFolder, "SelectCharacter"),
	-- Server -> Client: character selection confirmed
	CharacterConfirmed = getOrCreateRemote(gameFolder, "CharacterConfirmed"),
	-- Server -> Client: player died (attacker, victim)
	PlayerDied    = getOrCreateRemote(gameFolder, "PlayerDied"),
	-- Server -> Client: respawn countdown
	RespawnTimer  = getOrCreateRemote(gameFolder, "RespawnTimer"),
	-- Server -> Client: player respawned
	Respawned     = getOrCreateRemote(gameFolder, "Respawned"),
	-- Server -> Client: kill feed notification
	KillFeed      = getOrCreateRemote(gameFolder, "KillFeed"),
}

return Remotes
