--[[
	ArenaBuilder (Server)
	Generates the game world programmatically: lobby plaza + two arenas.

	Layout:
	  - Lobby: city plaza at origin (0, 0, 0)
	  - City Arena: open city block at (200, 0, 0)
	  - Shadow Realm: dark underworld arena at (400, 0, 0)

	MatchManager randomly picks an arena each match.
]]

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

--------------------------------------------------------------------------------
-- ENVIRONMENT SETUP (Lighting, Sky, Atmosphere)
--------------------------------------------------------------------------------

local function setupEnvironment()
	Workspace.Terrain:Clear()

	for _, child in ipairs(Lighting:GetChildren()) do
		child:Destroy()
	end

	-- Bright daytime lighting — clean, high visibility for fighting
	Lighting.Ambient = Color3.fromRGB(140, 140, 150)
	Lighting.OutdoorAmbient = Color3.fromRGB(130, 130, 140)
	Lighting.Brightness = 2.5
	Lighting.ClockTime = 14.5          -- early afternoon sun
	Lighting.GeographicLatitude = 30
	Lighting.FogEnd = 8000
	Lighting.FogStart = 2000
	Lighting.FogColor = Color3.fromRGB(200, 210, 220)
	Lighting.GlobalShadows = true
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 0.8

	-- Clear sky atmosphere
	local atmo = Instance.new("Atmosphere")
	atmo.Density = 0.2
	atmo.Offset = 0.25
	atmo.Color = Color3.fromRGB(200, 210, 225)
	atmo.Decay = Color3.fromRGB(160, 170, 190)
	atmo.Glare = 0
	atmo.Haze = 0.5
	atmo.Parent = Lighting

	local sky = Instance.new("Sky")
	sky.StarCount = 0
	sky.CelestialBodiesShown = true
	sky.SunAngularSize = 18
	sky.Parent = Lighting

	-- Subtle bloom for neon accents
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.25
	bloom.Size = 20
	bloom.Threshold = 2.5
	bloom.Parent = Lighting

	-- Color correction — slightly desaturated urban feel
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Brightness = 0.02
	cc.Contrast = 0.08
	cc.Saturation = -0.05
	cc.TintColor = Color3.fromRGB(248, 248, 255)
	cc.Parent = Lighting

	-- Sun rays for atmosphere
	local rays = Instance.new("SunRaysEffect")
	rays.Intensity = 0.05
	rays.Spread = 0.8
	rays.Parent = Lighting
end

--------------------------------------------------------------------------------
-- HELPERS
--------------------------------------------------------------------------------

local function createPart(properties)
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CastShadow = true

	for key, value in pairs(properties) do
		part[key] = value
	end

	return part
end

local function createInvisibleWall(parent, position, size)
	local wall = Instance.new("Part")
	wall.Name = "Barrier"
	wall.Anchored = true
	wall.Transparency = 1
	wall.CanCollide = true
	wall.Size = size
	wall.Position = position
	wall.Parent = parent
	return wall
end

-- Adds a simple window grid (SurfaceGui) to a building face
local function addWindows(building, face, rows, cols, windowColor)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.Parent = building

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 1, 0)
	frame.BackgroundTransparency = 1
	frame.Parent = gui

	-- Padding
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0.05, 0)
	padding.PaddingBottom = UDim.new(0.05, 0)
	padding.PaddingLeft = UDim.new(0.05, 0)
	padding.PaddingRight = UDim.new(0.05, 0)
	padding.Parent = frame

	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(1 / cols - 0.02, 0, 1 / rows - 0.02, 0)
	grid.CellPadding = UDim2.new(0.01, 0, 0.01, 0)
	grid.FillDirection = Enum.FillDirection.Horizontal
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = frame

	local wColor = windowColor or Color3.fromRGB(160, 200, 220)
	for i = 1, rows * cols do
		local window = Instance.new("Frame")
		window.BackgroundColor3 = wColor
		window.BackgroundTransparency = 0.15
		window.BorderSizePixel = 0
		window.LayoutOrder = i
		window.Parent = frame
	end
end

