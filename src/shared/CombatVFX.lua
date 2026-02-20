--[[
	CombatVFX
	Visual effects for all combat actions: M1 swings, abilities, dash, block,
	hit impacts, damage numbers, camera shake. Called from client scripts.

	Uses Part-based effects, TweenService, and ParticleEmitters for
	clear visual feedback on every action.
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
-- M1 SWING TRAIL
-- Each combo hit gets a unique swing arc direction.
--------------------------------------------------------------------------------

function CombatVFX.playM1Swing(character, comboIndex, element)
	local root = getRoot(character)
	if not root then return end

	local colors = getColors(element)

	-- Swing arc configurations per combo hit:
	-- { CFrame offset from root, size, rotation for arc feel }
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
		-- Hit 3: uppercut arc
		{
			offset = CFrame.new(0, 2.5, -3) * CFrame.Angles(math.rad(-50), 0, 0),
			size = Vector3.new(4, 0.15, 4),
		},
		-- Hit 4: heavy downward slam (wider, bigger)
		{
			offset = CFrame.new(0, 0, -4) * CFrame.Angles(math.rad(15), 0, 0),
			size = Vector3.new(6, 0.2, 6),
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
		Transparency = 0.2,
	})

	TweenService:Create(trail, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Transparency = 1,
		Size = config.size * 1.4,
	}):Play()
	Debris:AddItem(trail, 0.3)

	-- Secondary glow trail (slightly offset, secondary color)
	local glow = effectPart({
		Name = "SwingGlow",
		Color = colors.Secondary,
		Size = config.size * 0.7,
		CFrame = trailCF * CFrame.new(0, 0, -0.3),
		Transparency = 0.5,
	})

	TweenService:Create(glow, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Transparency = 1,
		Size = config.size * 1.1,
	}):Play()
	Debris:AddItem(glow, 0.35)

	-- Heavy hit (4th) gets a shockwave ring
	if comboIndex >= 4 then
		local ring = effectPart({
			Name = "HeavyRing",
			Color = colors.Secondary,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.2, 4, 4),
			CFrame = root.CFrame * CFrame.new(0, 0, -4) * CFrame.Angles(0, 0, math.rad(90)),
			Transparency = 0.3,
		})

		TweenService:Create(ring, TweenInfo.new(0.35, Enum.EasingStyle.Quad), {
			Transparency = 1,
			Size = Vector3.new(0.2, 14, 14),
		}):Play()
		Debris:AddItem(ring, 0.45)

		-- Ground crack lines (radial)
		for i = 1, 6 do
			local angle = math.rad(i * 60 + math.random(-15, 15))
			local crackDir = Vector3.new(math.cos(angle), 0, math.sin(angle))
			local crackPos = root.Position + Vector3.new(0, -2, 0) + crackDir * 2

			local crack = effectPart({
				Name = "GroundCrack",
				Color = colors.Primary,
				Size = Vector3.new(0.3, 0.1, 2),
				CFrame = CFrame.lookAt(crackPos, crackPos + crackDir) * CFrame.new(0, 0, -1),
				Transparency = 0.3,
			})

			TweenService:Create(crack, TweenInfo.new(0.4, Enum.EasingStyle.Quad), {
				Transparency = 1,
				Size = Vector3.new(0.3, 0.1, 5),
				CFrame = crack.CFrame * CFrame.new(0, 0, -2),
			}):Play()
			Debris:AddItem(crack, 0.5)
		end
	end
end

