-- Contains elements with name and contents.
registered_recipes = {{name = "default:cobble", contents = {"default:cobble", "default:stone"}},
					  {name = "default:wood", contents = {"default:wood", "default:cobble"}},
					  {name = "default:furnace", contents = {"default:cobble", "default:cobble", "default:cobble", "default:cobble", "default:cobble", "default:cobble", "default:cobble", "default:cobble", "default:cobble", "default:cobble"}, time_to_craft = 10},
					  {name = "default:tree", contents = {"default:tree", "default:cobble", "default:wood"}},
					  {name = "default:pick_diamond", contents = {"default:pick_diamond"}},
					  {name = "default:stone", contents = {"default:cobble"}},
					  {name = "default:stone", contents = {"default:cobble"}},
					  {name = "default:stone", contents = {"default:cobble"}},
					  {name = "default:stone", contents = {"default:cobble"}},
}
-- Contains recipes with just the result and count of materials
-- example:
-- - name = "default:wood"
-- - used["default:cobble"].count = 2
parsed_recipes = {}

-- Contains player craft queues, indexed by player names.
player_craft_queues = {}

-- Contains HUDs for players, indexed by player names.
player_craft_hud = {}

player_current_page = {}

local step = 0.1

function round(num, numDecimalPlaces)
	local mult = 10^(numDecimalPlaces or 0)
	return math.floor(num * mult + 0.5) / mult
end

local function table_contains(table, contains)
	for i = 1, #table do
		if table[i].name == contains then
			return i
		end
	end
	return 0
end

-- This function just adds the item to the craft queue of the player,
-- no questions asked. Doesn't take items or check for their existance.
local function add_to_craft_queue(name, result, time_to_craft)
	local temp_element = {result = result, time_to_craft = time_to_craft}
	if player_craft_queues[name] then
		table.insert(player_craft_queues[name], temp_element)
	else
		player_craft_queues[name] = {temp_element}
	end
end
local function update_recipes()
	for i = 1, #registered_recipes do
		local time_to_craft = registered_recipes[i].time_to_craft or 1
		local used_items = {}
		local result = registered_recipes[i].name
		local reagents = registered_recipes[i].contents
		for y = 1, #reagents do
			local contains_pos = table_contains(used_items, reagents[y])
			if contains_pos > 0 then
				used_items[contains_pos].count = used_items[contains_pos].count + 1
			else
				minetest.chat_send_all("Adding a new item to the list: " .. reagents[y] .. ". Because pos is: " .. contains_pos)
				table.insert(used_items, {name = reagents[y], count = 1})
			end
		end
		table.insert(parsed_recipes, {name = result, used = used_items, time_to_craft = time_to_craft})
	end
end
update_recipes()
local function create_error_formspec(error_message)
	local error_formspec = "size[9,6]" ..
						   "label[1,1;" .. error_message .. "]"
	return error_formspec
