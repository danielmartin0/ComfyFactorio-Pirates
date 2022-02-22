
local ores = require "maps.pirates.ores"

local Memory = require 'maps.pirates.memory'
local Math = require 'maps.pirates.math'
local Balance = require 'maps.pirates.balance'
local Structures = require 'maps.pirates.structures.structures'
local Common = require 'maps.pirates.common'
local Utils = require 'maps.pirates.utils_local'
local inspect = require 'utils.inspect'.inspect
local Ores = require 'maps.pirates.ores'
local IslandsCommon = require 'maps.pirates.surfaces.islands.common'
local Hunt = require 'maps.pirates.surfaces.islands.hunt'
local Fortress = require 'maps.pirates.structures.island_structures.fortress.fortress'


local Public = {}
Public.Data = require 'maps.pirates.surfaces.islands.fortress.data'

local prizes={
	{"power-armor",1},
	{"steel-plate",100*50},
	{"plastic-bar",100*50},
	{"defender-capsule",50},
	{"distractor-capsule",20},
	{"advanced-circuit",100},
	{"processing-unit",20},
	{"personal-laser-defense-equipment",1},
	{"modular-armor",5},
	{"artillery-shell",5},
	{"solar-panel-equipment",10},
	{"fusion-reactor-equipment",1},
	{"battery",100},
}

function Public.noises(args)
	local ret = {}

	ret.height = IslandsCommon.island_height_1(args)
	ret.forest = args.noise_generator.forest
	ret.forest_abs = function (p) return Math.abs(ret.forest(p)) end
	ret.forest_abs_suppressed = function (p) return ret.forest_abs(p) - 1 * Math.slopefromto(ret.height(p), 0.35, 0.1) end
	ret.rock = args.noise_generator.rock
	ret.rock_abs = function (p) return Math.abs(ret.rock(p)) end
	ret.farness = IslandsCommon.island_farness_1(args)
	return ret
end


