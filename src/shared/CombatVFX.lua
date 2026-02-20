--[[
	CombatVFX
	TSB-style visual effects: hit-stop freeze frames, directional screen shake,
	ground destruction, impact shockwaves, ragdoll indicators, critical/black
	flash particles, uppercut/downslam effects.
]]

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local CombatVFX = {}

--------------------------------------------------------------------------------
-- ELEMENT COLORS
--------------------------------------------------------------------------------

local ELEMENT_COLORS = {
	Fire      = { Primary = Color3.fromRGB(255, 80, 20),  Secondary = Color3.fromRGB(255, 200, 50) },
	Water     = { Primary = Color3.fromRGB(30, 144, 255), Secondary = Color3.fromRGB(150, 220, 255) },
	Lightning = { Primary = Color3.fromRGB(255, 230, 50), Secondary = Color3.fromRGB(100, 180, 255) },
	Shadow    = { Primary = Color3.fromRGB(100, 50, 160), Secondary = Color3.fromRGB(60, 60, 70) },
}

local DEFAULT_COLORS = { Primary = Color3.fromRGB(255, 255, 255), Secondary = Color3.fromRGB(200, 200, 200) }

local function getColors(element)
	return ELEMENT_COLORS[element] or DEFAULT_COLORS
end

local function getRoot(character)
	if not character then return nil end
	return character:FindFirstChild("HumanoidRootPart")
end

--------------------------------------------------------------------------------
-- HELPER: Create a quick effect part
--------------------------------------------------------------------------------

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
	-- Freeze camera briefly by pausing character animations
	-- This gives that TSB "meaty hit" feel
	local player = Players.LocalPlayer
	if not player then return end
	local char = player.Character
	if not char then return end
	local humanoid = char:FindFirstChild("Humanoid")
	if not humanoid then return end

	-- Brief walkspeed reduction to simulate freeze
	local originalSpeed = humanoid.WalkSpeed
	humanoid.WalkSpeed = 0
	task.delay(duration, function()
		if humanoid and humanoid.Parent then
			humanoid.WalkSpeed = originalSpeed
		end
	end)
end

--------------------------------------------------------------------------------
-- DIRECTIONAL SCREEN SHAKE (camera shakes in attack direction)
--------------------------------------------------------------------------------

function CombatVFX.directionalShake(intensity, duration, direction)
	local camera = workspace.CurrentCamera
	if not camera then return end

	local shakeDir = direction or Vector3.new(1, 0, 0)
	-- Project direction onto camera-relative space
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
		-- Primary shake in attack direction + small random perpendicular noise
		local progress = elapsed / duration
		local wave = math.sin(progress * math.pi * 6) * decay
		local shakeX = localDir.X * wave * intensity + (math.random() - 0.5) * 0.2 * intensity * decay
		local shakeY = localDir.Y * wave * intensity * 0.5 + (math.random() - 0.5) * 0.3 * intensity * decay
		camera.CFrame = camera.CFrame * CFrame.new(shakeX, shakeY, 0)
	end)
end

-- Legacy shake (random, non-directional)
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

