// src/main.rs

/// Neuron32 CPU state.
#[derive(Debug,  Clone, PartialEq, Eq, Hash, Copy)]
pub enum HardwareUnit {
    MatrixMultiply,
    VectorAdd,
    ReLUActivation,
}
pub struct ProcessingElement {
    pub unit_type: HardwareUnit,
    // Physical hardware input registers (buffers) instead of general registers
    pub input_buffer_a: Option<f32>,
    pub input_buffer_b: Option<f32>,
    // Hardware routing: Which physical downstream node coordinates receive the output
    pub target_node_id: Option<usize>,
    pub target_buffer_slot: u8, // 0 for Input A, 1 for Input B
}

pub struct AiAccelerator {
    pub processing_grid: Vec<ProcessingElement>,
    pub output_bus: Vec<Option<f32>>,
}
#[derive(Debug, Default)]
struct NeuronCpu {
    // =========================
    // Scalar General Registers
    // =========================
    r0: u32,
    r1: u32,
    r2: u32,
    r3: u32,
    r4: u32,
    r5: u32,
    r6: u32,
    r7: u32,
    r8: u32,
    r9: u32,
    r10: u32,
    r11: u32,
    r12: u32,
    r13: u32,
    r14: u32,
    r15: u32,

    // =========================
    // Vector Registers
    // =========================
    v0: [u32; 8],
    v1: [u32; 8],
    v2: [u32; 8],
    v3: [u32; 8],
    v4: [u32; 8],
    v5: [u32; 8],
    v6: [u32; 8],
    v7: [u32; 8],

    // =========================
    // Matrix / Tensor Registers
    // =========================
    m0: [[f32; 4]; 4],
    m1: [[f32; 4]; 4],
    m2: [[f32; 4]; 4],
    m3: [[f32; 4]; 4],

    // =========================
    // Predicate Registers
    // =========================
    p0: u8,
    p1: u8,
    p2: u8,
    p3: u8,

    // =========================
    // Special Registers
    // =========================
    pc: u32,
    sp: u32,
    fp: u32,
    status: u32,

    // =========================
    // AI Control Registers
    // =========================
    ai_mode: u32,
    quant_ctrl: u32,
    sparse_ctrl: u32,
    tensor_ctrl: u32,
    tensor_status: u32,

    // CPU execution state.
    halted: bool,
}

// =========================
// STATUS REGISTER FLAGS
// =========================

const FLAG_ZERO: u32 = 1 << 0;
const FLAG_NEGATIVE: u32 = 1 << 1;
const FLAG_CARRY: u32 = 1 << 2;
const FLAG_OVERFLOW: u32 = 1 << 3;

impl NeuronCpu {
    fn new(memory_size: u32) -> Self {
        Self {
            sp: memory_size,
            ..Default::default()
        }
    }

    // ============================================================
    // SCALAR REGISTER ACCESS
    // ============================================================

    fn read_scalar(&self, register: u8) -> u32 {
        match register {
            0 => self.r0,
            1 => self.r1,
            2 => self.r2,
            3 => self.r3,
            4 => self.r4,
            5 => self.r5,
            6 => self.r6,
            7 => self.r7,
            8 => self.r8,
            9 => self.r9,
            10 => self.r10,
            11 => self.r11,
            12 => self.r12,
            13 => self.r13,
            14 => self.r14,
            15 => self.r15,

            _ => {
                panic!("Invalid Neuron scalar register: R{}", register);
            }
        }
    }

    fn write_scalar(&mut self, register: u8, value: u32) {
        match register {
            0 => self.r0 = value,
            1 => self.r1 = value,
            2 => self.r2 = value,
            3 => self.r3 = value,
            4 => self.r4 = value,
            5 => self.r5 = value,
            6 => self.r6 = value,
            7 => self.r7 = value,
            8 => self.r8 = value,
            9 => self.r9 = value,
            10 => self.r10 = value,
            11 => self.r11 = value,
            12 => self.r12 = value,
            13 => self.r13 = value,
            14 => self.r14 = value,
            15 => self.r15 = value,

            _ => {
                panic!("Invalid Neuron scalar register: R{}", register);
            }
        }
    }

    // ============================================================
    // MEMORY HELPERS
    // ============================================================

    fn read_u32(memory: &[u8], address: u32) -> u32 {
        let start = address as usize;
        let end = start + 4;

        let bytes: [u8; 4] = memory[start..end]
            .try_into()
            .expect("Unable to read 32-bit value from Neuron memory");

        u32::from_le_bytes(bytes)
    }

