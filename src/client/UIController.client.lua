--[[
	UIController (Client)
	TSB-style HUD:
	  - Health bar
	  - Stamina bar
	  - Awakening meter
	  - Move cooldown icons (Q/E/R/T/G)
	  - Kill feed
	  - Respawn timer
	  - Character selection UI
	  - Ragdoll / Critical indicators
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatConfig = require(Shared:WaitForChild("CombatConfig"))
local CharacterData = require(Shared:WaitForChild("CharacterData"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

--------------------------------------------------------------------------------
-- CREATE HUD
--------------------------------------------------------------------------------

local function createHUD()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "CombatHUD"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = playerGui

	-- Health bar
	local healthFrame = Instance.new("Frame")
	healthFrame.Name = "HealthFrame"
	healthFrame.Size = UDim2.new(0.4, 0, 0, 30)
	healthFrame.Position = UDim2.new(0.3, 0, 0.05, 0)
	healthFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	healthFrame.BorderSizePixel = 0
	healthFrame.Parent = screenGui
	Instance.new("UICorner", healthFrame).CornerRadius = UDim.new(0, 6)

	local healthBar = Instance.new("Frame")
	healthBar.Name = "HealthBar"
	healthBar.Size = UDim2.new(1, 0, 1, 0)
	healthBar.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
	healthBar.BorderSizePixel = 0
	healthBar.Parent = healthFrame
	Instance.new("UICorner", healthBar).CornerRadius = UDim.new(0, 6)

	local healthLabel = Instance.new("TextLabel")
	healthLabel.Name = "HealthLabel"
	healthLabel.Size = UDim2.new(1, 0, 1, 0)
	healthLabel.BackgroundTransparency = 1
	healthLabel.Text = "100 / 100"
	healthLabel.TextColor3 = Color3.new(1, 1, 1)
	healthLabel.TextScaled = true
	healthLabel.Font = Enum.Font.GothamBold
	healthLabel.ZIndex = 2
	healthLabel.Parent = healthFrame

	-- Stamina bar
	local staminaFrame = Instance.new("Frame")
	staminaFrame.Name = "StaminaFrame"
	staminaFrame.Size = UDim2.new(0.25, 0, 0, 10)
	staminaFrame.Position = UDim2.new(0.375, 0, 0.09, 0)
	staminaFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	staminaFrame.BorderSizePixel = 0
	staminaFrame.Parent = screenGui
	Instance.new("UICorner", staminaFrame).CornerRadius = UDim.new(0, 4)

	local staminaBar = Instance.new("Frame")
	staminaBar.Name = "StaminaBar"
	staminaBar.Size = UDim2.new(1, 0, 1, 0)
	staminaBar.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
	staminaBar.BorderSizePixel = 0
	staminaBar.Parent = staminaFrame
	Instance.new("UICorner", staminaBar).CornerRadius = UDim.new(0, 4)

	-- Awakening meter
	local awakeFrame = Instance.new("Frame")
	awakeFrame.Name = "AwakeningFrame"
	awakeFrame.Size = UDim2.new(0.2, 0, 0, 8)
	awakeFrame.Position = UDim2.new(0.4, 0, 0.105, 0)
	awakeFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	awakeFrame.BorderSizePixel = 0
	awakeFrame.Parent = screenGui
	Instance.new("UICorner", awakeFrame).CornerRadius = UDim.new(0, 3)

	local awakeBar = Instance.new("Frame")
	awakeBar.Name = "AwakeBar"
	awakeBar.Size = UDim2.new(0, 0, 1, 0)
	awakeBar.BackgroundColor3 = Color3.fromRGB(255, 120, 30)
	awakeBar.BorderSizePixel = 0
	awakeBar.Parent = awakeFrame
	Instance.new("UICorner", awakeBar).CornerRadius = UDim.new(0, 3)

	local awakeLabel = Instance.new("TextLabel")
	awakeLabel.Name = "AwakeLabel"
	awakeLabel.Size = UDim2.new(1, 0, 0, 14)
	awakeLabel.Position = UDim2.new(0, 0, 0, -16)
	awakeLabel.BackgroundTransparency = 1
	awakeLabel.Text = "AWAKENING [G]"
	awakeLabel.TextColor3 = Color3.fromRGB(255, 150, 50)
	awakeLabel.TextScaled = true
	awakeLabel.Font = Enum.Font.GothamBold
	awakeLabel.Parent = awakeFrame

	-- Move cooldown icons
	local moveFrame = Instance.new("Frame")
	moveFrame.Name = "MoveFrame"
	moveFrame.Size = UDim2.new(0, 340, 0, 60)
	moveFrame.Position = UDim2.new(0.5, -170, 0.88, 0)
	moveFrame.BackgroundTransparency = 1
	moveFrame.Parent = screenGui

	local moveLayout = Instance.new("UIListLayout")
	moveLayout.FillDirection = Enum.FillDirection.Horizontal
	moveLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	moveLayout.Padding = UDim.new(0, 8)
	moveLayout.Parent = moveFrame

	local moveSlots = {
		{ key = "Q", color = Color3.fromRGB(100, 200, 100), label = "Evasive" },
		{ key = "E", color = Color3.fromRGB(80, 130, 220), label = "Move 1" },
		{ key = "R", color = Color3.fromRGB(220, 130, 50), label = "Move 2" },
		{ key = "T", color = Color3.fromRGB(180, 60, 180), label = "Move 3" },
		{ key = "G", color = Color3.fromRGB(220, 50, 50), label = "Awaken" },
	}

	for _, slot in ipairs(moveSlots) do
		local slotFrame = Instance.new("Frame")
		slotFrame.Name = "Slot_" .. slot.key
		slotFrame.Size = UDim2.new(0, 60, 0, 60)
		slotFrame.BackgroundColor3 = slot.color
		slotFrame.BorderSizePixel = 0
		slotFrame.Parent = moveFrame
		Instance.new("UICorner", slotFrame).CornerRadius = UDim.new(0, 8)

		local keyLabel = Instance.new("TextLabel")
		keyLabel.Name = "KeyLabel"
		keyLabel.Size = UDim2.new(1, 0, 0.5, 0)
		keyLabel.BackgroundTransparency = 1
		keyLabel.Text = slot.key
		keyLabel.TextColor3 = Color3.new(1, 1, 1)
		keyLabel.TextScaled = true
		keyLabel.Font = Enum.Font.GothamBold
		keyLabel.Parent = slotFrame

		local cooldownLabel = Instance.new("TextLabel")
		cooldownLabel.Name = "CooldownLabel"
		cooldownLabel.Size = UDim2.new(1, 0, 0.5, 0)
		cooldownLabel.Position = UDim2.new(0, 0, 0.5, 0)
		cooldownLabel.BackgroundTransparency = 1
		cooldownLabel.Text = ""
		cooldownLabel.TextColor3 = Color3.new(1, 1, 1)
		cooldownLabel.TextScaled = true
		cooldownLabel.Font = Enum.Font.Gotham
		cooldownLabel.Parent = slotFrame

		local overlay = Instance.new("Frame")
		overlay.Name = "CooldownOverlay"
		overlay.Size = UDim2.new(1, 0, 1, 0)
		overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		overlay.BackgroundTransparency = 1
		overlay.BorderSizePixel = 0
		overlay.ZIndex = 3
		overlay.Parent = slotFrame
		Instance.new("UICorner", overlay).CornerRadius = UDim.new(0, 8)
	end

	-- Ragdoll indicator
	local ragdollLabel = Instance.new("TextLabel")
	ragdollLabel.Name = "RagdollLabel"
	ragdollLabel.Size = UDim2.new(0, 280, 0, 35)
	ragdollLabel.Position = UDim2.new(0.5, -140, 0.6, 0)
	ragdollLabel.BackgroundTransparency = 1
	ragdollLabel.Text = "RAGDOLLED - Press Q to recover!"
	ragdollLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
	ragdollLabel.TextStrokeTransparency = 0.5
	ragdollLabel.TextScaled = true
	ragdollLabel.Font = Enum.Font.GothamBold
	ragdollLabel.Visible = false
	ragdollLabel.Parent = screenGui

	-- Critical indicator
	local critLabel = Instance.new("TextLabel")
	critLabel.Name = "CriticalLabel"
	critLabel.Size = UDim2.new(0, 180, 0, 18)
	critLabel.Position = UDim2.new(0.5, -90, 0.12, 0)
	critLabel.BackgroundTransparency = 1
	critLabel.Text = "CRITICAL HIT READY!"
	critLabel.TextColor3 = Color3.fromRGB(255, 240, 100)
	critLabel.TextStrokeTransparency = 0.3
	critLabel.TextScaled = true
	critLabel.Font = Enum.Font.GothamBold
	critLabel.Visible = false
	critLabel.Parent = screenGui

	-- Announcement
	local announcement = Instance.new("TextLabel")
	announcement.Name = "Announcement"
	announcement.Size = UDim2.new(0.6, 0, 0, 60)
	announcement.Position = UDim2.new(0.2, 0, 0.35, 0)
	announcement.BackgroundTransparency = 1
	announcement.Text = ""
	announcement.TextColor3 = Color3.new(1, 1, 1)
	announcement.TextStrokeTransparency = 0.5
	announcement.TextScaled = true
	announcement.Font = Enum.Font.GothamBold
	announcement.Visible = false
	announcement.Parent = screenGui

	-- Kill feed
	local killFeedFrame = Instance.new("Frame")
	killFeedFrame.Name = "KillFeedFrame"
	killFeedFrame.Size = UDim2.new(0, 250, 0, 150)
	killFeedFrame.Position = UDim2.new(1, -260, 0.02, 0)
	killFeedFrame.BackgroundTransparency = 1
	killFeedFrame.Parent = screenGui
	local kfLayout = Instance.new("UIListLayout")
	kfLayout.SortOrder = Enum.SortOrder.LayoutOrder
	kfLayout.Padding = UDim.new(0, 2)
	kfLayout.Parent = killFeedFrame

	-- Respawn timer
	local respawnLabel = Instance.new("TextLabel")
	respawnLabel.Name = "RespawnLabel"
	respawnLabel.Size = UDim2.new(0, 300, 0, 50)
	respawnLabel.Position = UDim2.new(0.5, -150, 0.45, 0)
	respawnLabel.BackgroundTransparency = 1
	respawnLabel.Text = ""
	respawnLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
	respawnLabel.TextStrokeTransparency = 0.3
	respawnLabel.TextScaled = true
	respawnLabel.Font = Enum.Font.GothamBold
	respawnLabel.Visible = false
	respawnLabel.Parent = screenGui

	-- Controls hint
	local controlsLabel = Instance.new("TextLabel")
	controlsLabel.Name = "ControlsHint"
	controlsLabel.Size = UDim2.new(0, 200, 0, 100)
	controlsLabel.Position = UDim2.new(0, 10, 0.82, 0)
	controlsLabel.BackgroundTransparency = 0.6
	controlsLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	controlsLabel.Text = "LMB: Attack\nF: Block\nQ: Evasive\nE/R/T: Moves\nG: Awakening\nShift: Sprint/Dash"
	controlsLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	controlsLabel.TextScaled = true
	controlsLabel.Font = Enum.Font.Gotham
	controlsLabel.TextXAlignment = Enum.TextXAlignment.Left
	controlsLabel.TextWrapped = true
	controlsLabel.Parent = screenGui
	Instance.new("UICorner", controlsLabel).CornerRadius = UDim.new(0, 6)

	return screenGui
end

--------------------------------------------------------------------------------
-- CHARACTER SELECT UI
--------------------------------------------------------------------------------

local function createCharacterSelectUI()
	local selectGui = Instance.new("ScreenGui")
	selectGui.Name = "CharacterSelect"
	selectGui.ResetOnSpawn = false
	selectGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	selectGui.DisplayOrder = 10
	selectGui.Parent = playerGui

	local bg = Instance.new("Frame")
	bg.Name = "Background"
	bg.Size = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	bg.BackgroundTransparency = 0.3
	bg.Parent = selectGui

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(0.6, 0, 0, 60)
	title.Position = UDim2.new(0.2, 0, 0.08, 0)
	title.BackgroundTransparency = 1
	title.Text = "SELECT YOUR FIGHTER"
	title.TextColor3 = Color3.fromRGB(255, 80, 30)
	title.TextStrokeTransparency = 0
	title.TextScaled = true
	title.Font = Enum.Font.GothamBold
	title.Parent = selectGui

	local cardsFrame = Instance.new("Frame")
	cardsFrame.Name = "CardsFrame"
	cardsFrame.Size = UDim2.new(0.9, 0, 0, 300)
	cardsFrame.Position = UDim2.new(0.05, 0, 0.2, 0)
	cardsFrame.BackgroundTransparency = 1
	cardsFrame.Parent = selectGui

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 15)
	layout.Parent = cardsFrame

	local characters = CharacterData.GetAllCharacterNames()
	for _, charKey in ipairs(characters) do
		local charInfo = CharacterData.GetCharacter(charKey)
		local card = Instance.new("TextButton")
		card.Name = "Card_" .. charKey
		card.Size = UDim2.new(0, 150, 0, 280)
		card.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
		card.BorderSizePixel = 0
		card.Text = ""
		card.Parent = cardsFrame
		Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)

		local accent = Instance.new("Frame")
		accent.Size = UDim2.new(1, 0, 0, 6)
		accent.BackgroundColor3 = charInfo.Colors.Primary
		accent.BorderSizePixel = 0
		accent.Parent = card
		Instance.new("UICorner", accent).CornerRadius = UDim.new(0, 10)

		local charBody = Instance.new("Frame")
		charBody.Size = UDim2.new(0, 50, 0, 80)
		charBody.Position = UDim2.new(0.5, -25, 0.08, 0)
		charBody.BackgroundColor3 = charInfo.BodyColor
		charBody.BorderSizePixel = 0
		charBody.Parent = card
		Instance.new("UICorner", charBody).CornerRadius = UDim.new(0, 5)

		local headFrame = Instance.new("Frame")
		headFrame.Size = UDim2.new(0, 30, 0, 30)
		headFrame.Position = UDim2.new(0.5, -15, 0.02, 0)
		headFrame.BackgroundColor3 = Color3.fromRGB(245, 205, 170)
		headFrame.BorderSizePixel = 0
		headFrame.Parent = card
		Instance.new("UICorner", headFrame).CornerRadius = UDim.new(1, 0)

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(0.9, 0, 0, 22)
		nameLabel.Position = UDim2.new(0.05, 0, 0.42, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = charInfo.DisplayName
		nameLabel.TextColor3 = charInfo.Colors.Primary
		nameLabel.TextScaled = true
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.Parent = card

		local descLabel = Instance.new("TextLabel")
		descLabel.Size = UDim2.new(0.85, 0, 0, 40)
		descLabel.Position = UDim2.new(0.075, 0, 0.52, 0)
		descLabel.BackgroundTransparency = 1
		descLabel.Text = charInfo.Description
		descLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
		descLabel.TextScaled = true
		descLabel.Font = Enum.Font.Gotham
		descLabel.TextWrapped = true
		descLabel.Parent = card

		local tierLabel = Instance.new("TextLabel")
		tierLabel.Size = UDim2.new(0.5, 0, 0, 18)
		tierLabel.Position = UDim2.new(0.25, 0, 0.85, 0)
		tierLabel.BackgroundColor3 = Color3.fromRGB(60, 160, 60)
		tierLabel.Text = charInfo.Tier or "Free"
		tierLabel.TextColor3 = Color3.new(1, 1, 1)
		tierLabel.TextScaled = true
		tierLabel.Font = Enum.Font.GothamBold
		tierLabel.Parent = card
		Instance.new("UICorner", tierLabel).CornerRadius = UDim.new(0, 4)

		card.MouseButton1Click:Connect(function()
			Remotes.Game.SelectCharacter:FireServer(charKey)
		end)

		card.MouseEnter:Connect(function()
			TweenService:Create(card, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(50, 50, 60) }):Play()
		end)
		card.MouseLeave:Connect(function()
			TweenService:Create(card, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(35, 35, 40) }):Play()
		end)
	end

	return selectGui
end

--------------------------------------------------------------------------------
-- HUD UPDATES
--------------------------------------------------------------------------------

local hud = createHUD()
local charSelectUI = createCharacterSelectUI()

local function getElement(name)
	return hud:FindFirstChild(name, true)
end

local function showAnnouncement(text, duration, color)
	local label = getElement("Announcement")
	if label then
		label.Text = text
		label.TextColor3 = color or Color3.new(1, 1, 1)
		label.Visible = true
		task.delay(duration or 2, function()
			if label and label.Text == text then label.Visible = false end
		end)
	end
end

local function addKillFeedEntry(attackerName, victimName)
	local feedFrame = getElement("KillFeedFrame")
	if not feedFrame then return end

	local entry = Instance.new("TextLabel")
	entry.Size = UDim2.new(1, 0, 0, 20)
	entry.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	entry.BackgroundTransparency = 0.5
	entry.Text = attackerName .. " eliminated " .. victimName
	entry.TextColor3 = Color3.fromRGB(255, 200, 200)
	entry.TextScaled = true
	entry.Font = Enum.Font.GothamBold
	entry.TextXAlignment = Enum.TextXAlignment.Right
	entry.Parent = feedFrame
	Instance.new("UICorner", entry).CornerRadius = UDim.new(0, 4)

	task.delay(3, function()
		if entry and entry.Parent then
			TweenService:Create(entry, TweenInfo.new(1), { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
			task.delay(1.1, function() if entry and entry.Parent then entry:Destroy() end end)
		end
	end)
end

--------------------------------------------------------------------------------
-- REMOTES
--------------------------------------------------------------------------------

Remotes.Combat.HealthUpdate.OnClientEvent:Connect(function(targetPlayer, current, max)
	if targetPlayer == player then
		local fraction = math.clamp(current / max, 0, 1)
		local bar = getElement("HealthBar")
		if bar and bar.Parent and bar.Parent.Name == "HealthFrame" then
			bar.Size = UDim2.new(fraction, 0, 1, 0)
			bar.BackgroundColor3 = Color3.fromRGB(math.floor(255 * (1 - fraction)), math.floor(200 * fraction), 50)
		end
		local label = getElement("HealthLabel")
		if label then label.Text = math.floor(current) .. " / " .. max end
	end
end)

Remotes.Combat.StaminaUpdate.OnClientEvent:Connect(function(current, max)
	local bar = getElement("StaminaBar")
	if bar then bar.Size = UDim2.new(math.clamp(current / max, 0, 1), 0, 1, 0) end
end)

Remotes.Combat.AwakeningUpdate.OnClientEvent:Connect(function(current, max)
	local bar = getElement("AwakeBar")
	if bar then bar.Size = UDim2.new(math.clamp(current / max, 0, 1), 0, 1, 0) end
	local label = getElement("AwakeLabel")
	if label then
		if current >= max then
			label.Text = "AWAKENING READY! [G]"
			label.TextColor3 = Color3.fromRGB(255, 240, 100)
		else
			label.Text = "AWAKENING [G]"
			label.TextColor3 = Color3.fromRGB(255, 150, 50)
		end
	end
end)

Remotes.Combat.CooldownStart.OnClientEvent:Connect(function(slot, duration)
	local slotFrame = getElement("Slot_" .. slot)
	if not slotFrame then return end
	local overlay = slotFrame:FindFirstChild("CooldownOverlay")
	local cdLabel = slotFrame:FindFirstChild("CooldownLabel")
	if not overlay or not cdLabel then return end
	overlay.BackgroundTransparency = 0.6
	task.spawn(function()
		local endTime = os.clock() + duration
		while os.clock() < endTime do
			cdLabel.Text = tostring(math.ceil(endTime - os.clock()))
			task.wait(0.1)
		end
		cdLabel.Text = ""
		overlay.BackgroundTransparency = 1
	end)
end)

Remotes.Combat.Ragdoll.OnClientEvent:Connect(function(victim, ragdolled)
	if victim == player then
		local label = getElement("RagdollLabel")
		if label then label.Visible = ragdolled end
	end
end)

Remotes.Combat.PerfectBlock.OnClientEvent:Connect(function(blocker)
	if blocker == player then
		local label = getElement("CriticalLabel")
		if label then label.Visible = true end
		showAnnouncement("PERFECT BLOCK!", 0.8, Color3.fromRGB(200, 220, 255))
	end
end)

Remotes.Combat.CriticalHit.OnClientEvent:Connect(function(attacker)
	if attacker == player then
		local label = getElement("CriticalLabel")
		if label then label.Visible = false end
	end
end)

Remotes.Combat.AwakeningState.OnClientEvent:Connect(function(targetPlayer, activated, name)
	if targetPlayer == player and activated then
		showAnnouncement(name or "AWAKENED!", 2, Color3.fromRGB(255, 215, 0))
	end
end)

Remotes.Game.CharacterConfirmed.OnClientEvent:Connect(function()
	if charSelectUI then charSelectUI.Enabled = false end
	showAnnouncement("FIGHT!", 2, Color3.fromRGB(255, 80, 30))
end)

Remotes.Game.KillFeed.OnClientEvent:Connect(function(attackerName, victimName)
	addKillFeedEntry(attackerName, victimName)
end)

Remotes.Game.RespawnTimer.OnClientEvent:Connect(function(seconds)
	local label = getElement("RespawnLabel")
	if label then label.Visible = true; label.Text = "Respawning in " .. seconds .. "..." end
end)

Remotes.Game.Respawned.OnClientEvent:Connect(function()
	local label = getElement("RespawnLabel")
	if label then label.Visible = false end
end)

Remotes.Game.PlayerDied.OnClientEvent:Connect(function(attacker, victim)
	if victim == player then
		showAnnouncement("ELIMINATED", 2, Color3.fromRGB(255, 50, 50))
	end
end)

print("[UIController] Loaded - TSB-style HUD")
