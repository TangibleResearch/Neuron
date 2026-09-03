use std::collections::HashMap;
use std::error::Error;
use std::fmt;

use crate::isa::*;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct AssembleError {
    pub line: usize,
    pub message: String,
}

impl AssembleError {
    fn new(line: usize, message: impl Into<String>) -> Self {
        Self {
            line,
            message: message.into(),
        }
    }
}

impl fmt::Display for AssembleError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(formatter, "line {}: {}", self.line, self.message)
    }
}

impl Error for AssembleError {}

#[derive(Clone, Copy)]
enum OperandLayout {
    None,
    Scalar,
    TwoScalars,
    ThreeScalars,
    ScalarImmediate,
    Address,
    ThreeMatrices,
}

impl OperandLayout {
    const fn count(self) -> usize {
        match self {
            Self::None => 0,
            Self::Scalar | Self::Address => 1,
            Self::TwoScalars | Self::ScalarImmediate => 2,
            Self::ThreeScalars | Self::ThreeMatrices => 3,
        }
    }

    const fn instruction_size(self) -> u32 {
        match self {
            Self::None => 1,
            Self::Scalar => 2,
            Self::TwoScalars => 3,
            Self::ThreeScalars | Self::ThreeMatrices => 4,
            Self::ScalarImmediate => 6,
            Self::Address => 5,
        }
    }
}

#[derive(Clone, Copy)]
struct Instruction {
    opcode: u8,
    operands: OperandLayout,
}

/// Assembles NuASM source into Neuron machine code.
pub fn assemble(source: &str) -> Result<Vec<u8>, AssembleError> {
    let mut labels = HashMap::new();
    let mut address = 0_u32;

    for (line_index, raw_line) in source.lines().enumerate() {
        let line_number = line_index + 1;
        let line = clean_line(raw_line);
        if line.is_empty() {
            continue;
        }

        if let Some(label) = line.strip_suffix(':') {
            validate_label(label, line_number)?;
            if labels.insert(label.to_owned(), address).is_some() {
                return Err(AssembleError::new(
                    line_number,
                    format!("duplicate label {label}"),
                ));
            }
            continue;
        }

        let (mnemonic, operands) = parse_instruction(line, line_number)?;
        let instruction = instruction(&mnemonic).ok_or_else(|| {
            AssembleError::new(line_number, format!("unknown instruction {mnemonic}"))
        })?;
        check_operand_count(&mnemonic, instruction.operands, &operands, line_number)?;
        address = address
            .checked_add(instruction.operands.instruction_size())
            .ok_or_else(|| AssembleError::new(line_number, "program is too large"))?;
    }

    let mut output = Vec::with_capacity(address as usize);
    for (line_index, raw_line) in source.lines().enumerate() {
        let line_number = line_index + 1;
        let line = clean_line(raw_line);
        if line.is_empty() || line.ends_with(':') {
            continue;
        }

        let (mnemonic, operands) = parse_instruction(line, line_number)?;
        let instruction = instruction(&mnemonic).expect("instruction was validated in first pass");
        output.push(instruction.opcode);

        match instruction.operands {
            OperandLayout::None => {}
            OperandLayout::Scalar => output.push(parse_scalar(&operands[0], line_number)?),
            OperandLayout::TwoScalars => {
                output.push(parse_scalar(&operands[0], line_number)?);
                output.push(parse_scalar(&operands[1], line_number)?);
            }
            OperandLayout::ThreeScalars => {
                for operand in &operands {
                    output.push(parse_scalar(operand, line_number)?);
                }
            }
            OperandLayout::ScalarImmediate => {
                output.push(parse_scalar(&operands[0], line_number)?);
                output.extend_from_slice(&parse_u32(&operands[1], line_number)?.to_le_bytes());
            }
            OperandLayout::Address => {
                let target = labels
                    .get(&operands[0])
                    .copied()
                    .map(Ok)
                    .unwrap_or_else(|| parse_u32(&operands[0], line_number))?;
                output.extend_from_slice(&target.to_le_bytes());
            }
            OperandLayout::ThreeMatrices => {
                for operand in &operands {
                    output.push(parse_matrix(operand, line_number)?);
                }
            }
        }
    }

    Ok(output)
}

fn clean_line(line: &str) -> &str {
    line.split_once("//").map_or(line, |(code, _)| code).trim()
}