--------------------------------------------------------------------------------
-- HIT IMPACT (plays at the victim's position on hit confirmation)
--------------------------------------------------------------------------------

function CombatVFX.playHitImpact(position, damage, element, wasBlockBreak)
	local colors = getColors(element)
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

	-- Debris particles (small parts flying outward)
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

	-- Block break gets extra shatter effect
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
	billboard.Size = UDim2.new(3, 0, 1.5, 0)
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

	-- Float up and fade
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
	CombatVFX.removeBlockShield(character) -- remove existing first

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

	-- Pulsing glow
	local light = Instance.new("PointLight")
	light.Color = colors.Primary
	light.Brightness = 1.5
	light.Range = 12
	light.Parent = shield

	-- Subtle pulse tween (loops)
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
		-- Quick fade out
		TweenService:Create(shield, TweenInfo.new(0.15), { Transparency = 1 }):Play()
		Debris:AddItem(shield, 0.2)
	end
end

--------------------------------------------------------------------------------
-- DASH EFFECT (afterimage + speed lines)
--------------------------------------------------------------------------------

function CombatVFX.playDash(character, direction, element)
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

	-- Speed lines (thin streaks behind the character)
	for i = 1, 5 do
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
-- CAMERA SHAKE (for the local player on hit)
--------------------------------------------------------------------------------

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
-- ABILITY VFX (element-specific effects per ninja)
--------------------------------------------------------------------------------

-- Fire Ninja: FlameShadow
local fireAbilityVFX = {
	Q = function(root, colors) -- Fire Dash: flame trail
		for i = 1, 10 do
			task.delay(i * 0.025, function()
				if not root or not root.Parent then return end
				local flame = effectPart({
					Name = "FireDashFlame",
					Color = i % 2 == 0 and colors.Primary or colors.Secondary,
					Shape = Enum.PartType.Ball,
					Size = Vector3.new(1.8, 1.8, 1.8),
					Position = root.Position + Vector3.new(
						(math.random() - 0.5) * 2,
						(math.random() - 0.5) * 2,
						(math.random() - 0.5) * 2
					),
				})

				TweenService:Create(flame, TweenInfo.new(0.4), {
					Transparency = 1,
					Size = Vector3.new(0.3, 0.3, 0.3),
					Position = flame.Position + Vector3.new(0, 2, 0),
				}):Play()
				Debris:AddItem(flame, 0.5)
			end)
		end
	end,

	E = function(root, colors) -- Flame Slash: large fire arc
		local arc = effectPart({
			Name = "FlameSlashArc",
			Color = colors.Primary,
			Size = Vector3.new(8, 0.3, 8),
			CFrame = root.CFrame * CFrame.new(0, 0, -5) * CFrame.Angles(math.rad(10), 0, 0),
		})

		TweenService:Create(arc, TweenInfo.new(0.4, Enum.EasingStyle.Quad), {
			Transparency = 1,
			Size = Vector3.new(12, 0.3, 12),
		}):Play()
		Debris:AddItem(arc, 0.5)

		-- Fire embers
		for i = 1, 8 do
			local ember = effectPart({
				Name = "Ember",
				Color = colors.Secondary,
				Size = Vector3.new(0.3, 0.3, 0.3),
				Position = root.Position + root.CFrame.LookVector * 5 + Vector3.new(
					(math.random() - 0.5) * 6, math.random() * 3, (math.random() - 0.5) * 6
				),
			})
			ember.Anchored = false
			ember.AssemblyLinearVelocity = Vector3.new(
				(math.random() - 0.5) * 10, math.random() * 12 + 5, (math.random() - 0.5) * 10
			)
			TweenService:Create(ember, TweenInfo.new(0.6), { Transparency = 1 }):Play()
			Debris:AddItem(ember, 0.7)
		end
	end,

	R = function(root, colors) -- Inferno Trap: fire ball appears, then explodes
		local bombPos = root.Position + root.CFrame.LookVector * 12

		-- Fire ball
		local bomb = effectPart({
			Name = "InfernoBomb",
			Color = colors.Primary,
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(2, 2, 2),
			Position = bombPos + Vector3.new(0, 3, 0),
		})

		local bombLight = Instance.new("PointLight")
		bombLight.Color = colors.Primary
		bombLight.Brightness = 3
		bombLight.Range = 15
		bombLight.Parent = bomb

		-- Arc down to target
		TweenService:Create(bomb, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = bombPos,
			Size = Vector3.new(3, 3, 3),
		}):Play()

		-- Explode after delay
		task.delay(0.6, function()
			if bomb and bomb.Parent then bomb:Destroy() end

			-- Explosion sphere
			local explosion = effectPart({
				Name = "InfernoExplosion",
				Color = colors.Secondary,
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(3, 3, 3),
				Position = bombPos,
				Transparency = 0.2,
			})

			local expLight = Instance.new("PointLight")
			expLight.Color = colors.Primary
			expLight.Brightness = 5
			expLight.Range = 30
			expLight.Parent = explosion

			TweenService:Create(explosion, TweenInfo.new(0.5), {
				Transparency = 1,
				Size = Vector3.new(16, 16, 16),
			}):Play()
			Debris:AddItem(explosion, 0.6)

			-- Fire debris
			for i = 1, 12 do
				local d = effectPart({
					Name = "ExplosionDebris",
					Color = i % 2 == 0 and colors.Primary or colors.Secondary,
					Size = Vector3.new(0.5, 0.5, 0.5),
					Position = bombPos,
				})
				d.Anchored = false
				d.AssemblyLinearVelocity = Vector3.new(
					(math.random() - 0.5) * 40, math.random() * 25 + 10, (math.random() - 0.5) * 40
				)
				TweenService:Create(d, TweenInfo.new(0.6), { Transparency = 1, Size = Vector3.new(0.1, 0.1, 0.1) }):Play()
				Debris:AddItem(d, 0.7)
			end
		end)
	end,

	F = function(root, colors) -- Crimson Cyclone: spinning fire ring
		-- Rising fire pillar
		local pillar = effectPart({
			Name = "CyclonePillar",
			Color = colors.Primary,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.5, 8, 8),
			CFrame = CFrame.new(root.Position) * CFrame.Angles(0, 0, 0),
			Transparency = 0.3,
		})

		TweenService:Create(pillar, TweenInfo.new(0.8, Enum.EasingStyle.Quad), {
			Size = Vector3.new(20, 20, 20),
			Transparency = 1,
		}):Play()
		Debris:AddItem(pillar, 1.0)

		-- Expanding ring
		local ring = effectPart({
			Name = "CycloneRing",
			Color = colors.Secondary,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.3, 5, 5),
			CFrame = CFrame.new(root.Position) * CFrame.Angles(0, 0, math.rad(90)),
			Transparency = 0.2,
		})

		TweenService:Create(ring, TweenInfo.new(0.6, Enum.EasingStyle.Quad), {
			Size = Vector3.new(0.3, 18, 18),
			Transparency = 1,
		}):Play()
		Debris:AddItem(ring, 0.7)

		-- Spiral flames
		for i = 1, 12 do
			task.delay(i * 0.05, function()
				local angle = math.rad(i * 30)
				local dist = 3 + i * 0.5
				local flamePos = root.Position + Vector3.new(
					math.cos(angle) * dist, i * 0.4, math.sin(angle) * dist
				)
				local flame = effectPart({
					Name = "SpiralFlame",
					Color = i % 3 == 0 and colors.Secondary or colors.Primary,
					Shape = Enum.PartType.Ball,
					Size = Vector3.new(1.5, 1.5, 1.5),
					Position = flamePos,
				})
				TweenService:Create(flame, TweenInfo.new(0.4), {
					Transparency = 1,
					Size = Vector3.new(0.3, 0.3, 0.3),
				}):Play()
				Debris:AddItem(flame, 0.5)
			end)
		end
	end,
}

