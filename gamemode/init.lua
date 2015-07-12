AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )
AddCSLuaFile( "player_ext_shd.lua")
AddCSLuaFile( "player_class/player_hiding.lua")
AddCSLuaFile( "player_class/player_seeker.lua")
AddCSLuaFile( "sh_animations.lua")
AddCSLuaFile( "cl_hud.lua" )
include( "shared.lua" )
include( "player.lua" )

util.AddNetworkString("CleanUp")
--TODO add convars
GM.MaxWalkers = 25
GM.RoundTime = 0
GM.MaxRounds = 100
GM.MinHiding = 1
GM.MinSeeking = 1

function GM:InitPostEntity()
	self.SpawnPoints = ents.FindByClass( "info_player_start" )
	self.SpawnPoints = table.Add( self.SpawnPoints, ents.FindByClass( "info_player_deathmatch" ) )
	self.SpawnPoints = table.Add( self.SpawnPoints, ents.FindByClass( "info_player_combine" ) )
	self.SpawnPoints = table.Add( self.SpawnPoints, ents.FindByClass( "info_player_rebel" ) )
	
	-- CS Maps
	self.SpawnPoints = table.Add( self.SpawnPoints, ents.FindByClass( "info_player_counterterrorist" ) )
	self.SpawnPoints = table.Add( self.SpawnPoints, ents.FindByClass( "info_player_terrorist" ) )
	
	-- DOD Maps
	self.SpawnPoints = table.Add( self.SpawnPoints, ents.FindByClass( "info_player_axis" ) )
	self.SpawnPoints = table.Add( self.SpawnPoints, ents.FindByClass( "info_player_allies" ) )

	-- (Old) GMod Maps
	self.SpawnPoints = table.Add( self.SpawnPoints, ents.FindByClass( "gmod_player_start" ) )
	
	-- TF Maps
	self.SpawnPoints = table.Add( self.SpawnPoints, ents.FindByClass( "info_player_teamspawn" ) )
	
	-- INS Maps
	self.SpawnPoints = table.Add( self.SpawnPoints, ents.FindByClass( "ins_spawnpoint" ) )

	-- AOC Maps
	self.SpawnPoints = table.Add( self.SpawnPoints, ents.FindByClass( "aoc_spawnpoint" ) )

	-- Dystopia Maps
	self.SpawnPoints = table.Add( self.SpawnPoints, ents.FindByClass( "dys_spawn_point" ) )

	-- PVKII Maps
	self.SpawnPoints = table.Add( self.SpawnPoints, ents.FindByClass( "info_player_pirate" ) )
	self.SpawnPoints = table.Add( self.SpawnPoints, ents.FindByClass( "info_player_viking" ) )
	self.SpawnPoints = table.Add( self.SpawnPoints, ents.FindByClass( "info_player_knight" ) )

	-- DIPRIP Maps
	self.SpawnPoints = table.Add( self.SpawnPoints, ents.FindByClass( "diprip_start_team_blue" ) )
	self.SpawnPoints = table.Add( self.SpawnPoints, ents.FindByClass( "diprip_start_team_red" ) )

	-- OB Maps
	self.SpawnPoints = table.Add( self.SpawnPoints, ents.FindByClass( "info_player_red" ) )
	self.SpawnPoints = table.Add( self.SpawnPoints, ents.FindByClass( "info_player_blue" ) )

	-- SYN Maps
	self.SpawnPoints = table.Add( self.SpawnPoints, ents.FindByClass( "info_player_coop" ) )

	-- ZPS Maps
	self.SpawnPoints = table.Add( self.SpawnPoints, ents.FindByClass( "info_player_human" ) )
	self.SpawnPoints = table.Add( self.SpawnPoints, ents.FindByClass( "info_player_zombie" ) )

	-- ZM Maps
	self.SpawnPoints = table.Add( self.SpawnPoints, ents.FindByClass( "info_player_deathmatch" ) )
	self.SpawnPoints = table.Add( self.SpawnPoints, ents.FindByClass( "info_player_zombiemaster" ) )

	self.WalkerCount = 0

	local rand = math.random
	local n = #self.SpawnPoints

	while n > 2 do

		local k = rand(n) -- 1 <= k <= n

		self.SpawnPoints[n], self.SpawnPoints[k] = self.SpawnPoints[k], self.SpawnPoints[n]
		n = n - 1
 	end

 	self:PreGame()
