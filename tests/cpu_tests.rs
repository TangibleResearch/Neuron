use neuron::NeuronCpu;
use neuron::cpu::{FLAG_CARRY, FLAG_NEGATIVE, FLAG_OVERFLOW, FLAG_ZERO};

fn run(program: &[u8]) -> NeuronCpu {
    let mut memory = vec![0; 1024];
    memory[..program.len()].copy_from_slice(program);

    let mut cpu = NeuronCpu::new(memory.len() as u32);
    cpu.run(&mut memory);
    cpu
}

#[test]
fn executes_scalar_alu_instructions_through_the_cpu() {
    let program = [
        0x10, 0x01, 100, 0, 0, 0, // MOVI R1, 100
        0x10, 0x02, 40, 0, 0, 0, // MOVI R2, 40
        0x20, 0x03, 0x01, 0x02, // ADD R3, R1, R2
        0x21, 0x04, 0x01, 0x02, // SUB R4, R1, R2
        0x22, 0x05, 0x01, 0x02, // MUL R5, R1, R2
        0x23, 0x06, 0x01, 0x02, // DIV R6, R1, R2
        0x24, 0x07, 0x01, 0x02, // MOD R7, R1, R2
        0xFF, // HALT
    ];

    let cpu = run(&program);

    assert!(cpu.is_halted());
    assert_eq!(cpu.read_scalar(3), 140);
    assert_eq!(cpu.read_scalar(4), 60);
    assert_eq!(cpu.read_scalar(5), 4_000);
    assert_eq!(cpu.read_scalar(6), 2);
    assert_eq!(cpu.read_scalar(7), 20);
    assert_eq!(
        cpu.status() & (FLAG_ZERO | FLAG_NEGATIVE | FLAG_CARRY | FLAG_OVERFLOW),
        0
    );
}

#[test]
fn executes_mac_and_matrix_instructions_through_the_cpu() {
    let program = [
        0x10, 0x01, 2, 0, 0, 0, // MOVI R1, 2
        0x10, 0x02, 5, 0, 0, 0,    // MOVI R2, 5
        0x83, // MACCLR
        0x82, 0x01, 0x02, // MAC R1, R2
        0x82, 0x01, 0x02, // MAC R1, R2
        0x84, 0x03, // MACREAD R3
        0x90, 0x02, 0x00, 0x01, // MMUL M2, M0, M1
        0xFF, // HALT
    ];
    let mut memory = vec![0; 1024];
    memory[..program.len()].copy_from_slice(&program);
    let input = [
        [1, 2, 3, 4],
        [5, 6, 7, 8],
        [9, 10, 11, 12],
        [13, 14, 15, 16],
    ];
    let identity = [[1, 0, 0, 0], [0, 1, 0, 0], [0, 0, 1, 0], [0, 0, 0, 1]];
    let mut cpu = NeuronCpu::new(memory.len() as u32);
    cpu.write_matrix(0, input);
    cpu.write_matrix(1, identity);

    cpu.run(&mut memory);

    assert_eq!(cpu.read_scalar(3), 20);
    assert_eq!(cpu.mac_accumulator(), 20);
    assert_eq!(cpu.read_matrix(2), input);
}
