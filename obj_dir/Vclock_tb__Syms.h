// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Symbol table internal header
//
// Internal details; most calling programs do not need this header,
// unless using verilator public meta comments.

#ifndef VERILATED_VCLOCK_TB__SYMS_H_
#define VERILATED_VCLOCK_TB__SYMS_H_  // guard

#include "verilated.h"

// INCLUDE MODEL CLASS

#include "Vclock_tb.h"

// INCLUDE MODULE CLASSES
#include "Vclock_tb___024root.h"
#include "Vclock_tb___024unit.h"

// SYMS CLASS (contains all model state)
class alignas(VL_CACHE_LINE_BYTES) Vclock_tb__Syms final : public VerilatedSyms {
  public:
    // INTERNAL STATE
    Vclock_tb* const __Vm_modelp;
    VlDeleter __Vm_deleter;
    bool& __Vm_didInit;

    // MODULE INSTANCE STATE
    Vclock_tb___024root            TOP;
    Vclock_tb___024unit            TOP____024unit;

    // CONSTRUCTORS
    Vclock_tb__Syms(VerilatedContext* contextp, const char* namep, Vclock_tb* modelp);
    ~Vclock_tb__Syms();

    // METHODS
    const char* name() const { return TOP.vlNamep; }
};

#endif  // guard
