// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design internal header
// See Vclock_tb.h for the primary calling header

#ifndef VERILATED_VCLOCK_TB___024UNIT_H_
#define VERILATED_VCLOCK_TB___024UNIT_H_  // guard

#include "verilated.h"
#include "verilated_timing.h"


class Vclock_tb__Syms;

class alignas(VL_CACHE_LINE_BYTES) Vclock_tb___024unit final {
  public:

    // DESIGN SPECIFIC STATE
    CData/*0:0*/ __VmonitorOff;
    QData/*63:0*/ __VmonitorNum;

    // INTERNAL VARIABLES
    Vclock_tb__Syms* vlSymsp;
    const char* vlNamep;

    // CONSTRUCTORS
    Vclock_tb___024unit();
    ~Vclock_tb___024unit();
    void ctor(Vclock_tb__Syms* symsp, const char* namep);
    void dtor();
    VL_UNCOPYABLE(Vclock_tb___024unit);

    // INTERNAL METHODS
    void __Vconfigure(bool first);
};


#endif  // guard
