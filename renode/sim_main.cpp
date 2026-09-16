#include "sim_neuron.h"
#include "src/renode.h"
#include "src/peripherals/cpu-agent.h"
#include "src/buses/wishbone-initiator.h"

// See https://github.com/verilator/verilator/blob/master/docs/guide/faq.rst#why-do-i-get-undefined-reference-to-sc_time_stamp
double sc_time_stamp() { return 0; }

Neuron *neuron = nullptr;
CpuAgent *agent = nullptr;

void evaluateModel()
{
    neuron->evaluateModel();
}

CpuAgent *initAgent()
{
    Verilated::commandArgs(0, (const char **)nullptr);
    CpuAgent *agent = new CpuAgent();
    return agent;
}

void initBus(CpuAgent *agent)
{
    WishboneInitiator<uint32_t, uint32_t> *bus = new WishboneInitiator<uint32_t, uint32_t>();

    neuron = new Neuron();
    neuron->setBus(*bus);

    agent->addBus(bus);
    agent->addCPU(neuron);

    bus->evaluateModel = evaluateModel;
}

RenodeAgent *Init()
{
    agent = initAgent();
    agent->connectNative();
    initBus(agent);
    return agent;
}

int main(int argc, char **argv, char **env)
{
    if (argc < 3)
    {
        printf("Usage: %s {receiverPort} {senderPort} [{address}]\n", argv[0]);
        exit(-1);
    }
    const char *address = argc < 4 ? "127.0.0.1" : argv[3];

    agent = initAgent();
    agent->connect(atoi(argv[1]), atoi(argv[2]), address);
    initBus(agent);
    agent->simulate();

    return 0;
}
