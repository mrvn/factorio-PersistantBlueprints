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

--local pb_controller = {}
--for k, v in pairs(data.raw["constant-combinator"]["constant-combinator"]) do
--  pb_controller[k] = v
--end
local pb_controller = table.deepcopy(data.raw["constant-combinator"]["constant-combinator"])
pb_controller.name = "pb-controller"
pb_controller.minable = {mining_time = 1, result = "pb-controller"}
pb_controller.flags = {"placeable-neutral", "player-creation", "hide-alt-info"}
pb_controller.collision_mask = {"item-layer", "object-layer"}
pb_controller.icon = "__PersistantBlueprints__/graphics/icon/PB-chest.png"
pb_controller.icon_size = 32
pb_controller.icons = nil
pb_controller.next_upgrade = nil
pb_controller.fast_replaceable_group = nil
pb_controller.sprites =
  {
    layers =
      {
        {
          filename = "__PersistantBlueprints__/graphics/entity/PB-chest.png",
          priority = "extra-high",
          width = 32,
          height = 36,
          shift = util.by_pixel(0.5, -2),
          hr_version =
          {
            filename = "__PersistantBlueprints__/graphics/entity/PB-chest-hr.png",
            priority = "extra-high",
            width = 62,
            height = 72,
            shift = util.by_pixel(0.5, -2),
            scale = 0.5
          }
        },
        {
          filename = "__base__/graphics/entity/wooden-chest/wooden-chest-shadow.png",
          priority = "extra-high",
          width = 52,
          height = 20,
          shift = util.by_pixel(10, 6.5),
          draw_as_shadow = true,
          hr_version =
          {
            filename = "__base__/graphics/entity/wooden-chest/hr-wooden-chest-shadow.png",
            priority = "extra-high",
            width = 104,
            height = 40,
            shift = util.by_pixel(10, 6.5),
            draw_as_shadow = true,
            scale = 0.5
          }
        }
      }
  }
  
data:extend {
  {
    type = "custom-input",
    name = "PB_EditorButtonHotkey",
    key_sequence = "SHIFT + P"
  },
  {
    type = "item",
    name = "pb-controller",
    icon = "__PersistantBlueprints__/graphics/icon/PB-chest.png",
    icon_size = 32,
    subgroup = "production-machine",
    order = "h[PB]-a[controller]",
    place_result = "pb-controller",
    stack_size = 50
  },
  pb_controller,
  {
    type = "recipe",
    name = "pb-controller",
    ingredients = {{"stone", 2}},
    result = "pb-controller"
  },
}
