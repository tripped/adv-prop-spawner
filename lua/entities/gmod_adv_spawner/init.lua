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


AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )

include('shared.lua')


function ENT:Initialize()

	self.Entity:SetMoveType( MOVETYPE_NONE )
	self.Entity:PhysicsInit( SOLID_VPHYSICS )
	self.Entity:SetCollisionGroup( COLLISION_GROUP_WEAPON )
	self.Entity:DrawShadow( false )

	local phys = self.Entity:GetPhysicsObject()
	if (phys:IsValid()) then phys:Wake() end
	
	self.UndoList = {}

	// Spawner is "edge-triggered"
	self.SpawnLastValue = 0
	self.UndoLastValue = 0

	// Made more efficient by updating the overlay text and
	// Wire output only when number of active props changes (TheApathetic)
	self.CurrentPropCount = 0

	// Add inputs/outputs (TheApathetic)
	if ( WireLib ) then
		self.Inputs = Wire_CreateInputs(self.Entity, {"Spawn", "Undo"})
		self.Outputs = WireLib.CreateSpecialOutputs(self.Entity, {"Out", "LastSpawned"}, { "NORMAL", "ENTITY" })
	end
end



/*-----------------------------------------------------------------------*
 * Sets options for this spawner
 *-----------------------------------------------------------------------*/
function ENT:SetOptions( delay, undo_delay, key, undo_key, rep_all, nocollide,
		usematerial, usevelocity )

	self.delay = delay
	self.undo_delay = undo_delay
	
	//
	// Key bindings
	//
	self.key = key
	self.undo_key = undo_key
	numpad.Remove( self.CreateKey )
	numpad.Remove( self.UndoKey )
	self.CreateKey 	= numpad.OnDown( self:GetPlayer(), self.key, "AdvSpawnerCreate", self.Entity, true )
	self.UndoKey 	= numpad.OnDown( self:GetPlayer(), self.undo_key, "AdvSpawnerUndo", self.Entity, true )
	
	self.rep_all = (rep_all and rep_all != 0)
	
	self.nocollide = (nocollide and nocollide != 0)
	
	if(self.nocollide) then
		self.Entity:SetCollisionGroup( COLLISION_GROUP_WORLD )
		self.Entity.CollisionGroup = COLLISION_GROUP_WORLD
	else
		self.Entity:SetCollisionGroup( COLLISION_GROUP_NONE )
		self.Entity.CollisionGroup = COLLISION_GROUP_NONE
	end
	
	self.usematerial = (usematerial and usematerial != 0)
	self.usevelocity = (usevelocity and usevelocity != 0)
	
	self:ShowOutput()
end

function ENT:UpdateOptions( options )
	self:SetOptions( options["delay"], options["undo_delay"],
					 options["key"], options["undo_key"],
					 options["rep_all"], options["nocollide"],
					 options["usematerial"], options["usevelocity"])
end


function ENT:GetCreationDelay()	return self.delay	end
function ENT:GetDeletionDelay()	return self.undo_delay	end

function ENT:OnTakeDamage( dmginfo )	self.Entity:TakePhysicsDamage( dmginfo ) end

function ENT:SetDupeInfo( EntityClass, DupeTable, DupeInfo )

	self.EntityClass = EntityClass
	self.DupeTable = DupeTable
	self.DupeInfo = DupeInfo

end



/*-----------------------------------------------------------------------*
 * Spawns the entire network of advanced spawners connected to this one,
 * replicating all constraints and connections between them.
 *-----------------------------------------------------------------------*/
