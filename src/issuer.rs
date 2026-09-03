use crate::cpu::FLAG_ZERO;
use crate::isa::*;
use crate::mac::Mac;
use crate::matrix::{Matrix, MatrixEngine};
use crate::scalar_alu::{AluResult, ScalarAlu};

/// Dispatches decoded operations to Neuron execution units.
#[derive(Default)]
pub struct Issuer {
    scalar_alu: ScalarAlu,
    mac: Mac,
    matrix_engine: MatrixEngine,
}

pub enum IssueResult {
    Scalar(AluResult),
    Value(u32),
    Matrix(Matrix),
    Branch(u32),
    Output(char),
    Halt,
    None,
}

impl IssueResult {
    pub(crate) fn scalar(self) -> AluResult {
        match self {
            Self::Scalar(result) => result,
            _ => panic!("issuer did not return a scalar result"),
        }
    }

    pub(crate) fn value(self) -> u32 {
        match self {
            Self::Value(value) => value,
            _ => panic!("issuer did not return a value"),
        }
    }

    pub(crate) fn branch(self) -> Option<u32> {
        match self {
            Self::Branch(address) => Some(address),
            Self::None => None,
            _ => panic!("issuer did not return a branch result"),
        }
    }

    pub(crate) fn matrix(self) -> Matrix {
        match self {
            Self::Matrix(matrix) => matrix,
            _ => panic!("issuer did not return a matrix result"),
        }
    }

    pub(crate) fn output(self) -> char {
        match self {
            Self::Output(character) => character,
            _ => panic!("issuer did not return output"),
        }
    }

    pub(crate) fn expect_none(self) {
        if !matches!(self, Self::None) {
            panic!("issuer unexpectedly returned a result");
        }
    }

    pub(crate) fn expect_halt(self) {
        if !matches!(self, Self::Halt) {
            panic!("issuer did not return HALT");
        }
    }
}

impl Issuer {
    pub fn issue(&mut self, operation: u8, arguments: &[u32], flags: u32) -> IssueResult {
        match operation {
            OP_MOVI | OP_MOV | OP_LOAD | OP_POP => IssueResult::Value(arguments[0]),

            OP_OUT => IssueResult::Output((arguments[0] & 0xFF) as u8 as char),

            OP_ADD => IssueResult::Scalar(self.scalar_alu.add(arguments[0], arguments[1])),
            OP_SUB => IssueResult::Scalar(self.scalar_alu.sub(arguments[0], arguments[1])),
            OP_MUL => IssueResult::Scalar(self.scalar_alu.mul(arguments[0], arguments[1])),
            OP_DIV => IssueResult::Scalar(self.scalar_alu.div(arguments[0], arguments[1])),
            OP_MOD => IssueResult::Scalar(self.scalar_alu.modulo(arguments[0], arguments[1])),

            OP_AND => IssueResult::Value(arguments[0] & arguments[1]),
            OP_OR => IssueResult::Value(arguments[0] | arguments[1]),
            OP_XOR => IssueResult::Value(arguments[0] ^ arguments[1]),
            OP_NOT => IssueResult::Value(!arguments[0]),
            OP_SHL => IssueResult::Value(arguments[0].wrapping_shl(arguments[1] & 31)),
            OP_SHR => IssueResult::Value(arguments[0].wrapping_shr(arguments[1] & 31)),
            OP_CMP => IssueResult::Value(arguments[0].wrapping_sub(arguments[1])),

            OP_STORE | OP_PUSH => IssueResult::None,

            OP_JMP | OP_CALL | OP_RET => IssueResult::Branch(arguments[0]),
            OP_JZ => {
                if (flags & FLAG_ZERO) != 0 {
                    IssueResult::Branch(arguments[0])
                } else {
                    IssueResult::None
                }
            }
            OP_JNZ => {
                if (flags & FLAG_ZERO) == 0 {
                    IssueResult::Branch(arguments[0])
                } else {
                    IssueResult::None
                }
            }

            OP_MAC => {
                self.mac.step(arguments[0] as i8, arguments[1] as i8);
                IssueResult::None
            }
            OP_MACCLR => {
                self.mac.reset();
                IssueResult::None
            }
            OP_MACREAD => IssueResult::Value(self.mac.accumulator() as u32),

            OP_MMUL => panic!("MMUL requires matrix operands"),
            OP_HALT => IssueResult::Halt,

            _ => panic!("Issuer received unsupported opcode: {operation:#04X}"),
        }
    }

    pub fn issue_matrix(&mut self, operation: u8, a: Matrix, b: Matrix) -> IssueResult {
        if operation != OP_MMUL {
            panic!("Issuer received non-matrix opcode: {operation:#04X}");
        }

        self.matrix_engine.load_tiles(a, b);
        self.matrix_engine.start();
        while self.matrix_engine.is_busy() {
            self.matrix_engine.step_cycle();
        }

        IssueResult::Matrix(
            self.matrix_engine
                .read_output()
                .expect("MMUL finished without an output"),
        )
    }

    pub const fn mac_accumulator(&self) -> i32 {
        self.mac.accumulator()
    }
}
