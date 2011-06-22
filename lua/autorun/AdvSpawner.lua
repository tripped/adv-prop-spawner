/*-----------------------------------------------------------------------*
 * Advanced Prop Spawner
 * By Mr. Accident
 * mraccident@gmail.com
 *
 * Based on the standard wire prop spawner, but has the ability
 * to spawn any entity that has a registered duplication function.
 * Also spawns networks of attached spawners, allowing entire
 * contraptions to be spawned with constraints (and thrusters, and
 * wire gates, and so on) intact!
 *
 *-----------------------------------------------------------------------*/
 
 
 AdvSpawner = { }
  
 
/*-----------------------------------------------------------------------*
 * Function: AdvSpawner.NotifyError
 *
 * Displays a message notifying the specified player of an error.
 * Also plays a "bzzt!" sound. :3
 *-----------------------------------------------------------------------*/
function AdvSpawner.NotifyError( pl, msg )
	pl:SendLua(
		"GAMEMODE:AddNotify(\"" .. msg .. "\", NOTIFY_ERROR, 7);" ..
		"surface.PlaySound(\"buttons/button10.wav\")" )
end




/*-----------------------------------------------------------------------*
 * AdvSpawner.Replicators
 *
 * A table of functions, indexed by constraint type string, for
 * replicating different types of constraints.
 *
 * Each function takes two parameters:
 *    con                  The constraint entity to replicate
 *    GetEntSpawnedFrom    A function that maps con's attached entities to
 *                         the entities that the new constraint should use
 *
 * Each function returns the replicated constraint.
 *
 *-----------------------------------------------------------------------*/

AdvSpawner.Replicators = { }

AdvSpawner.Replicators["AdvBallsocket"] =
	function( con, GetEntSpawnedFrom )
		return constraint.AdvBallsocket(
			GetEntSpawnedFrom(con.Ent1), GetEntSpawnedFrom(con.Ent2),
			con.Bone1, con.Bone2, con.LPos1, con.LPos2, con.forcelimit, con.torquelimit,
			con.xmin, con.ymin, con.zmin, con.xmax, con.ymax, con.zmax,
			con.xfric, con.yfric, con.zfric, con.onlyrotation, con.nocollide )
	end

AdvSpawner.Replicators["Axis"] =
	function( con, GetEntSpawnedFrom )
		return constraint.Axis(
			GetEntSpawnedFrom(con.Ent1), GetEntSpawnedFrom(con.Ent2),
			con.Bone1, con.Bone2, con.LPos1, con.LPos2, con.forcelimit, con.torquelimit,
			con.friction, con.nocollide )
	end
	
AdvSpawner.Replicators["Ballsocket"] =
	function( con, GetEntSpawnedFrom )
		return constraint.Ballsocket(
			GetEntSpawnedFrom(con.Ent1), GetEntSpawnedFrom(con.Ent2),
			con.Bone1, con.Bone2, con.LPos, con.forcelimit, con.torquelimit, con.nocollide )
	end
	
AdvSpawner.Replicators["Elastic"] =
	function( con, GetEntSpawnedFrom )
		return constraint.Elastic(
			GetEntSpawnedFrom(con.Ent1), GetEntSpawnedFrom(con.Ent2),
			con.Bone1, con.Bone2, con.LPos1, con.LPos2, con.constant, con.damping,
			con.rdamping, con.material, con.width, con.stretchonly )
	end
	
AdvSpawner.Replicators["Hydraulic"] =
	function( con, GetEntSpawnedFrom )
		return constraint.Hydraulic(
			con.pl, GetEntSpawnedFrom(con.Ent1), GetEntSpawnedFrom(con.Ent2),
			con.Bone1, con.Bone2, con.LPos1, con.LPos2, con.Length1, con.Length2, con.width,
			con.key, con.fixed, con.fwd_speed ) -- only one speed is specified, but hydros have
												-- fwd_speed and bwd_speed fields
	end
	
AdvSpawner.Replicators["Keepupright"] =
	function( con, GetEntSpawnedFrom )
		return constraint.Keepupright(
			GetEntSpawnedFrom(con.Ent), con.Ang, con.Bone, con.angularlimit )
	end
	