function ENT:DoSpawn( pl, down )

	//
	// Traverse the network of spawners to build a list of spawners and constraints
	//
	local spawner_list = { }
	local con_list = { }
	self:BuildSpawnerNetwork( spawner_list, con_list )

	//
	// Build a map of original index data to newly spawned entities.
	// This is for when we ApplyDupeInfo() to the entities later.
	//
	local index_to_new_ent = { }
	local index_to_new_con = { }

	//
	// Spawn all props, indexing them in a table by the entity they came from.
	// This is so we know which props to attach our constraints to in the next step.
	//
	local SpawnedProps = { }
	local SpawnedNocollides = { }
	
	for k,Spawner in pairs(spawner_list) do
		SpawnedProps[Spawner] = Spawner:SpawnEntity(pl, down)
		index_to_new_ent[Spawner.OriginalId] = SpawnedProps[Spawner]
	end
	
	//
	// Now replicate all constraints
	//
	local SpawnedConstraints = { }
	
	for k,Constraint in pairs(con_list) do
		local ConTable = Constraint:GetTable()
		
		// Get the appropriate replicator for this type of constraint
		local MakeConstraint = AdvSpawner.Replicators[ConTable.Type]
		
		if MakeConstraint != nil then
		
			local GetEntSpawnedFrom = function( ent )
					local mapped = SpawnedProps[ent]
					// If the entity isn't mapped, assume that it's external to the
					// contraption and just connect to it directly
					if (!mapped) then mapped = ent end
					return mapped
				end

			local NewConstraint = MakeConstraint( ConTable, GetEntSpawnedFrom )
			
			if (Constraint.OriginalId) then
				index_to_new_con[Constraint.OriginalId] = NewConstraint
			end
						
			// Be sure we clean up the constraints when any of attached prop is removed
			for i = 1,6 do
				local EntI = NewConstraint:GetTable()["Ent" .. i]
				if EntI != nil and EntI:IsValid() then
					EntI:DeleteOnRemove( NewConstraint )
				end
			end
			
			table.insert( SpawnedConstraints, NewConstraint )

		else
			AdvSpawner.NotifyError( pl, "No function for replicating " .. ConTable.Type .. " constraints") 			
		end
	end
	
	
	//
	// Add nocollides between the spawners and their props
	// NOTE: if we add these _before_ replicating the constraints,
	//       gmod crashes. Why?
	//
	for spawner, spawned in pairs(SpawnedProps) do
		if !(spawner.nocollide) then
			local nocollide = constraint.NoCollide( spawner, spawned, 0, 0 )
			if (nocollide:IsValid()) then
				table.insert( SpawnedNocollides, nocollide )
				spawned:DeleteOnRemove( nocollide )
			end
		end
	end
	

	//
	// Now that all the spawned entities and constraints exist, we apply
	// stored dupe info to all the entities.
	//
	local GetEntById = function( id )
			if (index_to_new_ent[id] == nil) then return ents.GetByIndex(id) end
			return index_to_new_ent[id]
		end
	local GetConstById = function( id )
			return index_to_new_con[id]
		end
	for k,ent in pairs(SpawnedProps) do
		if (ent.StoredDupeInfo) then
			ent:ApplyDupeInfo( pl, ent, ent.StoredDupeInfo, GetEntById, GetConstById )
		end
	end
	
	//
	// Create 'Undo' entry
	//
	local my_undo = { }
	undo.Create("adv_prop_spawn")
		for k,prop in pairs(SpawnedProps) do
			undo.AddEntity( prop )
			table.insert( my_undo, prop )
		end
		for k,con in pairs(SpawnedConstraints) do
			undo.AddEntity( con )
			table.insert( my_undo, con )
		end
		for k,nocollide in pairs(SpawnedNocollides) do
			undo.AddEntity( nocollide )
			table.insert( my_undo, nocollide )
		end
		undo.SetPlayer( pl )
	undo.Finish()
	table.insert( self.UndoList, 1, my_undo )

	
	// Optional auto-undo
	local undo_delay = self:GetDeletionDelay()
	if (undo_delay == 0) then return end
	timer.Simple( undo_delay, function() self:DoUndo( pl, false ) end )
end



/*-----------------------------------------------------------------------*
 * Function: SpawnEntity
 *
 * Spawns a copy of the entity represented by this spawner.
 *
 * Parameters:
 *   pl          The player who will own the spawned entity
 *
 *-----------------------------------------------------------------------*/
