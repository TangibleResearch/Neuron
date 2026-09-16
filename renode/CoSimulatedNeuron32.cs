//
// Loadable Renode-side C# class for the Neuron32 co-simulated CPU.
// Load at runtime with: include @renode/CoSimulatedNeuron32.cs
// (no Renode rebuild needed — CoSimulatedCPU is a public class already
// present in Renode's built-in CoSimulationPlugin).
//
// Register access (GetRegisterValue32/SetRegisterValue32, and therefore
// `PC` below) round-trips through the C++ side's DebuggableCPU
// getRegisterGetProgram/getRegisterSetProgram methods, which are stubbed
// in renode/sim_neuron.cpp (no debug-injection mechanism exists in the
// RTL yet). Do NOT call `sysbus.cpu PC ...` or otherwise read/write a
// register from a .resc script or the Monitor — it will hang waiting for
// a response the C++ side never sends. Neuron's own RTL reset already
// sets PC=0, which is all every current .resc script needs.
using Antmicro.Renode.Core;
using Antmicro.Renode.Peripherals.CPU;

using ELFSharp.ELF;

using Machine = Antmicro.Renode.Core.Machine;

namespace Antmicro.Renode.Peripherals.CoSimulated
{
    public class CoSimulatedNeuron32 : CoSimulatedCPU
    {
        public CoSimulatedNeuron32(string cpuType, Machine machine, Endianess endianness = Endianess.LittleEndian,
            CpuBitness bitness = CpuBitness.Bits32, string address = null)
            : base(cpuType, machine, endianness, bitness, address)
        {
        }

        public override RegisterValue PC
        {
            // See the file-level note: not safe to call yet.
            get => GetRegisterValue32(0);
            set => SetRegisterValue32(0, checked((uint)value));
        }

        public override string Architecture { get { return "neuron"; } }

        protected override void InitializeRegisters()
        {
            // No GDB register map yet (PC above is only wired for the
            // abstract contract, not actually exercised) — see
            // CHATGPT.md's Renode backlog item for adding a real one
            // once the RTL has a debug-injection mechanism.
        }
    }
}
