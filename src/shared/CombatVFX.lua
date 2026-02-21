--[[
	CombatVFX
	TSB-style visual effects: hit-stop freeze frames, directional screen shake,
	ground destruction, impact shockwaves, ragdoll indicators, critical/black
	flash particles, uppercut/downslam effects.

	Uses character color (Color3) instead of element strings.
	playAbility() routes to generic VFX based on move properties from CharacterData.
]]

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local CombatVFX = {}

--------------------------------------------------------------------------------
-- HELPERS
--------------------------------------------------------------------------------

local DEFAULT_COLOR = Color3.fromRGB(255, 255, 255)

local function getRoot(character)
	if not character then return nil end
	return character:FindFirstChild("HumanoidRootPart")
end

local function effectPart(props)
	local part = Instance.new("Part")
	part.Name = props.Name or "VFX"
	part.Anchored = true
	part.CanCollide = false
	part.CastShadow = false
	part.Material = props.Material or Enum.Material.Neon
	part.Color = props.Color or Color3.new(1, 1, 1)
	part.Transparency = props.Transparency or 0.3
	part.Size = props.Size or Vector3.new(1, 1, 1)
	if props.Shape then part.Shape = props.Shape end
	if props.CFrame then
		part.CFrame = props.CFrame
	elseif props.Position then
		part.Position = props.Position
	end
	part.Parent = workspace
	return part
end

--------------------------------------------------------------------------------
-- HIT-STOP (brief freeze frame for impact feel)
--------------------------------------------------------------------------------

function CombatVFX.playHitStop(duration)
	local player = Players.LocalPlayer
	if not player then return end
	local char = player.Character
	if not char then return end
	local humanoid = char:FindFirstChild("Humanoid")
	if not humanoid then return end

	local originalSpeed = humanoid.WalkSpeed
	humanoid.WalkSpeed = 0
	task.delay(duration, function()
		if humanoid and humanoid.Parent then
			humanoid.WalkSpeed = originalSpeed
		end
	end)
end

--------------------------------------------------------------------------------
-- DIRECTIONAL SCREEN SHAKE
--------------------------------------------------------------------------------

function CombatVFX.directionalShake(intensity, duration, direction)
	local camera = workspace.CurrentCamera
	if not camera then return end

	local shakeDir = direction or Vector3.new(1, 0, 0)
	local camCF = camera.CFrame
	local localDir = camCF:VectorToObjectSpace(shakeDir).Unit

	local startTime = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local elapsed = os.clock() - startTime
		if elapsed >= duration then
			conn:Disconnect()
			return
		end

		local decay = 1 - (elapsed / duration)
		local progress = elapsed / duration
		local wave = math.sin(progress * math.pi * 6) * decay
		local shakeX = localDir.X * wave * intensity + (math.random() - 0.5) * 0.2 * intensity * decay
		local shakeY = localDir.Y * wave * intensity * 0.5 + (math.random() - 0.5) * 0.3 * intensity * decay
		camera.CFrame = camera.CFrame * CFrame.new(shakeX, shakeY, 0)
	end)
end

function CombatVFX.cameraShake(intensity, duration)
	local camera = workspace.CurrentCamera
	if not camera then return end

	local startTime = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local elapsed = os.clock() - startTime
		if elapsed >= duration then
			conn:Disconnect()
			return
		end

		local decay = 1 - (elapsed / duration)
		local shakeX = (math.random() - 0.5) * 2 * intensity * decay
		local shakeY = (math.random() - 0.5) * 2 * intensity * decay
		camera.CFrame = camera.CFrame * CFrame.new(shakeX, shakeY, 0)
	end)
end

--------------------------------------------------------------------------------
-- GROUND DESTRUCTION (cracks + flying debris at impact point)
--------------------------------------------------------------------------------

