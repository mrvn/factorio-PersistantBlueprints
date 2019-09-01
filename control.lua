--[[ PersistantBlueprints
  * Copyright (c) 2019 Goswin von Brederlow
  *
  * This program is free software: you can redistribute it and/or modify
  * it under the terms of the GNU General Public License as published by
  * the Free Software Foundation, either version 3 of the License, or
  * (at your option) any later version.
  *
  * This program is distributed in the hope that it will be useful,
  * but WITHOUT ANY WARRANTY; without even the implied warranty of
  * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  * GNU General Public License for more details.
  *
  * You should have received a copy of the GNU General Public License
  * along with this program.  If not, see <http://www.gnu.org/licenses/>.
--]]

--gui
function gui_create(player_index)
  local player = game.players[player_index]
  local player_global = global[player_index]

  player_global.button = player.gui.left.add {type = "button", name = "PB_EditorButton", 
                                              caption = {"PB.EditorButtonEnter"}, tooltip = {"PB.EditorButtonTooltip"}}

  local main_frame = player.gui.center.add {type="flow", name="PB-main-frame", direction="horizontal"}
  main_frame.style.margin = 0
  main_frame.style.padding = 0
  main_frame.style.horizontal_spacing=3
  main_frame.visible = false

  local button = main_frame.add {type = "button", name = "PB_EditorButton", 
                                 caption = {"PB.EditorButtonEnter"}, tooltip = {"PB.EditorButtonTooltip"}}
  
  local win = {
    main_frame = main_frame,
    button = button,
  }
  player_global.win = win
end

function gui_update(player_index)
  local player = game.players[player_index]
  local player_global = global[player_index]

  if player_global.editorActive then
    player_global.button.caption = {"PB.EditorButtonLeave"}
  else
    player_global.button.caption = {"PB.EditorButtonEnter"}
  end
end

surface_stub = "PB.Editor-"

function surface_name(force)
  return surface_stub .. force.name
end

function is_editor_surface(surface)
  return string.sub(surface.name, 1, string.len(surface_stub)) == surface_stub
end

function editor_init(force)
  name = surface_name(force)
  if game.surfaces[name] then
    return
  end

  local surface = game.create_surface(name, {width = 0, height = 0})
  surface.always_day = true
  if remote.interfaces["RSO"] then -- RSO compatibility
    pcall(remote.call, "RSO", "ignoreSurface", name)
  end

  -- generate initial chunks
  surface.request_to_generate_chunks({x=0, y=0}, 3)
  surface.force_generate_chunk_requests()
end

local function player_teleport_safely(surface, player, position, character)
  surface.request_to_generate_chunks(position, 0)
  if not surface.is_chunk_generated(position) then
    surface.force_generate_chunk_requests()
  end
  if character then
    position = surface.find_non_colliding_position(
      character.name, position, 32, 0.5, false
    ) or position
  end
  -- deactivate old character
  if player.character and player.character ~= character then
    player.character.active = false
  end
  -- A player cannot switch to a character on another surface
  local temp_character
  if character and (player.surface ~= character.surface) then
    temp_character = player.surface.create_entity{name="character",
                                                  position=player.position,
                                                  force=player.force}
    player.character = temp_character
  else
    if player.character ~= character then
      player.character = character
    end
  end
  player.teleport(position, surface)
  if temp_character then
    player.character.destroy()
  end
  -- activate new character
  if player.character ~= character then
    player.character = character
    player.teleport(position, surface)
  end
  if character then
    character.active = true
  end
end

function editor_enter(player_index, position)
  local player = game.players[player_index]
  local player_global = global[player_index]
  local surface = game.surfaces[surface_name(player.force)]
  if player_global.editor_active then
    player.print "invalid operation, player already in the editor."
    return
  end

  -- teleport to editor surface
  player_global.orig_character = player.character
  player_global.surface = player.surface
  player_global.position = player.position
  if position == nil then
    if player_global.editor_character then
      position = player_global.editor_character.position
    else
      position = {25.5, 25.5}
    end
  end
  player_teleport_safely(surface, player, position, player_global.editor_character)
  if player.character == nil then
    player.create_character()
    player_global.editor_character = player.character
  end

  if player_global.orig_character then
    -- bring blueprints
  end

  player_global.cheat_mode = player.cheat_mode
  player.cheat_mode = true
  player_global.editor_active = true
end

