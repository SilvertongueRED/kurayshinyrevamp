#==============================================================================
# Blackscreen Transition Probe
#
# Retired diagnostic shim. The old version hooked map/transition/interpreter
# events and produced very large logs; keep this root Mods file as a harmless
# stub so stale references do not revive the probe.
#==============================================================================

module BlackscreenTransitionProbe
  ENABLED = false unless const_defined?(:ENABLED)

  def self.log(_message); end
end
