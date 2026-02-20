--[[
	BotPlayer
	A lightweight wrapper that mimics the Roblox Player interface
	so the CombatHandler can treat bots and real players identically.
]]

local BotPlayer = {}
BotPlayer.__index = BotPlayer

function BotPlayer.new(name: string, character: Model)
	local self = setmetatable({}, BotPlayer)
	self.Name = name or "Bot Ninja"
	self.Character = character
	self.IsBot = true
	-- Parent must be truthy so "player.Parent" checks pass
	-- Set to workspace (where the character lives)
	self.Parent = game:GetService("Workspace")
	return self
end

-- Bots don't have a PlayerGui, so we no-op these
function BotPlayer:WaitForChild()
	return nil
end

function BotPlayer:FindFirstChild()
	return nil
end

return BotPlayer