function CombatVFX.groundDestruction(position, intensity, element)
	local colors = getColors(element)
	local numCracks = math.floor(intensity * 3) + 4
	local crackLength = intensity * 3 + 2

	-- Radial crack lines
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

		-- Fade out slowly
		task.delay(1.5, function()
			if crack and crack.Parent then
				TweenService:Create(crack, TweenInfo.new(1.0), { Transparency = 1 }):Play()
				Debris:AddItem(crack, 1.2)
			end
		end)
	end

	-- Flying rock debris
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

	-- Dust cloud
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

	local ring = effectPart({
		Name = "ShockwaveRing",
		Color = color or Color3.new(1, 1, 1),
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

function CombatVFX.playM1Swing(character, comboIndex, element)
	local root = getRoot(character)
	if not root then return end

	local colors = getColors(element)

	local swingConfigs = {
		-- Hit 1: right horizontal slash
		{
			offset = CFrame.new(2, 0.5, -3) * CFrame.Angles(0, math.rad(-20), math.rad(-25)),
			size = Vector3.new(0.15, 1.8, 5),
		},
		-- Hit 2: left horizontal slash
		{
			offset = CFrame.new(-2, 0.5, -3) * CFrame.Angles(0, math.rad(20), math.rad(25)),
			size = Vector3.new(0.15, 1.8, 5),
		},
		-- Hit 3: uppercut arc (heavier)
		{
			offset = CFrame.new(0, 2.5, -3) * CFrame.Angles(math.rad(-50), 0, 0),
			size = Vector3.new(4.5, 0.18, 4.5),
		},
		-- Hit 4: heavy downward slam (wider, bigger)
		{
			offset = CFrame.new(0, 0, -4) * CFrame.Angles(math.rad(15), 0, 0),
			size = Vector3.new(6.5, 0.25, 6.5),
		},
	}

	local config = swingConfigs[comboIndex] or swingConfigs[1]
	local trailCF = root.CFrame * config.offset

	-- Main swing trail
	local trail = effectPart({
		Name = "SwingTrail",
		Color = colors.Primary,
		Size = config.size,
		CFrame = trailCF,
		Transparency = 0.15,
	})

	TweenService:Create(trail, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Transparency = 1,
		Size = config.size * 1.5,
	}):Play()
	Debris:AddItem(trail, 0.3)

	-- Secondary glow trail
	local glow = effectPart({
		Name = "SwingGlow",
		Color = colors.Secondary,
		Size = config.size * 0.7,
		CFrame = trailCF * CFrame.new(0, 0, -0.3),
		Transparency = 0.45,
	})

	TweenService:Create(glow, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Transparency = 1,
		Size = config.size * 1.2,
	}):Play()
	Debris:AddItem(glow, 0.35)

	-- Heavy hit (4th) gets a shockwave ring + ground destruction
	if comboIndex >= 4 then
		CombatVFX.impactShockwave(root.Position + root.CFrame.LookVector * 4, colors.Secondary, 16)
		CombatVFX.groundDestruction(root.Position + root.CFrame.LookVector * 3, 2.0, element)
	end
end

--------------------------------------------------------------------------------
-- UPPERCUT VFX
--------------------------------------------------------------------------------