function CombatVFX.groundDestruction(position, intensity, color)
	color = color or DEFAULT_COLOR
	local numCracks = math.floor(intensity * 3) + 4
	local crackLength = intensity * 3 + 2

	for i = 1, numCracks do
		local angle = math.rad(i * (360 / numCracks) + math.random(-15, 15))
		local crackDir = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local crackPos = position + Vector3.new(0, -2, 0) + crackDir * 1.5

		local crack = effectPart({
			Name = "GroundCrack",
			Color = Color3.fromRGB(60, 55, 50),
			Size = Vector3.new(0.25 + intensity * 0.05, 0.1, 1.5),
			CFrame = CFrame.lookAt(crackPos, crackPos + crackDir) * CFrame.new(0, 0, -0.75),
			Transparency = 0.1,
			Material = Enum.Material.Slate,
		})

		TweenService:Create(crack, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
			Size = Vector3.new(0.25 + intensity * 0.05, 0.1, crackLength),
			CFrame = crack.CFrame * CFrame.new(0, 0, -(crackLength - 1.5) / 2),
			Transparency = 0.4,
		}):Play()

		task.delay(1.5, function()
			if crack and crack.Parent then
				TweenService:Create(crack, TweenInfo.new(1.0), { Transparency = 1 }):Play()
				Debris:AddItem(crack, 1.2)
			end
		end)
	end

	local debrisCount = math.floor(intensity * 2) + 3
	for i = 1, debrisCount do
		local rockSize = math.random() * 0.6 + 0.3
		local rock = effectPart({
			Name = "RockDebris",
			Color = Color3.fromRGB(80 + math.random(-15, 15), 75 + math.random(-15, 15), 70 + math.random(-15, 15)),
			Size = Vector3.new(rockSize, rockSize * 0.7, rockSize),
			Position = position + Vector3.new(0, -1, 0),
			Material = Enum.Material.Slate,
			Transparency = 0,
		})
		rock.Anchored = false
		rock.AssemblyLinearVelocity = Vector3.new(
			(math.random() - 0.5) * 25 * intensity,
			math.random() * 15 + 10 * intensity,
			(math.random() - 0.5) * 25 * intensity
		)
		rock.AssemblyAngularVelocity = Vector3.new(
			math.random() * 8, math.random() * 8, math.random() * 8
		)

		TweenService:Create(rock, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Transparency = 1,
			Size = Vector3.new(0.1, 0.1, 0.1),
		}):Play()
		Debris:AddItem(rock, 1.0)
	end

	local dust = effectPart({
		Name = "ImpactDust",
		Color = Color3.fromRGB(160, 155, 145),
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(2, 1, 2),
		Position = position + Vector3.new(0, -1.5, 0),
		Transparency = 0.4,
		Material = Enum.Material.SmoothPlastic,
	})

	TweenService:Create(dust, TweenInfo.new(0.6, Enum.EasingStyle.Quad), {
		Transparency = 1,
		Size = Vector3.new(6 + intensity * 2, 3, 6 + intensity * 2),
	}):Play()
	Debris:AddItem(dust, 0.8)
end

--------------------------------------------------------------------------------
-- IMPACT SHOCKWAVE RING
--------------------------------------------------------------------------------

function CombatVFX.impactShockwave(position, color, maxSize)
	maxSize = maxSize or 16
	color = color or DEFAULT_COLOR

	local ring = effectPart({
		Name = "ShockwaveRing",
		Color = color,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, 3, 3),
		CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)),
		Transparency = 0.2,
	})

	TweenService:Create(ring, TweenInfo.new(0.35, Enum.EasingStyle.Quad), {
		Transparency = 1,
		Size = Vector3.new(0.2, maxSize, maxSize),
	}):Play()
	Debris:AddItem(ring, 0.45)
end

--------------------------------------------------------------------------------
-- M1 SWING TRAIL (4-hit combo visuals)
--------------------------------------------------------------------------------

function CombatVFX.playM1Swing(character, comboIndex, color)
	local root = getRoot(character)
	if not root then return end

	color = color or DEFAULT_COLOR
	local secondaryColor = Color3.new(
		math.min(color.R + 0.3, 1),
		math.min(color.G + 0.3, 1),
		math.min(color.B + 0.3, 1)
	)

	local swingConfigs = {
		{ offset = CFrame.new(2, 0.5, -3) * CFrame.Angles(0, math.rad(-20), math.rad(-25)), size = Vector3.new(0.15, 1.8, 5) },
		{ offset = CFrame.new(-2, 0.5, -3) * CFrame.Angles(0, math.rad(20), math.rad(25)), size = Vector3.new(0.15, 1.8, 5) },
		{ offset = CFrame.new(0, 2.5, -3) * CFrame.Angles(math.rad(-50), 0, 0), size = Vector3.new(4.5, 0.18, 4.5) },
		{ offset = CFrame.new(0, 0, -4) * CFrame.Angles(math.rad(15), 0, 0), size = Vector3.new(6.5, 0.25, 6.5) },
	}

	local config = swingConfigs[comboIndex] or swingConfigs[1]
	local trailCF = root.CFrame * config.offset

	local trail = effectPart({
		Name = "SwingTrail",
		Color = color,
		Size = config.size,
		CFrame = trailCF,
		Transparency = 0.15,
	})

	TweenService:Create(trail, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Transparency = 1,
		Size = config.size * 1.5,
	}):Play()
	Debris:AddItem(trail, 0.3)

	local glow = effectPart({
		Name = "SwingGlow",
		Color = secondaryColor,
		Size = config.size * 0.7,
		CFrame = trailCF * CFrame.new(0, 0, -0.3),
		Transparency = 0.45,
	})

	TweenService:Create(glow, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Transparency = 1,
		Size = config.size * 1.2,
	}):Play()
	Debris:AddItem(glow, 0.35)

	if comboIndex >= 4 then
		CombatVFX.impactShockwave(root.Position + root.CFrame.LookVector * 4, secondaryColor, 16)
		CombatVFX.groundDestruction(root.Position + root.CFrame.LookVector * 3, 2.0, color)
	end