-- Build a city building with optional windows
local function createBuilding(parent, pos, size, color, windowRows, windowCols, windowFaces)
	local building = createPart({
		Name = "Building",
		Size = size,
		Position = pos,
		Color = color or Color3.fromRGB(160, 160, 165),
		Material = Enum.Material.Concrete,
	})
	building.Parent = parent

	-- Roof accent
	local roofHeight = 1
	local roof = createPart({
		Name = "Roof",
		Size = Vector3.new(size.X + 0.5, roofHeight, size.Z + 0.5),
		Position = pos + Vector3.new(0, size.Y / 2 + roofHeight / 2, 0),
		Color = Color3.fromRGB(
			math.max(0, color.R * 255 - 20) / 255,
			math.max(0, color.G * 255 - 20) / 255,
			math.max(0, color.B * 255 - 20) / 255
		),
		Material = Enum.Material.Concrete,
	})
	roof.Parent = parent

	-- Windows
	if windowRows and windowCols then
		local faces = windowFaces or { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }
		local wColors = {
			Color3.fromRGB(140, 190, 220), -- blue-tinted glass
			Color3.fromRGB(180, 210, 200), -- green-tinted glass
			Color3.fromRGB(170, 170, 190), -- gray glass
		}
		local wColor = wColors[math.random(1, #wColors)]
		for _, face in ipairs(faces) do
			addWindows(building, face, windowRows, windowCols, wColor)
		end
	end

	return building
end

-- Create a street lamp
local function createStreetLamp(parent, position)
	-- Pole
	local pole = createPart({
		Name = "LampPole",
		Size = Vector3.new(0.5, 12, 0.5),
		Position = position + Vector3.new(0, 6, 0),
		Color = Color3.fromRGB(60, 60, 65),
		Material = Enum.Material.Metal,
	})
	pole.Parent = parent

	-- Arm
	local arm = createPart({
		Name = "LampArm",
		Size = Vector3.new(3, 0.3, 0.3),
		Position = position + Vector3.new(1.5, 12, 0),
		Color = Color3.fromRGB(60, 60, 65),
		Material = Enum.Material.Metal,
	})
	arm.Parent = parent

	-- Light housing
	local housing = createPart({
		Name = "LampHousing",
		Size = Vector3.new(1.5, 0.5, 1.5),
		Position = position + Vector3.new(3, 11.5, 0),
		Color = Color3.fromRGB(80, 80, 85),
		Material = Enum.Material.Metal,
	})
	housing.Parent = parent

	-- Light
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 240, 210)
	light.Brightness = 1
	light.Range = 25
	light.Parent = housing
end

-- Create a concrete barrier
local function createBarrier(parent, position, rotation)
	local barrier = createPart({
		Name = "ConcreteBarrier",
		Size = Vector3.new(4, 2.5, 1.5),
		CFrame = CFrame.new(position) * CFrame.Angles(0, math.rad(rotation or 0), 0),
		Color = Color3.fromRGB(170, 170, 170),
		Material = Enum.Material.Concrete,
	})
	barrier.Parent = parent

	-- Yellow warning stripe
	local stripe = createPart({
		Name = "BarrierStripe",
		Size = Vector3.new(4.05, 0.3, 0.1),
		CFrame = barrier.CFrame * CFrame.new(0, 0.5, 0.75),
		Color = Color3.fromRGB(255, 200, 0),
		Material = Enum.Material.SmoothPlastic,
	})
	stripe.Parent = parent
end

-- Create a dumpster
local function createDumpster(parent, position, rotation)
	local body = createPart({
		Name = "Dumpster",
		Size = Vector3.new(4, 3, 2.5),
		CFrame = CFrame.new(position + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, math.rad(rotation or 0), 0),
		Color = Color3.fromRGB(40, 90, 40),
		Material = Enum.Material.Metal,
	})
	body.Parent = parent

	-- Lid
	local lid = createPart({
		Name = "DumpsterLid",
		Size = Vector3.new(4.2, 0.2, 2.7),
		CFrame = body.CFrame * CFrame.new(0, 1.6, 0),
		Color = Color3.fromRGB(35, 80, 35),
		Material = Enum.Material.Metal,
	})
	lid.Parent = parent
end

-- Create road markings
local function createRoadLine(parent, position, size, dashed)
	if dashed then
		local numDashes = math.floor(size.Z / 4)
		for i = 0, numDashes - 1 do
			local dash = createPart({
				Name = "RoadDash",
				Size = Vector3.new(size.X, 0.05, 2),
				Position = position + Vector3.new(0, 0, -size.Z / 2 + i * 4 + 1),
				Color = Color3.fromRGB(255, 255, 255),
				Material = Enum.Material.SmoothPlastic,
			})
			dash.Parent = parent
		end
	else
		local line = createPart({
			Name = "RoadLine",
			Size = Vector3.new(size.X, 0.05, size.Z),
			Position = position,
			Color = Color3.fromRGB(255, 255, 255),
			Material = Enum.Material.SmoothPlastic,
		})
		line.Parent = parent
	end
end

-- Create a parked car (simple blocky shape)
local function createCar(parent, position, rotation, bodyColor)
	local cf = CFrame.new(position) * CFrame.Angles(0, math.rad(rotation or 0), 0)

	-- Car body
	local body = createPart({
		Name = "CarBody",
		Size = Vector3.new(5.5, 2, 10),
		CFrame = cf * CFrame.new(0, 1.5, 0),
		Color = bodyColor or Color3.fromRGB(180, 40, 40),
		Material = Enum.Material.SmoothPlastic,
	})
	body.Parent = parent

	-- Cabin/roof
	local cabin = createPart({
		Name = "CarCabin",
		Size = Vector3.new(5, 1.8, 5),
		CFrame = cf * CFrame.new(0, 3.2, -0.5),
		Color = bodyColor or Color3.fromRGB(180, 40, 40),
		Material = Enum.Material.SmoothPlastic,
	})
	cabin.Parent = parent

	-- Windshield
	local windshield = createPart({
		Name = "Windshield",
		Size = Vector3.new(4.5, 1.5, 0.2),
		CFrame = cf * CFrame.new(0, 3, -3) * CFrame.Angles(math.rad(15), 0, 0),
		Color = Color3.fromRGB(150, 200, 230),
		Material = Enum.Material.Glass,
		Transparency = 0.4,
	})
	windshield.Parent = parent

	-- Wheels (4 cylinders)
	local wheelPositions = {
		cf * CFrame.new(-2.5, 0.6, -3),
		cf * CFrame.new(2.5, 0.6, -3),
		cf * CFrame.new(-2.5, 0.6, 3),
		cf * CFrame.new(2.5, 0.6, 3),
	}
	for _, wCF in ipairs(wheelPositions) do
		local wheel = createPart({
			Name = "Wheel",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.2, 1, 1.2),
			CFrame = wCF * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(30, 30, 30),
			Material = Enum.Material.SmoothPlastic,
		})
		wheel.Parent = parent
	end
end

--------------------------------------------------------------------------------
-- BUILD LOBBY (city plaza)
--------------------------------------------------------------------------------

