// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vregister_tb.h for the primary calling header

#include "Vregister_tb__pch.h"

VlCoroutine Vregister_tb___024root___eval_initial__TOP__Vtiming__0(Vregister_tb___024root* vlSelf);
VlCoroutine Vregister_tb___024root___eval_initial__TOP__Vtiming__1(Vregister_tb___024root* vlSelf);

void Vregister_tb___024root___eval_initial(Vregister_tb___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vregister_tb___024root___eval_initial\n"); );
    Vregister_tb__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    Vregister_tb___024root___eval_initial__TOP__Vtiming__0(vlSelf);
    Vregister_tb___024root___eval_initial__TOP__Vtiming__1(vlSelf);
}

void Vregister_tb___024root___eval_sample(Vregister_tb___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vregister_tb___024root___eval_sample\n"); );
    Vregister_tb__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
}

#ifdef VL_DEBUG
VL_ATTR_COLD void Vregister_tb___024root___dump_triggers__ico(const VlUnpacked<QData/*63:0*/, 1> &triggers, const std::string &tag);
#endif  // VL_DEBUG

bool Vregister_tb___024root___eval_ico(Vregister_tb___024root* vlSelf, CData/*0:0*/ firstIteration) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vregister_tb___024root___eval_ico\n"); );
    Vregister_tb__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    vlSelfRef.__VicoTriggered[0U] = ((0xfffffffffffffffeULL 
                                      & vlSelfRef.__VicoTriggered[0U]) 
                                     | (IData)((IData)(firstIteration)));
#ifdef VL_DEBUG
    if (VL_UNLIKELY(vlSymsp->_vm_contextp__->debug())) {
        Vregister_tb___024root___dump_triggers__ico(vlSelfRef.__VicoTriggered, "ico"s);
    }
#endif
    return (0U);
}

void Vregister_tb___024root___trigger_orInto__act_vec_vec(VlUnpacked<QData/*63:0*/, 1> &out, const VlUnpacked<QData/*63:0*/, 1> &in);
#ifdef VL_DEBUG
VL_ATTR_COLD void Vregister_tb___024root___dump_triggers__act(const VlUnpacked<QData/*63:0*/, 1> &triggers, const std::string &tag);
#endif  // VL_DEBUG
bool Vregister_tb___024root___trigger_anySet__act(const VlUnpacked<QData/*63:0*/, 1> &in);

