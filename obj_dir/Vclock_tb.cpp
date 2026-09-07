// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Model implementation (design independent parts)

#include "Vclock_tb__pch.h"

//============================================================
// Constructors

Vclock_tb::Vclock_tb(VerilatedContext* _vcontextp__, const char* _vcname__)
    : VerilatedModel{*_vcontextp__}
    , vlSymsp{new Vclock_tb__Syms(contextp(), _vcname__, this)}
    , m_evalLoop{*this, /*convergeLimit:*/ 10000}
    , __PVT____024unit{vlSymsp->TOP.__PVT____024unit}
    , rootp{&(vlSymsp->TOP)}
{
    // Register model with the context
    contextp()->addModel(this);
}

Vclock_tb::Vclock_tb(const char* _vcname__)
    : Vclock_tb(Verilated::threadContextp(), _vcname__)
{
}

//============================================================
// Destructor

Vclock_tb::~Vclock_tb() {
    delete vlSymsp;
}

//============================================================
// Evaluation function

#ifdef VL_DEBUG
void Vclock_tb___024root___eval_debug_assertions(Vclock_tb___024root* vlSelf);
#endif  // VL_DEBUG
VL_ATTR_COLD void Vclock_tb___024root___eval_static(Vclock_tb___024root* vlSelf);
void Vclock_tb___024root___eval_initial(Vclock_tb___024root* vlSelf);
VL_ATTR_COLD bool Vclock_tb___024root___eval_stl(Vclock_tb___024root* vlSelf, CData/*0:0*/ firstIteration);
void Vclock_tb___024root___eval_sample(Vclock_tb___024root* vlSelf);
bool Vclock_tb___024root___eval_ico(Vclock_tb___024root* vlSelf, CData/*0:0*/ firstIteration);
bool Vclock_tb___024root___eval_act(Vclock_tb___024root* vlSelf);
bool Vclock_tb___024root___eval_inact(Vclock_tb___024root* vlSelf);
bool Vclock_tb___024root___eval_nba(Vclock_tb___024root* vlSelf);
bool Vclock_tb___024root___eval_obs(Vclock_tb___024root* vlSelf);
bool Vclock_tb___024root___eval_react(Vclock_tb___024root* vlSelf);
void Vclock_tb___024root___eval_postponed(Vclock_tb___024root* vlSelf);
VL_ATTR_COLD void Vclock_tb___024root___eval_final(Vclock_tb___024root* vlSelf);
VL_ATTR_COLD void Vclock_tb___024root___eval_dump_triggers__stl(Vclock_tb___024root* vlSelf);
VL_ATTR_COLD void Vclock_tb___024root___eval_dump_triggers__ico(Vclock_tb___024root* vlSelf);
VL_ATTR_COLD void Vclock_tb___024root___eval_dump_triggers__act(Vclock_tb___024root* vlSelf);
VL_ATTR_COLD void Vclock_tb___024root___eval_dump_triggers__nba(Vclock_tb___024root* vlSelf);
VL_ATTR_COLD void Vclock_tb___024root___eval_dump_triggers__obs(Vclock_tb___024root* vlSelf);
VL_ATTR_COLD void Vclock_tb___024root___eval_dump_triggers__react(Vclock_tb___024root* vlSelf);

void Vclock_tb::eval_step() {
    VL_DEBUG_IF(VL_DBG_MSGF("+++++TOP Evaluate Vclock_tb::eval_step\n"); );
    m_evalLoop.eval();
}

void Vclock_tb::evalBegin() {
#ifdef VL_DEBUG
    // Debug assertions
    Vclock_tb___024root___eval_debug_assertions(&(vlSymsp->TOP));
#endif  // VL_DEBUG
    vlSymsp->__Vm_deleter.deleteAll();
}

void Vclock_tb::evalEnd() {
    // Evaluate cleanup
    Verilated::endOfEval(vlSymsp->__Vm_evalMsgQp);
    vlSymsp->TOP.__VdlySched.cleanupForevered();
}

