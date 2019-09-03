# PersistantBlueprints

Adds a prototype area where blueprints can be constructed in areas of
different sizes. A persistant blueprint can be placed in each
area, making it the master for that area. Clicking the controller
returns the player to the real world with a blueprint of the area in
hand. The blueprint can then be placed anywhere on the map in the
usual fashion and will contain a persistant blueprint, a slave,
connected to the master.

Now what makes persistant blueprint special is that the player can
return to the prototype area and modify it. Any changes made to the
prototype are also done by every connected slave.

Note: The slaves do not instantly change the entities nor is the
change free. The player has to actually do the changes of have
construction robots do them. Only ghosts and decosntruction plans are
placed by the persistant blueprint slaves.

# Quality of Live features

+ "PB Editor" in the left top corner allows quick switching between
the real world and prototype area. The position the player left from
is preserved.
+ Clicking a persistant blueprint slave teleports the player to the
connected master. No need to search for the right blueprint to modify.

# ToDo

+ placing a persistant blueprint master where one already exists moves
the master but not the slaves to match
+ placing a persitant blueprint slave (either an old persistant
blueprint or by blueprinting it directly) should sync to the prototype
area once
+ pasting the configuration of a persistant blueprint should sync to
the sources prototype area once
+ place landfill over water where necessary
+ support waterfill
+ handle cliffs
+ give alerts when a persistant blueprint save can't place entities
