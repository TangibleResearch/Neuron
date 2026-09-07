// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design internal header
// See Vregister_tb.h for the primary calling header

#ifndef VERILATED_VREGISTER_TB___024ROOT_H_
#define VERILATED_VREGISTER_TB___024ROOT_H_  // guard

#include "verilated.h"
#include "verilated_timing.h"


class Vregister_tb__Syms;

class alignas(VL_CACHE_LINE_BYTES) Vregister_tb___024root final {
  public:

    // DESIGN SPECIFIC STATE
    CData/*0:0*/ register_tb__DOT__clk;
    CData/*0:0*/ register_tb__DOT__reset;
    CData/*0:0*/ register_tb__DOT__write_enable;
    CData/*0:0*/ __Vtrigprevexpr___TOP__register_tb__DOT__clk__0;
    IData/*31:0*/ register_tb__DOT__data_in;
    IData/*31:0*/ register_tb__DOT__data_out;
    IData/*31:0*/ __Vi;
    VlUnpacked<QData/*63:0*/, 1> __VstlTriggered;
    VlUnpacked<QData/*63:0*/, 1> __VicoTriggered;
    VlUnpacked<QData/*63:0*/, 1> __VactTriggered;
    VlUnpacked<QData/*63:0*/, 1> __VactTriggeredAcc;
    VlUnpacked<QData/*63:0*/, 1> __VnbaTriggered;
    VlDelayScheduler __VdlySched;

    // INTERNAL VARIABLES
    Vregister_tb__Syms* vlSymsp;
    const char* vlNamep;

    // CONSTRUCTORS
    Vregister_tb___024root(Vregister_tb__Syms* symsp, const char* namep);
    ~Vregister_tb___024root();
    VL_UNCOPYABLE(Vregister_tb___024root);

    // INTERNAL METHODS
    void __Vconfigure(bool first);
};


#endif  // guard