end

--------------------------------------------------------------------------------
-- UPPERCUT VFX
--------------------------------------------------------------------------------

function CombatVFX.playUppercut(character, color)
	local root = getRoot(character)
	if not root then return end
	color = color or DEFAULT_COLOR

	local arc = effectPart({
		Name = "UppercutArc",
		Color = color,
		Size = Vector3.new(4, 0.2, 4),
		CFrame = root.CFrame * CFrame.new(0, 3, -3) * CFrame.Angles(math.rad(-70), 0, 0),
		Transparency = 0.15,
	})

	TweenService:Create(arc, TweenInfo.new(0.25, Enum.EasingStyle.Quad), {
		Transparency = 1,
		Size = Vector3.new(6, 0.2, 8),
		CFrame = arc.CFrame * CFrame.new(0, 0, -2),
	}):Play()
	Debris:AddItem(arc, 0.35)

	CombatVFX.impactShockwave(root.Position, color, 12)

	for i = 1, 4 do
		local offset = Vector3.new((math.random() - 0.5) * 3, 0, (math.random() - 0.5) * 3)
		local line = effectPart({
			Name = "UppercutLine",
			Color = Color3.new(1, 1, 1),
			Size = Vector3.new(0.08, 2, 0.08),
			Position = root.Position + offset,
			Transparency = 0.2,
		})

		TweenService:Create(line, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Transparency = 1,
			Size = Vector3.new(0.08, 8, 0.08),
			Position = line.Position + Vector3.new(0, 6, 0),
		}):Play()
		Debris:AddItem(line, 0.4)
	end
end

--------------------------------------------------------------------------------
-- DOWNSLAM VFX
--------------------------------------------------------------------------------

function CombatVFX.playDownslam(character, color)
	local root = getRoot(character)
	if not root then return end
	color = color or DEFAULT_COLOR

	local slam = effectPart({
		Name = "DownslamTrail",
		Color = color,
		Size = Vector3.new(5, 0.25, 5),
		CFrame = root.CFrame * CFrame.new(0, -1, -3) * CFrame.Angles(math.rad(60), 0, 0),
		Transparency = 0.1,
	})

	TweenService:Create(slam, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
		Transparency = 1,
		Size = Vector3.new(8, 0.25, 8),
	}):Play()
	Debris:AddItem(slam, 0.3)

	task.delay(0.15, function()
		local impactPos = root.Position + root.CFrame.LookVector * 3 + Vector3.new(0, -2, 0)
		CombatVFX.impactShockwave(impactPos, color, 20)
		CombatVFX.groundDestruction(impactPos, 3.0, color)
	end)
end

--------------------------------------------------------------------------------
-- FORWARD DASH ATTACK VFX
--------------------------------------------------------------------------------

function CombatVFX.playForwardDashAttack(character, color)
	local root = getRoot(character)
	if not root then return end
	color = color or DEFAULT_COLOR

	local flash = effectPart({
		Name = "DashAttackFlash",
		Color = color,
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(2.5, 2.5, 2.5),
		CFrame = root.CFrame * CFrame.new(0, 0, -4),
		Transparency = 0.1,
	})

	TweenService:Create(flash, TweenInfo.new(0.15), {
		Transparency = 1,
		Size = Vector3.new(5, 5, 5),
	}):Play()
	Debris:AddItem(flash, 0.2)
end

--------------------------------------------------------------------------------
-- PERFECT BLOCK FLASH
--------------------------------------------------------------------------------

function CombatVFX.playPerfectBlock(character)
	local root = getRoot(character)
	if not root then return end

	local flash = effectPart({
		Name = "PerfectBlockFlash",
		Color = Color3.fromRGB(255, 255, 255),
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(5, 5, 5),
		Position = root.Position,
		Transparency = 0,
	})

	local flashLight = Instance.new("PointLight")
	flashLight.Color = Color3.new(1, 1, 1)
	flashLight.Brightness = 6
	flashLight.Range = 25
	flashLight.Parent = flash

	TweenService:Create(flash, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Transparency = 1,
		Size = Vector3.new(10, 10, 10),
	}):Play()
	Debris:AddItem(flash, 0.3)

	CombatVFX.impactShockwave(root.Position, Color3.fromRGB(200, 220, 255), 10)
end

--------------------------------------------------------------------------------
-- CRITICAL HIT VFX
--------------------------------------------------------------------------------

