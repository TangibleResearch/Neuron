use std::env;
use std::fs;
use std::process::ExitCode;

use neuron::assembler::assemble;

fn main() -> ExitCode {
    match run() {
        Ok(()) => ExitCode::SUCCESS,
        Err(message) => {
            eprintln!("{message}");
            ExitCode::FAILURE
        }
    }
}

fn run() -> Result<(), String> {
    let mut arguments = env::args_os().skip(1);
    let input = arguments
        .next()
        .ok_or_else(|| "usage: nuasm <input.nuasm> <output.bin>".to_owned())?;
    let output = arguments
        .next()
        .ok_or_else(|| "usage: nuasm <input.nuasm> <output.bin>".to_owned())?;
    if arguments.next().is_some() {
        return Err("usage: nuasm <input.nuasm> <output.bin>".to_owned());
    }

    let source = fs::read_to_string(&input)
        .map_err(|error| format!("failed to read {}: {error}", input.to_string_lossy()))?;
    let machine_code = assemble(&source).map_err(|error| error.to_string())?;
    fs::write(&output, machine_code)
        .map_err(|error| format!("failed to write {}: {error}", output.to_string_lossy()))?;

    Ok(())
}
