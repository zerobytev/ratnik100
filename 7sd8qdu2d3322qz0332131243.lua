local name = "byte.tech"
local error = error
local setmetatable = setmetatable
local ipairs = ipairs
local pairs = pairs
local next = next
local printf = printf
local rawequal = rawequal
local rawset = rawset
local rawlen = rawlen
local readfile = readfile
local writefile = writefile
local require = require
local tonumber = tonumber
local toticks = toticks
local type = type
local unpack = unpack
local pcall = pcall


local function table_comp(a)
	local b = {}

	for c, d in next, a do
		b[c] = d
	end

	return b
end

local table = table_comp(table)

local math = table_comp(math)
local string = table_comp(string)
local ui = table_comp(ui)
local client = table_comp(client)
local database = table_comp(database)
local entity = table_comp(entity)
local ffi = table_comp(require("ffi"))
local globals = table_comp(globals)
local panorama = table_comp(panorama)
local renderer = table_comp(renderer)
local bit = table_comp(bit)

local ffi = require 'ffi'
local bit = require 'bit'
local vector = require("vector")
local json = require("json")
local trace = require ("gamesense/trace")
local pui = require("gamesense/pui")
--local base64 = require("gamesense/base64")
local clipboard = require("gamesense/clipboard")
--local http = require('gamesense/http')

local js = panorama.open()

local x, y = client.screen_size()

local databas = {
	cfgs = name .. "::db:",
	load = name .. "::loads",
	kill = name .. "::kills",
}




local menu = {
  main_switch = ui.new_checkbox('MISC', 'Movement', 'Jumpscout'),
  speed_threshold = ui.new_slider('MISC', 'Movement', 'Speed Threshold', 10, 200, 50, true, 'units', 1),
}


local function handle_ui()
  local enabled = ui.get(menu.main_switch)
  ui.set_visible(menu.speed_threshold, enabled)
end

handle_ui()
ui.set_callback(menu.main_switch, handle_ui)


local function get_player_speed()
  local me = entity.get_local_player()
  if not me then return 0 end
  local vx, vy, vz = entity.get_prop(me, 'm_vecVelocity')
  return math.sqrt(vx * vx + vy * vy + vz * vz)
end


local function on_setup_command(cmd)
  if not ui.get(menu.main_switch) then return end

  local speed = get_player_speed()
  local threshold = ui.get(menu.speed_threshold)


  if speed < threshold then
    cmd.sidemove = 0
  end
end


client.set_event_callback('setup_command', on_setup_command)

-- Initialize menu table safely
local menu = {}

-- Create UI checkbox
menu.show_gui = ui.new_checkbox("MISC", "Settings", "Overlay bytetech", true)

-- Dragging functionality
local function dragging(name, width, height)
    local x, y = 100, 100
    local dragging, drag_x, drag_y = false, 0, 0

    return {
        get = function(offset_x, offset_y)
            return x + (offset_x or 0), y + (offset_y or 0)
        end,
        drag = function(w, h, sensitivity)
            local screen_w, screen_h = client.screen_size()
            -- Prevent invalid screen size
            if not screen_w or not screen_h or screen_w <= 0 or screen_h <= 0 then
                client.log("Error: Invalid screen size (" .. tostring(screen_w) .. "x" .. tostring(screen_h) .. ")")
                return
            end

            local mouse_x, mouse_y = ui.mouse_position()
            if not mouse_x or not mouse_y then
                client.log("Error: Invalid mouse position")
                return
            end

            -- Check if mouse is in bounds and left mouse button is pressed
            if ui.is_mouse_in_bounds(x, y, w, h) and client.key_state(0x01) then
                if not dragging then
                    dragging = true
                    drag_x, drag_y = mouse_x - x, mouse_y - y
                end
            elseif dragging and not client.key_state(0x01) then
                dragging = false
            end

            if dragging then
                x = math.max(0, math.min(mouse_x - drag_x, screen_w - w))
                y = math.max(0, math.min(mouse_y - drag_y, screen_h - h))
            end
        end
    }
end

-- Initialize dragging for GUI
local gui_drag = dragging("byte_tech_gui", 200, 40)

-- GUI table
local gui = {
    width = 200,
    height = 40,
    alpha = 0, -- Initialize alpha as number
    draw = function(self)
        -- Validate self.alpha
        if type(self.alpha) ~= "number" then
            client.log("Error: self.alpha is not a number, resetting to 0")
            self.alpha = 0
        end

        -- Check if GUI is enabled and player is valid
        local me = entity.get_local_player()
        local frametime = globals.frametime() or 0.016 -- Fallback to 60 FPS
        if type(frametime) ~= "number" or frametime <= 0 then
            client.log("Error: Invalid frametime (" .. tostring(frametime) .. "), using fallback")
            frametime = 0.016
        end

        if not ui.get(menu.show_gui) or not me or not entity.is_alive(me) then
            self.alpha = math.max(self.alpha - frametime * 200, 0)
            if self.alpha <= 0 then return end
        else
            self.alpha = math.min(self.alpha + frametime * 200, 255)
        end

        if self.alpha > 0 then
            local x, y = gui_drag:get()
            gui_drag:drag(self.width, self.height, 1)

            -- Draw background rectangles
            renderer.rectangle(x, y, self.width, self.height, 30, 30, 30, math.floor(self.alpha))
            renderer.rectangle(x, y, self.width, 20, 0, 170, 255, math.floor(self.alpha))

            -- Draw title text
            renderer.text(x + 5, y + 4, 255, 255, 255, math.floor(self.alpha), "c", 0, "byte.tech")

            -- Draw player info
            local offset_y = y + 20
            local fps = math.floor(1 / math.max(frametime, 0.0001)) -- Prevent division by zero
            local ping = entity.get_prop(me, "m_iPing") or 0
            local time = os.date("%H:%M:%S") or "00:00:00"
            local nickname = entity.get_player_name(me) or "Unknown"

            renderer.text(x + 5, offset_y, 0, 255, 0, math.floor(self.alpha), "", 0, string.format("FPS: %d", fps))
            renderer.text(x + 60, offset_y, 0, 255, 0, math.floor(self.alpha), "", 0, string.format("Ping: %dms", ping))
            renderer.text(x + 110, offset_y, 0, 255, 0, math.floor(self.alpha), "", 0, string.format("Time: %s", time))
            renderer.text(x + 160, offset_y, 0, 255, 0, math.floor(self.alpha), "", 0, string.format("Nick: %s", nickname))
        end
    end
}

-- Register callback to draw GUI
client.set_event_callback("paint", function()
    gui:draw()
end)

local menu = {
  aimbot_enable = ui.new_checkbox("LEGIT", "Other", "Enable Aimbot"),
  trigger_enable = ui.new_checkbox("LEGIT", "Other", "Enable Triggerbot"),
  bhop_enable = ui.new_checkbox("LEGIT", "Other", "Enable Bunny Hop"),
  edge_jump_enable = ui.new_checkbox("LEGIT", "Other", "Enable Edge Jump"),
  aa_enable = ui.new_checkbox("LEGIT", "Other", "Enable Anti-Aim"),
  aimbot_fov = ui.new_slider("LEGIT", "Aimbot", "FOV", 1, 180, 30, true, "°"),
  aimbot_hitboxes = ui.new_multiselect("LEGIT", "Aimbot", "Hitboxes", {"Head", "Neck", "Chest"}),
  trigger_delay = ui.new_slider("LEGIT", "Triggerbot", "Delay", 0, 200, 50, true, "ms"),
  aa_type = ui.new_combobox("LEGIT", "Other", "AA Type", {"None", "Jitter", "Sway"})
}

local function is_enabled(tab) return ui.get(tab) end
local function get_hitbox_id(name) local hitboxes = {Head=0, Neck=1, Chest=2, Stomach=3} return hitboxes[name] or 0 end
local function normalize_angle(angle) angle = angle % 360 if angle > 180 then angle = angle - 360 end if angle < -180 then angle = angle + 360 end return angle end
local function calculate_angle(local_x, local_y, local_z, target_x, target_y, target_z)
  local delta_x = target_x - local_x
  local delta_y = target_y - local_y
  local delta_z = target_z - local_z
  local hyp = math.sqrt(delta_x * delta_x + delta_y * delta_y)
  local pitch = -math.deg(math.atan(delta_z / hyp))
  local yaw = math.deg(math.atan2(delta_y, delta_x))
  return pitch, yaw
end

local function run_silent_aim(cmd)
  if not is_enabled(menu.aimbot_enable) then return end
  local local_player = entity.get_local_player()
  if not local_player or not entity.is_alive(local_player) then return end
  local weapon = entity.get_player_weapon(local_player)
  if not weapon then return end

  local best_target, best_fov = nil, ui.get(menu.aimbot_fov)
  local local_x, local_y, local_z = client.eye_position()
  local pitch, yaw = client.camera_angles()
  if not yaw or not pitch then return end

  local players = entity.get_players(true)
  for _, player in ipairs(players) do
    if player ~= local_player and entity.is_alive(player) then
      for _, hitbox_name in ipairs(ui.get(menu.aimbot_hitboxes)) do
        local hitbox = get_hitbox_id(hitbox_name)
        local x, y, z = entity.hitbox_position(player, hitbox)
        if x then
          local target_pitch, target_yaw = calculate_angle(local_x, local_y, local_z, x, y, z)
          local delta_yaw = normalize_angle(target_yaw - yaw)
          local delta_pitch = normalize_angle(target_pitch - pitch)
          local current_fov = math.sqrt(delta_yaw * delta_yaw + delta_pitch * delta_pitch)
          if current_fov < best_fov then
            best_fov = current_fov
            best_target = {x = x, y = y, z = z}
          end
        end
      end
    end
  end

  if best_target then
    local smooth = 0.1
    local target_pitch, target_yaw = calculate_angle(local_x, local_y, local_z, best_target.x, best_target.y, best_target.z)
    cmd.pitch = cmd.pitch + (target_pitch - cmd.pitch) * (1 - smooth)
    cmd.yaw = normalize_angle(cmd.yaw + (target_yaw - cmd.yaw) * (1 - smooth))
  end
end

local triggerbot = { last_shot = 0, hitbox_ids = {Head=0, Neck=1, Chest=2, Stomach=3} }
local function run_triggerbot(cmd)
  if not is_enabled(menu.trigger_enable) then return end
  local local_player = entity.get_local_player()
  if not local_player or not entity.is_alive(local_player) then return end
  local weapon = entity.get_player_weapon(local_player)
  if not weapon then return end

  local next_attack = entity.get_prop(weapon, "m_flNextPrimaryAttack")
  if next_attack and next_attack > globals.curtime() then return end

  local camera_x, camera_y, camera_z = client.eye_position()
  local pitch, yaw = client.camera_angles()
  if not pitch or not yaw then return end

  local cos_pitch = math.cos(math.rad(pitch))
  local sin_yaw, cos_yaw = math.sin(math.rad(yaw)), math.cos(math.rad(yaw))
  local forward = {x = cos_yaw * cos_pitch, y = sin_yaw * cos_pitch, z = -math.sin(math.rad(pitch))}
  local end_x, end_y, end_z = camera_x + forward.x * 8192, camera_y + forward.y * 8192, camera_z + forward.z * 8192

  local hit_entity, hit_hitbox = client.trace_line(local_player, camera_x, camera_y, camera_z, end_x, end_y, end_z)
  if hit_entity and hit_entity ~= 0 and hit_entity ~= local_player then
    if entity.is_enemy(hit_entity) then
      for _, hitbox_name in ipairs(ui.get(menu.aimbot_hitboxes)) do
        if triggerbot.hitbox_ids[hitbox_name] == hit_hitbox then
          local delay = ui.get(menu.trigger_delay)
          if globals.curtime() * 1000 - triggerbot.last_shot >= delay then
            cmd.in_attack = 1
            triggerbot.last_shot = globals.curtime() * 1000
          end
          break
        end
      end
    end
  end
end

local function run_bhop(cmd)
  if not is_enabled(menu.bhop_enable) then return end
  local local_player = entity.get_local_player()
  if not local_player or not entity.is_alive(local_player) then return end
  local flags = entity.get_prop(local_player, "m_fFlags")
  if bit.band(flags, 1) == 0 and cmd.in_jump == 1 then
    cmd.in_jump = 0
  elseif bit.band(flags, 1) == 1 and cmd.in_jump == 1 then
    cmd.in_jump = 1
  end
end

local function run_antiaim(cmd)
  if not is_enabled(menu.aa_enable) or is_enabled(menu.aimbot_enable) then return end
  local local_player = entity.get_local_player()
  if not local_player or not entity.is_alive(local_player) then return end
  local yaw = cmd.yaw or select(2, client.camera_angles())
  local aa_type = ui.get(menu.aa_type)
  if aa_type == "Jitter" then
    yaw = yaw + (globals.tickcount() % 2 == 0 and 15 or -15)
  elseif aa_type == "Sway" then
    yaw = yaw + math.sin(globals.curtime()) * 30
  end
  cmd.yaw = normalize_angle(yaw)
end

local function run_edge_jump(cmd)
  if not is_enabled(menu.edge_jump_enable) then return end
  local local_player = entity.get_local_player()
  if not local_player or not entity.is_alive(local_player) then return end
  local flags = entity.get_prop(local_player, "m_fFlags")
  if bit.band(flags, 1) == 1 and cmd.in_jump == 1 then
    local origin = {entity.get_prop(local_player, "m_vecOrigin")}
    local view_z = select(3, client.eye_position())
    local trace_end_z = origin[3] - 10
    local fraction, ent = client.trace_line(local_player, origin[1], origin[2], view_z, origin[1], origin[2], trace_end_z)
    if fraction < 1 and ent == 0 then
      cmd.in_jump = 1
    end
  end
end

client.set_event_callback("setup_command", function(cmd)
  run_silent_aim(cmd)
  run_triggerbot(cmd)
  run_bhop(cmd)
  run_antiaim(cmd)
  run_edge_jump(cmd)
end)

-- Menu configuration for AI Rage Tips
local ai_rage_tips_menu = {
  enable = ui.new_checkbox("RAGE", "Other", "Enable AI Rage Tips"),
  tip_frequency = ui.new_slider("RAGE", "Other", "Tip Frequency", 3, 30, 5, true, "s", 1),
  tip_categories = ui.new_multiselect("RAGE", "Other", "Tip Categories", {"Aimbot", "Anti-Aim", "Resolver", "Quick Peek", "Positioning", "Exploits"}),
  debug_tips = ui.new_checkbox("RAGE", "Other", "Debug AI Rage Tips"),
  aggression_level = ui.new_slider("RAGE", "Other", "Aggression Level", 1, 10, 5, true, "", 1, {"Safe", "Moderate", "Aggressive"}),
  priority_tips = ui.new_checkbox("RAGE", "Other", "Prioritize Critical Tips"),
  notification_style = ui.new_combobox("RAGE", "Other", "Notification Style", {"Console", "Screen", "Both"})
}

-- Handler for menu visibility
local function ai_rage_tips_menu_handler()
  local enable = ui.get(ai_rage_tips_menu.enable)
  ui.set_visible(ai_rage_tips_menu.tip_frequency, enable)
  ui.set_visible(ai_rage_tips_menu.tip_categories, enable)
  ui.set_visible(ai_rage_tips_menu.debug_tips, enable)
  ui.set_visible(ai_rage_tips_menu.aggression_level, enable)
  ui.set_visible(ai_rage_tips_menu.priority_tips, enable)
  ui.set_visible(ai_rage_tips_menu.notification_style, enable)
end

-- Bind handler to menu elements
ui.set_callback(ai_rage_tips_menu.enable, ai_rage_tips_menu_handler)
ui.set_callback(ai_rage_tips_menu.tip_frequency, ai_rage_tips_menu_handler)
ui.set_callback(ai_rage_tips_menu.tip_categories, ai_rage_tips_menu_handler)
ui.set_callback(ai_rage_tips_menu.debug_tips, ai_rage_tips_menu_handler)
ui.set_callback(ai_rage_tips_menu.aggression_level, ai_rage_tips_menu_handler)
ui.set_callback(ai_rage_tips_menu.priority_tips, ai_rage_tips_menu_handler)
ui.set_callback(ai_rage_tips_menu.notification_style, ai_rage_tips_menu_handler)
ai_rage_tips_menu_handler()

