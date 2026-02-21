--[[
	ArenaBuilder (Server)
	Generates the entire TSB-style world:
	  - Lobby area with character selection pedestals
	  - Open city arena for free-for-all combat
	  - Destroyed urban aesthetic with rubble and props
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CharacterData = require(Shared:WaitForChild("CharacterData"))

--------------------------------------------------------------------------------
-- HELPERS
--------------------------------------------------------------------------------

local function createPart(props)
	local part = Instance.new("Part")
	part.Name = props.Name or "Part"
	part.Size = props.Size or Vector3.new(4, 1, 4)
	part.Position = props.Position or Vector3.new(0, 0, 0)
	part.Anchored = true
	part.Material = props.Material or Enum.Material.Concrete
	part.Color = props.Color or Color3.fromRGB(180, 180, 180)
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if props.Transparency then part.Transparency = props.Transparency end
	if props.CanCollide ~= nil then part.CanCollide = props.CanCollide end
	if props.CFrame then part.CFrame = props.CFrame end
	part.Parent = props.Parent or workspace
	return part
end

local function createInvisibleWall(name, pos, size, parent)
	local wall = Instance.new("Part")
	wall.Name = name
	wall.Size = size
	wall.Position = pos
	wall.Anchored = true
	wall.Transparency = 1
	wall.CanCollide = true
	wall.Parent = parent or workspace
	return wall
end

local function addWindows(building, face, rows, cols)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.Parent = building

	local grid = Instance.new("Frame")
	grid.Size = UDim2.new(1, 0, 1, 0)
	grid.BackgroundTransparency = 1
	grid.Parent = gui

	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(1 / cols, -4, 1 / rows, -4)
	layout.CellPadding = UDim2.new(0, 3, 0, 3)
	layout.Parent = grid

	for i = 1, rows * cols do
		local window = Instance.new("Frame")
		window.BackgroundColor3 = Color3.fromRGB(
			140 + math.random(-20, 30),
			160 + math.random(-20, 30),
			190 + math.random(-20, 30)
		)
		window.BackgroundTransparency = math.random() * 0.3 + 0.1
		window.BorderSizePixel = 0
		window.Parent = grid
	end
end

local function createBuilding(name, pos, size, color, parent)
	local building = createPart({
		Name = name,
		Size = size,
		Position = pos + Vector3.new(0, size.Y / 2, 0),
		Material = Enum.Material.Concrete,
		Color = color or Color3.fromRGB(130 + math.random(-15, 15), 130 + math.random(-15, 15), 135 + math.random(-15, 15)),
		Parent = parent,
	})

	createPart({
		Name = name .. "_Roof",
		Size = Vector3.new(size.X + 1, 0.5, size.Z + 1),
		Position = pos + Vector3.new(0, size.Y + 0.25, 0),
		Material = Enum.Material.SmoothPlastic,
		Color = Color3.fromRGB(80, 80, 85),
		Parent = parent,
	})

	local rows = math.floor(size.Y / 5)
	local cols = math.floor(size.X / 5)
	if rows > 0 and cols > 0 then
		addWindows(building, Enum.NormalId.Front, rows, cols)
		addWindows(building, Enum.NormalId.Back, rows, cols)
	end
	local sideCols = math.floor(size.Z / 5)
	if rows > 0 and sideCols > 0 then
		addWindows(building, Enum.NormalId.Left, rows, sideCols)
		addWindows(building, Enum.NormalId.Right, rows, sideCols)
	end

	return building
end

local function createStreetLamp(pos, parent)
	createPart({
		Name = "LampPole", Size = Vector3.new(0.4, 12, 0.4),
		Position = pos + Vector3.new(0, 6, 0),
		Material = Enum.Material.Metal, Color = Color3.fromRGB(60, 60, 65), Parent = parent,
	})
	createPart({
		Name = "LampArm", Size = Vector3.new(0.3, 0.3, 3),
		Position = pos + Vector3.new(0, 12, 1.5),
		Material = Enum.Material.Metal, Color = Color3.fromRGB(60, 60, 65), Parent = parent,
	})
	local housing = createPart({
		Name = "LampHousing", Size = Vector3.new(1.2, 0.5, 1.2),
		Position = pos + Vector3.new(0, 11.8, 3),
		Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(50, 50, 55), Parent = parent,
	})
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 240, 210)
	light.Brightness = 1.2
	light.Range = 25
	light.Parent = housing
end

local function createRubble(pos, parent)
	for i = 1, math.random(3, 6) do
		local s = math.random() * 1.5 + 0.3
		createPart({
			Name = "Rubble", Size = Vector3.new(s, s * 0.6, s),
			Position = pos + Vector3.new((math.random() - 0.5) * 5, s * 0.3, (math.random() - 0.5) * 5),
			Material = Enum.Material.Slate,
			Color = Color3.fromRGB(100 + math.random(-15, 15), 95 + math.random(-15, 15), 90 + math.random(-15, 15)),
			Parent = parent,
		})
	end
end

local function createCar(pos, color, rotation, parent)
	local body = createPart({
		Name = "CarBody", Size = Vector3.new(5, 2, 10),
		CFrame = CFrame.new(pos + Vector3.new(0, 1, 0)) * CFrame.Angles(0, math.rad(rotation or 0), 0),
		Material = Enum.Material.SmoothPlastic, Color = color, Parent = parent,
	})
	createPart({
		Name = "CarCabin", Size = Vector3.new(4.5, 1.5, 5),
		CFrame = body.CFrame * CFrame.new(0, 1.5, -0.5),
		Material = Enum.Material.SmoothPlastic, Color = color, Parent = parent,
	})
	createPart({
		Name = "Windshield", Size = Vector3.new(4.2, 1.3, 0.2),
		CFrame = body.CFrame * CFrame.new(0, 1.2, -3) * CFrame.Angles(math.rad(15), 0, 0),
		Material = Enum.Material.Glass, Color = Color3.fromRGB(180, 210, 240),
		Transparency = 0.4, Parent = parent,
	})
	for _, offset in ipairs({
		Vector3.new(-2.2, -0.3, -3.5), Vector3.new(2.2, -0.3, -3.5),
		Vector3.new(-2.2, -0.3, 3.5), Vector3.new(2.2, -0.3, 3.5),
	}) do
		createPart({
			Name = "Wheel", Size = Vector3.new(0.6, 1.4, 1.4),
			CFrame = body.CFrame * CFrame.new(offset),
			Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(30, 30, 35), Parent = parent,
		})
	end
end

local function createBarrier(pos, rotation, parent)
	local barrier = createPart({
		Name = "Barrier", Size = Vector3.new(4, 2.5, 1.5),
		CFrame = CFrame.new(pos + Vector3.new(0, 1.25, 0)) * CFrame.Angles(0, math.rad(rotation or 0), 0),
		Material = Enum.Material.Concrete, Color = Color3.fromRGB(160, 160, 155), Parent = parent,
	})
	createPart({
		Name = "BarrierStripe", Size = Vector3.new(4.05, 0.4, 1.55),
		CFrame = barrier.CFrame * CFrame.new(0, 0.5, 0),
		Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(220, 180, 40), Parent = parent,
	})
end

local function createRoadLine(startPos, endPos, isDashed, parent)
	local dir = (endPos - startPos)
	local length = dir.Magnitude
	local unit = dir.Unit
	if isDashed then
		local dashLen, gapLen, pos = 3, 2, 0
		while pos < length do
			local segEnd = math.min(pos + dashLen, length)
			local segCenter = startPos + unit * ((pos + segEnd) / 2) + Vector3.new(0, 0.02, 0)
			createPart({
				Name = "RoadDash", Size = Vector3.new(0.3, 0.05, segEnd - pos),
				CFrame = CFrame.lookAt(segCenter, segCenter + unit),
				Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(230, 220, 60), Parent = parent,
			})
			pos = segEnd + gapLen
		end
	else
		local center = (startPos + endPos) / 2 + Vector3.new(0, 0.02, 0)
		createPart({
			Name = "RoadLine", Size = Vector3.new(0.3, 0.05, length),
			CFrame = CFrame.lookAt(center, center + unit),
			Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(230, 220, 60), Parent = parent,
		})
	end
end

--------------------------------------------------------------------------------
-- LIGHTING
--------------------------------------------------------------------------------

local function setupLighting()
	workspace.Terrain:Clear()

	Lighting.ClockTime = 14.5
	Lighting.Brightness = 2.5
	Lighting.Ambient = Color3.fromRGB(70, 70, 80)
	Lighting.OutdoorAmbient = Color3.fromRGB(100, 100, 110)
	Lighting.FogEnd = 2000
	Lighting.GlobalShadows = true

	local sky = Lighting:FindFirstChildOfClass("Sky") or Instance.new("Sky")
	sky.SunAngularSize = 15
	sky.MoonAngularSize = 10
	sky.Parent = Lighting

	local atmo = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmo.Density = 0.3
	atmo.Offset = 0.2
	atmo.Color = Color3.fromRGB(200, 210, 225)
	atmo.Decay = Color3.fromRGB(120, 130, 150)
	atmo.Glare = 0.1
	atmo.Haze = 1.5
	atmo.Parent = Lighting

	local bloom = Lighting:FindFirstChildOfClass("BloomEffect") or Instance.new("BloomEffect")
	bloom.Intensity = 0.25
	bloom.Size = 18
	bloom.Threshold = 1.5
	bloom.Parent = Lighting

	local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect") or Instance.new("ColorCorrectionEffect")
	cc.Saturation = -0.1
	cc.Contrast = 0.05
	cc.Brightness = 0.02
	cc.Parent = Lighting

	local rays = Lighting:FindFirstChildOfClass("SunRaysEffect") or Instance.new("SunRaysEffect")
	rays.Intensity = 0.04
	rays.Spread = 0.6
	rays.Parent = Lighting
end

--------------------------------------------------------------------------------
-- LOBBY
--------------------------------------------------------------------------------

local function buildLobby()
	local lobbyFolder = Instance.new("Folder")
	lobbyFolder.Name = "Lobby"
	lobbyFolder.Parent = workspace

	-- Ground
	createPart({
		Name = "LobbyGround", Size = Vector3.new(100, 1, 100),
		Position = Vector3.new(0, -0.5, 0),
		Material = Enum.Material.Concrete, Color = Color3.fromRGB(170, 165, 160), Parent = lobbyFolder,
	})

	-- Title wall
	local titleWall = createPart({
		Name = "TitleWall", Size = Vector3.new(40, 12, 2),
		Position = Vector3.new(0, 6, -45),
		Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(40, 40, 45), Parent = lobbyFolder,
	})

	local titleGui = Instance.new("SurfaceGui")
	titleGui.Face = Enum.NormalId.Front
	titleGui.Parent = titleWall

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, 0, 0.6, 0)
	titleLabel.Position = UDim2.new(0, 0, 0.1, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "THE STRONGEST\nBATTLEGROUNDS"
	titleLabel.TextColor3 = Color3.fromRGB(255, 80, 30)
	titleLabel.TextStrokeTransparency = 0
	titleLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	titleLabel.TextScaled = true
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.Parent = titleGui

	local subtitleLabel = Instance.new("TextLabel")
	subtitleLabel.Size = UDim2.new(1, 0, 0.25, 0)
	subtitleLabel.Position = UDim2.new(0, 0, 0.7, 0)
	subtitleLabel.BackgroundTransparency = 1
	subtitleLabel.Text = "SELECT YOUR FIGHTER"
	subtitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	subtitleLabel.TextStrokeTransparency = 0.5
	subtitleLabel.TextScaled = true
	subtitleLabel.Font = Enum.Font.Gotham
	subtitleLabel.Parent = titleGui

	-- Character selection pedestals
	local characters = CharacterData.GetAllCharacterNames()
	local spacing = 12
	local startX = -(#characters - 1) * spacing / 2

	for i, charKey in ipairs(characters) do
		local charInfo = CharacterData.GetCharacter(charKey)
		local xPos = startX + (i - 1) * spacing

		local pedestal = createPart({
			Name = "Pedestal_" .. charKey, Size = Vector3.new(6, 1, 6),
			Position = Vector3.new(xPos, 0.5, -25),
			Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(50, 50, 55), Parent = lobbyFolder,
		})

		createPart({
			Name = "AccentRing_" .. charKey, Size = Vector3.new(6.2, 0.2, 6.2),
			Position = Vector3.new(xPos, 1.1, -25),
			Material = Enum.Material.Neon, Color = charInfo.Colors.Primary, Parent = lobbyFolder,
		})

		createPart({
			Name = "CharModel_" .. charKey, Size = Vector3.new(2, 4.5, 1.5),
			Position = Vector3.new(xPos, 3.5, -25),
			Material = Enum.Material.SmoothPlastic, Color = charInfo.BodyColor, Parent = lobbyFolder,
		})

		local head = Instance.new("Part")
		head.Name = "CharHead_" .. charKey
		head.Shape = Enum.PartType.Ball
		head.Size = Vector3.new(1.8, 1.8, 1.8)
		head.Position = Vector3.new(xPos, 6.5, -25)
		head.Anchored = true
		head.Material = Enum.Material.SmoothPlastic
		head.Color = Color3.fromRGB(245, 205, 170)
		head.Parent = lobbyFolder

		local nameSign = createPart({
			Name = "NameSign_" .. charKey, Size = Vector3.new(5, 2, 0.3),
			Position = Vector3.new(xPos, 8.5, -25),
			Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(40, 40, 45), Parent = lobbyFolder,
		})

		local nameGui = Instance.new("SurfaceGui")
		nameGui.Face = Enum.NormalId.Front
		nameGui.Parent = nameSign

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(1, 0, 0.6, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = charInfo.DisplayName
		nameLabel.TextColor3 = charInfo.Colors.Primary
		nameLabel.TextStrokeTransparency = 0.3
		nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		nameLabel.TextScaled = true
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.Parent = nameGui

		local descLabel = Instance.new("TextLabel")
		descLabel.Size = UDim2.new(0.9, 0, 0.35, 0)
		descLabel.Position = UDim2.new(0.05, 0, 0.6, 0)
		descLabel.BackgroundTransparency = 1
		descLabel.Text = charInfo.Description
		descLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
		descLabel.TextStrokeTransparency = 0.5
		descLabel.TextScaled = true
		descLabel.Font = Enum.Font.Gotham
		descLabel.TextWrapped = true
		descLabel.Parent = nameGui

		local accentLight = Instance.new("PointLight")
		accentLight.Color = charInfo.Colors.Primary
		accentLight.Brightness = 1.5
		accentLight.Range = 12
		accentLight.Parent = pedestal

		pedestal:SetAttribute("CharacterKey", charKey)
	end

	-- Spawn
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.Position = Vector3.new(0, 0.5, 15)
	spawn.Anchored = true
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Color = Color3.fromRGB(100, 100, 105)
	spawn.Transparency = 0.5
	spawn.Parent = lobbyFolder

	-- Lobby buildings
	local lobbyBuildings = {
		{ pos = Vector3.new(-40, 0, -40), size = Vector3.new(18, 28, 15) },
		{ pos = Vector3.new(40, 0, -40), size = Vector3.new(16, 34, 14) },
		{ pos = Vector3.new(-45, 0, 10), size = Vector3.new(12, 22, 18) },
		{ pos = Vector3.new(45, 0, 10), size = Vector3.new(14, 26, 16) },
	}
	for i, b in ipairs(lobbyBuildings) do
		createBuilding("LobbyBuilding" .. i, b.pos, b.size, nil, lobbyFolder)
	end

	createStreetLamp(Vector3.new(-15, 0, -10), lobbyFolder)
	createStreetLamp(Vector3.new(15, 0, -10), lobbyFolder)
	createStreetLamp(Vector3.new(-15, 0, 30), lobbyFolder)
	createStreetLamp(Vector3.new(15, 0, 30), lobbyFolder)
end

--------------------------------------------------------------------------------
-- CITY ARENA
--------------------------------------------------------------------------------

local function buildCityArena()
	local arenaFolder = Instance.new("Folder")
	arenaFolder.Name = "CityArena"
	arenaFolder.Parent = workspace

	local O = Vector3.new(300, 0, 0) -- arena origin offset

	-- Ground
	createPart({
		Name = "ArenaGround", Size = Vector3.new(200, 1, 200),
		Position = O + Vector3.new(0, -0.5, 0),
		Material = Enum.Material.Concrete, Color = Color3.fromRGB(130, 128, 125), Parent = arenaFolder,
	})

	-- Roads
	createPart({
		Name = "MainRoad", Size = Vector3.new(20, 0.06, 200),
		Position = O + Vector3.new(0, 0.03, 0),
		Material = Enum.Material.Asphalt, Color = Color3.fromRGB(55, 55, 60), Parent = arenaFolder,
	})
	createPart({
		Name = "CrossRoad", Size = Vector3.new(200, 0.06, 20),
		Position = O + Vector3.new(0, 0.03, 0),
		Material = Enum.Material.Asphalt, Color = Color3.fromRGB(55, 55, 60), Parent = arenaFolder,
	})

	createRoadLine(O + Vector3.new(0, 0, -95), O + Vector3.new(0, 0, 95), true, arenaFolder)
	createRoadLine(O + Vector3.new(-95, 0, 0), O + Vector3.new(95, 0, 0), true, arenaFolder)

	-- Surrounding buildings
	local buildings = {
		{ pos = Vector3.new(-60, 0, -85), size = Vector3.new(25, 40, 20) },
		{ pos = Vector3.new(-20, 0, -85), size = Vector3.new(22, 32, 18) },
		{ pos = Vector3.new(25, 0, -85), size = Vector3.new(28, 44, 22) },
		{ pos = Vector3.new(65, 0, -85), size = Vector3.new(20, 28, 16) },
		{ pos = Vector3.new(-55, 0, 85), size = Vector3.new(24, 36, 18) },
		{ pos = Vector3.new(-15, 0, 85), size = Vector3.new(20, 30, 20) },
		{ pos = Vector3.new(30, 0, 85), size = Vector3.new(26, 38, 16) },
		{ pos = Vector3.new(70, 0, 85), size = Vector3.new(18, 24, 18) },
		{ pos = Vector3.new(85, 0, -45), size = Vector3.new(18, 34, 22) },
		{ pos = Vector3.new(85, 0, 5), size = Vector3.new(20, 42, 24) },
		{ pos = Vector3.new(85, 0, 50), size = Vector3.new(16, 26, 18) },
		{ pos = Vector3.new(-85, 0, -40), size = Vector3.new(20, 30, 20) },
		{ pos = Vector3.new(-85, 0, 15), size = Vector3.new(22, 38, 22) },
		{ pos = Vector3.new(-85, 0, 55), size = Vector3.new(18, 28, 16) },
	}
	for i, b in ipairs(buildings) do
		createBuilding("ArenaBuilding" .. i, O + b.pos, b.size, nil, arenaFolder)
	end

	-- Lamps
	for _, pos in ipairs({
		Vector3.new(-35, 0, -35), Vector3.new(35, 0, -35),
		Vector3.new(-35, 0, 35), Vector3.new(35, 0, 35),
		Vector3.new(-55, 0, 0), Vector3.new(55, 0, 0),
		Vector3.new(0, 0, -55), Vector3.new(0, 0, 55),
	}) do
		createStreetLamp(O + pos, arenaFolder)
	end

	-- Cars
	createCar(O + Vector3.new(-30, 0, -15), Color3.fromRGB(180, 50, 50), 15, arenaFolder)
	createCar(O + Vector3.new(25, 0, 20), Color3.fromRGB(50, 80, 180), -25, arenaFolder)
	createCar(O + Vector3.new(-40, 0, 30), Color3.fromRGB(60, 60, 65), 80, arenaFolder)
	createCar(O + Vector3.new(45, 0, -25), Color3.fromRGB(230, 220, 200), 45, arenaFolder)

	-- Barriers
	createBarrier(O + Vector3.new(-20, 0, 30), 0, arenaFolder)
	createBarrier(O + Vector3.new(15, 0, -20), 90, arenaFolder)
	createBarrier(O + Vector3.new(30, 0, 40), 45, arenaFolder)
	createBarrier(O + Vector3.new(-35, 0, -30), 120, arenaFolder)

	-- Rubble
	for _, pos in ipairs({
		Vector3.new(10, 0, 10), Vector3.new(-25, 0, -20), Vector3.new(40, 0, -10),
		Vector3.new(-10, 0, 35), Vector3.new(20, 0, -40), Vector3.new(-45, 0, 15),
	}) do
		createRubble(O + pos, arenaFolder)
	end

	-- Spawn points
	local spawnPoints = {
		O + Vector3.new(0, 3, 0),
		O + Vector3.new(30, 3, 30), O + Vector3.new(-30, 3, -30),
		O + Vector3.new(30, 3, -30), O + Vector3.new(-30, 3, 30),
		O + Vector3.new(50, 3, 0), O + Vector3.new(-50, 3, 0),
		O + Vector3.new(0, 3, 50), O + Vector3.new(0, 3, -50),
	}
	for i, pos in ipairs(spawnPoints) do
		arenaFolder:SetAttribute("Spawn" .. i, pos)
	end
	arenaFolder:SetAttribute("SpawnCount", #spawnPoints)

	-- Boundary walls
	local half = 101
	local h = 50
	createInvisibleWall("NorthWall", O + Vector3.new(0, h / 2, -half), Vector3.new(202, h, 2), arenaFolder)
	createInvisibleWall("SouthWall", O + Vector3.new(0, h / 2, half), Vector3.new(202, h, 2), arenaFolder)
	createInvisibleWall("EastWall", O + Vector3.new(half, h / 2, 0), Vector3.new(2, h, 202), arenaFolder)
	createInvisibleWall("WestWall", O + Vector3.new(-half, h / 2, 0), Vector3.new(2, h, 202), arenaFolder)
end

--------------------------------------------------------------------------------
-- BUILD
--------------------------------------------------------------------------------

setupLighting()
buildLobby()
buildCityArena()

print("[ArenaBuilder] World generated - Lobby + City Arena")
