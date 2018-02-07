
`timescale 1 ns / 1 ps

module picodevice #(
	parameter [ 0:0] ENABLE_TRACE = 0,
	parameter        CORES_COUNT = 1,
	parameter [31:0] PRIVATE_MEM_BASE = 32'h0001_0000,
	parameter [31:0] PRIVATE_MEM_OFFS = 32'h0001_0000,
	parameter [31:0] PRIVATE_MEM_LEN = 32'h0000_0100
) (
    input clk, resetn,
	output trap,

	// Native memory interface
	output        mem_valid,
	output        mem_instr,
	input         mem_ready,
	output [31:0] mem_addr,
	output [ 3:0] mem_wstrb,
	output [31:0] mem_wdata,
	input  [31:0] mem_rdata,
	
	// Direct Memory Mover native memory interface
	output        dmm_mem_valid,
	input         dmm_mem_ready,
	output [31:0] dmm_mem_addr,
	output [ 3:0] dmm_mem_wstrb,
	output [31:0] dmm_mem_wdata,
	input  [31:0] dmm_mem_rdata,
	
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
	
	genvar i;

    /* virtual memory interface (per core) */
    wire        cpu2trans_mem_valid[CORES_COUNT-1:0];
	wire [31:0] cpu2trans_mem_addr [CORES_COUNT-1:0];
	wire [31:0] cpu2trans_mem_wdata[CORES_COUNT-1:0];
	wire [ 3:0] cpu2trans_mem_wstrb[CORES_COUNT-1:0];
	wire        cpu2trans_mem_instr[CORES_COUNT-1:0];
	wire        cpu2trans_mem_ready[CORES_COUNT-1:0];
	wire [31:0] cpu2trans_mem_rdata[CORES_COUNT-1:0];
	
	/* translated memory interface */
	wire [CORES_COUNT-1:0] trans2arb_mem_valid;
	wire [CORES_COUNT-1:0] trans2arb_mem_instr;
    wire [CORES_COUNT-1:0] trans2arb_mem_ready;
    wire [31:0] trans2arb_mem_addr [CORES_COUNT-1:0];
    wire [31:0] trans2arb_mem_wdata[CORES_COUNT-1:0];
    wire [ 3:0] trans2arb_mem_wstrb[CORES_COUNT-1:0];
    wire [31:0] trans2arb_mem_rdata[CORES_COUNT-1:0];

    /* resolved memory interface */
    wire        arb2axi_mem_valid;
    wire [31:0] arb2axi_mem_addr;
    wire [31:0] arb2axi_mem_wdata;
    wire [ 3:0] arb2axi_mem_wstrb;
    wire        arb2axi_mem_instr;
    wire        arb2axi_mem_ready;
    wire [31:0] arb2axi_mem_rdata;
    
    /* interrupt lines */
    wire [31:0] irq_cpu[CORES_COUNT-1:0];
    wire [31:0] eoi_cpu[CORES_COUNT-1:0];
	assign irq_cpu[0] = {8'h00, irq, 8'h00};
	generate for (i = 1; i < CORES_COUNT; i++)
		assign irq_cpu[i] = 32'b0;
	endgenerate
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
	wire [CORES_COUNT-1:0] dmm_req;
	wire [CORES_COUNT-1:0] dmm_done;
	
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
        
                .mem_valid(cpu2trans_mem_valid[i]),
                .mem_addr (cpu2trans_mem_addr [i]),
                .mem_wdata(cpu2trans_mem_wdata[i]),
                .mem_wstrb(cpu2trans_mem_wstrb[i]),
                .mem_instr(cpu2trans_mem_instr[i]),
                .mem_ready(cpu2trans_mem_ready[i]),
                .mem_rdata(cpu2trans_mem_rdata[i]),
        
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
				
				.fork_dmm_req (dmm_req[i] ),
				.fork_dmm_done(dmm_done[i]),
                
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
                .PRIVATE_MEM_BASE(PRIVATE_MEM_BASE+(PRIVATE_MEM_OFFS*i))
            ) translator (
                .clk(clk), .resetn(resetn),
                .core_mem_valid(cpu2trans_mem_valid[i]),
                .core_mem_instr(cpu2trans_mem_instr[i]),
                .core_mem_ready(cpu2trans_mem_ready[i]),
                .core_mem_addr (cpu2trans_mem_addr [i]),
                .core_mem_wdata(cpu2trans_mem_wdata[i]),
                .core_mem_wstrb(cpu2trans_mem_wstrb[i]),
                .core_mem_rdata(cpu2trans_mem_rdata[i]),
                .mem_valid(trans2arb_mem_valid[i]),
                .mem_instr(trans2arb_mem_instr[i]),
                .mem_ready(trans2arb_mem_ready[i]),
                .mem_addr (trans2arb_mem_addr [i]),
                .mem_wdata(trans2arb_mem_wdata[i]),
                .mem_wstrb(trans2arb_mem_wstrb[i]),
                .mem_rdata(trans2arb_mem_rdata[i])
            );
		end
    endgenerate
    
	picorv32_dmm #(
		.CORES_COUNT     (CORES_COUNT     ),
		.PRIVATE_MEM_BASE(PRIVATE_MEM_BASE),
		.PRIVATE_MEM_OFFS(PRIVATE_MEM_OFFS),
		.PRIVATE_MEM_LEN (PRIVATE_MEM_LEN )
	) dmm (
		.clk(clk), .resetn(resetn),
		.dmm_request(dmm_req      ),
		.dmm_done   (dmm_done     ),
		.mem_valid  (dmm_mem_valid),
		.mem_ready  (dmm_mem_ready),
		.mem_addr   (dmm_mem_addr ),
		.mem_wdata  (dmm_mem_wdata),
		.mem_wstrb  (dmm_mem_wstrb),
		.mem_rdata  (dmm_mem_rdata)
	);
	
    /* memory arbiter and resolver */
    picorv32_mem_arbiter #(
        .CORES_COUNT(CORES_COUNT)
    ) mem_arbiter (
		.clk(clk), .resetn(resetn),
        .core_mem_valid(trans2arb_mem_valid),
        .core_mem_instr(trans2arb_mem_instr),
        .core_mem_ready(trans2arb_mem_ready),
        .core_mem_addr (trans2arb_mem_addr ),
        .core_mem_wdata(trans2arb_mem_wdata),
        .core_mem_wstrb(trans2arb_mem_wstrb),
        .core_mem_rdata(trans2arb_mem_rdata),
        .mem_valid(mem_valid  ),
        .mem_instr(mem_instr  ),
        .mem_ready(mem_ready  ),
        .mem_addr (mem_addr   ),
        .mem_wdata(mem_wdata  ),
        .mem_wstrb(mem_wstrb  ),
        .mem_rdata(mem_rdata  )
    );

    

endmodule


module picorv32_mem_translator #(
    parameter [31:0] PRIVATE_MEM_BASE = 32'h0001_0000,
    parameter [ 0:0] SEQUENTIAL = 1
) (
    input clk, resetn,
    
    // core side
    input             core_mem_valid,
    input             core_mem_instr,
    output reg        core_mem_ready,
            
    input      [31:0] core_mem_addr,
    input      [31:0] core_mem_wdata,
    input      [ 3:0] core_mem_wstrb,
    output reg [31:0] core_mem_rdata,
    
    // arbiter side
    output reg        mem_valid,
    output reg        mem_instr,
    input             mem_ready,
                
    output reg [31:0] mem_addr,
    output reg [31:0] mem_wdata,
    output reg [ 3:0] mem_wstrb,
    input      [31:0] mem_rdata
);
	wire addr_is_private = &core_mem_addr[31:24];
	wire [31:0] addr_resolved = PRIVATE_MEM_BASE + core_mem_addr[23:0];

    generate if (SEQUENTIAL) begin
        always @(posedge clk) begin
			
			core_mem_ready <= 0;
			if (!resetn)
				core_mem_rdata <= 'bx;
			else if (core_mem_valid && mem_ready) begin
				core_mem_ready <= 1;
				core_mem_rdata <= mem_rdata;
			end
			
			mem_valid <= 0;
            if (!resetn) begin
				mem_instr <= 0;
				mem_addr  <= 'bx;
				mem_wdata <= 'bx;
				mem_wstrb <= 0;
            end else if (core_mem_valid) begin
				mem_addr  <= (addr_is_private) ? addr_resolved : core_mem_addr;
                mem_valid <= core_mem_valid;
                mem_instr <= core_mem_instr;
                mem_wdata <= core_mem_wdata;
				if (!mem_ready) begin
					mem_wstrb <= core_mem_wstrb;
					mem_valid <= 1;
				end
			end
				
        end
    end else begin
    
        assign mem_valid = core_mem_valid;
        assign core_mem_ready = mem_ready;
        assign mem_instr = core_mem_instr;
        assign core_mem_rdata = mem_rdata;
        assign mem_wdata = core_mem_wdata;
        assign mem_wstrb = core_mem_wstrb;
        assign mem_addr = (addr_is_private) ? addr_resolved : core_mem_addr;
    
    end
    endgenerate

endmodule

module picorv32_mem_arbiter #(
    parameter int CORES_COUNT = 1
) (
    input clk, resetn,
    
    // per-core picorv32 native memory interface
    input      [CORES_COUNT-1:0] core_mem_valid,
    input      [CORES_COUNT-1:0] core_mem_instr,
    output reg [CORES_COUNT-1:0] core_mem_ready,
        
    input      [31:0] core_mem_addr [CORES_COUNT-1:0],
    input      [31:0] core_mem_wdata[CORES_COUNT-1:0],
    input      [ 3:0] core_mem_wstrb[CORES_COUNT-1:0],
    output reg [31:0] core_mem_rdata[CORES_COUNT-1:0],
    
    // resolved and translated native memory interface (to AXI adapter)
    output reg        mem_valid,
    output reg        mem_instr,
    input             mem_ready,
        
    output reg [31:0] mem_addr,
    output reg [31:0] mem_wdata,
    output reg [ 3:0] mem_wstrb,
    input      [31:0] mem_rdata
);
	localparam indexbits = (CORES_COUNT > 1) ? clogb2(CORES_COUNT) : 1;
    
	reg [CORES_COUNT-1:0] core_mem_valid_q;
	reg [CORES_COUNT-1:0] pending;
	wire pending_any = |pending;
	wire pending_instr_any = |{core_mem_instr & pending};
	reg [indexbits-1:0] coreidx, latched_coreidx;
	reg claimed;
	
	always_comb begin
		coreidx <= 0;
		for (int idx = CORES_COUNT-1; idx >= 0; idx--) begin
			if (pending[idx] && (!pending_instr_any || core_mem_instr[idx]))
				coreidx <= idx;
		end
	end
	
	// genvar i;
	// generate for (i = 0; i < CORES_COUNT; i++) begin
	// always @(posedge clk) begin
		// if (!resetn)
	// end
	// end endgenerate
	
	always @(posedge clk) begin
		
		core_mem_valid_q <= (resetn) ? core_mem_valid : 0;
		
		core_mem_ready <= 0;
		if (!resetn) begin
			pending <= 0;
			for (int idx = 0; idx < CORES_COUNT; idx++)
				core_mem_rdata[idx] <= 'bx;
		end else begin
		for (int idx = 0; idx < CORES_COUNT; idx++) begin
			if (core_mem_valid[idx] && !core_mem_valid_q[idx])
				pending[idx] <= 1;
			else
			if (!core_mem_valid[idx] || (mem_ready && latched_coreidx == idx)) begin
				pending[idx] <= 0;
			end
			
			if (core_mem_valid[idx] && mem_ready && latched_coreidx == idx) begin
				core_mem_ready[idx] <= 1;
				core_mem_rdata[idx] <= mem_rdata;
			end
		end
		end
		
		mem_valid <= 0;
		mem_wstrb <= 0;
		if (!resetn) begin
			claimed <= 0;
			latched_coreidx <= 0;
			
			mem_instr <= 'bx;
			mem_addr  <= 'bx;
			mem_wdata <= 'bx;
		end else if (claimed) begin
			if (mem_ready)
				claimed <= 0;
			else begin
				mem_valid <= 1;
				mem_wstrb <= core_mem_wstrb[latched_coreidx];
				mem_instr <= core_mem_instr[latched_coreidx];
				mem_addr  <= core_mem_addr [latched_coreidx];
				mem_wdata <= core_mem_wdata[latched_coreidx];
			end
		end else if (pending_any) begin
			claimed <= 1;
			latched_coreidx <= coreidx;
		end
	
	end
	
	// always @(posedge clk) begin
		// core_mem_ready <= 0;
		// mem_valid <= 0;

		// if (!resetn) begin
			// latched_coreidx <= 0;
			// claimed <= 0;
			// for (int idx = 0; idx < CORES_COUNT; idx++)
				// core_mem_rdata[idx] <= 'bx;
			// mem_instr <= 0;
			// mem_addr <= 'bx;
			// mem_wdata <= 'bx;
			// mem_wstrb <= 0;
		// end else
		// if (claimed) begin
			// mem_instr <= core_mem_instr[latched_coreidx];
			// mem_addr <= core_mem_addr[latched_coreidx];
			// mem_wdata <= core_mem_wdata[latched_coreidx];
			// mem_wstrb <= core_mem_wstrb[latched_coreidx];
			// mem_valid <= core_mem_valid[latched_coreidx];
			// core_mem_ready[latched_coreidx] <= mem_ready && core_mem_valid[latched_coreidx];
			// if (mem_ready)
				// core_mem_rdata[latched_coreidx] <= mem_rdata;
			// if (!core_mem_valid[latched_coreidx]) begin
				// claimed <= 0;
			// end
		// end else
		// if (core_mem_valid_any) begin
			// claimed <= 1;
			// latched_coreidx <= coreidx;
		// end
	// end
	
//    generate
//   if (CORES_COUNT == 1) begin
//        assign mem_valid_o    = mem_valid_i[0];
//        assign mem_instr_o    = mem_instr_i[0];
//       assign mem_addr_o     = mem_addr_i [0];
//        assign mem_wdata_o    = mem_wdata_i[0];
//        assign mem_wstrb_o    = mem_wstrb_i[0];
//        assign mem_ready_o[0] = mem_ready_i;
//        assign mem_rdata_o[0] = mem_rdata_i;
//    end else begin
    
//    end 
//    endgenerate
    
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


module picorv32_dmm #(
	parameter int    CORES_COUNT = 1,
	parameter [31:0] PRIVATE_MEM_BASE = 32'h0001_0000,
	parameter [31:0] PRIVATE_MEM_OFFS = 32'h0001_0000,
	parameter [31:0] PRIVATE_MEM_LEN = 32'h0000_4000
) (
	input clk, resetn,
	
	input      [CORES_COUNT-1:0] dmm_request,
	output reg [CORES_COUNT-1:0] dmm_done,
	
	output            mem_valid,
    input             mem_ready,
        
    output     [31:0] mem_addr,
    output     [31:0] mem_wdata,
    output     [ 3:0] mem_wstrb,
    input      [31:0] mem_rdata
);
	localparam indexbits = clogb2(CORES_COUNT);
	
	genvar i;
	
	reg mm_start;
	reg [31:0] mm_addr_src, mm_addr_dst;
	wire mm_busy, mm_done;
	
	reg [CORES_COUNT-1:0] dmm_request_q, pending;
	wire pending_any = |pending;
	
	wire [31:0] addr_start [0:CORES_COUNT];
	
	reg [indexbits-1:0] coreidx, latched_coreidx;
	
	picorv32_mem_mover mem_mover (
		.clk(clk), .resetn(resetn),
		.start      (mm_start       ),
		.address_src(mm_addr_src    ),
		.address_dst(mm_addr_dst    ),
		.bytes_count(PRIVATE_MEM_LEN),
		.busy       (mm_busy        ),
		.done       (mm_done        ),
		.mem_valid  (mem_valid      ),
		.mem_ready  (mem_ready      ),
		.mem_addr   (mem_addr       ),
		.mem_wdata  (mem_wdata      ),
		.mem_wstrb  (mem_wstrb      ),
		.mem_rdata  (mem_rdata      )
	);
	
	always @(posedge clk) begin
		dmm_request_q <= (resetn) ? dmm_request : 0;
		
		if (!resetn)
			pending <= 0;
		else for (int idx = 0; idx < CORES_COUNT; idx++) begin
			if (dmm_request[idx] && !dmm_request_q[idx])
				pending[idx] <= 1;
			else if (mm_busy && latched_coreidx == idx)
				pending[idx] <= 0;
		end
		
		if (!resetn)
			dmm_done <= 0;
		else for (int idx = 0; idx < CORES_COUNT; idx++) begin
			if (mm_done && latched_coreidx == idx)
				dmm_done[idx] <= 1;
			else if (!dmm_request[idx])
				dmm_done[idx] <= 0;
		end
	end
	
	
	// START ADDRESS GENERATION
	generate for (i = 0; i < CORES_COUNT; i++)
		assign addr_start[i] = PRIVATE_MEM_BASE + (PRIVATE_MEM_OFFS*i);
	endgenerate
	assign addr_start[CORES_COUNT] = addr_start[CORES_COUNT-1];
	
	// CORE INDEX LOGIC
	always_comb begin
		coreidx <= 0;
		for (int idx = CORES_COUNT-1; idx >= 0; idx--) begin
			if (pending[idx])
				coreidx <= idx;
		end
	end
	
	// SEQUENTIAL LOGIC
	always @(posedge clk) begin
		
		mm_start <= 0;
		
		if (!resetn) begin
			latched_coreidx <= 'bx;
			mm_addr_dst <= 'bx;
			mm_addr_src <= 'bx;
		end else
		if (pending_any && !mm_busy) begin
			latched_coreidx <= coreidx;
			mm_addr_src <= addr_start[coreidx];
			mm_addr_dst <= addr_start[coreidx+1];
			mm_start <= 1;
		end
		
	end
	
	
	
	
	

endmodule


module picorv32_mem_mover (
	input clk, resetn,
	
	input             start,
	input      [31:0] address_src,
	input      [31:0] address_dst,
	input      [31:0] bytes_count,
	output reg        busy,
	output reg        done,
	
	output reg        mem_valid,
    input             mem_ready,
        
    output reg [31:0] mem_addr,
    output reg [31:0] mem_wdata,
    output reg [ 3:0] mem_wstrb,
    input      [31:0] mem_rdata
);
	reg [31:0] addr_read, addr_write, latched_data, remcnt;
	reg start_q;
	
	localparam fsm_state_idle  = 2'b00;
	localparam fsm_state_read  = 2'b01;
	localparam fsm_state_write = 2'b10;
	reg [1:0] fsm_state;
	
	always @* begin
		busy <= |fsm_state;
	end
	
	always @(posedge clk) begin
		start_q <= resetn && start;
	end
	
	always @(posedge clk) begin
		done <= 0;
		
		mem_valid <= 0;		
		mem_wstrb <= 0;
		mem_addr <= 'bx;
		mem_wdata <= 'bx;
		
		if (!resetn) begin
			addr_read <= 'bx;
			addr_write <= 'bx;
			remcnt <= 0;
			fsm_state <= fsm_state_idle;
			latched_data <= 'bx;
		end else begin
			case (fsm_state)
				fsm_state_idle: begin
					if (start && !start_q) begin
						addr_read <= address_src;
						addr_write <= address_dst;
						remcnt <= bytes_count;
						fsm_state <= fsm_state_read;
					end
				end
				fsm_state_read: begin
					if (mem_ready) begin
						latched_data <= mem_rdata;
						fsm_state <= fsm_state_write;
						addr_read <= addr_read + 4;
					end else if (!remcnt) begin
						fsm_state <= fsm_state_idle;
						done <= 1;
					end else begin
						mem_valid <= 1;
						mem_addr <= addr_read;
					end
				end
				fsm_state_write: begin
					if (mem_ready) begin
						fsm_state <= fsm_state_read;
						addr_write <= addr_write + 4;
						remcnt <= remcnt - 4;
					end else begin
						mem_valid <= 1;
						mem_addr <= addr_write;
						mem_wdata <= latched_data;
						mem_wstrb <= 4'b1111;
					end
				end
				default: begin
					fsm_state <= fsm_state_idle;
					remcnt <= 0;
				end
			endcase
		end
	end

endmodule


function integer clogb2;
	input [31:0] value;
	integer 	i;
	begin
		clogb2 = 0;
		for(i = 0; 2**i < value; i = i + 1)
			clogb2 = i + 1;
	end
endfunction



module picodevice_axi #(
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
	output [15:0] eoi,

	// Trace Interface (per core)
	output        trace_valid[CORES_COUNT-1:0],
	output [35:0] trace_data [CORES_COUNT-1:0]
);
	
	wire mem_valid, mem_instr, mem_ready, dmm_mem_valid, dmm_mem_ready;
	wire [3:0] mem_wstrb, dmm_mem_wstrb;
	wire [31:0] mem_addr, mem_wdata, mem_rdata, dmm_mem_addr, dmm_mem_wdata, dmm_mem_rdata;

	picodevice #(
		.ENABLE_TRACE(ENABLE_TRACE),
		.CORES_COUNT (CORES_COUNT )
	) core (
		.clk(clk), .resetn(resetn),
		.trap(trap),

		.mem_valid(mem_valid),
		.mem_instr(mem_instr),
		.mem_ready(mem_ready),
		.mem_addr (mem_addr ),
		.mem_wstrb(mem_wstrb),
		.mem_wdata(mem_wdata),
		.mem_rdata(mem_rdata),
	
		.dmm_mem_valid(dmm_mem_valid),
		.dmm_mem_ready(dmm_mem_ready),
		.dmm_mem_addr (dmm_mem_addr ),
		.dmm_mem_wstrb(dmm_mem_wstrb),
		.dmm_mem_wdata(dmm_mem_wdata),
		.dmm_mem_rdata(dmm_mem_rdata),
	
		.irq(irq),
		.eoi(eoi),

		.trace_valid(trace_valid),
		.trace_data (trace_data)
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
		.mem_valid      (mem_valid),
		.mem_instr      (mem_instr),
		.mem_ready      (mem_ready),
		.mem_addr       (mem_addr ),
		.mem_wdata      (mem_wdata),
		.mem_wstrb      (mem_wstrb),
		.mem_rdata      (mem_rdata)
	);
	
	picorv32_axi_adapter dmm_axi_adapter (
		.clk            (clk              ),
		.resetn         (resetn           ),
		.mem_axi_awvalid(dmm_axi_awvalid  ),
		.mem_axi_awready(dmm_axi_awready  ),
		.mem_axi_awaddr (dmm_axi_awaddr   ),
		.mem_axi_awprot (dmm_axi_awprot   ),
		.mem_axi_wvalid (dmm_axi_wvalid   ),
		.mem_axi_wready (dmm_axi_wready   ),
		.mem_axi_wdata  (dmm_axi_wdata    ),
		.mem_axi_wstrb  (dmm_axi_wstrb    ),
		.mem_axi_bvalid (dmm_axi_bvalid   ),
		.mem_axi_bready (dmm_axi_bready   ),
		.mem_axi_arvalid(dmm_axi_arvalid  ),
		.mem_axi_arready(dmm_axi_arready  ),
		.mem_axi_araddr (dmm_axi_araddr   ),
		.mem_axi_arprot (dmm_axi_arprot   ),
		.mem_axi_rvalid (dmm_axi_rvalid   ),
		.mem_axi_rready (dmm_axi_rready   ),
		.mem_axi_rdata  (dmm_axi_rdata    ),
		.mem_valid      (dmm_mem_valid    ),
		.mem_instr      (0                ),
		.mem_ready      (dmm_mem_ready    ),
		.mem_addr       (dmm_mem_addr     ),
		.mem_wdata      (dmm_mem_wdata    ),
		.mem_wstrb      (dmm_mem_wstrb    ),
		.mem_rdata      (dmm_mem_rdata    )
	);

endmodule

module picodevice_single #(
	parameter [ 0:0] ENABLE_TRACE = 0,
	parameter        CORES_COUNT = 1
) (
	input clk, resetn,
	output trap,
	
	output        mem_valid,
	output        mem_instr,
	input         mem_ready,
	output [31:0] mem_addr,
	output [ 3:0] mem_wstrb,
	output [31:0] mem_wdata,
	input  [31:0] mem_rdata,
	
	input  [15:0] irq,
	output [15:0] eoi,

	output        trace_valid[CORES_COUNT-1:0],
	output [35:0] trace_data [CORES_COUNT-1:0]
);
	
	wire [ 1:0] int_mem_valid, int_mem_instr, int_mem_ready;
	wire [ 3:0] int_mem_wstrb[1:0];
	wire [31:0] int_mem_addr [1:0];
	wire [31:0] int_mem_rdata[1:0];
	wire [31:0] int_mem_wdata[1:0];
	
	assign int_mem_instr[1] = 0;

	picodevice #(
		.ENABLE_TRACE(ENABLE_TRACE),
		.CORES_COUNT (CORES_COUNT )
	) core (
		.clk(clk), .resetn(resetn),
		.trap(trap),

		.mem_valid(int_mem_valid[0]),
		.mem_instr(int_mem_instr[0]),
		.mem_ready(int_mem_ready[0]),
		.mem_addr (int_mem_addr [0]),
		.mem_wstrb(int_mem_wstrb[0]),
		.mem_wdata(int_mem_wdata[0]),
		.mem_rdata(int_mem_rdata[0]),
	
		.dmm_mem_valid(int_mem_valid[1]),
		.dmm_mem_ready(int_mem_ready[1]),
		.dmm_mem_addr (int_mem_addr [1]),
		.dmm_mem_wstrb(int_mem_wstrb[1]),
		.dmm_mem_wdata(int_mem_wdata[1]),
		.dmm_mem_rdata(int_mem_rdata[1]),
	
		.irq(irq),
		.eoi(eoi),

		.trace_valid(trace_valid),
		.trace_data (trace_data)
	);
	
	picorv32_mem_arbiter #(
        .CORES_COUNT(2)
    ) arbiter (
		.clk(clk), .resetn(resetn),
        .core_mem_valid(int_mem_valid),
        .core_mem_instr(int_mem_instr),
        .core_mem_ready(int_mem_ready),
        .core_mem_addr (int_mem_addr ),
        .core_mem_wdata(int_mem_wdata),
        .core_mem_wstrb(int_mem_wstrb),
        .core_mem_rdata(int_mem_rdata),
        .mem_valid(mem_valid  ),
        .mem_instr(mem_instr  ),
        .mem_ready(mem_ready  ),
        .mem_addr (mem_addr   ),
        .mem_wdata(mem_wdata  ),
        .mem_wstrb(mem_wstrb  ),
        .mem_rdata(mem_rdata  )
    );
	
endmodule



module picodevice_single_axi #(
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
	
	// IRQ interface
	input  [15:0] irq,
	output [15:0] eoi,

	// Trace Interface (per core)
	output        trace_valid[CORES_COUNT-1:0],
	output [35:0] trace_data [CORES_COUNT-1:0]
);

	wire mem_valid, mem_instr, mem_ready;
	wire [3:0] mem_wstrb;
	wire [31:0] mem_addr, mem_wdata, mem_rdata;
	
	picodevice_single #(
		.ENABLE_TRACE(ENABLE_TRACE),
		.CORES_COUNT (CORES_COUNT )
	) core (
		.clk(clk), .resetn(resetn),
		.trap(trap),

		.mem_valid(mem_valid),
		.mem_instr(mem_instr),
		.mem_ready(mem_ready),
		.mem_addr (mem_addr ),
		.mem_wstrb(mem_wstrb),
		.mem_wdata(mem_wdata),
		.mem_rdata(mem_rdata),
	
		.irq(irq),
		.eoi(eoi),

		.trace_valid(trace_valid),
		.trace_data (trace_data)
	);
	
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
		.mem_valid      (mem_valid),
		.mem_instr      (mem_instr),
		.mem_ready      (mem_ready),
		.mem_addr       (mem_addr ),
		.mem_wdata      (mem_wdata),
		.mem_wstrb      (mem_wstrb),
		.mem_rdata      (mem_rdata)
	);

endmodule


