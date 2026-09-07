// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vclock_tb.h for the primary calling header

#include "Vclock_tb__pch.h"

VlCoroutine Vclock_tb___024root___eval_initial__TOP__Vtiming__0(Vclock_tb___024root* vlSelf);
VlCoroutine Vclock_tb___024root___eval_initial__TOP__Vtiming__1(Vclock_tb___024root* vlSelf);

void Vclock_tb___024root___eval_initial(Vclock_tb___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vclock_tb___024root___eval_initial\n"); );
    Vclock_tb__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    Vclock_tb___024root___eval_initial__TOP__Vtiming__0(vlSelf);
    Vclock_tb___024root___eval_initial__TOP__Vtiming__1(vlSelf);
}

void Vclock_tb___024root___eval_sample(Vclock_tb___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vclock_tb___024root___eval_sample\n"); );
    Vclock_tb__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
}

#ifdef VL_DEBUG
VL_ATTR_COLD void Vclock_tb___024root___dump_triggers__ico(const VlUnpacked<QData/*63:0*/, 1> &triggers, const std::string &tag);
#endif  // VL_DEBUG

bool Vclock_tb___024root___eval_ico(Vclock_tb___024root* vlSelf, CData/*0:0*/ firstIteration) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vclock_tb___024root___eval_ico\n"); );
    Vclock_tb__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    vlSelfRef.__VicoTriggered[0U] = ((0xfffffffffffffffeULL 
                                      & vlSelfRef.__VicoTriggered[0U]) 
                                     | (IData)((IData)(firstIteration)));
#ifdef VL_DEBUG
    if (VL_UNLIKELY(vlSymsp->_vm_contextp__->debug())) {
        Vclock_tb___024root___dump_triggers__ico(vlSelfRef.__VicoTriggered, "ico"s);
    }
#endif
    return (0U);
}

void Vclock_tb___024root___trigger_orInto__act_vec_vec(VlUnpacked<QData/*63:0*/, 1> &out, const VlUnpacked<QData/*63:0*/, 1> &in);
#ifdef VL_DEBUG
VL_ATTR_COLD void Vclock_tb___024root___dump_triggers__act(const VlUnpacked<QData/*63:0*/, 1> &triggers, const std::string &tag);
#endif  // VL_DEBUG
bool Vclock_tb___024root___trigger_anySet__act(const VlUnpacked<QData/*63:0*/, 1> &in);

bool Vclock_tb___024root___eval_act(Vclock_tb___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vclock_tb___024root___eval_act\n"); );
    Vclock_tb__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    CData/*0:0*/ __VactExecute;
    // Body
    {
        // Inlined CFunc: _eval_triggers_vec__act
        vlSelfRef.__VactTriggered[0U] = (QData)((IData)(
                                                        ((vlSelfRef.__VdlySched.awaitingCurrentTime() 
                                                          << 1U) 
                                                         | ((IData)(vlSelfRef.clock_tb__DOT__clk) 
                                                            != (IData)(vlSelfRef.__Vtrigprevexpr___TOP__clock_tb__DOT__clk__0)))));
        vlSelfRef.__Vtrigprevexpr___TOP__clock_tb__DOT__clk__0 
            = vlSelfRef.clock_tb__DOT__clk;
    }
    Vclock_tb___024root___trigger_orInto__act_vec_vec(vlSelfRef.__VactTriggered, vlSelfRef.__VactTriggeredAcc);
#ifdef VL_DEBUG
    if (VL_UNLIKELY(vlSymsp->_vm_contextp__->debug())) {
        Vclock_tb___024root___dump_triggers__act(vlSelfRef.__VactTriggered, "act"s);
    }
#endif
    Vclock_tb___024root___trigger_orInto__act_vec_vec(vlSelfRef.__VnbaTriggered, vlSelfRef.__VactTriggered);
    __VactExecute = Vclock_tb___024root___trigger_anySet__act(vlSelfRef.__VactTriggered);
    if (__VactExecute) {
        vlSelfRef.__VactTriggeredAcc.fill(0ULL);
        {
            // Inlined CFunc: _timing_resume
            if ((2ULL & vlSelfRef.__VactTriggered[0U])) {
                vlSelfRef.__VdlySched.resume();
            }
        }
    }
    return (__VactExecute);
}

bool Vclock_tb___024root___eval_inact(Vclock_tb___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vclock_tb___024root___eval_inact\n"); );
    Vclock_tb__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    CData/*0:0*/ __VinactExecute;
    // Body
    __VinactExecute = vlSelfRef.__VdlySched.awaitingZeroDelay();
    if (__VinactExecute) {
        VL_FATAL_MT("tb/clock_tb.sv", 3, "", "ZERODLY: Design Verilated with '--no-sched-zero-delay', but #0 delay executed at runtime");
    }
    return (__VinactExecute);
}

void Vclock_tb___024root___trigger_clear__act(VlUnpacked<QData/*63:0*/, 1> &out);