local function buildLobby()
	local folder = Instance.new("Folder")
	folder.Name = "Lobby"
	folder.Parent = Workspace

	-- Ground: large concrete plaza
	local ground = createPart({
		Name = "LobbyGround",
		Size = Vector3.new(120, 2, 120),
		Position = Vector3.new(0, -1, 0),
		Color = Color3.fromRGB(165, 165, 160),
		Material = Enum.Material.Concrete,
	})
	ground.Parent = folder

	-- Sidewalk border (slightly raised)
	local sidewalkData = {
		{ pos = Vector3.new(0, 0.2, -55), size = Vector3.new(120, 0.4, 10) },
		{ pos = Vector3.new(0, 0.2, 55), size = Vector3.new(120, 0.4, 10) },
		{ pos = Vector3.new(-55, 0.2, 0), size = Vector3.new(10, 0.4, 100) },
		{ pos = Vector3.new(55, 0.2, 0), size = Vector3.new(10, 0.4, 100) },
	}
	for i, sw in ipairs(sidewalkData) do
		local sidewalk = createPart({
			Name = "Sidewalk_" .. i,
			Size = sw.size,
			Position = sw.pos,
			Color = Color3.fromRGB(180, 180, 175),
			Material = Enum.Material.Concrete,
		})
		sidewalk.Parent = folder
	end

	-- Lobby spawn (default spawn for joining players)
	local lobbySpawn = Instance.new("SpawnLocation")
	lobbySpawn.Name = "LobbySpawn"
	lobbySpawn.Anchored = true
	lobbySpawn.Size = Vector3.new(8, 0.2, 8)
	lobbySpawn.Position = Vector3.new(0, 0.1, 0)
	lobbySpawn.TopSurface = Enum.SurfaceType.Smooth
	lobbySpawn.CanCollide = true
	lobbySpawn.Enabled = true
	lobbySpawn.Transparency = 1
	lobbySpawn.Parent = folder

	-- Title sign on a building wall
	local signWall = createPart({
		Name = "SignWall",
		Size = Vector3.new(30, 10, 1),
		Position = Vector3.new(0, 15, -49),
		Color = Color3.fromRGB(50, 50, 55),
		Material = Enum.Material.SmoothPlastic,
	})
	signWall.Parent = folder

	local signGui = Instance.new("SurfaceGui")
	signGui.Face = Enum.NormalId.Front
	signGui.Parent = signWall

	local signText = Instance.new("TextLabel")
	signText.Size = UDim2.new(1, 0, 0.5, 0)
	signText.Position = UDim2.new(0, 0, 0.1, 0)
	signText.BackgroundTransparency = 1
	signText.Text = "ELEMENTAL NINJA DUELS"
	signText.TextColor3 = Color3.fromRGB(255, 215, 0)
	signText.TextScaled = true
	signText.Font = Enum.Font.GothamBold
	signText.Parent = signGui

	local subText = Instance.new("TextLabel")
	subText.Size = UDim2.new(1, 0, 0.25, 0)
	subText.Position = UDim2.new(0, 0, 0.6, 0)
	subText.BackgroundTransparency = 1
	subText.Text = "SELECT YOUR NINJA & FIGHT"
	subText.TextColor3 = Color3.fromRGB(200, 200, 210)
	subText.TextScaled = true
	subText.Font = Enum.Font.Gotham
	subText.Parent = signGui

	-- Lobby buildings (surrounding the plaza)
	local lobbyBuildings = {
		-- Back row (behind sign)
		{ pos = Vector3.new(-30, 20, -58), size = Vector3.new(22, 40, 16), color = Color3.fromRGB(150, 145, 140), rows = 8, cols = 4 },
		{ pos = Vector3.new(30, 15, -58), size = Vector3.new(26, 30, 16), color = Color3.fromRGB(140, 140, 150), rows = 6, cols = 5 },
		-- Left side
		{ pos = Vector3.new(-58, 17, -15), size = Vector3.new(16, 34, 22), color = Color3.fromRGB(155, 150, 145), rows = 7, cols = 4 },
		{ pos = Vector3.new(-58, 12, 20), size = Vector3.new(16, 24, 20), color = Color3.fromRGB(160, 155, 155), rows = 5, cols = 4 },
		-- Right side
		{ pos = Vector3.new(58, 22, -10), size = Vector3.new(16, 44, 25), color = Color3.fromRGB(145, 145, 150), rows = 9, cols = 5 },
		{ pos = Vector3.new(58, 10, 25), size = Vector3.new(16, 20, 18), color = Color3.fromRGB(165, 160, 155), rows = 4, cols = 3 },
		-- Front side
		{ pos = Vector3.new(-25, 14, 58), size = Vector3.new(20, 28, 16), color = Color3.fromRGB(150, 150, 155), rows = 6, cols = 4 },
		{ pos = Vector3.new(25, 18, 58), size = Vector3.new(24, 36, 16), color = Color3.fromRGB(155, 152, 148), rows = 7, cols = 5 },
	}

	for _, bData in ipairs(lobbyBuildings) do
		createBuilding(folder, bData.pos, bData.size, bData.color, bData.rows, bData.cols)
	end

	-- Element pillars (decorative, one per ninja element)
	local pillarData = {
		{ pos = Vector3.new(-12, 4, -12), color = Color3.fromRGB(255, 80, 20), label = "FIRE" },
		{ pos = Vector3.new(12, 4, -12), color = Color3.fromRGB(30, 144, 255), label = "WATER" },
		{ pos = Vector3.new(-12, 4, 12), color = Color3.fromRGB(255, 230, 50), label = "LIGHTNING" },
		{ pos = Vector3.new(12, 4, 12), color = Color3.fromRGB(100, 50, 160), label = "SHADOW" },
	}

	for _, pData in ipairs(pillarData) do
		local pillar = createPart({
			Name = "ElementPillar",
			Size = Vector3.new(3, 8, 3),
			Position = pData.pos,
			Color = pData.color,
			Material = Enum.Material.Neon,
		})
		pillar.Parent = folder

		local pillarLight = Instance.new("PointLight")
		pillarLight.Color = pData.color
		pillarLight.Brightness = 2
		pillarLight.Range = 15
		pillarLight.Parent = pillar
	end

	-- Street lamps in lobby
	createStreetLamp(folder, Vector3.new(-25, 0, -25))
	createStreetLamp(folder, Vector3.new(25, 0, -25))
	createStreetLamp(folder, Vector3.new(-25, 0, 25))
	createStreetLamp(folder, Vector3.new(25, 0, 25))

	return folder