-- Water Ninja: MistBlade
local waterAbilityVFX = {
	Q = function(root, colors) -- Water Step: splash at start + end
		-- Splash at current position
		local splash = effectPart({
			Name = "WaterSplash",
			Color = colors.Primary,
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(3, 3, 3),
			Position = root.Position,
			Transparency = 0.3,
		})

		TweenService:Create(splash, TweenInfo.new(0.3), {
			Transparency = 1,
			Size = Vector3.new(8, 2, 8),
		}):Play()
		Debris:AddItem(splash, 0.4)

		-- Water droplets
		for i = 1, 6 do
			local drop = effectPart({
				Name = "WaterDrop",
				Color = colors.Secondary,
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(0.3, 0.3, 0.3),
				Position = root.Position,
			})
			drop.Anchored = false
			drop.AssemblyLinearVelocity = Vector3.new(
				(math.random() - 0.5) * 20, math.random() * 15 + 8, (math.random() - 0.5) * 20
			)
			TweenService:Create(drop, TweenInfo.new(0.5), { Transparency = 1 }):Play()
			Debris:AddItem(drop, 0.6)
		end
	end,

	E = function(root, colors) -- Tidal Slice: blue wave projectile
		local waveDir = root.CFrame.LookVector
		local waveStart = root.Position + waveDir * 3

		local wave = effectPart({
			Name = "TidalWave",
			Color = colors.Primary,
			Size = Vector3.new(6, 3, 0.5),
			CFrame = CFrame.lookAt(waveStart, waveStart + waveDir),
			Transparency = 0.2,
		})

		TweenService:Create(wave, TweenInfo.new(0.4, Enum.EasingStyle.Linear), {
			CFrame = wave.CFrame * CFrame.new(0, 0, -20),
			Transparency = 1,
			Size = Vector3.new(8, 4, 0.5),
		}):Play()
		Debris:AddItem(wave, 0.5)

		-- Water mist trail
		for i = 1, 5 do
			task.delay(i * 0.06, function()
				local mist = effectPart({
					Name = "WaveMist",
					Color = colors.Secondary,
					Shape = Enum.PartType.Ball,
					Size = Vector3.new(1.5, 1.5, 1.5),
					Position = waveStart + waveDir * (i * 4),
					Transparency = 0.4,
				})
				TweenService:Create(mist, TweenInfo.new(0.3), { Transparency = 1, Size = Vector3.new(3, 3, 3) }):Play()
				Debris:AddItem(mist, 0.4)
			end)
		end
	end,

	R = function(root, colors) -- Mist Veil: swirling mist around character
		for i = 1, 10 do
			task.delay(i * 0.08, function()
				if not root or not root.Parent then return end
				local angle = math.rad(i * 36)
				local mistPos = root.Position + Vector3.new(math.cos(angle) * 4, math.random() * 3, math.sin(angle) * 4)
				local mist = effectPart({
					Name = "MistVeil",
					Color = colors.Secondary,
					Shape = Enum.PartType.Ball,
					Size = Vector3.new(2, 2, 2),
					Position = mistPos,
					Transparency = 0.5,
					Material = Enum.Material.SmoothPlastic,
				})
				TweenService:Create(mist, TweenInfo.new(0.6), {
					Transparency = 1,
					Size = Vector3.new(4, 4, 4),
					Position = mistPos + Vector3.new(0, 2, 0),
				}):Play()
				Debris:AddItem(mist, 0.7)
			end)
		end
	end,

	F = function(root, colors) -- Raging Current: water surge dash
		-- Large water column
		local surge = effectPart({
			Name = "RagingSurge",
			Color = colors.Primary,
			Size = Vector3.new(4, 4, 20),
			CFrame = root.CFrame * CFrame.new(0, 0, -12),
			Transparency = 0.3,
		})

		TweenService:Create(surge, TweenInfo.new(0.6), {
			Transparency = 1,
			Size = Vector3.new(6, 6, 25),
		}):Play()
		Debris:AddItem(surge, 0.7)

		-- Water burst ring
		local ring = effectPart({
			Name = "WaterRing",
			Color = colors.Secondary,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.3, 4, 4),
			CFrame = CFrame.new(root.Position) * CFrame.Angles(0, 0, math.rad(90)),
			Transparency = 0.3,
		})

		TweenService:Create(ring, TweenInfo.new(0.5), {
			Size = Vector3.new(0.3, 14, 14),
			Transparency = 1,
		}):Play()
		Debris:AddItem(ring, 0.6)
	end,
}

