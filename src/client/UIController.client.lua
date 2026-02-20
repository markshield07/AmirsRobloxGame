--[[
	UIController (Client)
	Manages all HUD elements: health bar, stamina bar, ability cooldowns,
	ultimate meter, dash cooldowns, ragdoll indicator, critical hit flash,
	round score, and queue UI.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatConfig = require(Shared:WaitForChild("CombatConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

--------------------------------------------------------------------------------
-- CREATE HUD
--------------------------------------------------------------------------------

local function createHUD()
	-- Main ScreenGui
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "CombatHUD"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = playerGui

	-- ===== HEALTH BAR (top center) =====
	local healthFrame = Instance.new("Frame")
	healthFrame.Name = "HealthFrame"
	healthFrame.Size = UDim2.new(0.4, 0, 0, 30)
	healthFrame.Position = UDim2.new(0.3, 0, 0.05, 0)
	healthFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	healthFrame.BorderSizePixel = 0
	healthFrame.Parent = screenGui

	local healthCorner = Instance.new("UICorner")
	healthCorner.CornerRadius = UDim.new(0, 6)
	healthCorner.Parent = healthFrame

	local healthBar = Instance.new("Frame")
	healthBar.Name = "HealthBar"
	healthBar.Size = UDim2.new(1, 0, 1, 0)
	healthBar.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
	healthBar.BorderSizePixel = 0
	healthBar.Parent = healthFrame

	local healthBarCorner = Instance.new("UICorner")
	healthBarCorner.CornerRadius = UDim.new(0, 6)
	healthBarCorner.Parent = healthBar

	local healthLabel = Instance.new("TextLabel")
	healthLabel.Name = "HealthLabel"
	healthLabel.Size = UDim2.new(1, 0, 1, 0)
	healthLabel.BackgroundTransparency = 1
	healthLabel.Text = "100 / 100"
	healthLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	healthLabel.TextScaled = true
	healthLabel.Font = Enum.Font.GothamBold
	healthLabel.ZIndex = 2
	healthLabel.Parent = healthFrame

	-- ===== OPPONENT HEALTH BAR (top center, above player's) =====
	local oppHealthFrame = Instance.new("Frame")
	oppHealthFrame.Name = "OpponentHealthFrame"
	oppHealthFrame.Size = UDim2.new(0.4, 0, 0, 24)
	oppHealthFrame.Position = UDim2.new(0.3, 0, 0.01, 0)
	oppHealthFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	oppHealthFrame.BorderSizePixel = 0
	oppHealthFrame.Visible = false
	oppHealthFrame.Parent = screenGui

	local oppCorner = Instance.new("UICorner")
	oppCorner.CornerRadius = UDim.new(0, 6)
	oppCorner.Parent = oppHealthFrame

	local oppHealthBar = Instance.new("Frame")
	oppHealthBar.Name = "HealthBar"
	oppHealthBar.Size = UDim2.new(1, 0, 1, 0)
	oppHealthBar.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
	oppHealthBar.BorderSizePixel = 0
	oppHealthBar.Parent = oppHealthFrame

	local oppHealthBarCorner = Instance.new("UICorner")
	oppHealthBarCorner.CornerRadius = UDim.new(0, 6)
	oppHealthBarCorner.Parent = oppHealthBar

	-- ===== STAMINA BAR (below health) =====
	local staminaFrame = Instance.new("Frame")
	staminaFrame.Name = "StaminaFrame"
	staminaFrame.Size = UDim2.new(0.25, 0, 0, 12)
	staminaFrame.Position = UDim2.new(0.375, 0, 0.09, 0)
	staminaFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	staminaFrame.BorderSizePixel = 0
	staminaFrame.Parent = screenGui

	local staminaCorner = Instance.new("UICorner")
	staminaCorner.CornerRadius = UDim.new(0, 4)
	staminaCorner.Parent = staminaFrame

	local staminaBar = Instance.new("Frame")
	staminaBar.Name = "StaminaBar"
	staminaBar.Size = UDim2.new(1, 0, 1, 0)
	staminaBar.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
	staminaBar.BorderSizePixel = 0
	staminaBar.Parent = staminaFrame

	local staminaBarCorner = Instance.new("UICorner")
	staminaBarCorner.CornerRadius = UDim.new(0, 4)
	staminaBarCorner.Parent = staminaBar

	-- ===== ABILITY COOLDOWN ICONS (bottom center) =====
	local abilityFrame = Instance.new("Frame")
	abilityFrame.Name = "AbilityFrame"
	abilityFrame.Size = UDim2.new(0, 280, 0, 60)
	abilityFrame.Position = UDim2.new(0.5, -140, 0.88, 0)
	abilityFrame.BackgroundTransparency = 1
	abilityFrame.Parent = screenGui

	local abilityLayout = Instance.new("UIListLayout")
	abilityLayout.FillDirection = Enum.FillDirection.Horizontal
	abilityLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	abilityLayout.Padding = UDim.new(0, 10)
	abilityLayout.Parent = abilityFrame

	local abilitySlots = { "Q", "E", "R", "F" }
	local slotColors = {
		Q = Color3.fromRGB(80, 180, 80),
		E = Color3.fromRGB(80, 130, 220),
		R = Color3.fromRGB(220, 130, 50),
		F = Color3.fromRGB(220, 50, 50),
	}

	for _, slot in ipairs(abilitySlots) do
		local slotFrame = Instance.new("Frame")
		slotFrame.Name = "Slot_" .. slot
		slotFrame.Size = UDim2.new(0, 60, 0, 60)
		slotFrame.BackgroundColor3 = slotColors[slot]
		slotFrame.BorderSizePixel = 0
		slotFrame.Parent = abilityFrame

		local slotCorner = Instance.new("UICorner")
		slotCorner.CornerRadius = UDim.new(0, 8)
		slotCorner.Parent = slotFrame

		local keyLabel = Instance.new("TextLabel")
		keyLabel.Name = "KeyLabel"
		keyLabel.Size = UDim2.new(1, 0, 0.5, 0)
		keyLabel.BackgroundTransparency = 1
		keyLabel.Text = slot
		keyLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		keyLabel.TextScaled = true
		keyLabel.Font = Enum.Font.GothamBold
		keyLabel.Parent = slotFrame

		local cooldownLabel = Instance.new("TextLabel")
		cooldownLabel.Name = "CooldownLabel"
		cooldownLabel.Size = UDim2.new(1, 0, 0.5, 0)
		cooldownLabel.Position = UDim2.new(0, 0, 0.5, 0)
		cooldownLabel.BackgroundTransparency = 1
		cooldownLabel.Text = ""
		cooldownLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		cooldownLabel.TextScaled = true
		cooldownLabel.Font = Enum.Font.Gotham
		cooldownLabel.Parent = slotFrame

		-- Dark overlay for when on cooldown
		local cooldownOverlay = Instance.new("Frame")
		cooldownOverlay.Name = "CooldownOverlay"
		cooldownOverlay.Size = UDim2.new(1, 0, 1, 0)
		cooldownOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		cooldownOverlay.BackgroundTransparency = 1 -- hidden by default
		cooldownOverlay.BorderSizePixel = 0
		cooldownOverlay.ZIndex = 3
		cooldownOverlay.Parent = slotFrame

		local overlayCorner = Instance.new("UICorner")
		overlayCorner.CornerRadius = UDim.new(0, 8)
		overlayCorner.Parent = cooldownOverlay
	end

	-- ===== ULTIMATE METER (above abilities) =====
	local ultFrame = Instance.new("Frame")
	ultFrame.Name = "UltimateFrame"
	ultFrame.Size = UDim2.new(0, 200, 0, 10)
	ultFrame.Position = UDim2.new(0.5, -100, 0.86, 0)
	ultFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	ultFrame.BorderSizePixel = 0
	ultFrame.Parent = screenGui

	local ultCorner = Instance.new("UICorner")
	ultCorner.CornerRadius = UDim.new(0, 4)
	ultCorner.Parent = ultFrame

	local ultBar = Instance.new("Frame")
	ultBar.Name = "UltBar"
	ultBar.Size = UDim2.new(0, 0, 1, 0)
	ultBar.BackgroundColor3 = Color3.fromRGB(255, 215, 0) -- gold
	ultBar.BorderSizePixel = 0
	ultBar.Parent = ultFrame

	local ultBarCorner = Instance.new("UICorner")
	ultBarCorner.CornerRadius = UDim.new(0, 4)
	ultBarCorner.Parent = ultBar

	local ultLabel = Instance.new("TextLabel")
	ultLabel.Name = "UltLabel"
	ultLabel.Size = UDim2.new(1, 0, 0, 16)
	ultLabel.Position = UDim2.new(0, 0, 0, -18)
	ultLabel.BackgroundTransparency = 1
	ultLabel.Text = "ULTIMATE"
	ultLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	ultLabel.TextScaled = true
	ultLabel.Font = Enum.Font.GothamBold
	ultLabel.Parent = ultFrame

	-- ===== ROUND SCORE (top right) =====
	local scoreLabel = Instance.new("TextLabel")
	scoreLabel.Name = "ScoreLabel"
	scoreLabel.Size = UDim2.new(0, 150, 0, 40)
	scoreLabel.Position = UDim2.new(1, -160, 0.02, 0)
	scoreLabel.BackgroundTransparency = 1
	scoreLabel.Text = "Round: 0 - 0"
	scoreLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	scoreLabel.TextScaled = true
	scoreLabel.Font = Enum.Font.GothamBold
	scoreLabel.Parent = screenGui

	-- ===== CENTER ANNOUNCEMENT (for countdown, round results) =====
	local announcement = Instance.new("TextLabel")
	announcement.Name = "Announcement"
	announcement.Size = UDim2.new(0.6, 0, 0, 80)
	announcement.Position = UDim2.new(0.2, 0, 0.35, 0)
	announcement.BackgroundTransparency = 1
	announcement.Text = ""
	announcement.TextColor3 = Color3.fromRGB(255, 255, 255)
	announcement.TextStrokeTransparency = 0.5
	announcement.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	announcement.TextScaled = true
	announcement.Font = Enum.Font.GothamBold
	announcement.Visible = false
	announcement.Parent = screenGui

	-- ===== DASH COOLDOWN INDICATORS (above abilities, left side) =====
	local dashFrame = Instance.new("Frame")
	dashFrame.Name = "DashFrame"
	dashFrame.Size = UDim2.new(0, 180, 0, 24)
	dashFrame.Position = UDim2.new(0.5, -90, 0.84, -8)
	dashFrame.BackgroundTransparency = 1
	dashFrame.Parent = screenGui

	local dashLayout = Instance.new("UIListLayout")
	dashLayout.FillDirection = Enum.FillDirection.Horizontal
	dashLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	dashLayout.Padding = UDim.new(0, 8)
	dashLayout.Parent = dashFrame

	-- Forward/Back dash indicator
	local fbDash = Instance.new("Frame")
	fbDash.Name = "FBDashCooldown"
	fbDash.Size = UDim2.new(0, 80, 0, 20)
	fbDash.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	fbDash.BorderSizePixel = 0
	fbDash.Parent = dashFrame

	local fbCorner = Instance.new("UICorner")
	fbCorner.CornerRadius = UDim.new(0, 4)
	fbCorner.Parent = fbDash

	local fbBar = Instance.new("Frame")
	fbBar.Name = "Bar"
	fbBar.Size = UDim2.new(1, 0, 1, 0)
	fbBar.BackgroundColor3 = Color3.fromRGB(200, 160, 50)
	fbBar.BorderSizePixel = 0
	fbBar.Parent = fbDash

	local fbBarCorner = Instance.new("UICorner")
	fbBarCorner.CornerRadius = UDim.new(0, 4)
	fbBarCorner.Parent = fbBar

	local fbLabel = Instance.new("TextLabel")
	fbLabel.Name = "Label"
	fbLabel.Size = UDim2.new(1, 0, 1, 0)
	fbLabel.BackgroundTransparency = 1
	fbLabel.Text = "Q Dash"
	fbLabel.TextColor3 = Color3.new(1, 1, 1)
	fbLabel.TextScaled = true
	fbLabel.Font = Enum.Font.GothamBold
	fbLabel.ZIndex = 2
	fbLabel.Parent = fbDash

	-- Side dash indicator
	local sideDash = Instance.new("Frame")
	sideDash.Name = "SideDashCooldown"
	sideDash.Size = UDim2.new(0, 80, 0, 20)
	sideDash.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	sideDash.BorderSizePixel = 0
	sideDash.Parent = dashFrame

	local sideCorner = Instance.new("UICorner")
	sideCorner.CornerRadius = UDim.new(0, 4)
	sideCorner.Parent = sideDash

	local sideBar = Instance.new("Frame")
	sideBar.Name = "Bar"
	sideBar.Size = UDim2.new(1, 0, 1, 0)
	sideBar.BackgroundColor3 = Color3.fromRGB(100, 180, 220)
	sideBar.BorderSizePixel = 0
	sideBar.Parent = sideDash

	local sideBarCorner = Instance.new("UICorner")
	sideBarCorner.CornerRadius = UDim.new(0, 4)
	sideBarCorner.Parent = sideBar

	local sideLabel = Instance.new("TextLabel")
	sideLabel.Name = "Label"
	sideLabel.Size = UDim2.new(1, 0, 1, 0)
	sideLabel.BackgroundTransparency = 1
	sideLabel.Text = "Side"
	sideLabel.TextColor3 = Color3.new(1, 1, 1)
	sideLabel.TextScaled = true
	sideLabel.Font = Enum.Font.GothamBold
	sideLabel.ZIndex = 2
	sideLabel.Parent = sideDash

	-- ===== RAGDOLL INDICATOR (center screen, shows when ragdolled) =====
	local ragdollLabel = Instance.new("TextLabel")
	ragdollLabel.Name = "RagdollLabel"
	ragdollLabel.Size = UDim2.new(0, 300, 0, 40)
	ragdollLabel.Position = UDim2.new(0.5, -150, 0.6, 0)
	ragdollLabel.BackgroundTransparency = 1
	ragdollLabel.Text = "RAGDOLLED - Press Q+A/D to recover!"
	ragdollLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
	ragdollLabel.TextStrokeTransparency = 0.5
	ragdollLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	ragdollLabel.TextScaled = true
	ragdollLabel.Font = Enum.Font.GothamBold
	ragdollLabel.Visible = false
	ragdollLabel.Parent = screenGui

	-- ===== CRITICAL HIT INDICATOR (below stamina, shows when you have critical buff) =====
	local critLabel = Instance.new("TextLabel")
	critLabel.Name = "CriticalLabel"
	critLabel.Size = UDim2.new(0, 200, 0, 20)
	critLabel.Position = UDim2.new(0.5, -100, 0.11, 0)
	critLabel.BackgroundTransparency = 1
	critLabel.Text = "CRITICAL HIT READY!"
	critLabel.TextColor3 = Color3.fromRGB(255, 240, 100)
	critLabel.TextStrokeTransparency = 0.3
	critLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	critLabel.TextScaled = true
	critLabel.Font = Enum.Font.GothamBold
	critLabel.Visible = false
	critLabel.Parent = screenGui

	-- ===== QUEUE BUTTON (lobby) =====
	local queueButton = Instance.new("TextButton")
	queueButton.Name = "QueueButton"
	queueButton.Size = UDim2.new(0, 200, 0, 50)
	queueButton.Position = UDim2.new(0.5, -100, 0.75, 0)
	queueButton.BackgroundColor3 = Color3.fromRGB(60, 160, 60)
	queueButton.Text = "FIND MATCH"
	queueButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	queueButton.TextScaled = true
	queueButton.Font = Enum.Font.GothamBold
	queueButton.BorderSizePixel = 0
	queueButton.Parent = screenGui

	local queueCorner = Instance.new("UICorner")
	queueCorner.CornerRadius = UDim.new(0, 10)
	queueCorner.Parent = queueButton

	-- ===== PRACTICE BUTTON (lobby) =====
	local practiceButton = Instance.new("TextButton")
	practiceButton.Name = "PracticeButton"
	practiceButton.Size = UDim2.new(0, 200, 0, 50)
	practiceButton.Position = UDim2.new(0.5, -100, 0.82, 0)
	practiceButton.BackgroundColor3 = Color3.fromRGB(60, 100, 200)
	practiceButton.Text = "PRACTICE vs BOT"
	practiceButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	practiceButton.TextScaled = true
	practiceButton.Font = Enum.Font.GothamBold
	practiceButton.BorderSizePixel = 0
	practiceButton.Parent = screenGui

	local practiceCorner = Instance.new("UICorner")
	practiceCorner.CornerRadius = UDim.new(0, 10)
	practiceCorner.Parent = practiceButton

	return screenGui
end

--------------------------------------------------------------------------------
-- HUD UPDATE FUNCTIONS
--------------------------------------------------------------------------------

local hud = createHUD()

local function getElement(name)
	return hud:FindFirstChild(name, true)
end

-- Health bar update
local function updateHealthBar(targetPlayer, current, max)
	local fraction = math.clamp(current / max, 0, 1)

	if targetPlayer == player then
		local bar = getElement("HealthBar")
		if bar and bar.Parent and bar.Parent.Name == "HealthFrame" then
			bar.Size = UDim2.new(fraction, 0, 1, 0)
			-- Color shifts from green to red
			local r = math.floor(255 * (1 - fraction))
			local g = math.floor(200 * fraction)
			bar.BackgroundColor3 = Color3.fromRGB(r, g, 50)
		end
		local label = getElement("HealthLabel")
		if label then
			label.Text = math.floor(current) .. " / " .. max
		end
	else
		-- Opponent health bar
		local oppFrame = getElement("OpponentHealthFrame")
		if oppFrame then
			oppFrame.Visible = true
			local oppBar = oppFrame:FindFirstChild("HealthBar")
			if oppBar then
				oppBar.Size = UDim2.new(fraction, 0, 1, 0)
			end
		end
	end
end

-- Stamina bar update
local function updateStaminaBar(current, max)
	local bar = getElement("StaminaBar")
	if bar then
		bar.Size = UDim2.new(math.clamp(current / max, 0, 1), 0, 1, 0)
	end
end

-- Ultimate meter update
local function updateUltimateMeter(current, max)
	local bar = getElement("UltBar")
	if bar then
		bar.Size = UDim2.new(math.clamp(current / max, 0, 1), 0, 1, 0)
	end
	-- Glow effect when full
	local ultLabel = getElement("UltLabel")
	if ultLabel then
		if current >= max then
			ultLabel.Text = "ULTIMATE READY!"
			ultLabel.TextColor3 = Color3.fromRGB(255, 255, 100)
		else
			ultLabel.Text = "ULTIMATE"
			ultLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
		end
	end
end

-- Ability cooldown update
local function startCooldownVisual(slot, duration)
	local slotFrame = getElement("Slot_" .. slot)
	if not slotFrame then return end

	local overlay = slotFrame:FindFirstChild("CooldownOverlay")
	local cdLabel = slotFrame:FindFirstChild("CooldownLabel")
	if not overlay or not cdLabel then return end

	-- Show overlay
	overlay.BackgroundTransparency = 0.6

	-- Countdown timer
	task.spawn(function()
		local endTime = os.clock() + duration
		while os.clock() < endTime do
			local remaining = math.ceil(endTime - os.clock())
			cdLabel.Text = tostring(remaining)
			task.wait(0.1)
		end
		cdLabel.Text = ""
		overlay.BackgroundTransparency = 1
	end)
end

-- Announcement display
local function showAnnouncement(text, duration)
	local label = getElement("Announcement")
	if label then
		label.Text = text
		label.Visible = true
		task.delay(duration or 2, function()
			if label then
				label.Visible = false
			end
		end)
	end
end

--------------------------------------------------------------------------------
-- CONNECT REMOTES TO UI
--------------------------------------------------------------------------------

Remotes.Combat.HealthUpdate.OnClientEvent:Connect(function(targetPlayer, current, max)
	updateHealthBar(targetPlayer, current, max)
end)

Remotes.Combat.StaminaUpdate.OnClientEvent:Connect(function(current, max)
	updateStaminaBar(current, max)
end)

Remotes.Combat.UltimateUpdate.OnClientEvent:Connect(function(current, max)
	updateUltimateMeter(current, max)
end)

Remotes.Combat.CooldownStart.OnClientEvent:Connect(function(slot, duration)
	startCooldownVisual(slot, duration)
end)

-- Ragdoll indicator
Remotes.Combat.Ragdoll.OnClientEvent:Connect(function(victim, ragdolled, duration)
	if victim == player then
		local label = getElement("RagdollLabel")
		if label then
			label.Visible = ragdolled
		end
	end
end)

-- Perfect block → show critical indicator
Remotes.Combat.PerfectBlock.OnClientEvent:Connect(function(blocker)
	if blocker == player then
		local label = getElement("CriticalLabel")
		if label then
			label.Visible = true
			label.Text = "CRITICAL HIT READY!"
			label.TextColor3 = Color3.fromRGB(255, 240, 100)
		end

		-- Flash the screen briefly
		local announcement = getElement("Announcement")
		if announcement then
			announcement.Text = "PERFECT BLOCK!"
			announcement.TextColor3 = Color3.fromRGB(200, 220, 255)
			announcement.Visible = true
			task.delay(0.8, function()
				if announcement and announcement.Text == "PERFECT BLOCK!" then
					announcement.Visible = false
					announcement.TextColor3 = Color3.fromRGB(255, 255, 255)
				end
			end)
		end
	end
end)

-- Critical hit / Black Flash notification
Remotes.Combat.CriticalHit.OnClientEvent:Connect(function(attacker, hitType)
	if attacker == player then
		-- We used our critical, hide the indicator
		local label = getElement("CriticalLabel")
		if label then
			label.Visible = false
		end
	end
end)

-- Match events
Remotes.Match.MatchFound.OnClientEvent:Connect(function(opponentName, opponentNinja)
	waitingForPractice = false
	local queueButton = getElement("QueueButton")
	if queueButton then queueButton.Visible = false end
	local practiceButton = getElement("PracticeButton")
	if practiceButton then practiceButton.Visible = false end
	showAnnouncement("VS " .. opponentName, 2)
end)

Remotes.Match.RoundStart.OnClientEvent:Connect(function(roundNum, countdown)
	if countdown > 0 then
		showAnnouncement(tostring(countdown), 0.9)
	else
		showAnnouncement("FIGHT!", 1.5)
	end
end)

Remotes.Match.RoundEnd.OnClientEvent:Connect(function(winnerName, myScore, opponentScore)
	local scoreLabel = getElement("ScoreLabel")
	if scoreLabel then
		scoreLabel.Text = "You: " .. myScore .. " - " .. opponentScore
	end
	showAnnouncement(winnerName .. " wins the round!", 2)
end)

Remotes.Match.MatchEnd.OnClientEvent:Connect(function(winnerName)
	showAnnouncement(winnerName .. " WINS THE MATCH!", 3)

	-- Reset state so buttons work correctly after match
	isQueued = false
	waitingForPractice = false

	-- Show buttons again after a delay
	task.delay(4, function()
		local queueBtn = getElement("QueueButton")
		if queueBtn then
			queueBtn.Visible = true
			queueBtn.Text = "FIND MATCH"
			queueBtn.BackgroundColor3 = Color3.fromRGB(60, 160, 60)
		end
		local practiceBtn = getElement("PracticeButton")
		if practiceBtn then
			practiceBtn.Visible = true
			practiceBtn.Text = "PRACTICE vs BOT"
			practiceBtn.BackgroundColor3 = Color3.fromRGB(60, 100, 200)
		end
		local oppFrame = getElement("OpponentHealthFrame")
		if oppFrame then oppFrame.Visible = false end
		local scoreLabel = getElement("ScoreLabel")
		if scoreLabel then scoreLabel.Text = "Round: 0 - 0" end
	end)
end)

Remotes.Match.QueueStatus.OnClientEvent:Connect(function(status, queueSize)
	local queueButton = getElement("QueueButton")
	if queueButton then
		if status == "queued" then
			queueButton.Text = "SEARCHING... (" .. queueSize .. ")"
			queueButton.BackgroundColor3 = Color3.fromRGB(200, 160, 40)
		elseif status == "left" then
			queueButton.Text = "FIND MATCH"
			queueButton.BackgroundColor3 = Color3.fromRGB(60, 160, 60)
		end
	end
end)

--------------------------------------------------------------------------------
-- QUEUE BUTTON INTERACTION
--------------------------------------------------------------------------------

local isQueued = false

local queueButton = getElement("QueueButton")
if queueButton then
	queueButton.MouseButton1Click:Connect(function()
		if not isQueued then
			isQueued = true
			Remotes.Match.JoinQueue:FireServer()
		else
			isQueued = false
			Remotes.Match.LeaveQueue:FireServer()
		end
	end)
end

--------------------------------------------------------------------------------
-- PRACTICE BUTTON INTERACTION
--------------------------------------------------------------------------------

local waitingForPractice = false

local practiceButton = getElement("PracticeButton")
if practiceButton then
	practiceButton.MouseButton1Click:Connect(function()
		if waitingForPractice then return end
		waitingForPractice = true

		practiceButton.Text = "STARTING..."
		practiceButton.BackgroundColor3 = Color3.fromRGB(120, 120, 120)
		if queueButton then queueButton.Visible = false end
		Remotes.Match.StartPractice:FireServer()

		-- Safety timeout: restore buttons if match doesn't start within 10 seconds
		task.delay(10, function()
			if waitingForPractice then
				waitingForPractice = false
				if practiceButton then
					practiceButton.Text = "PRACTICE vs BOT"
					practiceButton.BackgroundColor3 = Color3.fromRGB(60, 100, 200)
					practiceButton.Visible = true
				end
				if queueButton then
					queueButton.Visible = true
				end
			end
		end)
	end)
end

print("[UIController] Loaded")
