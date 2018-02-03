
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
	localparam [ 0:0] ENABLE_FAST_MUL = 1;
	localparam [ 0:0] ENABLE_DIV = 1;
	localparam [ 0:0] ENABLE_IRQ = 1;
	localparam [ 0:0] ENABLE_IRQ_QREGS = 1;
	localparam [ 0:0] ENABLE_IRQ_TIMER = 1;
	localparam [ 0:0] REGS_INIT_ZERO = 0;
	localparam [31:0] MASKED_IRQ = 32'h 0000_0000;
	localparam [31:0] LATCHED_IRQ = 32'h ffff_ffff;
	localparam [31:0] PROGADDR_RESET = 32'h 0000_0000;
	localparam [31:0] PROGADDR_IRQ = 32'h 0000_0010;
	localparam [31:0] STACKADDR = 32'h ffff_ffff;
	localparam [31:0] PRIVATE_MEM_BASE = 32'h0001_0000;
	localparam [31:0] PRIVATE_MEM_OFFS = 32'h0001_0000;
	
	genvar i;

    /* virtual memory interface (per core) */
    wire        mem_valid_cpu2trans[CORES_COUNT-1:0];
	wire [31:0] mem_addr_cpu2trans [CORES_COUNT-1:0];
	wire [31:0] mem_wdata_cpu2trans[CORES_COUNT-1:0];
	wire [ 3:0] mem_wstrb_cpu2trans[CORES_COUNT-1:0];
	wire        mem_instr_cpu2trans[CORES_COUNT-1:0];
	wire        mem_ready_cpu2trans[CORES_COUNT-1:0];
	wire [31:0] mem_rdata_cpu2trans[CORES_COUNT-1:0];
	
	/* translated memory interface */
	wire        mem_valid_trans2arb[CORES_COUNT-1:0];
    wire [31:0] mem_addr_trans2arb [CORES_COUNT-1:0];
    wire [31:0] mem_wdata_trans2arb[CORES_COUNT-1:0];
    wire [ 3:0] mem_wstrb_trans2arb[CORES_COUNT-1:0];
    wire        mem_instr_trans2arb[CORES_COUNT-1:0];
    wire        mem_ready_trans2arb[CORES_COUNT-1:0];
    wire [31:0] mem_rdata_trans2arb[CORES_COUNT-1:0];

    /* resolved memory interface */
    wire        mem_valid_arb2axi;
    wire [31:0] mem_addr_arb2axi;
    wire [31:0] mem_wdata_arb2axi;
    wire [ 3:0] mem_wstrb_arb2axi;
    wire        mem_instr_arb2axi;
    wire        mem_ready_arb2axi;
    wire [31:0] mem_rdata_arb2axi;
    
    /* interrupt lines */
    wire [31:0] irq_cpu[CORES_COUNT-1:0];
    wire [31:0] eoi_cpu[CORES_COUNT-1:0];
    assign irq_cpu[0] = {8'h00, irq, 8'h00};
    assign eoi = eoi_cpu[0][23:8];
    
	// chained connections
	wire        int_resetn[0:CORES_COUNT];
	wire        int_ready [0:CORES_COUNT];
	wire        int_valid [0:CORES_COUNT];
	wire [31:0] int_pc    [0:CORES_COUNT];
	wire        int_cplt  [0:CORES_COUNT];
	wire [ 4:0] int_rd    [0:CORES_COUNT];
	wire [31:0] int_data  [0:CORES_COUNT];
	wire        int_wen   [0:CORES_COUNT];
	// chain boundaries assignments
	assign int_resetn[0]           = resetn;
	assign int_ready [CORES_COUNT] = 0;
	assign int_valid [0]           = 1;
	assign int_pc    [0]           = 0;
	assign int_cplt  [CORES_COUNT] = 0;
	assign int_rd    [0]           = 0;
	assign int_data  [0]           = 'bx;
	assign int_wen   [0]           = 0;
	assign trap = int_cplt[0];
	
	// DMA signals
	wire [CORES_COUNT-1:0] dma_req;
	wire [CORES_COUNT-1:0] dma_done;
    
    generate
        for (i = 0; i < CORES_COUNT; i++) begin
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
                .ENABLE_IRQ          (1                   ),
                .ENABLE_IRQ_QREGS    (ENABLE_IRQ_QREGS    ),
                .ENABLE_TRACE        (ENABLE_TRACE        ),
                .REGS_INIT_ZERO      (REGS_INIT_ZERO      ),
                .PROGADDR_RESET      (PROGADDR_RESET      ),
                .CORE_ID             (i                   ),
                .ENABLE_FORK         (1                   )
            ) core (
                .clk      (clk          ),
                .resetn   (int_resetn[i]),
                .trap     (int_cplt[i]  ),
        
                .mem_valid(mem_valid_cpu2trans[i]),
                .mem_addr (mem_addr_cpu2trans [i]),
                .mem_wdata(mem_wdata_cpu2trans[i]),
                .mem_wstrb(mem_wstrb_cpu2trans[i]),
                .mem_instr(mem_instr_cpu2trans[i]),
                .mem_ready(mem_ready_cpu2trans[i]),
                .mem_rdata(mem_rdata_cpu2trans[i]),
        
                .irq(irq_cpu[i]),
                .eoi(eoi_cpu[i]),
                
                .child_resetn(int_resetn[i+1]),
                .child_ready (int_ready[i+1] ),
                .child_valid (int_valid[i+1] ),
                .child_pc    (int_pc[i+1]    ),
                .child_rd    (int_rd[i+1]    ),
                .child_data  (int_data[i+1]  ),
                .child_wen   (int_wen[i+1]   ),
                .child_cplt  (int_cplt[i+1]  ),
				
				.fork_dma_req (dma_req[i] ),
				.fork_dma_done(dma_done[i]),
                
                .init_ready(int_ready[i]),
                .init_valid(int_valid[i]),
                .init_pc   (int_pc[i]   ),
                .init_rd   (int_rd[i]   ),
                .init_data (int_data[i] ),
				.init_wen  (int_wen[i]  ),
        
                .trace_valid(trace_valid[i]),
                .trace_data (trace_data [i])
            );
        
			picorv32_mem_translator #(
                .PRIVATE_MEM_START(PRIVATE_MEM_BASE + (PRIVATE_MEM_OFFS * i))
            ) translator (
                .clk(clk), .resetn(resetn),
                .mem_valid_i(mem_valid_cpu2trans[i]),
                .mem_instr_i(mem_instr_cpu2trans[i]),
                .mem_ready_o(mem_ready_cpu2trans[i]),
                .mem_addr_i (mem_addr_cpu2trans [i]),
                .mem_wdata_i(mem_wdata_cpu2trans[i]),
                .mem_wstrb_i(mem_wstrb_cpu2trans[i]),
                .mem_rdata_o(mem_rdata_cpu2trans[i]),
                .mem_valid_o(mem_valid_trans2arb[i]),
                .mem_instr_o(mem_instr_trans2arb[i]),
                .mem_ready_i(mem_ready_trans2arb[i]),
                .mem_addr_o (mem_addr_trans2arb [i]),
                .mem_wdata_o(mem_wdata_trans2arb[i]),
                .mem_wstrb_o(mem_wstrb_trans2arb[i]),
                .mem_rdata_i(mem_rdata_trans2arb[i])
            );
		end
    endgenerate
    
    /* memory arbiter and resolver */
    picorv32_mem_arbiter #(
        .CORES_COUNT(CORES_COUNT)
    ) mem_arbiter (
        .mem_valid_i(mem_valid_trans2arb),
        .mem_instr_i(mem_instr_trans2arb),
        .mem_ready_o(mem_ready_trans2arb),
        .mem_addr_i (mem_addr_trans2arb ),
        .mem_wdata_i(mem_wdata_trans2arb),
        .mem_wstrb_i(mem_wstrb_trans2arb),
        .mem_rdata_o(mem_rdata_trans2arb),
        .mem_valid_o(mem_valid_arb2axi  ),
        .mem_instr_o(mem_instr_arb2axi  ),
        .mem_ready_i(mem_ready_arb2axi  ),
        .mem_addr_o (mem_addr_arb2axi   ),
        .mem_wdata_o(mem_wdata_arb2axi  ),
        .mem_wstrb_o(mem_wstrb_arb2axi  ),
        .mem_rdata_i(mem_rdata_arb2axi  )
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
		.mem_valid      (mem_valid_arb2axi),
		.mem_instr      (mem_instr_arb2axi),
		.mem_ready      (mem_ready_arb2axi),
		.mem_addr       (mem_addr_arb2axi ),
		.mem_wdata      (mem_wdata_arb2axi),
		.mem_wstrb      (mem_wstrb_arb2axi),
		.mem_rdata      (mem_rdata_arb2axi)
	);

