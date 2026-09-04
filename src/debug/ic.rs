use crate::isa::*;
use std::sync::Mutex;

pub static INSTRUCTION_LOG: Mutex<Instruction> = Mutex::new(Instruction {
    add: 0,
    sub: 0,
    mul: 0,
    div: 0,
    mod_: 0,
    and: 0,
    or: 0,
    xor: 0,
    not: 0,
    shl: 0,
    shr: 0,
    load: 0,
    store: 0,
    push: 0,
    pop: 0,
    cmp: 0,
    jmp: 0,
    jz: 0,
    jnz: 0,
    call: 0,
    ret: 0,
    mac: 0,
    macclr: 0,
    macread: 0,
    mmul: 0,
    out: 0,
    halt: 0,
    movi: 0,
    mov: 0,
    relu: 0,
    total: 0,
});
pub struct Instruction {
    pub add: u64,
    pub sub: u64,
    pub mul: u64,
    pub div: u64,
    pub mod_: u64,
    pub and: u64,
    pub or: u64,
    pub xor: u64,
    pub not: u64,
    pub shl: u64,
    pub shr: u64,
    pub load: u64,
    pub store: u64,
    pub push: u64,
    pub pop: u64,
    pub cmp: u64,
    pub jmp: u64,
    pub jz: u64,
    pub jnz: u64,
    pub call: u64,
    pub ret: u64,
    pub mac: u64,
    pub macclr: u64,
    pub macread: u64,
    pub mmul: u64,
    pub out: u64,
    pub halt: u64,
    pub movi: u64,
    pub mov: u64,
    pub total: u64,
    pub relu: u64,
}

impl Instruction {
    pub fn log(instruction: u8) {
        let mut log = INSTRUCTION_LOG.lock().unwrap();

        match instruction {
            OP_MOVI => log.movi += 1,
            OP_MOV => log.mov += 1,

            OP_ADD => log.add += 1,
            OP_SUB => log.sub += 1,
            OP_MUL => log.mul += 1,
            OP_DIV => log.div += 1,
            OP_MOD => log.mod_ += 1,

            OP_AND => log.and += 1,
            OP_OR => log.or += 1,
            OP_XOR => log.xor += 1,
            OP_NOT => log.not += 1,
            OP_SHL => log.shl += 1,
            OP_SHR => log.shr += 1,

            OP_LOAD => log.load += 1,
            OP_STORE => log.store += 1,

            OP_PUSH => log.push += 1,
            OP_POP => log.pop += 1,

            OP_CMP => log.cmp += 1,

            OP_JMP => log.jmp += 1,
            OP_JZ => log.jz += 1,
            OP_JNZ => log.jnz += 1,

            OP_CALL => log.call += 1,
            OP_RET => log.ret += 1,

            OP_MAC => log.mac += 1,
            OP_MACCLR => log.macclr += 1,
            OP_MACREAD => log.macread += 1,

            OP_MMUL => log.mmul += 1,

            OP_OUT => log.out += 1,
            OP_RELU => log.relu += 1,
            OP_HALT => log.halt += 1,

            _ => return,
        }

        log.total += 1;
    }
}
