--[[
	CombatAPI (Shared ModuleScript)
	Bridge between CombatHandler and MatchManager.
	CombatHandler registers its functions here; MatchManager calls them.
	This eliminates the _G race condition.
]]

local CombatAPI = {}

-- These get set by CombatHandler when it loads
CombatAPI.InitPlayerCombat = nil   -- function(player, ninjaKey)
CombatAPI.ResetPlayerCombat = nil  -- function(player)
CombatAPI.RemovePlayerCombat = nil -- function(player)
CombatAPI.SetPlayerMatchId = nil   -- function(player, matchId)

-- Flag so MatchManager can wait until CombatHandler has registered
CombatAPI.IsReady = false

-- Wait until CombatHandler has registered its functions
function CombatAPI.WaitForReady()
	while not CombatAPI.IsReady do
		task.wait(0.1)
	end
end

return CombatAPI