    fn write_u32(memory: &mut [u8], address: u32, value: u32) {
        let start = address as usize;
        let end = start + 4;

        memory[start..end].copy_from_slice(&value.to_le_bytes());
    }

    fn fetch_u8(&mut self, memory: &[u8]) -> u8 {
        let value = memory[self.pc as usize];
        self.pc += 1;
        value
    }

    fn fetch_u32(&mut self, memory: &[u8]) -> u32 {
        let value = Self::read_u32(memory, self.pc);
        self.pc += 4;
        value
    }

    // ============================================================
    // STATUS FLAGS
    // ============================================================

    fn set_flag(&mut self, flag: u32, enabled: bool) {
        if enabled {
            self.status |= flag;
        } else {
            self.status &= !flag;
        }
    }

    fn flag(&self, flag: u32) -> bool {
        (self.status & flag) != 0
    }

    fn update_zero_negative(&mut self, value: u32) {
        self.set_flag(FLAG_ZERO, value == 0);

        self.set_flag(
            FLAG_NEGATIVE,
            (value & 0x8000_0000) != 0,
        );
    }

    // ============================================================
    // STACK
    // ============================================================

    fn push_u32(&mut self, memory: &mut [u8], value: u32) {
        self.sp = self
            .sp
            .checked_sub(4)
            .expect("Neuron stack underflow");

        Self::write_u32(memory, self.sp, value);
    }

    fn pop_u32(&mut self, memory: &[u8]) -> u32 {
        let value = Self::read_u32(memory, self.sp);

        self.sp = self
            .sp
            .checked_add(4)
            .expect("Neuron stack pointer overflow");

        value
    }

    // ============================================================
    // CPU EXECUTION
    // ============================================================