function editor_leave(player_index)
  local player = game.players[player_index]
  local player_global = global[player_index]

  if not player_global.editor_active then
    player.print "invalid operation, player not in editor."
    return
  end

  -- teleporting back to where the player came from
  player_teleport_safely(player_global.surface, player, player_global.position, player_global.orig_character)
  player.cheat_mode = player_global.cheat_mode
  player_global.editor_active = false
end

function editor_button_clicked(player_index)
  local player = game.players[player_index]
  local player_global = global[player_index]

  if player_global.editor_active then
    editor_leave(player_index)
  else
    editor_init(player.force)
    editor_enter(player_index)
  end

  gui_update(player_index)
end

function on_gui_click(event)
  if event.element.name == "PB_EditorButton" then
    editor_button_clicked(event.player_index)
  end
end

function editor_hotkey_pressed(event)
    editor_button_clicked(event.player_index)
end

-- player initialization
function player_init(player_index)
  if global[player_index] then
    return
  end

  global[player_index] = {}
  gui_create(player_index)    
end

function player_init_all()
  for _, player in pairs(game.players) do
    player_init(player.index)
  end
end

function on_init()
  global.master = global.master or {}
  global.slaves = global.slaves or {}
  player_init_all()
end

function on_configuration_changed(event)
    if event.mod_changes
      and event.mod_changes["PersistantBlueprints"]
      and event.mod_changes["PersistantBlueprints"].old_version == "0.0.0" then
        log("Updating from PersistantBlueprints 0.0.0")
    end
end

-- map generator
function map_coords(x, y)
  -- each quadrant has a different size
  if x >= 16 then
    if y >= 16 then
      level = 1
      size_x = 1
      size_y = 1
    else
      level = 2
      size_x = 3
      size_y = 3
    end
  else
    if y <= 16 then
      level = 3
      size_x = 7
      size_y = 7
    else
      level = 4
      size_x = 15
      size_y = 15
    end
  end
  local grid_x = math.floor(x / 32) % (size_x + 1)
  local grid_y = math.floor(y / 32) % (size_y + 1)
  local x0 = math.floor(x / 32 / (size_x + 1)) * 32 * (size_x + 1) + 32
  local y0 = math.floor(y / 32 / (size_y + 1)) * 32 * (size_y + 1)+ 32
  local x1 = x0 + size_x * 32 - 0.001
  local y1 = y0 + size_y * 32 - 0.001
  local area = {left_top = {x = x0, y = y0}, right_bottom = {x = x1, y = y1}}
  return {
    grid = {x = grid_x, y = grid_y},
    -- size = {x = size_x, y = size_y},
    area = area,
    -- level = level
  }
end

function map_chunk_generated(event)
  local surface = event.surface

  if not is_editor_surface(surface) then
    return
  end

  local area = event.area
  local x0 = area.left_top.x
  local y0 = area.left_top.y
  local x1 = area.right_bottom.x
  local y1 = area.right_bottom.y

  -- generate tiles
  tiles = {}
  local map = map_coords(x0 + 16, y0 + 16)
  local walkway = "refined-concrete"
  local left = "refined-hazard-concrete-left"
  local right = "refined-hazard-concrete-right"
  local aleft = "hazard-concrete-left"
  local aright = "hazard-concrete-right"
  local border
  if ((map.grid.x  + map.grid.y) % 2 == 0) then
    border = left
  else
    border = right
  end
  for x = x0, x1 - 1 do
    for y = y0, y1 - 1 do
      local name = walkway
      if ((map.grid.x == 0) or (map.grid.y == 0)) then
        -- create concrete walkways
        if (map.grid.x == 0) and ((x == x0) or (x == x1 - 1)) then
          name = border
        end
        if (map.grid.y == 0) and ((y == y0) or (y == y1 - 1)) then
          name = border
        end
        -- teleport arrows
        local outer = 11
        if (map.grid.x == 0) and (map.grid.y == 0) then
          local u = x - x0 - 16
          local v = y - y0 - 16
          -- outer up arrow
          if (v == -outer - 1) or (v == -outer - 2) or (v == -outer - 3) or (v == -outer - 4) then
            if (u == 0) or (u == 1) then
              name = aright
            end
            if (u == -1) or (u == -2) then
              name = aleft
            end
          end
          -- outer down arrow
          if (v == outer) or (v == outer + 1) or (v == outer + 2) or (v == outer + 3) then
            if (u == 0) or (u == 1) then
              name = aleft
            end
            if (u == -1) or (u == -2) then
              name = aright
            end
          end
          -- outer left
          if (u == -outer - 1) or (u == -outer - 2) or (u == -outer - 3) or (u == -outer - 4) then
            -- outer left up arrow
            if (v == -outer - 1) or (v == -outer - 2) or (v == -outer - 3) or (v == -outer - 4) then
              name = aright
            end
          -- outer left arrow
            if (v == 0) or (v == 1) then
              name = aright
            end
            if (v == -1) or (v == -2) then
              name = aleft
            end
            -- outer left down arrow
            if (v == outer) or (v == outer + 1) or (v == outer + 2) or (v == outer + 3) then
              name = aleft
            end
          end
          -- outer right
          if (u == outer) or (u == outer + 1) or (u == outer + 2) or (u == outer + 3) then
            -- outer right up arrow
            if (v == -outer - 1) or (v == -outer - 2) or (v == -outer - 3) or (v == -outer - 4) then
              name = aleft
            end
          -- outer right arrow
            if (v == 0) or (v == 1) then
              name = aleft
            end
            if (v == -1) or (v == -2) then
              name = aright
            end
            -- outer right down arrow
            if (v == outer) or (v == outer + 1) or (v == outer + 2) or (v == outer + 3) then
              name = aright
            end
          end
        end
      else
        -- blueprint area
        if (x + y) % 2 == 0 then
          name = "lab-dark-1"
        else
          name = "lab-dark-2"
        end
      end
      table.insert(tiles, {name = name, position = {x, y}})
    end
  end
  surface.set_tiles(tiles)

  -- remove decoratives and entities
  surface.destroy_decoratives{area=area}
  for _, entity in ipairs(surface.find_entities(area)) do
    if entity.type ~= "character" then
      entity.destroy()
    end
  end

  -- create entities on crossroads
  if (map.grid.x == 0) and (map.grid.y == 0) then
    electricInterface = surface.create_entity {name = "electric-energy-interface", position = {x0 + 16, y0 + 15}, force = force}
    electricInterface.minable = false
    pole = surface.create_entity {name = "big-electric-pole", position = {x0 + 16, y0 + 17}, force = force}
    pole.minable = false
  end
