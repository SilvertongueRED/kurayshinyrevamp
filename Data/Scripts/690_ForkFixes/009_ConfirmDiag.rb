#-------------------------------------------------------------------------------
# TEMP DIAGNOSTIC -- Pad A / Confirm double-fire.  Writes Logs/confirm_diag.log.
#
# Per frame (only when there is Confirm activity) it records what EVERY input
# layer reports for logical C, so a single physical Pad A press shows exactly
# where it becomes two edges:
#   finT  = final trigger?(C) the menus actually see (post full override chain)
#   finP  = final press?(C)        finR = final repeat?(C)
#   engT  = engine-native trigger?(C)   engP = engine-native press?(C)
#           (in clean OG KIF there is no override, so engT == finT)
#   padAct= fork pad layer edge (ControlRebind.pad_action_edge?)
#   bvEdge= de-dup virtual-hold edge (InputDedupe.edge?)
#   phys0 = raw-HID physical Pad A (SDL 0) held
#
# Loads last (690_ForkFixes) so its Input.update hook is OUTERMOST and reads the
# value menus see.  Set  $kif_confirm_diag = false  to silence.  REMOVE after fix.
# Works unchanged in the fork and in clean OG KIF (extra fields blank when absent).
#-------------------------------------------------------------------------------
$kif_confirm_diag = true if $kif_confirm_diag.nil?
KIF_CDIAG_DIR = (File.expand_path("Logs") rescue "Logs") unless defined?(KIF_CDIAG_DIR)

def kif_cdiag_log(msg)
  return unless $kif_confirm_diag
  begin
    Dir.mkdir(KIF_CDIAG_DIR) unless File.directory?(KIF_CDIAG_DIR)
  rescue
  end
  begin
    File.open(File.join(KIF_CDIAG_DIR, "confirm_diag.log"), "a:UTF-8") do |fh|
      fh.write("[#{Time.now.strftime('%H:%M:%S')} f#{(Graphics.frame_count rescue 0)}] #{msg}\n")
    end
  rescue
  end
rescue
end

kif_cdiag_log("=== confirm_diag loaded (fork=#{defined?(ControlRebind) ? 1 : 0}) ===")

module Input
  class << self
    unless method_defined?(:_cdiag_orig_update)
      alias_method :_cdiag_orig_update, :update
      def update(*a)
        _cdiag_orig_update(*a)
        begin
          c = (Input::C rescue 2)
          fin  = ((trigger?(c) rescue false) ? 1 : 0)
          pr   = ((press?(c)   rescue false) ? 1 : 0)
          rp   = ((repeat?(c)  rescue false) ? 1 : 0)
          eng  = ((respond_to?(:_rebind_orig_trigger?) ? (_rebind_orig_trigger?(c) rescue false) : (trigger?(c) rescue false)) ? 1 : 0)
          engp = ((respond_to?(:_rebind_orig_press?)   ? (_rebind_orig_press?(c)   rescue false) : (press?(c)   rescue false)) ? 1 : 0)
          pae  = ((defined?(ControlRebind) && ControlRebind.respond_to?(:pad_action_edge?) ? (ControlRebind.pad_action_edge?(c) rescue false) : false) ? 1 : 0)
          a    = (Input::A rescue 11)
          bv   = ((defined?(InputDedupe) && InputDedupe.respond_to?(:edge?) ? (InputDedupe.edge?(c) rescue false) : false) ? 1 : 0)
          bvA  = ((defined?(InputDedupe) && InputDedupe.respond_to?(:edge?) ? (InputDedupe.edge?(a) rescue false) : false) ? 1 : 0)
          cfm  = ((defined?(InputDedupe) && InputDedupe.respond_to?(:confirm_edge?) ? (InputDedupe.confirm_edge? rescue false) : false) ? 1 : 0)
          brg  = ((defined?(ControlRebind) && ControlRebind.respond_to?(:mp_confirm_bridge_active?) ? (ControlRebind.mp_confirm_bridge_active? rescue false) : false) ? 1 : 0)
          ph0  = ((defined?(ControlRebind) && ControlRebind.respond_to?(:phys_down?) ? (ControlRebind.phys_down?(0) rescue false) : false) ? 1 : 0)
          ph2  = ((defined?(ControlRebind) && ControlRebind.respond_to?(:phys_down?) ? (ControlRebind.phys_down?(2) rescue false) : false) ? 1 : 0)
          mL   = ((defined?(Input::MOUSELEFT) && (trigger?(Input::MOUSELEFT) rescue false)) ? 1 : 0)
          rc   = ((respond_to?(:mouse_ui_recent_real_confirm?) && (mouse_ui_recent_real_confirm? rescue false)) ? 1 : 0)
          if fin == 1 || pr == 1 || eng == 1 || engp == 1 || pae == 1 || bv == 1 || bvA == 1 || ph0 == 1 || ph2 == 1 || mL == 1
            kif_cdiag_log("finT=#{fin} finP=#{pr} finR=#{rp} | engT=#{eng} engP=#{engp} | padAct=#{pae} bvC=#{bv} bvA=#{bvA} cfm=#{cfm} brg=#{brg} phys0=#{ph0} phys2=#{ph2} mouseL=#{mL} recentC=#{rc}")
          end
        rescue
        end
      end
    end
  end
end
