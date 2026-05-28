--[[
	DodgingNpc — a patrolling NPC that dodges incoming projectiles.

	Drop this script into an NPC model under workspace. The model must contain:
		- Humanoid             (with an Animator child)
		- HumanoidRootPart
		- Animations/Run       (Animation)
		- Animations/Idle      (Animation)

	The workspace must contain:
		- waypoints/           (Folder of BaseParts named "1", "2", "3", ...
		                       — visited in order, looping back to "1")
		- Projectiles/         (Folder; any BasePart inside is treated as a
		                       projectile the NPC may need to dodge)

	The NPC patrols the waypoints, idling briefly at each, and triggers a Jump
	when an unseen projectile gets within DODGE_DISTANCE studs.
--]]

local PathfindingService = game:GetService("PathfindingService")

-- NPC references
local npc = script.Parent
local humanoid = npc:FindFirstChildOfClass("Humanoid")
local hrp = npc:FindFirstChild("HumanoidRootPart")
local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
local animationFolder = npc:FindFirstChild("Animations")

assert(humanoid, "DodgingNpc: NPC is missing a Humanoid")
assert(hrp, "DodgingNpc: NPC is missing a HumanoidRootPart")
assert(animator, "DodgingNpc: Humanoid is missing an Animator")
assert(animationFolder, "DodgingNpc: NPC is missing an Animations folder")

-- Workspace references
local waypointFolder = workspace:WaitForChild("waypoints")
local projectileFolder = workspace:WaitForChild("Projectiles")

-- Tunables
local WAYPOINT_REACH_OFFSET = 6   -- distance at which we consider a waypoint reached
local IDLE_DURATION = 2           -- seconds spent idling at each waypoint
local DODGE_DISTANCE = 20         -- projectile proximity that triggers a dodge

-- Loaded animations
local runAnimation = animator:LoadAnimation(animationFolder.Run)
local idleAnimation = animator:LoadAnimation(animationFolder.Idle)

-- Pathfinding setup
local path = PathfindingService:CreatePath({
	AgentRadius = 6,
	AgentHeight = 10,
	AgentCanJump = false,
	WaypointSpacing = 20,
})

-- Mutable state
local state = "spawn"
local currentPoint = nil
local nextPoint = nil
local idleTimer = nil
local dodgeObject = nil
local ignoreProjectiles = {} -- projectiles we've already dodged

local function moveTowards(targetPart)
	local ok, errorMessage = pcall(function()
		path:ComputeAsync(hrp.Position, targetPart.Position)
	end)
	if not ok then
		warn("DodgingNpc: pathfinding failed", npc.Name, targetPart.Name, errorMessage)
		return
	end

	local waypoints = path:GetWaypoints()
	if #waypoints < 2 then
		return
	end

	if not runAnimation.IsPlaying then
		runAnimation:Play()
	end

	-- Waypoint 1 is the current position; move toward waypoint 2.
	humanoid:MoveTo(waypoints[2].Position)
end

local function scanForIncomingProjectile()
	for _, projectile in ipairs(projectileFolder:GetChildren()) do
		if projectile:IsA("BasePart") and not table.find(ignoreProjectiles, projectile) then
			if (hrp.Position - projectile.Position).Magnitude <= DODGE_DISTANCE then
				return projectile
			end
		end
	end
	return nil
end

local function nextWaypointAfter(currentWaypoint)
	local nextIndex = tonumber(currentWaypoint.Name) + 1
	if nextIndex > #waypointFolder:GetChildren() then
		nextIndex = 1
	end
	return waypointFolder:FindFirstChild(tostring(nextIndex))
end

while task.wait() do
	-- Dodge has the highest priority: a projectile entering our radius forces
	-- us into the dodge state on the next iteration.
	local incoming = scanForIncomingProjectile()
	if incoming then
		dodgeObject = incoming
		state = "dodge"
	end

	if state == "patrol" then
		if nextPoint then
			moveTowards(nextPoint)
			if (hrp.Position - nextPoint.Position).Magnitude <= WAYPOINT_REACH_OFFSET then
				currentPoint = nextPoint
				nextPoint = nil
				runAnimation:Stop()
				idleTimer = tick() + IDLE_DURATION
				idleAnimation:Play()
				state = "idle"
			end
		elseif currentPoint then
			nextPoint = nextWaypointAfter(currentPoint)
		else
			-- Lost the current waypoint somehow; bail back to the first one.
			state = "spawn"
		end

	elseif state == "idle" then
		if idleTimer and tick() >= idleTimer then
			idleAnimation:Stop()
			state = "patrol"
		end

	elseif state == "dodge" then
		table.insert(ignoreProjectiles, dodgeObject)
		dodgeObject = nil
		humanoid.Jump = true
		state = "patrol"

	else
		-- "spawn" or any unexpected state: head to waypoint "1" and start patrolling.
		nextPoint = waypointFolder:FindFirstChild("1")
		state = "patrol"
	end
end
