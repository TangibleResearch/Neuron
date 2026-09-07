// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Model implementation (design independent parts)

#include "Vregister_tb__pch.h"

//============================================================
// Constructors

Vregister_tb::Vregister_tb(VerilatedContext* _vcontextp__, const char* _vcname__)
    : VerilatedModel{*_vcontextp__}
    , vlSymsp{new Vregister_tb__Syms(contextp(), _vcname__, this)}
    , m_evalLoop{*this, /*convergeLimit:*/ 10000}
    , rootp{&(vlSymsp->TOP)}
{
    // Register model with the context
    contextp()->addModel(this);
}

Vregister_tb::Vregister_tb(const char* _vcname__)
    : Vregister_tb(Verilated::threadContextp(), _vcname__)
{
}

//============================================================
// Destructor

Vregister_tb::~Vregister_tb() {
    delete vlSymsp;
}

//============================================================
// Evaluation function

#ifdef VL_DEBUG
void Vregister_tb___024root___eval_debug_assertions(Vregister_tb___024root* vlSelf);
#endif  // VL_DEBUG
VL_ATTR_COLD void Vregister_tb___024root___eval_static(Vregister_tb___024root* vlSelf);
void Vregister_tb___024root___eval_initial(Vregister_tb___024root* vlSelf);
VL_ATTR_COLD bool Vregister_tb___024root___eval_stl(Vregister_tb___024root* vlSelf, CData/*0:0*/ firstIteration);
void Vregister_tb___024root___eval_sample(Vregister_tb___024root* vlSelf);
bool Vregister_tb___024root___eval_ico(Vregister_tb___024root* vlSelf, CData/*0:0*/ firstIteration);
bool Vregister_tb___024root___eval_act(Vregister_tb___024root* vlSelf);
bool Vregister_tb___024root___eval_inact(Vregister_tb___024root* vlSelf);
bool Vregister_tb___024root___eval_nba(Vregister_tb___024root* vlSelf);
bool Vregister_tb___024root___eval_obs(Vregister_tb___024root* vlSelf);
bool Vregister_tb___024root___eval_react(Vregister_tb___024root* vlSelf);
void Vregister_tb___024root___eval_postponed(Vregister_tb___024root* vlSelf);
VL_ATTR_COLD void Vregister_tb___024root___eval_final(Vregister_tb___024root* vlSelf);
VL_ATTR_COLD void Vregister_tb___024root___eval_dump_triggers__stl(Vregister_tb___024root* vlSelf);
VL_ATTR_COLD void Vregister_tb___024root___eval_dump_triggers__ico(Vregister_tb___024root* vlSelf);
VL_ATTR_COLD void Vregister_tb___024root___eval_dump_triggers__act(Vregister_tb___024root* vlSelf);
VL_ATTR_COLD void Vregister_tb___024root___eval_dump_triggers__nba(Vregister_tb___024root* vlSelf);
VL_ATTR_COLD void Vregister_tb___024root___eval_dump_triggers__obs(Vregister_tb___024root* vlSelf);
VL_ATTR_COLD void Vregister_tb___024root___eval_dump_triggers__react(Vregister_tb___024root* vlSelf);

void Vregister_tb::eval_step() {
    VL_DEBUG_IF(VL_DBG_MSGF("+++++TOP Evaluate Vregister_tb::eval_step\n"); );
    m_evalLoop.eval();
}

void Vregister_tb::evalBegin() {
#ifdef VL_DEBUG
    // Debug assertions
    Vregister_tb___024root___eval_debug_assertions(&(vlSymsp->TOP));
#endif  // VL_DEBUG
    vlSymsp->__Vm_deleter.deleteAll();
}

void Vregister_tb::evalEnd() {
    // Evaluate cleanup
    Verilated::endOfEval(vlSymsp->__Vm_evalMsgQp);
    vlSymsp->TOP.__VdlySched.cleanupForevered();
}

void Vregister_tb::evalStatic() {
    Vregister_tb___024root___eval_static(&(vlSymsp->TOP));
}

void Vregister_tb::evalInitial() {
    Vregister_tb___024root___eval_initial(&(vlSymsp->TOP));
}

bool Vregister_tb::evalStl(bool firstIteration) {
    return Vregister_tb___024root___eval_stl(&(vlSymsp->TOP), firstIteration);
}

void Vregister_tb::evalSample() {
    Vregister_tb___024root___eval_sample(&(vlSymsp->TOP));
}

bool Vregister_tb::evalIco(bool firstIteration) {
    return Vregister_tb___024root___eval_ico(&(vlSymsp->TOP), firstIteration);
}

bool Vregister_tb::evalAct() {
    return Vregister_tb___024root___eval_act(&(vlSymsp->TOP));
}

bool Vregister_tb::evalInact() {
    return Vregister_tb___024root___eval_inact(&(vlSymsp->TOP));
}

bool Vregister_tb::evalNba() {
    return Vregister_tb___024root___eval_nba(&(vlSymsp->TOP));
}

bool Vregister_tb::evalObs() {
    return Vregister_tb___024root___eval_obs(&(vlSymsp->TOP));
}

bool Vregister_tb::evalReact() {
    return Vregister_tb___024root___eval_react(&(vlSymsp->TOP));
}

void Vregister_tb::evalPostponed() {
    Vregister_tb___024root___eval_postponed(&(vlSymsp->TOP));
}

void Vregister_tb::evalFinal() {
    Vregister_tb___024root___eval_final(&(vlSymsp->TOP));
}

VL_ATTR_COLD void Vregister_tb::dumpTriggersStl() {
    Vregister_tb___024root___eval_dump_triggers__stl(&(vlSymsp->TOP));
}

VL_ATTR_COLD void Vregister_tb::dumpTriggersIco() {
    Vregister_tb___024root___eval_dump_triggers__ico(&(vlSymsp->TOP));
}

VL_ATTR_COLD void Vregister_tb::dumpTriggersAct() {
    Vregister_tb___024root___eval_dump_triggers__act(&(vlSymsp->TOP));
}

VL_ATTR_COLD void Vregister_tb::dumpTriggersNba() {
    Vregister_tb___024root___eval_dump_triggers__nba(&(vlSymsp->TOP));
}

VL_ATTR_COLD void Vregister_tb::dumpTriggersObs() {
    Vregister_tb___024root___eval_dump_triggers__obs(&(vlSymsp->TOP));
}

VL_ATTR_COLD void Vregister_tb::dumpTriggersReact() {
    Vregister_tb___024root___eval_dump_triggers__react(&(vlSymsp->TOP));
}

//============================================================
// Events and timing
bool Vregister_tb::eventsPending() { return !vlSymsp->TOP.__VdlySched.empty() && !contextp()->gotFinish(); }

uint64_t Vregister_tb::nextTimeSlot() { return vlSymsp->TOP.__VdlySched.nextTimeSlot(); }

//============================================================
// Utilities

const char* Vregister_tb::name() const {
    return vlSymsp->name();
}

//============================================================
// Invoke final blocks

VL_ATTR_COLD void Vregister_tb::final() {
    contextp()->executingFinal(true);
    evalFinal();
    contextp()->executingFinal(false);
}

//============================================================
// Implementations of abstract methods from VerilatedModel

const char* Vregister_tb::hierName() const { return vlSymsp->name(); }
const char* Vregister_tb::modelName() const { return "Vregister_tb"; }
unsigned Vregister_tb::threads() const { return 1; }
void Vregister_tb::prepareClone() const { contextp()->prepareClone(); }
void Vregister_tb::atClone() const {
    contextp()->threadPoolpOnClone();
}
