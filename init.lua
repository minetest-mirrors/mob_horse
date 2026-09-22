
-- translation and get mod path

local S = core.get_translator("mob_horse")
local MP = core.get_modpath(core.get_current_modname()) .. "/"

-- horse shoes (speed, jump, brake/reverse speed, overlay texture)

local shoes = {
	["mobs:horseshoe_steel"] = {
		speed = 7, jump = 4, reverse = 2, overlay = "mobs_horseshoe_steelo.png"},
	["mobs:horseshoe_bronze"] = {
		speed = 7, jump = 4, reverse = 4, overlay = "mobs_horseshoe_bronzeo.png"},
	["mobs:horseshoe_mese"] = {
		speed = 9, jump = 5, reverse = 8, overlay = "mobs_horseshoe_meseo.png"},
	["mobs:horseshoe_diamond"] = {
		speed = 10, jump = 6, reverse = 6, overlay = "mobs_horseshoe_diamondo.png"},
	["mobs:horseshoe_crystal"] = {
		speed = 11, jump = 6, reverse = 9, overlay = "mobs_horseshoe_crystalo.png"}
}

-- helper function for horse texture overlay

local function update_horse_texture(self)

	local texture_mods = ""

	if self.shoed then

		local shoe = shoes[self.shoed]

		if shoe and shoe.overlay then
			texture_mods = "^" .. shoe.overlay
		end
	end

	if self.saddle then
		texture_mods = texture_mods .. "^mobs_saddle_overlay.png"
	end

	self.texture_mods = texture_mods

	self.object:set_texture_mod(texture_mods)
end

-- drop item

local function drop_item(pos, item)

	local obj = core.add_item(pos, item)

	if obj then
		obj:set_velocity({x = math.random() - 0.5, y = 5, z = math.random() - 0.5})
	end
end

-- rideable horse

mobs:register_mob("mob_horse:horse", {
	description = S("Horse"),
	type = "animal",
	visual = "mesh",
	visual_size = {x = 1.20, y = 1.20},
	mesh = "mobs_horse.x",
	collisionbox = {-0.4, -0.01, -0.4, 0.4, 1.25, 0.4},
	animation = {
		speed_normal = 15,
		stand_start = 25, stand_end = 25, -- stand still
		stand2_start = 25, stand2_end = 50, stand2_loop = false, -- head to side
		walk_start = 75, walk_end = 100,
		run_start = 75, run_end = 100, run_speed = 45,
		punch_start = 55, punch_end = 75, punch_speed = 35 -- rear up
	},
	textures = {
		{"mobs_horse.png"}, -- textures by Mjollna
		{"mobs_horsepeg.png"},
		{"mobs_horseara.png"}
	},
	fear_height = 3,
	--runaway = true,
	fly = false,
	walk_chance = 60,
	view_range = 7,
	follow = {
		"farming:wheat", "default:apple", "farming:oat",
		"farming:barley", "farming:corn"
	},
	pushable = true,
	passive = false, attack_type = "dogfight", reach = 2.5, damage = 3,
	attack_chance = 95,
	attack_monsters = true,
	hp_min = 15,
	hp_max = 23,
	armor = 100,
	lava_damage = 5,
	fire_damage = 4,
	fall_damage = 1,
	water_damage = 0,
	makes_footstep_sound = true,
	sounds = {
		random = "mob_horse",
		death = "mob_horse_whinny",
		attack = "mob_horse_whinny"
	},
	drops = {
		{name = "mobs:leather", chance = 1, min = 0, max = 2},
		{name = "mobs:meat_raw", chance = 1, min = 1, max = 2}
	},

	do_mount_action = function(self, dtime) -- holding sneak and LMB while riding horse

		local now = os.time()

		-- only allowed to continue after 5 seconds
		self.neigh_timer = (self.neigh_timer or 0)
		if (now - self.neigh_timer) < 5 then return end
		self.neigh_timer = now

		core.sound_play("mob_horse_whinny", {pos = self.object:get_pos()}, true)
	end,

	do_custom = function(self, dtime)

		-- set required riding values if not already present
		if not self.max_speed_forward then

			self.max_speed_forward = 6
			self.max_speed_reverse = 2
			self.accel = 6
			self.driver_attach_at = {x = 0, y = 10, z = -2}
			self.driver_eye_offset = {x = 0, y = 13, z = 0}
			self.driver_scale = {x = 0.8, y = 0.8} -- shrink driver to fit model
--			self.alt_turn = true -- uses left and right keys to turn horse instead
		end

		-- if driver present allow control of horse
		if self.driver then

			mobs.drive(self, "walk", "stand", false, dtime)

			return false -- skip rest of mob functions
		end
	end,

	on_die = function(self, pos)

		-- detach player from horse properly
		if self.driver then
			mobs.detach(self.driver, {x = 1, y = 0, z = 1})
		end

		-- drop saddle if found
		if self.saddle then
			drop_item(pos, "mobs:saddle")
		end

		-- drop any horseshoes added
		if self.shoed then
			drop_item(pos, self.shoed)
		end
	end,

	on_rightclick = function(self, clicker)

		-- make sure player is clicking
		if not clicker or not clicker:is_player() then return end

		-- feed, tame or heal horse
		if mobs:feed_tame(self, clicker, 10, true, true) then return end

		-- applying protection rune
		if mobs:protect(self, clicker) then return end

		local player_name = clicker:get_player_name()

		-- make sure tamed horse is being clicked by owner only
		if self.tamed and self.owner == player_name then

			local inv = clicker:get_inventory()
			local tool = clicker:get_wielded_item()
			local item = tool:get_name()

			-- detatch player already riding horse
			if self.driver and clicker == self.driver then

				mobs.detach(clicker, {x = 1, y = 0, z = 1})

				self:set_animation("stand")

				return
			end

			-- attach saddle to horse
			if not self.driver and not self.child and not self.saddle
			and tool:get_name() == "mobs:saddle" then

				self.saddle = true
				self.order = "stand"
				self.object:set_properties({stepheight = 1.2})

				-- take saddle from inventory
				inv:remove_item("main", "mobs:saddle")

				update_horse_texture(self)

				return
			end

			local shoe = shoes[item]

			if shoe then -- apply horseshoes

				-- drop any existing shoes
				if self.shoed then
					drop_item(self.object:get_pos(), self.shoed)
				end

				self.max_speed_forward = shoe.speed
				self.jump_height = shoe.jump
				self.max_speed_reverse = shoe.reverse
				self.accel = shoe.speed
				self.shoed = item

				update_horse_texture(self)

				-- show horse speed and jump stats with shoes fitted
				core.chat_send_player(player_name,
						S("Horse shoes fitted -")
						.. S(" speed: ") .. shoe.speed
						.. S(" , jump height: ") .. shoe.jump
						.. S(" , stop speed: ") .. shoe.reverse)

				tool:take_item()

				clicker:set_wielded_item(tool)

				return
			end
		end

		-- used to capture horse with magic lasso
		if mobs:capture_mob(self, clicker, nil, nil, 100, false, nil) then return end

		-- ride horse if saddled
		if self.saddle and self.owner == player_name then
			mobs.attach(self, clicker)
		end
	end,
--[[
	on_sound = function(self, def)
		if def.loudness > 0.8 then -- if loud enough startle horse into jumping
			self.object:set_velocity({x = 0, y = 5, z = 0})
		end
	end
]]
})

