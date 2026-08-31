/// The kind of physical compute unit represented by a processing element.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum HardwareUnit {
    MatrixMultiply,
    VectorAdd,
    ReLUActivation,
}

/// A processing element and its physical input and routing buffers.
#[derive(Debug, Clone, PartialEq)]
pub struct ProcessingElement {
    pub unit_type: HardwareUnit,
    pub input_buffer_a: Option<f32>,
    pub input_buffer_b: Option<f32>,
    pub target_node_id: Option<usize>,
    /// `0` routes to input A and `1` routes to input B.
    pub target_buffer_slot: u8,
}

/// The processing grid and output buses for the AI accelerator.
#[derive(Debug, Clone, PartialEq)]
pub struct AiAccelerator {
    pub processing_grid: Vec<ProcessingElement>,
    pub output_bus: Vec<Option<f32>>,
}