end

-- teleport magic
teleport_pads = {
  -- top
  {x0 = -15, y0 = -15, x1 = -12, y1 = -12, dx = -1, dy = -1},
  {x0 = - 2, y0 = -15, x1 =   1, y1 = -12, dx =  0, dy = -1},
  {x0 =  11, y0 = -15, x1 =  14, y1 = -12, dx =  1, dy = -1},
  -- middle
  {x0 = -15, y0 = - 2, x1 = -12, y1 =   1, dx = -1, dy =  0},
  {x0 =  11, y0 = - 2, x1 =  14, y1 =   1, dx =  1, dy =  0},
  -- bottom
  {x0 = -15, y0 =  11, x1 = -12, y1 =  14, dx = -1, dy =  1},
  {x0 = - 2, y0 =  11, x1 =   1, y1 =  14, dx =  0, dy =  1},
  {x0 =  11, y0 =  11, x1 =  14, y1 =  14, dx =  1, dy =  1},
}

function teleport_delta(x, y)
  local map = map_coords(x, y)
  if (map.grid.x == 0) and (map.grid.y == 0) then
    x = (x % 32) - 16
    y = (y % 32) - 16
    for _, pad in ipairs(teleport_pads) do
      if (x >= pad.x0) and (x <= pad.x1) and (y >= pad.y0) and (y <= pad.y1) then
        return {x = pad.dx * (size_x * 32 + 28), y = pad.dy * (size_y * 32 + 28)}
      end
    end
  end
  return nil
end

function on_tick(event)
    for player_index, player in pairs(game.players) do
      if player.connected and not player.driving then
        local player_global = global[player.index]
        if player_global.editor_active then
          local surface = player.surface
          local x = player.position.x
          local y = player.position.y
          local delta = teleport_delta(x, y)
          if delta then
            player_teleport_safely(player.surface, player, {x + delta.x, y + delta.y}, player.character)
          end
	end
      end
    end
end

function player_created(event)
    player_init(event.player_index)
end

-- building and mining
function entity_abort_built(event, reason)
  local entity = event.created_entity
  if reason then
    entity.surface.create_entity{
      name = "flying-text",
      position = entity.position,
      text = {reason},
    }
  end
  if event.player_index then
    local player = game.players[event.player_index]
    player.mine_entity(entity, true)
  else
    entity.order_deconstruction(entity.force)
  end
end

