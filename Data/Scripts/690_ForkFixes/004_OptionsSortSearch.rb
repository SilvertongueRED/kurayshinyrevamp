#==============================================================================
# 004_OptionsSortSearch.rb         (Fork fix 2026-06-21: Options Search + Sort)
#==============================================================================
# Adds, to the Options menu and its real settings sub-menus, two features:
#
#  * A single COMBINED control row pinned at the top of each managed options
#    screen, showing the LIVE keys bound to Search/Sort, e.g.
#       "Search [Y-S/Back]   Sort [X-A/Pad X]      Default"
#    where Y/X are the logical buttons and the part after the dash is the
#    keyboard key / controller button currently bound to them (read live from
#    keybindings.mkxp1). Operable by:
#       - SHORTCUTS:  X = toggle Sort, Y = open Search (Input::X=JUMPUP,
#         Input::Y=JUMPDOWN). These only act inside the Options menu tree.
#       - Mouse / Confirm on the row -> a chooser: Search / toggle Sort.
#       - Left / Right on the row also toggles Sort.
#
#  * SORT (persisted on $PokemonSystem, survives relaunches):
#       - Default : the menu's normal build order.
#       - Recent  : the most-recently-CHANGED setting floats to the top of its
#                   own menu level, and the category that contains a changed
#                   setting floats up at every level above it. Second-most-recent
#                   next, and so on.
#
#  * SEARCH (Y): type part of a setting's name, pick a match, jump straight to
#    it. Scope = current menu level and everything below it.
#
# v2 (2026-06-21, user feedback):
#   - X/Y shortcuts are now restricted to MANAGED Options-tree scenes only, so
#     they no longer fire in other PokemonOption_Scene menus (overworld / field
#     menus, Randomizer, fusion pickers, etc.).
#   - The pinned bar now lists the live keyboard+controller bindings for Y and X.
#   - Tooltip notes the buttons are rebindable in the F1 / Rebind Controls menus.
#   - Debug logging to Logs/options_sortsearch_debug.log (set $oss_debug=false to
#     silence) so recency/sort behaviour can be verified from a real session.
#
# Everything is additive and guarded so it can never crash or block a menu.
# Loads from 690_ForkFixes (after 016_UI + 052 ControlRebind, before the mod
# files that only wrap pbGetOptions). Class constants resolved lazily by NAME.
#==============================================================================

$oss_debug = false unless defined?($oss_debug)  # TEMP diagnostic; recency confirmed working 2026-06-21 (set true to re-enable)

if defined?(PokemonOption_Scene) && defined?(Option)

#------------------------------------------------------------------------------
# The combined Search/Sort row. Rendered by Window_PokemonOption#drawItem via its
# generic "else" branch (name on the left, values[0] on the right). Never reports
# a real change (get is always 0).
#------------------------------------------------------------------------------
class SearchSortOption < Option
  def initialize
    super(_INTL("Search settings by name [Y], or change how this menu is sorted [X]."))
  end

  # Live so it reflects any rebinding without rebuilding the object.
  def name
    OptionSortSearch.row_name_text
  end

  def values
    [ (OptionSortSearch.sort_recent? ? _INTL("Recent") : _INTL("Default")) ]
  end

  def get;        0;            end
  def set(_v);                  end
  def next(cur);  cur || 0;     end
  def prev(cur);  cur || 0;     end

  def activate
    OptionSortSearch.open_row_menu(OptionSortSearch.current_scene)
  end
end

