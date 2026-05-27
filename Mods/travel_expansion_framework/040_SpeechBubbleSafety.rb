module TravelExpansionFramework
  class << self
    def speechbubble_temp
      return nil if !defined?($PokemonTemp) || !$PokemonTemp
      return $PokemonTemp
    rescue
      return nil
    end

    def dispose_speechbubble_object(object)
      return if object.nil?
      return if object.respond_to?(:disposed?) && object.disposed?
      object.dispose if object.respond_to?(:dispose)
    rescue
    end

    def speechbubble_object_alive?(object)
      return false if object.nil?
      return false if object.respond_to?(:disposed?) && object.disposed?
      return true
    rescue
      return false
    end

    def clear_speechbubble_visuals!
      temp = speechbubble_temp
      return if !temp
      dispose_speechbubble_object(temp.speechbubble_arrow) if temp.respond_to?(:speechbubble_arrow)
      dispose_speechbubble_object(temp.speechbubble_vp) if temp.respond_to?(:speechbubble_vp)
      temp.speechbubble_arrow = nil if temp.respond_to?(:speechbubble_arrow=)
      temp.speechbubble_vp = nil if temp.respond_to?(:speechbubble_vp=)
      temp.speechbubble_outofrange = false if temp.respond_to?(:speechbubble_outofrange=)
    rescue
    end

    def reset_speechbubble_state!
      temp = speechbubble_temp
      return if !temp
      clear_speechbubble_visuals!
      temp.speechbubble_bubble = nil if temp.respond_to?(:speechbubble_bubble=)
      temp.speechbubble_talking = nil if temp.respond_to?(:speechbubble_talking=)
      temp.speechbubble_alwaysDown = false if temp.respond_to?(:speechbubble_alwaysDown=)
      temp.speechbubble_alwaysUp = false if temp.respond_to?(:speechbubble_alwaysUp=)
      temp.speechbubble_outofrange = false if temp.respond_to?(:speechbubble_outofrange=)
    rescue
    end

    def speechbubble_target_event
      temp = speechbubble_temp
      return nil if !temp || !defined?($game_map) || !$game_map
      id = temp.speechbubble_talking rescue nil
      events = $game_map.events rescue nil
      return events[id] if events && id && events[id]
      return nil
    rescue
      return nil
    end

    def clamp_speechbubble_value(value, minimum, maximum)
      value = value.to_i
      minimum = minimum.to_i
      maximum = maximum.to_i
      return minimum if maximum < minimum
      return minimum if value < minimum
      return maximum if value > maximum
      return value
    rescue
      return minimum.to_i
    end

    def assign_speechbubble_window_position(window, x, y)
      if window.respond_to?(:x=)
        window.x = x
      else
        window.instance_variable_set(:@x, x)
      end
      if window.respond_to?(:y=)
        window.y = y
      else
        window.instance_variable_set(:@y, y)
      end
    rescue
    end

    def force_speechbubble_window_visible!(window)
      return if !window
      window.visible = true if window.respond_to?(:visible=)
      window.opacity = 255 if window.respond_to?(:opacity=)
      window.back_opacity = 255 if window.respond_to?(:back_opacity=)
      window.contents_opacity = 255 if window.respond_to?(:contents_opacity=)
      window.setSkin("Graphics/windowskins/frlgtextskin") if window.respond_to?(:setSkin)
    rescue
    end

    def position_speechbubble_float!(window, target)
      return if !window || !target || !defined?(Graphics)
      force_speechbubble_window_visible!(window)
      width = window.width rescue window.instance_variable_get(:@width).to_i
      height = window.height rescue window.instance_variable_get(:@height).to_i
      width = 400 if width <= 0
      height = 100 if height <= 0
      screen_x = target.respond_to?(:screen_x) ? target.screen_x : Graphics.width / 2
      screen_y = target.respond_to?(:screen_y) ? target.screen_y : Graphics.height / 2
      x = screen_x - (width / 2)
      y = screen_y - height - 40
      y = screen_y + 8 if y < 2
      x = clamp_speechbubble_value(x, 2, Graphics.width - width - 2)
      y = clamp_speechbubble_value(y, 2, Graphics.height - height - 2)
      assign_speechbubble_window_position(window, x, y)
      window.z = 99999 if window.respond_to?(:z=)
    rescue
    end

    def normalize_speechbubble_message_window!(msgwindow)
      map_id = ($game_map.map_id rescue nil)
      return if respond_to?(:void_active_now?) && void_active_now?(map_id)
      temp = speechbubble_temp
      return if !temp || !msgwindow || !defined?(Graphics)
      return if (temp.speechbubble_bubble rescue nil).to_i != 2
      target = speechbubble_target_event
      force_speechbubble_window_visible!(msgwindow)
      msgwindow.x = 0 if msgwindow.respond_to?(:x=)
      msgwindow.width = Graphics.width if msgwindow.respond_to?(:width=)
      msgwindow.height = 102 if msgwindow.respond_to?(:height=)
      msgwindow.z = 99999 if msgwindow.respond_to?(:z=)
      if defined?(MessageConfig::WindowOpacity) && msgwindow.respond_to?(:back_opacity=)
        msgwindow.back_opacity = MessageConfig::WindowOpacity
      end
      force_up = temp.speechbubble_alwaysUp rescue false
      force_down = temp.speechbubble_alwaysDown rescue false
      target_y = target.respond_to?(:screen_y) ? target.screen_y : Graphics.height / 2
      player_facing_up = defined?($game_player) && $game_player && $game_player.direction == 8
      top = force_up || (!force_down && (target_y >= Graphics.height - 120 || player_facing_up))
      msgwindow.y = top ? 6 : Graphics.height - msgwindow.height - 6 if msgwindow.respond_to?(:y=)
      arrow = temp.speechbubble_arrow rescue nil
      ensure_speechbubble_arrow!(target, top) if target && !speechbubble_object_alive?(arrow)
      temp.speechbubble_outofrange = top && target_y >= Graphics.height - 120 if temp.respond_to?(:speechbubble_outofrange=)
    rescue
    end

    def speechbubble_arrow_bitmap(name)
      return RPG::Cache.load_bitmap_path("Graphics/Pictures/#{name}") if defined?(RPG) && defined?(RPG::Cache) && RPG::Cache.respond_to?(:load_bitmap_path)
      return Bitmap.new("Graphics/Pictures/#{name}") if defined?(Bitmap)
      return nil
    rescue
      return nil
    end

    def ensure_speechbubble_arrow!(target, top)
      temp = speechbubble_temp
      return if !temp || !target || !defined?(Graphics) || !defined?(Viewport) || !defined?(Sprite)
      clear_speechbubble_visuals!
      screen_x = target.respond_to?(:screen_x) ? target.screen_x : Graphics.width / 2
      screen_y = target.respond_to?(:screen_y) ? target.screen_y : Graphics.height / 2
      player_facing_up = defined?($game_player) && $game_player && $game_player.direction == 8
      force_up = temp.speechbubble_alwaysUp rescue false
      force_down = temp.speechbubble_alwaysDown rescue false
      natural_top = force_up || (!force_down && player_facing_up)
      out_of_range = !natural_top && screen_y >= Graphics.height - 120
      viewport = Viewport.new(0, (natural_top || out_of_range) ? 104 : 0, Graphics.width, 280)
      viewport.z = 999999 if viewport.respond_to?(:z=)
      arrow = Sprite.new(viewport)
      arrow.z = 999999 if arrow.respond_to?(:z=)
      arrow.zoom_x = 2 if arrow.respond_to?(:zoom_x=)
      arrow.zoom_y = 2 if arrow.respond_to?(:zoom_y=)
      arrow_name = "Arrow1"
      if natural_top || out_of_range
        arrow_name = "Arrow4"
        arrow.x = screen_x - Graphics.width if arrow.respond_to?(:x=)
        arrow.y = (screen_y - Graphics.height) - 136 if arrow.respond_to?(:y=)
        if (arrow.x rescue 0) < (out_of_range ? -250 : -230)
          arrow.x = screen_x if arrow.respond_to?(:x=)
          arrow_name = "Arrow3"
        end
        if out_of_range && (arrow.x rescue 0) >= 256
          arrow.x -= 15 if arrow.respond_to?(:x=)
          arrow_name = "Arrow3"
        end
      else
        arrow.x = screen_x if arrow.respond_to?(:x=)
        arrow.y = screen_y if arrow.respond_to?(:y=)
      end
      bitmap = speechbubble_arrow_bitmap(arrow_name)
      bitmap = speechbubble_arrow_bitmap("Arrow3") if !bitmap && (natural_top || out_of_range)
      if !bitmap
        dispose_speechbubble_object(arrow)
        dispose_speechbubble_object(viewport)
        return
      end
      arrow.bitmap = bitmap
      temp.speechbubble_outofrange = out_of_range if temp.respond_to?(:speechbubble_outofrange=)
      temp.speechbubble_vp = viewport if temp.respond_to?(:speechbubble_vp=)
      temp.speechbubble_arrow = arrow if temp.respond_to?(:speechbubble_arrow=)
    rescue
      clear_speechbubble_visuals!
    end
  end
