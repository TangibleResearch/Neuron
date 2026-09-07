// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vclock_tb.h for the primary calling header

#include "Vclock_tb__pch.h"

VL_ATTR_COLD void Vclock_tb___024unit___ctor_var_reset(Vclock_tb___024unit* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+      Vclock_tb___024unit___ctor_var_reset\n"); );
    Vclock_tb__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    vlSelf->__VmonitorNum = 0;
    vlSelf->__VmonitorOff = 0;
}