    fn step(&mut self, memory: &mut [u8]) {
        if self.halted {
            return;
        }

        let opcode_address = self.pc;

        let opcode = self.fetch_u8(memory);

        println!(
            "[FETCH] opcode {:#04X} at PC {}",
            opcode,
            opcode_address
        );

        match opcode {
            // ====================================================
            // 0x10 - MOVI
            //
            // MOVI destination, immediate32
            //
            // [10][dst][imm32]
            // ====================================================

            0x10 => {
                let destination = self.fetch_u8(memory);

                let immediate = self.fetch_u32(memory);

                self.write_scalar(destination, immediate);

                self.update_zero_negative(immediate);

                println!(
                    "  -> MOVI R{}, {}",
                    destination,
                    immediate
                );
            }

            // ====================================================
            // 0x11 - MOV
            //
            // MOV destination, source
            //
            // [11][dst][src]
            // ====================================================

            0x11 => {
                let destination = self.fetch_u8(memory);
                let source = self.fetch_u8(memory);

                let value = self.read_scalar(source);

                self.write_scalar(destination, value);

                println!(
                    "  -> MOV R{}, R{}",
                    destination,
                    source
                );
            }

            // ====================================================
            // 0x20 - ADD
            //
            // ADD destination, source_a, source_b
            // ====================================================

            0x20 => {
                let destination = self.fetch_u8(memory);
                let source_a = self.fetch_u8(memory);
                let source_b = self.fetch_u8(memory);

                let a = self.read_scalar(source_a);
                let b = self.read_scalar(source_b);

                let (result, carry) = a.overflowing_add(b);

                let signed_a = a as i32;
                let signed_b = b as i32;
                let signed_result = result as i32;

                let overflow =
                    (signed_a > 0 && signed_b > 0 && signed_result < 0)
                        || (signed_a < 0
                            && signed_b < 0
                            && signed_result >= 0);

                self.write_scalar(destination, result);

                self.update_zero_negative(result);
                self.set_flag(FLAG_CARRY, carry);
                self.set_flag(FLAG_OVERFLOW, overflow);

                println!(
                    "  -> ADD R{}, R{}, R{} = {}",
                    destination,
                    source_a,
                    source_b,
                    result
                );
            }

            // ====================================================
            // 0x21 - SUB
            // ====================================================

            0x21 => {
                let destination = self.fetch_u8(memory);
                let source_a = self.fetch_u8(memory);
                let source_b = self.fetch_u8(memory);

                let a = self.read_scalar(source_a);
                let b = self.read_scalar(source_b);

                let (result, borrow) = a.overflowing_sub(b);

                let signed_a = a as i32;
                let signed_b = b as i32;
                let signed_result = result as i32;

                let overflow =
                    (signed_a >= 0
                        && signed_b < 0
                        && signed_result < 0)
                        || (signed_a < 0
                            && signed_b >= 0
                            && signed_result >= 0);

                self.write_scalar(destination, result);

                self.update_zero_negative(result);

                self.set_flag(
                    FLAG_CARRY,
                    !borrow,
                );

                self.set_flag(
                    FLAG_OVERFLOW,
                    overflow,
                );

                println!(
                    "  -> SUB R{}, R{}, R{} = {}",
                    destination,
                    source_a,
                    source_b,
                    result
                );
            }

            // ====================================================
            // 0x22 - MUL
            // ====================================================

            0x22 => {
                let destination = self.fetch_u8(memory);
                let source_a = self.fetch_u8(memory);
                let source_b = self.fetch_u8(memory);

                let a = self.read_scalar(source_a);
                let b = self.read_scalar(source_b);

                let (result, overflow) =
                    a.overflowing_mul(b);

                self.write_scalar(
                    destination,
                    result,
                );

                self.update_zero_negative(result);

                self.set_flag(
                    FLAG_OVERFLOW,
                    overflow,
                );

                println!(
                    "  -> MUL R{}, R{}, R{} = {}",
                    destination,
                    source_a,
                    source_b,
                    result
                );
            }

            // ====================================================
            // 0x23 - DIV
            // ====================================================

            0x23 => {
                let destination = self.fetch_u8(memory);
                let source_a = self.fetch_u8(memory);
                let source_b = self.fetch_u8(memory);

                let a = self.read_scalar(source_a);
                let b = self.read_scalar(source_b);

                if b == 0 {
                    panic!("Neuron divide-by-zero exception");
                }

                let result = a / b;

                self.write_scalar(
                    destination,
                    result,
                );

                self.update_zero_negative(result);

                println!(
                    "  -> DIV R{}, R{}, R{} = {}",
                    destination,
                    source_a,
                    source_b,
                    result
                );
            }

            // ====================================================
            // 0x24 - MOD
            // ====================================================

            0x24 => {
                let destination = self.fetch_u8(memory);
                let source_a = self.fetch_u8(memory);
                let source_b = self.fetch_u8(memory);

                let a = self.read_scalar(source_a);
                let b = self.read_scalar(source_b);

                if b == 0 {
                    panic!("Neuron modulo-by-zero exception");
                }

                let result = a % b;

                self.write_scalar(
                    destination,
                    result,
                );

                self.update_zero_negative(result);

                println!(
                    "  -> MOD R{}, R{}, R{} = {}",
                    destination,
                    source_a,
                    source_b,
                    result
                );
            }

            // ====================================================
            // 0x30 - AND
            // ====================================================

            0x30 => {
                let destination = self.fetch_u8(memory);
                let source_a = self.fetch_u8(memory);
                let source_b = self.fetch_u8(memory);

                let result =
                    self.read_scalar(source_a)
                        & self.read_scalar(source_b);

                self.write_scalar(
                    destination,
                    result,
                );

                self.update_zero_negative(result);

                println!(
                    "  -> AND R{}, R{}, R{} = {}",
                    destination,
                    source_a,
                    source_b,
                    result
                );
            }

            // ====================================================
            // 0x31 - OR
            // ====================================================

            0x31 => {
                let destination = self.fetch_u8(memory);
                let source_a = self.fetch_u8(memory);
                let source_b = self.fetch_u8(memory);

                let result =
                    self.read_scalar(source_a)
                        | self.read_scalar(source_b);

                self.write_scalar(
                    destination,
                    result,
                );

                self.update_zero_negative(result);

                println!(
                    "  -> OR R{}, R{}, R{} = {}",
                    destination,
                    source_a,
                    source_b,
                    result
                );
            }

            // ====================================================
            // 0x32 - XOR
            // ====================================================

            0x32 => {
                let destination = self.fetch_u8(memory);
                let source_a = self.fetch_u8(memory);
                let source_b = self.fetch_u8(memory);

                let result =
                    self.read_scalar(source_a)
                        ^ self.read_scalar(source_b);

                self.write_scalar(
                    destination,
                    result,
                );

                self.update_zero_negative(result);

                println!(
                    "  -> XOR R{}, R{}, R{} = {}",
                    destination,
                    source_a,
                    source_b,
                    result
                );
            }

            // ====================================================
            // 0x33 - NOT
            //
            // NOT destination, source
            // ====================================================

            0x33 => {
                let destination = self.fetch_u8(memory);
                let source = self.fetch_u8(memory);

                let result =
                    !self.read_scalar(source);

                self.write_scalar(
                    destination,
                    result,
                );

                self.update_zero_negative(result);

                println!(
                    "  -> NOT R{}, R{} = {}",
                    destination,
                    source,
                    result
                );
            }

            // ====================================================
            // 0x34 - SHL
            // ====================================================

            0x34 => {
                let destination = self.fetch_u8(memory);
                let source = self.fetch_u8(memory);
                let amount_register = self.fetch_u8(memory);

                let value = self.read_scalar(source);

                let amount =
                    self.read_scalar(amount_register) & 31;

                let result =
                    value.wrapping_shl(amount);

                self.write_scalar(
                    destination,
                    result,
                );

                self.update_zero_negative(result);

                println!(
                    "  -> SHL R{}, R{}, R{} = {}",
                    destination,
                    source,
                    amount_register,
                    result
                );
            }

            // ====================================================
            // 0x35 - SHR
            // ====================================================

            0x35 => {
                let destination = self.fetch_u8(memory);
                let source = self.fetch_u8(memory);
                let amount_register = self.fetch_u8(memory);

                let value = self.read_scalar(source);

                let amount =
                    self.read_scalar(amount_register) & 31;

                let result =
                    value.wrapping_shr(amount);

                self.write_scalar(
                    destination,
                    result,
                );

                self.update_zero_negative(result);

                println!(
                    "  -> SHR R{}, R{}, R{} = {}",
                    destination,
                    source,
                    amount_register,
                    result
                );
            }

            // ====================================================
            // 0x40 - LOAD
            //
            // LOAD destination, address_register
            // ====================================================

            0x40 => {
                let destination = self.fetch_u8(memory);
                let address_register =
                    self.fetch_u8(memory);

                let address =
                    self.read_scalar(address_register);

                let value =
                    Self::read_u32(memory, address);

                self.write_scalar(
                    destination,
                    value,
                );

                println!(
                    "  -> LOAD R{}, [R{}] = {}",
                    destination,
                    address_register,
                    value
                );
            }

            // ====================================================
            // 0x41 - STORE
            //
            // STORE address_register, source
            // ====================================================

            0x41 => {
                let address_register =
                    self.fetch_u8(memory);

                let source =
                    self.fetch_u8(memory);

                let address =
                    self.read_scalar(address_register);

                let value =
                    self.read_scalar(source);

                Self::write_u32(
                    memory,
                    address,
                    value,
                );

                println!(
                    "  -> STORE [R{}], R{}",
                    address_register,
                    source
                );
            }

            // ====================================================
            // 0x50 - PUSH
            // ====================================================

            0x50 => {
                let source =
                    self.fetch_u8(memory);

                let value =
                    self.read_scalar(source);

                self.push_u32(
                    memory,
                    value,
                );

                println!(
                    "  -> PUSH R{} ({})",
                    source,
                    value
                );
            }

            // ====================================================
            // 0x51 - POP
            // ====================================================

            0x51 => {
                let destination =
                    self.fetch_u8(memory);

                let value =
                    self.pop_u32(memory);

                self.write_scalar(
                    destination,
                    value,
                );

                println!(
                    "  -> POP R{} ({})",
                    destination,
                    value
                );
            }

            // ====================================================
            // 0x60 - CMP
            //
            // CMP source_a, source_b
            //
            // Updates STATUS.
            // ====================================================

            0x60 => {
                let source_a =
                    self.fetch_u8(memory);

                let source_b =
                    self.fetch_u8(memory);

                let a =
                    self.read_scalar(source_a);

                let b =
                    self.read_scalar(source_b);

                let result =
                    a.wrapping_sub(b);

                self.update_zero_negative(result);

                self.set_flag(
                    FLAG_CARRY,
                    a >= b,
                );

                println!(
                    "  -> CMP R{}, R{}",
                    source_a,
                    source_b
                );
            }

            // ====================================================
            // 0x70 - JMP
            //
            // JMP absolute_address
            // ====================================================

            0x70 => {
                let address =
                    self.fetch_u32(memory);

                self.pc = address;

                println!(
                    "  -> JMP {}",
                    address
                );
            }

            // ====================================================
            // 0x71 - JZ
            // ====================================================

            0x71 => {
                let address =
                    self.fetch_u32(memory);

                if self.flag(FLAG_ZERO) {
                    self.pc = address;

                    println!(
                        "  -> JZ {} TAKEN",
                        address
                    );
                } else {
                    println!(
                        "  -> JZ {} NOT TAKEN",
                        address
                    );
                }
            }

            // ====================================================
            // 0x72 - JNZ
            // ====================================================

            0x72 => {
                let address =
                    self.fetch_u32(memory);

                if !self.flag(FLAG_ZERO) {
                    self.pc = address;

                    println!(
                        "  -> JNZ {} TAKEN",
                        address
                    );
                } else {
                    println!(
                        "  -> JNZ {} NOT TAKEN",
                        address
                    );
                }
            }

            // ====================================================
            // 0x80 - CALL
            //
            // CALL absolute_address
            // ====================================================

            0x80 => {
                let address =
                    self.fetch_u32(memory);

                let return_address =
                    self.pc;

                self.push_u32(
                    memory,
                    return_address,
                );

                self.pc = address;

                println!(
                    "  -> CALL {}",
                    address
                );
            }

            // ====================================================
            // 0x81 - RET
            // ====================================================

            0x81 => {
                let return_address =
                    self.pop_u32(memory);

                self.pc =
                    return_address;

                println!(
                    "  -> RET {}",
                    return_address
                );
            }

            // ====================================================
            // 0xFF - HALT
            // ====================================================

            0xFF => {
                self.halted = true;

                println!(
                    "  -> HALT"
                );
            }

            _ => {
                panic!(
                    "Unknown Neuron opcode: {:#04X}",
                    opcode
                );
            }
        }
    }
}