end
local function create_craft_formspec(error_message, name)
	
	local items_per_page = 5
	
	local num_pages = math.floor(#parsed_recipes/items_per_page)
	
	if not name then
		return create_error_formspec("Name is nil!")
	end
	
	error_message = error_message or ""
	
	if not player_current_page[name] then
		player_current_page[name] = 0
	end
	
	local page = player_current_page[name]
	local formspec = "size[9,6]"
	local recipe_offset = (page * items_per_page) + 1
	
	
	for i = recipe_offset, recipe_offset + items_per_page - 1 do--#parsed_recipes do
		local recipe = parsed_recipes[i]
		if not recipe then
			break
		end
		local result = recipe.name
		local materials = recipe.used
		local ypos = i - recipe_offset
		formspec = formspec .. "item_image[0," .. ypos .. ";1,1;" .. result .. "]" ..
				   "label[1," .. ypos + 0.25 .. ";" .. minetest.registered_items[result].description .. "]"
		for y = 1, #materials do
			local name = materials[y].name
			local count = materials[y].count
			if y <= 4 then
				formspec = formspec .. "item_image[" .. 8 - y.. "," .. ypos .. ";0.5,0.5;" .. name .. "]" ..
						   "label[".. 7.6 - y .."," .. ypos ..";" .. count .. "x]"
			else -- Second row of materials needed, apparently.
				formspec = formspec .. "item_image[" .. 8 - y + 4 .. "," .. ypos + 0.5 .. ";0.5,0.5;" .. name .. "]" ..
						   "label[".. 7.6 - y + 4 .."," .. ypos + 0.5 ..";" .. count .. "x]"
			end
		end
		formspec = formspec .. "button[8," .. ypos .. ";1,1;recipe_" .. i .. ";+]"
		if page < num_pages then
			formspec = formspec .. "button[8,5;1,1;next_page;>]" 
		end
		if page > 0 then
			formspec = formspec .. "button[7,5;1,1;prev_page;<]"
		end
		formspec = formspec .. "label[0,6;" .. error_message .. "]"
	end
	return formspec
end
function check_if_player_has_materials(inv, mats)
	for i = 1, #mats do
		local material = mats[i]
		local stack = ItemStack(material.name .. " " .. material.count)
		if not inv:contains_item("main", stack) then
			return false
		end
	end
	return true
end
local function take_items_from_list(inv, items)
	for i = 1, #items do
		local stack = ItemStack(items[i].name .. " " .. items[i].count) 
		inv:remove_item("main", stack)
	end
	return true
end
local function add_hud_icon(name, item)
	local player = minetest.get_player_by_name(name)
	local hud = player_craft_hud[name]
	local item_def = minetest.registered_items[item]
	local tiles = item_def.tiles
	local inv_image = ""
	if not player_craft_hud[name] then
		player_craft_hud[name] = {}
	end
	if not player_craft_hud[name].count then
		player_craft_hud[name].count = 0
	end
	if not tiles then
		inv_image = minetest.inventorycube(item_def.inventory_image)
	elseif #tiles < 3 then
		inv_image = minetest.inventorycube(tiles[1])
	elseif #tiles == 3 then
		inv_image = minetest.inventorycube(tiles[1], tiles[3], tiles[3])
	elseif #tiles > 3 then
		inv_image = minetest.inventorycube(tiles[1], tiles[6], tiles[3])
	end
	
	local offset = { x=(-10*24)-25+30*player_craft_hud[name].count, y=-(48+24+48)}
	local temp_element = {}
	temp_element.id = player:hud_add({
		hud_elem_type = "image",
		position = {x=0.5,y=1},
		scale = {x=0.5,y=0.5},
		offset = offset,
		text = inv_image
	})
	temp_element.offset = offset
	player_craft_hud[name].count = player_craft_hud[name].count + 1
	table.insert(player_craft_hud[name], temp_element)
end
-- Update crafting of all players

local function update_crafting(dtime)
	--local time_at_start = os.clock()
	for player_name, craft_queue in pairs(player_craft_queues) do
		if craft_queue[1] then
			local craft = craft_queue[1]
			local result = craft.result
			local progress = craft.progress or 0
			local time_to_craft = craft.time_to_craft or 1
			if minetest.get_player_by_name(player_name) == nil then
				return false
			end
			if player_craft_hud[player_name].completed then
				minetest.get_player_by_name(player_name):hud_change(player_craft_hud[player_name].completed,
																	"text", round((progress/time_to_craft)*100, 2) .. "%")
			else
				local offset = { x=(-10*24)-64, y=-(48+24+48)}
				player_craft_hud[player_name].completed = minetest.get_player_by_name(player_name):hud_add({
					hud_elem_type = "text",
					position = {x=0.5,y=1},
					number = 0xFFFFFF,
					text = progress .. "/" .. time_to_craft,
					offset = offset
				})
			end
			if progress >= time_to_craft then -- Craft has finished.
				table.remove(craft_queue, 1) -- Remove the craft from the queue
				minetest.get_player_by_name(player_name):hud_remove(player_craft_hud[player_name].completed)
				player_craft_hud[player_name].completed = nil
				minetest.get_player_by_name(player_name):hud_remove(player_craft_hud[player_name][1].id) -- Remove hud element
				table.remove(player_craft_hud[player_name], 1) -- Remove hud element ID
				for i = 1, #player_craft_hud[player_name] do -- Move all the other elements 30px to the side.
					local hud_id = player_craft_hud[player_name][i].id
					local offset = player_craft_hud[player_name][i].offset
					local new_offset = {x=offset.x-30, y=offset.y}
					player_craft_hud[player_name][i].offset = new_offset
					minetest.get_player_by_name(player_name):hud_change(hud_id, "offset", new_offset)
				end
				player_craft_hud[player_name].count = player_craft_hud[player_name].count - 1
				minetest.get_player_by_name(player_name):get_inventory():add_item("main", result .. " 1") -- Give player the item
			end
			craft.progress = progress + dtime--((os.clock() - time_at_start) / 1000, 1)
			print(dtime)
		end
	end
	--minetest.after(0.1, update_crafting)
end
minetest.register_globalstep(function(dtime)
	update_crafting(dtime)
end)
minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname == "craft:formspec" then
		local page = player_current_page[player:get_player_name()] or 0
		if fields["next_page"] then
			player_current_page[player:get_player_name()] = page + 1
			minetest.show_formspec(player:get_player_name(), "craft:formspec", create_craft_formspec("Next page", player:get_player_name()))
		end
		if fields["prev_page"] then
			player_current_page[player:get_player_name()] = page - 1
			minetest.show_formspec(player:get_player_name(), "craft:formspec", create_craft_formspec("Previous page", player:get_player_name()))
		end
		for i = 1, #parsed_recipes do
			local recipe = parsed_recipes[i]
			local result = recipe.name
			local materials = recipe.used
			local time_to_craft = recipe.time_to_craft
			if fields["recipe_" .. i] then
				local inventory = minetest.get_inventory({type="player", name=player:get_player_name()})
				local enough_mats = check_if_player_has_materials(inventory, materials)
				if enough_mats then
					take_items_from_list(inventory, materials)
					add_to_craft_queue(player:get_player_name(), result, time_to_craft)
					add_hud_icon(player:get_player_name(), result)
					minetest.show_formspec(player:get_player_name(), "craft:formspec", create_craft_formspec("Crafting " .. minetest.registered_items[result].description:lower() .. ".", player:get_player_name()))
				else
					minetest.show_formspec(player:get_player_name(), "craft:formspec", create_craft_formspec("Not enough materials.", player:get_player_name()))
				end
			end
		end
	end
end)

minetest.register_chatcommand("test_inv", {
	description = "Test the new inventory. Remove on release.",
	params = "",
	func = function(name, param)
		local formspec = create_craft_formspec("Successfully initialized crafting formspec. Obviously.", name)
		minetest.show_formspec(name, "craft:formspec", formspec)
	end,
})
update_crafting()
