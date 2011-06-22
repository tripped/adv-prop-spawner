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


TOOL.Category		= "Construction"
TOOL.Name			= "#Advanced Prop Spawner"
TOOL.Command		= nil
TOOL.ConfigName		= ""

TOOL.ClientConVar = {
	delay		= 0,
	undo_delay	= 0,
	key			= -1,
	undo_key	= -1,
	rep_all		= 0,
	nocollide	= 1,
	usematerial	= 1,
	usevelocity	= 1
}

if CLIENT then
	language.Add( "Tool_adv_spawner_name", "Advanced Prop Spawner" )
	language.Add( "Tool_adv_spawner_desc", "Spawns entities or contraptions at the spawner's location" )
	language.Add( "Tool_adv_spawner_0", "Click an entity to make a spawner. Right-click an entity to make spawners for a whole contraption!" )
	language.Add( "Undone_gmod_adv_spawner", "Undone Advanced Prop Spawner" )
	language.Add( "Undone_adv_prop_spawn", "Undone advanced spawn" )
	language.Add( "Cleanup_gmod_adv_spawner", "Advanced Prop Spawners" )
	language.Add( "Cleaned_gmod_adv_spawner", "Cleaned up Advanced Prop Spawners" )
end

if SERVER then
	CreateConVar("sbox_maxadv_spawners",10)
end

cleanup.Register("gmod_adv_spawner")



/*-----------------------------------------------------------------------*
 * Gets a table containing tool options.
 *-----------------------------------------------------------------------*/
function TOOL:GetOptions()
	local options = { }
	options["delay"]			= self:GetClientNumber("delay", 0)
	options["undo_delay"]		= self:GetClientNumber("undo_delay", 0)
	options["key"]				= self:GetClientNumber("key", -1)
	options["undo_key"]			= self:GetClientNumber("undo_key", -1)
	options["rep_all"]			= self:GetClientNumber("rep_all", 0)
	options["nocollide"]		= self:GetClientNumber("nocollide", 1)
	options["usematerial"]		= self:GetClientNumber("usematerial", 0)
	options["usevelocity"]		= self:GetClientNumber("usevelocity", 0)
	return options
end



/*-----------------------------------------------------------------------*
 * Left-click handler.
 *
 * Turns the clicked entity into a spawner.
 *-----------------------------------------------------------------------*/
function TOOL:LeftClick(trace)

	local ent = trace.Entity
	if !ent or !ent:IsValid() then return false end
	if CLIENT then return true end

	// Player and tool options
	local pl = self:GetOwner()
	local options = self:GetOptions()

	// Make-a da spawner	
	local spawner = MakeSpawnerFromEnt( ent, pl, options )

	if( !spawner ) then return false end	
	if( spawner == ent ) then return true end
	
	spawner.OriginalId = ent:EntIndex()

	ent:Remove()

	undo.Create("gmod_adv_spawner")
		undo.AddEntity( spawner )
		undo.SetPlayer( pl )
	undo.Finish()

	return true
end



/*-----------------------------------------------------------------------*
 * Right-click handler.
 *
 * Creates a network of spawners for an entire contraption, starting
 * from the right-clicked entity.
 *-----------------------------------------------------------------------*/
