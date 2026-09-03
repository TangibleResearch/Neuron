use std::fmt;

pub use crate::isa::opcode_name;

/// Structured information emitted after one instruction executes.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct TraceEvent {
    /// Address of the executed instruction.
    pub pc: u32,
    pub opcode: u8,
    /// STATUS register value after the instruction executed.
    pub status: u32,
}

impl fmt::Display for TraceEvent {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            formatter,
            "PC={:#010X} opcode={:#04X} ({}) STATUS={:#010X}",
            self.pc,
            self.opcode,
            opcode_name(self.opcode),
            self.status
        )
    }
}
