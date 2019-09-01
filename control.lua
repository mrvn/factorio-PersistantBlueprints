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
  surfaceName = surface_name(force)
  if game.surfaces[surfaceName] then
    return
  end

  local surface = game.create_surface(surfaceName, {width = 0, height = 0})
  surface.always_day = true

  -- generate initial chunks
  surface.request_to_generate_chunks({x=0, y=0}, 3)
  surface.force_generate_chunk_requests()

  -- create entities
  electricInterface = surface.create_entity {name = "electric-energy-interface", position = {0, 0}, force = force}
  electricInterface.minable = false
  pole = surface.create_entity {name = "big-electric-pole", position = {0, -2}, force = force}
  pole.minable = false
end

function editor_enter(player_index)
  local player = game.players[player_index]
  local player_global = global[player_index]

  if player_global.editorActive then
    player.print "invalid operation, player already in the editor."
    return
  end

  -- teleport to editor surface
  player_global.character = player.character
  player_global.surface = player.surface
  player.character = nil
  player.teleport({0, 0}, surface_name(player.force))

  if player_global.character then
    -- bring blueprints
  end

  player.cheat_mode = true
  player_global.editorActive = true
end

function editor_leave(player_index)
  local player = game.players[player_index]
  local player_global = global[player_index]

  if not player_global.editorActive then
    player.print "invalid operation, player not in editor."
    return
  end

  -- teleporting back to where the player came from
  player.cheat_mode = false

  player.teleport({0, 0}, player_global.surface)
  player.character = player_global.character
  player_global.character = nil

  player_global.editorActive = false
end

function editor_button_clicked(player_index)
  log("editor_button_clicked")
  local player = game.players[player_index]
  local player_global = global[player_index]

  if player_global.editorActive then
    editor_leave(player_index)
  else
    editor_init(player.force)
    editor_enter(player_index)
  end

  gui_update(player_index)
end

function on_gui_click(event)
  log("on_gui_click")
  if event.element.name == "PB_EditorButton" then
    log("  editor button")
    editor_button_clicked(event.player_index)
  end
end

function editor_hotkey_pressed(event)
  log("editor_hotkey_pressed")
    editor_button_clicked(event.player_index)
end

-- player initialization
function player_init(player_index)
  log("player_init")
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

-- map generator
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

  log("map_chunk_generated([" .. x0 .. ", " .. y0 .. "]-["
        .. x1 .. ", " .. y1 .."])")

  -- generate tiles
  tiles = {}
  for x = x0, x1 - 1 do
    for y = y0, y1 - 1 do
      if (x + y) % 2 == 0 then
        table.insert(tiles, {name = "lab-dark-1", position = {x, y}})
      else
        table.insert(tiles, {name = "lab-dark-2", position = {x, y}})
      end
    end
  end
  surface.set_tiles(tiles)

  -- remove decoratives and entities
  surface.destroy_decoratives{area=area}
  for _, entity in ipairs(surface.find_entities(area)) do
    entity.destroy()
  end
end

-- catch events
script.on_event(defines.events.on_player_created, function(event)
    player_init(event.player_index)
end)

script.on_event(defines.events.on_chunk_generated, map_chunk_generated)
script.on_event(defines.events.on_gui_click, on_gui_click)
script.on_event("PB_EditorButtonHotkey", editor_hotkey_pressed)

script.on_init(function()
    log("on_init")
    player_init_all()
end)

script.on_configuration_changed(function(event)
    log("on_configuration_changed")
    if event.mod_changes 
      and event.mod_changes["PersistantBlueprints"]
      and event.mod_changes["PersistantBlueprints"].old_version == "0.0.0" then
        log("Updating from PersistantBlueprints 0.0.0")
    end
end)

