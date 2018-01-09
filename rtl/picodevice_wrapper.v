

module picodevice_wrapper (
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
    picodevice #(
        .ENABLE_TRACE(0),
        .CORES_COUNT (1)
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
