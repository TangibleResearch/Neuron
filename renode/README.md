# Neuron32 as a Renode CPU

Wraps `rtl/neuron_core.sv` as a co-simulated CPU for
[Renode](https://renode.io), so Neuron32 can run inside a simulated
platform alongside Renode's peripheral models, instead of the standalone
`sim/` harness talking directly to `memory.sv`.

## Status: boots and steps against the real RTL. Not yet production-ready.

Verified, in order, by actually running `~/Applications/Renode.app` (not
inferred from docs):

1. `renode/build.sh` verilates `rtl/neuron_core.sv` and links
   `sim_neuron.cpp`/`sim_main.cpp` (a `DebuggableCPU` wrapping
   `Vneuron_core`, bridging its native bus to a Wishbone initiator via
   Renode's `IntegrationLibrary`) into `renode/build/libVtop.dylib`. This
   builds cleanly.
2. `renode/scripts/neuron.resc` loads `renode/platforms/neuron.repl`
   (`cpu: CoSimulated.CoSimulatedNeuron32 @ sysbus`, `cpuType: "neuron"`),
   points it at `libVtop.dylib`, loads `sim/testvectors/hello.bin` at
   `0x0`, and starts the machine.
3. Renode actually starts the machine, connects to the co-simulated core,
   and steps it: `sysbus.cpu ExecutedInstructions` after a `pause` reports
   a large nonzero count (real execution, not a stub).

Run it yourself:

```sh
~/Applications/Renode.app/Contents/MacOS/renode --disable-xwt --console \
    -e 'i @renode/scripts/neuron.resc' -e 'pause' -e 'sysbus.cpu ExecutedInstructions'
```

### Two real bugs fixed to get here (don't reintroduce them)

- **`CoSimulatedNeuron32.cs` was missing `using ELFSharp.ELF;`.**
  `CoSimulatedCPU`'s constructor takes an `Endianess` parameter, and that
  type is `ELFSharp.ELF.Endianess`, not something in
  `Antmicro.Renode.Peripherals.CPU` — confirmed by checking what
  `BaseCPU.cs` itself imports for the same type. Compiled fine once added.
- **`Antmicro.Renode.Plugins.CoSimulationPlugin` (the assembly containing
  `CoSimulatedCPU`) is not loaded at Renode startup.** Confirmed via
  `python "System.AppDomain.CurrentDomain.GetAssemblies()"` — it's absent
  until something actually instantiates a `CoSimulated.*` peripheral.
  Renode's `include @*.cs` compiles against only currently-loaded
  assemblies (`AdHocCompiler.cs` -> `AssemblyHelper.GetAssembliesLocations()`
  -> `AppDomain.CurrentDomain.GetAssemblies()`), so compiling
  `CoSimulatedNeuron32.cs` before anything else touches a `CoSimulated.*`
  type fails with "type or namespace CoSimulatedCPU could not be found" —
  even though the class and its base are both real, public, and correctly
  named. Fix: `neuron.resc` creates a **throwaway machine**, loads a
  built-in `CoSimulated.CoSimulatedUART` peripheral on it purely to force
  the assembly to load, removes that machine (`mach rem`), *then* compiles
  our class. It must be a separate, removed machine — an earlier version
  added the warmup peripheral to the real machine, and its
  never-configured connection crashed (`Marshal.StructureToPtr` null
  pointer) the instant `start` ran, since `start` starts every machine's
  peripherals, including ones you didn't mean to keep. If you're tempted
  to simplify this away, re-run the command above with a real `start`
  (not just `pause`) first.

### What's not done

1. **Halt detection.** `ExecutedInstructions` was ~1.5 million after a
   113-byte `hello.bin` (about 30 real instructions) — the core almost
   certainly HALTs correctly (`sim/run.sh` proves that against the same
   binary) but Renode keeps calling into it and counting cycles
   afterward. `Neuron::isHalted()` in `sim_neuron.cpp` needs to actually
   read `neuron_core`'s `halted` output and return it — check whether
   it's currently stubbed/always-false, and if so wire it up and confirm
   `ExecutedInstructions` stops growing once the program's real `HALT`
   executes.
2. **Shutdown exception.** Quitting Renode after a run throws
   `ObjectDisposedException` in
   `CoSimulationConnection.DisconnectAll -> LimitTimer.Reset ->
   BaseClockSource.AdvanceInner` (a `ThreadLocal` already disposed by the
   time cleanup runs) — this happens during Renode's own teardown, not
   during actual simulation, and didn't happen on every single quit
   attempt during development, so it may be a pre-existing Renode
   thread-shutdown race rather than something in our code. Reproduce with
   `-e 'i @renode/scripts/neuron.resc' -e 'quit'` (no `pause`) and see if
   it's consistent; if it only happens after our CPU has actually run for
   a while, it's more likely ours.
3. **GDB / register inspection is not implemented** — `Neuron`'s
   `getRegisterGetProgram`/`getRegisterSetProgram` in `sim_neuron.cpp` are
   stubbed. Don't call `sysbus.cpu PC ...` or connect GDB; both will hang
   waiting for a response that never comes. A real implementation needs a
   debug-injection mechanism on the RTL side (e.g. a reserved
   MOVI+STORE-based debug protocol) — there isn't one yet.
4. **No console/UART peripheral is wired up**, so `OUT` bytes currently go
   nowhere visible from Renode (unlike `sim/run.sh`, which streams them to
   stdout directly). Once halt detection works, the next useful step is
   probably a `CoSimulated`- or memory-mapped-register-based UART so `OUT`
   output is visible from the Renode monitor/console.
5. **Alignment**: `NeuronBusInterface` in `sim_neuron.h` assumes every
   32-bit access is 4-byte aligned (true for every current `.nuasm` test
   program, not enforced). Fine for now, flagged in the header comment
   too.

### Architecture notes for whoever picks this up

- The bus bridge is in C++ (`sim_neuron.cpp`/`.h`), not a separate SV APB3
  adapter — it reuses Renode's `IntegrationLibrary`
  `WishboneInitiator`/`CpuAgent` C++ templates directly against
  `neuron_core`'s native bus ports. This is simpler than writing and
  verifying a bespoke SV bus-protocol adapter and was a deliberate choice;
  don't add an SV-side adapter layer without a concrete reason to.
- `CMakeLists.txt` expects a local Renode source checkout for
  `IntegrationLibrary` headers/build files — see the top of that file for
  the exact path variable it reads. If you re-clone Renode's source,
  `renode/cmake/configure-and-verilate.cmake` is where that path is
  consumed.
- `sim_neuron.h`/`.cpp` implement `DebuggableCPU`, not the plainer `CPU`
  base — `CpuAgent` (from `IntegrationLibrary/src/peripherals/cpu-agent.h`)
  requires it even though we don't use the debug half of the interface.