fn main() {
    let memory_size: u32 = 1024;

    let mut virtual_ram =
        vec![0_u8; memory_size as usize];

    // ============================================================
    // TEST PROGRAM
    // ============================================================
    //
    // MOVI R1, 500
    // MOVI R2, 200
    //
    // ADD R3, R1, R2
    //
    // MOVI R4, 700
    //
    // CMP R3, R4
    //
    // JNZ fail
    //
    // PUSH R3
    // POP R5
    //
    // HALT
    //
    // Expected:
    //
    // R3 = 700
    // R5 = 700
    // ZERO flag = 1
    //
    // ============================================================

    let machine_code: [u8; 35] = [
        // MOVI R1, 500
        0x10,
        0x01,
        0xF4,
        0x01,
        0x00,
        0x00,

        // MOVI R2, 200
        0x10,
        0x02,
        0xC8,
        0x00,
        0x00,
        0x00,

        // ADD R3, R1, R2
        0x20,
        0x03,
        0x01,
        0x02,

        // MOVI R4, 700
        0x10,
        0x04,
        0xBC,
        0x02,
        0x00,
        0x00,

        // CMP R3, R4
        0x60,
        0x03,
        0x04,

        // JNZ address 32
        0x72,
        0x20,
        0x00,
        0x00,
        0x00,

        // PUSH R3
        0x50,
        0x03,

        // POP R5
        0x51,
        0x05,

        // HALT
        0xFF,
    ];

    virtual_ram[0..machine_code.len()]
        .copy_from_slice(&machine_code);

    let mut cpu =
        NeuronCpu::new(memory_size);

    println!(
        "--- Neuron32 Boot ---"
    );

    println!(
        "{cpu:?}\n"
    );

    while !cpu.halted {
        cpu.step(
            &mut virtual_ram,
        );

        println!(
            "PC={} SP={} STATUS={:#010X}",
            cpu.pc,
            cpu.sp,
            cpu.status
        );

        println!();
    }

    println!(
        "--- Final Neuron State ---"
    );

    println!(
        "R1 = {}",
        cpu.read_scalar(1)
    );

    println!(
        "R2 = {}",
        cpu.read_scalar(2)
    );

    println!(
        "R3 = {}",
        cpu.read_scalar(3)
    );

    println!(
        "R4 = {}",
        cpu.read_scalar(4)
    );

    println!(
        "R5 = {}",
        cpu.read_scalar(5)
    );

    println!(
        "ZERO      = {}",
        cpu.flag(FLAG_ZERO)
    );

    println!(
        "NEGATIVE  = {}",
        cpu.flag(FLAG_NEGATIVE)
    );

    println!(
        "CARRY     = {}",
        cpu.flag(FLAG_CARRY)
    );

    println!(
        "OVERFLOW  = {}",
        cpu.flag(FLAG_OVERFLOW)
    );
}