function Public.terrain(args)
	local noises = Public.noises(args)
	local p = args.p

	
	if IslandsCommon.place_water_tile(args) then return end

	if noises.height(p) < 0 then
		args.tiles[#args.tiles + 1] = {name = 'water', position = args.p}
		return
	end
	
	if p.x == -16 and p.y == -16 then
		-- TODO: integrate this with Fortress.create_turret
		args.entities[#args.entities + 1] = {name = 'gun-turret', position = args.p, visible_on_overworld = true} 
		--[[
		for i=-2,1
		do
			args.entities[#args.entities + 1] = {name = "stone-wall", position = {p.x+i*11,p.y-2*11}, visible_on_overworld = true}
			args.entities[#args.entities + 1] = {name = "stone-wall", position = {p.x+i*11,p.y+1*11}, visible_on_overworld = true}
		end
			
		for i=-1,0
		do
			args.entities[#args.entities + 1] = {name = "stone-wall", position = {p.x-2*11,p.y+i*11}, visible_on_overworld = true}
			args.entities[#args.entities + 1] = {name = "stone-wall", position = {p.x+1*11,p.y+i*11}, visible_on_overworld = true}
		end
		--]]
	end 
	
	if noises.height(p) < 0.1 then
		args.tiles[#args.tiles + 1] = {name = 'sand-1', position = args.p}
		if args.specials and noises.farness(p) > 0.0001 and noises.farness(p) < 0.6 and Math.random(150) == 1 then
			args.specials[#args.specials + 1] = {name = 'buried-treasure', position = args.p}
		end
	elseif noises.height(p) < 0.16 then
		args.tiles[#args.tiles + 1] = {name = 'grass-4', position = args.p}
	else
		if noises.forest_abs_suppressed(p) > 0.5 and noises.rock(p) < 0.3 then
			args.tiles[#args.tiles + 1] = {name = 'grass-3', position = args.p}
		elseif noises.forest_abs_suppressed(p) > 0.2 and noises.rock(p) < 0.3 then
			args.tiles[#args.tiles + 1] = {name = 'grass-2', position = args.p}
		else
			args.tiles[#args.tiles + 1] = {name = 'grass-1', position = args.p}
		end
	end

	if noises.height(p) > 0.2 then
		if noises.forest_abs(p) > 0.65 then
            local treedensity = 0.4 * Math.slopefromto(noises.forest_abs_suppressed(p), 0.6, 0.85)
			if noises.forest(p) > 0.87 then
				if Math.random(1,100) < treedensity*100 then args.entities[#args.entities + 1] = {name = 'tree-01', position = args.p, visible_on_overworld = true} end
			elseif noises.forest(p) < -1.4 then
				if Math.random(1,100) < treedensity*100 then args.entities[#args.entities + 1] = {name = 'tree-03', position = args.p, visible_on_overworld = true} end
			else
				if Math.random(1,100) < treedensity*100 then args.entities[#args.entities + 1] = {name = 'tree-02', position = args.p, visible_on_overworld = true} end
			end
		end
	end

	if noises.forest_abs_suppressed(p) < 0.6 then
		if noises.height(p) > 0.12 then
			local rockdensity = 0.0018 * Math.slopefromto(noises.rock_abs(p), -0.15, 0.3)
			local rockrng = Math.random()
			if rockrng < rockdensity then
				args.entities[#args.entities + 1] = IslandsCommon.random_rock_1(args.p)
			elseif rockrng < rockdensity * 1.5 then
				args.decoratives[#args.decoratives + 1] = {name = 'rock-medium', position = args.p}
			elseif rockrng < rockdensity * 2 then
				args.decoratives[#args.decoratives + 1] = {name = 'rock-small', position = args.p}
			elseif rockrng < rockdensity * 2.5 then
				args.decoratives[#args.decoratives + 1] = {name = 'rock-tiny', position = args.p}
			end
		end
	end
	
	
end


function Public.chunk_structures(args)
	local destination = Common.current_destination()
	local surface = game.surfaces[destination.surface_name]

	local spec = function(p)
		local noises = Public.noises{p = p, noise_generator = args.noise_generator, static_params = args.static_params, seed = args.seed}

		return {
			placeable = noises.farness(p) > 0.4,
			density_perchunk = 28 * Math.slopefromto(noises.farness(p), 0.4, 1)^2,
		}
	end

	IslandsCommon.enemies_1(args, spec, false, 0.3)
	
end


function Public.break_rock(surface, p, entity_name)
	return Ores.try_ore_spawn(surface, p, entity_name, 6)
end

function Public.generate_silo_position()
	--local boatposition = memory.boat.position
	local overworld_progression = Common.overworldx()/40
	local destination = Common.current_destination()
	local island_center = destination.static_params.islandcenter_position
	local width = destination.static_params.width
	local height = destination.static_params.height
	local surface = game.surfaces[destination.surface_name]
	local max_wall_distance=9
	local p
	local corner = {}
	local layers=math.min(math.max(1,math.floor(0.25*(overworld_progression))),2)
	local level=math.min(math.max(1,math.floor(0.1*(overworld_progression))),10)

	p=Hunt.free_position_1(0.8,0)
	
	p = {
		x = math.floor(p.x),
		y = math.floor(p.y),
		r = find_radius(max_wall_distance,layers)
	}
	
	Fortress.create_fortress(p.x,p.y,max_wall_distance,layers,level)
	
	return p
end 

function Public.spawn_structures(destination,points_to_avoid)
	local overworld_progression = Common.overworldx()/40
	local num_specials = math.min(math.max(1,math.floor(0.25*(overworld_progression))),4)
	local island_center = destination.static_params.islandcenter_position
	local surface = game.surfaces[destination.surface_name]
	-- TODO: export this into memory.ancient_force
	local memory = Memory.get_crew_memory()
	local ancient_force = string.format('ancient-friendly-%03d', memory.id) 
	local args = {
		static_params = destination.static_params,
		noise_generator = Utils.noise_generator({}, 0),
	}
	local max_wall_distance=5
	local layers=1
	local i, p

	for i=1,num_specials
	do
		p=Hunt.mid_farness_position_1(args,points_to_avoid)
		
		p = {
			x = math.floor(p.x),
			y = math.floor(p.y),
			r = find_radius(max_wall_distance,layers)
		}

		Fortress.create_fortress(p.x,p.y,max_wall_distance,1,i*2-1)
		local chest = surface.create_entity {name="wooden-chest", force=ancient_force, position = {p.x,p.y}}
		local prize = prizes[math.floor(math.random(1,#prizes))]
		
		chest.insert({name=prize[1],count=prize[2]})
		
		points_to_avoid[#points_to_avoid + 1] = p
	end

end

function find_radius(max_wall_distance,layers)
	-- affected area: farthest layer + spawner size
	local length=max_wall_distance*layers+7
	local sqr=length*length
	return math.sqrt(sqr+sqr)
end

return Public