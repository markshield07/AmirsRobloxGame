--[[
	ArenaBuilder (Server)
	Generates the 1v1 arena and lobby area programmatically.
	Run once on server start. Replace with hand-built models later if desired.

	Layout:
	  - Lobby platform at Y=5, centered at origin
	  - Arena platform at Y=5, offset to one side
	  - Two arena spawn points
	  - Spectator ring around arena
	  - Invisible walls to keep players in bounds
]]

local Workspace = game:GetService("Workspace")

--------------------------------------------------------------------------------
-- HELPERS
--------------------------------------------------------------------------------

local function createPart(properties)
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth

	for key, value in pairs(properties) do
		part[key] = value
	end

	part.Parent = Workspace
	return part
end

local function createSpawnLocation(name, position, parent)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = name
	spawn.Anchored = true
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = position
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.BottomSurface = Enum.SurfaceType.Smooth
	spawn.CanCollide = true
	spawn.Enabled = false -- don't auto-spawn here
	spawn.Transparency = 0.5
	spawn.Parent = parent or Workspace
	return spawn
end

local function createInvisibleWall(position, size)
	local wall = Instance.new("Part")
	wall.Name = "ArenaWall"
	wall.Anchored = true
	wall.Transparency = 1
	wall.CanCollide = true
	wall.Size = size
	wall.Position = position
	wall.Parent = Workspace
	return wall
end

--------------------------------------------------------------------------------
-- BUILD LOBBY
--------------------------------------------------------------------------------

local function buildLobby()
	local lobbyFolder = Instance.new("Folder")
	lobbyFolder.Name = "Lobby"
	lobbyFolder.Parent = Workspace

	-- Main lobby platform
	local lobbyFloor = createPart({
		Name = "LobbyFloor",
		Size = Vector3.new(80, 2, 80),
		Position = Vector3.new(0, 4, 0),
		Color = Color3.fromRGB(100, 110, 120),
		Material = Enum.Material.SmoothPlastic,
	})
	lobbyFloor.Parent = lobbyFolder

	-- Lobby spawn point (where players spawn when joining or returning from match)
	local lobbySpawn = Instance.new("SpawnLocation")
	lobbySpawn.Name = "LobbySpawn"
	lobbySpawn.Anchored = true
	lobbySpawn.Size = Vector3.new(8, 1, 8)
	lobbySpawn.Position = Vector3.new(0, 5.5, 0)
	lobbySpawn.TopSurface = Enum.SurfaceType.Smooth
	lobbySpawn.CanCollide = true
	lobbySpawn.Enabled = true -- this IS the default spawn
	lobbySpawn.Transparency = 0.5
	lobbySpawn.Color = Color3.fromRGB(80, 180, 80)
	lobbySpawn.Parent = lobbyFolder

	-- Decorative pillars at corners
	local pillarPositions = {
		Vector3.new(-35, 15, -35),
		Vector3.new(35, 15, -35),
		Vector3.new(-35, 15, 35),
		Vector3.new(35, 15, 35),
	}
	local pillarColors = {
		Color3.fromRGB(255, 80, 20),   -- Fire red
		Color3.fromRGB(30, 144, 255),  -- Water blue
		Color3.fromRGB(255, 230, 50),  -- Lightning yellow
		Color3.fromRGB(100, 50, 160),  -- Shadow purple
	}

	for i, pos in ipairs(pillarPositions) do
		local pillar = createPart({
			Name = "ElementPillar_" .. i,
			Size = Vector3.new(4, 20, 4),
			Position = pos,
			Color = pillarColors[i],
			Material = Enum.Material.Neon,
		})
		pillar.Parent = lobbyFolder
	end

	-- Title sign
	local sign = Instance.new("Part")
	sign.Name = "TitleSign"
	sign.Anchored = true
	sign.Size = Vector3.new(30, 8, 1)
	sign.Position = Vector3.new(0, 18, -38)
	sign.Color = Color3.fromRGB(30, 30, 40)
	sign.Material = Enum.Material.SmoothPlastic
	sign.Parent = lobbyFolder

	local signGui = Instance.new("SurfaceGui")
	signGui.Face = Enum.NormalId.Front
	signGui.Parent = sign

	local signText = Instance.new("TextLabel")
	signText.Size = UDim2.new(1, 0, 1, 0)
	signText.BackgroundTransparency = 1
	signText.Text = "ELEMENTAL NINJA DUELS"
	signText.TextColor3 = Color3.fromRGB(255, 215, 0)
	signText.TextScaled = true
	signText.Font = Enum.Font.GothamBold
	signText.Parent = signGui

	return lobbyFolder
