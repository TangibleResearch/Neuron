// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vregister_tb.h for the primary calling header

#include "Vregister_tb__pch.h"

void Vregister_tb___024root___ctor_var_reset(Vregister_tb___024root* vlSelf);

Vregister_tb___024root::Vregister_tb___024root(Vregister_tb__Syms* symsp, const char* namep)
    : __VdlySched{*symsp->_vm_contextp__}
 {
    vlSymsp = symsp;
    vlNamep = strdup(namep);
    // Reset structure values
    Vregister_tb___024root___ctor_var_reset(this);
}

void Vregister_tb___024root::__Vconfigure(bool first) {
    (void)first;  // Prevent unused variable warning
}

Vregister_tb___024root::~Vregister_tb___024root() {
    VL_DO_DANGLING(std::free(const_cast<char*>(vlNamep)), vlNamep);
}