function CombatVFX.playCriticalHit(position)
	local flash = effectPart({
		Name = "CritFlash",
		Color = Color3.fromRGB(255, 240, 180),
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(3, 3, 3),
		Position = position,
		Transparency = 0,
	})

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 240, 180)
	light.Brightness = 5
	light.Range = 20
	light.Parent = flash

	TweenService:Create(flash, TweenInfo.new(0.25), {
		Transparency = 1,
		Size = Vector3.new(8, 8, 8),
	}):Play()
	Debris:AddItem(flash, 0.35)

	for i = 1, 4 do
		local angle = math.rad(i * 90 + math.random(-20, 20))
		local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))

		local crack = effectPart({
			Name = "CritCrack",
			Color = Color3.fromRGB(255, 255, 255),
			Size = Vector3.new(0.15, 0.15, 3),
			CFrame = CFrame.lookAt(position, position + dir),
			Transparency = 0,
		})

		TweenService:Create(crack, TweenInfo.new(0.2), {
			Transparency = 1,
			Size = Vector3.new(0.15, 0.15, 6),
			CFrame = crack.CFrame * CFrame.new(0, 0, -1.5),
		}):Play()
		Debris:AddItem(crack, 0.3)
	end
end

--------------------------------------------------------------------------------
-- BLACK FLASH VFX
--------------------------------------------------------------------------------

function CombatVFX.playBlackFlash(position)
	local dark = effectPart({
		Name = "BlackFlashSphere",
		Color = Color3.fromRGB(10, 5, 15),
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(4, 4, 4),
		Position = position,
		Transparency = 0.1,
		Material = Enum.Material.SmoothPlastic,
	})

	TweenService:Create(dark, TweenInfo.new(0.3), {
		Transparency = 1,
		Size = Vector3.new(12, 12, 12),
	}):Play()
	Debris:AddItem(dark, 0.4)

	for i = 1, 12 do
		local particle = effectPart({
			Name = "BFParticle",
			Color = i % 3 == 0 and Color3.fromRGB(180, 20, 20) or Color3.fromRGB(15, 10, 20),
			Size = Vector3.new(0.4, 0.4, 0.4),
			Position = position,
			Transparency = 0.1,
		})
		particle.Anchored = false
		particle.AssemblyLinearVelocity = Vector3.new(
			(math.random() - 0.5) * 35,
			math.random() * 20 + 5,
			(math.random() - 0.5) * 35
		)

		TweenService:Create(particle, TweenInfo.new(0.5), {
			Transparency = 1,
			Size = Vector3.new(0.1, 0.1, 0.1),
		}):Play()
		Debris:AddItem(particle, 0.6)
	end

	local flash = effectPart({
		Name = "BFFlash",
		Color = Color3.fromRGB(200, 20, 20),
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(2, 2, 2),
		Position = position,
		Transparency = 0,
	})

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(200, 20, 20)
	light.Brightness = 8
	light.Range = 30
	light.Parent = flash

	TweenService:Create(flash, TweenInfo.new(0.15), {
		Transparency = 1,
		Size = Vector3.new(6, 6, 6),
	}):Play()
	Debris:AddItem(flash, 0.25)

	CombatVFX.impactShockwave(position, Color3.fromRGB(180, 20, 20), 22)
end

--------------------------------------------------------------------------------
-- RAGDOLL INDICATORS
--------------------------------------------------------------------------------

function CombatVFX.playRagdollStart(character)
	local root = getRoot(character)
	if not root then return end

	local flash = effectPart({
		Name = "RagdollFlash",
		Color = Color3.fromRGB(255, 200, 100),
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(3, 3, 3),
		Position = root.Position,
		Transparency = 0.3,
	})

	TweenService:Create(flash, TweenInfo.new(0.2), {
		Transparency = 1,
		Size = Vector3.new(6, 6, 6),
	}):Play()
	Debris:AddItem(flash, 0.3)
end

function CombatVFX.playRagdollCancel(character)
	local root = getRoot(character)
	if not root then return end

	local burst = effectPart({
		Name = "RecoveryBurst",
		Color = Color3.fromRGB(150, 200, 255),
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(3, 3, 3),
		Position = root.Position,
		Transparency = 0.3,
	})

	TweenService:Create(burst, TweenInfo.new(0.2), {
		Transparency = 1,
		Size = Vector3.new(7, 7, 7),
	}):Play()
	Debris:AddItem(burst, 0.3)
end

--------------------------------------------------------------------------------
-- EVASIVE DODGE VFX
--------------------------------------------------------------------------------