function TOOL:RightClick( trace )

	local ClickedEnt = trace.Entity
	if (!ClickedEnt or !ClickedEnt:IsValid()) then return false end	
	if (CLIENT) then return true end

	//
	// Player and tool options
	//
	local pl = self:GetOwner()
	local options = self:GetOptions()
	
	//
	// If the user clicked an existing spawner, just update it and its neighbors
	//
	if(ClickedEnt:GetClass() == "gmod_adv_spawner") then
		UpdateSpawnerNetwork( ClickedEnt, options )
		return true
	end

	//
	// 1. Traverse constraints to build list of entities to turn into spawners	
	//
	local ent_list = { }
	local con_list = { }
	BuildEntityNetwork( ClickedEnt, /*out*/ ent_list, /*out*/ con_list )

	//
	// 2. Create a spawner for each entity, mapping each spawner to the
	//    index of the original entity
	//
	local index_to_ent = { }
	local index_to_con = { }
	for k,ent in pairs( ent_list ) do
		local NewSpawner = MakeSpawnerFromEnt( ent, pl, options )
		
		// Only the first spawner should have numpad bindings
		options["key"] = -1
		options["undo_key"] = -1
		
		// Set the original ID of the spawner (for ApplyDupeInfo mapping)
		NewSpawner.OriginalId = ent:EntIndex()
		
		index_to_ent[ ent:EntIndex() ] = NewSpawner
	end
	
	//
	// 3. Replicate the original constraints, and map each new constraint
	//    to the index of the original constraint
	//
	local GetEntSpawnedFrom = function( e )
			if (e == nil) then return nil end			
			local mapped = index_to_ent[ e:EntIndex() ]			
			if (!mapped) then mapped = e end
			return mapped
		end
	for k,con in pairs( con_list ) do
		local ConTable = con:GetTable()
		local MakeConstraint = AdvSpawner.Replicators[ConTable.Type]
		local NewConstraint
		
		if (MakeConstraint != nil) then
			NewConstraint = MakeConstraint( con, GetEntSpawnedFrom )
			
			// Set the original ID of the constraint (for ApplyDupeInfo mapping)
			NewConstraint.OriginalId = con:EntIndex()
			
			index_to_con[ con:EntIndex() ] = NewConstraint
		else
			AdvSpawner.NotifyError( pl, "Can't replicate constraint type " .. con.Type )
		end
	end

	//
	// 4. Remove all the original entities and constraints
	//
	for k,ent in pairs( ent_list ) do
		ent:Remove()
	end
	for k,con in pairs( con_list ) do
		con:Remove()
	end
	
	//
	// 5. Create undo entry
	//
	undo.Create("gmod_adv_spawner")
		for k,ent in pairs( index_to_ent ) do
			undo.AddEntity( ent )
		end
		for k,con in pairs( index_to_con ) do
			undo.AddEntity( con )
		end
		undo.SetPlayer( pl )
	undo.Finish()

	return true
end