end

if defined?(pbCallBub) && !defined?(tef_speechbubble_original_pbCallBub)
  alias tef_speechbubble_original_pbCallBub pbCallBub
end

def pbCallBub(status = 0, value = 0, always_down = false, always_up = false)
  TravelExpansionFramework.clear_speechbubble_visuals! if defined?(TravelExpansionFramework) && TravelExpansionFramework.respond_to?(:clear_speechbubble_visuals!)
  tef_speechbubble_original_pbCallBub(status, value, always_down, always_up) if defined?(tef_speechbubble_original_pbCallBub)
  if defined?($PokemonTemp) && $PokemonTemp && $PokemonTemp.respond_to?(:speechbubble_outofrange=)
    $PokemonTemp.speechbubble_outofrange = false
  end
rescue
end

if defined?(pbRepositionMessageWindow) && !defined?(tef_speechbubble_original_pbRepositionMessageWindow)
  alias tef_speechbubble_original_pbRepositionMessageWindow pbRepositionMessageWindow
end

def pbRepositionMessageWindow(msgwindow, linecount = 2)
  begin
    tef_speechbubble_original_pbRepositionMessageWindow(msgwindow, linecount) if defined?(tef_speechbubble_original_pbRepositionMessageWindow)
  rescue
    if msgwindow && defined?(Graphics)
      msgwindow.height = 102 if msgwindow.respond_to?(:height=)
      msgwindow.y = Graphics.height - msgwindow.height - 6 if msgwindow.respond_to?(:y=)
    end
  end
  TravelExpansionFramework.normalize_speechbubble_message_window!(msgwindow) if defined?(TravelExpansionFramework) && TravelExpansionFramework.respond_to?(:normalize_speechbubble_message_window!)
  if defined?(TravelExpansionFramework) && TravelExpansionFramework.respond_to?(:void_active_now?)
    map_id = ($game_map.map_id rescue nil)
    if TravelExpansionFramework.void_active_now?(map_id) && TravelExpansionFramework.respond_to?(:normalize_void_message_window!)
      TravelExpansionFramework.normalize_void_message_window!(msgwindow)
    end
  end
