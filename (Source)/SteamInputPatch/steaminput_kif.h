//==============================================================================
// steaminput_kif.h  -  KIF Steam Input (native DualSense) Ruby binding
//
// Call SteamHapticsBindingInit() once during MRI binding setup (see
// binding-mri.cpp). Safe to call whether or not MKXPZ_STEAM_INPUT is defined;
// when it is not defined, the registered Ruby module simply reports unavailable.
//==============================================================================
#ifndef STEAMINPUT_KIF_H
#define STEAMINPUT_KIF_H

void SteamHapticsBindingInit();

#endif // STEAMINPUT_KIF_H
