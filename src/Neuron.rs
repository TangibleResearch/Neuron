use dotenvy::dotenv;
use neuron::{NeuronCpu, debug::etb::ETB, drivers::keyboard::check_keyboard_present};
use std::env;
use std::fs;
use std::process::ExitCode;

const MEMORY_SIZE: usize = 1024;

fn main() -> ExitCode {
    dotenv().ok();
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
    let program_path = arguments
        .next()
        .ok_or_else(|| "usage: neuron <program.bin>".to_owned())?;
    if arguments.next().is_some() {
        return Err("usage: neuron <program.bin>".to_owned());
    }

    let program = fs::read(&program_path)
        .map_err(|error| format!("failed to read {}: {error}", program_path.to_string_lossy()))?;
    if program.len() > MEMORY_SIZE {
        return Err(format!(
            "program is {} bytes but Neuron memory is only {MEMORY_SIZE} bytes",
            program.len()
        ));
    }

    let mut memory = vec![0_u8; MEMORY_SIZE];
    memory[..program.len()].copy_from_slice(&program);

    let mut cpu = NeuronCpu::new(MEMORY_SIZE as u32);
    let mut etb = ETB::new();

    println!("--- Neuron32 Boot ---");
    dotenv().ok();
    if check_keyboard_present() {
        println!("Keyboard detected. Ready for input.");
    } else {
        println!("No keyboard detected. Proceeding without keyboard input.");
    }
    println!("© Copyright 2026 Tangible Research Inc. All rights reserved.");
    println!("Checking System Specifications...");
    match env::var("VERSION") {
        Ok(val) => println!("Version no: {}", val),
        Err(e) => println!("Couldn't read VERSION: {}", e),
    }
    match env::var("CODENAME") {
        Ok(val) => println!("Codename {}", val),
        Err(e) => println!("Couldn't read CODENAME: {}", e),
    }
    match env::var("SYSTEM") {
        Ok(val) => println!("System: {}", val),
        Err(e) => println!("Couldn't read SYSTEM: {}", e),
    }
    match env::var("SERIAL") {
        Ok(val) => println!("Serial : {}", val),
        Err(e) => println!("Couldn't read SERIAL: {}", e),
    }
    match env::var("COMPILE_DATE") {
        Ok(val) => println!("Compile on: {}", val),
        Err(e) => println!("Couldn't read COMPILE_DATE: {}", e),
    }
    while !cpu.is_halted() {
        if let Some(event) = cpu.step(&mut memory) {
            etb.record(event);
        }
    }

    println!("Debugger Output:");
    etb.dump(&mut std::io::stdout().lock())
        .map_err(|error| format!("failed to write execution trace: {error}"))?;
    println!(
        "PC={} SP={} STATUS={:#010X}",
        cpu.program_counter(),
        cpu.stack_pointer(),
        cpu.status()
    );
    for register in 1..=5 {
        println!("R{register} = {}", cpu.read_scalar(register));
    }

    Ok(())
}
