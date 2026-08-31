use crate::mac::Mac;
use crate::matrix::{Matrix, MatrixEngine};
use crate::scalar_alu::ScalarAlu;

pub const FLAG_ZERO: u32 = 1 << 0;
pub const FLAG_NEGATIVE: u32 = 1 << 1;
pub const FLAG_CARRY: u32 = 1 << 2;
pub const FLAG_OVERFLOW: u32 = 1 << 3;

#[derive(Debug, Default)]
pub struct NeuronCpu {
    mac: Mac,
    matrix_engine: MatrixEngine,
    scalar_alu: ScalarAlu,

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
    // Matrix Registers
    // =========================
    m0: Matrix,
    m1: Matrix,
    m2: Matrix,
    m3: Matrix,

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

    halted: bool,
}
impl NeuronCpu {
    pub fn new(memory_size: u32) -> Self {
        Self {
            sp: memory_size,
            ..Default::default()
        }
    }

    // ============================================================
    // SCALAR REGISTER ACCESS
    // ============================================================

    pub fn read_scalar(&self, register: u8) -> u32 {
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

    pub fn write_scalar(&mut self, register: u8, value: u32) {
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

    pub fn read_vector(&self, register: u8) -> [u32; 8] {
        match register {
            0 => self.v0,
            1 => self.v1,
            2 => self.v2,
            3 => self.v3,
            4 => self.v4,
            5 => self.v5,
            6 => self.v6,
            7 => self.v7,
            _ => panic!("Invalid Neuron vector register: V{}", register),
        }
    }

    pub fn write_vector(&mut self, register: u8, value: [u32; 8]) {
        match register {
            0 => self.v0 = value,
            1 => self.v1 = value,
            2 => self.v2 = value,
            3 => self.v3 = value,
            4 => self.v4 = value,
            5 => self.v5 = value,
            6 => self.v6 = value,
            7 => self.v7 = value,
            _ => panic!("Invalid Neuron vector register: V{}", register),
        }
    }

    // ============================================================
    // MATRIX REGISTER ACCESS
    // ============================================================

    pub fn read_matrix(&self, register: u8) -> Matrix {
        match register {
            0 => self.m0,
            1 => self.m1,
            2 => self.m2,
            3 => self.m3,
            _ => panic!("Invalid Neuron matrix register: M{}", register),
        }
    }

    pub fn write_matrix(&mut self, register: u8, value: Matrix) {
        match register {
            0 => self.m0 = value,
            1 => self.m1 = value,
            2 => self.m2 = value,
            3 => self.m3 = value,
            _ => panic!("Invalid Neuron matrix register: M{}", register),
        }
    }

    pub fn read_predicate(&self, register: u8) -> u8 {
        match register {
            0 => self.p0,
            1 => self.p1,
            2 => self.p2,
            3 => self.p3,
            _ => panic!("Invalid Neuron predicate register: P{}", register),
        }
    }

    pub fn write_predicate(&mut self, register: u8, value: u8) {
        match register {
            0 => self.p0 = value,
            1 => self.p1 = value,
            2 => self.p2 = value,
            3 => self.p3 = value,
            _ => panic!("Invalid Neuron predicate register: P{}", register),
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

        self.set_flag(FLAG_NEGATIVE, (value & 0x8000_0000) != 0);
    }

    // ============================================================
    // STACK
    // ============================================================

    fn push_u32(&mut self, memory: &mut [u8], value: u32) {
        self.sp = self.sp.checked_sub(4).expect("Neuron stack underflow");

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

    pub fn step(&mut self, memory: &mut [u8]) {
        if self.halted {
            return;
        }

        let opcode_address = self.pc;

        let opcode = self.fetch_u8(memory);

        println!("[FETCH] opcode {:#04X} at PC {}", opcode, opcode_address);

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

                println!("  -> MOVI R{}, {}", destination, immediate);
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

                println!("  -> MOV R{}, R{}", destination, source);
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

                // Send the operands to the physical Scalar ALU.
                let alu_result = self.scalar_alu.add(a, b);

                // Write the ALU result back to the register file.
                self.write_scalar(destination, alu_result.value);

                // Copy the ALU's flags into STATUS.
                self.set_flag(FLAG_ZERO, alu_result.zero);
                self.set_flag(FLAG_NEGATIVE, alu_result.negative);
                self.set_flag(FLAG_CARRY, alu_result.carry);
                self.set_flag(FLAG_OVERFLOW, alu_result.overflow);

                println!(
                    "  -> ADD R{}, R{}, R{} = {}",
                    destination, source_a, source_b, alu_result.value
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

                let alu_result = self.scalar_alu.sub(a, b);
                self.write_scalar(destination, alu_result.value);

                self.update_zero_negative(alu_result.value);

                self.set_flag(FLAG_CARRY, alu_result.carry);

                self.set_flag(FLAG_OVERFLOW, alu_result.overflow);

                println!(
                    "  -> SUB R{}, R{}, R{} = {}",
                    destination, source_a, source_b, alu_result.value
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

                let alu_result = self.scalar_alu.mul(a, b);

                self.write_scalar(destination, alu_result.value);

                self.set_flag(FLAG_ZERO, alu_result.zero);
                self.set_flag(FLAG_NEGATIVE, alu_result.negative);
                self.set_flag(FLAG_CARRY, alu_result.carry);
                self.set_flag(FLAG_OVERFLOW, alu_result.overflow);

                println!(
                    "  -> MUL R{}, R{}, R{} = {}",
                    destination, source_a, source_b, alu_result.value
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

                let alu_result = self.scalar_alu.div(a, b);

                self.write_scalar(destination, alu_result.value);

                self.set_flag(FLAG_ZERO, alu_result.zero);
                self.set_flag(FLAG_NEGATIVE, alu_result.negative);
                self.set_flag(FLAG_CARRY, alu_result.carry);
                self.set_flag(FLAG_OVERFLOW, alu_result.overflow);

                println!(
                    "  -> DIV R{}, R{}, R{} = {}",
                    destination, source_a, source_b, alu_result.value
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

                let alu_result = self.scalar_alu.modulo(a, b);

                self.write_scalar(destination, alu_result.value);

                self.set_flag(FLAG_ZERO, alu_result.zero);
                self.set_flag(FLAG_NEGATIVE, alu_result.negative);
                self.set_flag(FLAG_CARRY, alu_result.carry);
                self.set_flag(FLAG_OVERFLOW, alu_result.overflow);

                println!(
                    "  -> MOD R{}, R{}, R{} = {}",
                    destination, source_a, source_b, alu_result.value
                );
            }
            // ====================================================
            // 0x30 - AND
            // ====================================================
            0x30 => {
                let destination = self.fetch_u8(memory);
                let source_a = self.fetch_u8(memory);
                let source_b = self.fetch_u8(memory);

                let result = self.read_scalar(source_a) & self.read_scalar(source_b);

                self.write_scalar(destination, result);

                self.update_zero_negative(result);

                println!(
                    "  -> AND R{}, R{}, R{} = {}",
                    destination, source_a, source_b, result
                );
            }

            // ====================================================
            // 0x31 - OR
            // ====================================================
            0x31 => {
                let destination = self.fetch_u8(memory);
                let source_a = self.fetch_u8(memory);
                let source_b = self.fetch_u8(memory);

                let result = self.read_scalar(source_a) | self.read_scalar(source_b);

                self.write_scalar(destination, result);

                self.update_zero_negative(result);

                println!(
                    "  -> OR R{}, R{}, R{} = {}",
                    destination, source_a, source_b, result
                );
            }

            // ====================================================
            // 0x32 - XOR
            // ====================================================
            0x32 => {
                let destination = self.fetch_u8(memory);
                let source_a = self.fetch_u8(memory);
                let source_b = self.fetch_u8(memory);

                let result = self.read_scalar(source_a) ^ self.read_scalar(source_b);

                self.write_scalar(destination, result);

                self.update_zero_negative(result);

                println!(
                    "  -> XOR R{}, R{}, R{} = {}",
                    destination, source_a, source_b, result
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

                let result = !self.read_scalar(source);

                self.write_scalar(destination, result);

                self.update_zero_negative(result);

                println!("  -> NOT R{}, R{} = {}", destination, source, result);
            }

            // ====================================================
            // 0x34 - SHL
            // ====================================================
            0x34 => {
                let destination = self.fetch_u8(memory);
                let source = self.fetch_u8(memory);
                let amount_register = self.fetch_u8(memory);

                let value = self.read_scalar(source);

                let amount = self.read_scalar(amount_register) & 31;

                let result = value.wrapping_shl(amount);

                self.write_scalar(destination, result);

                self.update_zero_negative(result);

                println!(
                    "  -> SHL R{}, R{}, R{} = {}",
                    destination, source, amount_register, result
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

                let amount = self.read_scalar(amount_register) & 31;

                let result = value.wrapping_shr(amount);

                self.write_scalar(destination, result);

                self.update_zero_negative(result);

                println!(
                    "  -> SHR R{}, R{}, R{} = {}",
                    destination, source, amount_register, result
                );
            }

            // ====================================================
            // 0x40 - LOAD
            //
            // LOAD destination, address_register
            // ====================================================
            0x40 => {
                let destination = self.fetch_u8(memory);
                let address_register = self.fetch_u8(memory);

                let address = self.read_scalar(address_register);

                let value = Self::read_u32(memory, address);

                self.write_scalar(destination, value);

                println!(
                    "  -> LOAD R{}, [R{}] = {}",
                    destination, address_register, value
                );
            }

            // ====================================================
            // 0x41 - STORE
            //
            // STORE address_register, source
            // ====================================================
            0x41 => {
                let address_register = self.fetch_u8(memory);

                let source = self.fetch_u8(memory);

                let address = self.read_scalar(address_register);

                let value = self.read_scalar(source);

                Self::write_u32(memory, address, value);

                println!("  -> STORE [R{}], R{}", address_register, source);
            }

            // ====================================================
            // 0x50 - PUSH
            // ====================================================
            0x50 => {
                let source = self.fetch_u8(memory);

                let value = self.read_scalar(source);

                self.push_u32(memory, value);

                println!("  -> PUSH R{} ({})", source, value);
            }

            // ====================================================
            // 0x51 - POP
            // ====================================================
            0x51 => {
                let destination = self.fetch_u8(memory);

                let value = self.pop_u32(memory);

                self.write_scalar(destination, value);

                println!("  -> POP R{} ({})", destination, value);
            }

            // ====================================================
            // 0x60 - CMP
            //
            // CMP source_a, source_b
            //
            // Updates STATUS.
            // ====================================================
            0x60 => {
                let source_a = self.fetch_u8(memory);

                let source_b = self.fetch_u8(memory);

                let a = self.read_scalar(source_a);

                let b = self.read_scalar(source_b);

                let result = a.wrapping_sub(b);

                self.update_zero_negative(result);

                self.set_flag(FLAG_CARRY, a >= b);

                println!("  -> CMP R{}, R{}", source_a, source_b);
            }

            // ====================================================
            // 0x70 - JMP
            //
            // JMP absolute_address
            // ====================================================
            0x70 => {
                let address = self.fetch_u32(memory);

                self.pc = address;

                println!("  -> JMP {}", address);
            }

            // ====================================================
            // 0x71 - JZ
            // ====================================================
            0x71 => {
                let address = self.fetch_u32(memory);

                if self.flag(FLAG_ZERO) {
                    self.pc = address;

                    println!("  -> JZ {} TAKEN", address);
                } else {
                    println!("  -> JZ {} NOT TAKEN", address);
                }
            }

            // ====================================================
            // 0x72 - JNZ
            // ====================================================
            0x72 => {
                let address = self.fetch_u32(memory);

                if !self.flag(FLAG_ZERO) {
                    self.pc = address;

                    println!("  -> JNZ {} TAKEN", address);
                } else {
                    println!("  -> JNZ {} NOT TAKEN", address);
                }
            }

            // ====================================================
            // 0x80 - CALL
            //
            // CALL absolute_address
            // ====================================================
            0x80 => {
                let address = self.fetch_u32(memory);

                let return_address = self.pc;

                self.push_u32(memory, return_address);

                self.pc = address;

                println!("  -> CALL {}", address);
            }

            // ====================================================
            // 0x81 - RET
            // ====================================================
            0x81 => {
                let return_address = self.pop_u32(memory);

                self.pc = return_address;

                println!("  -> RET {}", return_address);
            }
            // ====================================================
            // 0x82 - MAC (Multiply-Accumulate)
            //
            // Encoding:
            // 82 <register A> <register B>
            //
            // Operation:
            // ACC = ACC + (A * B)
            // ====================================================
            0x82 => {
                let address_a = self.fetch_u8(memory);
                let address_b = self.fetch_u8(memory);

                let value_a = self.read_scalar(address_a) as i8;
                let value_b = self.read_scalar(address_b) as i8;

                let accumulator = self.mac.step(value_a, value_b);

                println!(
                    "  -> MAC R{}, R{} | {} * {} | ACC = {}",
                    address_a, address_b, value_a, value_b, accumulator
                );
            }

            // ====================================================
            // 0x83 - MACCLR
            //
            // Operation:
            // ACC = 0
            // ====================================================
            0x83 => {
                self.mac.reset();

                println!("  -> MACCLR | ACC = 0");
            }

            // ====================================================
            // 0x84 - MACREAD
            //
            // Encoding:
            // 84 <destination register>
            //
            // Operation:
            // destination = ACC
            // ====================================================
            0x84 => {
                let destination = self.fetch_u8(memory);

                let accumulator = self.mac.accumulator();

                self.write_scalar(destination, accumulator as u32);

                self.update_zero_negative(accumulator as u32);

                println!("  -> MACREAD R{} | ACC = {}", destination, accumulator);
            }

            // ====================================================
            // 0x90 - MMUL (4x4 INT8 matrix multiply, INT32 output)
            //
            // Encoding:
            // 90 <destination matrix> <source A matrix> <source B matrix>
            //
            // Example:
            // MMUL M2, M0, M1
            //
            // Operation:
            // M2 = M0 x M1
            // ====================================================
            0x90 => {
                let destination = self.fetch_u8(memory);
                let source_a = self.fetch_u8(memory);
                let source_b = self.fetch_u8(memory);

                let a = self.read_matrix(source_a);
                let b = self.read_matrix(source_b);

                self.matrix_engine.load_tiles(a, b);
                self.matrix_engine.start();

                let mut cycles = 0;
                while self.matrix_engine.is_busy() {
                    self.matrix_engine.step_cycle();
                    cycles += 1;
                }

                let result = self
                    .matrix_engine
                    .read_output()
                    .expect("MMUL finished without an output");

                self.write_matrix(destination, result);

                println!(
                    "  -> MMUL M{}, M{}, M{} | {} matrix cycles",
                    destination, source_a, source_b, cycles
                );
            }

            // ====================================================
            // 0xFF - HALT
            // ====================================================
            0xFF => {
                self.halted = true;

                println!("  -> HALT");
            }

            _ => {
                panic!("Unknown Neuron opcode: {:#04X}", opcode);
            }
        }
    }

    /// Runs instructions until the CPU executes `HALT`.
    pub fn run(&mut self, memory: &mut [u8]) {
        while !self.halted {
            self.step(memory);
        }
    }

    pub const fn is_halted(&self) -> bool {
        self.halted
    }

    pub const fn program_counter(&self) -> u32 {
        self.pc
    }

    pub const fn stack_pointer(&self) -> u32 {
        self.sp
    }

    pub const fn frame_pointer(&self) -> u32 {
        self.fp
    }

    pub fn set_frame_pointer(&mut self, value: u32) {
        self.fp = value;
    }

    pub const fn status(&self) -> u32 {
        self.status
    }

    pub const fn mac_accumulator(&self) -> i32 {
        self.mac.accumulator()
    }

    pub const fn ai_mode(&self) -> u32 {
        self.ai_mode
    }

    pub fn set_ai_mode(&mut self, value: u32) {
        self.ai_mode = value;
    }

    pub const fn quantization_control(&self) -> u32 {
        self.quant_ctrl
    }

    pub fn set_quantization_control(&mut self, value: u32) {
        self.quant_ctrl = value;
    }

    pub const fn sparsity_control(&self) -> u32 {
        self.sparse_ctrl
    }

    pub fn set_sparsity_control(&mut self, value: u32) {
        self.sparse_ctrl = value;
    }

    pub const fn tensor_control(&self) -> u32 {
        self.tensor_ctrl
    }

    pub fn set_tensor_control(&mut self, value: u32) {
        self.tensor_ctrl = value;
    }

    pub const fn tensor_status(&self) -> u32 {
        self.tensor_status
    }
}
