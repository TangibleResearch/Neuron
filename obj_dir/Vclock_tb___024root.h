// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design internal header
// See Vclock_tb.h for the primary calling header

#ifndef VERILATED_VCLOCK_TB___024ROOT_H_
#define VERILATED_VCLOCK_TB___024ROOT_H_  // guard

#include "verilated.h"
#include "verilated_timing.h"
class Vclock_tb___024unit;


class Vclock_tb__Syms;

class alignas(VL_CACHE_LINE_BYTES) Vclock_tb___024root final {
  public:
    // CELLS
    Vclock_tb___024unit* __PVT____024unit;

    // DESIGN SPECIFIC STATE
    CData/*0:0*/ clock_tb__DOT__clk;
    CData/*0:0*/ __Vtrigprevexpr___TOP__clock_tb__DOT__clk__0;
    IData/*31:0*/ __Vi;
    VlUnpacked<QData/*63:0*/, 1> __VstlTriggered;
    VlUnpacked<QData/*63:0*/, 1> __VicoTriggered;
    VlUnpacked<QData/*63:0*/, 1> __VactTriggered;
    VlUnpacked<QData/*63:0*/, 1> __VactTriggeredAcc;
    VlUnpacked<QData/*63:0*/, 1> __VnbaTriggered;
    VlDelayScheduler __VdlySched;

    // INTERNAL VARIABLES
    Vclock_tb__Syms* vlSymsp;
    const char* vlNamep;

    // CONSTRUCTORS
    Vclock_tb___024root(Vclock_tb__Syms* symsp, const char* namep);
    ~Vclock_tb___024root();
    VL_UNCOPYABLE(Vclock_tb___024root);

    // INTERNAL METHODS
    void __Vconfigure(bool first);
};


#endif  // guard