function ENT:SpawnEntity( pl )

	local EntityClass = self.EntityClass
	local DupeClass = self.DupeClass
	local DupeTable = self.DupeTable
	local DupeInfo = self.DupeInfo
	
	DupeClass = duplicator.FindEntityClass(EntityClass)
	
	//
	// Get appropriate model, position, velocity, etc. and add them to
	// the dupe entity table. This is similar to what is done in
	// AdvDupe.GetSaveableEntity.
	//
	local phys = self:GetPhysicsObject()
	if (!phys or !phys:IsValid()) then return nil end
	DupeTable.Model = self:GetModel()
	DupeTable.Pos = self:GetPos()
	DupeTable.Ang = self:GetAngles()
	DupeTable.Vel = phys:GetVelocity()
	DupeTable.aVel = phys:GetAngleVelocity()
	DupeTable.frozen = !phys:IsMoveable()

	//
	// Next build the argument list that will be passed to DupeClass.Func
	//
	local Args = { }
	for index,key in pairs(DupeClass.Args) do
		if(key == "Data") then
			Args[index] = DupeTable // this is kinda weird
		elseif(key == "PhysicsObjects") then
			Args[index] = { phys }
		else
			Args[index] = DupeTable[key]
		end

		if(Args[index] == nil) then
			Args[index] = false
		end
	end

	//
	// Call duplication function
	//
	local ent = DupeClass.Func(pl, unpack(Args))

	if (!ent || !ent:IsValid()) then return nil end

	// Set the ent's dupeinfo so we can use it later
	if (DupeInfo != nil) then
		ent.StoredDupeInfo = DupeInfo
	end
	
	ent:SetPos( DupeTable.Pos )

	if (self.usematerial) then
		ent:SetMaterial( self:GetMaterial() )
	end
	
	if (self.usevelocity) then
		local ent_phys = ent:GetPhysicsObject()
		if (!ent_phys or !ent_phys:IsValid()) then return ent end
		ent_phys:SetVelocity( DupeTable.Vel )
		ent_phys:AddAngleVelocity( DupeTable.aVel )
	end

	return ent
end




/*-----------------------------------------------------------------------*
 * Traverses the network of advanced spawners beginning with 'self' and
 * builds lists of the spawners and constraints making up the network.
 *
 * Parameters:
 *   spawner_list    (out) list to which to add discovered spawners
 *   con_list        (out) list to which to add discovered constraints
 *
 *-----------------------------------------------------------------------*/
function ENT:BuildSpawnerNetwork( spawner_list, con_list )

	if table.HasValue( spawner_list, self ) then return	end
	
	table.insert( spawner_list, self )
	
	if self.Constraints == nil then return end

	// Check all constraints
	for k,Constraint in pairs(self.Constraints)
	do	
		if (Constraint:IsValid() and !table.HasValue( con_list, Constraint )) then
			local ConTable = Constraint:GetTable()
			local NonSpawnerConstraint = false

			for i = 1,6 do
				local EntI = ConTable["Ent" .. i]
				if (EntI != nil and EntI != self) then
					if (EntI:GetClass() == "gmod_adv_spawner") then
						EntI:BuildSpawnerNetwork( spawner_list, con_list )
					else
						NonSpawnerConstraint = true
					end
				end
			end

			if		(!table.HasValue( con_list, Constraint ))
				and	(!NonSpawnerConstraint or self.rep_all)
				and	(!Constraint:GetVar("NoReplicate"))
			then
				table.insert( con_list, Constraint )
			end

		elseif (!Constraint:IsValid()) then
			// Tidy up invalid constraints
			self.Constraints[k] = nil
		end
	end	
end




/*-----------------------------------------------------------------------*
 * Builds dupe information for the advanced duplicator.
 *-----------------------------------------------------------------------*/
function ENT:BuildDupeInfo()
	local info = self.BaseClass.BuildDupeInfo(self) or {}
	
	info.EntityClass = self.EntityClass
	info.DupeInfo = self.DupeInfo
	info.DupeTable = self.DupeTable
	info.OriginalId = self.OriginalId
	
	return info
end

/*-----------------------------------------------------------------------*
 * Applies dupe information.
 *-----------------------------------------------------------------------*/