-- check for custom spawn.lua
local input = io.open(MP .. "spawn.lua", "r")

if input then
	input:close()
	input = nil
	dofile(MP .. "spawn.lua")
else

	mobs:spawn({
		name = "mob_horse:horse",
		nodes = {"default:dirt_with_grass", "ethereal:dry_dirt"},
		min_light = 14,
		interval = 60,
		chance = 16000,
		min_height = 10,
		max_height = 31000,
		day_toggle = true
	})
end

-- spawn egg (true at end means horse can be placed in protected areas)

mobs:register_egg("mob_horse:horse", S("Horse"), "wool_brown.png", 1, nil, true)

-- steel horseshoes

core.register_craftitem(":mobs:horseshoe_steel", {
	description = S("Steel HorseShoes (use on horse to apply)"),
	inventory_image = "mobs_horseshoe_steel.png",
})

core.register_craft({
	output = "mobs:horseshoe_steel",
	recipe = {
		{"", "default:steelblock", ""},
		{"default:steel_ingot", "", "default:steel_ingot"},
		{"default:steel_ingot", "", "default:steel_ingot"}
	}
})

-- bronze horseshoes

core.register_craftitem(":mobs:horseshoe_bronze", {
	description = S("Bronze HorseShoes (use on horse to apply)"),
	inventory_image = "mobs_horseshoe_bronze.png"
})

core.register_craft({
	output = "mobs:horseshoe_bronze",
	recipe = {
		{"", "default:bronzeblock", ""},
		{"default:bronze_ingot", "", "default:bronze_ingot"},
		{"default:bronze_ingot", "", "default:bronze_ingot"}
	}
})

-- mese horseshoes

core.register_craftitem(":mobs:horseshoe_mese", {
	description = S("Mese HorseShoes (use on horse to apply)"),
	inventory_image = "mobs_horseshoe_mese.png"
})

core.register_craft({
	output = "mobs:horseshoe_mese",
	recipe = {
		{"", "default:mese", ""},
		{"default:mese_crystal_fragment", "", "default:mese_crystal_fragment"},
		{"default:mese_crystal_fragment", "", "default:mese_crystal_fragment"}
	}
})

-- diamond horseshoes

core.register_craftitem(":mobs:horseshoe_diamond", {
	description = S("Diamond HorseShoes (use on horse to apply)"),
	inventory_image = "mobs_horseshoe_diamond.png"
})

core.register_craft({
	output = "mobs:horseshoe_diamond",
	recipe = {
		{"", "default:diamondblock", ""},
		{"default:diamond", "", "default:diamond"},
		{"default:diamond", "", "default:diamond"}
	}
})

-- crystal horseshoes

if core.get_modpath("ethereal") then

	core.register_craftitem(":mobs:horseshoe_crystal", {
		description = S("Crystal HorseShoes (use on horse to apply)"),
		inventory_image = "mobs_horseshoe_crystal.png"
	})

	core.register_craft({
		output = "mobs:horseshoe_crystal",
		recipe = {
			{"", "ethereal:crystal_block", ""},
			{"ethereal:crystal_ingot", "", "ethereal:crystal_ingot"},
			{"ethereal:crystal_ingot", "", "ethereal:crystal_ingot"}
		}
	})
end

-- lucky blocks

if core.get_modpath("lucky_block") then

	lucky_block:add_blocks({
		{"dro", {"mobs:horseshoe_steel"}},
		{"dro", {"mobs:horseshoe_bronze"}},
		{"dro", {"mobs:horseshoe_mese"}},
		{"dro", {"mobs:horseshoe_diamond"}},
		{"dro", {"mobs:horseshoe_crystal"}}
	})
end

print("[MOD] Mobs Redo Horse loaded")