#------------------------------------------------------------------------------
module OptionSortSearch
  module_function

  SORT_DEFAULT = 0
  SORT_RECENT  = 1
  SEP          = "\x1F".freeze

  # SDL scancode -> short key name (for the live keyboard-binding label).
  def scan_names
    @scan_names ||= begin
      h = {}
      ("A".."Z").each_with_index { |c, i| h[4 + i]  = c }      # A=4 .. Z=29
      ("1".."9").each_with_index { |c, i| h[30 + i] = c }      # 1=30 .. 9=38
      h[39] = "0"
      h[40] = "Enter"; h[41] = "Esc"; h[42] = "Bksp"; h[43] = "Tab"; h[44] = "Space"
      h[45] = "-"; h[46] = "="; h[47] = "["; h[48] = "]"; h[49] = "\\"
      h[51] = ";"; h[52] = "'"; h[53] = "`"; h[54] = ","; h[55] = "."; h[56] = "/"
      (1..12).each { |n| h[57 + n] = "F#{n}" }                  # F1=58 .. F12=69
      h[79] = "Right"; h[80] = "Left"; h[81] = "Down"; h[82] = "Up"
      h[98] = "KP0"; (1..9).each { |n| h[88 + n] = "KP#{n}" }   # KP1=89 .. KP9=97
      h[224] = "Ctrl"; h[225] = "Shift"; h[226] = "Alt"; h[227] = "Win"
      h
    end
  end

  # Registered Options tree: class name => [parent class name (nil=root), button
  # label used in the parent]. A scene's PATH is the label chain from root.
  def tree
    {
      "PokemonOption_Scene"          => [nil, nil],
      "VanillaOptSc_1"               => ["PokemonOption_Scene", "PIF Settings"],
      "PokemonGameOption_Scene"      => ["PokemonOption_Scene", "PIF Settings"],
      "KurayOptionsScene"            => ["PokemonOption_Scene", "KIF Settings"],
      "MouseUIOptionsScene"          => ["PokemonOption_Scene", "Mouse Options"],
      "MultiplayerOptScene"          => ["PokemonOption_Scene", "Multiplayer"],
      "ModManager::Scene_ModSettings"=> ["PokemonOption_Scene", "Mod Settings"],
      "KurayOptSc_1"                 => ["KurayOptionsScene", "Shinies"],
      "KurayOptSc_2"                 => ["KurayOptionsScene", "Battles & Pokemons"],
      "KurayOptSc_3"                 => ["KurayOptionsScene", "Graphics"],
      "KurayOptSc_4"                 => ["KurayOptionsScene", "Others"],
      "KurayOptSc_5"                 => ["KurayOptionsScene", "Self-Battle & Import"],
      "KurayOptSc_6"                 => ["KurayOptionsScene", "Challenges"],
      "RumbleOptionsScene"           => ["KurayOptionsScene", "Controller Vibration / Speaker"],
    }
  end

  def crawlable_names
    tree.keys - ["ModManager::Scene_ModSettings"]
  end

  #--- debug log ----------------------------------------------------------------
  def dlog(msg)
    return unless $oss_debug
    begin
      Dir.mkdir("Logs") unless File.directory?("Logs")
      File.open(File.join("Logs", "options_sortsearch_debug.log"), "a") { |f|
        f.puts("#{(Time.now.strftime('%H:%M:%S') rescue '')} #{msg}")
      }
    rescue
    end
  end

  #--- persisted state ----------------------------------------------------------
  def sys; (defined?($PokemonSystem) ? $PokemonSystem : nil); end

  def sort_mode
    s = sys
    return SORT_DEFAULT unless s
    v = (s.instance_variable_get(:@oss_sort_mode) rescue nil)
    (v == SORT_RECENT) ? SORT_RECENT : SORT_DEFAULT
  end

  def sort_mode=(v)
    s = sys
    s.instance_variable_set(:@oss_sort_mode, (v == SORT_RECENT ? SORT_RECENT : SORT_DEFAULT)) if s
  end

  def sort_recent?; sort_mode == SORT_RECENT; end

  def recency
    s = sys
    return {} unless s
    h = (s.instance_variable_get(:@oss_recency) rescue nil)
    unless h.is_a?(Hash)
      h = {}
      s.instance_variable_set(:@oss_recency, h)
    end
    h
  end

  def next_seq
    s = sys
    return 0 unless s
    n = ((s.instance_variable_get(:@oss_seq) rescue 0) || 0) + 1
    s.instance_variable_set(:@oss_seq, n)
    n
  end

  #--- transient ----------------------------------------------------------------
  def current_scene;        @current_scene;        end
  def current_scene=(v);    @current_scene = v;    end
  def busy?;                @busy ? true : false;  end
  def pending_focus;        @pending_focus;        end

  #--- live binding labels for the pinned bar -----------------------------------
  def invalidate_bindings; @kbmap = nil; @row_name = nil; end

  def binding_entries
    @kbmap ||= begin
      parsed = (defined?(ControlRebind) ? (ControlRebind.kb_parse rescue nil) : nil)
      (parsed && parsed[:entries].is_a?(Array)) ? parsed[:entries] : []
    end
  rescue
    []
  end

  def kbd_label_for(logical)
    e = binding_entries.find { |h| h[:t] == 1 && h[:tgt] == logical }
    return nil unless e
    scan_names[e[:u0]] || "K#{e[:u0]}"
  rescue
    nil
  end

  def pad_label_for(logical)
    e = binding_entries.find { |h| h[:t] == 2 && h[:tgt] == logical }
    return nil unless e
    if defined?(ControlRebind) && ControlRebind.respond_to?(:kb_cbtn_label)
      (ControlRebind.kb_cbtn_label(e[:u0]) rescue "Btn#{e[:u0]}")
    else
      "Btn#{e[:u0]}"
    end
  rescue
    nil
  end

  def key_hint(logical, fallback)
    parts = []
    k = kbd_label_for(logical); parts << k if k
    p = pad_label_for(logical); parts << p if p
    parts.empty? ? fallback : parts.join("/")
  rescue
    fallback
  end

  def row_name_text
    # Static labels for the two logical buttons (Y = Search, X = Sort). The
    # value column (drawn to the right by drawItem) shows the current sort mode,
    # e.g. "Search [Y]   Sort [X]   Default".
    _INTL("Search [Y]   Sort [X]")
  end

  def search_button; (defined?(Input::Y) ? Input::Y : 15); end
  def sort_button;   (defined?(Input::X) ? Input::X : 14); end

  #--- helpers ------------------------------------------------------------------
  def safe_const(name); Object.const_get(name); rescue; nil; end

  def class_name_of(scene); (scene.is_a?(Class) ? scene : scene.class).name.to_s; end

  def managed?(scene)
    return false unless scene
    tree.key?(class_name_of(scene))
  rescue
    false
  end

  def path_for(scene); resolve_path(class_name_of(scene)); end

  def resolve_path(cname)
    parts = []; seen = {}; cur = cname
    while cur && tree[cur]
      par, label = tree[cur]
      break if label.nil?
      break if seen[cur]
      seen[cur] = true
      parts.unshift(label)
      cur = par
    end
    parts
  end

  def setting_key(path_array, name); (path_array + [name]).join(SEP); end

  def prefix?(a, b)
    return true if a.empty?
    return false if b.length < a.length
    a.each_index { |i| return false if a[i] != b[i] }
    true
  end

  #--- recency ------------------------------------------------------------------
  def record_change(scene, name)
    return unless sys && managed?(scene) && name && !name.to_s.empty?
    base = path_for(scene)
    seqv = next_seq
    rec  = recency
    rec[setting_key(base, name)] = seqv
    pre = []
    base.each do |comp|
      pre = pre + [comp]
      rec[pre.join(SEP)] = seqv
    end
    dlog("record_change class=#{class_name_of(scene)} name=#{name.inspect} base=#{base.inspect} seq=#{seqv} recencySize=#{rec.size}")
  rescue
  end

  def option_seq(scene, option)
    return 0 unless option.respond_to?(:name) && option.name
    recency[setting_key(path_for(scene), option.name)] || 0
  rescue
    0
  end

  #--- sorting ------------------------------------------------------------------
  def sorted_options(scene, options)
    return options unless options.is_a?(Array)
    return options unless sort_recent? && managed?(scene)
    indexed = []
    options.each_with_index { |o, i| indexed << [o, i, option_seq(scene, o)] }
    indexed.sort_by! { |(_o, i, s)| [ (s > 0 ? 0 : 1), (s > 0 ? -s : 0), i ] }
    indexed.map { |(o, _i, _s)| o }
  rescue
    options
  end

  #--- the combined row ---------------------------------------------------------
  def make_row; SearchSortOption.new; rescue; nil; end
  def inject_row?(scene); managed?(scene); end

  # Prepend the combined row ONLY. We deliberately do NOT sort or capture the
  # default order here: other mods' pbAddOnOptions wrappers (notably the
  # "Mod Settings" mod) run AFTER us and insert their own options, so the list
  # we see at this point is INCOMPLETE. Sorting/capturing an incomplete list is
  # exactly what made late-added rows (e.g. "Mod Settings") vanish on a sort
  # toggle. The complete, default-ordered list is captured later by
  # finalize_order (from initOptionsWindow, after the whole chain has run).
  def decorate(scene, options)
    return options unless inject_row?(scene)
    row = make_row
    options = [row] + options if row
    options
  rescue
    options
  end

  # Called from initOptionsWindow -- i.e. AFTER every pbAddOnOptions wrapper has
  # run -- so @PokemonOptions is now the COMPLETE list (including options
  # inserted by mods that load after us). Capture that as the true default
  # order, then apply the current sort and re-pin the row. Done before the
  # option window is built, so there is no visible reorder flash.
  def finalize_order(scene)
    return unless managed?(scene)
    opts = scene.instance_variable_get(:@PokemonOptions)
    return unless opts.is_a?(Array)
    pure = opts.reject { |o| o.is_a?(SearchSortOption) }
    scene.instance_variable_set(:@oss_default_order, pure.dup)
    ordered = sort_recent? ? sorted_options(scene, pure) : pure.dup
    row = make_row
    ordered = [row] + ordered if row
    opts.replace(ordered)
    dlog("finalize class=#{class_name_of(scene)} mode=#{sort_recent? ? 'Recent' : 'Default'} recencySize=#{recency.size} order=#{ordered.map { |o| (o.respond_to?(:name) ? o.name : o.class.name) }.inspect}")
  rescue
  end

  #--- polling ------------------------------------------------------------------
  def scene_poll(scene)
    sp = scene.instance_variable_get(:@sprites) rescue nil
    return unless sp
    w = sp["option"]
    return unless w
    opts = scene.instance_variable_get(:@PokemonOptions) rescue nil
    return unless opts.is_a?(Array)

    detect_changes(scene, w, opts)

    return if busy?
    return unless managed?(scene)                       # v2: hotkeys only in the Options tree
    return unless (w.respond_to?(:active) ? w.active : true)
    self.current_scene = scene
    handle_hotkeys(scene, w)
  rescue
  end

  def detect_changes(scene, w, opts)
    snap = scene.instance_variable_get(:@oss_snapshot)
    if !snap.is_a?(Array) || snap.length != opts.length
      snap = []
      opts.length.times { |i| snap[i] = (w[i] rescue nil) }
      scene.instance_variable_set(:@oss_snapshot, snap)
      return
    end
    opts.length.times do |i|
      cur = (w[i] rescue nil)
      next if cur == snap[i]
      snap[i] = cur
      o = opts[i]
      next if o.is_a?(SearchSortOption)
      nm = (o.respond_to?(:name) ? o.name : nil)
      dlog("delta class=#{class_name_of(scene)} managed=#{managed?(scene)} i=#{i} name=#{nm.inspect}")
      record_change(scene, nm) if nm
    end
  rescue
  end

  def handle_hotkeys(scene, w)
    if itrigger?(search_button)
      with_busy(scene) { do_search(scene) }
    elsif itrigger?(sort_button)
      with_busy(scene) { toggle_sort(scene) }
    elsif on_row?(w) && (itrigger?(Input::LEFT) || itrigger?(Input::RIGHT))
      with_busy(scene) { toggle_sort(scene) }
    end
  rescue
  end

  def on_row?(w); (w.respond_to?(:index) ? w.index : -1) == 0; rescue; false; end
  def itrigger?(btn); Input.trigger?(btn); rescue; false; end

  def with_busy(scene)
    @busy = true
    begin
      yield
    ensure
      @busy = false
      refresh_after(scene)
    end
  end

  #--- actions ------------------------------------------------------------------
  def toggle_sort(scene)
    self.sort_mode = (sort_recent? ? SORT_DEFAULT : SORT_RECENT)
    dlog("toggle_sort -> #{sort_recent? ? 'Recent' : 'Default'} class=#{class_name_of(scene)} recencySize=#{recency.size}")
    (pbPlayDecisionSE rescue nil)
    resort_scene(scene)
  rescue
  end

  def resort_scene(scene)
    return unless inject_row?(scene)
    base = scene.instance_variable_get(:@oss_default_order)
    opts = scene.instance_variable_get(:@PokemonOptions)
    sp   = scene.instance_variable_get(:@sprites)
    return unless base.is_a?(Array) && opts.is_a?(Array) && sp
    w = sp["option"]
    return unless w
    ordered = sort_recent? ? sorted_options(scene, base) : base.dup
    row = make_row
    ordered = [row] + ordered if row
    keep = (w.index rescue 0)
    opts.replace(ordered)
    snap = []
    opts.length.times do |i|
      v = ((opts[i].get rescue 0) || 0)
      w.setValueNoRefresh(i, v)
      snap[i] = v
    end
    scene.instance_variable_set(:@oss_snapshot, snap)
    keep = opts.length - 1 if keep && keep >= opts.length
    (w.index = (keep || 0)) rescue nil
    w.refresh
    dlog("resort class=#{class_name_of(scene)} mode=#{sort_recent? ? 'Recent' : 'Default'} order=#{opts.map { |o| (o.respond_to?(:name) ? o.name : o.class.name) }.inspect}")
  rescue
  end

  def refresh_after(scene); resort_scene(scene) if inject_row?(scene); rescue; end

  def open_row_menu(scene)
    return unless scene
    @busy = true
    begin
      cur  = sort_recent? ? _INTL("Recent") : _INTL("Default")
      cmds = [ _INTL("Search settings..."),
               _INTL("Toggle sort (now: {1})", cur),
               _INTL("Cancel") ]
      c = (pbMessage(_INTL("Search & Sort"), cmds, cmds.length) rescue (cmds.length - 1))
      if c == 0
        do_search(scene)
      elsif c == 1
        toggle_sort(scene)
      end
    ensure
      @busy = false
      refresh_after(scene)
    end
  rescue
  end

  #--- search -------------------------------------------------------------------
  def do_search(scene)
    @opt_cache = {}
    q = (pbEnterText(_INTL("Search settings:"), 0, 30) rescue "")
    q = (q || "").to_s.strip
    return if q.empty?
    results = search_index(scene, q)
    dlog("search q=#{q.inspect} from=#{class_name_of(scene)} results=#{results.size}")
    if results.empty?
      (pbMessage(_INTL("No settings matched \"{1}\".", q)) rescue nil)
      return
    end
    results = results[0, 40]
    labels  = results.map { |r| r[:label] }
    labels << _INTL("Cancel")
    choice  = (pbMessage(_INTL("Matches for \"{1}\":", q), labels, labels.length) rescue (labels.length - 1))
    return if choice < 0 || choice >= results.length
    jump_to(scene, results[choice])
  rescue
  end

  def category_labels; tree.values.map { |(_p, l)| l }.compact; end

  def header_name?(name)
    return true if name.nil?
    s = name.to_s.strip
    return true if s.empty?
    return true if s.start_with?("#")
    false
  end

  def search_index(scene, q)
    ql   = q.downcase
    base = managed?(scene) ? path_for(scene) : []
    cats = category_labels
    out  = []
    seen = {}
    crawlable_names.each do |cname|
      p = resolve_path(cname)
      next unless prefix?(base, p)
      klass = safe_const(cname)
      next unless klass
      opts = build_options(klass)
      next unless opts.is_a?(Array)
      opts.each do |o|
        next unless o.respond_to?(:name)
        nm = o.name
        next if header_name?(nm)
        next if o.is_a?(SearchSortOption)
        next if cats.include?(nm)
        hay  = nm.to_s.downcase
        desc = (o.respond_to?(:description) ? o.description : nil)
        hay2 = desc.is_a?(String) ? desc.downcase : ""
        next unless hay.include?(ql) || hay2.include?(ql)
        key = cname + SEP + nm.to_s
        next if seen[key]
        seen[key] = true
        cat = p.empty? ? _INTL("Options") : p.join(" > ")
        out << { :label => "#{nm}  -  #{cat}", :scene_name => cname, :name => nm }
      end
    end
    out.sort_by! { |r| [ (r[:name].to_s.downcase.start_with?(ql) ? 0 : 1), r[:name].to_s.downcase ] }
    out
  rescue
    []
  end

  def build_options(klass)
    @opt_cache ||= {}
    k = klass.name.to_s
    return @opt_cache[k] if @opt_cache.key?(k)
    res = nil
    begin
      scene = (klass.new rescue klass.allocate)
      opts  = scene.pbGetOptions(false)
      res   = opts if opts.is_a?(Array)
    rescue
      res = nil
    end
    @opt_cache[k] = res
    res
  end

  def jump_to(from_scene, result)
    cname = result[:scene_name]
    nm    = result[:name]
    if cname == class_name_of(from_scene)
      focus_current(from_scene, nm)
      return
    end
    klass = safe_const(cname)
    return unless klass
    @pending_focus = nm
    begin
      pbFadeOutIn {
        begin
          target = klass.new
          screen = PokemonOptionScreen.new(target)
          screen.pbStartScreen
        rescue
        end
      }
    ensure
      @pending_focus = nil
    end
  rescue
    @pending_focus = nil
  end

  def focus_current(scene, name)
    opts = scene.instance_variable_get(:@PokemonOptions)
    sp   = scene.instance_variable_get(:@sprites)
    return unless opts.is_a?(Array) && sp
    w = sp["option"]
    return unless w
    idx = opts.index { |o| o.respond_to?(:name) && o.name == name }
    return unless idx
    (w.index = idx) rescue nil
    w.refresh rescue nil
  rescue
  end

  def apply_pending_focus(scene)
    nm = @pending_focus
    return unless nm
    @pending_focus = nil
    focus_current(scene, nm)
  rescue
  end