if SERVER then

	/*-----------------------------------------------------------------------*
	 * Function: BuildEntityNetwork
	 *
	 * Builds lists of entities and constraints in a network, beginning
	 * with the specified entity.
	 *
	 * Parameters:
	 *   startEnt    The entity at which to begin
	 *   ent_list    (out) list to which to add all discovered entities
	 *   con_list    (out) list to which to add all discovered constraints
	 *-----------------------------------------------------------------------*/
	function BuildEntityNetwork( startEnt, ent_list, con_list )
	
		if table.HasValue( ent_list, startEnt ) then return end
		
		table.insert( ent_list, startEnt )
		
		if startEnt.Constraints == nil then return end
		
		for k,Constraint in pairs(startEnt.Constraints) do
			if (Constraint:IsValid() and !table.HasValue( con_list, Constraint )) then
				// Add the constraint to the list of things to duplicate
				table.insert( con_list, Constraint )
				
				// Recursively check other entities attached to the constraint
				local ConTable = Constraint:GetTable()
				if (ConTable.Type != "NoCollide") then
					for i = 1,6 do
						local EntI = ConTable["Ent" .. i]
						if (EntI != self and EntI != nil and EntI:GetClass() != "gmod_adv_spawner") then
							BuildEntityNetwork( EntI, ent_list, con_list )
						end
					end
				end
			elseif (!Constraint:IsValid()) then
				// Tidy up invalid constraints
				startEnt.Constraints[k] = nil
			end
		end
	end


	/*-----------------------------------------------------------------------*
	 * Function: UpdateSpawnerNetwork
	 *
	 * Updates the options for a pre-existing network of spawners.
	 *
	 * Parameters:
	 *   startEnt    The spawner in the network at which to begin updating
	 *   options     Table containing the options to set
	 *   updated     Table of spawners that have already been updated
	 *               (can be nil)
	 *-----------------------------------------------------------------------*/
	function UpdateSpawnerNetwork( startEnt, options, updated )

		if (!updated) then updated = { } end	
		if (!startEnt) then return end
		if (startEnt:GetClass() != "gmod_adv_spawner") then return end
		if (table.HasValue( updated, startEnt )) then return end
		
		startEnt:UpdateOptions( options )
		
		// Only the first spawner should have numpad bindings
		options["key"] = -1
		options["undo_key"] = -1
		
		table.insert( updated, startEnt )
		
		if (!startEnt.Constraints) then return end
		
		for k,Constraint in pairs(startEnt.Constraints) do
			if (Constraint:IsValid()) then
				local ConTable = Constraint:GetTable()
				if (ConTable.Type != "NoCollide") then				
					for i = 1,6 do
						local EntI = ConTable["Ent"..i]
						UpdateSpawnerNetwork( EntI, options, updated )
					end
				end
			end
		end
	end


	/*-----------------------------------------------------------------------*
	 * Function: MakeSpawnerFromEnt
	 *
	 * Creates a spawner for the specified entity.
	 *
	 * Parameters:
	 *   ent         The entity for which to create a spawner
	 *   pl          Player who will own the spawner
	 *   opts        Table of advanced spawner options:
	 *                 delay, undo_delay, rep_all, nocollide, etc.
	 *
	 * Remarks:
	 *   Does not remove the specified entity. Just updates options if
	 *   ent is already a spawner.
	 *-----------------------------------------------------------------------*/
	function MakeSpawnerFromEnt( ent, pl, opts )

		if (!ent or !ent:IsValid()) then return false end

		// TODO: just use the options table for everything instead
		// of unrolling it manually like this :P
		local delay = opts["delay"]
		local undo_delay = opts["undo_delay"]
		local key = opts["key"]
		local undo_key = opts["undo_key"]
		local rep_all = opts["rep_all"]
		local nocollide = opts["nocollide"]
		local usematerial = opts["usematerial"]
		local usevelocity = opts["usevelocity"]
		
		//
		// If ent is already a spawner, just update its options
		//
		if (ent:GetClass() == "gmod_adv_spawner") then
			if(ent:GetTable().pl != pl) then
				AdvSpawner.NotifyError( pl, "That spawner does not belong to you!" )
				return false
			end
			ent:UpdateOptions( opts )
			return ent
		end

		//
		// Info for creating the "ghost" of the spawner
		//
		local phys			= ent:GetPhysicsObject()
		if (!phys:IsValid()) then return false end

		local model 		= ent:GetModel()
		local frozen		= !phys:IsMoveable()
		local Pos			= ent:GetPos()
		local Ang			= ent:GetAngles()
		local mat			= ent:GetMaterial()
		local r,b,g,a		= ent:GetColor()

		// 
		// Get info needed to actually create duplicates of the spawner entity
		//
		local EntityClass = ent:GetClass()
		local DupeInfo
		local DupeTable = ent:GetTable()
		local DupeClass = duplicator.FindEntityClass( ent:GetClass() )

		if (DupeClass == nil) then
			AdvSpawner.NotifyError( pl, "Can't create spawner for " .. ent:GetClass() )
			return false
		end
		if (type(ent.BuildDupeInfo) == "function") then
			local ok, result
			ok,result = pcall(ent.BuildDupeInfo, ent)
			if (ok) then DupeInfo = result end
		end

		//
		// Create the advanced spawner entity
		//
		local adv_spawner = MakeAdvSpawner( pl, Pos, Ang, delay, undo_delay, model, mat, r, g, b, nil, nil, frozen,
									key, undo_key, rep_all, nocollide, usematerial, usevelocity )

		if (!adv_spawner or !adv_spawner:IsValid()) then
			AdvSpawner.NotifyError( pl, "Failed to create Advanced Prop Spawner!" )
			return false
		end

		adv_spawner:SetDupeInfo( EntityClass, DupeTable, DupeInfo )

		return adv_spawner
	end


	/*-----------------------------------------------------------------------*
	 * Function: MakeAdvSpawner
	 *
	 * Makes an advanced spawner with the specified properties.
	 *-----------------------------------------------------------------------*/
	function MakeAdvSpawner( pl, Pos, Ang, delay, undo_delay, model, mat, r, g, b, vel, avel, frozen,
		key, undo_key, rep_all, nocollide, usematerial, usevelocity )
	
		if !pl:CheckLimit("adv_spawners") then return nil end
		
		local spawner = ents.Create("gmod_adv_spawner")
			if !spawner:IsValid() then return end
			spawner:SetPos(Pos)
			spawner:SetAngles(Ang)
			spawner:SetModel(model)
			spawner:SetRenderMode(3)
			spawner:SetMaterial(mat or "")
			spawner:SetColor((r or 255),(g or 255),(b or 255),100)
		spawner:Spawn()

		if spawner:GetPhysicsObject():IsValid() then
			local Phys = spawner:GetPhysicsObject()
			Phys:EnableMotion(!frozen)
		end

		// In multiplayer we clamp the delay to help prevent people being idiots
		if !SinglePlayer() and delay < 0.2 then
			delay = 0.33
		end

		// Set options
		spawner:SetPlayer(pl)
		spawner:GetTable():SetOptions(delay, undo_delay, key, undo_key, rep_all, nocollide, usematerial, usevelocity )

		local tbl = {
			pl 			= pl,
			delay		= delay,
			undo_delay	= undo_delay;
			mat			= mat,
			r			= r,
			g			= g,
			b			= b
		}
		table.Merge(spawner:GetTable(), tbl)

		pl:AddCount("adv_spawners", spawner)
		pl:AddCleanup("gmod_adv_spawner", spawner)

		return spawner
	end

	duplicator.RegisterEntityClass("gmod_adv_spawner", MakeAdvSpawner, "Pos", "Ang", "delay", "undo_delay", "model", "mat", "r", "g", "b", "Vel", "aVel", "frozen",
			"key", "undo_key", "rep_all", "nocollide", "usematerial", "usevelocity")

