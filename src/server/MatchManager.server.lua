--[[
	MatchManager (Server)
	Handles queueing, matchmaking, teleportation, and round logic.
	Works with CombatHandler for damage/health tracking.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatConfig = require(Shared:WaitForChild("CombatConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"))

--------------------------------------------------------------------------------
-- CONFIGURATION
--------------------------------------------------------------------------------

-- Arena spawn positions (read from ArenaBuilder attributes, with fallbacks)
local function getArenaPositions()
	local arena = game.Workspace:FindFirstChild("Arena")
	if arena then
		return {
			SpawnA = Vector3.new(
				arena:GetAttribute("SpawnA_X") or 200,
				arena:GetAttribute("SpawnA_Y") or 10,
				arena:GetAttribute("SpawnA_Z") or -20
			),
			SpawnB = Vector3.new(
				arena:GetAttribute("SpawnB_X") or 200,
				arena:GetAttribute("SpawnB_Y") or 10,
				arena:GetAttribute("SpawnB_Z") or 20
			),
			Lobby = Vector3.new(
				arena:GetAttribute("LobbySpawn_X") or 0,
				arena:GetAttribute("LobbySpawn_Y") or 10,
				arena:GetAttribute("LobbySpawn_Z") or 0
			),
		}
	end
	-- Fallback defaults
	return {
		SpawnA = Vector3.new(200, 10, -20),
		SpawnB = Vector3.new(200, 10, 20),
		Lobby = Vector3.new(0, 10, 0),
	}
end

local ARENA_SPAWN_A, ARENA_SPAWN_B, LOBBY_SPAWN
task.defer(function()
	-- Wait briefly for ArenaBuilder to finish
	task.wait(1)
	local positions = getArenaPositions()
	ARENA_SPAWN_A = positions.SpawnA
	ARENA_SPAWN_B = positions.SpawnB
	LOBBY_SPAWN = positions.Lobby
	print("[MatchManager] Arena positions loaded:", ARENA_SPAWN_A, ARENA_SPAWN_B)
end)

-- Immediate fallbacks so variables are never nil
ARENA_SPAWN_A = Vector3.new(200, 10, -20)
ARENA_SPAWN_B = Vector3.new(200, 10, 20)
LOBBY_SPAWN = Vector3.new(0, 10, 0)

--------------------------------------------------------------------------------
-- STATE
--------------------------------------------------------------------------------

local queue = {}                -- list of players waiting for a match
local playerNinjaSelection = {} -- [Player] = "FlameShadow" etc.
local activeMatches = {}        -- [matchId] = { player1, player2, scores, ... }
local playerToMatch = {}        -- [Player] = matchId
local nextMatchId = 1

-- KO event: CombatHandler fires this when a player reaches 0 HP
local matchKOEvent = Instance.new("BindableEvent")
matchKOEvent.Name = "MatchKOEvent"
matchKOEvent.Parent = game:GetService("ServerScriptService")

--------------------------------------------------------------------------------
-- HELPERS
--------------------------------------------------------------------------------

local function teleportPlayer(player, position)
	local char = player.Character
	if char then
		local root = char:FindFirstChild("HumanoidRootPart")
		if root then
			root.CFrame = CFrame.new(position)
		end
	end
end

local function resetCharacter(player)
	local char = player.Character
	if char then
		local humanoid = char:FindFirstChild("Humanoid")
		if humanoid then
			humanoid.Health = humanoid.MaxHealth
		end
	end
end

local function removeFromQueue(player)
	for i, p in ipairs(queue) do
		if p == player then
			table.remove(queue, i)
			return true
		end
	end
	return false
end

local function isInMatch(player)
	return playerToMatch[player] ~= nil
end

local function isInQueue(player)
	for _, p in ipairs(queue) do
		if p == player then return true end
	end
	return false
end

--------------------------------------------------------------------------------
-- NINJA SELECTION
--------------------------------------------------------------------------------

Remotes.Match.SelectNinja.OnServerEvent:Connect(function(player, ninjaKey)
	-- Validate that this ninja exists
	local NinjaData = require(Shared:WaitForChild("NinjaData"))
	if NinjaData.GetNinja(ninjaKey) then
		playerNinjaSelection[player] = ninjaKey
	end
end)

-- Default ninja if none selected
local function getNinjaSelection(player)
	return playerNinjaSelection[player] or "FlameShadow"
end

--------------------------------------------------------------------------------
-- QUEUE SYSTEM
--------------------------------------------------------------------------------

Remotes.Match.JoinQueue.OnServerEvent:Connect(function(player)
	-- Don't allow if already in queue or match
	if isInQueue(player) or isInMatch(player) then return end

	table.insert(queue, player)
	Remotes.Match.QueueStatus:FireClient(player, "queued", #queue)
	print("[MatchManager] " .. player.Name .. " joined queue. Queue size: " .. #queue)

	-- Try to match players
	tryMatchPlayers()
end)

Remotes.Match.LeaveQueue.OnServerEvent:Connect(function(player)
	if removeFromQueue(player) then
		Remotes.Match.QueueStatus:FireClient(player, "left", #queue)
		print("[MatchManager] " .. player.Name .. " left queue.")
	end
end)

--------------------------------------------------------------------------------
-- MATCHMAKING
--------------------------------------------------------------------------------

function tryMatchPlayers()
	while #queue >= 2 do
		local player1 = table.remove(queue, 1)
		local player2 = table.remove(queue, 1)

		-- Verify both players are still connected
		if not player1.Parent or not player2.Parent then
			if player1.Parent then table.insert(queue, 1, player1) end
			if player2.Parent then table.insert(queue, 1, player2) end
			return
		end

		startMatch(player1, player2)
	end
end

--------------------------------------------------------------------------------
-- MATCH FLOW
--------------------------------------------------------------------------------

function startMatch(player1, player2)
	local matchId = nextMatchId
	nextMatchId = nextMatchId + 1

	local match = {
		Id = matchId,
		Player1 = player1,
		Player2 = player2,
		Scores = { [player1] = 0, [player2] = 0 },
		CurrentRound = 0,
		IsActive = true,
	}

	activeMatches[matchId] = match
	playerToMatch[player1] = matchId
	playerToMatch[player2] = matchId

	print("[MatchManager] Match #" .. matchId .. ": " .. player1.Name .. " vs " .. player2.Name)

	-- Notify players
	Remotes.Match.MatchFound:FireClient(player1, player2.Name, getNinjaSelection(player2))
	Remotes.Match.MatchFound:FireClient(player2, player1.Name, getNinjaSelection(player1))

	-- Initialize combat states
	-- Wait for CombatAPI to be available
	task.wait(0.5)
	local CombatAPI = _G.CombatAPI
	if CombatAPI then
		CombatAPI.InitPlayerCombat(player1, getNinjaSelection(player1))
		CombatAPI.InitPlayerCombat(player2, getNinjaSelection(player2))
	end

	-- Start first round
	task.spawn(function()
		startRound(match)
	end)
end

function startRound(match)
	if not match.IsActive then return end

	match.CurrentRound = match.CurrentRound + 1
	local roundNum = match.CurrentRound

	print("[MatchManager] Match #" .. match.Id .. " — Round " .. roundNum)

	-- Teleport players to arena spawns
	teleportPlayer(match.Player1, ARENA_SPAWN_A)
	teleportPlayer(match.Player2, ARENA_SPAWN_B)

	-- Reset combat states for new round
	local CombatAPI = _G.CombatAPI
	if CombatAPI then
		CombatAPI.ResetPlayerCombat(match.Player1)
		CombatAPI.ResetPlayerCombat(match.Player2)
	end

	-- Countdown
	for i = CombatConfig.Match.CountdownTime, 1, -1 do
		Remotes.Match.RoundStart:FireClient(match.Player1, roundNum, i)
		Remotes.Match.RoundStart:FireClient(match.Player2, roundNum, i)
		task.wait(1)
	end

	-- FIGHT!
	Remotes.Match.RoundStart:FireClient(match.Player1, roundNum, 0) -- 0 = fight
	Remotes.Match.RoundStart:FireClient(match.Player2, roundNum, 0)
end

function endRound(match, winner, loser)
	if not match.IsActive then return end

	-- Update scores
	match.Scores[winner] = match.Scores[winner] + 1

	local winnerScore = match.Scores[winner]
	local loserScore = match.Scores[loser]

	-- Notify both players
	Remotes.Match.RoundEnd:FireClient(match.Player1, winner.Name, winnerScore, loserScore)
	Remotes.Match.RoundEnd:FireClient(match.Player2, winner.Name, winnerScore, loserScore)

	print("[MatchManager] Round won by " .. winner.Name .. " (" .. winnerScore .. "-" .. loserScore .. ")")

	-- Check if match is over
	if winnerScore >= CombatConfig.Match.RoundsToWin then
		-- Match over!
		task.wait(CombatConfig.Match.RoundEndFreeze)
		endMatch(match, winner, loser)
	else
		-- Next round after freeze
		task.wait(CombatConfig.Match.RoundEndFreeze)
		startRound(match)
	end
end

function endMatch(match, winner, loser)
	match.IsActive = false

	print("[MatchManager] Match #" .. match.Id .. " won by " .. winner.Name)

	-- Notify players
	Remotes.Match.MatchEnd:FireClient(match.Player1, winner.Name, match.Scores)
	Remotes.Match.MatchEnd:FireClient(match.Player2, winner.Name, match.Scores)

	-- Clean up combat states
	local CombatAPI = _G.CombatAPI
	if CombatAPI then
		CombatAPI.RemovePlayerCombat(match.Player1)
		CombatAPI.RemovePlayerCombat(match.Player2)
	end

	-- Teleport back to lobby
	task.wait(2)
	teleportPlayer(match.Player1, LOBBY_SPAWN)
	teleportPlayer(match.Player2, LOBBY_SPAWN)

	-- Clean up match tracking
	playerToMatch[match.Player1] = nil
	playerToMatch[match.Player2] = nil
	activeMatches[match.Id] = nil
end

--------------------------------------------------------------------------------
-- KO EVENT LISTENER
--------------------------------------------------------------------------------

matchKOEvent.Event:Connect(function(attacker, victim)
	-- Find the match these players are in
	local matchId = playerToMatch[attacker] or playerToMatch[victim]
	if not matchId then return end

	local match = activeMatches[matchId]
	if not match or not match.IsActive then return end

	endRound(match, attacker, victim)
end)

--------------------------------------------------------------------------------
-- CLEANUP ON PLAYER LEAVE
--------------------------------------------------------------------------------

Players.PlayerRemoving:Connect(function(player)
	-- Remove from queue
	removeFromQueue(player)

	-- Clean up ninja selection
	playerNinjaSelection[player] = nil

	-- Handle mid-match disconnect
	local matchId = playerToMatch[player]
	if matchId then
		local match = activeMatches[matchId]
		if match and match.IsActive then
			-- Other player wins by default
			local winner = (match.Player1 == player) and match.Player2 or match.Player1
			endMatch(match, winner, player)
		end
	end
end)

print("[MatchManager] Loaded")