function CombatVFX.playEvasive(character, color)
	local root = getRoot(character)
	if not root then return end
	color = color or DEFAULT_COLOR

	-- Afterimage at dodge start
	local afterimage = effectPart({
		Name = "EvasiveAfterimage",
		Color = color,
		Size = Vector3.new(2.5, 5, 1.5),
		CFrame = root.CFrame,
		Transparency = 0.4,
	})

	TweenService:Create(afterimage, TweenInfo.new(0.35), {
		Transparency = 1,
		Size = Vector3.new(3, 5.5, 2),
	}):Play()
	Debris:AddItem(afterimage, 0.45)

	-- Quick dust burst
	local dust = effectPart({
		Name = "EvasiveDust",
		Color = Color3.fromRGB(200, 200, 200),
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.5, 0.5, 1.5),
		Position = root.Position - Vector3.new(0, 2.5, 0),
		Transparency = 0.4,
		Material = Enum.Material.SmoothPlastic,
	})

	TweenService:Create(dust, TweenInfo.new(0.3), {
		Transparency = 1,
		Size = Vector3.new(5, 1.5, 5),
	}):Play()
	Debris:AddItem(dust, 0.4)
end

--------------------------------------------------------------------------------
-- AWAKENING VFX
--------------------------------------------------------------------------------

function CombatVFX.playAwakeningActivate(character, color)
	local root = getRoot(character)
	if not root then return end
	color = color or DEFAULT_COLOR

	-- Big burst sphere
	local burst = effectPart({
		Name = "AwakeningBurst",
		Color = color,
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(5, 5, 5),
		Position = root.Position,
		Transparency = 0,
	})

	local burstLight = Instance.new("PointLight")
	burstLight.Color = color
	burstLight.Brightness = 8
	burstLight.Range = 40
	burstLight.Parent = burst

	TweenService:Create(burst, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {
		Transparency = 1,
		Size = Vector3.new(25, 25, 25),
	}):Play()
	Debris:AddItem(burst, 0.6)

	-- Rising energy pillars
	for i = 1, 6 do
		local angle = math.rad(i * 60)
		local dist = 4
		local pillarPos = root.Position + Vector3.new(math.cos(angle) * dist, -2, math.sin(angle) * dist)

		local pillar = effectPart({
			Name = "AwakeningPillar",
			Color = color,
			Size = Vector3.new(1, 1, 1),
			Position = pillarPos,
			Transparency = 0.2,
		})

		TweenService:Create(pillar, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(1.5, 15, 1.5),
			Position = pillarPos + Vector3.new(0, 7, 0),
			Transparency = 1,
		}):Play()
		Debris:AddItem(pillar, 0.7)
	end

	-- Ground shockwave
	CombatVFX.impactShockwave(root.Position, color, 25)
	CombatVFX.groundDestruction(root.Position, 3.0, color)
end

function CombatVFX.playAwakeningDeactivate(character, color)
	local root = getRoot(character)
	if not root then return end
	color = color or DEFAULT_COLOR

	local fade = effectPart({
		Name = "AwakeningFade",
		Color = color,
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(8, 8, 8),
		Position = root.Position,
		Transparency = 0.5,
	})

	TweenService:Create(fade, TweenInfo.new(0.4), {
		Transparency = 1,
		Size = Vector3.new(3, 3, 3),
	}):Play()
	Debris:AddItem(fade, 0.5)
end

--------------------------------------------------------------------------------
-- HIT IMPACT (plays at victim's position on hit confirmation)
--------------------------------------------------------------------------------

function CombatVFX.playHitImpact(position, damage, color, wasBlockBreak, isCritical, isBlackFlash)
	color = color or DEFAULT_COLOR
	local secondaryColor = Color3.new(
		math.min(color.R + 0.3, 1),
		math.min(color.G + 0.3, 1),
		math.min(color.B + 0.3, 1)
	)

	if isBlackFlash then
		CombatVFX.playBlackFlash(position)
		CombatVFX.showDamageNumber(position, damage, true)
		return
	end

	if isCritical then
		CombatVFX.playCriticalHit(position)
		CombatVFX.showDamageNumber(position, damage, true)
		return
	end

	local impactColor = wasBlockBreak and Color3.fromRGB(255, 50, 50) or color

	local flash = effectPart({
		Name = "HitFlash",
		Color = impactColor,
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(2, 2, 2),
		Position = position,
		Transparency = 0.2,
	})

	local flashLight = Instance.new("PointLight")
	flashLight.Color = impactColor
	flashLight.Brightness = 3
	flashLight.Range = 18
	flashLight.Parent = flash

	TweenService:Create(flash, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Transparency = 1,
		Size = Vector3.new(5, 5, 5),
	}):Play()
	Debris:AddItem(flash, 0.4)

	local debrisCount = wasBlockBreak and 10 or 6
	for i = 1, debrisCount do
		local d = effectPart({
			Name = "HitDebris",
			Color = i % 2 == 0 and color or secondaryColor,
			Size = Vector3.new(0.25, 0.25, 0.25),
			Position = position,
		})
		d.Anchored = false
		d.AssemblyLinearVelocity = Vector3.new(
			(math.random() - 0.5) * 30,
			math.random() * 15 + 8,
			(math.random() - 0.5) * 30
		)

		TweenService:Create(d, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Transparency = 1,
			Size = Vector3.new(0.05, 0.05, 0.05),
		}):Play()
		Debris:AddItem(d, 0.6)
	end

	if wasBlockBreak then
		for i = 1, 8 do
			local shard = effectPart({
				Name = "BlockShard",
				Color = Color3.fromRGB(200, 200, 255),
				Material = Enum.Material.Glass,
				Size = Vector3.new(0.4, 0.6, 0.1),
				Position = position,
				Transparency = 0.3,
			})
			shard.Anchored = false
			shard.AssemblyLinearVelocity = Vector3.new(
				(math.random() - 0.5) * 40,
				math.random() * 20 + 5,
				(math.random() - 0.5) * 40
			)
			shard.AssemblyAngularVelocity = Vector3.new(
				math.random() * 10, math.random() * 10, math.random() * 10
			)

			TweenService:Create(shard, TweenInfo.new(0.6), {
				Transparency = 1,
			}):Play()
			Debris:AddItem(shard, 0.7)
		end
	end

	CombatVFX.showDamageNumber(position, damage, wasBlockBreak)