bool Vregister_tb___024root___eval_act(Vregister_tb___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vregister_tb___024root___eval_act\n"); );
    Vregister_tb__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    CData/*0:0*/ __VactExecute;
    // Body
    {
        // Inlined CFunc: _eval_triggers_vec__act
        vlSelfRef.__VactTriggered[0U] = (QData)((IData)(
                                                        ((vlSelfRef.__VdlySched.awaitingCurrentTime() 
                                                          << 1U) 
                                                         | ((IData)(vlSelfRef.register_tb__DOT__clk) 
                                                            & (~ (IData)(vlSelfRef.__Vtrigprevexpr___TOP__register_tb__DOT__clk__0))))));
        vlSelfRef.__Vtrigprevexpr___TOP__register_tb__DOT__clk__0 
            = vlSelfRef.register_tb__DOT__clk;
    }
    Vregister_tb___024root___trigger_orInto__act_vec_vec(vlSelfRef.__VactTriggered, vlSelfRef.__VactTriggeredAcc);
#ifdef VL_DEBUG
    if (VL_UNLIKELY(vlSymsp->_vm_contextp__->debug())) {
        Vregister_tb___024root___dump_triggers__act(vlSelfRef.__VactTriggered, "act"s);
    }
#endif
    Vregister_tb___024root___trigger_orInto__act_vec_vec(vlSelfRef.__VnbaTriggered, vlSelfRef.__VactTriggered);
    __VactExecute = Vregister_tb___024root___trigger_anySet__act(vlSelfRef.__VactTriggered);
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

bool Vregister_tb___024root___eval_inact(Vregister_tb___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vregister_tb___024root___eval_inact\n"); );
    Vregister_tb__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    CData/*0:0*/ __VinactExecute;
    // Body
    __VinactExecute = vlSelfRef.__VdlySched.awaitingZeroDelay();
    if (__VinactExecute) {
        VL_FATAL_MT("tb/register_tb.sv", 3, "", "ZERODLY: Design Verilated with '--no-sched-zero-delay', but #0 delay executed at runtime");
    }
    return (__VinactExecute);
}

void Vregister_tb___024root___trigger_clear__act(VlUnpacked<QData/*63:0*/, 1> &out);

bool Vregister_tb___024root___eval_nba(Vregister_tb___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vregister_tb___024root___eval_nba\n"); );
    Vregister_tb__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Locals
    CData/*0:0*/ __VnbaExecute;
    // Body
    __VnbaExecute = Vregister_tb___024root___trigger_anySet__act(vlSelfRef.__VnbaTriggered);
    if (__VnbaExecute) {
        {
            // Inlined CFunc: _eval_body__nba
            if ((1ULL & vlSelfRef.__VnbaTriggered[0U])) {
                {
                    // Inlined CFunc: _nba_sequent__TOP__0
                    if (vlSelfRef.register_tb__DOT__reset) {
                        vlSelfRef.register_tb__DOT__data_out = 0U;
                    } else if (vlSelfRef.register_tb__DOT__write_enable) {
                        vlSelfRef.register_tb__DOT__data_out 
                            = vlSelfRef.register_tb__DOT__data_in;
                    }
                }
            }
        }
        Vregister_tb___024root___trigger_clear__act(vlSelfRef.__VnbaTriggered);
    }
    return (__VnbaExecute);
}

bool Vregister_tb___024root___eval_obs(Vregister_tb___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vregister_tb___024root___eval_obs\n"); );
    Vregister_tb__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    return (0U);
}

bool Vregister_tb___024root___eval_react(Vregister_tb___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vregister_tb___024root___eval_react\n"); );
    Vregister_tb__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    return (0U);
}

void Vregister_tb___024root___eval_postponed(Vregister_tb___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vregister_tb___024root___eval_postponed\n"); );
    Vregister_tb__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
}

VlCoroutine Vregister_tb___024root___eval_initial__TOP__Vtiming__0(Vregister_tb___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vregister_tb___024root___eval_initial__TOP__Vtiming__0\n"); );
    Vregister_tb__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    vlSelfRef.register_tb__DOT__reset = 1U;
    vlSelfRef.register_tb__DOT__write_enable = 0U;
    vlSelfRef.register_tb__DOT__data_in = 0U;
    co_await vlSelfRef.__VdlySched.delay(0x0000000000002710ULL, 
                                         nullptr, "tb/register_tb.sv", 
                                         26);
    vlSelfRef.register_tb__DOT__reset = 0U;
    vlSelfRef.register_tb__DOT__write_enable = 1U;
    vlSelfRef.register_tb__DOT__data_in = 0x0000002aU;
    co_await vlSelfRef.__VdlySched.delay(0x0000000000002710ULL, 
                                         nullptr, "tb/register_tb.sv", 
                                         32);
    vlSelfRef.register_tb__DOT__write_enable = 0U;
    co_await vlSelfRef.__VdlySched.delay(0x0000000000002710ULL, 
                                         nullptr, "tb/register_tb.sv", 
                                         36);
    VL_WRITEF_NX("Register value = %0d\n",1, '#',32,vlSelfRef.register_tb__DOT__data_out);
    VL_FINISH_MT("tb/register_tb.sv", 40, "");
    co_return;
}

VlCoroutine Vregister_tb___024root___eval_initial__TOP__Vtiming__1(Vregister_tb___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vregister_tb___024root___eval_initial__TOP__Vtiming__1\n"); );
    Vregister_tb__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
    // Body
    while (VL_LIKELY(!vlSymsp->_vm_contextp__->gotFinish())) {
        co_await vlSelfRef.__VdlySched.delay(0x0000000000001388ULL, 
                                             nullptr, 
                                             "tb/register_tb.sv", 
                                             11);
        vlSelfRef.register_tb__DOT__clk = (1U & (~ (IData)(vlSelfRef.register_tb__DOT__clk)));
    }
    co_return;
}

bool Vregister_tb___024root___trigger_anySet__ico(const VlUnpacked<QData/*63:0*/, 1> &in) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vregister_tb___024root___trigger_anySet__ico\n"); );
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

bool Vregister_tb___024root___trigger_anySet__act(const VlUnpacked<QData/*63:0*/, 1> &in) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vregister_tb___024root___trigger_anySet__act\n"); );
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

void Vregister_tb___024root___trigger_orInto__act_vec_vec(VlUnpacked<QData/*63:0*/, 1> &out, const VlUnpacked<QData/*63:0*/, 1> &in) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vregister_tb___024root___trigger_orInto__act_vec_vec\n"); );
    // Locals
    IData/*31:0*/ n;
    // Body
    n = 0U;
    do {
        out[n] = (out[n] | in[n]);
        n = ((IData)(1U) + n);
    } while ((0U >= n));
}

void Vregister_tb___024root___trigger_clear__act(VlUnpacked<QData/*63:0*/, 1> &out) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vregister_tb___024root___trigger_clear__act\n"); );
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
void Vregister_tb___024root___eval_debug_assertions(Vregister_tb___024root* vlSelf) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vregister_tb___024root___eval_debug_assertions\n"); );
    Vregister_tb__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    auto& vlSelfRef = std::ref(*vlSelf).get();
}
#endif  // VL_DEBUG
