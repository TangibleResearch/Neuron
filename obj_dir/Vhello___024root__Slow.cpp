// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vhello.h for the primary calling header

#include "Vhello__pch.h"

void Vhello___024root___ctor_var_reset(Vhello___024root* vlSelf);

Vhello___024root::Vhello___024root(Vhello__Syms* symsp, const char* namep)
 {
    vlSymsp = symsp;
    vlNamep = strdup(namep);
    // Reset structure values
    Vhello___024root___ctor_var_reset(this);
}

void Vhello___024root::__Vconfigure(bool first) {
    (void)first;  // Prevent unused variable warning
}

Vhello___024root::~Vhello___024root() {
    VL_DO_DANGLING(std::free(const_cast<char*>(vlNamep)), vlNamep);
}