end

--------------------------------------------------------------------------------
-- DAMAGE NUMBER (floating text)
--------------------------------------------------------------------------------

function CombatVFX.showDamageNumber(position, damage, isCrit)
	local holder = Instance.new("Part")
	holder.Name = "DmgHolder"
	holder.Anchored = true
	holder.CanCollide = false
	holder.Transparency = 1
	holder.Size = Vector3.new(0.1, 0.1, 0.1)
	holder.Position = position + Vector3.new((math.random() - 0.5) * 2, 2, (math.random() - 0.5) * 2)
	holder.Parent = workspace

	local billboard = Instance.new("BillboardGui")
	billboard.Size = isCrit and UDim2.new(4, 0, 2, 0) or UDim2.new(3, 0, 1.5, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 80
	billboard.Adornee = holder
	billboard.Parent = holder

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = tostring(math.floor(damage))
	label.TextColor3 = isCrit and Color3.fromRGB(255, 60, 60) or Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = billboard

	TweenService:Create(holder, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = holder.Position + Vector3.new(0, 4, 0),
	}):Play()

	TweenService:Create(label, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()

	Debris:AddItem(holder, 1.0)
end

--------------------------------------------------------------------------------
-- BLOCK SHIELD (persistent while blocking)
--------------------------------------------------------------------------------

function CombatVFX.createBlockShield(character, color)
	CombatVFX.removeBlockShield(character)

	local root = getRoot(character)
	if not root then return end

	color = color or DEFAULT_COLOR

	local shield = Instance.new("Part")
	shield.Name = "BlockShield"
	shield.Shape = Enum.PartType.Ball
	shield.Size = Vector3.new(9, 9, 9)
	shield.Material = Enum.Material.ForceField
	shield.Color = color
	shield.Transparency = 0.75
	shield.Anchored = false
	shield.CanCollide = false
	shield.Massless = true
	shield.CastShadow = false

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = shield
	weld.Parent = shield

	shield.CFrame = root.CFrame
	shield.Parent = character

	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = 1.5
	light.Range = 12
	light.Parent = shield

	local pulseUp = TweenService:Create(shield,
		TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Transparency = 0.65, Size = Vector3.new(9.5, 9.5, 9.5) }
	)
	pulseUp:Play()

	return shield
end

function CombatVFX.removeBlockShield(character)
	if not character then return end
	local shield = character:FindFirstChild("BlockShield")
	if shield then
		TweenService:Create(shield, TweenInfo.new(0.15), { Transparency = 1 }):Play()
		Debris:AddItem(shield, 0.2)
	end
end

--------------------------------------------------------------------------------
-- DASH EFFECT (afterimage + speed lines)
--------------------------------------------------------------------------------

