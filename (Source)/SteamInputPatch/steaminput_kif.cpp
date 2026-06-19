//==============================================================================
// steaminput_kif.cpp  -  KIF Steam Input (native DualSense) Ruby binding
//------------------------------------------------------------------------------
// Adds a `SteamHaptics` Ruby module backed by the Steamworks Steam Input API.
// This lets KIF detect the REAL controller type (e.g. a DualSense reported as
// k_ESteamInputType_PS5Controller == 13) and drive its main motors, trigger
// motors and lightbar EVEN WHILE Steam Input is presenting the pad to the OS /
// SDL as a virtual Xbox 360 controller. (SDL alone only ever sees the virtual
// Xbox pad, so it cannot tell a DualSense apart behind Steam Input - the Steam
// Input API is the supported way to see through that.)
//
// Design notes
//  * Every InputHandle_t (uint64) stays INSIDE C++. Ruby never receives one,
//    because this engine's Win32API / MRI integer marshalling is 32-bit
//    oriented and cannot reliably pass a 64-bit handle back by value.
//  * Steamworks is initialised lazily on first use and shut down via atexit, so
//    no changes to the engine's main()/event loop are required. RunFrame() is
//    driven once per game frame by the Ruby side (Haptics.tick -> run_frame).
//  * If Steamworks fails to initialise (e.g. no App ID / Steam not running) or
//    no Steam-Input controller is connected, `available?` returns false and the
//    Ruby layer transparently falls back to the existing XInput backend.
//
// Build: add this file to the binding-mri sources, link steam_api64, add the
// Steamworks SDK public headers to the include path, and define MKXPZ_STEAM_INPUT.
// Without that define the module compiles to harmless stubs.
//==============================================================================
#include <ruby.h>

#ifdef MKXPZ_STEAM_INPUT
#include "steam/steam_api.h"
#include <cstdlib>

namespace {
  bool          g_inited = false;
  bool          g_ok     = false;
  InputHandle_t g_handles[STEAM_INPUT_MAX_COUNT];
  int           g_count  = 0;

  void shutdownSteam() {
    if (g_ok) { SteamAPI_Shutdown(); g_ok = false; }
  }

  void refresh() {
    if (!g_ok || !SteamInput()) return;
    SteamInput()->RunFrame();
    int n = SteamInput()->GetConnectedControllers(g_handles);
    g_count = (n < 0) ? 0 : n;
  }

  bool ensureInit() {
    if (g_inited) return g_ok;
    g_inited = true;
    if (!SteamAPI_Init())          return false;   // no App ID / Steam off -> graceful
    if (!SteamInput())             { SteamAPI_Shutdown(); return false; }
    SteamInput()->Init(true /* bExplicitlyCallRunFrame */);
    std::atexit(shutdownSteam);
    g_ok = true;
    refresh();                                      // populate handles immediately
    return true;
  }

  InputHandle_t primary() { return (g_count > 0) ? g_handles[0] : (InputHandle_t)0; }

  unsigned short clamp16(VALUE v) {
    long x = NUM2LONG(v);
    if (x < 0) x = 0; else if (x > 65535) x = 65535;
    return (unsigned short)x;
  }
  uint8 clamp8(VALUE v) {
    long x = NUM2LONG(v);
    if (x < 0) x = 0; else if (x > 255) x = 255;
    return (uint8)x;
  }

  VALUE si_available(VALUE) { return (ensureInit() && g_count > 0) ? Qtrue : Qfalse; }
  VALUE si_run_frame(VALUE) { if (ensureInit()) refresh(); return Qnil; }
  VALUE si_count(VALUE)     { return INT2NUM(ensureInit() ? g_count : 0); }

  VALUE si_type(VALUE) {
    if (!ensureInit()) return INT2NUM(0);
    InputHandle_t h = primary();
    if (!h) return INT2NUM(0);
    return INT2NUM((int)SteamInput()->GetInputTypeForHandle(h));
  }

  VALUE si_rumble(VALUE, VALUE lo, VALUE hi) {
    if (ensureInit()) { InputHandle_t h = primary();
      if (h) SteamInput()->TriggerVibration(h, clamp16(lo), clamp16(hi)); }
    return Qnil;
  }
  VALUE si_rumble_ex(VALUE, VALUE lo, VALUE hi, VALUE lt, VALUE rt) {
    if (ensureInit()) { InputHandle_t h = primary();
      if (h) SteamInput()->TriggerVibrationExtended(h, clamp16(lo), clamp16(hi), clamp16(lt), clamp16(rt)); }
    return Qnil;
  }
  VALUE si_led(VALUE, VALUE r, VALUE g, VALUE b) {
    if (ensureInit()) { InputHandle_t h = primary();
      if (h) SteamInput()->SetLEDColor(h, clamp8(r), clamp8(g), clamp8(b), k_ESteamInputLEDFlag_SetColor); }
    return Qnil;
  }
  VALUE si_led_reset(VALUE) {
    if (ensureInit()) { InputHandle_t h = primary();
      if (h) SteamInput()->SetLEDColor(h, 0, 0, 0, k_ESteamInputLEDFlag_RestoreUserDefault); }
    return Qnil;
  }
}

#else // ---------------- MKXPZ_STEAM_INPUT not defined: safe stubs --------------

namespace {
  VALUE si_available(VALUE)                                  { return Qfalse;    }
  VALUE si_run_frame(VALUE)                                  { return Qnil;      }
  VALUE si_count(VALUE)                                      { return INT2NUM(0);}
  VALUE si_type(VALUE)                                       { return INT2NUM(0);}
  VALUE si_rumble(VALUE, VALUE, VALUE)                       { return Qnil;      }
  VALUE si_rumble_ex(VALUE, VALUE, VALUE, VALUE, VALUE)      { return Qnil;      }
  VALUE si_led(VALUE, VALUE, VALUE, VALUE)                   { return Qnil;      }
  VALUE si_led_reset(VALUE)                                  { return Qnil;      }
}

#endif

void SteamHapticsBindingInit() {
  VALUE m = rb_define_module("SteamHaptics");
  rb_define_module_function(m, "available?",       RUBY_METHOD_FUNC(si_available),  0);
  rb_define_module_function(m, "run_frame",        RUBY_METHOD_FUNC(si_run_frame),  0);
  rb_define_module_function(m, "controller_count", RUBY_METHOD_FUNC(si_count),      0);
  rb_define_module_function(m, "controller_type",  RUBY_METHOD_FUNC(si_type),       0);
  rb_define_module_function(m, "rumble",           RUBY_METHOD_FUNC(si_rumble),     2);
  rb_define_module_function(m, "rumble_ex",        RUBY_METHOD_FUNC(si_rumble_ex),  4);
  rb_define_module_function(m, "led",              RUBY_METHOD_FUNC(si_led),        3);
  rb_define_module_function(m, "led_reset",        RUBY_METHOD_FUNC(si_led_reset),  0);
}