end

--------------------------------------------------------------------------------
-- BUILD ARENA (city battleground)
--------------------------------------------------------------------------------

local function buildArena()
	local folder = Instance.new("Folder")
	folder.Name = "Arena"
	folder.Parent = Workspace

	local CX, CZ = 200, 0  -- arena center

	-- Ground: damaged asphalt / concrete
	local ground = createPart({
		Name = "ArenaGround",
		Size = Vector3.new(140, 2, 140),
		Position = Vector3.new(CX, -1, CZ),
		Color = Color3.fromRGB(130, 130, 125),
		Material = Enum.Material.Concrete,
	})
	ground.Parent = folder

	-- Road running through the arena (X-axis)
	local road = createPart({
		Name = "Road",
		Size = Vector3.new(140, 0.05, 22),
		Position = Vector3.new(CX, 0.05, CZ),
		Color = Color3.fromRGB(60, 60, 60),
		Material = Enum.Material.Asphalt,
	})
	road.Parent = folder

	-- Road markings
	createRoadLine(folder, Vector3.new(CX, 0.1, CZ), Vector3.new(0.3, 0.05, 140), true) -- center dashed
	createRoadLine(folder, Vector3.new(CX, 0.1, CZ - 10), Vector3.new(0.4, 0.05, 140), false) -- edge solid
	createRoadLine(folder, Vector3.new(CX, 0.1, CZ + 10), Vector3.new(0.4, 0.05, 140), false) -- edge solid

	-- Cross road (Z-axis)
	local crossRoad = createPart({
		Name = "CrossRoad",
		Size = Vector3.new(22, 0.05, 140),
		Position = Vector3.new(CX, 0.05, CZ),
		Color = Color3.fromRGB(60, 60, 60),
		Material = Enum.Material.Asphalt,
	})
	crossRoad.Parent = folder

	-- Sidewalks around the intersection
	local sidewalks = {
		{ pos = Vector3.new(CX - 40, 0.3, CZ - 40), size = Vector3.new(50, 0.6, 50) },
		{ pos = Vector3.new(CX + 40, 0.3, CZ - 40), size = Vector3.new(50, 0.6, 50) },
		{ pos = Vector3.new(CX - 40, 0.3, CZ + 40), size = Vector3.new(50, 0.6, 50) },
		{ pos = Vector3.new(CX + 40, 0.3, CZ + 40), size = Vector3.new(50, 0.6, 50) },
	}
	for i, sw in ipairs(sidewalks) do
		local sidewalk = createPart({
			Name = "Sidewalk_" .. i,
			Size = sw.size,
			Position = sw.pos,
			Color = Color3.fromRGB(175, 175, 170),
			Material = Enum.Material.Concrete,
		})
		sidewalk.Parent = folder
	end

	-- Arena buildings (surrounding the intersection on all 4 corners)
	local arenaBuildings = {
		-- Northeast corner (quadrant: +X, -Z)
		{ pos = Vector3.new(CX + 42, 25, CZ - 42), size = Vector3.new(28, 50, 28), color = Color3.fromRGB(155, 150, 148), rows = 10, cols = 5 },
		{ pos = Vector3.new(CX + 55, 15, CZ - 20), size = Vector3.new(18, 30, 16), color = Color3.fromRGB(145, 145, 150), rows = 6, cols = 3 },
		{ pos = Vector3.new(CX + 25, 12, CZ - 55), size = Vector3.new(20, 24, 18), color = Color3.fromRGB(160, 158, 152), rows = 5, cols = 4 },

		-- Northwest corner (quadrant: -X, -Z)
		{ pos = Vector3.new(CX - 42, 20, CZ - 42), size = Vector3.new(26, 40, 26), color = Color3.fromRGB(150, 148, 145), rows = 8, cols = 5 },
		{ pos = Vector3.new(CX - 55, 17, CZ - 22), size = Vector3.new(18, 34, 20), color = Color3.fromRGB(158, 155, 150), rows = 7, cols = 3 },
		{ pos = Vector3.new(CX - 22, 10, CZ - 55), size = Vector3.new(16, 20, 16), color = Color3.fromRGB(162, 160, 155), rows = 4, cols = 3 },

		-- Southeast corner (quadrant: +X, +Z)
		{ pos = Vector3.new(CX + 42, 22, CZ + 42), size = Vector3.new(24, 44, 24), color = Color3.fromRGB(148, 148, 152), rows = 9, cols = 4 },
		{ pos = Vector3.new(CX + 55, 13, CZ + 20), size = Vector3.new(18, 26, 18), color = Color3.fromRGB(155, 152, 148), rows = 5, cols = 3 },
		{ pos = Vector3.new(CX + 20, 16, CZ + 55), size = Vector3.new(22, 32, 18), color = Color3.fromRGB(152, 150, 155), rows = 6, cols = 4 },

		-- Southwest corner (quadrant: -X, +Z)
		{ pos = Vector3.new(CX - 42, 18, CZ + 42), size = Vector3.new(22, 36, 22), color = Color3.fromRGB(158, 155, 152), rows = 7, cols = 4 },
		{ pos = Vector3.new(CX - 55, 25, CZ + 22), size = Vector3.new(18, 50, 20), color = Color3.fromRGB(142, 142, 148), rows = 10, cols = 3 },
		{ pos = Vector3.new(CX - 22, 11, CZ + 55), size = Vector3.new(18, 22, 16), color = Color3.fromRGB(165, 162, 158), rows = 4, cols = 3 },
	}

	for _, bData in ipairs(arenaBuildings) do
		createBuilding(folder, bData.pos, bData.size, bData.color, bData.rows, bData.cols)
	end

	-- Street lamps around the intersection
	local lampPositions = {
		Vector3.new(CX - 13, 0, CZ - 13),
		Vector3.new(CX + 13, 0, CZ - 13),
		Vector3.new(CX - 13, 0, CZ + 13),
		Vector3.new(CX + 13, 0, CZ + 13),
	}
	for _, pos in ipairs(lampPositions) do
		createStreetLamp(folder, pos)
	end

	-- Props: concrete barriers, dumpsters, cars
	createBarrier(folder, Vector3.new(CX - 15, 0, CZ - 14), 0)
	createBarrier(folder, Vector3.new(CX + 16, 0, CZ + 14), 90)
	createBarrier(folder, Vector3.new(CX + 14, 0, CZ - 16), 45)

	createDumpster(folder, Vector3.new(CX - 28, 0, CZ - 16), 10)
	createDumpster(folder, Vector3.new(CX + 30, 0, CZ + 18), -20)

	-- Parked cars along the road edges
	createCar(folder, Vector3.new(CX - 20, 0, CZ + 14), 0, Color3.fromRGB(40, 80, 160))
	createCar(folder, Vector3.new(CX + 22, 0, CZ - 14), 180, Color3.fromRGB(180, 40, 40))
	createCar(folder, Vector3.new(CX - 35, 0, CZ - 14), 0, Color3.fromRGB(220, 220, 220))

	-- Rubble/debris piles (small clusters of parts for battle-worn feel)
	local rubblePositions = {
		Vector3.new(CX + 8, 0, CZ + 6),
		Vector3.new(CX - 10, 0, CZ - 8),
		Vector3.new(CX + 5, 0, CZ - 5),
	}
	for _, rPos in ipairs(rubblePositions) do
		for i = 1, math.random(3, 5) do
			local rubble = createPart({
				Name = "Rubble",
				Size = Vector3.new(
					math.random() * 1.5 + 0.5,
					math.random() * 0.8 + 0.3,
					math.random() * 1.5 + 0.5
				),
				Position = rPos + Vector3.new(
					(math.random() - 0.5) * 4,
					math.random() * 0.5,
					(math.random() - 0.5) * 4
				),
				Color = Color3.fromRGB(
					140 + math.random(-15, 15),
					140 + math.random(-15, 15),
					135 + math.random(-15, 15)
				),
				Material = Enum.Material.Concrete,
				Rotation = Vector3.new(
					math.random() * 30,
					math.random() * 360,
					math.random() * 30
				),
			})
			rubble.Parent = folder
		end
	end

	-- Arena spawn points (invisible, used by MatchManager)
	local spawnA = Instance.new("SpawnLocation")
	spawnA.Name = "ArenaSpawnA"
	spawnA.Anchored = true
	spawnA.Size = Vector3.new(6, 0.2, 6)
	spawnA.Position = Vector3.new(CX, 0.1, CZ - 20)
	spawnA.TopSurface = Enum.SurfaceType.Smooth
	spawnA.CanCollide = true
	spawnA.Enabled = false
	spawnA.Transparency = 1
	spawnA.Parent = folder

	local spawnB = Instance.new("SpawnLocation")
	spawnB.Name = "ArenaSpawnB"
	spawnB.Anchored = true
	spawnB.Size = Vector3.new(6, 0.2, 6)
	spawnB.Position = Vector3.new(CX, 0.1, CZ + 20)
	spawnB.TopSurface = Enum.SurfaceType.Smooth
	spawnB.CanCollide = true
	spawnB.Enabled = false
	spawnB.Transparency = 1
	spawnB.Parent = folder

	-- Invisible arena boundaries (keep fighters in the intersection area)
	createInvisibleWall(folder, Vector3.new(CX, 20, CZ - 65), Vector3.new(140, 40, 2))
	createInvisibleWall(folder, Vector3.new(CX, 20, CZ + 65), Vector3.new(140, 40, 2))
	createInvisibleWall(folder, Vector3.new(CX - 65, 20, CZ), Vector3.new(2, 40, 140))
	createInvisibleWall(folder, Vector3.new(CX + 65, 20, CZ), Vector3.new(2, 40, 140))
	createInvisibleWall(folder, Vector3.new(CX, 50, CZ), Vector3.new(140, 2, 140)) -- ceiling

	return folder