-- Utility function to check if a value exists in a table
local function includes(table, value)
  for _, v in ipairs(table) do
    if v == value then return true end
  end
  return false
end

-- Main AI Rage Tips object
local ai_rage_tips = {
  last_tip_time = 0,
  -- Tip database with priorities (1 = low, 3 = high)
  tips = {
    Aimbot = {
      {condition = function(data) return data.enemy_health <= 30 end, tip = "Enemy low HP, aim for head with Aimbot!", priority = 3},
      {condition = function(data) return data.distance < 400 end, tip = "Close enemy, reduce Minimum Damage in Aimbot!", priority = 2},
      {condition = function(data) return data.distance > 1500 and data.is_enemy_sniper end, tip = "Long-range sniper, enable Multipoint in Aimbot!", priority = 2},
      {condition = function(data) return data.player_health < 50 end, tip = "Your HP is low, maximize Aimbot Damage!", priority = 3},
      {condition = function(data) return data.is_enemy_sniper end, tip = "Enemy sniper, prioritize Head in Aimbot!", priority = 2}
    },
    ["Anti-Aim"] = {
      {condition = function(data) return data.enemy_health > 80 and data.ping < 50 end, tip = "Strong enemy with low ping, max out Desync!", priority = 2},
      {condition = function(data) return data.enemy_count > 2 end, tip = "Multiple enemies, use Random Yaw in Anti-Aim!", priority = 2},
      {condition = function(data) return data.is_enemy_sniper and data.distance > 1000 end, tip = "Sniper at range, enable Jitter in Anti-Aim!", priority = 2},
      {condition = function(data) return data.is_in_air end, tip = "You're airborne, enable Anti-Aim Freestanding!", priority = 3},
      {condition = function(data) return data.is_open_area end, tip = "Open area, use Freestanding Anti-Aim!", priority = 2}
    },
    Resolver = {
      {condition = function(data) return data.ping > 100 end, tip = "High enemy ping, enable Resolver for accurate AA!", priority = 2},
      {condition = function(data) return data.enemy_health < 50 end, tip = "Weak enemy, Resolver will help finish them!", priority = 2},
      {condition = function(data) return data.is_enemy_sniper end, tip = "Sniper enemy, use Resolver to bypass AA!", priority = 2}
    },
    ["Quick Peek"] = {
      {condition = function(data) return data.distance < 500 and data.player_health > 80 end, tip = "Peek with Quick Peek, you're in a strong position!", priority = 2},
      {condition = function(data) return data.player_health < 30 end, tip = "Низкое HP, не пикать, даже с Быстрым пиком!", priority = 3},
      {condition = function(data) return data.enemy_count > 2 end, tip = "Multiple enemies, use Quick Peek cautiously!", priority = 2},
      {condition = function(data) return data.is_close_area end, tip = "Tight area, set Quick Peek to minimal radius!", priority = 2}
    },
    Positioning = {
      {condition = function(data) return data.distance > 1000 and data.player_health < 50 end, tip = "Don't peek, your HP is too low!", priority = 3},
      {condition = function(data) return data.distance < 400 and data.player_health > 80 and data.aggression_level > 7 end, tip = "Enemy close, push with DT and Aimbot!", priority = 2},
      {condition = function(data) return data.enemy_count > 3 end, tip = "Too many enemies, retreat to cover!", priority = 3},
      {condition = function(data) return data.is_open_area and data.distance > 1500 end, tip = "Open area, stick to cover and avoid pushing!", priority = 2},
      {condition = function(data) return data.is_elevated end, tip = "You're elevated, push with Quick Peek and Aimbot!", priority = 2}
    },
    Exploits = {
      {condition = function(data) return data.player_health > 90 and data.enemy_health < 40 end, tip = "You're strong, push with Hideshots and DT!", priority = 2},
      {condition = function(data) return data.ping > 150 end, tip = "High enemy ping, use Fakelag for exploits!", priority = 2},
      {condition = function(data) return data.enemy_weapon == "weapon_knife" end, tip = "Enemy with knife, enable Backstab Anti-Aim!", priority = 3},
      {condition = function(data) return data.aggression_level > 8 end, tip = "Max aggression, spam DT and Hideshots!", priority = 2}
    }
  },
  -- Get nearest enemy and distance
  get_nearest_enemy = function()
    local me = entity.get_local_player()
    if not me or not entity.is_alive(me) then return nil, math.huge end

    local my_pos = vector(entity.get_origin(me))
    local players = entity.get_players(true)
    local nearest_enemy = nil
    local min_distance = math.huge

    for _, player in ipairs(players) do
      if entity.is_alive(player) then
        local enemy_pos = vector(entity.get_origin(player))
        local distance = my_pos:dist2d(enemy_pos)
        if distance < min_distance then
          min_distance = distance
          nearest_enemy = player
        end
      end
    end

    return nearest_enemy, min_distance
  end,
  -- Detect environment type (open or tight area)
  get_environment_type = function()
    local me = entity.get_local_player()
    if not me then return false, false end
    local my_pos = vector(entity.get_origin(me))
    local trace = client.trace_bullet(me, my_pos.x, my_pos.y, my_pos.z, my_pos.x + 1000, my_pos.y, my_pos.z)
    local is_open_area = trace and trace.fraction > 0.8
    local is_close_area = trace and trace.fraction < 0.3
    return is_open_area, is_close_area
  end,
  -- Draw notification on screen or console
  draw_notification = function(self, tip)
    if type(tip) ~= "string" then
      tip = "Error: Invalid tip format."
      client.log("[AI Rage Tips Error] Tip is not a string: " .. tostring(tip))
    end
    local style = ui.get(ai_rage_tips_menu.notification_style)
    if style == "Screen" or style == "Both" then
      local screen_w, screen_h = client.screen_size()
      local text_w, text_h = renderer.measure_text("default", tip)
      local x, y = screen_w / 2 - text_w / 2, screen_h * 0.2
      renderer.rectangle(x - 10, y - 10, text_w + 20, text_h + 20, 0, 0, 0, 200)
      renderer.text(x, y, 255, 255, 255, 255, "default", 0, tip)
    end
    if style == "Console" or style == "Both" then
      if notify and notify.create_new then
        notify.create_new({{"AI Rage Tip: "}, {tip, true}})
      else
        client.log("[AI Rage Tips] " .. tip)
      end
    end
    if ui.get(ai_rage_tips_menu.debug_tips) then
      client.color_log(0, 255, 0, "[AI Rage Tips] " .. tip)
    end
  end,
  -- Main logic to run tips
  run = function(self)
    if not ui.get(ai_rage_tips_menu.enable) then return end
    local current_time = globals.curtime()
    local tip_interval = ui.get(ai_rage_tips_menu.tip_frequency)
    if current_time - self.last_tip_time < tip_interval then return end

    local me = entity.get_local_player()
    if not me or not entity.is_alive(me) then return end

    local selected_categories = ui.get(ai_rage_tips_menu.tip_categories)
    if #selected_categories == 0 then
      self:draw_notification("No categories selected.")
      return
    end

    -- Gather game state data
    local nearest_enemy, distance = self:get_nearest_enemy()
    if not nearest_enemy then
      self:draw_notification("No enemies nearby.")
      self.last_tip_time = current_time
      return
    end

    local velocity = vector(entity.get_prop(me, "m_vecVelocity")):length2d() or 0
    local is_in_air = bit.band(entity.get_prop(me, "m_fFlags") or 0, 1) == 0
    local player_health = entity.get_prop(me, "m_iHealth") or 100
    local enemy_health = entity.get_prop(nearest_enemy, "m_iHealth") or 100
    local enemy_weapon = entity.get_player_weapon(nearest_enemy)
    local enemy_weapon_name = enemy_weapon and entity.get_classname(enemy_weapon):lower() or "unknown"
    local is_enemy_sniper = enemy_weapon_name:find("sniper") ~= nil
    local ping = entity.get_prop(nearest_enemy, "m_iPing") or 0
    local enemy_count = #entity.get_players(true)
    local aggression_level = ui.get(ai_rage_tips_menu.aggression_level)
    local is_open_area, is_close_area = self:get_environment_type()
    local my_pos_z = select(3, entity.get_origin(me)) or 0
    local enemy_pos_z = select(3, entity.get_origin(nearest_enemy)) or 0
    local is_elevated = my_pos_z > enemy_pos_z + 32

    -- Compile game state for analysis
    local game_state = {
      velocity = velocity,
      is_in_air = is_in_air,
      distance = distance,
      player_health = player_health,
      enemy_health = enemy_health,
      ping = ping,
      is_enemy_sniper = is_enemy_sniper,
      enemy_count = enemy_count,
      aggression_level = aggression_level,
      is_open_area = is_open_area,
      is_close_area = is_close_area,
      is_elevated = is_elevated,
      enemy_weapon = enemy_weapon_name
    }

    -- Collect available tips
    local available_tips = {}
    for _, category in ipairs(selected_categories) do
      if self.tips[category] then
        for _, tip_data in ipairs(self.tips[category]) do
          if tip_data.condition(game_state) then
            table.insert(available_tips, {tip = tip_data.tip, priority = tip_data.priority})
          end
        end
      end
    end

    -- Filter high-priority tips if enabled
    if ui.get(ai_rage_tips_menu.priority_tips) then
      local high_priority_tips = {}
      for _, tip_data in ipairs(available_tips) do
        if tip_data.priority >= 3 then
          table.insert(high_priority_tips, tip_data)
        end
      end
      if #high_priority_tips > 0 then
        available_tips = high_priority_tips
      end
    end

    -- Select and display a random tip
    local selected_tip = #available_tips > 0 and available_tips[math.random(#available_tips)] or {tip = "No suitable tips available.", priority = 1}
    if type(selected_tip.tip) ~= "string" then
      client.log("[AI Rage Tips Error] Selected tip is not a string: " .. tostring(selected_tip.tip))
      selected_tip.tip = "Error: Invalid tip format."
    end
    self:draw_notification(selected_tip.tip)
    self.last_tip_time = current_time
  end
}

-- Register event handler
client.set_event_callback("paint", function()
  local success, err = pcall(ai_rage_tips.run, ai_rage_tips)
  if not success then
    client.log("[AI Rage Tips Error] " .. err)
  end
end)


-- Menu configuration for kill messages
local kill_messages_menu = {
    enable = ui.new_checkbox("MISC", "Settings", "Kill Messages", false)
}

