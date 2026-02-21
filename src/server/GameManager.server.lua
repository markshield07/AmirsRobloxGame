--[[
	GameManager (Server)
	TSB-style free-for-all game flow:
	  - Players select a character in the lobby
	  - Teleport to the city arena to fight
	  - Respawn on death after a short delay
	  - Kill feed broadcasts
	  - No strict matchmaking — open world fighting
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatConfig = require(Shared:WaitForChild("CombatConfig"))
local CharacterData = require(Shared:WaitForChild("CharacterData"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local CombatAPI = require(Shared:WaitForChild("CombatAPI"))

-- Wait for CombatHandler to initialize
CombatAPI.WaitForReady()

--------------------------------------------------------------------------------
-- PLAYER DATA
--------------------------------------------------------------------------------

local playerData = {} -- [player] = { CharacterKey, IsInArena, ... }

local function getArenaSpawn()
	local arena = workspace:FindFirstChild("CityArena")
	if not arena then return Vector3.new(300, 5, 0) end

	local count = arena:GetAttribute("SpawnCount") or 1
	local index = math.random(1, count)
	return arena:GetAttribute("Spawn" .. index) or Vector3.new(300, 5, 0)
end

--------------------------------------------------------------------------------
-- CHARACTER SELECTION
--------------------------------------------------------------------------------

Remotes.Game.SelectCharacter.OnServerEvent:Connect(function(player, characterKey)
	if not CharacterData.GetCharacter(characterKey) then return end

	local data = playerData[player]
	if not data then
		data = { CharacterKey = nil, IsInArena = false }
		playerData[player] = data
	end

	data.CharacterKey = characterKey

	-- Confirm to client
	Remotes.Game.CharacterConfirmed:FireClient(player, characterKey)

	-- If not in arena yet, teleport them
	if not data.IsInArena then
		data.IsInArena = true
		teleportToArena(player, characterKey)
	end
end)

--------------------------------------------------------------------------------
-- TELEPORT TO ARENA
--------------------------------------------------------------------------------

function teleportToArena(player, characterKey)
	-- Wait for character
	local char = player.Character
	if not char then
		player.CharacterAdded:Wait()
		char = player.Character
	end

	local root = char and char:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = CFrame.new(getArenaSpawn())
	end

	-- Initialize combat
	CombatAPI.InitPlayerCombat(player, characterKey)
end

--------------------------------------------------------------------------------
-- RESPAWN ON DEATH
--------------------------------------------------------------------------------

local function onPlayerDied(attacker, victim)
	-- Kill feed
	local attackerName = attacker and attacker.Name or "Unknown"
	local victimName = victim and victim.Name or "Unknown"
	Remotes.Game.KillFeed:FireAllClients(attackerName, victimName)
	Remotes.Game.PlayerDied:FireAllClients(attacker, victim)

	-- Handle respawn
	local data = playerData[victim]
	if not data or victim.IsBot then return end

	-- Start respawn countdown
	local respawnDelay = CombatConfig.Respawn.Delay
	for i = respawnDelay, 1, -1 do
		Remotes.Game.RespawnTimer:FireClient(victim, i)
		task.wait(1)
	end

	-- Respawn
	if not playerData[victim] then return end -- player left

	-- Reset the character
	local charKey = data.CharacterKey or "StrongestHero"
	player = victim -- alias for clarity

	-- Force respawn
	if player.Character then
		local humanoid = player.Character:FindFirstChild("Humanoid")
		if humanoid then
			humanoid.Health = humanoid.MaxHealth
		end
	else
		player:LoadCharacter()
		player.CharacterAdded:Wait()
	end

	-- Teleport back to arena
	local char = player.Character
	if char then
		local root = char:FindFirstChild("HumanoidRootPart")
		if root then
			root.CFrame = CFrame.new(getArenaSpawn())
		end
	end

	CombatAPI.ResetPlayerCombat(player)
	Remotes.Game.Respawned:FireClient(player)
end

-- Listen for KO events from CombatHandler
local KOEvent = ReplicatedStorage:WaitForChild("KOEvent")
KOEvent.Event:Connect(function(attacker, victim)
	-- Run in separate thread to not block combat
	task.spawn(function()
		onPlayerDied(attacker, victim)
	end)
end)

--------------------------------------------------------------------------------
-- PLAYER JOINS / LEAVES
--------------------------------------------------------------------------------

Players.PlayerAdded:Connect(function(player)
	playerData[player] = {
		CharacterKey = nil,
		IsInArena = false,
	}

	-- Auto-select first free character and spawn into arena
	-- In TSB, players go through character select first
	-- For now: auto-assign and let them change later
	player.CharacterAdded:Connect(function(character)
		-- Wait a moment for character to load
		task.wait(0.5)

		local data = playerData[player]
		if data and data.IsInArena and data.CharacterKey then
			-- Already in arena, re-init combat after respawn
			local root = character:FindFirstChild("HumanoidRootPart")
			if root then
				root.CFrame = CFrame.new(getArenaSpawn())
			end
			CombatAPI.InitPlayerCombat(player, data.CharacterKey)
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	CombatAPI.RemovePlayerCombat(player)
	playerData[player] = nil
end)

print("[GameManager] Loaded - TSB free-for-all game flow")