function ENT:ApplyDupeInfo(pl, ent, info, GetEntByID, GetConstByID)
	self.BaseClass.ApplyDupeInfo(self, pl, ent, info, GetEntByID, GetConstByID)

	self.EntityClass = info.EntityClass
	self.DupeInfo = info.DupeInfo
	self.DupeTable = info.DupeTable
	self.OriginalId = info.OriginalId
end

/*-----------------------------------------------------------------------*
 * Stuff below here is mostly just yoinked from the wired prop spawner :3
 *-----------------------------------------------------------------------*/

function ENT:DoUndo( pl, message )

	if (!self.UndoList || #self.UndoList == 0) then return end

	local ents = self.UndoList[	#self.UndoList ]
	self.UndoList[	#self.UndoList ] = nil

	if (!ents) then
		return self:DoUndo(pl)
	end
	
	for k,ent in pairs(ents) do
		ent:Remove()
	end
	
	if ( message ) then
		umsg.Start( "UndoAdvSpawnerProp", pl ) umsg.End()
	end
end

function ENT:Think()
	self.BaseClass.Think(self)

	// Purge list of no longer existing props
	for i = #self.UndoList,1,-1 do
		local ents = self.UndoList[i]
		
		local baleeted = true
		for k,ent in pairs(ents) do
			if(ent && ent:IsValid()) then baleeted = false end
		end
		
		if (baleeted) then
			table.remove( self.UndoList, i )
		end
	end

	// Check to see if active prop count has changed
	if (#self.UndoList != self.CurrentPropCount) then
		self.CurrentPropCount = #self.UndoList
		
		if (WireLib) then
			Wire_TriggerOutput(self.Entity, "Out", self.CurrentPropCount)
		end
		self:ShowOutput()
	end

	self.Entity:NextThink(CurTime() + 0.1)
	return true
end

function ENT:TriggerInput(iname, value)
	local pl = self:GetPlayer()

	if (iname == "Spawn") then
		// Spawner is "edge-triggered" (TheApathetic)
		if ((value > 0) == self.SpawnLastValue) then return end
		self.SpawnLastValue = (value > 0)

		if (self.SpawnLastValue) then
			// Simple copy/paste of old numpad Spawn with a few modifications
			local delay = self:GetCreationDelay()
			if (delay == 0) then self:DoSpawn( pl ) return end

			local TimedSpawn = 	function ( ent, pl )
				if (!ent) then return end
				if (!ent == NULL) then return end
				ent:GetTable():DoSpawn( pl )
			end

			timer.Simple( delay, TimedSpawn, self.Entity, pl )
		end
	elseif (iname == "Undo") then
		// Same here
		if ((value > 0) == self.UndoLastValue) then return end
		self.UndoLastValue = (value > 0)

		if (self.UndoLastValue) then self:DoUndo(pl) end
	end
end

function ENT:ShowOutput()
	self:SetOverlayText(
		"Spawn Delay: " .. tostring(self:GetCreationDelay()) ..
		"\nUndo Delay: ".. tostring(self:GetDeletionDelay()) ..
		"\nUse external constraints: " .. tostring(self.rep_all) ..
		"\nUse material: " .. tostring(self.usematerial) ..
		"\nUse velocity: " .. tostring(self.usevelocity) ..
		"\nActive Props: "..tostring(self.CurrentPropCount) )
end


/*-----------------------------------------------------------------------*
 * Handler for spawn keypad input
 *-----------------------------------------------------------------------*/
function SpawnAdvSpawner( pl, ent )
	if (!ent || !ent:IsValid()) then return end

	delay = ent:GetTable():GetCreationDelay()
	
	if(delay == 0) then ent:DoSpawn( pl ) return end
	
	timer.Simple( delay, function() ent:DoSpawn( pl ) end)
end

/*-----------------------------------------------------------------------*
 * Handler for undo keypad input
 *-----------------------------------------------------------------------*/
function UndoAdvSpawner( pl, ent )
	if (!ent || !ent:IsValid()) then return end
	
	ent:DoUndo( pl, true )
end

numpad.Register( "AdvSpawnerCreate",	SpawnAdvSpawner )
numpad.Register( "AdvSpawnerUndo",		UndoAdvSpawner  )