-- Lightning Ninja: StormFist
local lightningAbilityVFX = {
	Q = function(root, colors) -- Thunder Jab: quick yellow flash
		local flash = effectPart({
			Name = "ThunderFlash",
			Color = colors.Primary,
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(3, 3, 3),
			CFrame = root.CFrame * CFrame.new(0, 0, -4),
			Transparency = 0,
		})

		TweenService:Create(flash, TweenInfo.new(0.15), {
			Transparency = 1,
			Size = Vector3.new(6, 6, 6),
		}):Play()
		Debris:AddItem(flash, 0.2)

		-- Electric sparks
		for i = 1, 4 do
			local spark = effectPart({
				Name = "Spark",
				Color = colors.Secondary,
				Size = Vector3.new(0.1, 0.1, math.random() * 2 + 1),
				Position = root.Position + Vector3.new(
					(math.random() - 0.5) * 4, (math.random() - 0.5) * 3 + 1, (math.random() - 0.5) * 4 - 3
				),
				Transparency = 0,
			})
			TweenService:Create(spark, TweenInfo.new(0.12), { Transparency = 1 }):Play()
			Debris:AddItem(spark, 0.15)
		end
	end,

	E = function(root, colors) -- Lightning Strike: bolt from sky
		local strikePos = root.Position + root.CFrame.LookVector * 10
		local skyPos = strikePos + Vector3.new(0, 50, 0)

		-- Warning circle on ground
		local warning = effectPart({
			Name = "StrikeWarning",
			Color = colors.Primary,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.1, 6, 6),
			Position = strikePos - Vector3.new(0, 2, 0),
			Transparency = 0.5,
		})
		Debris:AddItem(warning, 1.0)

		-- Bolt comes down after brief delay
		task.delay(0.3, function()
			if warning and warning.Parent then warning:Destroy() end

			-- Lightning bolt (tall thin part)
			local bolt = effectPart({
				Name = "LightningBolt",
				Color = colors.Primary,
				Size = Vector3.new(1.5, 50, 1.5),
				Position = strikePos + Vector3.new(0, 25, 0),
				Transparency = 0,
			})

			local boltLight = Instance.new("PointLight")
			boltLight.Color = colors.Primary
			boltLight.Brightness = 8
			boltLight.Range = 40
			boltLight.Parent = bolt

			TweenService:Create(bolt, TweenInfo.new(0.3), {
				Transparency = 1,
				Size = Vector3.new(3, 50, 3),
			}):Play()
			Debris:AddItem(bolt, 0.4)

			-- Impact ring
			local impactRing = effectPart({
				Name = "LightningImpact",
				Color = colors.Secondary,
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.3, 3, 3),
				CFrame = CFrame.new(strikePos) * CFrame.Angles(0, 0, math.rad(90)),
				Transparency = 0.2,
			})

			TweenService:Create(impactRing, TweenInfo.new(0.4), {
				Size = Vector3.new(0.3, 14, 14),
				Transparency = 1,
			}):Play()
			Debris:AddItem(impactRing, 0.5)
		end)
	end,

	R = function(root, colors) -- Static Field: crackling ring on ground
		local fieldPos = root.Position

		-- Field ring
		local field = effectPart({
			Name = "StaticField",
			Color = colors.Primary,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.2, 8, 8),
			Position = fieldPos - Vector3.new(0, 2, 0),
			Transparency = 0.4,
		})

		TweenService:Create(field, TweenInfo.new(2.5), {
			Transparency = 1,
			Size = Vector3.new(0.2, 14, 14),
		}):Play()
		Debris:AddItem(field, 3.0)

		-- Periodic sparks within the field
		for i = 1, 8 do
			task.delay(i * 0.3, function()
				local sparkPos = fieldPos + Vector3.new(
					(math.random() - 0.5) * 10, -1, (math.random() - 0.5) * 10
				)
				local spark = effectPart({
					Name = "FieldSpark",
					Color = colors.Secondary,
					Size = Vector3.new(0.1, math.random() * 3 + 1, 0.1),
					Position = sparkPos,
				})
				TweenService:Create(spark, TweenInfo.new(0.1), { Transparency = 1 }):Play()
				Debris:AddItem(spark, 0.15)
			end)
		end
	end,

	F = function(root, colors) -- Storm Breaker: massive lightning explosion
		-- Ground slam ring
		local slamRing = effectPart({
			Name = "StormSlamRing",
			Color = colors.Primary,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.3, 3, 3),
			CFrame = CFrame.new(root.Position) * CFrame.Angles(0, 0, math.rad(90)),
			Transparency = 0,
		})

		TweenService:Create(slamRing, TweenInfo.new(0.6, Enum.EasingStyle.Quad), {
			Size = Vector3.new(0.3, 28, 28),
			Transparency = 1,
		}):Play()
		Debris:AddItem(slamRing, 0.7)

		-- Multiple lightning bolts around the area
		for i = 1, 6 do
			task.delay(i * 0.08, function()
				local angle = math.rad(i * 60)
				local dist = math.random(3, 8)
				local boltPos = root.Position + Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)

				local bolt = effectPart({
					Name = "StormBolt",
					Color = colors.Primary,
					Size = Vector3.new(0.8, 30, 0.8),
					Position = boltPos + Vector3.new(0, 15, 0),
				})

				TweenService:Create(bolt, TweenInfo.new(0.2), { Transparency = 1 }):Play()
				Debris:AddItem(bolt, 0.3)
			end)
		end

		-- Central explosion sphere
		local exp = effectPart({
			Name = "StormExplosion",
			Color = colors.Secondary,
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(4, 4, 4),
			Position = root.Position,
			Transparency = 0.1,
		})

		local expLight = Instance.new("PointLight")
		expLight.Color = colors.Primary
		expLight.Brightness = 8
		expLight.Range = 50
		expLight.Parent = exp

		TweenService:Create(exp, TweenInfo.new(0.5), {
			Transparency = 1,
			Size = Vector3.new(20, 20, 20),
		}):Play()
		Debris:AddItem(exp, 0.6)
	end,
}