-- Kill message management
local kill_messages = {
    messages = {},
    hit_counts = {}, -- Track hits per player
    max_display_time = 5, -- Seconds to display each message
    max_messages = 5, -- Max number of messages to show at once
    -- Add a new kill message
    add = function(self, message)
        table.insert(self.messages, { text = message, time = globals.curtime() })
        if #self.messages > self.max_messages then
            table.remove(self.messages, 1)
        end
    end,
    -- Draw messages in bottom-right corner
    draw = function(self)
        if not ui.get(kill_messages_menu.enable) then return end

        local screen_w, screen_h = client.screen_size()
        if not screen_w or not screen_h or screen_w <= 0 or screen_h <= 0 then
            client.log("Error: Invalid screen size (" .. tostring(screen_w) .. "x" .. tostring(screen_h) .. ")")
            return
        end

        local y_offset = screen_h - 50 -- Start near bottom-right
        -- Iterate backwards to safely remove expired messages
        for i = #self.messages, 1, -1 do
            local msg = self.messages[i]
            local time_elapsed = globals.curtime() - msg.time
            if time_elapsed < self.max_display_time then
                local alpha = math.min(255, 255 * (1 - time_elapsed / self.max_display_time))
                local text_w, text_h = renderer.measure_text("default", msg.text)
                if not text_w or not text_h then
                    client.log("Error: Failed to measure text for message: " .. tostring(msg.text))
                    return
                end
                local x = screen_w - text_w - 20
                local y = y_offset - ((#self.messages - i) * (text_h + 10))
                renderer.rectangle(x - 10, y - 5, text_w + 20, text_h + 10, 0, 0, 0, math.floor(alpha * 0.8))
                renderer.text(x, y, 255, 255, 255, math.floor(alpha), "default", 0, msg.text)
            else
                table.remove(self.messages, i)
            end
        end
    end
}


-- Track hits on players
client.set_event_callback("player_hurt", function(e)
    local attacker = entity.get_local_player()
    if not attacker or e.attacker ~= client.userid_to_entindex(e.attacker) then return end

    local victim = client.userid_to_entindex(e.userid)
    if not victim or not entity.is_alive(victim) then return end

    local victim_id = e.userid
    kill_messages.hit_counts[victim_id] = (kill_messages.hit_counts[victim_id] or 0) + 1
end)

-- Handle player death to create kill messages
client.set_event_callback("player_death", function(e)
    if not ui.get(kill_messages_menu.enable) then return end

    local attacker = entity.get_local_player()
    if not attacker or e.attacker ~= client.userid_to_entindex(e.attacker) then return end

    local victim = client.userid_to_entindex(e.userid)
    if not victim then return end

    local victim_name = entity.get_player_name(victim) or "Unknown"
    local damage = e.dmg_health or 0
    local hitgroup = e.hitgroup or 0
    local hit_count = kill_messages.hit_counts[e.userid] or 1
    local bullet_time = 1 -- Placeholder for bullet time (bt)

    -- Map hitgroup to readable name
    local hitgroup_names = {
        [0] = "body",
        [1] = "head",
        [2] = "chest",
        [3] = "stomach",
        [4] = "left arm",
        [5] = "right arm",
        [6] = "left leg",
        [7] = "right leg"
    }
    local hitgroup_name = hitgroup_names[hitgroup] or "body"

    -- Format the kill message
    local message = string.format("Killed %s in %s (dmg: %d) (hc: %d) (bt: %d)", 
        victim_name, hitgroup_name, damage, hit_count, bullet_time)
    kill_messages:add(message)

    -- Reset hit count for the victim
    kill_messages.hit_counts[e.userid] = nil
end)

-- Draw kill messages on paint
client.set_event_callback("paint", function()
    local success, err = pcall(kill_messages.draw, kill_messages)
    if not success then
        client.log("[Kill Messages Error] " .. tostring(err))
    end
end)

local enable_resolver = ui.new_checkbox("RAGE", "Other", "Resolver")


json.encode_number_precision(6)
json.encode_sparse_array(true, 2, 10)

local resolver = {
  history = {},
  player_records = {},
  last_simulation_time = {}
}

local function get_targets()
  return entity.get_players(true)
end

local function get_hitbox_position(player, hitbox)
  local x, y, z = entity.hitbox_position(player, hitbox)
  return x and {x = x, y = y, z = z} or nil
end

function resolver.record_player(player)
  if not entity.is_alive(player) then return end

  local steam_id = entity.get_steam64(player)
  if not steam_id then return end

  if not resolver.player_records[steam_id] then
      resolver.player_records[steam_id] = {
          last_angles = {},
          desync_history = {},
          shot_records = {},
          missed_shots = 0,
          learned_side = nil
      }
  end

  local sim_time = entity.get_prop(player, "m_flSimulationTime")
  local eye_angles = {entity.get_prop(player, "m_angEyeAngles")}

  if sim_time ~= resolver.last_simulation_time[steam_id] then
      table.insert(resolver.player_records[steam_id].last_angles, {
          angles = eye_angles,
          sim_time = sim_time,
          hitbox_pos = get_hitbox_position(player, 0)
      })

      if #resolver.player_records[steam_id].last_angles > 8 then
          table.remove(resolver.player_records[steam_id].last_angles, 1)
      end

      resolver.last_simulation_time[steam_id] = sim_time
  end
end

function resolver.resolve_angles(player)
  local steam_id = entity.get_steam64(player)
  if not steam_id or not resolver.player_records[steam_id] then return end

  local records = resolver.player_records[steam_id]
  if #records.last_angles < 2 then return end

  local angle_delta = records.last_angles[#records.last_angles].angles[2] - records.last_angles[#records.last_angles - 1].angles[2]
  local desync_side = angle_delta > 0 and 1 or -1
  table.insert(records.desync_history, desync_side)

  if #records.desync_history > 5 then
      table.remove(records.desync_history, 1)
  end


  local resolve_angle = records.last_angles[#records.last_angles].angles[2]
  if records.learned_side then
      resolve_angle = resolve_angle + (58 * records.learned_side)
  end


  if #records.desync_history >= 5 then
      local side_count = 0
      for _, side in ipairs(records.desync_history) do
          side_count = side_count + side
      end
      if side_count > 0 then
          records.learned_side = 1
      else
          records.learned_side = -1
      end
  end

  return resolve_angle
end

function resolver.on_shot_fired(e)
  local target = e.target
  if not target then return end

  local steam_id = entity.get_steam64(target)
  if not steam_id or not resolver.player_records[steam_id] then return end

  table.insert(resolver.player_records[steam_id].shot_records, {
      tick = e.tick,
      predicted_angle = resolver.player_records[steam_id].last_angles[#resolver.player_records[steam_id].last_angles],
      hit = e.hit,
      teleported = e.teleported
  })

  if not e.hit then
      resolver.player_records[steam_id].missed_shots = resolver.player_records[steam_id].missed_shots + 1
  else
      resolver.player_records[steam_id].missed_shots = 0
  end
end

local last_update = globals.realtime()
function resolver.update()

  if not ui.get(enable_resolver) then return end

  if globals.realtime() - last_update < 0.1 then return end
  last_update = globals.realtime()

  local targets = get_targets()
  for _, player in ipairs(targets) do
      resolver.record_player(player)
      local resolved_angle = resolver.resolve_angles(player)

      if resolved_angle then
          plist.set(player, "Force body yaw value", resolved_angle)
      end
  end
end

client.set_event_callback("paint", resolver.update)
client.set_event_callback("aim_fire", resolver.on_shot_fired)


local function initdb()
	if database.read(databas.cfgs) == nil then 
		database.write(databas.cfgs, {})
	end

	local loads = database.read(databas.load)
	local kills = database.read(databas.kill)

	if loads == nil then
		loads = 0
	end

	loads = loads + 1
	database.write(databas.load, loads)

	if kills == nil then
		kills = 0
	end

	database.write(databas.kill, kills)
end; initdb()

local render = {
	anim = {},

	logo = function(self, da)
		local big = renderer.load_png("https://i.postimg.cc/QMJ1WNpP/photo-2025-07-27-14-53-53-2.png", 29, 29)
		local small = renderer.load_png("https://i.postimg.cc/wjL42JH3/photo-2025-07-27-14-53-53-2.png", 19, 19)
		local icon = da and big or small
		local pixel = da and {29,29} or {19,19}

		return icon, unpack(pixel)
	end,

	clamp = function(self, value, minimum, maximum)
        if minimum > maximum then 
			minimum, maximum = maximum, minimum 
		end

        return math.max(minimum, math.min(maximum, value))
	end,

	alphen = function(self, value)
        return math.max(0, math.min(255, value))
	end,

	lerp = function(self, a, b, speed)
		return (b - a) * speed + a
	end,

	math_anim2 = function(self, start, end_pos, speed)
		speed = self:clamp(globals.frametime() * ((speed / 100) or 0.08) * 175.0, 0.01, 1.0)

		local a = self:lerp(start, end_pos, speed)

		return tonumber(string.format("%.3f", a))
	end,

	new_anim = function(self, name, value, speed)

		if self.anim[name] == nil then
			self.anim[name] = value
		end
		
		local animation = self:math_anim2(self.anim[name], value, speed)

		self.anim[name] = animation

		return self.anim[name]
	end,

	rect = function(self, x, y, w, h, clr, rounding)
		local r, g, b, a = unpack(clr)

		renderer.circle(x + rounding, y + rounding, r, g, b, a, rounding, 180, 0.25)
		renderer.rectangle(x + rounding, y, w - rounding - rounding, rounding, r, g, b, a)
		renderer.circle(x + w - rounding, y + rounding, r, g, b, a, rounding, 90, 0.25)
		renderer.rectangle(x, y + rounding, w, h - rounding*2, r, g, b, a)
		renderer.circle(x + rounding, y + h - rounding, r, g, b, a, rounding, 270, 0.25)
		renderer.rectangle(x + rounding, y + h - rounding, w - rounding - rounding, rounding, r, g, b, a)
		renderer.circle(x + w - rounding, y + h - rounding, r, g, b, a, rounding, 0, 0.25)
	end,

	rectv = function(self, x, y, w, h, clr, rounding, clr2, h2)
		local r, g, b, a = unpack(clr)
		local r1, g1, b1, a1

		renderer.circle(x + rounding, y + rounding, r, g, b, a, rounding, 180, 0.25)
		renderer.rectangle(x + rounding, y, w - rounding - rounding, rounding, r, g, b, a)
		renderer.circle(x + w - rounding, y + rounding, r, g, b, a, rounding, 90, 0.25)
		renderer.rectangle(x, y + rounding, w, h - rounding, r, g, b, a)

		if clr2 then 
			r1, g1, b1, a1 = unpack(clr2)
			renderer.rectangle(x, y + h, w, h - (h + (h2 or 2)), r1, g1, b1, a1)
		end
	end,

	measuret = function(self, string)
		return renderer.measure_text("a", string)
	end
}




local menu = {
  main_switch = ui.new_checkbox('RAGE', 'Other', 'AI Peek'),
  key = ui.new_hotkey('RAGE', 'Other', 'Peek bot key', true, 0),
  mode = ui.new_combobox('RAGE', 'Other', 'Detection mode', {'Risky', 'Safe'}),
  target = ui.new_combobox('RAGE', 'Other', 'Detection target', {'Current', 'All target'}),
  hitbox = ui.new_multiselect('RAGE', 'Other', 'Detection hitbox', {'Head', 'Neck', 'Chest', 'Stomach', 'Arms', 'Legs', 'Feet'}),
  tick = ui.new_slider('RAGE', 'Other', 'Reserve extrapolate tick', 0, 5, 0),
  unlock = ui.new_checkbox('RAGE', 'Other', 'Unlock camera'),
  segament = ui.new_slider('RAGE', 'Other', 'Segament', 2, 60, 2),
  radius = ui.new_slider('RAGE', 'Other', 'Radius', 0, 250, 50),
  depart = ui.new_slider('RAGE', 'Other', 'Department', 1, 12, 2),
  middle = ui.new_checkbox('RAGE', 'Other', 'Middle point'),
  limit = ui.new_checkbox('RAGE', 'Other', 'Max prediction point limit'),
  limit_num = ui.new_slider('RAGE', 'Other', 'Limit num', 0, 20, 5),
  debugger = ui.new_multiselect('RAGE', 'Other', 'Debugger', {'Line player-predict', 'Line predict-target', 'Fraction detection', 'Base'}),
  color = ui.new_color_picker('RAGE', 'Other', 'Debugger color', 255, 255, 255, 255)
}


local function g_menu_handler()
    local main = menu.main_switch
    for i, o in pairs(menu) do
        ui.set_visible(o, ui.get(main))
    end
    ui.set_visible(menu.limit_num, ui.get(main) and ui.get(menu.limit))
    ui.set_visible(main, true)
end

g_menu_handler()
for i, o in pairs(menu) do
    ui.set_callback(o, g_menu_handler)
end

local includes = function(table, key)
    for i = 1, #table do
        if table[i] == key then
            return true
        end
    end
    return false
end

local function extrapolate(player, ticks, x, y, z)
    local xv, yv, zv = entity.get_prop(player, "m_vecVelocity")
    local new_x = x + globals.tickinterval() * xv * ticks
    local new_y = y + globals.tickinterval() * yv * ticks
    local new_z = z + globals.tickinterval() * zv * ticks
    return new_x, new_y, new_z
end

local is_in_air = function(player)
    return bit.band(entity.get_prop(player, "m_fFlags"), 1) == 0
end

local r, g, b, a = 255, 255, 255, 255
local my_old_view = vector(0, 0, 0)
local my_old_vec = vector(0, 0, 0)
local minimum_damage = ui.reference('RAGE', 'Aimbot', 'Minimum damage')
local quick_peek_assist = { ui.reference("RAGE", "Other", "Quick peek assist") }
local quick_peek_assist_mode = { ui.reference("RAGE", "Other", "Quick peek assist mode") }

local function init_old()
    local me = entity.get_local_player()
    if me == nil then
        return
    end
    local pitch, yaw = client.camera_angles()
    my_old_view = vector(pitch, yaw, 0)
    local x, y, z = entity.hitbox_position(me, 3)
    my_old_vec = vector(x, y, z)
end

local IS_WORKING = false
local WORKING_VEC = my_old_vec

local function vector_angles(x1, y1, z1, x2, y2, z2)
    local origin_x, origin_y, origin_z
    local target_x, target_y, target_z
    if x2 == nil then
        target_x, target_y, target_z = x1, y1, z1
        origin_x, origin_y, origin_z = client.eye_position()
        if origin_x == nil then
            return
        end
    else
        origin_x, origin_y, origin_z = x1, y1, z1
        target_x, target_y, target_z = x2, y2, z2
    end

    local delta_x, delta_y, delta_z = target_x - origin_x, target_y - origin_y, target_z - origin_z
    if delta_x == 0 and delta_y == 0 then
        return (delta_z > 0 and 270 or 90), 0
    else
        local yaw = math.deg(math.atan2(delta_y, delta_x))
        local hyp = math.sqrt(delta_x * delta_x + delta_y * delta_y)
        local pitch = math.deg(math.atan2(-delta_z, hyp))
        return pitch, yaw
    end
end

local function get_view_point(radius, v, vec)
    local me = entity.get_local_player()
    local eye_pos = vec
    local viewangle = my_old_view
    local a_vec = eye_pos + vector(0, 0, 0):init_from_angles(0, (90 + viewangle.y + radius), 0) * v
    return a_vec
end

local function get_predict_point(radius, segament, vec)
    local points = {}
    local me = entity.get_local_player()
    local my_vec = vec
    segament = math.max(2, math.floor(segament))
    local angles_pre_point = 360 / segament
    for i = 0, 360, angles_pre_point do
        local m_p = get_view_point(i, radius, my_vec)
        table.insert(points, m_p)
    end
    return points
end

local function get_depart_point(vec, my_vec, department, limit_vec)
    local vec_1 = vector(vec.x, vec.y, 0)
    local vec_2 = vector(my_vec.x, my_vec.y, 0)
    local vec_3 = vector(limit_vec.x, limit_vec.y, 0)

    local each_plus = (vec_1 - vec_2) / department
    local limit_vec_cal = (vec_3 - vec_2):length()

    local points = {}

    for i = 1, department do
        local add_vec = each_plus * i
        if add_vec:length() < limit_vec_cal then
            table.insert(points, my_vec + add_vec)
        end
    end

    return points
end

local function endpos(origin, dest)
    local local_player = entity.get_local_player()
    local tr = trace.line(origin, dest, { skip = local_player })
    local endpos = tr.end_pos
    return endpos, tr.fraction
end

local function draw_circle_3d(x, y, z, radius, r, g, b, a, accuracy, width, outline, start_degrees, percentage, fill_r, fill_g, fill_b, fill_a)
    local accuracy = accuracy ~= nil and accuracy or 3
    local width = width ~= nil and width or 1
    local outline = outline ~= nil and outline or false
    local start_degrees = start_degrees ~= nil and start_degrees or 0
    local percentage = percentage ~= nil and percentage or 1

    local center_x, center_y
    if fill_a then
        center_x, center_y = renderer.world_to_screen(x, y, z)
    end

    local screen_x_line_old, screen_y_line_old
    for rot = start_degrees, percentage * 360, accuracy do
        local rot_temp = math.rad(rot)
        local lineX, lineY, lineZ = radius * math.cos(rot_temp) + x, radius * math.sin(rot_temp) + y, z
        local screen_x_line, screen_y_line = renderer.world_to_screen(lineX, lineY, lineZ)
        if screen_x_line ~= nil and screen_x_line_old ~= nil then
            if fill_a and center_x ~= nil then
                renderer.triangle(screen_x_line, screen_y_line, screen_x_line_old, screen_y_line_old, center_x, center_y, fill_r, fill_g, fill_b, fill_a)
            end
            for i = 1, width do
                local i = i - 1
                renderer.line(screen_x_line, screen_y_line - i, screen_x_line_old, screen_y_line_old - i, r, g, b, a)
                renderer.line(screen_x_line - 1, screen_y_line, screen_x_line_old - i, screen_y_line_old, r, g, b, a)
            end
            if outline then
                local outline_a = a / 255 * 160
                renderer.line(screen_x_line, screen_y_line - width, screen_x_line_old, screen_y_line_old - width, 16, 16, 16, outline_a)
                renderer.line(screen_x_line, screen_y_line + 1, screen_x_line_old, screen_y_line_old + 1, 16, 16, 16, outline_a)
            end
        end
        screen_x_line_old, screen_y_line_old = screen_x_line, screen_y_line
    end
end

local function calculate_end_pos(draw_line, draw_circle, debug_fraction, vec, my_vec)
    local me = entity.get_local_player()
    local dx, dy, dz = entity.get_origin(me)
    local debug_vec = vector(my_vec.x, my_vec.y, dz + 5)
    local debug_vec_2 = vector(vec.x, vec.y, dz + 5)
    local pos_1, fraction_1 = endpos(my_vec, vec)
    local pos_2, fraction_2 = endpos(debug_vec, debug_vec_2)

    local end_Pos = vector(pos_2.x, pos_2.y, vec.z)

    if draw_line then
        local x1, y1 = renderer.world_to_screen(pos_2.x, pos_2.y, pos_2.z)
        local x2, y2 = renderer.world_to_screen(debug_vec.x, debug_vec.y, debug_vec.z)
        renderer.line(x1, y1, x2, y2, r, g, b, a)
    end

    if debug_fraction then
        local debug_text = tostring(math.floor(fraction_1) * 100)
        local x3, y3 = renderer.world_to_screen(debug_vec_2.x, debug_vec_2.y, debug_vec_2.z)
        renderer.text(x3, y3, r, g, b, a, 'c', 0, debug_text)
    end

    return end_Pos
end

local function calculate_real_point(draw_line, draw_circle, debug_fraction, vec)
    local points_list = {}
    local me = entity.get_local_player()
    local my_vec = vec
    local points = get_predict_point(ui.get(menu.radius), ui.get(menu.segament), my_vec)

    for i, o in pairs(points) do
        if ui.get(menu.middle) then
            local halfone = points[i + 1]
            halfone = halfone == nil and points[1] or halfone
            local halfpoint = vector((halfone.x + o.x) / 2, (halfone.y + o.y) / 2, o.z)
            local end_pos = calculate_end_pos(draw_line, draw_circle, debug_fraction, halfpoint, my_vec)
            table.insert(points_list, {
                endpos = end_pos,
                ideal = halfpoint
            })
        end
        local end_pos = calculate_end_pos(draw_line, draw_circle, debug_fraction, o, my_vec)
        table.insert(points_list, {
            endpos = end_pos,
            ideal = o
        })
    end

    return points_list
end

local function run_all_Point(debug_line, debug_cir, debug_fraction, department, vec)
    local me = entity.get_local_player()
    local m_points = calculate_real_point(debug_line, debug_cir, debug_fraction, vec)
    local dx, dy, dz = entity.get_origin(me)
    local points = {}
    for i, o in pairs(m_points) do
        local calculate_vec = o.ideal
        local limit_vec = o.endpos
        table.insert(points, limit_vec)
        if debug_cir then
            draw_circle_3d(limit_vec.x, limit_vec.y, dz + 5, 5, r, g, b, a)
        end

        if department ~= 1 then
            for _, depart_vec in pairs(get_depart_point(calculate_vec, vec, department, limit_vec)) do
                table.insert(points, depart_vec)
                if debug_cir then
                    draw_circle_3d(depart_vec.x, depart_vec.y, dz + 5, 5, r, g, b, a)
                end
            end
        end
    end

    return points
end

local function get_peek_hitbox(content)
    local hitbox = {}
    if includes(content, 'Head') then
        table.insert(hitbox, 0)
    end
    if includes(content, 'Neck') then
        table.insert(hitbox, 1)
    end
    if includes(content, 'Chest') then
        table.insert(hitbox, 4)
        table.insert(hitbox, 5)
        table.insert(hitbox, 6)
    end
    if includes(content, 'Stomach') then
        table.insert(hitbox, 2)
        table.insert(hitbox, 3)
    end
    if includes(content, 'Arms') then
        table.insert(hitbox, 13)
        table.insert(hitbox, 14)
        table.insert(hitbox, 15)
        table.insert(hitbox, 16)
        table.insert(hitbox, 17)
        table.insert(hitbox, 18)
    end
    if includes(content, 'Legs') then
        table.insert(hitbox, 7)
        table.insert(hitbox, 8)
        table.insert(hitbox, 9)
        table.insert(hitbox, 10)
    end
    if includes(content, 'Feet') then
        table.insert(hitbox, 11)
        table.insert(hitbox, 12)
    end
    return hitbox
end

local function using_auto_peek()
    return (ui.get(quick_peek_assist[1]) and ui.get(quick_peek_assist[2]))
end

local function aiPeekrunner()
    local predict_tick = ui.get(menu.tick)
    local me = entity.get_local_player()
    if me == nil then return end

    if entity.is_alive(me) == false then
        return
    end

    if ui.get(menu.key) == false then
        return
    end

    local m_x, m_y, m_z = entity.hitbox_position(me, 3)
    local my_vec = vector(m_x, m_y, m_z)

    local mpitch, myaw = client.camera_angles()

    if ui.get(menu.main_switch) == false then
        return
    end

    local debugger = ui.get(menu.debugger)
    local m_points = run_all_Point(
        includes(debugger, 'Line player-predict'),
        includes(debugger, 'Base'),
        includes(debugger, 'Fraction detection'),
        ui.get(menu.depart),
        my_old_vec
    )
    local sort_type = ui.get(menu.mode)
    local p_Hitbox = get_peek_hitbox(ui.get(menu.hitbox))
    local p_List = {}
    if not (ui.get(menu.target) == 'Current') then
        local players = entity.get_players(true)
        if #players == 0 then
            WORKING_VEC = nil
            IS_WORKING = false
            return
        end
        for i, o in pairs(m_points) do
            for _, player in pairs(players) do
                local best_target = player
                for _, v in pairs(p_Hitbox) do
                    local ex, ey, ez = entity.hitbox_position(best_target, v)
                    local new_x, new_y, new_z = extrapolate(best_target, predict_tick, ex, ey, ez)
                    local e_vec = vector(new_x, new_y, new_z)
                    local _, dmg = client.trace_bullet(me, o.x, o.y, o.z, e_vec.x, e_vec.y, e_vec.z)
                    if dmg >= math.min(ui.get(minimum_damage), entity.get_prop(best_target, 'm_iHealth')) then
                        table.insert(p_List, {
                            TARGET = best_target,
                            damage = dmg,
                            vec = o,
                            enemy_vec = e_vec
                        })
                    end
                end
            end

            if ui.get(menu.limit) and #p_List >= ui.get(menu.limit_num) then
                break
            end
        end
    else
        local best_target = client.current_threat()
        if best_target == nil then
            WORKING_VEC = nil
            IS_WORKING = false
            return
        end
        for i, o in pairs(m_points) do
            for k, v in pairs(p_Hitbox) do
                local ex, ey, ez = entity.hitbox_position(best_target, v)
                local new_x, new_y, new_z = extrapolate(best_target, predict_tick, ex, ey, ez)
                local e_vec = vector(new_x, new_y, new_z)
                local _, dmg = client.trace_bullet(me, o.x, o.y, o.z, e_vec.x, e_vec.y, e_vec.z)
                if dmg > math.min(ui.get(minimum_damage), entity.get_prop(best_target, 'm_iHealth')) then
                    table.insert(p_List, {
                        TARGET = best_target,
                        damage = dmg,
                        vec = o,
                        enemy_vec = e_vec
                    })
                end
            end

            if ui.get(menu.limit) and #p_List >= ui.get(menu.limit_num) then
                break
            end
        end
    end

    table.sort(p_List, function(a, b)
        if sort_type == 'Risky' then
            return a.damage > b.damage
        else
            return a.damage < b.damage
        end
    end)

    for i, o in pairs(p_List) do
        if entity.is_alive(o.TARGET) == false then
            table.remove(p_List, i)
        end
    end

    local _, _, debug_point = entity.get_origin(me)
    if #p_List >= 1 then
        local lib = p_List[1]
        local vec = lib.vec
        local damage = lib.damage
        local e_vec = lib.enemy_vec
        local new_debug = vector(vec.x, vec.y, debug_point + 5)
        local x1, y1 = renderer.world_to_screen(new_debug.x, new_debug.y, new_debug.z)
        if includes(debugger, 'Line predict-target') then
            local x2, y2 = renderer.world_to_screen(e_vec.x, e_vec.y, e_vec.z)
            renderer.line(x1, y1, x2, y2, r, g, b, a)
        end

        if y1 ~= nil then
            y1 = y1 - 12
        end

        local render_text = tostring(math.floor(damage))
        renderer.text(x1, y1, r, g, b, a, 0, render_text)
        IS_WORKING = true
        WORKING_VEC = vec
    else
        WORKING_VEC = nil
        IS_WORKING = false
    end
end

local RUN_MOVEMENT = false
local function aiPeekragebot()
    if ui.get(menu.main_switch) == false then
        return
    end

    RUN_MOVEMENT = false
end

local function set_movement(cmd, desired_pos)
    local local_player = entity.get_local_player()
    local x, y, z = entity.get_prop(local_player, "m_vecAbsOrigin")
    local pitch, yaw = vector_angles(x, y, z, desired_pos.x, desired_pos.y, desired_pos.z)
    cmd.in_forward = 1
    cmd.in_back = 0
    cmd.in_moveleft = 0
    cmd.in_moveright = 0
    cmd.in_speed = 0

    cmd.forwardmove = 800
    cmd.sidemove = 0

    cmd.move_yaw = yaw
end

local indr, indg, indb, inda = 255, 255, 255, 255

local function aiPeekretreat(cmd)
    local me = entity.get_local_player()
    if me == nil then
        return
    end

    if ui.get(menu.main_switch) == false then
        return
    end

    if entity.is_alive(me) == false then
        return
    end

    local is_forward = cmd.in_forward == 1
    local is_backward = cmd.in_back == 1
    local is_left = cmd.in_moveleft == 1
    local is_right = cmd.in_moveright == 1

    if ui.get(menu.key) then
        local my_weapon = entity.get_player_weapon(me)
        if my_weapon == nil then
            return
        end

        local in_air = is_in_air(me)
        local timer = globals.curtime()
        local can_Fire = (entity.get_prop(me, "m_flNextAttack") <= timer and entity.get_prop(my_weapon, "m_flNextPrimaryAttack") <= timer)
        local x, y, z = entity.get_origin(me)

        if math.abs(x - my_old_vec.x) <= 10 then
            RUN_MOVEMENT = true
        end

        if can_Fire == false then
            RUN_MOVEMENT = false
        end
        indr, indg, indb, inda = 255, 255, 0, 255
        if IS_WORKING and RUN_MOVEMENT and in_air == false and WORKING_VEC ~= nil then
            set_movement(cmd, WORKING_VEC)
            indr, indg, indb, inda = 0, 255, 0, 255
        elseif RUN_MOVEMENT == false and in_air == false and is_forward == false and is_backward == false and is_left == false and is_right == false then
            set_movement(cmd, my_old_vec)
        end
    else
        indr, indg, indb, inda = 0, 255, 0, 255
    end
end

init_old()

client.set_event_callback("paint", function()
    if ui.get(menu.main_switch) == false then
        return
    end

    renderer.indicator(indr, indg, indb, inda, 'AI PEEK')
end)

client.set_event_callback("paint", aiPeekrunner)
client.set_event_callback("setup_command", aiPeekretreat)

client.set_event_callback("run_command", function()
    local me = entity.get_local_player()
    if me == nil then return end

    if entity.is_alive(me) == false then
        return
    end

    local m_x, m_y, m_z = entity.hitbox_position(me, 3)
    local my_vec = vector(m_x, m_y, m_z)
    local mpitch, myaw = client.camera_angles()

    if ui.get(menu.key) == false or ui.get(menu.unlock) then
        my_old_view = vector(mpitch, myaw, 0)
    end

    if ui.get(menu.key) == false then
        my_old_vec = my_vec
    end
end)


local chat_spam_enabled = ui.new_checkbox("MISC", "Settings", "Enable Chat Spam")
local chat_mode = ui.new_combobox("MISC", "Settings", "Chat Mode", {"Public", "Team"})
local spam_interval = ui.new_slider("MISC", "Settings", "Spam Interval (seconds)", 1, 10, 2, true, "s", 1, { [1] = "1 second" })
local spam_messages = ui.new_textbox("MISC", "Settings", "Custom Spam Messages (one per line)")


local function get_messages()
    local raw_messages = ui.get(spam_messages)
    local messages = {}
    for message in raw_messages:gmatch("[^\r\n]+") do
        table.insert(messages, message)
    end
    return messages
end


local function handle_ui()
    local enabled = ui.get(chat_spam_enabled)
    ui.set_visible(chat_mode, enabled)
    ui.set_visible(spam_interval, enabled)
    ui.set_visible(spam_messages, enabled)
end


handle_ui()
ui.set_callback(chat_spam_enabled, handle_ui)


local last_spam_time = 0
local current_message_index = 1


local function on_paint()
    if not ui.get(chat_spam_enabled) then return end

    local current_time = globals.realtime()
    local interval = ui.get(spam_interval) * 1.0

    if current_time - last_spam_time < interval then return end

    local messages = get_messages()
    if #messages == 0 then return end


    local message = messages[current_message_index]
    current_message_index = (current_message_index % #messages) + 1


    local chat_command = ui.get(chat_mode) == "Team" and "say_team" or "say"
    client.exec(chat_command .. " " .. message)

    last_spam_time = current_time
end


client.set_event_callback("paint", on_paint)


local trails_enabled = ui.new_checkbox("VISUALS", "Player ESP", "Enable Trails")
local trail_color = ui.new_color_picker("VISUALS", "Player ESP", "Trail Color", 93, 240, 235, 255)
local trail_duration = ui.new_slider("VISUALS", "Player ESP", "Trail Duration (seconds)", 1, 10, 3, true, "s", 1)
local trail_frequency = ui.new_slider("VISUALS", "Player ESP", "Trail Update Frequency (Hz)", 1, 60, 30, true, "Hz", 1)


local function handle_ui()
    local enabled = ui.get(trails_enabled)
    ui.set_visible(trail_color, enabled)
    ui.set_visible(trail_duration, enabled)
    ui.set_visible(trail_frequency, enabled)
end


handle_ui()
ui.set_callback(trails_enabled, handle_ui)


local trail_positions = {}
local last_update_time = 0


local function add_trail_position()
    local me = entity.get_local_player()
    if not me or not entity.is_alive(me) then
        return
    end

    local x, y, z = entity.get_origin(me)
    local current_time = globals.realtime()
    table.insert(trail_positions, { x = x, y = y, z = z + 10, time = current_time })
end


local function clean_old_positions()
    local current_time = globals.realtime()
    local duration = ui.get(trail_duration)
    for i = #trail_positions, 1, -1 do
        if current_time - trail_positions[i].time > duration then
            table.remove(trail_positions, i)
        end
    end
end


local function on_paint()
    if not ui.get(trails_enabled) then
        trail_positions = {}
        return
    end

    local me = entity.get_local_player()
    if not me or not entity.is_alive(me) then
        return
    end

    local current_time = globals.realtime()
    local frequency = ui.get(trail_frequency)
    local update_interval = 1 / frequency


    if current_time - last_update_time >= update_interval then
        add_trail_position()
        clean_old_positions()
        last_update_time = current_time
    end


    local r, g, b, a = ui.get(trail_color)


    for i = 2, #trail_positions do
        local prev_pos = trail_positions[i - 1]
        local curr_pos = trail_positions[i]
        local x1, y1 = renderer.world_to_screen(prev_pos.x, prev_pos.y, prev_pos.z)
        local x2, y2 = renderer.world_to_screen(curr_pos.x, curr_pos.y, curr_pos.z)

        if x1 and y1 and x2 and y2 then

            local age = current_time - curr_pos.time
            local alpha = math.max(0, a * (1 - age / ui.get(trail_duration)))
            renderer.line(x1, y1, x2, y2, r, g, b, alpha)
        end
    end
end


client.set_event_callback("paint", on_paint)


local dragging = function(name, base_x, base_y)
    return (function()
        local a = {}
		local magnit = {}	
        local p = {__index = {drag = function(self, ...)
                    local q, r = self:get()
                    local s, t = a.drag(q, r, ...)
                    if q ~= s or r ~= t then
                        self:set(s, t)
                    end
                    return s, t
                end, set = function(self, q, r)
                    local j, k = client.screen_size()
                    ui.set(self.x_reference, q / j * self.res)
                    ui.set(self.y_reference, r / k * self.res)
                end, get = function(self, x333, y333)
                    local j, k = client.screen_size()
                    return ui.get(self.x_reference) / self.res * j + (x333 or 0), ui.get(self.y_reference) / self.res * k + (y333 or 0)
                end}}
        function a.new(u, v, w, x)
            x = x or 10000
            local j, k = client.screen_size()
            local y = ui.new_slider("misc", "settings", "ender::x:" .. u, 0, x, v / j * x)
            local z = ui.new_slider("misc", "settings", "ender::y:" .. u, 0, x, w / k * x)
            ui.set_visible(y, false)
            ui.set_visible(z, false)
            return setmetatable({
				name = u, 
				x_reference = y, 
				y_reference = z, 
				res = x}, p
			)
        end
        function a.drag(x_widget, y_widget, w_w, h_w, alp)
            if globals.framecount() ~= b then
                uii = ui.is_menu_open()
                f, g = d, e
                d, e = ui.mouse_position()
                i = h
                h = client.key_state(0x01) == true
                m = l
                l = {}
                o = n
				magnit[name] = {
					x = false, 
					y = false
				}
                j, k = client.screen_size()
            end

			local held = h and f > x_widget and g > y_widget and f < x_widget + w_w and g < y_widget + h_w
			local held_a = render:new_anim("drag.alpha.held", held and 1 or 0, 8)

            if uii and i ~= nil then
				render:rect(x_widget, y_widget, w_w, h_w, {255, 255, 255, alp}, 6)
				
				if held then 
                    n = true
                    x_widget, y_widget = x_widget + d - f, y_widget + e - g

                    local distance_to_center_x = math.abs(x_widget - (j/2 - (w_w/2)))
					local distance_to_center_y = math.abs(y_widget - (k - 40 - (h_w/2)))

					if distance_to_center_y <= 3 then
						magnit[name].y = true
						y_widget = k - 40 - (h_w/2)
					end

					if distance_to_center_x <= 3 then
						magnit[name].x = true
						x_widget = j/2 - (w_w/2)
					end

                    x_widget = render:clamp(j - w_w, 0, x_widget)
                    y_widget = render:clamp(k - h_w, 0, y_widget)
				end

				if held_a > 0.1 then 
					local ax = render:new_anim("drag.alpha.x:" .. name, held_a * (80 + (magnit[name].x and 90 or 0)), 8)
					local ay = render:new_anim("drag.alpha.y:" .. name, held_a * (80 + (magnit[name].y and 90 or 0)), 8)

					renderer.rectangle(0, 0, j, k, 0, 0, 0, render:alphen(held_a * 120))

					renderer.rectangle(j/2, 0, 1, k, 255, 255, 255, ax)
					renderer.rectangle(0, k - 40, j, 1, 255, 255, 255, ay)
				end
            end
            table.insert(l, {x_widget, y_widget, w_w, h_w})
            return x_widget, y_widget, w_w, h_w
        end
        return a
    end)().new(name, base_x, base_y)
end

local menu = {}
local user_lua = js.MyPersonaAPI.GetName()

local refs = {
	aa = {
		enabled = pui.reference("aa", "anti-aimbot angles", "enabled"),
		pitch = {pui.reference("aa", "anti-aimbot angles", "pitch")},
		yaw_base = {pui.reference("aa", "anti-aimbot angles", "Yaw base")},
		yaw = {pui.reference("aa", "anti-aimbot angles", "Yaw")},
		yaw_jitter = {pui.reference("aa", "anti-aimbot angles", "Yaw Jitter")},
		body_yaw = {pui.reference("aa", "anti-aimbot angles", "Body yaw")},
		body_free = {pui.reference("aa", "anti-aimbot angles", "Freestanding body yaw")},
		freestand = {pui.reference("aa", "anti-aimbot angles", "Freestanding")},
		roll = {pui.reference("aa", "anti-aimbot angles", "Roll")},
		edge_yaw = {pui.reference("aa", "anti-aimbot angles", "Edge yaw")},
		fake_peek = {pui.reference("aa", "other", "Fake peek")},
	},

	bindfs = {ui.reference("aa", "anti-aimbot angles", "Freestanding")},
	slow_motion = {ui.reference("aa", "other", "Slow motion")},
	accent = ui.reference("misc", "settings", "menu color"),

	hits = {
		miss = pui.reference("rage", "other", "log misses due to spread"),
		hit = pui.reference("misc", "miscellaneous", "log damage dealt"),
	},

	fakelag = {
		enable = {pui.reference("aa", "fake lag", "enabled")},
		amount = {pui.reference("aa", "fake lag", "amount")},
		variance = {pui.reference("aa", "fake lag", "variance")},
		limit = {pui.reference("aa", "fake lag", "limit")},
		lg = {pui.reference("aa", "other", "Leg movement")},
	},

	aa_other = {
		sw = {pui.reference("aa", "other", "Slow motion")}, 
		hide_shots = {pui.reference("aa", "other", "On shot anti-aim")},
	},

	rage = {
		enable = ui.reference('rage', 'aimbot', 'Enabled'),
		dt = {ui.reference("rage", "aimbot", "Double tap")},
		always = {ui.reference("rage", "other", "Automatic fire")},
		fd = {ui.reference("rage", "other", "Duck peek assist")},
		qp = {ui.reference("rage", "other", "Quick peek assist")},
		os = {ui.reference("aa", "other", "On shot anti-aim")},
		mindmg = {pui.reference('rage', 'aimbot', 'minimum damage')},
		baim = {ui.reference('rage', 'aimbot', 'force body aim')},
		safe = {ui.reference('rage', 'aimbot', 'force safe point')},
		ovr = {ui.reference('rage', 'aimbot', 'minimum damage override')},
	},
}

local phobia = {
	ui = {
		servers = {
			gen = {
                ["•  PUZO HVH | MODEL SERVER | 16K"] = "45.136.204.145:1488",
                ["•  eXpidors.Ru | ONLY SCOUT"] = "62.122.215.105:6666",
                ["•  [hvhserver.xyz] roll fix"] = "62.122.214.55:27015",
                ["•  eXpidors.Ru - Scout"] = "62.122.215.105:6666",
                ["•  sippin' on wok mm hvh"] = "46.174.55.52:1488",
                ["•  War3ft Project"] = "46.174.52.69:27015",
                ["•  SharkProject | 1x1"] = "46.174.49.147:1488",
                ["•  SharkProject | MM"] = "37.230.228.148:27015",
                ["•  PUZO HVH | ONLY SCOUT"] = "37.230.162.58:1488",
                ["•  LivixProject HVH"] = "185.9.145.159:28423",
                ["•  Elysium MM HVH | AWP"] = "62.122.214.127:27015",
			},

			selected = ""
		},

		show = function(self, visible)
			local m3nu = {refs.aa, refs.fakelag, refs.aa_other}

			for _, groups in ipairs(m3nu) do
			  	for _, v in pairs(groups) do
					for _, item in ipairs(v) do
						item:set_visible(visible)
					end
			  	end
			end
			refs.aa.enabled:set_visible(visible)
		end,

		high_word = function(self, word)
			if not word or #word == 0 or type(word) ~= "string" then
			   	return word
			end
		  
			local first_letter = string.upper(string.sub(word, 1, 1))
			local rest_of_word = string.sub(word, 2)
		  
			return first_letter .. rest_of_word
		end,

		depends = function(element_group, element_config_function)
			element_group = element_group.__type == "pui::element" and {
				element_group
			} or element_group
		
			local created_elements, dependency_value = element_config_function(element_group[1])
		
			for _, element in ipairs(created_elements) do
				element:depend({
					element_group[1],
					dependency_value
				})
			end
		
			created_elements[element_group.key or "turn"] = element_group[1]
		
			return created_elements
		end,

		header = function(self, group)
			local accent = "\a333333FF"
			local head = "вЂѕвЂѕвЂѕвЂѕвЂѕвЂѕвЂѕвЂѕвЂѕвЂѕвЂѕвЂѕвЂѕвЂѕвЂѕвЂѕвЂѕвЂѕвЂѕвЂѕвЂѕвЂѕвЂѕвЂѕвЂѕвЂѕ"

			return group:label(accent .. head)
		end,

		execute = function(self)
			local conditions = {"Global", "Stand", "Walking", "Run", "Crouch", "Sneak", "Air", "Air-Crouch", "Fakelag", "Hideshots"}
			local servs = {}

			local group = {
				a = pui.group("AA", "Fake Lag"),
				f = pui.group("AA", "Other"),
				o = pui.group("AA", "anti-aimbot angles"),
			}

			for k, v in pairs(self.servers.gen) do
				table.insert(servs, k)
			end

pui.macros.d = "\a1A2F4AFF"   
pui.macros.gray = "\a0F1C2EFF" 
pui.macros.a = "\a3A56A5FF"    
pui.macros.ab = "\a6387D0FF"   

			menu = {
				title = group.o:label("\f<gray>----------- \f<a>byte\rtech\f<gray> -----------"),
				--headerr = group.o:label("pulsive text"),
				tab = group.o:combobox("\n tabs", {"Home", "Anti-Aim", "Options"}), 

				home = {
					configs = {
						space1 = group.f:label("\f<d>Create \f<a>config"),
						name = group.f:textbox("\n ~ namememe"),

						list = group.a:listbox("\nconfigs", {}),

						save = group.f:button("\f<a>о„…\r Save"),
						import = group.f:button("\f<a>о…Ѓ\r Import"),
						
						load = group.a:button("Load"),
						export = group.a:button("Export"), -- cfgsgsgs

						delete = group.a:button("\aD95148FFо„‡ Delete")
					},
					
					links = {
						discord = group.o:button("\f<gray>Telegram", function()
							js.SteamOverlayAPI.OpenExternalBrowserURL("https://t.me/gsbyte_techgs")		
						end),
					}
				},

				--servers = {
					--list = group.a:listbox("\nactive-servers", servs),
					--connect = group.a:button("\f<a>о„‚\r Connect"),
					--copy = group.a:button("\f<a>о„І\r Copy ip-address"),

					--space = self:header(group.a),
					--retry = group.a:button("\f<a>о…‰\r Rejoin \f<a>(Retry)"),
				--},

				--stats = {
					--title = group.f:label("\f<d>Statistics"),
					--space = self:header(group.f),
					--loads = group.f:label("\f<a>о„Ў\r Total loads:\f<a> "..database.read(databas.load)),
					--kills = group.f:label("\f<a>о‡ \r Total killed:\f<a> "..database.read(databas.kill))
				--},

				antiaim = {
					tab = group.a:combobox("\f<a>AnitAim \f<ab>", {"Builder","Features", --"AntiBrute" 
					}),

					general = {
						space1 = group.a:label("\n"),

						safe_head = group.a:checkbox("Safe Head"),
						backstab = self.depends(group.a:checkbox("Avoid Backstab"), function()
							return {
								group.a:slider("\n distance backstab", 100, 200, 170, true, "СЃРј", 1),
							}, true
						end),

						space2 = group.a:label("\n"),

						manual = self.depends(group.a:checkbox("Manuals"), function() -- get_manual
							return {
								group.a:hotkey("\f<d>Left \f"),
								group.a:hotkey("\f<d>Right \f"),
								group.a:hotkey("\f<d>Forward"),
								self:header(group.a)
							}, true
						end),

						fs = self.depends(group.a:checkbox("Freestand", 0), function() -- menu.antiaim.general.fs
							return {
								group.a:checkbox("\f<d>Static"),
								self:header(group.a)
							}, true
						end),

						edge_yaw = group.a:checkbox("Edge yaw", 0)
					},

					builder = {
						state_curr = group.a:combobox("\n current cond", conditions),

						states = {},
					},

					antibf = {
						header = self:header(group.f),

						enable = group.a:checkbox("Enable \f<a>Bruteforce"),

						_tab = group.f:combobox("Anti-Bruteforce \f<a>Tab", {"Builder", "Trigger"}),
						tab = group.f:combobox("Builder bruteforce", {"Presets", "Custom"}),
						info = group.f:label("\f<d>Settings \f<a>applied\r on all \f<a>state!"),

						presets = {
							list = group.a:listbox("\n bruforce presets", {"jitter", "jitter random"}),

							stage = group.a:slider("Bruforce stages \f<a>...", 1, 3, 2, true)
						},

						custom = {
							space = group.a:label("\n otstup c"),
								
							jitter = {
								type = group.a:combobox("\n bf yaw type", {"Off", "Center", "Offset", "Random", "Skitter"}),
								yaw = group.a:slider("\n bf yaw grodus", -90, 90, 0, true, "В°", 1),

								lef = group.a:slider("Add yaw ~ \f<a>l/r\nbf", -70, 70, 0, true, "В°", 1),
								rig = group.a:slider("\n bf yaw r", -70, 70, 0, true, "В°", 1), -- jitter.yaw

								body = self.depends(group.a:combobox("Body yaw \nbf3", {"Off", "Opposite", "Static", "Jitter"}), function()
									return {
										group.a:combobox("\n body type static3", {"Left", "Right"})
									}, "Static"
								end),

								delay = group.a:slider("\f<d>Delay yaw \nbf", 1, 12, 1, true, "t", 1, {[1] = "Off"}),
							},
						},
						trigger = {
							space = group.a:label("\n otstup t"),

							timer = self.depends(group.a:checkbox("\f<a>о„Ў\r Time"), function()
								return {
									group.a:slider("\f<a>о‡Њ\r Bruteforce \f<a>res/on\r ever per", 1, 60, 60, true, "s", 1, {[60] = "1 min"}), -- export
									self:header(group.a)
								}, true
							end),

							round = group.a:checkbox("\f<a>о‡Ќ\r Start \f<a>round"),
							notify = group.a:checkbox("\f<a>о‡Ј\r Notify"),
						}
					},
				},

				options = {
					tab = group.a:combobox("\ntabopt", {"Visuals", "Other"}),
					space = group.a:label("\n"),

					vis = {
						accent = group.a:color_picker("\naccent", 119, 120, 159),
						watermark = self.depends(group.a:checkbox("Watermark"), function()
							return {
								group.a:label("\f<d>Custom name"),
								group.a:textbox("\nwater-name"),
								self:header(group.a)
							}, true
						end),

						crosshair = self.depends(group.a:checkbox("Crosshair indicator"), function()
							return {
								group.a:textbox("\ncross-name"),
								group.a:slider("\ncrosshair offset", 5, 100, 50, true, "px", 1),
								self:header(group.a)
							}, true
						end),

						viewmodel = group.a:checkbox("Viewmodel modifier"),
						viewmodel_fov = group.a:slider("\f<d>Fov", -120, 120, 60, true, "", 1),
						viewmodel_x = group.a:slider("\n viewmodel x", -90, 90, 1, true, "x", 1),
						viewmodel_y = group.a:slider("\n viewmodel y", -90, 90, 1, true, "y", 1),
						viewmodel_z = group.a:slider("\n viewmodel z", -90, 90, 1, true, "z", 1),
						space_view = self:header(group.a),

						damage = self.depends(group.a:checkbox("Damage indicator"), function()
							return {
								group.a:checkbox("\f<d>Allow on general")
							}, true
						end),

						notify = group.a:multiselect("\f<d>Notify options", {"Hit", "Miss"}),
						notify_style = group.a:combobox("\n soon ", {"Soon"})
					},

					helpers = {
						trashtalk = group.a:checkbox("Trashtalk"),
						breaker = group.a:checkbox("Animation breaker"),
					}
				},
			}

			menu.options.vis.viewmodel_fov:depend({menu.options.vis.viewmodel, true})
			menu.options.vis.viewmodel_x:depend({menu.options.vis.viewmodel, true})
			menu.options.vis.viewmodel_y:depend({menu.options.vis.viewmodel, true})
			menu.options.vis.viewmodel_z:depend({menu.options.vis.viewmodel, true})
			menu.options.vis.space_view:depend({menu.options.vis.viewmodel, true})

			menu.antiaim.antibf.tab:depend({menu.antiaim.antibf._tab, "Builder"})

			local exodus = {
				pitch = {[-89] = "Up", [0] = "Zero", [89] = "Down"},
				yaw = {[-180] = "Left", [0] = "Zero", [180] = "Right"}
			}

			for _, state in ipairs(conditions) do

				menu.antiaim.builder.states[state] = {}
				local aa = menu.antiaim.builder.states[state]

				local c = "\n" .. state

				if state ~= "Global" then
					aa.active = group.a:checkbox("Active \f<a>" .. string.lower(state))
				end

				aa.space = self:header(group.a)

				aa.yaw_type = group.a:combobox("\n yaw type" .. c, {"Off", "Center", "Offset", "Random", "Skitter"})
				aa.yaw_value = group.a:slider("\n yaw value" .. c, -90, 90, 0, true, "В°", 1):depend({aa.yaw_type, "Off", true})

				aa.yaw_l = group.a:slider("\f<d>Yaw add \f<a>(l-r)" .. c, -90, 90, 0, true, "В°", 1)
				aa.yaw_r = group.a:slider("\nYaw right" .. c, -90, 90, 0, true, "В°", 1)

				aa.space_2 = group.a:label("\n space2")

				aa.body_type = group.a:combobox("Body \f<a>yaw type" .. c, {"Off", "Opposite", "Static", "Jitter"})
				aa.body_type_static = group.a:combobox("\n Body static type" .. c, {"Left", "Right"}):depend({aa.body_type, "Static"})
				aa.yaw_delay = group.a:slider("\f<d>Delay" .. c, 1, 12, 1, true, "t", 1, {[1] = "Off"})

				aa.space_3 = self:header(group.a)

				aa.defensive_yaw = group.a:combobox("\f<d>Defensive\f<a> yaw" .. c, {"Off", "Static", "Random", "Spin", "Jitter", "Random static"})

				-- static & random
				aa.defyawstat = group.a:slider("\n Custom yaw static & random" .. c, -180, 180, 0, true, "В°", 1):depend({aa.defensive_yaw, "Static", "Random", "Random static"})

				-- spin
				aa.defyawspinleft = group.a:slider("Spin limit\f<a> left \\ right" .. c, -180, 180, 0, true, "В°", 1, exodus.yaw):depend({aa.defensive_yaw, "Spin"})
				aa.defyawspinrgt = group.a:slider("\nSpin limit left" .. c, -180, 180, 0, true, "В°", 1, exodus.yaw):depend({aa.defensive_yaw, "Spin"})
				aa.defyawspinspd = group.a:slider("\n Spin speed" .. c, 1, 16, 6, true, "t", 1):depend({aa.defensive_yaw, "Spin"})
				aa.defyawspin = group.a:slider("\f<d> Spin updated" .. c, 1, 30, 12, true, "В°", 1):depend({aa.defensive_yaw, "Spin"})

				-- jitter
				aa.defyawjittr = group.a:slider("\n Jitter yaw" .. c, 0, 180, 90, true, "В°", 1):depend({aa.defensive_yaw, "Jitter"})
				aa.defyawjittrtick = group.a:slider("\n Jitter yaw delay" .. c, 1, 16, 1, true, "t", 1):depend({aa.defensive_yaw, "Jitter"})
				aa.defyawjittrand = group.a:slider("\f<d>Randomize" .. c, 0, 90, 0, true, "В°", 1):depend({aa.defensive_yaw, "Jitter"})

				aa.defyawrandomt = group.a:slider("\f<d> Tick\nrandom sta yaw" .. c, 1, 12, 1, true, "t", 1):depend({aa.defensive_yaw, "Random static"})

				aa.defss = self:header(group.a):depend({aa.defensive_yaw, "Off", true})

				--.>,<.- PiTcH dEf -.>,<.-------------------===============-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
				aa.defpitch = group.a:combobox("\f<d>Defensive\f<a> pitch" .. c, {"Static", "Random", "Spin", "Jitter", "Random static"}):depend({aa.defensive_yaw, "Off", true})
				aa.defpitchstat = group.a:slider("\n Pitch static" .. c, -89, 89, 0, true, "В°", 1, exodus.pitch):depend({aa.defensive_yaw, "Off", true})

				-- random
				aa.defpitchrand = group.a:slider("\n Pitch random" .. c, -89, 89, 0, true, "В°", 1, exodus.pitch):depend({aa.defensive_yaw, "Off", true}, {aa.defpitch, "Random", "Spin"})

				-- spin
				aa.defpitchspint = group.a:slider("\n Pitch spin speed" .. c, 1, 18, 6, true, "t", 1):depend({aa.defensive_yaw, "Off", true}, {aa.defpitch, "Spin"})
				aa.defpitchspinupd = group.a:slider("\f<d> Spin updated \n pitch" .. c, 1, 30, 12, true, "В°", 1):depend({aa.defensive_yaw, "Off", true}, {aa.defpitch, "Spin"})
				
				-- jitter
				aa.defpitchjittr = group.a:slider("\n Pitch jitter" .. c, -89, 89, 0, true, "В°", 1, exodus.pitch):depend({aa.defensive_yaw, "Off", true}, {aa.defpitch, "Jitter"})
				aa.defpitchjittrtick = group.a:slider("\n Pitch jitter delay" .. c, 1, 16, 1, true, "t", 1, exodus.pitch):depend({aa.defensive_yaw, "Off", true}, {aa.defpitch, "Jitter"})
				aa.defpitchjittrrand = group.a:slider("\f<d>Randomize \n Pitch" .. c, 0, 90, 0, true, "В°", 1):depend({aa.defensive_yaw, "Off", true}, {aa.defpitch, "Jitter"})
				
				-- static rand
				aa.defpitchrand_tick = group.a:slider("\f<d> Tick\nrandom sta" .. c, 1, 12, 1, true, "t", 1):depend({aa.defensive_yaw, "Off", true}, {aa.defpitch, "Random static"})

				aa.defss2 = group.o:label("\n tr"):depend({aa.defensive_yaw, "Off", true})
				aa.defpitchtriggers = group.o:multiselect("\f<d>Defensive \f<a>triggers" .. c, {"Always", "Tick", "Weapon switch"}):depend({aa.defensive_yaw, "Off", true})
				aa.defpitchtrigger_t = group.o:slider("\n trigger tick" .. c, 1, 13, 1, true, "t", 1):depend({aa.defensive_yaw, "Off", true}, {aa.defpitchtriggers, "Tick"})

				for _, v in pairs(aa) do
					local arr = {{menu.antiaim.builder.state_curr, state}}

					if _ ~= "active" and state ~= "Global" then
						arr = {{menu.antiaim.builder.state_curr, state}, {aa.active, true}}
					end

					v:depend(table.unpack(arr))
				end
			end

			--menu.antiaim.builder.export = group.o:button("\f<a>о… \r Export state")
			--menu.antiaim.builder.import = group.o:button("\f<a>о…­\r Import state")

			local traverses = {
				[menu.antiaim.antibf.custom] = {{menu.antiaim.antibf._tab, "Builder"}, {menu.antiaim.antibf.tab, "Custom"}, {menu.antiaim.antibf.enable, true}},
				[menu.antiaim.antibf.presets] = {{menu.antiaim.antibf._tab, "Builder"}, {menu.antiaim.antibf.tab, "Presets"}, {menu.antiaim.antibf.enable, true}},
				[menu.antiaim.antibf.trigger] = {{menu.antiaim.antibf._tab, "Trigger"}, {menu.antiaim.antibf.enable, true}},
			
				--[menu.stats] = {{menu.tab, "Home", true}},
				[menu.home] = {{menu.tab, "Home"}},
				[menu.antiaim] = {{menu.tab, "Anti-Aim"}},
				[menu.options] = {{menu.tab, "Options"}},
				--[menu.servers] = {{menu.tab, "Servers"}},
			
				[menu.options.vis] = {{menu.options.tab, "Visuals"}},
				[menu.options.helpers] = {{menu.options.tab, "Other"}},
				[menu.antiaim.general] = {{menu.antiaim.tab, "Features"}},
				[menu.antiaim.builder] = {{menu.antiaim.tab, "Builder"}},
				[menu.antiaim.antibf] = {{menu.antiaim.tab, "AntiBrute"}}
			}
			
			for element, deps in pairs(traverses) do
				pui.traverse(element, function(ac)
					ac:depend(unpack(deps))
				end)
			end
		end,
	},
}

phobia.ui:execute()

local helpers = {
		to_hex = function(self, r, g, b, a)
			return bit.tohex(
			(math.floor((r or 0) + 0.5) * 16777216) + 
			(math.floor((g or 0) + 0.5) * 65536) + 
			(math.floor((b or 0) + 0.5) * 256) + 
			(math.floor((a or 0) + 0.5))
			)
		end,

		pulse = function(self, color, speed)
			local r, g, b, a = unpack(color)
			
			local c1 = r * math.abs(math.cos(globals.curtime()*speed)) 
			local c2 = g * math.abs(math.cos(globals.curtime()*speed))
			local c3 = b * math.abs(math.cos(globals.curtime()*speed))
			local c4 = a * math.abs(math.cos(globals.curtime()*speed))

			return c1, c2, c3, c4
		end,

		animate_text = function(self, speed, string, r, g, b, a)
			local t_out, t_out_iter = { }, 1
			local time = globals.curtime()

			local l = string:len( ) - 1
	
			local r_add = (255 - r)
			local g_add = (255 - g)
			local b_add = (255 - b)
			local a_add = (155 - a)
	
			for i = 1, #string do
				local iter = (i - 1)/(#string - 1) + time * speed
				t_out[t_out_iter] = "\a" .. self:to_hex( r + r_add * math.abs(math.cos( iter )), g + g_add * math.abs(math.cos( iter )), b + b_add * math.abs(math.cos( iter )), a + a_add * math.abs(math.cos( iter )) )
	
				t_out[t_out_iter + 1] = string:sub( i, i )
	
				t_out_iter = t_out_iter + 2
			end
	
			return t_out
		end,

		in_air = function(self, ent)
			local flags = entity.get_prop(ent, "m_fFlags")
			return bit.band(flags, 1) == 0
		end,

		in_duck = function(self, ent)
			local flags = entity.get_prop(ent, "m_fFlags")
			return bit.band(flags, 4) == 4
		end,

		normalize_pitch = function(self, angle)
			return render:clamp(angle, -89, 89)
		end,

		normalize_yaw = function(self, angle)
			angle =  angle % 360 
			angle = (angle + 360) % 360
			if (angle > 180)  then
				angle = angle - 360
			end
			return angle
		end,

		get_state = function(self)
			local me = entity.get_local_player()

			local velocity_vector = entity.get_prop(me, "m_vecVelocity")
			
			local velocity = vector(velocity_vector):length2d()
			local duck = self:in_duck(me) or ui.get(refs.rage.fd[1])
			local menu = menu.antiaim.builder.states
			local manual = 0
		
			local dt = (ui.get(refs.rage.dt[1]) and ui.get(refs.rage.dt[2]))
			local os = (ui.get(refs.rage.os[1]) and ui.get(refs.rage.os[2]))
			local fd = ui.get(refs.rage.fd[1])

			local state = "Global"

			if velocity > 1.5 then
				if menu["Run"].active() then
					state = "Run"
				end
			elseif menu["Stand"].active() then
				state = "Stand"
			end
		
			if self:in_air(me) then
				if duck then
					if menu["Air-Crouch"].active() then
						state = "Air-Crouch"
					end
				else
					if menu["Air"].active() then
						state = "Air"
					end
				end
			elseif duck and velocity > 1.5 and menu["Sneak"].active() then
				state = "Sneak"
			elseif velocity > 1 and ui.get(refs.slow_motion[1]) and ui.get(refs.slow_motion[2]) and menu["Walking"].active() then
				state = "Walking"
			elseif manual == -90 and menu["Manual left"].active() then
				state = "Manual left"
			elseif manual == 90 and menu["Manual right"].active() then
				state = "Manual right"
			elseif duck and menu["Crouch"].active() then
				state = "Crouch"
			end
		
			if velocity then
				if menu["Fakelag"].active() and ((not dt and not os) or fd) then
					state = "Fakelag"
				end

				if menu["Hideshots"].active() and os and not dt and not fd then
					state = "Hideshots"
				end
			end

			return state
		end,

		contains = function(self, tbl, val)
			for k, v in pairs(tbl) do
				if v == val then
					return true
				end
			end
			return false
		end,

		charge = function(self)
			if not entity.is_alive(entity.get_local_player()) then 
				return 
			end

			local a = entity.get_local_player()

			local weapon = entity.get_prop(a, "m_hActiveWeapon")

			if weapon == nil then 
				return false 
			end

			local next_attack = entity.get_prop(a, "m_flNextAttack") + 0.01
			local checkcheck = entity.get_prop(weapon, "m_flNextPrimaryAttack")

			if checkcheck == nil then 
				return 
			end

			local next_primary_attack = checkcheck + 0.01

			if next_attack == nil or next_primary_attack == nil then 
				return false 
			end

			return next_attack - globals.curtime() < 0 and next_primary_attack - globals.curtime() < 0
		end
}


function accent()
	local clr, clr1, clr2, clr3 = menu.options.vis.accent:get()

	return clr, clr1, clr2, clr3
end

local notify = (function()
    local lerp = function(start_value, end_value, amount)
		local f=globals.frametime()
        return (end_value - start_value) * (f*amount) + start_value
    end

    local measure_text = function(font, ...)
        local text_parts = {...}
        local combined_text = table.concat(text_parts, "")
        return vector(renderer.measure_text(font, combined_text))
    end

    local notification_settings = {
        notifications = {
            bottom = {}
        },
        max = {
            bottom = 6
        }
    }

    notification_settings.__index = notification_settings

    notification_settings.create_new = function(...)
        table.insert(notification_settings.notifications.bottom, {
            started = false,
            instance = setmetatable({
                active = false,
                timeout = 4,
                color = {
                    r = 0,
                    g = 0,
                    b = 0,
                    a = 0
                },
                x = x / 2,
                y = y,
                text = ...
            }, notification_settings)
        })
    end

    function notification_settings:handler()
        local notification_index = 0
        local active_count = 0

        for i, notification_data in pairs(notification_settings.notifications.bottom) do
            if not notification_data.instance.active and notification_data.started then
                table.remove(notification_settings.notifications.bottom, i)
            end
        end

        for i = 1, #notification_settings.notifications.bottom do
            if notification_settings.notifications.bottom[i].instance.active then
                active_count = active_count + 1
            end
        end

        for i, notification_data in pairs(notification_settings.notifications.bottom) do
            if i > notification_settings.max.bottom then
                return
            end

            if notification_data.instance.active then
                notification_data.instance:render_bottom(notification_index, active_count)
                notification_index = notification_index + 1
            end

            if not notification_data.started then
                notification_data.instance:start()
                notification_data.started = true
            end
        end
    end

    function notification_settings:start()
        self.active = true
        self.delay = globals.realtime() + self.timeout
    end

    function notification_settings:get_text()
        local combined_text = ""
        for _, text_data in pairs(self.text) do
            local text_size = measure_text("", text_data[1])
            local red, green, blue = 255, 255, 255 
            if text_data[2] then
                red, green, blue, _ = accent()
            end
            combined_text = combined_text .. ("\a%02x%02x%02x%02x%s"):format(red, green, blue, self.color.a, text_data[1])
        end
        return combined_text
    end

	local rendr = (function()
        local d = {}
        d.rect = function(d, b, c, e, f, g, k, l, m)
            m = math.min(d / 2, b / 2, m)

			renderer.rectangle(d, b + m, c, e - m * 2, f, g, k, l)
			renderer.rectangle(d + m, b, c - m * 2, m, f, g, k, l)
			renderer.rectangle(d + m, b + e - m, c - m * 2, m, f, g, k, l)

			renderer.circle(d + m, b + m, f, g, k, l, m, 180, .25)
			renderer.circle(d - m + c, b + m, f, g, k, l, m, 90, .25) 
			renderer.circle(d - m + c, b - m + e, f, g, k, l, m, 0, .25)
			renderer.circle(d + m, b - m + e, f, g, k, l, m, -90, .25)
        end
        d.rect_o = function(d, b, c, e, f, g, k, l, m, n)
            m = math.min(c / 2, e / 2, m)
			if m == 1 then
				renderer.rectangle(d, b, c, n, f, g, k, l)
				renderer.rectangle(d, b + e - n, c, n, f, g, k, l)
			else
				renderer.rectangle(d + m, b, c - m * 2, n, f, g, k, l)
				renderer.rectangle(d + m, b + e - n, c - m * 2, n, f, g, k, l)
				renderer.rectangle(d, b + m, n, e - m * 2, f, g, k, l)
				renderer.rectangle(d + c - n, b + m, n, e - m * 2, f, g, k, l)
				renderer.circle_outline(d + m, b + m, f, g, k, l, m, 180, .25, n)
				renderer.circle_outline(d + m, b + e - m, f, g, k, l, m, 90, .25, n)
				renderer.circle_outline(d + c - m, b + m, f, g, k, l, m, -90, .25, n)
				renderer.circle_outline(d + c - m, b + e - m, f, g, k, l, m, 0, .25, n)
			end
        end
        d.glow = function(b, c, e, f, g, k, l, m, n, o, p, q, r, s, s)
            local t = 1
            local u = 1
            if s then d.rect(b, c, e, f, l, m, n, o, k) end
            for l = 0, g do
                local m = o / 2 * (l / g) ^ 3
                d.rect_o(b + (l - g - u) * t, c + (l - g - u) * t, e - (l - g - u) * t * 2, f - (l - g - u) * t * 2, p, q, r, m / 1.5, k + t * (g - l + u), t) 
			end 
		end
		return d 
	end)()

    function notification_settings:render_bottom(index, active_count)
        local padding = 16
		local default = menu.options.vis.notify_style:get() == "Default"
        local text_margin = "     " .. self:get_text()
        local text_size = measure_text("", text_margin)
        local gray = 15
        local corner_thickness = 2
        local widht = padding + text_size.x
        widht = widht + corner_thickness * 2
        local h = 23
        local p_x = self.x - widht / 2
        local p_y = math.ceil(self.y - 40 + 0.4) 

        if globals.realtime() < self.delay then
            self.y = lerp(self.y, y - 140 - (index - 1) * h * 1.5, 7)
            self.color.a = lerp(self.color.a, 255, 2)
        else
            self.y = lerp(self.y, self.y + 5, 15)
            self.color.a = lerp(self.color.a, 0, 20)
            if self.color.a <= 1 then
                self.active = false
            end
        end

        local r, g, b = accent() 
		local alpha = self.color.a

        local balpha = render:alphen(alpha - 120)
		local log0, lx, ly = render:logo(default)
		local log_x, log_y = default and p_x - 7 or p_x - 2, default and p_y - 2 or p_y + 2

        local offset = corner_thickness + 2
        offset = offset + padding
		
		if not default then
			rendr.glow(p_x - 5, p_y, widht, h+1, 12, 6, 15, 15, 15, alpha, r, g, b, alpha, true)
		else
      		render:rect(p_x + 5, p_y, widht - 12, h + 1, {gray, gray, gray, balpha}, 6)
		end

		renderer.text(p_x + offset - 18, p_y + h / 2 - text_size.y / 2, r, g, b, alpha, "", nil, text_margin)
		renderer.texture(log0, log_x, log_y, lx, ly, r, g, b, alpha)
	end

    client.set_event_callback("paint_ui", function()
        notification_settings:handler()
    end)

    return notification_settings
end)()

local cfgs = {
	upd_name = function(self)
		local index = menu.home.configs.list()
		local i = 0

		local configs = database.read(databas.cfgs) or {}

		for k, v in pairs(configs) do
			if index == i then
				return menu.home.configs.name(k)
			end

			i = i + 1
		end

		return nil
	end,

	upd_cfgs = function(self)
		local names = {}
		local configs = database.read(databas.cfgs) or {}

		for k, v in pairs(configs) do
			table.insert(names, k)
		end

		if #names > 0 then
			menu.home.configs.list:update(names)
		end

		self:upd_name()
	end,

	export = function(self, notify33)
		local cfg = pui.setup({menu.home, menu.antiaim, menu.options})

		local data = cfg:save()
		local encrypted = json.stringify(data)

		if notify33 then
			notify.create_new({{"Config "}, {"exported", true}})
		end

		return encrypted
	end,

	import = function(self, encrypted, norit)
		local success, data = pcall(json.parse, encrypted)

		if not success then
			notify.create_new({{"Cfg invalid, "}, {"try other", true}})
			return
		end

		local cfg = pui.setup({menu.home, menu.antiaim, menu.options})

		cfg:load(data)

		if norit then 
			notify.create_new({{"Config "}, {"imported", true}})
		end
	end,

	export_state = function(self)
		local state = menu.antiaim.builder.state_curr:get()
		local cfg = pui.setup({menu.antiaim.builder.states[state]})

		local data = cfg:save()
		local encrypted = json.stringify(data)

		notify.create_new({{"State "}, {state:lower(), true}, {" exported"}})
		clipboard.set(encrypted)
	end,

	import_state = function(self, encrypted)
		local success, data = pcall(json.parse, encrypted)

		if not success then
			notify.create_new({{"This not "}, {"config state, ", true}, {"import other"}})
			return
		end

		local state = menu.antiaim.builder.state_curr:get()

		local config = pui.setup({menu.antiaim.builder.states[state]})
		config:load(data)

		notify.create_new({{"State "}, {state:lower(), true}, {" imported"}})
	end,

	save = function(self)
		local name = menu.home.configs.name()

		if name:match("%w") == nil then
			notify.create_new({{"Please type other "}, {"name", true}})
			return print("Inval. name")
		end

		local data = self:export(false)

		notify.create_new({{"Config "}, {name, true}, {" saved"}})

        local configs = database.read(databas.cfgs) or {}
		
        configs[name] = data

        database.write(databas.cfgs, configs)
		self:upd_cfgs()
	end,

	trash = function(self)
		local name = menu.home.configs.name()

		if name:match("%w") == nil then
			notify.create_new({{"Pls select "}, {"config", true}})
			return
		end
	
		local configs = database.read(databas.cfgs) or {}
	
		if configs[name] then
			configs[name] = nil

			database.write(databas.cfgs, configs)
			notify.create_new({{"Config "}, {name, true}, {" deleted"}})
		else
			notify.create_new({{"Config "}, {name, true}, {" not found"}})
		end
	
		self:upd_cfgs()
	end,
	
	load = function(self)
		local name = menu.home.configs.name()

		if name:match("%w") == nil then
			notify.create_new({{"Pls select "}, {"config", true}})
			return
		end

		local configs = database.read(databas.cfgs) or {}
		self:import(configs[name])

		notify.create_new({{"Loaded config "}, {name, true}})
	end,
}

cfgs:upd_cfgs()

menu.home.configs.list:set_callback(function()
	cfgs:upd_name()
end)

-- aaaa cfgsgsgs
menu.home.configs.export:set_callback(function()
	local data = cfgs:export(true)

	clipboard.set(data)
end)

menu.home.configs.import:set_callback(function()
	cfgs:import(clipboard.get(), true)
end)

menu.home.configs.save:set_callback(function()
	cfgs:save()
end)

menu.home.configs.load:set_callback(function()
	cfgs:load()
end)

menu.home.configs.delete:set_callback(function()
	cfgs:trash()
end)
-- aa  
--menu.antiaim.builder.export:set_callback(function() 
	--cfgs:export_state()
--end)

--menu.antiaim.builder.import:set_callback(function() 
	---cfgs:import_state(clipboard.get())
--end)

local defensive = {
	check = 0,
	defensive = 0,
	sim_time = globals.tickcount(),
	active_until = 0,
	ticks = 0,
	active = false,

	activatee = function(self)
    	local me = entity.get_local_player()
    	local tickcount = globals.tickcount()
    	local sim_time = entity.get_prop(me, "m_flSimulationTime")
    	local sim_diff = toticks(sim_time - self.sim_time)

    	if sim_diff < 0 then
    	 	self.active_until = tickcount + math.abs(sim_diff)
    	end

		self.ticks = render:clamp(self.active_until - tickcount, 0, 16)
    	self.active = self.active_until > tickcount

		self.sim_time = sim_time
	end,

	normalize = function(self)
		local me = entity.get_local_player()
		local tickbase = entity.get_prop(me, "m_nTickBase")

		self.defensive = math.abs(tickbase - self.check)
		self.check = math.max(tickbase, self.check or 0)
	end,

	reset = function(self)
		self.check = 0
		self.defensive = 0
	end
}

local antiaim = {
	manual_side = 0,

	get_manual = function(self)
		local me = entity.get_local_player()

		if me == nil or not menu.antiaim.general.manual.turn:get() then
			return
		end

		local left = menu.antiaim.general.manual[1]:get()
		local right = menu.antiaim.general.manual[2]:get()
		local forward = menu.antiaim.general.manual[3]:get()

		if self.last_forward == nil then
			self.last_forward, self.last_right, self.last_left = forward, right, left
		end

		if left ~= self.last_left then
			if self.manual_side == 1 then
				self.manual_side = nil
			else
				self.manual_side = 1
			end
		end

		if right ~= self.last_right then
			if self.manual_side == 2 then
				self.manual_side = nil
			else
				self.manual_side = 2
			end
		end

		if forward ~= self.last_forward then
			if self.manual_side == 3 then
				self.manual_side = nil
			else
				self.manual_side = 3
			end
		end

		self.last_forward, self.last_right, self.last_left = forward, right, left

		if not self.manual_side then
			return
		end

		return ({-90, 90, 180})[self.manual_side]
	end,

	get_backstab = function (self)

		if not menu.antiaim.general.backstab.turn:get() then 
			return 
		end

		local me = entity.get_local_player()
		local target = client.current_threat()

		if me == nil or not entity.is_alive(me) then 
			return false 
		end

		if not target then
			return false
		end

		local weapon_ent = entity.get_player_weapon(target)

		if not weapon_ent then
			return false
		end

		local weapon_name = entity.get_classname(weapon_ent)

		if not weapon_name:find('Knife') then
			return false
		end

		local lpos = vector(entity.get_origin(me))
		local epos = vector(entity.get_origin(target))
		local dist = menu.antiaim.general.backstab[1]:get()

		return epos:dist2d(lpos) < dist
	end,

	get_defensive = function(self, data)
		local trigs = data.defpitchtriggers

		local target = client.current_threat()
		local me = entity.get_local_player()

		if helpers:contains(trigs, "Always") then 
			return true 
		end

		if helpers:contains(trigs, "Tick") then
			local tick = data.defpitchtrigger_t*2

			if globals.tickcount() % 32 >= tick then 
				return true
			end
		end

		if helpers:contains(trigs, "Weapon switch") then 
			local nextattack = math.max(entity.get_prop(me, 'm_flNextAttack') - globals.curtime(), 0)

			if nextattack / globals.tickinterval() > defensive.defensive + 2 then
				return true
			end
		end

		if helpers:contains(trigs, "On hittable") then 
			return true 
		end
	end,

	side = 0,
	cycle = 0,
	yaw_random = 0,

	skitter = {
		counter = 0,
		last = 0,
	},

	def = {
		yaw = {
			spin = 0,
			jitter_side = 0,
			random = 0
		},
		pitch = {
			spin = 0,
			jitter_side = 0,
			random = 0
		},
	},

	brute = {
		on = false,
		time = 0, -- globals.curtime()
		time_sw = false,
	},

	set = function(self, cmd, data)
	
		local ref = {
			pitch_mode = refs.aa.pitch[1],
			pitch = refs.aa.pitch[2],
			yaw_mode = refs.aa.yaw[1],
			yaw = refs.aa.yaw[2],
			yaw_base = refs.aa.yaw_base[1],
			jitter_type = refs.aa.yaw_jitter[1],
			jitter_yaw = refs.aa.yaw_jitter[2],
			body_mode = refs.aa.body_yaw[1],
			body = refs.aa.body_yaw[2],
			body_f = refs.aa.body_free[1],
		}

		if menu.antiaim.antibf.enable:get() then
		
			local timer_enabled = menu.antiaim.antibf.trigger.timer.turn:get()
			local interval = menu.antiaim.antibf.trigger.timer[1]:get()
			local notifys = menu.antiaim.antibf.trigger.notify:get()
		
			if timer_enabled then
				if self.brute.time == 0 then
					self.brute.time = globals.curtime()
				end
		
				if globals.curtime() - self.brute.time >= interval then
					self.brute.time = globals.curtime()

					if notifys then 
						notify.create_new({{"Bruteforce "}, {"updated ", true}, {"(" .. interval .. "s)"}})
					end

					self.brute.on = not self.brute.on
				end
			else
				-- block empty
			end
		else
			self.brute.on = false
		end

		local is_delayed = true
		local current_side = self.side
		local manual = self:get_manual()

		local antibf = menu.antiaim.antibf.custom
		local yaw_delay = math.max(1, self.brute.on and antibf.jitter.delay:get() or data.yaw_delay)
		
		if globals.chokedcommands() == 0 and self.cycle == yaw_delay then
			current_side = current_side == 1 and 0 or 1
			is_delayed = false
		end
	
		local target = client.current_threat()
		local me = entity.get_local_player()

		local pitch = 90
		local yaw_offset = 0
		local general_yaw = self.brute.on and antibf.jitter.yaw:get() or data.yaw_value
		local body_yaw = self.brute.on and antibf.jitter.body.turn:get() or data.body_type
		local jitter_yaw = self.brute.on and antibf.jitter.type:get() or data.yaw_type
		local bodyy
	
		if body_yaw == "Off" then
			bodyy = "Off"
		elseif body_yaw == "Opposite" then
			bodyy = "Opposite"
		elseif body_yaw == "Static" then
			bodyy = "Static"
		else
			bodyy = "Static"
		end
	
		if jitter_yaw == 'Offset' then
			if current_side == 1 then
				yaw_offset = general_yaw
			end
		elseif jitter_yaw == 'Center' then
			yaw_offset = (current_side == 1 and -general_yaw or general_yaw)
		elseif jitter_yaw == 'Random' then
			local rand = (math.random(0, general_yaw) - general_yaw/2)
			if not is_delayed then
				yaw_offset = yaw_offset + rand

				self.yaw_random = rand
			else
				yaw_offset = yaw_offset + self.yaw_random
			end
		elseif jitter_yaw == 'Skitter' then
			local sequence = {0, 2, 1, 0, 2, 1, 0, 1, 2, 0, 1, 2, 0, 1, 2}

			local next_side

			if self.skitter.counter == #sequence then
				self.skitter.counter = 1
			elseif not is_delayed then
				self.skitter.counter = self.skitter.counter + 1
			end

			next_side = sequence[self.skitter.counter]

			self.skitter.last = next_side

			if body_yaw == "Jitter" then
				current_side = next_side
			end

			if next_side == 0 then
				yaw_offset = yaw_offset - math.abs(general_yaw)
			elseif next_side == 1 then
				yaw_offset = yaw_offset + math.abs(general_yaw)
			end
		end
	
		local add_left = (self.brute.on and antibf.jitter.lef:get() or data.yaw_l)
		local add_right = (self.brute.on and antibf.jitter.rig:get() or data.yaw_r)

		yaw_offset = yaw_offset + (current_side == 0 and add_right or (current_side == 1 and add_left or 0))
	
		local body_yaw_angle = 0
		local body_static = self.brute.on and antibf.jitter.body[1]:get() or data.body_type_static -- 1234123241234123
		local safe_head = false

		if body_yaw == "Static" then
			if body_static == "Left" then
				body_yaw_angle = -90
			elseif body_static == "Right" then
				body_yaw_angle = 90
			end
		else
			body_yaw_angle = (current_side == 2) and 0 or (current_side == 1 and 90 or -90)
		end

		local defensive_value = 0
		local backstb = self:get_backstab()
		local edge_y = menu.antiaim.general.edge_yaw:get() and menu.antiaim.general.edge_yaw:get_hotkey()

		if self:get_defensive(data) then 
			cmd.force_defensive = true
			if defensive.ticks * defensive.defensive > 0 then
				defensive_value = math.max(defensive.defensive, defensive.ticks)
			end
		end

		refs.aa.edge_yaw[1]:override(edge_y)
		refs.aa.freestand[1]:override(false)
		ui.set(refs.bindfs[2], "Always on")

		if menu.antiaim.general.backstab.turn:get() and backstb then 
			yaw_offset = yaw_offset + 180
		end

		if menu.antiaim.general.safe_head:get() then
			if target then
				local weapon = entity.get_player_weapon(me)
				if weapon and (entity.get_classname(weapon):find('Knife') or entity.get_classname(weapon):find('Taser')) then
					yaw_offset = 0
					current_side = 2
					safe_head = true
				end
			end
		end

		if manual then 
			yaw_offset = manual
		elseif menu.antiaim.general.fs.turn:get() and menu.antiaim.general.fs.turn:get_hotkey() then 
			refs.aa.freestand[1]:override(true)
			if menu.antiaim.general.fs[1]:get() then 
				yaw_offset = 0
				current_side = 0
			end
		end

		if data.defensive_yaw ~= "Off" and defensive_value > 0 and not self.brute.on and not safe_head then 
			local yaw_static = data.defyawstat
			local pitch_static = data.defpitchstat

			if data.defensive_yaw == "Static" then 
				yaw_offset = yaw_static
			elseif data.defensive_yaw == "Random" then 
				local random = math.random(-yaw_static, yaw_static)

				yaw_offset = random
			elseif data.defensive_yaw == "Spin" then 
				local l = data.defyawspinleft
				local r = data.defyawspinrgt
				local upd = data.defyawspin
				local sped = data.defyawspinspd

				self.def.yaw.spin = self.def.yaw.spin + upd * (sped / 5)

				if self.def.yaw.spin >= r then 
					self.def.yaw.spin = l
				end

				yaw_offset = self.def.yaw.spin
			elseif data.defensive_yaw == "Jitter" then 
				local delay = data.defyawjittrtick*3
				local degre = data.defyawjittr
				local randm = data.defyawjittrand
				local random = math.random(-randm, randm)

				if delay == 1 then 
					self.def.yaw.jitter_side = self.def.yaw.jitter_side == -1 and 1 or -1
				else 
					self.def.yaw.jitter_side = (globals.tickcount() % delay*2)+1 <= delay and -1 or 1
				end

				yaw_offset = self.def.yaw.jitter_side * degre + random
			elseif data.defensive_yaw == "Random static" then 
				local delay = data.defyawrandomt
				local tick = (globals.tickcount() % 32)

				if tick >= 28 + math.random(0,delay) then 
					self.def.yaw.random = math.random(-yaw_static, yaw_static)
				end

				yaw_offset = self.def.yaw.random
			end

			-- </> Pitch

			if data.defpitch == "Static" then 
				pitch = pitch_static
			elseif data.defpitch == "Random" then 
				local random = math.random(pitch_static, data.defpitchrand)
				
				pitch = random 
			elseif data.defpitch == "Spin" then 
				local lock = data.defpitchrand
				local sped = data.defpitchspint
				local upd = data.defpitchspinupd

				self.def.pitch.spin = self.def.pitch.spin + upd * (sped / 15)

				if self.def.pitch.spin > lock then 
					self.def.pitch.spin = pitch_static
				end
				
				pitch = self.def.pitch.spin
			elseif data.defpitch == "Jitter" then 
				local delay = data.defpitchjittrtick*3
				local degre = data.defpitchjittr
				local randm = data.defpitchjittrrand
				local random = math.random(-randm, randm)

				if delay == 1 then 
					self.def.pitch.jitter_side = self.def.pitch.jitter_side == -1 and 1 or -1
				else 
					self.def.pitch.jitter_side = (globals.tickcount() % delay*2)+1 <= delay and -1 or 1
				end

				pitch = (self.def.pitch.jitter_side == -1 and pitch_static or degre) + random
			elseif data.defpitch == "Random static" then 
				local delay = data.defpitchrand_tick
				local tick = (globals.tickcount() % 32)

				if tick >= 28 + math.random(0,delay) then 
					self.def.pitch.random = math.random(-pitch_static, pitch_static)
				end

				pitch = self.def.pitch.random
			end
		end

		refs.aa.enabled:override(true)

		ref.pitch_mode:override(pitch == "default" and pitch or "custom")
		ref.pitch:override(helpers:normalize_pitch(type(pitch) == "number" and pitch or 0))
		ref.yaw_base:override("At targets")
		ref.yaw_mode:override(180)
		ref.yaw:override(helpers:normalize_yaw(yaw_offset))
		ref.jitter_type:override("Off")
		ref.jitter_yaw:override(0)
		ref.body_mode:override(bodyy)
		ref.body:override(body_yaw ~= "Off" and body_yaw_angle or 0)
		ref.body_f:override(false)

		if globals.chokedcommands() == 0 then
			if self.cycle >= yaw_delay then
				self.cycle = 1
			else
				self.cycle = self.cycle + 1
			end
		end
	
		self.side = current_side
	end,

	run = function(self, cmd)
		local me = entity.get_local_player()

		if not entity.is_alive(me) then
			return
		end


		local state = helpers:get_state()

		local data = {}

		for k, v in pairs(menu.antiaim.builder.states[state]) do
			data[k] = v()
		end

		self:set(cmd, data)
	end
}

local hud_water = dragging('ender:water', 30, 30)

--menu.servers.copy:set_callback(function()
	--clipboard.set(phobia.ui.servers.selected)
	
	--notify.create_new({{phobia.ui.servers.selected, true}})
--end)

--menu.servers.connect:set_callback(function()
	--client.exec("connect " .. phobia.ui.servers.selected)
	--notify.create_new({{"Connecting in "}, {phobia.ui.servers.selected, true}})
--end)

--menu.servers.retry:set_callback(function()
	--client.exec("disconnect; retry")
--end)

local cals = {
	menu_setup = function(self)
		if not pui.menu_open then 
			return 
		end

		local pr, pg, pb, pa = helpers:pulse({119, 120, 159, 190}, 2)
		local f1 = helpers:to_hex(pr, pg, pb, pa)

		--menu.headerr:set("\a"..f1.."вЂѕвЂѕвЂѕвЂѕвЂѕвЂѕвЂѕвЂѕвЂѕвЂѕвЂѕвЂѕвЂѕвЂѕвЂѕвЂѕвЂѕвЂѕвЂѕвЂѕвЂѕвЂѕвЂѕвЂѕвЂѕвЂѕ")

		phobia.ui:show(false)

		--local index = menu.servers.list:get()
		local i = 0

		for k, v in pairs(phobia.ui.servers.gen) do
		if index == i then
				phobia.ui.servers.selected = v
			end
			i = i + 1
		end
	end,

	crosshair = {
		active = function(self, is_tab)
			if not is_tab then 
				return menu.options.vis.crosshair.turn:get()
			else
				return client.key_state(0x09) -- tab
			end
		end,

		run = function(self)
			local me = entity.get_local_player()
			local alpha = render:new_anim("crosshair.on", not self:active(true) and ((self:active()) and 255 or 0) or 0, 8)

			if alpha < 0.1 then 
				return 
			end

			local nname = menu.options.vis.crosshair[1]:get()
			local name = nname == "" and "byte.tech" or nname

			local r, g, b, a = accent()
			local offset = render:new_anim("crosshair.offset", menu.options.vis.crosshair[2]:get(), 6)
			local anim = helpers:animate_text(2, name, r, g, b, alpha)
			local state = helpers:get_state()
			
			local scp = render:new_anim("crosshair.scoped", entity.is_alive(me) and entity.get_prop(me, "m_bIsScoped") or 0, 8)
			local meas_n = render:new_anim("crosshair.name", renderer.measure_text("cb", name), 8)

			local binds = {
				{
					name = "dt",
					clr = {
						r,
						(helpers:charge() and 1 or 0) * g,
						(helpers:charge() and 1 or 0) * b
					},
					re = (ui.get(refs.rage.dt[1]) and ui.get(refs.rage.dt[2])) and not ui.get(refs.rage.fd[1])
				},
				{
					name = "fd",
					clr = {222,222,222},
					re = ui.get(refs.rage.fd[1])
				},
				{
					name = "qp",
					clr = {255,255,255},
					re = ui.get(refs.rage.qp[1]) and ui.get(refs.rage.qp[2])
				}
			}

			if alpha > 110 then 
				local move = render:new_anim("crosshair.move", (not entity.is_alive(me) and y - 15 or y/2 + offset), 6)

				renderer.text(x/2 + (10+(meas_n/2))*scp, move, 255, 255, 255, alpha, "cb", nil, unpack(anim))
			end

			if entity.is_alive(me) then 
				local meas_s = render:new_anim("crosshair.state", -renderer.measure_text("c-", state:upper())*0.5, 16)
				local state_ = (9-meas_s)*scp
				local statea = render:alphen(alpha - 130)

				renderer.text(x/2 + state_, y/2 + offset + 13, 255, 255, 255, statea, "c-", nil, state:upper())

				local off = 0

				for _, bind in ipairs(binds) do 
					local meas = -renderer.measure_text("c-", bind.name:upper())*0.5
					local alphen = render:new_anim("crosshair.alpha:" .. bind.name, bind.re and 1 or 0, 8)
					local of = render:new_anim("crosshair.offset." .. bind.name, bind.re and 10 or 0, 8)

					off = off + of

					renderer.text(x/2 + (9-meas)*scp, y/2 + offset + off + 15, bind.clr[1], bind.clr[2], bind.clr[3], alpha*alphen, "c-", nil, bind.name:upper())
				end
			end
		end
	},

	watermark = {
		logo = renderer.load_png("", 72, 13),

		run = function(self)
			local water = menu.options.vis.watermark
			local early_move = render:new_anim("watermark.on", water.turn() and 255 or 0, 8)

			if early_move < 0.1 then 
				return 
			end
			
			local r, g, b, a = accent()

			local move = 110*(early_move/255)
			local uuser = water[2]:get()
			local lua = uuser:match("%w") == nil and user_lua or uuser

			local m = {
				name = math.floor(render:measuret(name)),
				user = math.floor(render:new_anim("watermark.user", render:measuret(lua), 8))
			}

			local x, y = hud_water:get(5, 115)

			hud_water:drag(111 + (m.user), 35, (early_move/255)*10)

			render:rectv(x, y - move, 22 + m.name, 25, {25, 25, 25, move}, 6, {r, g, b, early_move}) -- 1
			render:rectv(x + (27 + m.name), y - move, 72 + (m.user - 60), 25, {25, 25, 25, move}, 6, {r, g, b, early_move}) -- 2

			renderer.text(x + (32 + m.name), y - move + 5, 255, 255, 255, early_move, "a", nil, lua)
			renderer.texture(self.logo, x + 5, y - move + 6, 72, 13, r, g, b, early_move)
		end
	},

	viewmodel = {
		active = function(self)
			return menu.options.vis.viewmodel:get()
		end,

		run = function(self)
			if not self:active() then 
				return 
			end

			local x = render:new_anim("viewmodel.x", menu.options.vis.viewmodel_x:get(), 8)
			local fov = render:new_anim("viewmodel.fov", menu.options.vis.viewmodel_fov:get(), 8)
			local y = render:new_anim("viewmodel.y", menu.options.vis.viewmodel_y:get(), 8)
			local z = render:new_anim("viewmodel.z", menu.options.vis.viewmodel_z:get(), 8)

			client.set_cvar("viewmodel_offset_x", x)
			client.set_cvar("viewmodel_offset_y", y)
			client.set_cvar("viewmodel_offset_z", z)
			client.set_cvar("viewmodel_fov", fov)
		end
	},

	dmgmarker = {
		active = function(self)
			return menu.options.vis.damage.turn:get()
		end,

		work = function(self)
			if not self:active() then 
				return 
			end

			local dmg = refs.rage.mindmg[1]:get()
			
			if ui.get(refs.rage.ovr[1]) and ui.get(refs.rage.ovr[2]) then
				return ui.get(refs.rage.ovr[3])
			else
				return dmg
			end
		end,

		run = function(self)
			if not self:active() then 
				return 
			end

			local general = menu.options.vis.damage[1]:get()

			if not general then 
				if ui.get(refs.rage.ovr[2]) then 
					renderer.text(x/2 + 6, y/2 - 16, 255, 255, 255, 255, "a", nil, self:work())
				end
			else
				renderer.text(x/2 + 6, y/2 - 16, 255, 255, 255, 255, "a", nil, self:work())
			end
		end
	},

	logging = {
		hitboxes = { 
			[0] = 'body', 'head', 'chest', 'stomach', 'left arm', 'right arm', 'left leg', 'right leg', 'neck', '?', 'gear'
		},
		
		active = function(self, arg)
			return menu.options.vis.notify:get(arg)
		end,

		create = function(self, arg)
			client.color_log(139, 140, 179, "вЂў ".. name .. " -\r " .. arg)
		end,

		hit = function(self, shot)
			if not self:active("Hit") then 
				return 
			end

			if refs.hits.hit:get() then 
				refs.hits.hit:override(false)
			end

			local target = entity.get_player_name(shot.target)
			local hitbox = self.hitboxes[shot.hitgroup] or "?"
			local hp = math.max(0, entity.get_prop(shot.target, 'm_iHealth'))
			local damage = shot.damage
			local bt = globals.tickcount() - shot.tick
			local hc = math.floor(shot.hit_chance)

			local reas = hp ~= 0 and "1" or "2"

			if reas == "1" then 
				notify.create_new({
					{"Hit "}, {target, true},
					{" in "}, {hitbox, true},
					{" for "}, {damage, true},
					{" (" .. hp .. " rhp)"}
				})

				self:create(string.format("Hit %s in %s for %s (rhp %s) (hc: %s) (bt: %s)", target, hitbox, damage, hp, hc, bt))
			else
				notify.create_new({
					{"Killed "}, {target, true},
					{" in "}, {hitbox, true}
				})

				self:create(string.format("Killed %s in %s (dmg: %s) (hc: %s) (bt: %s)", target, hitbox, damage, hc, bt))
			end
		end,

		miss = function(self, shot)
			if not self:active("Miss") then 
				return 
			end
			
			if refs.hits.miss:get() then 
				refs.hits.miss:override(false)
			end

			local target = entity.get_player_name(shot.target)
			local hitbox = self.hitboxes[shot.hitgroup] or "?"
				
			local bt = globals.tickcount() - shot.tick
			local hc = math.floor(shot.hit_chance)

			notify.create_new({
				{"Miss "}, {target, true},
				{" in "}, {shot.reason, true},
				{" (" .. hc .. "%)"}
			})

			self:create(string.format("Missed %s in %s due to %s (hc: %s, bt: %s)", target, hitbox, shot.reason, hc, bt))
		end
	},
	tt = {
    phrases = {
        "1 by byte.tech",
        "byte.tech - code that owns you pixel by pixel!",
        "What's your ping? byte.tech DDOSed your brain!",
        "What you doin, noob? Another frag for byte.tech!",
        "My IQ's hacked by byte.tech, where's yours?",
        "Easy frag, loser, byte.tech stack smoked you!",
        "Godmode on with byte.tech, catch this 1!",
        "1 by your boss, byte.tech!",
        "Yo, trash, byte.tech decompiled your skills!",
        "1, just 1, byte.tech owns the game!",
        "Where you aimin, scrub? byte.tech's in your crosshair!",
        "Don't try, byte.tech shut you down!",
        "This noob still pressin buttons? byte.tech wrecked you!",
        "byte.tech zeroed you out like a code bug!",
        "Missed, loser! byte.tech hacked your aim!",
        "Take notes from byte.tech, stop embarrassing yourself!",
        "SPOT FIRE, SPOT FIRE, byte.tech backstabbed you!",
        "byte.tech sent you to digital heaven!",
        "Kneel and beg byte.tech for mercy!",
        "byte.tech launched a DDOS on your sorry ass!",
        "Pray byte.tech don't one-tap you... too late!",
        "Know a glitch? That's your skill vs byte.tech!",
        "See that code? byte.tech sent you 0xDEAD!",
        "Red byte from byte.tech owned you!",
        "byte.tech pushed a commit with your frag in it!",
        "Usin trash lua? byte.tech deleted you!",
        "1, dumbass, byte.tech cracked your anti-aim!",
        "Showed your skill? byte.tech sent you to the dump!",
        "byte.tech knows no bugs, only frags!",
        "Without byte.tech, you're just a console noob!",
        "1 skill, 0 chance against byte.tech!",
        "Your AA weaker than byte.tech on low battery!",
        "With that playstyle, go to Roblox HVH, not byte.tech!",
        "I ain't cheating, but byte.tech smoked you!",
        "Byte by byte, you got owned by byte.tech!",
        "byte.tech with skitter, you with 2010 paste!",
        "What, usin luasense? byte.tech owned you easy!",
        "Turn on anti-aim, byte.tech ate you without it!",
        "1 2 3 4 5, byte.tech came to hack you all!",
        "byte.tech: the algorithm of your destruction!",
        "Your skill's a bug, byte.tech's the patch!",
        "byte.tech: your anti-aim's a 404 error!",
        "Why you missin, trash? byte.tech multiplied you by zero!",
        "You ain't playin, byte.tech's usin you!",
        "Your anti-aim's open-source garbage, byte.tech's premium!",
        "byte.tech banned you from life!",
		"Buy - https://discord.gg/qvTREN9p",
    },

		active = function(self)
			return menu.options.helpers.trashtalk:get()
		end,

		run = function(self, event)
			local me = entity.get_local_player()

			if not entity.is_alive(me) then
				return
			end
		
			local victim = client.userid_to_entindex(event.userid)
			local attacker = client.userid_to_entindex(event.attacker)
			local db_kill = database.read(databas.kill)

			if attacker == me and victim ~= me then 
				db_kill = db_kill + 1

				if self:active() then
					client.exec(string.format("say %s", self.phrases[math.random(1, #self.phrases)]))
				end
			end

			database.write(databas.kill, db_kill)
		end
	},

	breaker = {
		run = function(self)
			local me = entity.get_local_player()

			if not menu.options.helpers.breaker:get() or not entity.is_alive(me) then 
				return 
			end

			if globals.tickcount() % 4 > 1 then
				entity.set_prop(me, "m_flPoseParameter", 0, 0)
			end

			refs.fakelag.lg[1]:set("Always slide")
		end
	}
}

notify.create_new({{"Welcome back, "}, {user_lua, true}})

for _, data in ipairs({
	{"player_death", function(event)
		cals.tt:run(event)
	end},

	{"aim_hit", function(event)
		cals.logging:hit(event)
	end},

	{"aim_miss", function(shot)
		cals.logging:miss(shot)
	end},

	{"pre_render", function()
		cals.breaker:run()
	end},

	{"setup_command", function(cmd) 
		antiaim:run(cmd)
	end},

	{"paint", function()
		cals.viewmodel:run()
		cals.crosshair:run()
		cals.dmgmarker:run()
	end},

	{"paint_ui", function()
		cals.watermark:run()
		cals.menu_setup()
	end},

	{"shutdown", function(self)
		phobia.ui:show(true)
	end},

	{"predict_command", function()
		defensive:normalize()
	end},
	
	{"net_update_end", function()
		defensive:activatee()
	end},
}) do
	local name = data[1]
    local func = data[2]

    client.set_event_callback(name, func)
end

cvar.con_filter_enable:set_int(1)
cvar.con_filter_text:set_string("IrWL5106TZZKNFPz4P4Gl3pSN?J370f5hi373ZjPg%VOVh6lN")
client.exec("con_filter_enable 1")


