

module picodevice_single_axi_wrapper #(
	parameter        CORES_COUNT = 2,
	parameter [31:0] PRIVATE_MEM_BASE = 32'h0001_0000,
	parameter [31:0] PRIVATE_MEM_OFFS = 32'h0001_0000,
	parameter [31:0] PRIVATE_MEM_LEN = 32'h0000_0100,
	parameter [31:0] PROGADDR_RESET = 32'h0000_0000,
    parameter [31:0] PROGADDR_IRQ = 32'h0000_0010
) (
    input clk, resetn,
	output trap,

	// AXI4-lite master memory interface
	output        mem_axi_awvalid,
	input         mem_axi_awready,
	output [31:0] mem_axi_awaddr,
	output [ 2:0] mem_axi_awprot,

	output        mem_axi_wvalid,
	input         mem_axi_wready,
	output [31:0] mem_axi_wdata,
	output [ 3:0] mem_axi_wstrb,

	input         mem_axi_bvalid,
	output        mem_axi_bready,

	output        mem_axi_arvalid,
	input         mem_axi_arready,
	output [31:0] mem_axi_araddr,
	output [ 2:0] mem_axi_arprot,

	input         mem_axi_rvalid,
	output        mem_axi_rready,
	input  [31:0] mem_axi_rdata,

	// IRQ interface
	input  [15:0] irq,
	output [15:0] eoi
);

    /* actual device */
    picodevice_single_axi #(
        .ENABLE_TRACE    (0               ),
        .CORES_COUNT     (CORES_COUNT     ),
        .PRIVATE_MEM_BASE(PRIVATE_MEM_BASE),
        .PRIVATE_MEM_OFFS(PRIVATE_MEM_OFFS),
        .PRIVATE_MEM_LEN (PRIVATE_MEM_LEN ),
        .PROGADDR_RESET  (PROGADDR_RESET  ),
        .PROGADDR_IRQ    (PROGADDR_IRQ    )
    ) device (
        .clk(clk), .resetn(resetn),
        .trap(trap),
        
        .mem_axi_awvalid(mem_axi_awvalid),
        .mem_axi_awready(mem_axi_awready),
        .mem_axi_awaddr (mem_axi_awaddr ),
        .mem_axi_awprot (mem_axi_awprot ),
        
        .mem_axi_wvalid (mem_axi_wvalid ),
        .mem_axi_wready (mem_axi_wready ),
        .mem_axi_wdata  (mem_axi_wdata  ),
        .mem_axi_wstrb  (mem_axi_wstrb  ),

        .mem_axi_bvalid (mem_axi_bvalid ),
        .mem_axi_bready (mem_axi_bready ),

        .mem_axi_arvalid(mem_axi_arvalid),
        .mem_axi_arready(mem_axi_arready),
        .mem_axi_araddr (mem_axi_araddr ),
        .mem_axi_arprot (mem_axi_arprot ),

        .mem_axi_rvalid (mem_axi_rvalid ),
        .mem_axi_rready (mem_axi_rready ),
        .mem_axi_rdata  (mem_axi_rdata  ),

        .irq(irq),
        .eoi(eoi)
    );

endmodule


