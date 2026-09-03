use std::io::{self, Write};

use super::trace::TraceEvent;

pub const ETB_CAPACITY: usize = 256;

/// Fixed-capacity execution trace buffer.
pub struct ETB {
    events: [Option<TraceEvent>; ETB_CAPACITY],
    write_index: usize,
    len: usize,
}

impl ETB {
    pub const fn new() -> Self {
        Self {
            events: [None; ETB_CAPACITY],
            write_index: 0,
            len: 0,
        }
    }

    /// Records an event, overwriting the oldest entry when the buffer is full.
    pub fn record(&mut self, event: TraceEvent) {
        self.events[self.write_index] = Some(event);
        self.write_index = (self.write_index + 1) % ETB_CAPACITY;
        self.len = (self.len + 1).min(ETB_CAPACITY);
    }

    pub const fn len(&self) -> usize {
        self.len
    }

    pub const fn is_empty(&self) -> bool {
        self.len == 0
    }

    /// Iterates from the oldest retained event to the newest.
    pub fn iter(&self) -> impl Iterator<Item = &TraceEvent> {
        let first = if self.len == ETB_CAPACITY {
            self.write_index
        } else {
            0
        };

        (0..self.len).map(move |offset| {
            let index = (first + offset) % ETB_CAPACITY;
            self.events[index]
                .as_ref()
                .expect("occupied ETB slot must contain a trace event")
        })
    }

    /// Writes a human-readable view without changing the stored events.
    pub fn dump(&self, writer: &mut impl Write) -> io::Result<()> {
        for event in self.iter() {
            writeln!(writer, "{event}")?;
        }
        Ok(())
    }
}

impl Default for ETB {
    fn default() -> Self {
        Self::new()
    }
}
