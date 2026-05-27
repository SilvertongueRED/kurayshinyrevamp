#include "ruby.h"

#ifdef GBA_PLAYER_WITH_MGBA
#include <mgba/core/core.h>
#define GBA_PLAYER_HAS_MGBA 1
#else
#define GBA_PLAYER_HAS_MGBA 0
#endif

static VALUE gba_player_bridge_open_rom(VALUE self, VALUE path, VALUE mode, VALUE config)
{
  Check_Type(path, T_STRING);
  Check_Type(mode, T_STRING);
  (void)self;
  (void)config;

#if GBA_PLAYER_HAS_MGBA
  /* The full Windows/MKXP-Z child-surface implementation belongs here. */
  rb_warn("gba_player_bridge was compiled with libmgba headers, but window embedding is not implemented yet.");
  return Qfalse;
#else
  rb_warn("gba_player_bridge was compiled without libmgba headers.");
  return Qfalse;
#endif
}

static VALUE gba_player_bridge_close(VALUE self)
{
  (void)self;
  return Qtrue;
}

static VALUE gba_player_bridge_status(VALUE self)
{
  (void)self;
#if GBA_PLAYER_HAS_MGBA
  return rb_str_new_cstr("Native bridge loaded; libmgba headers detected; renderer not implemented.");
#else
  return rb_str_new_cstr("Native bridge loaded without libmgba support.");
#endif
}

void Init_gba_player_bridge(void)
{
  VALUE bridge = rb_define_module("GBAPlayerBridge");
  rb_define_singleton_method(bridge, "open_rom", gba_player_bridge_open_rom, 3);
  rb_define_singleton_method(bridge, "close", gba_player_bridge_close, 0);
  rb_define_singleton_method(bridge, "status", gba_player_bridge_status, 0);
}
