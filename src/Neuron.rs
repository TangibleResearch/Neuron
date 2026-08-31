use neuron::NeuronCpu;

const MEMORY_SIZE: usize = 1024;

const PROGRAM: [u8; 25] = [
    // MOVI R1, 100
    0x10, 0x01, 100, 0, 0, 0, // MOVI R2, 40
    0x10, 0x02, 40, 0, 0, 0, // ADD R3, R1, R2
    0x20, 0x03, 0x01, 0x02, // SUB R4, R1, R2
    0x21, 0x04, 0x01, 0x02, // SUB R5, R2, R1
    0x21, 0x05, 0x02, 0x01, // HALT
    0xFF,
];

fn main() {
    let mut memory = vec![0_u8; MEMORY_SIZE];
    memory[..PROGRAM.len()].copy_from_slice(&PROGRAM);

    let mut cpu = NeuronCpu::new(MEMORY_SIZE as u32);

    println!("--- Neuron32 Boot ---");
    cpu.run(&mut memory);

    println!("--- Final Neuron State ---");
    println!(
        "PC={} SP={} STATUS={:#010X}",
        cpu.program_counter(),
        cpu.stack_pointer(),
        cpu.status()
    );
    for register in 1..=5 {
        println!("R{register} = {}", cpu.read_scalar(register));
    }
}