function entity_built(event)
  local entity = event.created_entity
  if entity and entity.name == "pb-controller" then
    entity.destructible = false
    local control = entity.get_control_behavior()
    local surface = entity.surface
    if is_editor_surface(surface) then
      -- building a new master
      local x = entity.position.x
      local y = entity.position.y
      local map = map_coords(x, y)
      if (map.grid.x == 0) or (map.grid.y == 0) then
        entity_abort_built(event, "PB.on_walkway")
      else
        masters = surface.find_entities_filtered{area=map.area, name="pb-controller"}
        for _, master in ipairs(masters) do
          if master ~= entity then
            master.teleport(entity.position)
            -- FIXME: teleport all slaves to match
            entity_abort_built(event, nil)
            return
          end
        end
        -- place entity and make it a master
        entity.minable = nil
        signal = {signal = {type = "item", name = "blueprint"}, count = entity.unit_number}
        control.set_signal(1, signal)
        global.master[entity.unit_number] = entity
        global.slaves[entity.unit_number] = {}
      end
    else
      -- building a slave
      local signal = control.get_signal(1)
      if signal and signal.signal and (signal.signal.type == "item") and (signal.signal.name == "blueprint") then
        local master = signal.count
        log("  slaved to " .. master)
        local slaves = global.slaves[master]
        if slaves then
          slaves[entity.unit_number] = entity
        else
          entity_abort_built(event, "PB.invalid_master")
        end
      else
        entity_abort_built(event, "PB.lacking_master")
      end
    end
  else
    -- building something else
    local surface = entity.surface
    if is_editor_surface(surface) then
      -- on an editor surface
      local x = entity.position.x
      local y = entity.position.y
      local map = map_coords(x, y)
      if (map.grid.x ~= 0) or (map.grid.y ~= 0) then
        -- inside a construction area
        local master
        masters = surface.find_entities_filtered{area=map.area, name="pb-controller"}
        for _, t in ipairs(masters) do
          master = t
          break
        end
        if master then
          -- area has a master
          local dx = x - master.position.x
          local dy = y - master.position.y
          log("offset to master: (" .. dx .. ", " .. dy .. ")")
          local blueprint = surface.create_entity{
            name = "item-on-ground",
            position = {map.area.left_top.x - 1, map.area.left_top.y - 1}, -- outside build area
            stack = "blueprint",
            raise_built = false,
            create_build_effect_smoke = false,
          }.stack
          blueprint.create_blueprint{surface = entity.surface,
                                     force = entity.force,
                                     area = {left_top = {x, y}, right_bottom = {x, y}},
                                     always_include_tiles = true}
          for _, slave in pairs(global.slaves[master.unit_number]) do
            -- build entity in slave area
            local sx = slave.position.x + dx
            local sy = slave.position.y + dy
            log("building " .. entity.name .. " for slave " .. slave.unit_number .. " at (" .. sx .. ", " .. sy .. ")")
            log("slave at (" .. slave.position.x .. ", " .. slave.position.y .. ")")
            blueprint.build_blueprint{surface = slave.surface,
                                      force = slave.force,
                                      position = {x = sx, y = sy},
                                      direction = defines.direction.north,
                                      skip_fog_of_war = false,
                                      by_player = event.player_index}
          end
          blueprint.clear()
          -- item.destroy()
        end
      end
    end
  end
end

function entity_pre_mined(event)
  log("entity_pre_mined")
  local entity = event.entity
  if entity and entity.name == "pb-controller" then
    entity.destructible = true
    entity.minable = {mining_time = 0.1, result = "pb-controller"}
    -- only slaves can be mined, remove from master
    local control = entity.get_control_behavior()
    local signal = control.get_signal(1)
    log(serpent.block(signal))
    if signal and signal.signal and (signal.signal.type == "item") and (signal.signal.name == "blueprint") then
      local master = signal.count
      local slaves = global.slaves[master]
      log("removing slave to " .. master)
      slaves[entity.unit_number] = nil
    end
  else
    local surface = entity.surface
    if is_editor_surface(surface) then
      -- on an editor surface
      local x = entity.position.x
      local y = entity.position.y
      local map = map_coords(x, y)
      if (map.grid.x ~= 0) or (map.grid.y ~= 0) then
        -- inside a construction area
        local master
        local masters = surface.find_entities_filtered{area=map.area, name="pb-controller"}
        for _, t in ipairs(masters) do
          master = t
          break
        end
        if master then
          -- area has a master
          local dx = x - master.position.x
          local dy = y - master.position.y
          log("offset to master: (" .. dx .. ", " .. dy .. ")")
          for _, slave in pairs(global.slaves[master.unit_number]) do
            -- deconstruct entity in slave area
            local sx = slave.position.x + dx
            local sy = slave.position.y + dy
            log("destroying " .. entity.name .. " for slave " .. slave.unit_number .. " at (" .. sx .. ", " .. sy .. ")")
            log("slave at (" .. slave.position.x .. ", " .. slave.position.y .. ")")
            slave.surface.deconstruct_area{area = {left_top = {sx, sy}, right_bottom = {sx, sy}}, force = slave.force, player = event.player_index, skip_fog_of_war = false}
          end
        end
      end
    end
  end
