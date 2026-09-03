// build.rs
use std::fs::{self, OpenOptions};
use std::io::Write;
use std::time::{SystemTime, UNIX_EPOCH};

fn main() {
    // 1. Calculate current date natively
    let start = SystemTime::now();
    let since_the_epoch = start.duration_since(UNIX_EPOCH).expect("Time went backwards");
    let secs = since_the_epoch.as_secs();
    let days_since_epoch = secs / 86400;
    
    let mut year = 1970;
    let mut days_left = days_since_epoch;
    loop {
        let is_leap = (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
        let days_in_year = if is_leap { 366 } else { 365 };
        if days_left < days_in_year { break; }
        days_left -= days_in_year;
        year += 1;
    }
    
    let is_leap = (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
    let month_days = vec![31, if is_leap { 29 } else { 28 }, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    let mut month = 1;
    for days in month_days.iter() {
        if days_left < *days { break; }
        days_left -= *days;
        month += 1;
    }
    let day = days_left + 1;
    let compile_date = format!("{:04}-{:02}-{:02}", year, month, day);

    // 2. Read the existing .env file contents if it exists
    let mut preserved_lines = Vec::new();
    if let Ok(content) = fs::read_to_string(".env") {
        for line in content.lines() {
            // Keep everything EXCEPT old COMPILE_DATE entries to avoid infinite accumulation
            if !line.trim().starts_with("COMPILE_DATE=") && !line.trim().is_empty() {
                preserved_lines.push(line.to_string());
            }
        }
    }

    // 3. Open file with truncate(true) to overwrite cleanly with the freshly filtered content
    let mut file = OpenOptions::new()
        .write(true)
        .create(true)
        .truncate(true)
        .open(".env")
        .expect("Failed to open .env file");

    // 4. Write back your original keys first
    for line in preserved_lines {
        writeln!(file, "{}", line).expect("Failed to rewrite old content");
    }

    // 5. Append the fresh compile date at the very bottom
    writeln!(file, "COMPILE_DATE=\"{}\"", compile_date)
        .expect("Failed to append compile date into .env");

    println!("cargo:rerun-if-changed=.env");
}
