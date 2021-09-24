mcl_linked_players = {}

local function sync_inv_lists(i1, i2)
        i1:set_lists(i2:get_lists())
end

function mcl_linked_players.sync_invs(player, reversed)
        if player then
                local name = player:get_player_name()
                local inv = player:get_inventory()
                local cplayers = minetest.get_connected_players()
                for _, nplayer in pairs(cplayers) do
                        local nname = nplayer:get_player_name()
                        if name ~= nname then
                                local inv1 = nplayer:get_inventory()
                                if reversed then
                                        sync_inv_lists(inv, inv1)
                                        break
                                else
                                        sync_inv_lists(inv1, inv)
                                end
                        end
                end
        end
end

local actions = {
        { nil, { "player_inventory_action", "player_receive_fields", "dieplayer" } },
        { true, { "joinplayer", "respawnplayer" } },
}

for _, s in pairs(actions) do
        for _, sync in pairs(s[2]) do
                minetest["register_on_" .. sync](function(player)
                        mcl_linked_players.sync_invs(player, s[1])
                end)
        end
end

minetest.register_on_placenode(function(_, _, placer)
        minetest.after(0.01, function()
                mcl_linked_players.sync_invs(placer)
        end)
end)

minetest.register_on_craft(function(_, player)
        mcl_linked_players.sync_invs(player)
end)

minetest.register_on_item_eat(function(_, _, _, user)
        mcl_linked_players.sync_invs(user)
end)

local drop_settings = {
        age = 1.0,
        radius_magnet = 2.0,
        xp_radius_magnet = 7.25,
        player_collect_height = 0.8,
        magnet_time = 0.75,
}

minetest.register_globalstep(function(dtime)
	for _, player in pairs(minetest.get_connected_players()) do
		if player:get_hp() > 0 or not minetest.settings:get_bool("enable_damage") then
			local name = player:get_player_name()
			local pos = player:get_pos()
			local inv = player:get_inventory()
			local checkpos = vector.offset(pos, 0, drop_settings.player_collect_height, 0)
			for _, object in pairs(minetest.get_objects_inside_radius(checkpos, drop_settings.xp_radius_magnet)) do
                                local entity = object:get_luaentity()
				if not object:is_player() and vector.distance(checkpos, object:get_pos()) < drop_settings.radius_magnet and entity and entity.name == "__builtin:item" and entity._magnet_timer and (entity._insta_collect or (entity.age > drop_settings.age)) then
					if entity._magnet_timer >= 0 and entity._magnet_timer < drop_settings.magnet_time and inv and inv:room_for_item("main", ItemStack(entity.itemstring)) then
						if not entity._removed then
							if entity.itemstring ~= "" then
								for _, pplayer in pairs(minetest.get_connected_players()) do
									pplayer:get_inventory():add_item("main", ItemStack(entity.itemstring))
                                                                        if has_awards then
                                                                                local itemname = ItemStack(entity.itemstring):get_name()
                                                                                local playername = pplayer:get_player_name()
                                                                                for name, award in pairs(registered_pickup_achievement) do
                                                                                        if itemname == name or minetest.get_item_group(itemname, name) ~= 0 then
                                                                                                awards.unlock(playername, award)
                                                                                        end
                                                                                end
                                                                        end
								end
								entity.target = checkpos
								entity._removed = true
								object:set_velocity(vector.new(0, 0, 0))
								object:set_acceleration(vector.new(0, 0, 0))
								object:move_to(checkpos)
								minetest.after(0.25, function()
									if object and entity then
										object:remove()
									end
								end)
							end
						end
					end
				elseif not object:is_player() and entity and entity.name == "mcl_experience:orb" then
					entity.collector = player:get_player_name()
					entity.collected = true

				end
			end
		end
		local ctr = player:get_player_control()
                if ctr.LMB or ctr.RMB then
                        local item = player:get_wielded_item():get_name()
                        local def = minetest.registered_items[item]
                        if minetest.registered_tools[item] or def.on_place or def.on_secondary_use or def.on_use or def.after_use then
                                mcl_linked_players.sync_invs(player)
                        end
                end
	end
end)