function CombatVFX.playDash(character, direction, color, dashType)
	local root = getRoot(character)
	if not root then return end

	color = color or DEFAULT_COLOR
	local dashDir = direction and direction.Unit or root.CFrame.LookVector

	local afterimage = effectPart({
		Name = "DashAfterimage",
		Color = color,
		Size = Vector3.new(2.5, 5, 1.5),
		CFrame = root.CFrame,
		Transparency = 0.5,
		Material = Enum.Material.Neon,
	})

	TweenService:Create(afterimage, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Transparency = 1,
		Size = Vector3.new(3, 5.5, 2),
	}):Play()
	Debris:AddItem(afterimage, 0.5)

	local lineCount = dashType == "forward" and 7 or 5
	for i = 1, lineCount do
		local offset = Vector3.new(
			(math.random() - 0.5) * 4,
			(math.random() - 0.5) * 4 + 1,
			0
		)
		local linePos = root.Position + offset

		local line = effectPart({
			Name = "SpeedLine",
			Color = Color3.new(1, 1, 1),
			Size = Vector3.new(0.08, 0.08, 2),
			CFrame = CFrame.lookAt(linePos, linePos + dashDir),
			Transparency = 0.2,
		})

		TweenService:Create(line, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Transparency = 1,
			Size = Vector3.new(0.08, 0.08, 8),
			CFrame = line.CFrame * CFrame.new(0, 0, -3),
		}):Play()
		Debris:AddItem(line, 0.4)
	end

	local dust = effectPart({
		Name = "DashDust",
		Color = Color3.fromRGB(180, 175, 170),
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(2, 1, 2),
		Position = root.Position - Vector3.new(0, 2.5, 0),
		Transparency = 0.5,
		Material = Enum.Material.SmoothPlastic,
	})

	TweenService:Create(dust, TweenInfo.new(0.4, Enum.EasingStyle.Quad), {
		Transparency = 1,
		Size = Vector3.new(6, 2, 6),
	}):Play()
	Debris:AddItem(dust, 0.5)
end

--------------------------------------------------------------------------------
-- GENERIC ABILITY VFX (routes based on move properties from CharacterData)
--------------------------------------------------------------------------------

-- Projectile move: beam/orb traveling forward
local function playProjectileVFX(root, color, moveData)
	local projSize = (moveData.ProjectileWidth or 2)
	local projPos = root.Position + root.CFrame.LookVector * 4

	local proj = effectPart({
		Name = "ProjectileVFX",
		Color = color,
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(projSize, projSize, projSize * 1.5),
		CFrame = CFrame.lookAt(projPos, projPos + root.CFrame.LookVector),
		Transparency = 0.1,
	})

	local projLight = Instance.new("PointLight")
	projLight.Color = color
	projLight.Brightness = 4
	projLight.Range = 20
	projLight.Parent = proj

	local travelDist = math.min(moveData.Range or 20, 35)
	TweenService:Create(proj, TweenInfo.new(moveData.Duration or 0.4, Enum.EasingStyle.Linear), {
		CFrame = proj.CFrame * CFrame.new(0, 0, -travelDist),
		Transparency = 1,
		Size = Vector3.new(projSize * 0.5, projSize * 0.5, projSize * 0.8),
	}):Play()
	Debris:AddItem(proj, (moveData.Duration or 0.4) + 0.2)

	-- Muzzle flash
	local muzzle = effectPart({
		Name = "MuzzleFlash",
		Color = color,
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(3, 3, 3),
		Position = projPos,
		Transparency = 0,
	})

	TweenService:Create(muzzle, TweenInfo.new(0.2), {
		Transparency = 1,
		Size = Vector3.new(5, 5, 5),
	}):Play()
	Debris:AddItem(muzzle, 0.3)
end

-- Grab move: pull-in effect
local function playGrabVFX(root, color, moveData)
	local grabPos = root.Position + root.CFrame.LookVector * 4

	local grab = effectPart({
		Name = "GrabVFX",
		Color = color,
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(8, 8, 8),
		Position = grabPos,
		Transparency = 0.5,
	})

	TweenService:Create(grab, TweenInfo.new(0.3), {
		Transparency = 1,
		Size = Vector3.new(2, 2, 2),
	}):Play()
	Debris:AddItem(grab, 0.4)

	-- Hit flashes during grab duration
	local hitCount = moveData.HitCount or 3
	local duration = moveData.Duration or 0.8
	for i = 1, hitCount do
		task.delay(i * (duration / hitCount), function()
			if not root or not root.Parent then return end
			local hitFlash = effectPart({
				Name = "GrabHit",
				Color = color,
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(2, 2, 2),
				Position = root.Position + root.CFrame.LookVector * 3 + Vector3.new((math.random() - 0.5) * 2, (math.random() - 0.5) * 2, 0),
				Transparency = 0.2,
			})
			TweenService:Create(hitFlash, TweenInfo.new(0.15), { Transparency = 1, Size = Vector3.new(4, 4, 4) }):Play()
			Debris:AddItem(hitFlash, 0.25)
		end)
	end
end

-- Counter move: shield stance
local function playCounterVFX(root, color, moveData)
	local shield = effectPart({
		Name = "CounterShield",
		Color = color,
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(7, 7, 7),
		Position = root.Position,
		Transparency = 0.5,
		Material = Enum.Material.ForceField,
	})

	TweenService:Create(shield, TweenInfo.new(0.2), {
		Transparency = 0.7,
		Size = Vector3.new(8, 8, 8),
	}):Play()

	local counterWindow = moveData.CounterWindow or 1.0
	task.delay(counterWindow, function()
		if shield and shield.Parent then
			TweenService:Create(shield, TweenInfo.new(0.3), { Transparency = 1 }):Play()
			Debris:AddItem(shield, 0.4)
		end
	end)
