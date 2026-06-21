#==============================================================================
# 005_MenuWrapAround.rb          (Fork fix 2026-06-21: Universal menu wrap)
#==============================================================================
# ROOT BUG: SpriteWindow_Selectable#scroll_up / scroll_down only wrap at list
# boundaries when Input.trigger? is true (first press frame). On auto-repeat
# frames (holding the key), trigger? is false, so the wrap condition fails and
# the cursor gets stuck at the top or bottom of every menu.
#
# FIX: unconditionally run the modular-index math in both
#   SpriteWindow_Selectable  (base class)
#   SpriteWindow_SelectableEx (subclass that re-declares the same methods)
# so EVERY menu that inherits from either class wraps from top→bottom and
# bottom→top on both tap and hold.
#
# The @index != oldindex guard still prevents the cursor SE from firing when
# already at a boundary in a single-item list (no false-alarm sounds).
# jump_up / jump_down (Page-Up / Page-Down) are intentionally left alone
# because jumping past the ends of a long list is unintuitive.
#==============================================================================

class SpriteWindow_Selectable
  def scroll_up
    oldindex = @index
    @index   = (@index - @column_max + @item_max) % @item_max
    if @index != oldindex
      pbPlayCursorSE
      update_cursor_rect
    end
  end

  def scroll_down
    oldindex = @index
    @index   = (@index + @column_max) % @item_max
    if @index != oldindex
      pbPlayCursorSE
      update_cursor_rect
    end
  end
end

class SpriteWindow_SelectableEx
  def scroll_up
    oldindex = @index
    @index   = (@index - @column_max + @item_max) % @item_max
    if @index != oldindex
      pbPlayCursorSE
      update_cursor_rect
    end
  end

  def scroll_down
    oldindex = @index
    @index   = (@index + @column_max) % @item_max
    if @index != oldindex
      pbPlayCursorSE
      update_cursor_rect
    end
  end
end
