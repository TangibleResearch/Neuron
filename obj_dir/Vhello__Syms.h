// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Symbol table internal header
//
// Internal details; most calling programs do not need this header,
// unless using verilator public meta comments.

#ifndef VERILATED_VHELLO__SYMS_H_
#define VERILATED_VHELLO__SYMS_H_  // guard

#include "verilated.h"

// INCLUDE MODEL CLASS

#include "Vhello.h"

// INCLUDE MODULE CLASSES
#include "Vhello___024root.h"

// SYMS CLASS (contains all model state)
class alignas(VL_CACHE_LINE_BYTES) Vhello__Syms final : public VerilatedSyms {
  public:
    // INTERNAL STATE
    Vhello* const __Vm_modelp;
    VlDeleter __Vm_deleter;
    bool& __Vm_didInit;

    // MODULE INSTANCE STATE
    Vhello___024root               TOP;

    // CONSTRUCTORS
    Vhello__Syms(VerilatedContext* contextp, const char* namep, Vhello* modelp);
    ~Vhello__Syms();

    // METHODS
    const char* name() const { return TOP.vlNamep; }
};

#endif  // guard