fn parse_instruction(
    line: &str,
    line_number: usize,
) -> Result<(String, Vec<String>), AssembleError> {
    let mut parts = line.splitn(2, char::is_whitespace);
    let mnemonic = parts.next().unwrap_or_default().to_ascii_uppercase();
    let operand_text = parts.next().unwrap_or_default().trim();
    let operands = if operand_text.is_empty() {
        Vec::new()
    } else {
        operand_text
            .split(',')
            .map(|operand| operand.trim().to_owned())
            .collect()
    };

    if mnemonic.is_empty() {
        return Err(AssembleError::new(line_number, "missing instruction"));
    }

    Ok((mnemonic, operands))
}

fn check_operand_count(
    mnemonic: &str,
    layout: OperandLayout,
    operands: &[String],
    line_number: usize,
) -> Result<(), AssembleError> {
    let expected = layout.count();
    if operands.len() != expected {
        return Err(AssembleError::new(
            line_number,
            format!("{mnemonic} expects {expected} operands"),
        ));
    }
    Ok(())
}

fn parse_scalar(register: &str, line_number: usize) -> Result<u8, AssembleError> {
    parse_register(register, 'R', 15, "register", line_number)
}

fn parse_matrix(register: &str, line_number: usize) -> Result<u8, AssembleError> {
    parse_register(register, 'M', 3, "matrix register", line_number)
}

fn parse_register(
    register: &str,
    prefix: char,
    maximum: u8,
    kind: &str,
    line_number: usize,
) -> Result<u8, AssembleError> {
    let normalized = register.to_ascii_uppercase();
    let number = normalized
        .strip_prefix(prefix)
        .and_then(|value| value.parse::<u8>().ok())
        .filter(|value| *value <= maximum)
        .ok_or_else(|| AssembleError::new(line_number, format!("invalid {kind} {register}")))?;
    Ok(number)
}

fn parse_u32(value: &str, line_number: usize) -> Result<u32, AssembleError> {
    let parsed = value
        .strip_prefix("0x")
        .or_else(|| value.strip_prefix("0X"))
        .map_or_else(|| value.parse::<u32>(), |hex| u32::from_str_radix(hex, 16));
    parsed.map_err(|_| AssembleError::new(line_number, format!("invalid integer {value}")))
}

fn validate_label(label: &str, line_number: usize) -> Result<(), AssembleError> {
    let mut characters = label.chars();
    let valid_start = characters
        .next()
        .is_some_and(|character| character.is_ascii_alphabetic() || character == '_');
    let valid_rest =
        characters.all(|character| character.is_ascii_alphanumeric() || character == '_');
    if !valid_start || !valid_rest {
        return Err(AssembleError::new(
            line_number,
            format!("invalid label {label}"),
        ));
    }
    Ok(())
}