end


/*-----------------------------------------------------------------------*
 * Builds the tool's control panel.
 *-----------------------------------------------------------------------*/
function TOOL.BuildCPanel( CPanel )

	local params = {
		Label = "#Presets",
		MenuButton = 1,
		Folder = "adv_spawner",
		Options = {
			default = {
				adv_spawner_delay			= 0,
				adv_spawner_undo_delay	= 0,
				adv_spawner_key			= -1,
				adv_spawner_undo_key		= -1,
				adv_spawner_rep_all		= 0,
				adv_spawner_nocollide		= 1,
				adv_spawner_usematerial	= 0,
				adv_spawner_usevelocity	= 0,
			}
		},
		CVars = {
			"adv_spawner_delay",
			"adv_spawner_undo_delay",
			"adv_spawner_key",
			"adv_spawner_undo_key",
			"adv_spawner_rep_all",
			"adv_spawner_nocollide",
			"adv_spawner_usematerial",
			"adv_spawner_usevelocity",
		}
	}
	CPanel:AddControl( "ComboBox", params )
	
	// Spawn/undo key selection
	params = { 
		Label		= "#Spawn Key",
		Label2		= "#Undo Key",
		Command		= "adv_spawner_key",
		Command2	= "adv_spawner_undo_key",
		ButtonSize	= "22",
	}
	CPanel:AddControl( "Numpad",  params )
	
	CPanel:AddControl( "Label", { Text = "Be sure that only one spawner in a network has numpad keys set! Right-clicking a spawner contraption will clear key bindings for all spawners except the one clicked." } )
	
	// Spawn delay
	local params = {
		Label	= "#Spawn Delay",
		Type	= "Float",
		Min		= "0",
		Max		= "100",
		Command	= "adv_spawner_delay",
	}
	CPanel:AddControl( "Slider",  params )

	// Automatic undo delay
	local params = {
		Label	= "#Automatic Undo Delay",
		Type	= "Float",
		Min		= "0",
		Max		= "100",
		Command	= "adv_spawner_undo_delay",
	}
	CPanel:AddControl( "Slider",  params )
	
	
	CPanel:AddControl( "Label", { Text = " " } )
	
	
	// All-constraint replication
	CPanel:AddControl( "Checkbox", {
			Label = "Replicate External Constraints",
			Command = "adv_spawner_rep_all", })
	--CPanel:AddControl( "Label", { Text = "If selected, a spawner that is constrained to some other object will spawn entities that are constrained to that same object." })
	
	// Automatic no-collide
	CPanel:AddControl( "Checkbox", { 
			Label = "No-collide Spawners With All But World",
			Command = "adv_spawner_nocollide", })
	--CPanel:AddControl( "Label", { Text = "If selected, spawners will be made non-solid. (Spawned props will still be solid)" })
	
	// Use spawner material
	CPanel:AddControl( "Checkbox", { 
			Label = "Use Spawner Material",
			Command = "adv_spawner_usematerial" })
	--CPanel:AddControl( "Label", { Text = "Spawned entities will have the same material as the spawner." })
	
	// Use spawner velocity
	CPanel:AddControl( "Checkbox", { 
			Label = "Use Spawner Velocity",
			Command = "adv_spawner_usevelocity" })
	--CPanel:AddControl( "Label", { Text = "Spawned entities will have the same initial velocity as their spawner." })
		
end