void Vclock_tb::evalStatic() {
    Vclock_tb___024root___eval_static(&(vlSymsp->TOP));
}

void Vclock_tb::evalInitial() {
    Vclock_tb___024root___eval_initial(&(vlSymsp->TOP));
}

bool Vclock_tb::evalStl(bool firstIteration) {
    return Vclock_tb___024root___eval_stl(&(vlSymsp->TOP), firstIteration);
}

void Vclock_tb::evalSample() {
    Vclock_tb___024root___eval_sample(&(vlSymsp->TOP));
}

bool Vclock_tb::evalIco(bool firstIteration) {
    return Vclock_tb___024root___eval_ico(&(vlSymsp->TOP), firstIteration);
}

bool Vclock_tb::evalAct() {
    return Vclock_tb___024root___eval_act(&(vlSymsp->TOP));
}

bool Vclock_tb::evalInact() {
    return Vclock_tb___024root___eval_inact(&(vlSymsp->TOP));
}

bool Vclock_tb::evalNba() {
    return Vclock_tb___024root___eval_nba(&(vlSymsp->TOP));
}

bool Vclock_tb::evalObs() {
    return Vclock_tb___024root___eval_obs(&(vlSymsp->TOP));
}

bool Vclock_tb::evalReact() {
    return Vclock_tb___024root___eval_react(&(vlSymsp->TOP));
}

void Vclock_tb::evalPostponed() {
    Vclock_tb___024root___eval_postponed(&(vlSymsp->TOP));
}

void Vclock_tb::evalFinal() {
    Vclock_tb___024root___eval_final(&(vlSymsp->TOP));
}

VL_ATTR_COLD void Vclock_tb::dumpTriggersStl() {
    Vclock_tb___024root___eval_dump_triggers__stl(&(vlSymsp->TOP));
}

VL_ATTR_COLD void Vclock_tb::dumpTriggersIco() {
    Vclock_tb___024root___eval_dump_triggers__ico(&(vlSymsp->TOP));
}

VL_ATTR_COLD void Vclock_tb::dumpTriggersAct() {
    Vclock_tb___024root___eval_dump_triggers__act(&(vlSymsp->TOP));
}

VL_ATTR_COLD void Vclock_tb::dumpTriggersNba() {
    Vclock_tb___024root___eval_dump_triggers__nba(&(vlSymsp->TOP));
}

VL_ATTR_COLD void Vclock_tb::dumpTriggersObs() {
    Vclock_tb___024root___eval_dump_triggers__obs(&(vlSymsp->TOP));
}

VL_ATTR_COLD void Vclock_tb::dumpTriggersReact() {
    Vclock_tb___024root___eval_dump_triggers__react(&(vlSymsp->TOP));
}

//============================================================
// Events and timing
bool Vclock_tb::eventsPending() { return !vlSymsp->TOP.__VdlySched.empty() && !contextp()->gotFinish(); }

uint64_t Vclock_tb::nextTimeSlot() { return vlSymsp->TOP.__VdlySched.nextTimeSlot(); }

//============================================================
// Utilities

const char* Vclock_tb::name() const {
    return vlSymsp->name();
}

//============================================================
// Invoke final blocks

VL_ATTR_COLD void Vclock_tb::final() {
    contextp()->executingFinal(true);
    evalFinal();
    contextp()->executingFinal(false);
}

//============================================================
// Implementations of abstract methods from VerilatedModel

const char* Vclock_tb::hierName() const { return vlSymsp->name(); }
const char* Vclock_tb::modelName() const { return "Vclock_tb"; }
unsigned Vclock_tb::threads() const { return 1; }
void Vclock_tb::prepareClone() const { contextp()->prepareClone(); }
void Vclock_tb::atClone() const {
    contextp()->threadPoolpOnClone();
}