end

function entity_settings_pasted(event)
  local source = event.source
  local destination = event.destination
  log("entity_settings_pasted")
end

function gui_opened(event)
  log("gui_opened")
  local entity = event.entity
  if entity and entity.name == "pb-controller" then
    log("controller opened")
    local player = game.players[event.player_index]
    player.opened = nil
    if is_editor_surface(entity.surface) then
      log("  master clicked")
      -- return to where the player came from
      editor_leave(event.player_index)
      -- put a blueprint into the players cursor
      local stack = player.cursor_stack
      if stack.set_stack({name="blueprint"}) then
        local x = entity.position.x
        local y = entity.position.y
        local map = map_coords(x, y)
        -- create blueprint of area
        stack.create_blueprint{surface = entity.surface,
                               force = entity.force,
                               area = map.area,
                               always_include_tiles = true}
      end
    else
      log("  slave clicked")
      local control = entity.get_control_behavior()
      local signal = control.get_signal(1)
      if signal and signal.signal and (signal.signal.type == "item") and (signal.signal.name == "blueprint") then
        local master = signal.count
        local master = global.master[master]
        editor_enter(event.player_index, master.position)
      end
    end
    if player.opened then
      player.opened = nil
    end
  end
end

-- catch events
script.on_event(defines.events.on_player_created, player_created)
script.on_event(defines.events.on_chunk_generated, map_chunk_generated)
script.on_event(defines.events.on_gui_click, on_gui_click)
script.on_event("PB_EditorButtonHotkey", editor_hotkey_pressed)
script.on_init(on_init)
script.on_configuration_changed(on_configuration_changed)
script.on_event(defines.events.on_tick, on_tick)
script.on_event(defines.events.on_built_entity, entity_built)
script.on_event(defines.events.on_robot_built_entity, entity_built)
script.on_event(defines.events.on_pre_player_mined_item, entity_pre_mined)
script.on_event(defines.events.on_robot_pre_mined, entity_pre_mined)
script.on_event(defines.events.on_gui_opened, gui_opened)
script.on_event(defines.events.on_entity_settings_pasted, entity_settings_pasted)

-- on_cancelled_deconstruction	Called when the deconstruction of an entity is canceled.
-- on_forces_merged  Called after two forces have been merged using game.merge_forces().
-- on_gui_checked_state_changed	Called when LuaGuiElement checked state is changed (related to checkboxes and radio buttons)
-- on_gui_click	Called when LuaGuiElement is clicked.
-- on_gui_closed	Called when the player closes the GUI they have open.
-- on_gui_confirmed	Called when LuaGuiElement is confirmed.
-- on_gui_elem_changed	Called when LuaGuiElement element value is changed (related to choose element buttons)
-- on_gui_location_changed	Called when LuaGuiElement element location is changed (related to frames in player.
-- on_gui_opened	Called when the player opens a GUI.
-- on_gui_selected_tab_changed	Called when LuaGuiElement selected tab is changed (related to tabbed-panes)
-- on_gui_selection_state_changed	Called when LuaGuiElement selection state is changed (related to drop-downs and listboxes)
-- on_gui_switch_state_changed	Called when LuaGuiElement switch state is changed (related to switches)
-- on_gui_text_changed	Called when LuaGuiElement text is changed by the player
-- on_gui_value_changed   Called when LuaGuiElement slider value is changed (related to the slider element) 
-- on_marked_for_deconstruction	Called when an entity is marked for deconstruction with the Deconstruction planner or via script.
-- on_player_pipette	Called when a player invokes the "smart pipette" over an entity.
-- on_pre_entity_settings_pasted	Called before entity copy-paste is done.
-- on_robot_mined	Called when a robot mines an entity.
-- on_robot_mined_entity	Called after the results of an entity being mined are collected just before the entity is destroyed.
-- on_selected_entity_changed	Called after the selected entity changes for a given player.
-- script_raised_built	A static event mods can use to tell other mods they built something with a script.
-- script_raised_destroy	A static event mods can use to tell other mods they destroyed something with a script.
-- script_raised_revive
