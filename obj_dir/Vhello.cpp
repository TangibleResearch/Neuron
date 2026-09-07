// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Model implementation (design independent parts)

#include "Vhello__pch.h"

//============================================================
// Constructors

Vhello::Vhello(VerilatedContext* _vcontextp__, const char* _vcname__)
    : VerilatedModel{*_vcontextp__}
    , vlSymsp{new Vhello__Syms(contextp(), _vcname__, this)}
    , m_evalLoop{*this, /*convergeLimit:*/ 10000}
    , rootp{&(vlSymsp->TOP)}
{
    // Register model with the context
    contextp()->addModel(this);
}

Vhello::Vhello(const char* _vcname__)
    : Vhello(Verilated::threadContextp(), _vcname__)
{
}

//============================================================
// Destructor

Vhello::~Vhello() {
    delete vlSymsp;
}

//============================================================
// Evaluation function

#ifdef VL_DEBUG
void Vhello___024root___eval_debug_assertions(Vhello___024root* vlSelf);
#endif  // VL_DEBUG
VL_ATTR_COLD void Vhello___024root___eval_static(Vhello___024root* vlSelf);
VL_ATTR_COLD void Vhello___024root___eval_initial(Vhello___024root* vlSelf);
VL_ATTR_COLD bool Vhello___024root___eval_stl(Vhello___024root* vlSelf, CData/*0:0*/ firstIteration);
void Vhello___024root___eval_sample(Vhello___024root* vlSelf);
bool Vhello___024root___eval_ico(Vhello___024root* vlSelf, CData/*0:0*/ firstIteration);
bool Vhello___024root___eval_act(Vhello___024root* vlSelf);
bool Vhello___024root___eval_inact(Vhello___024root* vlSelf);
bool Vhello___024root___eval_nba(Vhello___024root* vlSelf);
bool Vhello___024root___eval_obs(Vhello___024root* vlSelf);
bool Vhello___024root___eval_react(Vhello___024root* vlSelf);
void Vhello___024root___eval_postponed(Vhello___024root* vlSelf);
VL_ATTR_COLD void Vhello___024root___eval_final(Vhello___024root* vlSelf);
VL_ATTR_COLD void Vhello___024root___eval_dump_triggers__stl(Vhello___024root* vlSelf);
VL_ATTR_COLD void Vhello___024root___eval_dump_triggers__ico(Vhello___024root* vlSelf);
VL_ATTR_COLD void Vhello___024root___eval_dump_triggers__act(Vhello___024root* vlSelf);
VL_ATTR_COLD void Vhello___024root___eval_dump_triggers__nba(Vhello___024root* vlSelf);
VL_ATTR_COLD void Vhello___024root___eval_dump_triggers__obs(Vhello___024root* vlSelf);
VL_ATTR_COLD void Vhello___024root___eval_dump_triggers__react(Vhello___024root* vlSelf);

void Vhello::eval_step() {
    VL_DEBUG_IF(VL_DBG_MSGF("+++++TOP Evaluate Vhello::eval_step\n"); );
    m_evalLoop.eval();
}

void Vhello::evalBegin() {
#ifdef VL_DEBUG
    // Debug assertions
    Vhello___024root___eval_debug_assertions(&(vlSymsp->TOP));
#endif  // VL_DEBUG
    vlSymsp->__Vm_deleter.deleteAll();
}

void Vhello::evalEnd() {
    // Evaluate cleanup
    Verilated::endOfEval(vlSymsp->__Vm_evalMsgQp);
}

void Vhello::evalStatic() {
    Vhello___024root___eval_static(&(vlSymsp->TOP));
}

void Vhello::evalInitial() {
    Vhello___024root___eval_initial(&(vlSymsp->TOP));
}

bool Vhello::evalStl(bool firstIteration) {
    return Vhello___024root___eval_stl(&(vlSymsp->TOP), firstIteration);
}

void Vhello::evalSample() {
    Vhello___024root___eval_sample(&(vlSymsp->TOP));
}

bool Vhello::evalIco(bool firstIteration) {
    return Vhello___024root___eval_ico(&(vlSymsp->TOP), firstIteration);
}

bool Vhello::evalAct() {
    return Vhello___024root___eval_act(&(vlSymsp->TOP));
}

bool Vhello::evalInact() {
    return Vhello___024root___eval_inact(&(vlSymsp->TOP));
}

bool Vhello::evalNba() {
    return Vhello___024root___eval_nba(&(vlSymsp->TOP));
}

bool Vhello::evalObs() {
    return Vhello___024root___eval_obs(&(vlSymsp->TOP));
}

bool Vhello::evalReact() {
    return Vhello___024root___eval_react(&(vlSymsp->TOP));
}

void Vhello::evalPostponed() {
    Vhello___024root___eval_postponed(&(vlSymsp->TOP));
}

void Vhello::evalFinal() {
    Vhello___024root___eval_final(&(vlSymsp->TOP));
}

VL_ATTR_COLD void Vhello::dumpTriggersStl() {
    Vhello___024root___eval_dump_triggers__stl(&(vlSymsp->TOP));
}

VL_ATTR_COLD void Vhello::dumpTriggersIco() {
    Vhello___024root___eval_dump_triggers__ico(&(vlSymsp->TOP));
}

VL_ATTR_COLD void Vhello::dumpTriggersAct() {
    Vhello___024root___eval_dump_triggers__act(&(vlSymsp->TOP));
}

VL_ATTR_COLD void Vhello::dumpTriggersNba() {
    Vhello___024root___eval_dump_triggers__nba(&(vlSymsp->TOP));
}

VL_ATTR_COLD void Vhello::dumpTriggersObs() {
    Vhello___024root___eval_dump_triggers__obs(&(vlSymsp->TOP));
}

VL_ATTR_COLD void Vhello::dumpTriggersReact() {
    Vhello___024root___eval_dump_triggers__react(&(vlSymsp->TOP));
}

//============================================================
// Events and timing
bool Vhello::eventsPending() { return false; }

uint64_t Vhello::nextTimeSlot() {
    VL_FATAL_MT(__FILE__, __LINE__, "", "No delays in the design");
    return 0;
}

//============================================================
// Utilities

const char* Vhello::name() const {
    return vlSymsp->name();
}

//============================================================
// Invoke final blocks

VL_ATTR_COLD void Vhello::final() {
    contextp()->executingFinal(true);
    evalFinal();
    contextp()->executingFinal(false);
}

//============================================================
// Implementations of abstract methods from VerilatedModel

const char* Vhello::hierName() const { return vlSymsp->name(); }
const char* Vhello::modelName() const { return "Vhello"; }
unsigned Vhello::threads() const { return 1; }
void Vhello::prepareClone() const { contextp()->prepareClone(); }
void Vhello::atClone() const {
    contextp()->threadPoolpOnClone();
}