end

--------------------------------------------------------------------------------
-- BUILD SHADOW REALM (dark underworld arena)
--------------------------------------------------------------------------------

local function buildShadowRealm()
	local folder = Instance.new("Folder")
	folder.Name = "ShadowRealm"
	folder.Parent = Workspace

	local CX, CZ = 400, 0  -- shadow realm center

	-- Void floor far below (neon lava layer visible through gaps)
	local lavaFloor = createPart({
		Name = "LavaFloor",
		Size = Vector3.new(200, 2, 200),
		Position = Vector3.new(CX, -12, CZ),
		Color = Color3.fromRGB(255, 80, 0),
		Material = Enum.Material.Neon,
	})
	lavaFloor.Parent = folder

	-- Main fighting platform: dark obsidian
	local platform = createPart({
		Name = "ShadowPlatform",
		Size = Vector3.new(100, 4, 100),
		Position = Vector3.new(CX, -2, CZ),
		Color = Color3.fromRGB(25, 20, 30),
		Material = Enum.Material.Basalt,
	})
	platform.Parent = folder

	-- Cracked stone surface layer
	local surface = createPart({
		Name = "ShadowSurface",
		Size = Vector3.new(90, 0.5, 90),
		Position = Vector3.new(CX, 0.25, CZ),
		Color = Color3.fromRGB(35, 30, 40),
		Material = Enum.Material.Slate,
	})
	surface.Parent = folder

	-- LAVA CHANNELS: rivers of lava carved into the platform edges
	local lavaChannels = {
		-- Outer ring channels (gaps showing lava below)
		{ pos = Vector3.new(CX - 42, -0.5, CZ), size = Vector3.new(3, 1, 80) },
		{ pos = Vector3.new(CX + 42, -0.5, CZ), size = Vector3.new(3, 1, 80) },
		{ pos = Vector3.new(CX, -0.5, CZ - 42), size = Vector3.new(80, 1, 3) },
		{ pos = Vector3.new(CX, -0.5, CZ + 42), size = Vector3.new(80, 1, 3) },
		-- Cross channels
		{ pos = Vector3.new(CX - 20, -0.5, CZ - 20), size = Vector3.new(2, 1, 30) },
		{ pos = Vector3.new(CX + 20, -0.5, CZ + 20), size = Vector3.new(2, 1, 30) },
	}

	for i, lc in ipairs(lavaChannels) do
		local channel = createPart({
			Name = "LavaChannel_" .. i,
			Size = lc.size,
			Position = lc.pos,
			Color = Color3.fromRGB(255, 100, 0),
			Material = Enum.Material.Neon,
		})
		channel.CanCollide = false
		channel.Parent = folder

		local lavaLight = Instance.new("PointLight")
		lavaLight.Color = Color3.fromRGB(255, 80, 0)
		lavaLight.Brightness = 1.5
		lavaLight.Range = 12
		lavaLight.Parent = channel
	end

	-- LAVA POOLS: bubbling lava pools at corners
	local poolPositions = {
		Vector3.new(CX - 35, -0.3, CZ - 35),
		Vector3.new(CX + 35, -0.3, CZ - 35),
		Vector3.new(CX - 35, -0.3, CZ + 35),
		Vector3.new(CX + 35, -0.3, CZ + 35),
	}

	for i, poolPos in ipairs(poolPositions) do
		local pool = createPart({
			Name = "LavaPool_" .. i,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1, 10, 10),
			CFrame = CFrame.new(poolPos),
			Color = Color3.fromRGB(255, 60, 0),
			Material = Enum.Material.Neon,
		})
		pool.CanCollide = false
		pool.Parent = folder

		local poolLight = Instance.new("PointLight")
		poolLight.Color = Color3.fromRGB(255, 100, 0)
		poolLight.Brightness = 3
		poolLight.Range = 20
		poolLight.Parent = pool
	end

	-- OBSIDIAN PILLARS: dark stone columns around the arena
	local pillarData = {
		{ pos = Vector3.new(CX - 30, 10, CZ - 30), height = 20, width = 4 },
		{ pos = Vector3.new(CX + 30, 12, CZ - 30), height = 24, width = 3.5 },
		{ pos = Vector3.new(CX - 30, 11, CZ + 30), height = 22, width = 3.5 },
		{ pos = Vector3.new(CX + 30, 9, CZ + 30), height = 18, width = 4 },
		{ pos = Vector3.new(CX - 38, 14, CZ), height = 28, width = 5 },
		{ pos = Vector3.new(CX + 38, 13, CZ), height = 26, width = 5 },
		{ pos = Vector3.new(CX, 15, CZ - 38), height = 30, width = 4.5 },
		{ pos = Vector3.new(CX, 11, CZ + 38), height = 22, width = 4.5 },
	}

	for i, pd in ipairs(pillarData) do
		local pillar = createPart({
			Name = "ObsidianPillar_" .. i,
			Size = Vector3.new(pd.width, pd.height, pd.width),
			Position = pd.pos,
			Color = Color3.fromRGB(20, 15, 25),
			Material = Enum.Material.Basalt,
		})
		pillar.Parent = folder

		-- Glowing rune accent at top
		local runeAccent = createPart({
			Name = "PillarRune_" .. i,
			Size = Vector3.new(pd.width + 0.5, 1.5, pd.width + 0.5),
			Position = pd.pos + Vector3.new(0, pd.height / 2 - 0.5, 0),
			Color = Color3.fromRGB(160, 40, 200),
			Material = Enum.Material.Neon,
		})
		runeAccent.Parent = folder

		local runeLight = Instance.new("PointLight")
		runeLight.Color = Color3.fromRGB(140, 30, 180)
		runeLight.Brightness = 2
		runeLight.Range = 15
		runeLight.Parent = runeAccent
	end

	-- CENTER RUNE CIRCLE: glowing ritual circle on the ground
	-- Outer ring
	local runeRingOuter = createPart({
		Name = "RuneRingOuter",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.15, 30, 30),
		Position = Vector3.new(CX, 0.55, CZ),
		Color = Color3.fromRGB(180, 50, 220),
		Material = Enum.Material.Neon,
	})
	runeRingOuter.CanCollide = false
	runeRingOuter.Parent = folder

	-- Inner ring
	local runeRingInner = createPart({
		Name = "RuneRingInner",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.15, 18, 18),
		Position = Vector3.new(CX, 0.56, CZ),
		Color = Color3.fromRGB(120, 30, 160),
		Material = Enum.Material.Neon,
	})
	runeRingInner.CanCollide = false
	runeRingInner.Parent = folder

	-- Fill inside the inner ring to hide the neon
	local runeFill = createPart({
		Name = "RuneFill",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.14, 17, 17),
		Position = Vector3.new(CX, 0.555, CZ),
		Color = Color3.fromRGB(35, 30, 40),
		Material = Enum.Material.Slate,
	})
	runeFill.CanCollide = false
	runeFill.Parent = folder

	-- Rune lines (radial spokes inside the circle)
	for i = 1, 8 do
		local angle = math.rad(i * 45)
		local lineLength = 14
		local midX = CX + math.cos(angle) * lineLength / 2
		local midZ = CZ + math.sin(angle) * lineLength / 2

		local runeLine = createPart({
			Name = "RuneLine_" .. i,
			Size = Vector3.new(0.3, 0.1, lineLength),
			CFrame = CFrame.lookAt(
				Vector3.new(midX, 0.58, midZ),
				Vector3.new(CX + math.cos(angle) * lineLength, 0.58, CZ + math.sin(angle) * lineLength)
			),
			Color = Color3.fromRGB(160, 40, 200),
			Material = Enum.Material.Neon,
		})
		runeLine.CanCollide = false
		runeLine.Parent = folder
	end

	-- Central rune glow
	local centerGlow = Instance.new("PointLight")
	centerGlow.Color = Color3.fromRGB(140, 30, 180)
	centerGlow.Brightness = 2
	centerGlow.Range = 25
	centerGlow.Parent = runeRingOuter

	-- FLOATING ROCKS: hovering chunks of dark stone above the arena
	local floatingRocks = {
		{ pos = Vector3.new(CX - 25, 25, CZ - 20), size = Vector3.new(8, 4, 6), rot = Vector3.new(10, 30, -5) },
		{ pos = Vector3.new(CX + 20, 30, CZ + 15), size = Vector3.new(10, 5, 7), rot = Vector3.new(-8, 45, 12) },
		{ pos = Vector3.new(CX + 30, 22, CZ - 25), size = Vector3.new(6, 3, 8), rot = Vector3.new(15, -20, 8) },
		{ pos = Vector3.new(CX - 15, 35, CZ + 28), size = Vector3.new(12, 6, 9), rot = Vector3.new(-5, 60, -10) },
		{ pos = Vector3.new(CX, 40, CZ), size = Vector3.new(14, 5, 14), rot = Vector3.new(3, 0, 3) },
		{ pos = Vector3.new(CX - 35, 28, CZ + 10), size = Vector3.new(7, 3, 5), rot = Vector3.new(20, -40, 5) },
		{ pos = Vector3.new(CX + 10, 33, CZ - 35), size = Vector3.new(9, 4, 6), rot = Vector3.new(-12, 25, -8) },
	}

	for i, rock in ipairs(floatingRocks) do
		local floater = createPart({
			Name = "FloatingRock_" .. i,
			Size = rock.size,
			Position = rock.pos,
			Rotation = rock.rot,
			Color = Color3.fromRGB(30 + math.random(-5, 5), 25 + math.random(-5, 5), 35 + math.random(-5, 5)),
			Material = Enum.Material.Basalt,
		})
		floater.Parent = folder

		-- Underside glow (lava light from below)
		local underGlow = Instance.new("PointLight")
		underGlow.Color = Color3.fromRGB(255, 80, 0)
		underGlow.Brightness = 0.8
		underGlow.Range = 10
		underGlow.Parent = floater
	end

	-- CHAINS: hanging from floating rocks
	local chainAnchors = {
		{ from = Vector3.new(CX - 25, 22, CZ - 20), length = 18 },
		{ from = Vector3.new(CX + 20, 26, CZ + 15), length = 22 },
		{ from = Vector3.new(CX, 36, CZ), length = 32 },
		{ from = Vector3.new(CX - 15, 30, CZ + 28), length = 26 },
	}

	for i, chain in ipairs(chainAnchors) do
		local numLinks = math.floor(chain.length / 2)
		for j = 0, numLinks - 1 do
			local link = createPart({
				Name = "ChainLink_" .. i .. "_" .. j,
				Size = Vector3.new(0.4, 2, 0.4),
				Position = chain.from + Vector3.new(0, -j * 2, 0),
				Color = Color3.fromRGB(50, 45, 40),
				Material = Enum.Material.Metal,
			})
			link.CanCollide = false
			link.Parent = folder
		end
	end

	-- SKULL PEDESTALS at spawn points
	for _, spawnOffset in ipairs({ Vector3.new(0, 0, -20), Vector3.new(0, 0, 20) }) do
		local pedestalPos = Vector3.new(CX, 0, CZ) + spawnOffset

		-- Pedestal base
		local pedestal = createPart({
			Name = "SkullPedestal",
			Size = Vector3.new(5, 1.5, 5),
			Position = pedestalPos + Vector3.new(0, 0.75, 0),
			Color = Color3.fromRGB(40, 35, 45),
			Material = Enum.Material.Basalt,
		})
		pedestal.Parent = folder

		-- Pedestal accent ring
		local pedestalRing = createPart({
			Name = "PedestalRing",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.3, 6, 6),
			Position = pedestalPos + Vector3.new(0, 1.5, 0),
			Color = Color3.fromRGB(180, 50, 220),
			Material = Enum.Material.Neon,
		})
		pedestalRing.CanCollide = false
		pedestalRing.Parent = folder

		-- Skull (simplified: sphere with smaller sphere eyes)
		local skull = createPart({
			Name = "Skull",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(2.5, 2.5, 2.5),
			Position = pedestalPos + Vector3.new(0, 3, 0),
			Color = Color3.fromRGB(200, 190, 170),
			Material = Enum.Material.SmoothPlastic,
		})
		skull.Parent = folder

		-- Skull eyes
		for _, eyeOffset in ipairs({ Vector3.new(-0.4, 0.2, -1), Vector3.new(0.4, 0.2, -1) }) do
			local eye = createPart({
				Name = "SkullEye",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(0.5, 0.5, 0.5),
				Position = pedestalPos + Vector3.new(0, 3, 0) + eyeOffset,
				Color = Color3.fromRGB(255, 30, 0),
				Material = Enum.Material.Neon,
			})
			eye.Parent = folder

			local eyeGlow = Instance.new("PointLight")
			eyeGlow.Color = Color3.fromRGB(255, 30, 0)
			eyeGlow.Brightness = 2
			eyeGlow.Range = 6
			eyeGlow.Parent = eye
		end
	end

	-- EDGE FLAMES: fire-colored neon pillars along the platform edge
	for i = 0, 7 do
		local angle = math.rad(i * 45 + 22.5)
		local dist = 44
		local flamePos = Vector3.new(CX + math.cos(angle) * dist, 3, CZ + math.sin(angle) * dist)

		local flameBase = createPart({
			Name = "FlameBase_" .. i,
			Size = Vector3.new(2, 6, 2),
			Position = flamePos,
			Color = Color3.fromRGB(40, 30, 45),
			Material = Enum.Material.Basalt,
		})
		flameBase.Parent = folder

		-- Flame tip (neon)
		local flameTip = createPart({
			Name = "FlameTip_" .. i,
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(2.5, 3.5, 2.5),
			Position = flamePos + Vector3.new(0, 5, 0),
			Color = Color3.fromRGB(255, 100, 0),
			Material = Enum.Material.Neon,
		})
		flameTip.Parent = folder

		local flameLight = Instance.new("PointLight")
		flameLight.Color = Color3.fromRGB(255, 80, 0)
		flameLight.Brightness = 2.5
		flameLight.Range = 18
		flameLight.Parent = flameTip
	end

	-- BROKEN ROCK DEBRIS on the platform surface
	local debrisPositions = {
		Vector3.new(CX + 12, 0, CZ + 8),
		Vector3.new(CX - 15, 0, CZ - 10),
		Vector3.new(CX + 8, 0, CZ - 15),
		Vector3.new(CX - 10, 0, CZ + 12),
	}
	for _, dPos in ipairs(debrisPositions) do
		for j = 1, math.random(2, 4) do
			local debris = createPart({
				Name = "ShadowDebris",
				Size = Vector3.new(
					math.random() * 2 + 0.5,
					math.random() * 1 + 0.3,
					math.random() * 2 + 0.5
				),
				Position = dPos + Vector3.new(
					(math.random() - 0.5) * 5,
					math.random() * 0.5 + 0.3,
					(math.random() - 0.5) * 5
				),
				Color = Color3.fromRGB(
					30 + math.random(-5, 10),
					25 + math.random(-5, 10),
					35 + math.random(-5, 10)
				),
				Material = Enum.Material.Basalt,
				Rotation = Vector3.new(
					math.random() * 25,
					math.random() * 360,
					math.random() * 25
				),
			})
			debris.Parent = folder
		end
	end

	-- Arena spawn points (invisible)
	local spawnA = Instance.new("SpawnLocation")
	spawnA.Name = "ShadowSpawnA"
	spawnA.Anchored = true
	spawnA.Size = Vector3.new(6, 0.2, 6)
	spawnA.Position = Vector3.new(CX, 0.6, CZ - 20)
	spawnA.TopSurface = Enum.SurfaceType.Smooth
	spawnA.CanCollide = true
	spawnA.Enabled = false
	spawnA.Transparency = 1
	spawnA.Parent = folder

	local spawnB = Instance.new("SpawnLocation")
	spawnB.Name = "ShadowSpawnB"
	spawnB.Anchored = true
	spawnB.Size = Vector3.new(6, 0.2, 6)
	spawnB.Position = Vector3.new(CX, 0.6, CZ + 20)
	spawnB.TopSurface = Enum.SurfaceType.Smooth
	spawnB.CanCollide = true
	spawnB.Enabled = false
	spawnB.Transparency = 1
	spawnB.Parent = folder

	-- Invisible boundaries
	createInvisibleWall(folder, Vector3.new(CX, 20, CZ - 52), Vector3.new(110, 40, 2))
	createInvisibleWall(folder, Vector3.new(CX, 20, CZ + 52), Vector3.new(110, 40, 2))
	createInvisibleWall(folder, Vector3.new(CX - 52, 20, CZ), Vector3.new(2, 40, 110))
	createInvisibleWall(folder, Vector3.new(CX + 52, 20, CZ), Vector3.new(2, 40, 110))
	createInvisibleWall(folder, Vector3.new(CX, 55, CZ), Vector3.new(110, 2, 110)) -- ceiling

	return folder
