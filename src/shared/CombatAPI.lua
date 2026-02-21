--[[
	CombatAPI
	Shared interface between server modules (CombatHandler, GameManager, BotManager).
	Functions are registered at runtime by the owning module.
]]

local CombatAPI = {}

-- Registered by CombatHandler:
-- CombatAPI.InitPlayerCombat(player, characterKey)
-- CombatAPI.ResetPlayerCombat(player)
-- CombatAPI.RemovePlayerCombat(player)
-- CombatAPI.GetPlayerState(player)

-- Bot combat functions (registered by CombatHandler):
-- CombatAPI.BotAttack(botPlayer)
-- CombatAPI.BotUseMove(botPlayer, slot)
-- CombatAPI.BotBlock(botPlayer, blocking)
-- CombatAPI.BotDash(botPlayer, direction, dashType)
-- CombatAPI.BotEvasive(botPlayer, direction)

-- Registered by BotManager:
-- CombatAPI.SpawnBot(characterKey, position) → BotPlayer
-- CombatAPI.DestroyBot(botPlayer)
-- CombatAPI.StartBotAI(botPlayer, humanPlayer)
-- CombatAPI.StopBotAI(botPlayer)

-- Ready flag
CombatAPI._ready = false

function CombatAPI.MarkReady()
	CombatAPI._ready = true
end

function CombatAPI.WaitForReady()
	while not CombatAPI._ready do
		task.wait(0.1)
	end
end

return CombatAPI
