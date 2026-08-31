/// A signed 8-bit multiply-accumulate unit with a 32-bit accumulator.
#[derive(Debug, Clone, Copy)]
pub struct Mac {
    accumulator: i32,
}

impl Mac {
    pub const fn new() -> Self {
        Self { accumulator: 0 }
    }

    /// Performs `ACC = ACC + (a * b)` and returns the new accumulator.
    pub fn step(&mut self, a: i8, b: i8) -> i32 {
        let product = (a as i32) * (b as i32);
        self.accumulator = self.accumulator.wrapping_add(product);
        self.accumulator
    }

    pub const fn accumulator(&self) -> i32 {
        self.accumulator
    }

    pub fn reset(&mut self) {
        self.accumulator = 0;
    }
}

impl Default for Mac {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::Mac;

    #[test]
    fn accumulates_and_resets() {
        let mut mac = Mac::new();

        assert_eq!(mac.step(2, 5), 10);
        assert_eq!(mac.step(-3, 4), -2);

        mac.reset();
        assert_eq!(mac.accumulator(), 0);
    }
}