AdvSpawner.Replicators["Motor"] =
	function( con, GetEntSpawnedFrom )
		return constraint.Motor(
			GetEntSpawnedFrom(con.Ent1), GetEntSpawnedFrom(con.Ent2),
			con.Bone1, con.Bone2, con.LPos1, con.LPos2, con.friction, con.torque, con.forcetime,
			con.nocollide, con.toggle, con.pl, con.forcelimit, con.numpadkey_fwd, con.numpadkey_bwd )
	end
	
AdvSpawner.Replicators["Muscle"] =
	function( con, GetEntSpawnedFrom )
		return constraint.Muscle(
			con.pl, GetEntSpawnedFrom(con.Ent1), GetEntSpawnedFrom(con.Ent2),
			con.Bone1, con.Bone2, con.LPos1, con.LPos2, con.Length1, con.Length2, con.width,
			con.key, con.fixed, con.period, con.amplitude )
	end
	
AdvSpawner.Replicators["NoCollide"] =
	function( con, GetEntSpawnedFrom )
		return constraint.NoCollide(
			GetEntSpawnedFrom(con.Ent1), GetEntSpawnedFrom(con.Ent2), con.Bone1, con.Bone2 )
	end
	
AdvSpawner.Replicators["Pulley"] =
	function( con, GetEntSpawnedFrom )
		return constraint.Pulley(
			GetEntSpawnedFrom(con.Ent1), GetEntSpawnedFrom(con.Ent4),
			con.Bone1, con.Bone4, con.LPos1, con.LPos4, con.WPos2, con.WPos3,
			con.forcelimit, con.rigid, con.width, con.material )
	end
	
AdvSpawner.Replicators["Rope"] =
	function( con, GetEntSpawnedFrom )
		return constraint.Rope( GetEntSpawnedFrom(con.Ent1), GetEntSpawnedFrom(con.Ent2),
			con.Bone1, con.Bone2, con.LPos1, con.LPos2, con.length, con.addlength,
			con.forcelimit, con.width, con.material, con.rigid )
	end
	
AdvSpawner.Replicators["Slider"] =
	function( con, GetEntSpawnedFrom )
		return constraint.Slider(
			GetEntSpawnedFrom(con.Ent1), GetEntSpawnedFrom(con.Ent2),
			con.Bone1, con.Bone2, con.LPos1, con.LPos2, con.width )
	end
	
AdvSpawner.Replicators["Weld"] =
	function( con, GetEntSpawnedFrom )
		return constraint.Weld(
			GetEntSpawnedFrom(con.Ent1), GetEntSpawnedFrom(con.Ent2),
			con.Bone1, con.Bone2, con.LPos1, con.LPos2, con.forcelimit, con.nocollide_until_break)
	end	
	
AdvSpawner.Replicators["Winch"] =
	function( con, GetEntSpawnedFrom )
		return constraint.Winch(
			con.pl, GetEntSpawnedFrom(con.Ent1), GetEntSpawnedFrom(con.Ent2),
			con.Bone1, con.Bone2, con.LPos1, con.LPos2, con.width, con.fwd_bind, con.bwd_bind,
			con.fwd_speed, con.bwd_speed, con.material, con.toggle )
	end

/* This doesn't work quite yet.

AdvSpawner.Replicators["WireWinch"] =
	function( con, GetEntSpawnedFrom )
		con.fwd_bind = -1	-- these aren't used anyway, so we can mess with 'em
		con.bwd_bind = -1
		local wirewinch = AdvSpawner.Replicators["Winch"]( con, GetEntSpawnedFrom )
		wirewinch.Type = "WireWinch"
		return wirewinch
	end
*/	
	

/*-----------------------------------------------------------------------*
 * Function: AdvSpawner.GetNetworkRepresentative
 *
 * Gets a single, unique "representative" element from the spawner
 * network that contains the specified spawner entity.
 *-----------------------------------------------------------------------*/
 
function AdvSpawner.GetNetworkRepresentative( ent )

	Log( "GetNetworkRepresentative: " .. tostring(ent) )

	local spawners = { }
	ent:GetTable():BuildSpawnerNetwork( spawners, { } )
	
	// We'll arbitrarily say that the representative element is the one
	// with the smallest index.
	local rep = nil
	
	for k,spawner in pairs(spawners) do
	
		Log( "Comparing: " .. tostring(rep) .. " and " .. tostring(spawner) )
		
		local rep_index = !rep or rep:EntIndex()
		local cur_index = spawner.Entity:EntIndex()
	
		if (!rep or (cur_index < rep_index) ) then
			rep = spawner.Entity
		end
	end
	
	return rep
end