end

--------------------------------------------------------------------------------
-- BUILD EVERYTHING
--------------------------------------------------------------------------------

setupEnvironment()

local lobby = buildLobby()
local arena = buildArena()
local shadowRealm = buildShadowRealm()

-- Store spawn positions as attributes for MatchManager (City Arena)
arena:SetAttribute("SpawnA_X", 200)
arena:SetAttribute("SpawnA_Y", 1)
arena:SetAttribute("SpawnA_Z", -20)
arena:SetAttribute("SpawnB_X", 200)
arena:SetAttribute("SpawnB_Y", 1)
arena:SetAttribute("SpawnB_Z", 20)
arena:SetAttribute("LobbySpawn_X", 0)
arena:SetAttribute("LobbySpawn_Y", 1)
arena:SetAttribute("LobbySpawn_Z", 0)

-- Store spawn positions for Shadow Realm
shadowRealm:SetAttribute("SpawnA_X", 400)
shadowRealm:SetAttribute("SpawnA_Y", 1)
shadowRealm:SetAttribute("SpawnA_Z", -20)
shadowRealm:SetAttribute("SpawnB_X", 400)
shadowRealm:SetAttribute("SpawnB_Y", 1)
shadowRealm:SetAttribute("SpawnB_Z", 20)

print("[ArenaBuilder] All arenas built!")
print("  Lobby plaza: (0, 1, 0)")
print("  City Arena: (200, 1, -20) / (200, 1, 20)")
print("  Shadow Realm: (400, 1, -20) / (400, 1, 20)")
