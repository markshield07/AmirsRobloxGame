--[[
	Remotes
	Creates and returns all RemoteEvents / RemoteFunctions used by the game.
	Both server and client require this module so remotes are always in sync.

	Usage:
		local Remotes = require(path.to.Remotes)
		-- Fire from client:  Remotes.Combat.Attack:FireServer(...)
		-- Listen on server:  Remotes.Combat.Attack.OnServerEvent:Connect(...)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = {}

-- Folder helper: get or create a folder inside ReplicatedStorage
local function getOrCreateFolder(name: string): Folder
	local folder = ReplicatedStorage:FindFirstChild(name)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = ReplicatedStorage
	end
	return folder
end

-- Remote helper: get or create a RemoteEvent inside a folder
local function getOrCreateRemote(folder: Folder, name: string): RemoteEvent
	local remote = folder:FindFirstChild(name)
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
	end
	return remote
end

-- Remote function helper
local function getOrCreateRemoteFunction(folder: Folder, name: string): RemoteFunction
	local remote = folder:FindFirstChild(name)
	if not remote then
		remote = Instance.new("RemoteFunction")
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
	-- Client -> Server: player pressed attack
	Attack        = getOrCreateRemote(combatFolder, "Attack"),
	-- Client -> Server: player used ability (Q/E/R/F)
	UseAbility    = getOrCreateRemote(combatFolder, "UseAbility"),
	-- Client -> Server: player started/stopped blocking
	Block         = getOrCreateRemote(combatFolder, "Block"),
	-- Client -> Server: player dashed (direction + dash type)
	Dash          = getOrCreateRemote(combatFolder, "Dash"),
	-- Server -> Client: apply hit effect / damage number
	HitEffect     = getOrCreateRemote(combatFolder, "HitEffect"),
	-- Server -> Client: update health for a player
	HealthUpdate  = getOrCreateRemote(combatFolder, "HealthUpdate"),
	-- Server -> Client: update stamina
	StaminaUpdate = getOrCreateRemote(combatFolder, "StaminaUpdate"),
	-- Server -> Client: update ultimate charge
	UltimateUpdate = getOrCreateRemote(combatFolder, "UltimateUpdate"),
	-- Server -> Client: cooldown started for an ability
	CooldownStart = getOrCreateRemote(combatFolder, "CooldownStart"),
	-- Server -> All Clients: broadcast a combat action for VFX/sound
	-- actionType: "M1", "Ability", "Dash", "BlockStart", "BlockEnd",
	--             "Uppercut", "Downslam", "ForwardDashAttack"
	ActionVFX = getOrCreateRemote(combatFolder, "ActionVFX"),

	-- Server -> Client: ragdoll state change (victim, isRagdolled, duration)
	Ragdoll       = getOrCreateRemote(combatFolder, "Ragdoll"),
	-- Server -> Client: hitstun applied (victim, duration)
	Hitstun       = getOrCreateRemote(combatFolder, "Hitstun"),
	-- Server -> Client: perfect block occurred (blocker)
	PerfectBlock  = getOrCreateRemote(combatFolder, "PerfectBlock"),
	-- Server -> Client: critical hit landed (attacker, isCritical or isBlackFlash)
	CriticalHit   = getOrCreateRemote(combatFolder, "CriticalHit"),
	-- Server -> Client: hit-stop freeze frame (duration)
	HitStop       = getOrCreateRemote(combatFolder, "HitStop"),
}

--------------------------------------------------------------------------------
-- MATCH REMOTES
--------------------------------------------------------------------------------
local matchFolder = getOrCreateFolder("MatchRemotes")

Remotes.Match = {
	-- Client -> Server: player wants to join queue
	JoinQueue     = getOrCreateRemote(matchFolder, "JoinQueue"),
	-- Client -> Server: player wants to leave queue
	LeaveQueue    = getOrCreateRemote(matchFolder, "LeaveQueue"),
	-- Client -> Server: player selected a ninja
	SelectNinja   = getOrCreateRemote(matchFolder, "SelectNinja"),
	-- Server -> Client: match found, teleporting
	MatchFound    = getOrCreateRemote(matchFolder, "MatchFound"),
	-- Server -> Client: round starting (countdown)
	RoundStart    = getOrCreateRemote(matchFolder, "RoundStart"),
	-- Server -> Client: round ended
	RoundEnd      = getOrCreateRemote(matchFolder, "RoundEnd"),
	-- Server -> Client: full match ended
	MatchEnd      = getOrCreateRemote(matchFolder, "MatchEnd"),
	-- Server -> Client: update queue status
	QueueStatus   = getOrCreateRemote(matchFolder, "QueueStatus"),
	-- Client -> Server: player wants to start practice vs bot
	StartPractice = getOrCreateRemote(matchFolder, "StartPractice"),
	-- Client -> Server: player wants to leave practice
	LeavePractice = getOrCreateRemote(matchFolder, "LeavePractice"),
}

return Remotes