end

--------------------------------------------------------------------------------
-- BUILD ARENA
--------------------------------------------------------------------------------

local function buildArena()
	local arenaFolder = Instance.new("Folder")
	arenaFolder.Name = "Arena"
	arenaFolder.Parent = Workspace

	-- Arena platform (circular feel using octagonal parts)
	local arenaFloor = createPart({
		Name = "ArenaFloor",
		Size = Vector3.new(60, 2, 60),
		Position = Vector3.new(200, 4, 0), -- offset from lobby
		Color = Color3.fromRGB(50, 55, 65),
		Material = Enum.Material.SmoothPlastic,
	})
	arenaFloor.Parent = arenaFolder

	-- Arena border ring
	local borderThickness = 2
	local arenaSize = 60
	local borderHeight = 3
	local borderY = 6.5

	-- Four border walls
	local borders = {
		{ pos = Vector3.new(200, borderY, -(arenaSize/2)), size = Vector3.new(arenaSize, borderHeight, borderThickness) },
		{ pos = Vector3.new(200, borderY, (arenaSize/2)), size = Vector3.new(arenaSize, borderHeight, borderThickness) },
		{ pos = Vector3.new(200 - (arenaSize/2), borderY, 0), size = Vector3.new(borderThickness, borderHeight, arenaSize) },
		{ pos = Vector3.new(200 + (arenaSize/2), borderY, 0), size = Vector3.new(borderThickness, borderHeight, arenaSize) },
	}

	for i, b in ipairs(borders) do
		local wall = createPart({
			Name = "ArenaBorder_" .. i,
			Size = b.size,
			Position = b.pos,
			Color = Color3.fromRGB(80, 80, 100),
			Material = Enum.Material.Neon,
			Transparency = 0.7,
		})
		wall.Parent = arenaFolder
	end

	-- Arena spawn points
	local spawnA = createSpawnLocation("ArenaSpawnA", Vector3.new(200, 5.5, -20), arenaFolder)
	spawnA.Color = Color3.fromRGB(100, 150, 255)

	local spawnB = createSpawnLocation("ArenaSpawnB", Vector3.new(200, 5.5, 20), arenaFolder)
	spawnB.Color = Color3.fromRGB(255, 100, 100)

	-- Center line marker
	local centerLine = createPart({
		Name = "CenterLine",
		Size = Vector3.new(50, 0.2, 0.5),
		Position = Vector3.new(200, 5.1, 0),
		Color = Color3.fromRGB(255, 215, 0),
		Material = Enum.Material.Neon,
	})
	centerLine.Parent = arenaFolder

	-- Invisible ceiling to prevent escape
	createInvisibleWall(Vector3.new(200, 40, 0), Vector3.new(70, 1, 70))

	return arenaFolder
end

--------------------------------------------------------------------------------
-- BUILD EVERYTHING
--------------------------------------------------------------------------------

local lobby = buildLobby()
local arena = buildArena()

-- Update MatchManager spawn positions to match our arena
-- The MatchManager reads these directly from workspace
-- Store spawn positions as attributes on the arena folder for easy access
arena:SetAttribute("SpawnA_X", 200)
arena:SetAttribute("SpawnA_Y", 10)
arena:SetAttribute("SpawnA_Z", -20)
arena:SetAttribute("SpawnB_X", 200)
arena:SetAttribute("SpawnB_Y", 10)
arena:SetAttribute("SpawnB_Z", 20)
arena:SetAttribute("LobbySpawn_X", 0)
arena:SetAttribute("LobbySpawn_Y", 10)
arena:SetAttribute("LobbySpawn_Z", 0)

print("[ArenaBuilder] Lobby and Arena built successfully!")
print("  Lobby: (0, 5, 0)")
print("  Arena Spawn A: (200, 10, -20)")
print("  Arena Spawn B: (200, 10, 20)")