module picodevice_axi_wrapper #(
	parameter        CORES_COUNT = 1,
	parameter [31:0] PRIVATE_MEM_BASE = 32'h0001_0000,
	parameter [31:0] PRIVATE_MEM_OFFS = 32'h0001_0000,
	parameter [31:0] PRIVATE_MEM_LEN = 32'h0000_0100,
	parameter [31:0] PROGADDR_RESET = 32'h0000_0000,
    parameter [31:0] PROGADDR_IRQ = 32'h0000_0010
) (
	input clk, resetn,
	output trap,

	// AXI4-lite master memory interface

	output        mem_axi_awvalid,
	input         mem_axi_awready,
	output [31:0] mem_axi_awaddr,
	output [ 2:0] mem_axi_awprot,

	output        mem_axi_wvalid,
	input         mem_axi_wready,
	output [31:0] mem_axi_wdata,
	output [ 3:0] mem_axi_wstrb,

	input         mem_axi_bvalid,
	output        mem_axi_bready,

	output        mem_axi_arvalid,
	input         mem_axi_arready,
	output [31:0] mem_axi_araddr,
	output [ 2:0] mem_axi_arprot,

	input         mem_axi_rvalid,
	output        mem_axi_rready,
	input  [31:0] mem_axi_rdata,

	// AXI4-lite data mover master interface
	
	output        dmm_axi_awvalid,
	input         dmm_axi_awready,
	output [31:0] dmm_axi_awaddr,
	output [ 2:0] dmm_axi_awprot,

	output        dmm_axi_wvalid,
	input         dmm_axi_wready,
	output [31:0] dmm_axi_wdata,
	output [ 3:0] dmm_axi_wstrb,

	input         dmm_axi_bvalid,
	output        dmm_axi_bready,

	output        dmm_axi_arvalid,
	input         dmm_axi_arready,
	output [31:0] dmm_axi_araddr,
	output [ 2:0] dmm_axi_arprot,

	input         dmm_axi_rvalid,
	output        dmm_axi_rready,
	input  [31:0] dmm_axi_rdata,
	
	// Pico Co-Processor Interface (PCPI)
	// NOT PRESENT
	
	// IRQ interface
	input  [15:0] irq,
	output [15:0] eoi
);
	picodevice_axi #(
		.ENABLE_TRACE    (0               ),
        .CORES_COUNT     (CORES_COUNT     ),
        .PRIVATE_MEM_BASE(PRIVATE_MEM_BASE),
        .PRIVATE_MEM_OFFS(PRIVATE_MEM_OFFS),
        .PRIVATE_MEM_LEN (PRIVATE_MEM_LEN ),
        .PROGADDR_RESET  (PROGADDR_RESET  ),
        .PROGADDR_IRQ    (PROGADDR_IRQ    )
	) device (
		.clk(clk), .resetn(resetn),
		.trap(trap),
		
		.mem_axi_awvalid(mem_axi_awvalid),
		.mem_axi_awready(mem_axi_awready),
		.mem_axi_awaddr (mem_axi_awaddr ),
		.mem_axi_awprot (mem_axi_awprot ),
		.mem_axi_wvalid (mem_axi_wvalid ),
		.mem_axi_wready (mem_axi_wready ),
		.mem_axi_wdata  (mem_axi_wdata  ),
		.mem_axi_wstrb  (mem_axi_wstrb  ),
		.mem_axi_bvalid (mem_axi_bvalid ),
		.mem_axi_bready (mem_axi_bready ),
		.mem_axi_arvalid(mem_axi_arvalid),
		.mem_axi_arready(mem_axi_arready),
		.mem_axi_araddr (mem_axi_araddr ),
		.mem_axi_arprot (mem_axi_arprot ),
		.mem_axi_rvalid (mem_axi_rvalid ),
		.mem_axi_rready (mem_axi_rready ),
		.mem_axi_rdata  (mem_axi_rdata  ),
	
		.dmm_axi_awvalid(dmm_axi_awvalid),
		.dmm_axi_awready(dmm_axi_awready),
		.dmm_axi_awaddr (dmm_axi_awaddr ),
		.dmm_axi_awprot (dmm_axi_awprot ),
		.dmm_axi_wvalid (dmm_axi_wvalid ),
		.dmm_axi_wready (dmm_axi_wready ),
		.dmm_axi_wdata  (dmm_axi_wdata  ),
		.dmm_axi_wstrb  (dmm_axi_wstrb  ),
		.dmm_axi_bvalid (dmm_axi_bvalid ),
		.dmm_axi_bready (dmm_axi_bready ),
		.dmm_axi_arvalid(dmm_axi_arvalid),
		.dmm_axi_arready(dmm_axi_arready),
		.dmm_axi_araddr (dmm_axi_araddr ),
		.dmm_axi_arprot (dmm_axi_arprot ),
		.dmm_axi_rvalid (dmm_axi_rvalid ),
		.dmm_axi_rready (dmm_axi_rready ),
		.dmm_axi_rdata  (dmm_axi_rdata  )
	);

endmodule

