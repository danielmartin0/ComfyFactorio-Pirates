local Math = require 'maps.pirates.math'
local Memory = require 'maps.pirates.memory'
local Common = require 'maps.pirates.common'
local event = require 'utils.event'

local Public = {}

local turret_levels={
	{"gun-turret","firearm-magazine"}, -- no spawners
	{"gun-turret","firearm-magazine"}, -- only biter spawners
	{"gun-turret","firearm-magazine"}, -- biter/spitter spawners
	{"gun-turret","firearm-magazine"},
	{"small-worm-turret"},
	{"gun-turret","piercing-rounds-magazine"},
	{"medium-worm-turret"},
	{"gun-turret","uranium-rounds-magazine"},
	{"big-worm-turret"},
	{"behemoth-worm-turret"}
}

function Public.create_fortress(center_x,center_y,wall_distance_step,layers,level)
	if (wall_distance_step or 0) < 5 then wall_distance_step = 5 end
	if (layers or 0) < 1 then layers=1 end
	if (level or 0) < 1 then level=1 end
	if level > #turret_levels then level=turret_levels end

	local memory = Memory.get_crew_memory()
	local enemy_force_name = memory.enemy_force_name
	local destination = Common.current_destination()
	local surface = game.surfaces[destination.surface_name]
	local max_wall_distance=wall_distance_step*layers
	local lawn_mower=7 -- spawner size + walls
	local doorway=2
	local turrets={}
	local i, x,	y, item, wall_distance
	
	local area=surface.find_entities({{center_x-max_wall_distance-lawn_mower,center_y-max_wall_distance-lawn_mower},{center_x+max_wall_distance+lawn_mower,center_y+max_wall_distance+lawn_mower}})
	for i=1,#area
	do
		area[i].destroy()
	end

	local tiles={}
	for x=-max_wall_distance,max_wall_distance
	do
		for y=-max_wall_distance,max_wall_distance
		do
			tiles[#tiles+1]={position={center_x+x,center_y+y},name="refined-concrete"}
		end
	end	
	
	surface.set_tiles(tiles, true, true)	

	destination.dynamic_data.rings=destination.dynamic_data.rings or {}
	local rings=destination.dynamic_data.rings
	
	for wall_distance=wall_distance_step,max_wall_distance,wall_distance_step
	do
		local ring_turrets={}
		local ring_walls={}
	
		for i=-wall_distance+1,wall_distance-1
		do
			-- is math.abs() unnecessary slow here?
			if i>=-doorway and i<=doorway
			then
				item="gate"
			else
				item="stone-wall"
			end
			ring_walls[#ring_walls+1]=surface.create_entity{name = item, force=enemy_force_name, position = {center_x+i,center_y-wall_distance-1}, direction = defines.direction.west}
			ring_walls[#ring_walls+1]=surface.create_entity{name = item, force=enemy_force_name, position = {center_x+i,center_y-wall_distance}, direction = defines.direction.west} 
			ring_walls[#ring_walls+1]=surface.create_entity{name = item, force=enemy_force_name, position = {center_x+i,center_y+wall_distance+1}, direction = defines.direction.west}
			ring_walls[#ring_walls+1]=surface.create_entity{name = item, force=enemy_force_name, position = {center_x+i,center_y+wall_distance}, direction = defines.direction.west}
		end		

		for i=-wall_distance+1,wall_distance-1
		do
			if i>=-doorway and i<=doorway
			then
				item="gate"
			else
				item="stone-wall"
			end
		
			ring_walls[#ring_walls+1]=surface.create_entity{name = item, force=enemy_force_name, position = {center_x-wall_distance-1,center_y+i}} 
			ring_walls[#ring_walls+1]=surface.create_entity{name = item, force=enemy_force_name, position = {center_x-wall_distance,center_y+i}} 
			ring_walls[#ring_walls+1]=surface.create_entity{name = item, force=enemy_force_name, position = {center_x+wall_distance+1,center_y+i}}
			ring_walls[#ring_walls+1]=surface.create_entity{name = item, force=enemy_force_name, position = {center_x+wall_distance,center_y+i}}
		end

		ring_turrets[1] = create_turret(surface,turret_levels[level][1],enemy_force_name,center_x+wall_distance+1,center_y+wall_distance+1)
		ring_turrets[2] = create_turret(surface,turret_levels[level][1],enemy_force_name,center_x+wall_distance+1,center_y-wall_distance)
		ring_turrets[3] = create_turret(surface,turret_levels[level][1],enemy_force_name,center_x-wall_distance  ,center_y+wall_distance+1)
		ring_turrets[4] = create_turret(surface,turret_levels[level][1],enemy_force_name,center_x-wall_distance  ,center_y-wall_distance)
		
		
		for i=1,#ring_turrets
		do
			turrets[#turrets+1] = ring_turrets[i]
		end
		
		if level > 1
		then 
			surface.create_entity {name = 'biter-spawner', force=enemy_force_name, position = {center_x-wall_distance-4,center_y+Math.random(-wall_distance+4,wall_distance-5)}}
			surface.create_entity {name = 'biter-spawner', force=enemy_force_name, position = {center_x+wall_distance+5,center_y+Math.random(-wall_distance+4,wall_distance-5)}}
		end
		if level > 2
		then
			surface.create_entity {name = 'spitter-spawner', force=enemy_force_name, position = {center_x+Math.random(-wall_distance+4,wall_distance-5),center_y-wall_distance-4}}
			surface.create_entity {name = 'spitter-spawner', force=enemy_force_name, position = {center_x+Math.random(-wall_distance+4,wall_distance-5),center_y+wall_distance+5}}
		end
		
		rings[#rings+1]={
			ring_turrets=ring_turrets,
			ring_walls=ring_walls
		}
	end
		
	if turret_levels[level][2] 
	then
		for i=1,#turrets
		do
			turrets[i].insert({name=turret_levels[level][2], count=200})
		end
	end
end

event.add(defines.events.on_entity_damaged,function (event)
	local destination = Common.current_destination()
	local memory = Memory.get_crew_memory()
	local enemy_force_name = memory.enemy_force_name
	local rings=destination.dynamic_data.rings 
	local i,j
	local stay_open=60*3
	
	if _DEBUG and rings == nil then
		game.print("No rings")
	end
	
	if rings == nil then return end
	
--	game.print("--------")
--	game.print("rings "..#rings)
--	game.print(event.entity.valid)
--	if event.entity.valid then
--		game.print(event.entity.unit_number)
--	end
	
	
	for j=1,#rings
	do
		local ring_turrets=rings[j].ring_turrets
		local ring_walls=rings[j].ring_walls
		local found=false
		for i=1,#ring_turrets
		do
			--game.print(j.." "..i..": "..((ring_turrets[i].valid and "true") or "false"))
			--if ring_turrets[i].valid then
			--	game.print(ring_turrets[i].unit_number .. " - " .. (((ring_turrets[i].valid and ring_turrets[i] == event.entity) and "true") or "false"))
			--end

			if ring_turrets[i].valid and event.entity == ring_turrets[i]
			then
				found=true
				break
			end
		end
		
		--game.print(found)
		if found then 
			for i=1,#ring_walls
			do
				if ring_walls[i].valid and ring_walls[i].name == "gate" then ring_walls[i].request_to_open(enemy_force_name,stay_open) end
			end
		end
	end
end)


function create_turret(surface,entity_name,enemy_force_name,x,y)
	local turret=surface.create_entity{name = entity_name, force=enemy_force_name, position = {x,y}}
	
	for i=-2,1
	do
		surface.create_entity{name = "stone-wall", force=enemy_force_name, position = {x+i,y-2}}
		surface.create_entity{name = "stone-wall", force=enemy_force_name, position = {x+i,y+1}}
	end
		
	for i=-1,0
	do
		surface.create_entity{name = "stone-wall", force=enemy_force_name, position = {x-2,y+i}}
		surface.create_entity{name = "stone-wall", force=enemy_force_name, position = {x+1,y+i}}
	end
	
	return turret
end

return Public