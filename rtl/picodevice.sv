
`timescale 1 ns / 1 ps

module picodevice #(
	parameter [ 0:0] ENABLE_TRACE = 0,
	parameter        CORES_COUNT = 1
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

	// Pico Co-Processor Interface (PCPI)
	// NOT PRESENT
	
	// IRQ interface
	input  [15:0] irq,
	output [15:0] eoi,

	// Trace Interface (per core)
	output        trace_valid[CORES_COUNT-1:0],
	output [35:0] trace_data [CORES_COUNT-1:0]
);
    localparam [ 0:0] ENABLE_COUNTERS = 1;
	localparam [ 0:0] ENABLE_COUNTERS64 = 1;
	localparam [ 0:0] ENABLE_REGS_16_31 = 1;
	localparam [ 0:0] ENABLE_REGS_DUALPORT = 1;
	localparam [ 0:0] TWO_STAGE_SHIFT = 1;
	localparam [ 0:0] BARREL_SHIFTER = 0;
	localparam [ 0:0] TWO_CYCLE_COMPARE = 0;
	localparam [ 0:0] TWO_CYCLE_ALU = 0;
	localparam [ 0:0] COMPRESSED_ISA = 0;
	localparam [ 0:0] CATCH_MISALIGN = 1;
	localparam [ 0:0] CATCH_ILLINSN = 1;
	localparam [ 0:0] ENABLE_PCPI = 0;
	localparam [ 0:0] ENABLE_MUL = 0;
	localparam [ 0:0] ENABLE_FAST_MUL = 0;
	localparam [ 0:0] ENABLE_DIV = 0;
	localparam [ 0:0] ENABLE_IRQ = 1;
	localparam [ 0:0] ENABLE_IRQ_QREGS = 1;
	localparam [ 0:0] ENABLE_IRQ_TIMER = 1;
	localparam [ 0:0] REGS_INIT_ZERO = 0;
	localparam [31:0] MASKED_IRQ = 32'h 0000_0000;
	localparam [31:0] LATCHED_IRQ = 32'h ffff_ffff;
	localparam [31:0] PROGADDR_RESET = 32'h 0000_0000;
	localparam [31:0] PROGADDR_IRQ = 32'h 0000_0010;
	localparam [31:0] STACKADDR = 32'h ffff_ffff;
	
	genvar i;

    /* virtual memory interface (per core) */
    wire        mem_valid_cpu[CORES_COUNT-1:0];
	wire [31:0] mem_addr_cpu [CORES_COUNT-1:0];
	wire [31:0] mem_wdata_cpu[CORES_COUNT-1:0];
	wire [ 3:0] mem_wstrb_cpu[CORES_COUNT-1:0];
	wire        mem_instr_cpu[CORES_COUNT-1:0];
	wire        mem_ready_cpu[CORES_COUNT-1:0];
	wire [31:0] mem_rdata_cpu[CORES_COUNT-1:0];

    /* resolved memory interface */
    wire        mem_valid_arbiter;
    wire [31:0] mem_addr_arbiter;
    wire [31:0] mem_wdata_arbiter;
    wire [ 3:0] mem_wstrb_arbiter;
    wire        mem_instr_arbiter;
    wire        mem_ready_arbiter;
    wire [31:0] mem_rdata_arbiter;
    
    /* interrupt lines (to core0 only) */
    wire [31:0] irq_cpu;
    wire [31:0] eoi_cpu;
    assign irq_cpu = {8'h00, irq, 8'h00};
    assign eoi = eoi_cpu[23:8]; 
    
    /* core0 */
    picorv32 #(
            .ENABLE_COUNTERS     (ENABLE_COUNTERS     ),
            .ENABLE_COUNTERS64   (ENABLE_COUNTERS64   ),
            .ENABLE_REGS_16_31   (ENABLE_REGS_16_31   ),
            .ENABLE_REGS_DUALPORT(ENABLE_REGS_DUALPORT),
            .TWO_STAGE_SHIFT     (TWO_STAGE_SHIFT     ),
            .BARREL_SHIFTER      (BARREL_SHIFTER      ),
            .TWO_CYCLE_COMPARE   (TWO_CYCLE_COMPARE   ),
            .TWO_CYCLE_ALU       (TWO_CYCLE_ALU       ),
            .COMPRESSED_ISA      (COMPRESSED_ISA      ),
            .CATCH_MISALIGN      (CATCH_MISALIGN      ),
            .CATCH_ILLINSN       (CATCH_ILLINSN       ),
            .ENABLE_PCPI         (ENABLE_PCPI         ),
            .ENABLE_MUL          (ENABLE_MUL          ),
            .ENABLE_FAST_MUL     (ENABLE_FAST_MUL     ),
            .ENABLE_DIV          (ENABLE_DIV          ),
            .ENABLE_IRQ          (ENABLE_IRQ          ),
            .ENABLE_IRQ_QREGS    (ENABLE_IRQ_QREGS    ),
            .ENABLE_IRQ_TIMER    (ENABLE_IRQ_TIMER    ),
            .ENABLE_TRACE        (ENABLE_TRACE        ),
            .REGS_INIT_ZERO      (REGS_INIT_ZERO      ),
            .MASKED_IRQ          (MASKED_IRQ          ),
            .LATCHED_IRQ         (LATCHED_IRQ         ),
            .PROGADDR_RESET      (PROGADDR_RESET      ),
            .PROGADDR_IRQ        (PROGADDR_IRQ        ),
            .STACKADDR           (STACKADDR           )
        ) core0 (
            .clk      (clk   ),
            .resetn   (resetn),
            .trap     (trap  ),
    
            .mem_valid(mem_valid_cpu[0]),
            .mem_addr (mem_addr_cpu [0]),
            .mem_wdata(mem_wdata_cpu[0]),
            .mem_wstrb(mem_wstrb_cpu[0]),
            .mem_instr(mem_instr_cpu[0]),
            .mem_ready(mem_ready_cpu[0]),
            .mem_rdata(mem_rdata_cpu[0]),
    
            .pcpi_valid( ),
            .pcpi_insn ( ),
            .pcpi_rs1  ( ),
            .pcpi_rs2  ( ),
            .pcpi_wr   ( ),
            .pcpi_rd   ( ),
            .pcpi_wait ( ),
            .pcpi_ready( ),
    
            .irq(irq_cpu),
            .eoi(eoi_cpu),
    
            .trace_valid(trace_valid[0]),
            .trace_data (trace_data [0])
        );
    
    /* subsequent cores */
    generate
        for (i = 1; i < CORES_COUNT; i++) begin: picorv32_cores
            picorv32 #(
                .ENABLE_COUNTERS     (ENABLE_COUNTERS     ),
                .ENABLE_COUNTERS64   (ENABLE_COUNTERS64   ),
                .ENABLE_REGS_16_31   (ENABLE_REGS_16_31   ),
                .ENABLE_REGS_DUALPORT(ENABLE_REGS_DUALPORT),
                .TWO_STAGE_SHIFT     (TWO_STAGE_SHIFT     ),
                .BARREL_SHIFTER      (BARREL_SHIFTER      ),
                .TWO_CYCLE_COMPARE   (TWO_CYCLE_COMPARE   ),
                .TWO_CYCLE_ALU       (TWO_CYCLE_ALU       ),
                .COMPRESSED_ISA      (COMPRESSED_ISA      ),
                .CATCH_MISALIGN      (CATCH_MISALIGN      ),
                .CATCH_ILLINSN       (CATCH_ILLINSN       ),
                .ENABLE_PCPI         (0                   ),
                .ENABLE_MUL          (ENABLE_MUL          ),
                .ENABLE_FAST_MUL     (ENABLE_FAST_MUL     ),
                .ENABLE_DIV          (ENABLE_DIV          ),
                .ENABLE_IRQ          (0                   ),
                .ENABLE_TRACE        (ENABLE_TRACE        ),
                .REGS_INIT_ZERO      (REGS_INIT_ZERO      ),
                .PROGADDR_RESET      (PROGADDR_RESET      )
            ) core (
                .clk      (clk   ),
                .resetn   (resetn),
                .trap     (trap  ),
        
                .mem_valid(mem_valid_cpu[i]),
                .mem_addr (mem_addr_cpu [i]),
                .mem_wdata(mem_wdata_cpu[i]),
                .mem_wstrb(mem_wstrb_cpu[i]),
                .mem_instr(mem_instr_cpu[i]),
                .mem_ready(mem_ready_cpu[i]),
                .mem_rdata(mem_rdata_cpu[i]),
        
                .pcpi_valid( ),
                .pcpi_insn ( ),
                .pcpi_rs1  ( ),
                .pcpi_rs2  ( ),
                .pcpi_wr   ( ),
                .pcpi_rd   ( ),
                .pcpi_wait ( ),
                .pcpi_ready( ),
        
                .irq( ),
                .eoi( ),
        
                .trace_valid(trace_valid[i]),
                .trace_data (trace_data [i])
            );
        end
    endgenerate
    
    /* memory arbiter and resolver */
    picorv32_mem_arbiter #(
        .CORES_COUNT(CORES_COUNT)
    ) mem_arbiter (
        .mem_valid_i(mem_valid_cpu    ),
        .mem_instr_i(mem_instr_cpu    ),
        .mem_ready_o(mem_ready_cpu    ),
        .mem_addr_i (mem_addr_cpu     ),
        .mem_wdata_i(mem_wdata_cpu    ),
        .mem_wstrb_i(mem_wstrb_cpu    ),
        .mem_rdata_o(mem_rdata_cpu    ),
        .mem_valid_o(mem_valid_arbiter),
        .mem_instr_o(mem_instr_arbiter),
        .mem_ready_i(mem_ready_arbiter),
        .mem_addr_o (mem_addr_arbiter ),
        .mem_wdata_o(mem_wdata_arbiter),
        .mem_wstrb_o(mem_wstrb_arbiter),
        .mem_rdata_i(mem_rdata_arbiter)
    );

    /* AXI adapter */
	picorv32_axi_adapter axi_adapter (
		.clk            (clk              ),
		.resetn         (resetn           ),
		.mem_axi_awvalid(mem_axi_awvalid  ),
		.mem_axi_awready(mem_axi_awready  ),
		.mem_axi_awaddr (mem_axi_awaddr   ),
		.mem_axi_awprot (mem_axi_awprot   ),
		.mem_axi_wvalid (mem_axi_wvalid   ),
		.mem_axi_wready (mem_axi_wready   ),
		.mem_axi_wdata  (mem_axi_wdata    ),
		.mem_axi_wstrb  (mem_axi_wstrb    ),
		.mem_axi_bvalid (mem_axi_bvalid   ),
		.mem_axi_bready (mem_axi_bready   ),
		.mem_axi_arvalid(mem_axi_arvalid  ),
		.mem_axi_arready(mem_axi_arready  ),
		.mem_axi_araddr (mem_axi_araddr   ),
		.mem_axi_arprot (mem_axi_arprot   ),
		.mem_axi_rvalid (mem_axi_rvalid   ),
		.mem_axi_rready (mem_axi_rready   ),
		.mem_axi_rdata  (mem_axi_rdata    ),
		.mem_valid      (mem_valid_arbiter),
		.mem_instr      (mem_instr_arbiter),
		.mem_ready      (mem_ready_arbiter),
		.mem_addr       (mem_addr_arbiter ),
		.mem_wdata      (mem_wdata_arbiter),
		.mem_wstrb      (mem_wstrb_arbiter),
		.mem_rdata      (mem_rdata_arbiter)
	);

endmodule


module picorv32_mem_arbiter #(
    parameter int CORES_COUNT = 1
) (
    input clk, resetn,
    
    // per-core picorv32 native memory interface
    input             mem_valid_i[CORES_COUNT-1:0],
    input             mem_instr_i[CORES_COUNT-1:0],
    output reg        mem_ready_o[CORES_COUNT-1:0],
        
    input      [31:0] mem_addr_i [CORES_COUNT-1:0],
    input      [31:0] mem_wdata_i[CORES_COUNT-1:0],
    input      [ 3:0] mem_wstrb_i[CORES_COUNT-1:0],
    output reg [31:0] mem_rdata_o[CORES_COUNT-1:0],
    
    // resolved and translated native memory interface (to AXI adapter)
    output reg        mem_valid_o,
    output reg        mem_instr_o,
    input             mem_ready_i,
        
    output reg [31:0] mem_addr_o,
    output reg [31:0] mem_wdata_o,
    output reg [ 3:0] mem_wstrb_o,
    input      [31:0] mem_rdata_i
);
    
    generate
    if (CORES_COUNT == 1) begin
        assign mem_valid_o    = mem_valid_i[0];
        assign mem_instr_o    = mem_instr_i[0];
        assign mem_addr_o     = mem_addr_i [0];
        assign mem_wdata_o    = mem_wdata_i[0];
        assign mem_wstrb_o    = mem_wstrb_i[0];
        assign mem_ready_o[0] = mem_ready_i;
        assign mem_rdata_o[0] = mem_rdata_i;
    end else begin
    
    end 
    endgenerate
    
//    reg [CORES_COUNT-1:0] onehot;
//    wire anyone;
//    assign anyone = |onehot;

//    always @(posedge clk)
//    begin
//        if ((resetn == 0) || (anyone == 0)) begin
//            mem_valid_o <= 0;
//            mem_instr_o <= 1'bx;
//            mem_addr_o  <= {32{1'bx}};
//            mem_wdata_o <= {32{1'bx}};
//            mem_wstrb_o <= {4{1'bx}};
            
//            for (int i = 0; i < (CORES_COUNT - 1); i++) begin
//                mem_rdata_o[i] <= {32{1'bx}};
//                mem_ready_o[i] <= 0;
//            end
//        end else begin
//            for (int i = 0; i < (CORES_COUNT - 1); i++) begin
//                if (onehot == (1 << i)) begin
//                    mem_valid_o <= mem_valid_i[i];
//                    mem_instr_o <= mem_instr_i[i];
//                    mem_addr_o  <= mem_addr_i[i];
//                    mem_wdata_o <= mem_wdata_i[i];
//                    mem_wstrb_o <= mem_wstrb_i[i];
//                end
//            end
//        end
//    end

endmodule
