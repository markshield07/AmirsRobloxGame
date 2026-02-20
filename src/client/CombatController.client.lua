--[[
	CombatController (Client)
	Handles player input and sends combat intentions to the server.
	Also plays local VFX/animations for responsiveness.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatConfig = require(Shared:WaitForChild("CombatConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local player = Players.LocalPlayer
local mouse = player:GetMouse()

--------------------------------------------------------------------------------
-- LOCAL STATE (for input responsiveness only — server is authoritative)
--------------------------------------------------------------------------------

local isBlocking = false
local lastDashTime = 0
local lastDashDirection = nil
local lastDirectionTapTime = 0
local abilityCooldowns = { Q = 0, E = 0, R = 0, F = 0 }
local isInMatch = false

--------------------------------------------------------------------------------
-- HELPERS
--------------------------------------------------------------------------------

local function now()
	return tick()
end

local function getMoveDirection()
	local char = player.Character
	if not char then return Vector3.new(0, 0, -1) end
	local humanoid = char:FindFirstChild("Humanoid")
	if humanoid and humanoid.MoveDirection.Magnitude > 0 then
		return humanoid.MoveDirection
	end
	local root = char:FindFirstChild("HumanoidRootPart")
	if root then
		return root.CFrame.LookVector
	end
	return Vector3.new(0, 0, -1)
end

local function canUseAbility(slot)
	return now() >= abilityCooldowns[slot]
end

--------------------------------------------------------------------------------
-- M1 ATTACK (Left Mouse Button / Touch Tap)
--------------------------------------------------------------------------------

local function onAttack()
	if not isInMatch then return end
	if isBlocking then return end
	Remotes.Combat.Attack:FireServer()
end

mouse.Button1Down:Connect(onAttack)

-- Touch support
UserInputService.TouchTap:Connect(function(touchPositions, gameProcessed)
	if gameProcessed then return end
	onAttack()
end)

--------------------------------------------------------------------------------
-- BLOCK (Right Mouse Button — hold)
--------------------------------------------------------------------------------

mouse.Button2Down:Connect(function()
	if not isInMatch then return end
	isBlocking = true
	Remotes.Combat.Block:FireServer(true)
end)

mouse.Button2Up:Connect(function()
	if isBlocking then
		isBlocking = false
		Remotes.Combat.Block:FireServer(false)
	end
end)

--------------------------------------------------------------------------------
-- ABILITIES (Q, E, R, F keys)
--------------------------------------------------------------------------------

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if not isInMatch then return end
	if isBlocking then return end

	local key = input.KeyCode

	-- Abilities
	if key == Enum.KeyCode.Q and canUseAbility("Q") then
		Remotes.Combat.UseAbility:FireServer("Q")
	elseif key == Enum.KeyCode.E and canUseAbility("E") then
		Remotes.Combat.UseAbility:FireServer("E")
	elseif key == Enum.KeyCode.R and canUseAbility("R") then
		Remotes.Combat.UseAbility:FireServer("R")
	elseif key == Enum.KeyCode.F and canUseAbility("F") then
		Remotes.Combat.UseAbility:FireServer("F")

	-- Dash (Spacebar or double-tap WASD)
	elseif key == Enum.KeyCode.LeftShift or key == Enum.KeyCode.Space then
		if now() - lastDashTime >= CombatConfig.Dash.Cooldown then
			lastDashTime = now()
			local direction = getMoveDirection()
			Remotes.Combat.Dash:FireServer(direction)
		end
	end
end)

--------------------------------------------------------------------------------
-- SERVER EVENT LISTENERS
--------------------------------------------------------------------------------

-- Cooldown notification from server
Remotes.Combat.CooldownStart.OnClientEvent:Connect(function(slot, duration)
	abilityCooldowns[slot] = now() + duration
end)

-- Hit effect (damage numbers, screen shake, etc.)
Remotes.Combat.HitEffect.OnClientEvent:Connect(function(hitPosition, damage, wasBlockBreak)
	-- TODO: Spawn damage number GUI at hitPosition
	-- TODO: Camera shake if local player was hit
	-- TODO: Hit particles

	-- For now, just print
	if hitPosition then
		-- Placeholder: you'd spawn a BillboardGui with the damage number here
	end
end)

-- Match found
Remotes.Match.MatchFound.OnClientEvent:Connect(function(opponentName, opponentNinja)
	isInMatch = true
	print("[Client] Match found! vs " .. opponentName .. " (" .. opponentNinja .. ")")
end)

-- Round start countdown
Remotes.Match.RoundStart.OnClientEvent:Connect(function(roundNum, countdown)
	if countdown > 0 then
		print("[Client] Round " .. roundNum .. " starting in " .. countdown .. "...")
	else
		print("[Client] FIGHT!")
	end
end)

-- Round end
Remotes.Match.RoundEnd.OnClientEvent:Connect(function(winnerName, score1, score2)
	print("[Client] Round won by " .. winnerName .. " (" .. score1 .. "-" .. score2 .. ")")
end)

-- Match end
Remotes.Match.MatchEnd.OnClientEvent:Connect(function(winnerName, scores)
	isInMatch = false
	print("[Client] Match over! Winner: " .. winnerName)
end)

print("[CombatController] Loaded")
