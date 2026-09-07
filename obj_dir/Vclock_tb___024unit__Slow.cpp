// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vclock_tb.h for the primary calling header

#include "Vclock_tb__pch.h"

void Vclock_tb___024unit___ctor_var_reset(Vclock_tb___024unit* vlSelf);

Vclock_tb___024unit::Vclock_tb___024unit() = default;
Vclock_tb___024unit::~Vclock_tb___024unit() = default;

void Vclock_tb___024unit::ctor(Vclock_tb__Syms* symsp, const char* namep) {
    vlSymsp = symsp;
    vlNamep = strdup(Verilated::catName(vlSymsp->name(), namep));
    // Reset structure values
    Vclock_tb___024unit___ctor_var_reset(this);
}

void Vclock_tb___024unit::__Vconfigure(bool first) {
    (void)first;  // Prevent unused variable warning
}

void Vclock_tb___024unit::dtor() {
    VL_DO_DANGLING(std::free(const_cast<char*>(vlNamep)), vlNamep);
}
