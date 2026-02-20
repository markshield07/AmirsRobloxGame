--[[
	MatchManager (Server)
	Handles queueing, matchmaking, teleportation, and round logic.
	Works with CombatHandler for damage/health tracking via shared CombatAPI.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatConfig = require(Shared:WaitForChild("CombatConfig"))
local NinjaData = require(Shared:WaitForChild("NinjaData"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local CombatAPI = require(Shared:WaitForChild("CombatAPI"))

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
				arena:GetAttribute("SpawnA_Y") or 6,
				arena:GetAttribute("SpawnA_Z") or -20
			),
			SpawnB = Vector3.new(
				arena:GetAttribute("SpawnB_X") or 200,
				arena:GetAttribute("SpawnB_Y") or 6,
				arena:GetAttribute("SpawnB_Z") or 20
			),
			Lobby = Vector3.new(
				arena:GetAttribute("LobbySpawn_X") or 0,
				arena:GetAttribute("LobbySpawn_Y") or 6,
				arena:GetAttribute("LobbySpawn_Z") or 0
			),
		}
	end
	-- Fallback defaults
	return {
		SpawnA = Vector3.new(200, 6, -20),
		SpawnB = Vector3.new(200, 6, 20),
		Lobby = Vector3.new(0, 6, 0),
	}
end

-- Immediate fallbacks so variables are never nil
local ARENA_SPAWN_A = Vector3.new(200, 6, -20)
local ARENA_SPAWN_B = Vector3.new(200, 6, 20)
local LOBBY_SPAWN = Vector3.new(0, 6, 0)

task.defer(function()
	-- Wait briefly for ArenaBuilder to finish
	task.wait(1)
	local positions = getArenaPositions()
	ARENA_SPAWN_A = positions.SpawnA
	ARENA_SPAWN_B = positions.SpawnB
	LOBBY_SPAWN = positions.Lobby
	print("[MatchManager] Arena positions loaded:", ARENA_SPAWN_A, ARENA_SPAWN_B)
end)

--------------------------------------------------------------------------------
-- STATE
--------------------------------------------------------------------------------

local queue = {}                -- list of players waiting for a match
local playerNinjaSelection = {} -- [Player] = "FlameShadow" etc.
local activeMatches = {}        -- [matchId] = { Player1, Player2, Scores, ... }
local playerToMatch = {}        -- [Player] = matchId
local nextMatchId = 1

-- KO event: CombatHandler fires this when a player reaches 0 HP
local matchKOEvent = Instance.new("BindableEvent")
matchKOEvent.Name = "MatchKOEvent"
matchKOEvent.Parent = game:GetService("ServerScriptService")

--------------------------------------------------------------------------------
-- HELPERS
--------------------------------------------------------------------------------

local function isBotPlayer(player)
	return typeof(player) == "table" and player.IsBot == true
end

local function safeFireClient(remote, player, ...)
	if isBotPlayer(player) then return end
	remote:FireClient(player, ...)
end

local function waitForCharacter(player)
	if isBotPlayer(player) then return player.Character end
	if not player.Character then
		player.CharacterAdded:Wait()
	end
	local char = player.Character
	if char and not char:FindFirstChild("HumanoidRootPart") then
		char:WaitForChild("HumanoidRootPart", 5)
	end
	return player.Character
end

local function teleportPlayer(player, position)
	local char = waitForCharacter(player)
	if char then
		local root = char:FindFirstChild("HumanoidRootPart")
		if root then
			root.CFrame = CFrame.new(position)
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

-- Default ninja if none selected
local function getNinjaSelection(player)
	return playerNinjaSelection[player] or "FlameShadow"
end

--------------------------------------------------------------------------------
-- FORWARD DECLARATIONS (local functions referenced before definition)
--------------------------------------------------------------------------------

local tryMatchPlayers
local startMatch
local startRound
local endRound
local endMatch
local startPracticeMatch
local endPracticeMatch

--------------------------------------------------------------------------------
-- NINJA SELECTION
--------------------------------------------------------------------------------

Remotes.Match.SelectNinja.OnServerEvent:Connect(function(player, ninjaKey)
	if NinjaData.GetNinja(ninjaKey) then
		playerNinjaSelection[player] = ninjaKey
	end
end)

--------------------------------------------------------------------------------
-- QUEUE SYSTEM
--------------------------------------------------------------------------------

Remotes.Match.JoinQueue.OnServerEvent:Connect(function(player)
	if isInQueue(player) or isInMatch(player) then return end

	table.insert(queue, player)
	Remotes.Match.QueueStatus:FireClient(player, "queued", #queue)
	print("[MatchManager] " .. player.Name .. " joined queue. Queue size: " .. #queue)

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

tryMatchPlayers = function()
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

startMatch = function(player1, player2)
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

	-- Notify players (safe for bots) — includes own ninja key for client VFX
	safeFireClient(Remotes.Match.MatchFound, player1, player2.Name, getNinjaSelection(player2), getNinjaSelection(player1))
	safeFireClient(Remotes.Match.MatchFound, player2, player1.Name, getNinjaSelection(player1), getNinjaSelection(player2))

	-- Wait for CombatHandler to be ready
	CombatAPI.WaitForReady()

	-- Initialize combat states with match ID so getOpponent is match-aware
	CombatAPI.InitPlayerCombat(player1, getNinjaSelection(player1), matchId)
	CombatAPI.InitPlayerCombat(player2, getNinjaSelection(player2), matchId)

	-- Start bot AI if one participant is a bot
	if isBotPlayer(player2) and CombatAPI.StartBotAI then
		CombatAPI.StartBotAI(player2, player1)
	elseif isBotPlayer(player1) and CombatAPI.StartBotAI then
		CombatAPI.StartBotAI(player1, player2)
	end

	-- Start first round
	task.spawn(function()
		startRound(match)
	end)
end

startRound = function(match)
	if not match.IsActive then return end

	match.CurrentRound = match.CurrentRound + 1
	local roundNum = match.CurrentRound

	print("[MatchManager] Match #" .. match.Id .. " — Round " .. roundNum)

	-- Teleport players to arena spawns
	teleportPlayer(match.Player1, ARENA_SPAWN_A)
	teleportPlayer(match.Player2, ARENA_SPAWN_B)

	-- Reset combat states for new round
	CombatAPI.ResetPlayerCombat(match.Player1)
	CombatAPI.ResetPlayerCombat(match.Player2)

	-- Countdown
	for i = CombatConfig.Match.CountdownTime, 1, -1 do
		safeFireClient(Remotes.Match.RoundStart, match.Player1, roundNum, i)
		safeFireClient(Remotes.Match.RoundStart, match.Player2, roundNum, i)
		task.wait(1)
	end

	-- FIGHT!
	safeFireClient(Remotes.Match.RoundStart, match.Player1, roundNum, 0)
	safeFireClient(Remotes.Match.RoundStart, match.Player2, roundNum, 0)
end

endRound = function(match, winner, loser)
	if not match.IsActive then return end

	match.Scores[winner] = match.Scores[winner] + 1

	local p1Score = match.Scores[match.Player1]
	local p2Score = match.Scores[match.Player2]

	safeFireClient(Remotes.Match.RoundEnd, match.Player1, winner.Name, p1Score, p2Score)
	safeFireClient(Remotes.Match.RoundEnd, match.Player2, winner.Name, p2Score, p1Score)

	print("[MatchManager] Round won by " .. winner.Name .. " (" .. p1Score .. "-" .. p2Score .. ")")

	if match.Scores[winner] >= CombatConfig.Match.RoundsToWin then
		task.wait(CombatConfig.Match.RoundEndFreeze)
		endMatch(match, winner, loser)
	else
		task.wait(CombatConfig.Match.RoundEndFreeze)
		startRound(match)
	end
end

endMatch = function(match, winner, loser)
	match.IsActive = false

	print("[MatchManager] Match #" .. match.Id .. " won by " .. winner.Name)

	safeFireClient(Remotes.Match.MatchEnd, match.Player1, winner.Name)
	safeFireClient(Remotes.Match.MatchEnd, match.Player2, winner.Name)

	-- Stop bot AI and destroy bot if applicable
	if isBotPlayer(match.Player2) then
		if CombatAPI.StopBotAI then CombatAPI.StopBotAI(match.Player2) end
		CombatAPI.RemovePlayerCombat(match.Player2)
		if CombatAPI.DestroyBot then CombatAPI.DestroyBot(match.Player2) end
		CombatAPI.RemovePlayerCombat(match.Player1)
	elseif isBotPlayer(match.Player1) then
		if CombatAPI.StopBotAI then CombatAPI.StopBotAI(match.Player1) end
		CombatAPI.RemovePlayerCombat(match.Player1)
		if CombatAPI.DestroyBot then CombatAPI.DestroyBot(match.Player1) end
		CombatAPI.RemovePlayerCombat(match.Player2)
	else
		CombatAPI.RemovePlayerCombat(match.Player1)
		CombatAPI.RemovePlayerCombat(match.Player2)
	end

	-- Teleport real players back to lobby
	if not isBotPlayer(match.Player1) then
		task.wait(2)
		teleportPlayer(match.Player1, LOBBY_SPAWN)
	end
	if not isBotPlayer(match.Player2) then
		task.wait(0.1)
		teleportPlayer(match.Player2, LOBBY_SPAWN)
	end

	-- Clean up match tracking
	playerToMatch[match.Player1] = nil
	playerToMatch[match.Player2] = nil
	activeMatches[match.Id] = nil
end

--------------------------------------------------------------------------------
-- PRACTICE MODE (Player vs Bot)
--------------------------------------------------------------------------------

-- Pick a random ninja for the bot that's different from the player's choice
local function pickBotNinja(playerNinja)
	local allNinjas = NinjaData.GetAllNinjaNames()
	local choices = {}
	for _, name in ipairs(allNinjas) do
		if name ~= playerNinja then
			table.insert(choices, name)
		end
	end
	if #choices > 0 then
		return choices[math.random(1, #choices)]
	end
	return "MistBlade" -- fallback
end

startPracticeMatch = function(player)
	if isInMatch(player) or isInQueue(player) then
		print("[MatchManager] Player already in match or queue, ignoring practice request")
		return
	end

	-- Make sure player character is loaded before proceeding
	waitForCharacter(player)

	CombatAPI.WaitForReady()

	-- Wait for bot functions to be registered by BotManager
	local attempts = 0
	while not CombatAPI.SpawnBot and attempts < 50 do
		task.wait(0.1)
		attempts = attempts + 1
	end
	if not CombatAPI.SpawnBot then
		warn("[MatchManager] BotManager not loaded, cannot start practice")
		return
	end

	local playerNinja = getNinjaSelection(player)
	local botNinja = pickBotNinja(playerNinja)

	-- Spawn bot at arena spawn B
	local botPlayer = CombatAPI.SpawnBot(botNinja, ARENA_SPAWN_B)

	-- Register bot's ninja selection so startMatch uses the correct ninja
	playerNinjaSelection[botPlayer] = botNinja

	-- Start a match with the real player vs the bot
	startMatch(player, botPlayer)

	print("[MatchManager] Practice match started: " .. player.Name .. " vs " .. botPlayer.Name)
end

Remotes.Match.StartPractice.OnServerEvent:Connect(function(player)
	task.spawn(function()
		local ok, err = pcall(startPracticeMatch, player)
		if not ok then
			warn("[MatchManager] Practice match error: " .. tostring(err))
			-- Clean up match state so player can try again
			local matchId = playerToMatch[player]
			if matchId then
				local match = activeMatches[matchId]
				if match then
					match.IsActive = false
					playerToMatch[match.Player1] = nil
					playerToMatch[match.Player2] = nil
					activeMatches[matchId] = nil
				end
			end
			-- Tell client the match is over so buttons restore
			safeFireClient(Remotes.Match.MatchEnd, player, "Error")
		end
	end)
end)

Remotes.Match.LeavePractice.OnServerEvent:Connect(function(player)
	local matchId = playerToMatch[player]
	if not matchId then return end

	local match = activeMatches[matchId]
	if not match or not match.IsActive then return end

	-- End match (player forfeits, but we don't care about the winner in practice)
	endMatch(match, player, player) -- player "wins" by leaving
end)

--------------------------------------------------------------------------------
-- KO EVENT LISTENER
--------------------------------------------------------------------------------

matchKOEvent.Event:Connect(function(attacker, victim)
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
	removeFromQueue(player)
	playerNinjaSelection[player] = nil

	local matchId = playerToMatch[player]
	if matchId then
		local match = activeMatches[matchId]
		if match and match.IsActive then
			-- If vs bot, just clean up; otherwise other player wins
			local otherPlayer = (match.Player1 == player) and match.Player2 or match.Player1
			endMatch(match, otherPlayer, player)
		end
	end
end)

print("[MatchManager] Loaded (with practice mode)")