endmodule


module picorv32_mem_translator #(
    parameter [31:0] PRIVATE_MEM_START = 32'h0001_0000,
    parameter [ 0:0] SEQUENTIAL = 0
) (
    input clk, resetn,
    
    // core side
    input             mem_valid_i,
    input             mem_instr_i,
    output reg        mem_ready_o,
            
    input      [31:0] mem_addr_i,
    input      [31:0] mem_wdata_i,
    input      [ 3:0] mem_wstrb_i,
    output reg [31:0] mem_rdata_o,
    
    // arbiter side
    output reg        mem_valid_o,
    output reg        mem_instr_o,
    input             mem_ready_i,
                
    output reg [31:0] mem_addr_o,
    output reg [31:0] mem_wdata_o,
    output reg [ 3:0] mem_wstrb_o,
    input      [31:0] mem_rdata_i
);

    generate
    if (SEQUENTIAL) begin
        wire mem_addr_v;
        wire [31:0] mem_addr_r;
    
        assign mem_addr_v = &mem_addr_i[31:24];
        assign mem_addr_r = PRIVATE_MEM_START + mem_addr_i[23:0];
    
        always @(posedge clk)
        begin
            if (!resetn) begin
                mem_ready_o = 0;
                mem_valid_o = 0;
                mem_instr_o = 0;
                mem_rdata_o = 'x;
                mem_addr_o  = 'x;
                mem_wdata_o = 'x;
                mem_wstrb_o = 'x;
            end else begin
                if (mem_addr_v)
                    mem_addr_o = mem_addr_r;
                else
                    mem_addr_o = mem_addr_i;
                mem_ready_o = mem_ready_i;
                mem_rdata_o = mem_rdata_i;
                mem_valid_o = mem_valid_i;
                mem_instr_o = mem_instr_i;
                mem_wdata_o = mem_wdata_i;
                mem_wstrb_o = mem_wstrb_i;
            end
        end
    end else begin
    
        assign mem_valid_o = mem_valid_i;
        assign mem_ready_o = mem_ready_i;
        assign mem_instr_o = mem_instr_i;
        assign mem_rdata_o = mem_rdata_i;
        assign mem_wdata_o = mem_wdata_i;
        assign mem_wstrb_o = mem_wstrb_i;
        
        wire        mem_addr_virtual = &mem_addr_i[31:24];
        wire [31:0] mem_addr = PRIVATE_MEM_START + mem_addr_i[23:0];
        assign mem_addr_o = (mem_addr_virtual) ? mem_addr : mem_addr_i;
    
    end
    endgenerate

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