end

-- Multi-hit move: rapid hit flashes
local function playMultiHitVFX(root, color, moveData)
	local hitCount = moveData.HitCount or 3
	local duration = moveData.Duration or 0.8

	-- Initial burst
	local burst = effectPart({
		Name = "MultiHitBurst",
		Color = color,
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(3, 3, 3),
		Position = root.Position + root.CFrame.LookVector * 3,
		Transparency = 0.2,
	})

	TweenService:Create(burst, TweenInfo.new(0.2), {
		Transparency = 1,
		Size = Vector3.new(6, 6, 6),
	}):Play()
	Debris:AddItem(burst, 0.3)

	-- Rapid hits
	for i = 1, hitCount do
		task.delay(i * (duration / hitCount), function()
			if not root or not root.Parent then return end
			local hitPos = root.Position + root.CFrame.LookVector * (3 + math.random() * 2) + Vector3.new(
				(math.random() - 0.5) * 3, (math.random() - 0.5) * 2, 0
			)
			local hit = effectPart({
				Name = "MultiHit",
				Color = color,
				Size = Vector3.new(1.5, 1.5, 1.5),
				Position = hitPos,
				Transparency = 0.1,
			})
			TweenService:Create(hit, TweenInfo.new(0.12), { Transparency = 1, Size = Vector3.new(3, 3, 3) }):Play()
			Debris:AddItem(hit, 0.2)
		end)
	end
end

-- Standard melee move: punch/slash flash
local function playMeleeVFX(root, color, moveData)
	local flash = effectPart({
		Name = "MeleeFlash",
		Color = color,
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(3, 3, 3),
		CFrame = root.CFrame * CFrame.new(0, 0, -4),
		Transparency = 0.1,
	})

	local flashLight = Instance.new("PointLight")
	flashLight.Color = color
	flashLight.Brightness = 3
	flashLight.Range = 15
	flashLight.Parent = flash

	TweenService:Create(flash, TweenInfo.new(0.2), {
		Transparency = 1,
		Size = Vector3.new(6, 6, 6),
	}):Play()
	Debris:AddItem(flash, 0.3)

	-- Knockback trail if strong knockback
	if moveData.Knockback and moveData.Knockback >= 25 then
		CombatVFX.impactShockwave(root.Position + root.CFrame.LookVector * 4, color, 14)
	end

	-- Ground destruction for block-breaking moves
	if moveData.BreaksBlock then
		CombatVFX.groundDestruction(root.Position + root.CFrame.LookVector * 3, 2.0, color)
	end
end

-- AoE move: radial shockwave
local function playAoEVFX(root, color, moveData)
	local radius = moveData.Radius or 10

	local ring = effectPart({
		Name = "AoERing",
		Color = color,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, 3, 3),
		CFrame = CFrame.new(root.Position) * CFrame.Angles(0, 0, math.rad(90)),
		Transparency = 0.1,
	})

	TweenService:Create(ring, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {
		Size = Vector3.new(0.3, radius * 2, radius * 2),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ring, 0.6)

	CombatVFX.groundDestruction(root.Position, 2.5, color)

	-- Explosion sphere
	local exp = effectPart({
		Name = "AoEExplosion",
		Color = color,
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(4, 4, 4),
		Position = root.Position,
		Transparency = 0.2,
	})

	local expLight = Instance.new("PointLight")
	expLight.Color = color
	expLight.Brightness = 5
	expLight.Range = radius * 2
	expLight.Parent = exp

	TweenService:Create(exp, TweenInfo.new(0.4), {
		Transparency = 1,
		Size = Vector3.new(radius, radius, radius),
	}):Play()
	Debris:AddItem(exp, 0.5)
end

-- Main ability VFX router — uses move properties to pick the right effect
function CombatVFX.playAbility(character, characterKey, slot)
	local root = getRoot(character)
	if not root then return end

	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local CharacterData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CharacterData"))
	local charData = CharacterData.GetCharacter(characterKey)
	if not charData then return end

	local color = charData.Colors and charData.Colors.Primary or DEFAULT_COLOR
	local moveData = charData.Moves and charData.Moves[slot]
	if not moveData then return end

	-- Route to appropriate VFX based on move properties
	if moveData.IsProjectile then
		playProjectileVFX(root, color, moveData)
	elseif moveData.IsGrab then
		playGrabVFX(root, color, moveData)
	elseif moveData.IsCounter then
		playCounterVFX(root, color, moveData)
	elseif moveData.Radius then
		playAoEVFX(root, color, moveData)
	elseif moveData.HitCount and moveData.HitCount > 1 then
		playMultiHitVFX(root, color, moveData)
	else
		playMeleeVFX(root, color, moveData)
	end
end

return CombatVFX
