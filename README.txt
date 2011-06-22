Advanced Prop Spawner v1.0
Mr. Accident (mraccident@gmail.com)


HOW TO INSTALL
==============

  1. Extract contents of ZIP file (or move the "advanced spawner" folder) to
      <Steam Install>\steamapps\<Username>\garrysmod\garrysmod\addons

  2. There is no step 2.



HOW TO USE
==========

Using the advanced prop spawner is simple: just click an entity to turn it into a spawner. Right-click an entity to turn it and all connected entities into spawners, along with all their constraints. You can use the right-click feature to make contraption spawners.

You can spawn the entity or contraption by pressing the selected "Spawn Key." Alternately, if you are using WireMod, you can trigger the "Spawn" input. (If you make a set of spawners for a contraption, you only have to wire up one of them -- when any spawner in a network is triggered, it spawns the entire network.)


Advanced spawners are flexible! Networks of spawners can be modified after being created -- simply add or remove constraints as desired.



TOOL OPTIONS
============

- Spawn Key
  The numpad key that will spawn the entity or contraption.

  NOTE: In any connected set of spawners, only one of them should have a spawn key set.
  Any one spawner will spawn the entire contraption, so triggering more than one at once
  will result in multiple simultaneous spawns. If your contraption spawner has this problem,
  just right-click one of the spawners -- it will update the whole network, ensuring that
  only the right-clicked spawner has key bindings!


- Undo Key
  The numpad key that will "undo" the least recently spawned entity or contraption.


- Spawn Delay
  The time in seconds that the spawner will wait after being triggered to actually do the spawn.


- Undo Delay
  The time in seconds after which the spawner will automatically undo each entity or contraption
  it spawns. If this is set to zero, no automatic undo will be performed.


- Replicate External Constraints
  If this is selected, the spawner will replicate all of its constraints, not just the ones
  that attach it to other spawners. For example, if you make an advanced prop spawner and
  rope it to a physics prop, with this option selected it will spawn entities that are also
  roped to that same physics prop.


- No-collide Spawners With All But World
  If this is selected, the spawners will be made non-solid. (The entities they spawn will
  still be solid.) This is recommended for any contraptions with more than just a few parts.


- Use Spawner Material
  If this is selected, spawned entities will use the same material that is set for the spawner.


- Use Spawner Velocity
  If this is selected, spawned entities will initially have the same velocity as the spawner.
  Otherwise, they will start with zero velocity, regardless of how fast the spawner is moving.




KNOWN BUGS/LIMITATIONS
======================

- Wired physics constraints (Wire Winch, Wire Hydraulic, etc.) can't be spawned at the moment.
  This should be fixed in a future release.