rescue
end

if defined?(pbDisposeMessageWindow) && !defined?(tef_speechbubble_original_pbDisposeMessageWindow)
  alias tef_speechbubble_original_pbDisposeMessageWindow pbDisposeMessageWindow
end

def pbDisposeMessageWindow(msgwindow)
  begin
    tef_speechbubble_original_pbDisposeMessageWindow(msgwindow) if defined?(tef_speechbubble_original_pbDisposeMessageWindow)
  ensure
    TravelExpansionFramework.reset_speechbubble_state! if defined?(TravelExpansionFramework) && TravelExpansionFramework.respond_to?(:reset_speechbubble_state!)
    if defined?(TravelExpansionFramework)
      TravelExpansionFramework.dispose_void_textbox_backdrop!(msgwindow) if TravelExpansionFramework.respond_to?(:dispose_void_textbox_backdrop!)
      TravelExpansionFramework.reset_void_message_state! if TravelExpansionFramework.respond_to?(:reset_void_message_state!)
    end
  end
end

if defined?(Window_AdvancedTextPokemon)
  class Window_AdvancedTextPokemon
    if method_defined?(:text=) && !method_defined?(:tef_speechbubble_original_text_equals)
      alias tef_speechbubble_original_text_equals text=
    end

    def text=(value)
      if defined?(TravelExpansionFramework) && TravelExpansionFramework.respond_to?(:void_active_now?)
        map_id = ($game_map.map_id rescue nil)
        if TravelExpansionFramework.void_active_now?(map_id)
          TravelExpansionFramework.reset_speechbubble_state! if TravelExpansionFramework.respond_to?(:reset_speechbubble_state!)
          value = TravelExpansionFramework.prepare_void_rendered_message_text(value, map_id) if TravelExpansionFramework.respond_to?(:prepare_void_rendered_message_text)
          TravelExpansionFramework.prepare_void_message_window_for_text!(self, value) if TravelExpansionFramework.respond_to?(:prepare_void_message_window_for_text!)
          if respond_to?(:setText)
            setText(value)
          elsif respond_to?(:tef_speechbubble_original_text_equals)
            tef_speechbubble_original_text_equals(value)
          end
          if TravelExpansionFramework.respond_to?(:void_message_text_blank?) &&
             TravelExpansionFramework.void_message_text_blank?(value)
            TravelExpansionFramework.dispose_void_textbox_backdrop!(self) if TravelExpansionFramework.respond_to?(:dispose_void_textbox_backdrop!)
            self.visible = false if respond_to?(:visible=)
            self.contents_opacity = 0 if respond_to?(:contents_opacity=)
          else
            self.visible = true if respond_to?(:visible=)
            self.contents_opacity = 255 if respond_to?(:contents_opacity=)
          end
          return
        end
      end
      temp = nil
      temp = $PokemonTemp if defined?($PokemonTemp) && $PokemonTemp
      mode = temp ? (temp.speechbubble_bubble rescue nil).to_i : 0
      if value != nil && value != "" && mode > 0 && defined?(TravelExpansionFramework)
        case mode
        when 1
          temp.speechbubble_bubble = 0 if temp.respond_to?(:speechbubble_bubble=)
          TravelExpansionFramework.force_speechbubble_window_visible!(self) if TravelExpansionFramework.respond_to?(:force_speechbubble_window_visible!)
          resizeToFit2(value, 400, 100) if respond_to?(:resizeToFit2)
          target = TravelExpansionFramework.speechbubble_target_event if TravelExpansionFramework.respond_to?(:speechbubble_target_event)
          TravelExpansionFramework.position_speechbubble_float!(self, target) if target && TravelExpansionFramework.respond_to?(:position_speechbubble_float!)
          setText(value)
          return
        when 2
          TravelExpansionFramework.force_speechbubble_window_visible!(self) if TravelExpansionFramework.respond_to?(:force_speechbubble_window_visible!)
          setText(value)
          return
        when 3
          temp.speechbubble_bubble = 0 if temp.respond_to?(:speechbubble_bubble=)
          TravelExpansionFramework.force_speechbubble_window_visible!(self) if TravelExpansionFramework.respond_to?(:force_speechbubble_window_visible!)
          resizeToFit2(value, 400, 100) if respond_to?(:resizeToFit2)
          target = defined?($game_player) ? $game_player : nil
          TravelExpansionFramework.position_speechbubble_float!(self, target) if target && TravelExpansionFramework.respond_to?(:position_speechbubble_float!)
          setText(value)
          return
        end
      end
      if respond_to?(:tef_speechbubble_original_text_equals)
        tef_speechbubble_original_text_equals(value)
      else
        setText(value)
      end
    end
  end
end