fn instruction(mnemonic: &str) -> Option<Instruction> {
    let (opcode, operands) = match mnemonic {
        "MOVI" => (OP_MOVI, OperandLayout::ScalarImmediate),
        "MOV" => (OP_MOV, OperandLayout::TwoScalars),
        "ADD" => (OP_ADD, OperandLayout::ThreeScalars),
        "SUB" => (OP_SUB, OperandLayout::ThreeScalars),
        "MUL" => (OP_MUL, OperandLayout::ThreeScalars),
        "DIV" => (OP_DIV, OperandLayout::ThreeScalars),
        "MOD" => (OP_MOD, OperandLayout::ThreeScalars),
        "AND" => (OP_AND, OperandLayout::ThreeScalars),
        "OR" => (OP_OR, OperandLayout::ThreeScalars),
        "XOR" => (OP_XOR, OperandLayout::ThreeScalars),
        "NOT" => (OP_NOT, OperandLayout::TwoScalars),
        "SHL" => (OP_SHL, OperandLayout::ThreeScalars),
        "SHR" => (OP_SHR, OperandLayout::ThreeScalars),
        "LOAD" => (OP_LOAD, OperandLayout::TwoScalars),
        "STORE" => (OP_STORE, OperandLayout::TwoScalars),
        "PUSH" => (OP_PUSH, OperandLayout::Scalar),
        "POP" => (OP_POP, OperandLayout::Scalar),
        "CMP" => (OP_CMP, OperandLayout::TwoScalars),
        "JMP" => (OP_JMP, OperandLayout::Address),
        "JZ" => (OP_JZ, OperandLayout::Address),
        "JNZ" => (OP_JNZ, OperandLayout::Address),
        "CALL" => (OP_CALL, OperandLayout::Address),
        "RET" => (OP_RET, OperandLayout::None),
        "MAC" => (OP_MAC, OperandLayout::TwoScalars),
        "MACCLR" => (OP_MACCLR, OperandLayout::None),
        "MACREAD" => (OP_MACREAD, OperandLayout::Scalar),
        "MMUL" => (OP_MMUL, OperandLayout::ThreeMatrices),
        "OUT" => (OP_OUT, OperandLayout::Scalar),
        "HALT" => (OP_HALT, OperandLayout::None),
        _ => return None,
    };
    Some(Instruction { opcode, operands })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn encodes_movi() {
        assert_eq!(assemble("MOVI R1, 72").unwrap(), [OP_MOVI, 1, 72, 0, 0, 0]);
    }

    #[test]
    fn encodes_add_out_and_halt() {
        assert_eq!(
            assemble("ADD R3, R1, R2\nOUT R3\nHALT").unwrap(),
            [OP_ADD, 3, 1, 2, OP_OUT, 3, OP_HALT]
        );
    }

    #[test]
    fn encodes_every_current_instruction_layout() {
        let cases = [
            ("MOVI R1, 72", vec![OP_MOVI, 1, 72, 0, 0, 0]),
            ("MOV R2, R1", vec![OP_MOV, 2, 1]),
            ("ADD R3, R1, R2", vec![OP_ADD, 3, 1, 2]),
            ("SUB R3, R1, R2", vec![OP_SUB, 3, 1, 2]),
            ("MUL R3, R1, R2", vec![OP_MUL, 3, 1, 2]),
            ("DIV R3, R1, R2", vec![OP_DIV, 3, 1, 2]),
            ("MOD R3, R1, R2", vec![OP_MOD, 3, 1, 2]),
            ("AND R3, R1, R2", vec![OP_AND, 3, 1, 2]),
            ("OR R3, R1, R2", vec![OP_OR, 3, 1, 2]),
            ("XOR R3, R1, R2", vec![OP_XOR, 3, 1, 2]),
            ("NOT R2, R1", vec![OP_NOT, 2, 1]),
            ("SHL R3, R1, R2", vec![OP_SHL, 3, 1, 2]),
            ("SHR R3, R1, R2", vec![OP_SHR, 3, 1, 2]),
            ("LOAD R2, R1", vec![OP_LOAD, 2, 1]),
            ("STORE R1, R2", vec![OP_STORE, 1, 2]),
            ("PUSH R1", vec![OP_PUSH, 1]),
            ("POP R2", vec![OP_POP, 2]),
            ("CMP R1, R2", vec![OP_CMP, 1, 2]),
            ("JMP 0x12345678", vec![OP_JMP, 0x78, 0x56, 0x34, 0x12]),
            ("JZ 9", vec![OP_JZ, 9, 0, 0, 0]),
            ("JNZ 10", vec![OP_JNZ, 10, 0, 0, 0]),
            ("CALL 11", vec![OP_CALL, 11, 0, 0, 0]),
            ("RET", vec![OP_RET]),
            ("MAC R1, R2", vec![OP_MAC, 1, 2]),
            ("MACCLR", vec![OP_MACCLR]),
            ("MACREAD R3", vec![OP_MACREAD, 3]),
            ("MMUL M2, M0, M1", vec![OP_MMUL, 2, 0, 1]),
            ("OUT R1", vec![OP_OUT, 1]),
            ("HALT", vec![OP_HALT]),
        ];

        for (source, expected) in cases {
            assert_eq!(assemble(source).unwrap(), expected, "source: {source}");
        }
    }

    #[test]
    fn accepts_register_boundaries_and_hexadecimal() {
        assert_eq!(assemble("MOVI R15, 0x48\nMOV R0, R15").unwrap()[1], 15);
    }

    #[test]
    fn rejects_invalid_source_with_line_numbers() {
        let unknown = assemble("\nFOO R1").unwrap_err();
        assert_eq!(unknown.to_string(), "line 2: unknown instruction FOO");

        let register = assemble("MOV R19, R1").unwrap_err();
        assert_eq!(register.to_string(), "line 1: invalid register R19");

        let operands = assemble("MOVI R1").unwrap_err();
        assert_eq!(operands.to_string(), "line 1: MOVI expects 2 operands");
    }

    #[test]
    fn resolves_forward_and_backward_labels() {
        let output =
            assemble("start:\n    MOVI R1, 1\n    JZ done\n    JMP start\ndone:\n    HALT")
                .unwrap();

        assert_eq!(
            output,
            [
                OP_MOVI, 1, 1, 0, 0, 0, OP_JZ, 16, 0, 0, 0, OP_JMP, 0, 0, 0, 0, OP_HALT,
            ]
        );
    }
}