end

function GM:PreGame()
	timer.Simple( 30, function() self:PreRoundStart() end)
	SetGlobalFloat("EndTime", CurTime() + 30 )
	SetGlobalString("RoundState", PRE_GAME)
end


function GM:PreRoundStart()
	--do not start round without players or at least one player in each team
	if team.NumPlayers( TEAM_HIDING ) < self.MinHiding or team.NumPlayers( TEAM_SEEKING ) < self.MinSeeking then
		--check again after half a second second
		timer.Simple(0.5, function() self:PreRoundStart() end)
		--clear remaning npcs to save recources
		for k,v in pairs(ents.FindByClass("npc_walker")) do
    		v:Remove()
		end
		SetGlobalFloat("EndTime", CurTime() + 1 )
		SetGlobalString("RoundState", WAITING)
		return
	end

	SetGlobalString("RoundState", CREATING)

	for k,v in pairs(ents.FindByClass("npc_walker")) do
    	v:Remove()
	end

	self.WalkerCount = 0
	for k,v in pairs(self.SpawnPoints) do
		if self.WalkerCount == self.MaxWalkers then break end
		local walker = ents.Create("npc_walker")
		if !IsValid( walker ) then break end
		walker:SetPos( v:GetPos() )
		walker:Spawn()
		walker:Activate()
		self.WalkerCount = self.WalkerCount + 1
	end

	timer.Simple(5, function()
		SetGlobalString("RoundState", PRE_ROUND)
		for k,v in pairs(team.GetPlayers( TEAM_HIDING )) do
			v:Spawn()
		end
		for k,v in pairs(team.GetPlayers( TEAM_SEEKING )) do
			v:Spawn()
			v:Freeze( true )
		end
	end) 
	timer.Simple(45, function() self:RoundStart() end )
	SetGlobalFloat("EndTime", CurTime() + 45 )
end

function GM:RoundStart()
	for k,v in pairs(team.GetPlayers( TEAM_SEEKING )) do
		v:Freeze( false )
	end
	timer.Create( "RoundThink", 1, 300, function() self:RoundThink() end)
	self.RoundTime = 1
	SetGlobalFloat("EndTime", CurTime() + 300 )
	SetGlobalInt( GetGlobalInt("RoundNumber", 0) + 1)
	SetGlobalString("RoundState", IN_ROUND)
end

--will be called every second
function GM:RoundThink()
	--end conditions
	self.RoundTime = self.RoundTime + 1

	if self.RoundTime == 300 then self:RoundEnd( false ) end

	if team.NumPlayers( TEAM_HIDING ) < self.MinHiding or team.NumPlayers( TEAM_SEEKING ) < self.MinSeeking then
		self:RoundEnd()
	end

	local seekersWin = true
	for k,v in pairs(team.GetPlayers( TEAM_HIDING )) do
		if v:Alive() then seekersWin = false end
	end

	local hidingWin = true
	for k,v in pairs(team.GetPlayers( TEAM_SEEKING )) do
		if v:Alive() then hidingWin = false end
	end

	if seekersWin then
		self:RoundEnd(true)
	end

	if hidingWin then
		self:RoundEnd(false)
	end
end

function GM:RoundEnd( caught )
	if timer.Exists("RoundThink") then timer.Destroy("RoundThink") end
	--choose winner and stuff

	if caught then
		PrintMessage( HUD_PRINTCENTER, "The Hunters won." )
	else
		PrintMessage( HUD_PRINTCENTER, "The Citiziens won." )
	end
	self:PostRound()
end

function GM:PostRound()
	net.Start("CleanUp")
	net.Broadcast()
	timer.Simple( 5, function() self:PreRoundStart() end)
	SetGlobalFloat("EndTime", CurTime() + 5 )
	SetGlobalString("RoundState", POST_ROUND)

	if GetGlobalInt("RoundNumber", 0) == self.MaxRounds then
		game.LoadNextMap()
	end
	--teamswap
	for k,v in pairs(player.GetAll()) do
		if v:Team() == TEAM_SEEKING then
			v:SetTeam(TEAM_HIDING)
		elseif v:Team() == TEAM_HIDING then
			v:SetTeam(TEAM_SEEKING)
		end
		v:KillSilent()
	end
end

