module AutoplayBot
  module InputQueue
    module_function

    def reset
      @current_triggers = {}
      @next_triggers = {}
      @pressed = {}
      @dir = 0
      @dir_frames = 0
      @frame = 0
    end

    def begin_frame
      reset unless @current_triggers
      @frame += 1
      @current_triggers.clear
      if @next_triggers && !@next_triggers.empty?
        @next_triggers.each_key { |button| @current_triggers[button] = true }
        @next_triggers.clear
      end
      @pressed.keys.each do |button|
        @pressed[button] -= 1
        @pressed.delete(button) if @pressed[button] <= 0
      end
      if @dir_frames.to_i > 0
        @dir_frames -= 1
        @dir = 0 if @dir_frames <= 0
      else
        @dir = 0
      end
    end

    def clear
      reset
    end

    def empty?
      reset unless @current_triggers
      @current_triggers.empty? && @next_triggers.empty? && @pressed.empty? && @dir.to_i == 0
    end

    def resolve_button(button)
      return button if button.is_a?(Integer)
      return nil unless defined?(Input)
      name = button.to_s.upcase
      return Input.const_get(name) if Input.const_defined?(name)
      nil
    rescue
      nil
    end

    def tap(button, frames = 1)
      resolved = resolve_button(button)
      return false unless resolved
      reset unless @current_triggers
      @current_triggers[resolved] = true
      hold(resolved, frames)
      true
    end

    def tap_next(button, frames = 1)
      resolved = resolve_button(button)
      return false unless resolved
      reset unless @current_triggers
      @next_triggers ||= {}
      @next_triggers[resolved] = true
      hold(resolved, frames)
      true
    end

    def hold(button, frames = 1)
      resolved = resolve_button(button)
      return false unless resolved
      reset unless @current_triggers
      @pressed[resolved] = [@pressed[resolved].to_i, frames.to_i].max
      true
    end

    def hold_dir(direction, frames = 1)
      reset unless @current_triggers
      dir = direction.to_i
      hold_frames = [1, frames.to_i].max
      if @dir.to_i == dir
        @dir_frames = [@dir_frames.to_i, hold_frames].max
      else
        @dir = dir
        @dir_frames = hold_frames
      end
      button = direction_button(@dir)
      if button
        hold(button, @dir_frames)
        hold_run_modifier(@dir_frames)
      end
      true
    end

    def hold_run_modifier(frames = 1)
      return false unless defined?(AutoplayBot::Runtime) &&
                          AutoplayBot::Runtime.respond_to?(:run_modifier_allowed?) &&
                          AutoplayBot::Runtime.run_modifier_allowed?
      button = resolve_button(:ACTION)
      return false unless button
      hold(button, frames)
      true
    rescue
      false
    end

    def direction_button(direction)
      return :DOWN if direction.to_i == 2
      return :LEFT if direction.to_i == 4
      return :RIGHT if direction.to_i == 6
      return :UP if direction.to_i == 8
      nil
    end

    def triggered?(button)
      reset unless @current_triggers
      @current_triggers[button] == true
    end

    def pressed?(button)
      reset unless @current_triggers
      @pressed[button].to_i > 0
    end

    def repeated?(button)
      triggered?(button) || pressed?(button)
    end

    def dir4
      reset unless @current_triggers
      @dir.to_i
    end

    def dir8
      reset unless @current_triggers
      @dir.to_i
    end

    def dir_frames_remaining
      reset unless @current_triggers
      @dir_frames.to_i
    end
  end
end

AutoplayBot::InputQueue.reset