-- Shadow Ninja: ShadowFang
local shadowAbilityVFX = {
	Q = function(root, colors) -- Shadow Step: vanish poof + reappear
		-- Vanish smoke at current position
		for i = 1, 6 do
			local smoke = effectPart({
				Name = "ShadowSmoke",
				Color = colors.Secondary,
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(1.5, 1.5, 1.5),
				Position = root.Position + Vector3.new(
					(math.random() - 0.5) * 3, (math.random() - 0.5) * 3 + 1, (math.random() - 0.5) * 3
				),
				Transparency = 0.3,
				Material = Enum.Material.SmoothPlastic,
			})

			TweenService:Create(smoke, TweenInfo.new(0.4), {
				Transparency = 1,
				Size = Vector3.new(3, 3, 3),
				Position = smoke.Position + Vector3.new(0, 2, 0),
			}):Play()
			Debris:AddItem(smoke, 0.5)
		end

		-- Brief purple flash
		local flash = effectPart({
			Name = "ShadowFlash",
			Color = colors.Primary,
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(4, 4, 4),
			Position = root.Position,
			Transparency = 0.3,
		})
		TweenService:Create(flash, TweenInfo.new(0.2), { Transparency = 1, Size = Vector3.new(7, 7, 7) }):Play()
		Debris:AddItem(flash, 0.3)
	end,

	E = function(root, colors) -- Dark Spike: spikes from ground
		local spawnDir = root.CFrame.LookVector
		for i = 1, 5 do
			task.delay(i * 0.08, function()
				local spikePos = root.Position + spawnDir * (3 + i * 3) - Vector3.new(0, 1, 0)

				local spike = effectPart({
					Name = "DarkSpike",
					Color = colors.Primary,
					Size = Vector3.new(1, 0.5, 1),
					Position = spikePos,
					Transparency = 0,
				})

				-- Spike rises from ground
				TweenService:Create(spike, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Size = Vector3.new(1.2, 6, 1.2),
					Position = spikePos + Vector3.new(0, 3, 0),
				}):Play()

				-- Then fade
				task.delay(0.3, function()
					if spike and spike.Parent then
						TweenService:Create(spike, TweenInfo.new(0.3), {
							Transparency = 1,
							Size = Vector3.new(0.5, 8, 0.5),
						}):Play()
						Debris:AddItem(spike, 0.4)
					end
				end)
			end)
		end
	end,

	R = function(root, colors) -- Counter Guard: dark shield shimmer
		local counterShield = effectPart({
			Name = "CounterShield",
			Color = colors.Primary,
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(7, 7, 7),
			Position = root.Position,
			Transparency = 0.5,
			Material = Enum.Material.ForceField,
		})

		-- Flash then settle
		TweenService:Create(counterShield, TweenInfo.new(0.2), {
			Transparency = 0.7,
			Size = Vector3.new(8, 8, 8),
		}):Play()

		-- Hold briefly then fade
		task.delay(1.0, function()
			if counterShield and counterShield.Parent then
				TweenService:Create(counterShield, TweenInfo.new(0.3), {
					Transparency = 1,
				}):Play()
				Debris:AddItem(counterShield, 0.4)
			end
		end)
	end,

	F = function(root, colors) -- Nightfall Execution: dark slash wave
		-- Dark slash wave forward
		local slashWave = effectPart({
			Name = "NightfallSlash",
			Color = colors.Primary,
			Size = Vector3.new(8, 6, 0.5),
			CFrame = root.CFrame * CFrame.new(0, 0, -5),
			Transparency = 0.1,
		})

		TweenService:Create(slashWave, TweenInfo.new(0.4, Enum.EasingStyle.Quad), {
			CFrame = slashWave.CFrame * CFrame.new(0, 0, -15),
			Transparency = 1,
			Size = Vector3.new(12, 8, 0.5),
		}):Play()
		Debris:AddItem(slashWave, 0.5)

		-- Screen darkening effect (dark sphere around character)
		local darkness = effectPart({
			Name = "NightfallDarkness",
			Color = Color3.new(0, 0, 0),
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(20, 20, 20),
			Position = root.Position,
			Transparency = 0.7,
			Material = Enum.Material.SmoothPlastic,
		})

		TweenService:Create(darkness, TweenInfo.new(0.8), {
			Transparency = 1,
			Size = Vector3.new(30, 30, 30),
		}):Play()
		Debris:AddItem(darkness, 1.0)

		-- Purple slash marks
		for i = 1, 3 do
			task.delay(i * 0.1, function()
				local slash = effectPart({
					Name = "NightSlash",
					Color = colors.Primary,
					Size = Vector3.new(0.2, 4 + i, 6 + i * 2),
					CFrame = root.CFrame * CFrame.new(
						(math.random() - 0.5) * 4,
						(math.random() - 0.5) * 2,
						-6 - i * 3
					) * CFrame.Angles(0, 0, math.rad(30 * i - 60)),
				})
				TweenService:Create(slash, TweenInfo.new(0.25), { Transparency = 1 }):Play()
				Debris:AddItem(slash, 0.35)
			end)
		end
	end,
}

-- Lookup table: ninja key -> ability VFX table
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