function CombatVFX.playUppercut(character, element)
	local root = getRoot(character)
	if not root then return end
	local colors = getColors(element)

	-- Upward arc trail
	local arc = effectPart({
		Name = "UppercutArc",
		Color = colors.Primary,
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

	-- Ground burst
	CombatVFX.impactShockwave(root.Position, colors.Secondary, 12)

	-- Rising speed lines
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

function CombatVFX.playDownslam(character, element)
	local root = getRoot(character)
	if not root then return end
	local colors = getColors(element)

	-- Downward slam trail
	local slam = effectPart({
		Name = "DownslamTrail",
		Color = colors.Primary,
		Size = Vector3.new(5, 0.25, 5),
		CFrame = root.CFrame * CFrame.new(0, -1, -3) * CFrame.Angles(math.rad(60), 0, 0),
		Transparency = 0.1,
	})

	TweenService:Create(slam, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
		Transparency = 1,
		Size = Vector3.new(8, 0.25, 8),
	}):Play()
	Debris:AddItem(slam, 0.3)

	-- Heavy ground impact (delayed slightly for when victim hits ground)
	task.delay(0.15, function()
		local impactPos = root.Position + root.CFrame.LookVector * 3 + Vector3.new(0, -2, 0)
		CombatVFX.impactShockwave(impactPos, colors.Secondary, 20)
		CombatVFX.groundDestruction(impactPos, 3.0, element)
	end)
end

--------------------------------------------------------------------------------
-- FORWARD DASH ATTACK VFX
--------------------------------------------------------------------------------

function CombatVFX.playForwardDashAttack(character, element)
	local root = getRoot(character)
	if not root then return end
	local colors = getColors(element)

	-- Quick punch flash
	local flash = effectPart({
		Name = "DashAttackFlash",
		Color = colors.Primary,
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

function CombatVFX.playPerfectBlock(character, element)
	local root = getRoot(character)
	if not root then return end

	-- Bright white flash
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

	-- Subtle ring
	CombatVFX.impactShockwave(root.Position, Color3.fromRGB(200, 220, 255), 10)
end

--------------------------------------------------------------------------------
-- CRITICAL HIT VFX
--------------------------------------------------------------------------------

function CombatVFX.playCriticalHit(position)
	-- White-yellow flash
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

	-- Crack lines radiating from point
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
	-- Dark sphere with red/black particles
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

	-- Red/black particles
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

	-- Intense light flash
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

	-- Shockwave
	CombatVFX.impactShockwave(position, Color3.fromRGB(180, 20, 20), 22)
end

--------------------------------------------------------------------------------
-- RAGDOLL INDICATOR (subtle visual when ragdolled)
--------------------------------------------------------------------------------

function CombatVFX.playRagdollStart(character)
	local root = getRoot(character)
	if not root then return end

	-- Brief flash at impact
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

	-- Quick recovery burst
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
-- HIT IMPACT (plays at victim's position on hit confirmation)
--------------------------------------------------------------------------------

function CombatVFX.playHitImpact(position, damage, element, wasBlockBreak, isCritical, isBlackFlash)
	local colors = getColors(element)

	-- Black Flash gets its own special VFX
	if isBlackFlash then
		CombatVFX.playBlackFlash(position)
		CombatVFX.showDamageNumber(position, damage, true)
		return
	end

	-- Critical Hit gets its own VFX
	if isCritical then
		CombatVFX.playCriticalHit(position)
		CombatVFX.showDamageNumber(position, damage, true)
		return
	end

	local impactColor = wasBlockBreak and Color3.fromRGB(255, 50, 50) or colors.Primary

	-- Impact flash sphere
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

	-- Debris particles
	local debrisCount = wasBlockBreak and 10 or 6
	for i = 1, debrisCount do
		local d = effectPart({
			Name = "HitDebris",
			Color = i % 2 == 0 and colors.Primary or colors.Secondary,
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

	-- Block break shatter
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

	-- Damage number
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

function CombatVFX.createBlockShield(character, element)
	CombatVFX.removeBlockShield(character)

	local root = getRoot(character)
	if not root then return end

	local colors = getColors(element)

	local shield = Instance.new("Part")
	shield.Name = "BlockShield"
	shield.Shape = Enum.PartType.Ball
	shield.Size = Vector3.new(9, 9, 9)
	shield.Material = Enum.Material.ForceField
	shield.Color = colors.Primary
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
	light.Color = colors.Primary
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

function CombatVFX.playDash(character, direction, element, dashType)
	local root = getRoot(character)
	if not root then return end

	local colors = getColors(element)
	local dashDir = direction and direction.Unit or root.CFrame.LookVector

	-- Afterimage at start position
	local afterimage = effectPart({
		Name = "DashAfterimage",
		Color = colors.Primary,
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

	-- Speed lines
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

	-- Ground dust puff
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
-- ABILITY VFX (element-specific effects per ninja)
-- Preserved from original — each element has Q/E/R/F VFX
--------------------------------------------------------------------------------

-- Fire Ninja: FlameShadow
local fireAbilityVFX = {
	Q = function(root, colors)
		for i = 1, 10 do
			task.delay(i * 0.025, function()
				if not root or not root.Parent then return end
				local flame = effectPart({
					Name = "FireDashFlame",
					Color = i % 2 == 0 and colors.Primary or colors.Secondary,
					Shape = Enum.PartType.Ball,
					Size = Vector3.new(1.8, 1.8, 1.8),
					Position = root.Position + Vector3.new(
						(math.random() - 0.5) * 2, (math.random() - 0.5) * 2, (math.random() - 0.5) * 2
					),
				})
				TweenService:Create(flame, TweenInfo.new(0.4), {
					Transparency = 1, Size = Vector3.new(0.3, 0.3, 0.3), Position = flame.Position + Vector3.new(0, 2, 0),
				}):Play()
				Debris:AddItem(flame, 0.5)
			end)
		end
	end,
	E = function(root, colors)
		local arc = effectPart({
			Name = "FlameSlashArc", Color = colors.Primary,
			Size = Vector3.new(8, 0.3, 8),
			CFrame = root.CFrame * CFrame.new(0, 0, -5) * CFrame.Angles(math.rad(10), 0, 0),
		})
		TweenService:Create(arc, TweenInfo.new(0.4, Enum.EasingStyle.Quad), { Transparency = 1, Size = Vector3.new(12, 0.3, 12) }):Play()
		Debris:AddItem(arc, 0.5)
		for i = 1, 8 do
			local ember = effectPart({
				Name = "Ember", Color = colors.Secondary, Size = Vector3.new(0.3, 0.3, 0.3),
				Position = root.Position + root.CFrame.LookVector * 5 + Vector3.new((math.random() - 0.5) * 6, math.random() * 3, (math.random() - 0.5) * 6),
			})
			ember.Anchored = false
			ember.AssemblyLinearVelocity = Vector3.new((math.random() - 0.5) * 10, math.random() * 12 + 5, (math.random() - 0.5) * 10)
			TweenService:Create(ember, TweenInfo.new(0.6), { Transparency = 1 }):Play()
			Debris:AddItem(ember, 0.7)
		end
	end,
	R = function(root, colors)
		local bombPos = root.Position + root.CFrame.LookVector * 12
		local bomb = effectPart({ Name = "InfernoBomb", Color = colors.Primary, Shape = Enum.PartType.Ball, Size = Vector3.new(2, 2, 2), Position = bombPos + Vector3.new(0, 3, 0) })
		local bombLight = Instance.new("PointLight"); bombLight.Color = colors.Primary; bombLight.Brightness = 3; bombLight.Range = 15; bombLight.Parent = bomb
		TweenService:Create(bomb, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = bombPos, Size = Vector3.new(3, 3, 3) }):Play()
		task.delay(0.6, function()
			if bomb and bomb.Parent then bomb:Destroy() end
			local explosion = effectPart({ Name = "InfernoExplosion", Color = colors.Secondary, Shape = Enum.PartType.Ball, Size = Vector3.new(3, 3, 3), Position = bombPos, Transparency = 0.2 })
			local expLight = Instance.new("PointLight"); expLight.Color = colors.Primary; expLight.Brightness = 5; expLight.Range = 30; expLight.Parent = explosion
			TweenService:Create(explosion, TweenInfo.new(0.5), { Transparency = 1, Size = Vector3.new(16, 16, 16) }):Play()
			Debris:AddItem(explosion, 0.6)
			CombatVFX.groundDestruction(bombPos, 2.5, "Fire")
			for i = 1, 12 do
				local d = effectPart({ Name = "ExplosionDebris", Color = i % 2 == 0 and colors.Primary or colors.Secondary, Size = Vector3.new(0.5, 0.5, 0.5), Position = bombPos })
				d.Anchored = false; d.AssemblyLinearVelocity = Vector3.new((math.random() - 0.5) * 40, math.random() * 25 + 10, (math.random() - 0.5) * 40)
				TweenService:Create(d, TweenInfo.new(0.6), { Transparency = 1, Size = Vector3.new(0.1, 0.1, 0.1) }):Play()
				Debris:AddItem(d, 0.7)
			end
		end)
	end,
	F = function(root, colors)
		local pillar = effectPart({ Name = "CyclonePillar", Color = colors.Primary, Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 8, 8), CFrame = CFrame.new(root.Position), Transparency = 0.3 })
		TweenService:Create(pillar, TweenInfo.new(0.8, Enum.EasingStyle.Quad), { Size = Vector3.new(20, 20, 20), Transparency = 1 }):Play()
		Debris:AddItem(pillar, 1.0)
		local ring = effectPart({ Name = "CycloneRing", Color = colors.Secondary, Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 5, 5), CFrame = CFrame.new(root.Position) * CFrame.Angles(0, 0, math.rad(90)), Transparency = 0.2 })
		TweenService:Create(ring, TweenInfo.new(0.6, Enum.EasingStyle.Quad), { Size = Vector3.new(0.3, 18, 18), Transparency = 1 }):Play()
		Debris:AddItem(ring, 0.7)
		CombatVFX.groundDestruction(root.Position, 3.0, "Fire")
		for i = 1, 12 do
			task.delay(i * 0.05, function()
				local angle = math.rad(i * 30); local dist = 3 + i * 0.5
				local flamePos = root.Position + Vector3.new(math.cos(angle) * dist, i * 0.4, math.sin(angle) * dist)
				local flame = effectPart({ Name = "SpiralFlame", Color = i % 3 == 0 and colors.Secondary or colors.Primary, Shape = Enum.PartType.Ball, Size = Vector3.new(1.5, 1.5, 1.5), Position = flamePos })
				TweenService:Create(flame, TweenInfo.new(0.4), { Transparency = 1, Size = Vector3.new(0.3, 0.3, 0.3) }):Play()
				Debris:AddItem(flame, 0.5)
			end)
		end
	end,
}

-- Water Ninja: MistBlade
local waterAbilityVFX = {
	Q = function(root, colors)
		local splash = effectPart({ Name = "WaterSplash", Color = colors.Primary, Shape = Enum.PartType.Ball, Size = Vector3.new(3, 3, 3), Position = root.Position, Transparency = 0.3 })
		TweenService:Create(splash, TweenInfo.new(0.3), { Transparency = 1, Size = Vector3.new(8, 2, 8) }):Play()
		Debris:AddItem(splash, 0.4)
		for i = 1, 6 do
			local drop = effectPart({ Name = "WaterDrop", Color = colors.Secondary, Shape = Enum.PartType.Ball, Size = Vector3.new(0.3, 0.3, 0.3), Position = root.Position })
			drop.Anchored = false; drop.AssemblyLinearVelocity = Vector3.new((math.random() - 0.5) * 20, math.random() * 15 + 8, (math.random() - 0.5) * 20)
			TweenService:Create(drop, TweenInfo.new(0.5), { Transparency = 1 }):Play()
			Debris:AddItem(drop, 0.6)
		end
	end,
	E = function(root, colors)
		local waveDir = root.CFrame.LookVector; local waveStart = root.Position + waveDir * 3
		local wave = effectPart({ Name = "TidalWave", Color = colors.Primary, Size = Vector3.new(6, 3, 0.5), CFrame = CFrame.lookAt(waveStart, waveStart + waveDir), Transparency = 0.2 })
		TweenService:Create(wave, TweenInfo.new(0.4, Enum.EasingStyle.Linear), { CFrame = wave.CFrame * CFrame.new(0, 0, -20), Transparency = 1, Size = Vector3.new(8, 4, 0.5) }):Play()
		Debris:AddItem(wave, 0.5)
		for i = 1, 5 do
			task.delay(i * 0.06, function()
				local mist = effectPart({ Name = "WaveMist", Color = colors.Secondary, Shape = Enum.PartType.Ball, Size = Vector3.new(1.5, 1.5, 1.5), Position = waveStart + waveDir * (i * 4), Transparency = 0.4 })
				TweenService:Create(mist, TweenInfo.new(0.3), { Transparency = 1, Size = Vector3.new(3, 3, 3) }):Play()
				Debris:AddItem(mist, 0.4)
			end)
		end
	end,
	R = function(root, colors)
		for i = 1, 10 do
			task.delay(i * 0.08, function()
				if not root or not root.Parent then return end
				local angle = math.rad(i * 36)
				local mistPos = root.Position + Vector3.new(math.cos(angle) * 4, math.random() * 3, math.sin(angle) * 4)
				local mist = effectPart({ Name = "MistVeil", Color = colors.Secondary, Shape = Enum.PartType.Ball, Size = Vector3.new(2, 2, 2), Position = mistPos, Transparency = 0.5, Material = Enum.Material.SmoothPlastic })
				TweenService:Create(mist, TweenInfo.new(0.6), { Transparency = 1, Size = Vector3.new(4, 4, 4), Position = mistPos + Vector3.new(0, 2, 0) }):Play()
				Debris:AddItem(mist, 0.7)
			end)
		end
	end,
	F = function(root, colors)
		local surge = effectPart({ Name = "RagingSurge", Color = colors.Primary, Size = Vector3.new(4, 4, 20), CFrame = root.CFrame * CFrame.new(0, 0, -12), Transparency = 0.3 })
		TweenService:Create(surge, TweenInfo.new(0.6), { Transparency = 1, Size = Vector3.new(6, 6, 25) }):Play()
		Debris:AddItem(surge, 0.7)
		CombatVFX.impactShockwave(root.Position, colors.Secondary, 14)
	end,
}

-- Lightning Ninja: StormFist
local lightningAbilityVFX = {
	Q = function(root, colors)
		local flash = effectPart({ Name = "ThunderFlash", Color = colors.Primary, Shape = Enum.PartType.Ball, Size = Vector3.new(3, 3, 3), CFrame = root.CFrame * CFrame.new(0, 0, -4), Transparency = 0 })
		TweenService:Create(flash, TweenInfo.new(0.15), { Transparency = 1, Size = Vector3.new(6, 6, 6) }):Play()
		Debris:AddItem(flash, 0.2)
		for i = 1, 4 do
			local spark = effectPart({ Name = "Spark", Color = colors.Secondary, Size = Vector3.new(0.1, 0.1, math.random() * 2 + 1), Position = root.Position + Vector3.new((math.random() - 0.5) * 4, (math.random() - 0.5) * 3 + 1, (math.random() - 0.5) * 4 - 3), Transparency = 0 })
			TweenService:Create(spark, TweenInfo.new(0.12), { Transparency = 1 }):Play()
			Debris:AddItem(spark, 0.15)
		end
	end,
	E = function(root, colors)
		local strikePos = root.Position + root.CFrame.LookVector * 10
		local warning = effectPart({ Name = "StrikeWarning", Color = colors.Primary, Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, 6, 6), Position = strikePos - Vector3.new(0, 2, 0), Transparency = 0.5 })
		Debris:AddItem(warning, 1.0)
		task.delay(0.3, function()
			if warning and warning.Parent then warning:Destroy() end
			local bolt = effectPart({ Name = "LightningBolt", Color = colors.Primary, Size = Vector3.new(1.5, 50, 1.5), Position = strikePos + Vector3.new(0, 25, 0), Transparency = 0 })
			local boltLight = Instance.new("PointLight"); boltLight.Color = colors.Primary; boltLight.Brightness = 8; boltLight.Range = 40; boltLight.Parent = bolt
			TweenService:Create(bolt, TweenInfo.new(0.3), { Transparency = 1, Size = Vector3.new(3, 50, 3) }):Play()
			Debris:AddItem(bolt, 0.4)
			CombatVFX.impactShockwave(strikePos, colors.Secondary, 14)
			CombatVFX.groundDestruction(strikePos, 2.0, "Lightning")
		end)
	end,
	R = function(root, colors)
		local fieldPos = root.Position
		local field = effectPart({ Name = "StaticField", Color = colors.Primary, Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 8, 8), Position = fieldPos - Vector3.new(0, 2, 0), Transparency = 0.4 })
		TweenService:Create(field, TweenInfo.new(2.5), { Transparency = 1, Size = Vector3.new(0.2, 14, 14) }):Play()
		Debris:AddItem(field, 3.0)
		for i = 1, 8 do
			task.delay(i * 0.3, function()
				local sparkPos = fieldPos + Vector3.new((math.random() - 0.5) * 10, -1, (math.random() - 0.5) * 10)
				local spark = effectPart({ Name = "FieldSpark", Color = colors.Secondary, Size = Vector3.new(0.1, math.random() * 3 + 1, 0.1), Position = sparkPos })
				TweenService:Create(spark, TweenInfo.new(0.1), { Transparency = 1 }):Play()
				Debris:AddItem(spark, 0.15)
			end)
		end
	end,
	F = function(root, colors)
		local slamRing = effectPart({ Name = "StormSlamRing", Color = colors.Primary, Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 3, 3), CFrame = CFrame.new(root.Position) * CFrame.Angles(0, 0, math.rad(90)), Transparency = 0 })
		TweenService:Create(slamRing, TweenInfo.new(0.6, Enum.EasingStyle.Quad), { Size = Vector3.new(0.3, 28, 28), Transparency = 1 }):Play()
		Debris:AddItem(slamRing, 0.7)
		CombatVFX.groundDestruction(root.Position, 3.5, "Lightning")
		for i = 1, 6 do
			task.delay(i * 0.08, function()
				local angle = math.rad(i * 60); local dist = math.random(3, 8)
				local boltPos = root.Position + Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
				local bolt = effectPart({ Name = "StormBolt", Color = colors.Primary, Size = Vector3.new(0.8, 30, 0.8), Position = boltPos + Vector3.new(0, 15, 0) })
				TweenService:Create(bolt, TweenInfo.new(0.2), { Transparency = 1 }):Play()
				Debris:AddItem(bolt, 0.3)
			end)
		end
		local exp = effectPart({ Name = "StormExplosion", Color = colors.Secondary, Shape = Enum.PartType.Ball, Size = Vector3.new(4, 4, 4), Position = root.Position, Transparency = 0.1 })
		local expLight = Instance.new("PointLight"); expLight.Color = colors.Primary; expLight.Brightness = 8; expLight.Range = 50; expLight.Parent = exp
		TweenService:Create(exp, TweenInfo.new(0.5), { Transparency = 1, Size = Vector3.new(20, 20, 20) }):Play()
		Debris:AddItem(exp, 0.6)
	end,
}

-- Shadow Ninja: ShadowFang
local shadowAbilityVFX = {
	Q = function(root, colors)
		for i = 1, 6 do
			local smoke = effectPart({ Name = "ShadowSmoke", Color = colors.Secondary, Shape = Enum.PartType.Ball, Size = Vector3.new(1.5, 1.5, 1.5), Position = root.Position + Vector3.new((math.random() - 0.5) * 3, (math.random() - 0.5) * 3 + 1, (math.random() - 0.5) * 3), Transparency = 0.3, Material = Enum.Material.SmoothPlastic })
			TweenService:Create(smoke, TweenInfo.new(0.4), { Transparency = 1, Size = Vector3.new(3, 3, 3), Position = smoke.Position + Vector3.new(0, 2, 0) }):Play()
			Debris:AddItem(smoke, 0.5)
		end
		local flash = effectPart({ Name = "ShadowFlash", Color = colors.Primary, Shape = Enum.PartType.Ball, Size = Vector3.new(4, 4, 4), Position = root.Position, Transparency = 0.3 })
		TweenService:Create(flash, TweenInfo.new(0.2), { Transparency = 1, Size = Vector3.new(7, 7, 7) }):Play()
		Debris:AddItem(flash, 0.3)
	end,
	E = function(root, colors)
		local spawnDir = root.CFrame.LookVector
		for i = 1, 5 do
			task.delay(i * 0.08, function()
				local spikePos = root.Position + spawnDir * (3 + i * 3) - Vector3.new(0, 1, 0)
				local spike = effectPart({ Name = "DarkSpike", Color = colors.Primary, Size = Vector3.new(1, 0.5, 1), Position = spikePos, Transparency = 0 })
				TweenService:Create(spike, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(1.2, 6, 1.2), Position = spikePos + Vector3.new(0, 3, 0) }):Play()
				task.delay(0.3, function()
					if spike and spike.Parent then
						TweenService:Create(spike, TweenInfo.new(0.3), { Transparency = 1, Size = Vector3.new(0.5, 8, 0.5) }):Play()
						Debris:AddItem(spike, 0.4)
					end
				end)
			end)
		end
	end,
	R = function(root, colors)
		local counterShield = effectPart({ Name = "CounterShield", Color = colors.Primary, Shape = Enum.PartType.Ball, Size = Vector3.new(7, 7, 7), Position = root.Position, Transparency = 0.5, Material = Enum.Material.ForceField })
		TweenService:Create(counterShield, TweenInfo.new(0.2), { Transparency = 0.7, Size = Vector3.new(8, 8, 8) }):Play()
		task.delay(1.0, function()
			if counterShield and counterShield.Parent then
				TweenService:Create(counterShield, TweenInfo.new(0.3), { Transparency = 1 }):Play()
				Debris:AddItem(counterShield, 0.4)
			end
		end)
	end,
	F = function(root, colors)
		local slashWave = effectPart({ Name = "NightfallSlash", Color = colors.Primary, Size = Vector3.new(8, 6, 0.5), CFrame = root.CFrame * CFrame.new(0, 0, -5), Transparency = 0.1 })
		TweenService:Create(slashWave, TweenInfo.new(0.4, Enum.EasingStyle.Quad), { CFrame = slashWave.CFrame * CFrame.new(0, 0, -15), Transparency = 1, Size = Vector3.new(12, 8, 0.5) }):Play()
		Debris:AddItem(slashWave, 0.5)
		local darkness = effectPart({ Name = "NightfallDarkness", Color = Color3.new(0, 0, 0), Shape = Enum.PartType.Ball, Size = Vector3.new(20, 20, 20), Position = root.Position, Transparency = 0.7, Material = Enum.Material.SmoothPlastic })
		TweenService:Create(darkness, TweenInfo.new(0.8), { Transparency = 1, Size = Vector3.new(30, 30, 30) }):Play()
		Debris:AddItem(darkness, 1.0)
		for i = 1, 3 do
			task.delay(i * 0.1, function()
				local slash = effectPart({ Name = "NightSlash", Color = colors.Primary, Size = Vector3.new(0.2, 4 + i, 6 + i * 2), CFrame = root.CFrame * CFrame.new((math.random() - 0.5) * 4, (math.random() - 0.5) * 2, -6 - i * 3) * CFrame.Angles(0, 0, math.rad(30 * i - 60)) })
				TweenService:Create(slash, TweenInfo.new(0.25), { Transparency = 1 }):Play()
				Debris:AddItem(slash, 0.35)
			end)
		end
	end,
}

-- Lookup table
local ABILITY_VFX_MAP = {
	FlameShadow = fireAbilityVFX,
	MistBlade   = waterAbilityVFX,
	StormFist   = lightningAbilityVFX,
	ShadowFang  = shadowAbilityVFX,
}

function CombatVFX.playAbility(character, ninjaKey, slot)
	local root = getRoot(character)
	if not root then return end

	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local NinjaData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("NinjaData"))
	local ninja = NinjaData.GetNinja(ninjaKey)
	if not ninja then return end

	local colors = getColors(ninja.Element)
	local vfxTable = ABILITY_VFX_MAP[ninjaKey]
	if vfxTable and vfxTable[slot] then
		vfxTable[slot](root, colors)
	end
end

return CombatVFX
