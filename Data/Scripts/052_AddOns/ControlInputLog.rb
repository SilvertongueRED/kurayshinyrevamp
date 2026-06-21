#===============================================================================
# ControlInputLog.rb  --  TEMPORARY confirm-input diagnostic  (2026-06-19)
#
# WHY THIS EXISTS
#   The "Pad A confirm double-fires (when bound to C) / needs a double-press
#   (when unbound)" bug happens ONLY on the bare game.exe, never under Steam
#   Input's virtual XInput pad. The confirm code has been rewritten 13 times
#   and every read is now derived from the press? LEVEL, so if it still doubles
#   the press? LEVEL itself must be misbehaving on the raw SDL device path.
#   This logger records the actual per-frame signal so we stop guessing.
#
#   Loads AFTER ControlRebind.rb (same folder, sorts later) so the remap/dedupe
#   aliases and the InputDedupe internals already exist.
#
# WHAT IT WRITES   ->   <game folder>/ControlInputLog.txt
#   One SESSION block per physical confirm-button press (press .. release+settle):
#     * per frame: raw ENGINE press?/trigger? for logical C and A (the device
#       truth, before our Ruby layer), plus the post-filter edgeC / confirm_latch
#       / b_edge and the confirm-latch internals (c_up / c_cool / c_armed)
#     * a VERDICT line counting how many times each fired for that ONE press
#       (each should be 1) and how many times press? FELL (1 = clean release,
#       >1 = the level dropped mid-hold = jitter = the real culprit)
#   The "bindings:" header line shows which SDL button maps to which logical
#   button, so you can tell the Pad-A->C vs Pad-A->A test runs apart.
#
# HOW TO USE
#   1. Run the BARE game.exe (NOT via Steam Input).
#   2. Open a menu that doubles (e.g. F3 Player List, Cases, a party submenu).
#   3. Press Confirm ONCE. Do that a handful of times. Then unbind Pad A from C
#      in the F1 menu and repeat. Quit.
#   4. Send me ControlInputLog.txt from the game folder.
#
# DEFAULT: ON. To disable, drop an empty file named ControlInputLog.OFF in the
# game folder. Auto-stops after ~300 KB. DELETE this .rb (and the .txt) before
# pushing to the public repo -- it is a diagnostic, not a feature.
#===============================================================================
unless defined?($control_input_log_installed) && $control_input_log_installed
  module ControlInputLog
    module_function

    SETTLE_FRAMES = 24       # keep logging this many frames after release
    SIZE_CAP      = 300_000  # bytes; stop past this so the file never bloats

    @on      = nil
    @active  = false
    @buf     = []
    @settle  = 0
    @fcount  = 0
    @session = 0
    @stopped = false
    @eTC = 0; @eTA = 0; @cl = 0; @ec = 0; @bc = 0
    @pTC = false; @pTA = false; @drops = 0; @was_down = false

    def root
      Dir.pwd
    rescue
      "."
    end

    def path
      File.join(root, "ControlInputLog.txt")
    rescue
      "ControlInputLog.txt"
    end

    def enabled?
      return false if @stopped
      return @on unless @on.nil?
      @on = !((File.exist?(File.join(root, "ControlInputLog.OFF")) rescue false))
      @on
    end

    # Raw ENGINE reads (post-keybindings, BEFORE our remap/dedupe/bridge layer) =
    # the closest Ruby-visible view of what the physical device actually delivers.
    def eP(b)
      (Input.respond_to?(:_rebind_orig_press?) ? Input._rebind_orig_press?(b) : Input.press?(b)) ? 1 : 0
    rescue
      0
    end

    def eT(b)
      (Input.respond_to?(:_rebind_orig_trigger?) ? Input._rebind_orig_trigger?(b) : Input.trigger?(b)) ? 1 : 0
    rescue
      0
    end

    # Peek an InputDedupe internal (optionally a hash key) without editing it.
    def dv(sym, key = nil)
      v = (InputDedupe.instance_variable_get(sym) rescue nil)
      return v if key.nil?
      v.is_a?(Hash) ? v[key] : nil
    rescue
      nil
    end

    def tgt_name(t)
      %w[A B C X Y Z L R].each do |n|
        c = (Input.const_get(n) rescue nil)
        return n if c && c == t
      end
      t.to_s
    rescue
      t.to_s
    end

    def binding_dump
      kp = (ControlRebind.instance_variable_get(:@kb_parsed) rescue nil)
      return "(@kb_parsed unavailable)" unless kp && kp[:entries]
      ents = kp[:entries].select { |h| h[:t] == 2 }
      return "(no controller-button bindings parsed)" if ents.empty?
      ents.map { |h| "SDL#{h[:u0]}->#{tgt_name(h[:tgt])}" }.join("  ")
    rescue
      "(binding dump failed)"
    end

    def tick
      return unless enabled?
      c = (Input::C rescue 13); a = (Input::A rescue 11)
      epc = eP(c); epa = eP(a); etc = eT(c); eta = eT(a)
      down = (epc == 1 || epa == 1)
      @fcount += 1

      if !@active && down
        @active = true; @settle = 0; @session += 1
        @eTC = 0; @eTA = 0; @cl = 0; @ec = 0; @bc = 0; @cvc = 0; @bvc = 0
        @pTC = false; @pTA = false; @drops = 0; @was_down = true
        @buf = []
        @buf << "=== SESSION #{@session}  #{(Time.now.strftime('%H:%M:%S') rescue '?')}  (one physical press) ==="
        @buf << "    FIX_BUILD = v4-engine-bridge (AUTOREPEAT_BRIDGE=#{(InputDedupe::AUTOREPEAT_BRIDGE rescue '?')}, text_advance-exempt) -- if you see this line the NEW code is running"
        @buf << "    bindings: #{binding_dump}"
        @buf << "    Input::C=#{c} Input::A=#{a}  bridge_active=#{(ControlRebind.mp_confirm_bridge_active? rescue '?')}"
        @buf << "    HID_active=#{(ControllerHIDInput.active? rescue '?')}  phys_readable=#{((ControlRebind.phys_held_sdl_set rescue nil) ? 'yes('+((ControlRebind.phys_held_sdl_set rescue {})||{}).keys.sort.inspect+')' : 'no')}"
        @buf << "    frame | ePc ePa | eTc eTa | physC | edgeC clatch bedgeC | FIXcv FIXbv | c_up c_cool c_armed"
      end

      if @active
        edgeC  = (dv(:@edge, c) ? 1 : 0)
        clatch = (dv(:@confirm_latch) ? 1 : 0)
        bedgeC = (dv(:@b_edge, c) ? 1 : 0)
        newcv  = (dv(:@cv_edge) ? 1 : 0)          # NEW menu-confirm edge (the fix)
        newbv  = (dv(:@bv_edge, c) ? 1 : 0)       # NEW per-button menu edge (the fix)
        physC  = (((ControlRebind.phys_held_sdl_set rescue {})||{})[0] ? 1 : 0)  # raw-HID: confirm button physically held?
        cup    = dv(:@c_up); ccool = dv(:@c_cool); carm = dv(:@c_armed)
        @eTC += 1 if etc == 1 && !@pTC
        @eTA += 1 if eta == 1 && !@pTA
        @pTC = (etc == 1); @pTA = (eta == 1)
        @cl += 1 if clatch == 1
        @ec += 1 if edgeC == 1
        @bc += 1 if bedgeC == 1
        @cvc += 1 if newcv == 1
        @bvc += 1 if newbv == 1
        @drops += 1 if @was_down && !down
        @was_down = down
        @buf << sprintf("    %5d |  %d   %d  |  %d   %d  |   %d   |   %d     %d      %d    |   %d     %d   | %4s %5s %5s",
                        @fcount, epc, epa, etc, eta, physC, edgeC, clatch, bedgeC, newcv, newbv,
                        cup.inspect, ccool.inspect, carm.inspect)
        if down
          @settle = 0
        else
          @settle += 1
          if @settle >= SETTLE_FRAMES
            @buf << "--- VERDICT: engineTrigEdges C=#{@eTC} A=#{@eTA} | OLD(dead) clatch=#{@cl} edgeC=#{@ec} bedgeC=#{@bc} | *** FIX cvEdge=#{@cvc} bvEdge=#{@bvc} *** | press?Drops=#{@drops}"
            @buf << "    (cvEdge/bvEdge are the NEW menu-confirm edges and SHOULD each be 1 even when engine/OLD show >1 = the auto-repeat is now collapsed)"
            @buf << ""
            flush
            @active = false
          end
        end
      end
    rescue
      @active = false
    end

    def flush
      File.open(path, "a") { |fh| fh.write(@buf.join("\n") + "\n") }
      @buf = []
      @stopped = true if ((File.size(path) rescue 0) > SIZE_CAP)
    rescue
      nil
    end
  end

  module Input
    class << self
      alias_method :_ctrlinputlog_prev_update, :update
      def update(*a)
        _ctrlinputlog_prev_update(*a)
        ControlInputLog.tick
      end
    end
  end
  $control_input_log_installed = true
end