bool Vclock_tb___024root___eval_nba(Vclock_tb___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vclock_tb___024root___eval_nba\n"); );
    Vclock_tb__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    CData/*0:0*/ __VnbaExecute;
    // Body
    __VnbaExecute = Vclock_tb___024root___trigger_anySet__act(vlSelfRef.__VnbaTriggered);
    if (__VnbaExecute) {
        {
            // Inlined CFunc: _eval_body__nba
            if ((1ULL & vlSelfRef.__VnbaTriggered[0U])) {
                {
                    // Inlined CFunc: _nba_sequent__TOP__0
                    if (VL_UNLIKELY((((~ (IData)(vlSymsp->TOP____024unit.__VmonitorOff)) 
                                      & (1U == vlSymsp->TOP____024unit.__VmonitorNum))))) {
                        VL_WRITEF_NX("time=%0t ns | clk=%b\n",3, 'T',-9
                                     , '#',64,VL_TIME_UNITED_Q(1000)
                                     , '#',1,(IData)(vlSelfRef.clock_tb__DOT__clk));
                    }
                }
            }
        }
        Vclock_tb___024root___trigger_clear__act(vlSelfRef.__VnbaTriggered);
    }
    return (__VnbaExecute);
}

bool Vclock_tb___024root___eval_obs(Vclock_tb___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vclock_tb___024root___eval_obs\n"); );
    Vclock_tb__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    return (0U);
}

bool Vclock_tb___024root___eval_react(Vclock_tb___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vclock_tb___024root___eval_react\n"); );
    Vclock_tb__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    return (0U);
}

void Vclock_tb___024root___eval_postponed(Vclock_tb___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vclock_tb___024root___eval_postponed\n"); );
    Vclock_tb__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
}

VlCoroutine Vclock_tb___024root___eval_initial__TOP__Vtiming__0(Vclock_tb___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vclock_tb___024root___eval_initial__TOP__Vtiming__0\n"); );
    Vclock_tb__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    vlSymsp->TOP____024unit.__VmonitorNum = 1U;
    co_await vlSelfRef.__VdlySched.delay(0x000000000000c350ULL, 
                                         nullptr, "tb/clock_tb.sv", 
                                         14);
    VL_FINISH_MT("tb/clock_tb.sv", 15, "");
    co_return;
}

VlCoroutine Vclock_tb___024root___eval_initial__TOP__Vtiming__1(Vclock_tb___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vclock_tb___024root___eval_initial__TOP__Vtiming__1\n"); );
    Vclock_tb__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    while (VL_LIKELY(!vlSymsp->_vm_contextp__->gotFinish())) {
        co_await vlSelfRef.__VdlySched.delay(0x0000000000001388ULL, 
                                             nullptr, 
                                             "tb/clock_tb.sv", 
                                             9);
        vlSelfRef.clock_tb__DOT__clk = (1U & (~ (IData)(vlSelfRef.clock_tb__DOT__clk)));
    }
    co_return;
}

bool Vclock_tb___024root___trigger_anySet__ico(const VlUnpacked<QData/*63:0*/, 1> &in) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vclock_tb___024root___trigger_anySet__ico\n"); );
    // Locals
    IData/*31:0*/ n;
    // Body
    n = 0U;
    do {
        if (in[n]) {
            return (1U);
        }
        n = ((IData)(1U) + n);
    } while ((1U > n));
    return (0U);
}

bool Vclock_tb___024root___trigger_anySet__act(const VlUnpacked<QData/*63:0*/, 1> &in) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vclock_tb___024root___trigger_anySet__act\n"); );
    // Locals
    IData/*31:0*/ n;
    // Body
    n = 0U;
    do {
        if (in[n]) {
            return (1U);
        }
        n = ((IData)(1U) + n);
    } while ((1U > n));
    return (0U);
}

void Vclock_tb___024root___trigger_orInto__act_vec_vec(VlUnpacked<QData/*63:0*/, 1> &out, const VlUnpacked<QData/*63:0*/, 1> &in) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vclock_tb___024root___trigger_orInto__act_vec_vec\n"); );
    // Locals
    IData/*31:0*/ n;
    // Body
    n = 0U;
    do {
        out[n] = (out[n] | in[n]);
        n = ((IData)(1U) + n);
    } while ((0U >= n));
}

void Vclock_tb___024root___trigger_clear__act(VlUnpacked<QData/*63:0*/, 1> &out) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vclock_tb___024root___trigger_clear__act\n"); );
    // Locals
    IData/*31:0*/ n;
    // Body
    n = 0U;
    do {
        out[n] = 0ULL;
        n = ((IData)(1U) + n);
    } while ((1U > n));
}

#ifdef VL_DEBUG
void Vclock_tb___024root___eval_debug_assertions(Vclock_tb___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vclock_tb___024root___eval_debug_assertions\n"); );
    Vclock_tb__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
}
#endif  // VL_DEBUG