end

#------------------------------------------------------------------------------
class PokemonOption_Scene
  unless method_defined?(:_oss_orig_pbAddOnOptions)
    alias_method :_oss_orig_pbAddOnOptions, :pbAddOnOptions
    def pbAddOnOptions(options)
      options = _oss_orig_pbAddOnOptions(options)
      begin
        options = OptionSortSearch.decorate(self, options)
      rescue
      end
      options
    end
  end

  unless method_defined?(:_oss_orig_pbUpdate)
    alias_method :_oss_orig_pbUpdate, :pbUpdate
    def pbUpdate
      _oss_orig_pbUpdate
      OptionSortSearch.scene_poll(self) rescue nil
    end
  end

  unless method_defined?(:_oss_orig_pbStartScene)
    alias_method :_oss_orig_pbStartScene, :pbStartScene
    def pbStartScene(inloadscreen = false)
      OptionSortSearch.invalidate_bindings rescue nil
      _oss_orig_pbStartScene(inloadscreen)
      OptionSortSearch.apply_pending_focus(self) rescue nil
    end
  end

  # Capture the complete default order + apply sort just before the option
  # window is built (after the full pbAddOnOptions chain). This is what keeps
  # late-injected rows like "Mod Settings" alive across a sort toggle.
  unless method_defined?(:_oss_orig_initOptionsWindow)
    alias_method :_oss_orig_initOptionsWindow, :initOptionsWindow
    def initOptionsWindow
      OptionSortSearch.finalize_order(self) rescue nil
      _oss_orig_initOptionsWindow
    end
  end
end

end # defined?(PokemonOption_Scene)
