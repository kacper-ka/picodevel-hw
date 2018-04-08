// This is free and unencumbered software released into the public domain.
//
// Anyone is free to copy, modify, publish, use, compile, sell, or
// distribute this software, either in source code form or as a compiled
// binary, for any purpose, commercial or non-commercial, and by any
// means.

`timescale 1 ns / 1 ps

`ifndef VERILATOR
module testbench #(
	parameter AXI_TEST = 0,
	parameter VERBOSE = 0
);
	reg clk = 1;
	reg [2:0] resetn = 0;
	wire [2:0] trap;
	wire [2:0] tests_passed;
	wire all_tests_passed = &tests_passed;
	wire all_trapped = &trap;
	wire all_started = &resetn;

	always #5 clk = ~clk;

	initial begin
        for (int i = 0; i < 3; i += 1) begin
            repeat (100) @(posedge clk);
            resetn[i] <= 1;
            repeat (10) @(posedge clk);
            while (!trap[i])
                @(posedge clk);
        end
	end

	initial begin
		if ($test$plusargs("vcd")) begin
			$dumpfile("testbench.vcd");
			$dumpvars(0, testbench);
		end
		//repeat (10000000) @(posedge clk);
		#30s;
		$display("TIMEOUT");
		$finish;
	end

    integer cycle_counter;
    always @(posedge clk) begin
        cycle_counter <= resetn ? cycle_counter + 1 : 0;
        if (all_started && all_trapped) begin
            repeat (20) @(posedge clk);
            $display("TRAP after %1d clock cycles", cycle_counter);
            if (all_tests_passed) begin
                $display("ALL TESTS PASSED.");
                $finish;
            end else begin
                $display("ERROR!");
                if ($test$plusargs("noerror"))
                    $finish;
                $stop;
            end
        end
    end
    
    testbench_picorv32 #(
        .AXI_TEST(AXI_TEST),
        .VERBOSE (VERBOSE )
    ) tb_picorv32 (
        .clk(clk), .resetn(resetn[0]),
        .trap(trap[0]), .tests_passed(tests_passed[0])
    );
    
    testbench_picodev #(
        .AXI_TEST   (AXI_TEST),
        .VERBOSE    (VERBOSE ),
        .CORES_COUNT(2       )
    ) tb_picodev2 (
        .clk(clk), .resetn(resetn[2]),
        .trap(trap[2]), .tests_passed(tests_passed[2])
    );
    
    testbench_picodev #(
        .AXI_TEST   (AXI_TEST),
        .VERBOSE    (VERBOSE ),
        .CORES_COUNT(4       )
    ) tb_picodev4 (
        .clk(clk), .resetn(resetn[1]),
        .trap(trap[1]), .tests_passed(tests_passed[1])
    );
	
endmodule
`endif


module axi4_memory #(
	parameter AXI_TEST = 0,
	parameter VERBOSE = 0
) (
	input             clk,
	input             mem_axi_awvalid,
	output reg        mem_axi_awready = 0,
	input [31:0]      mem_axi_awaddr,
	input [ 2:0]      mem_axi_awprot,

	input            mem_axi_wvalid,
	output reg       mem_axi_wready = 0,
	input [31:0]     mem_axi_wdata,
	input [ 3:0]     mem_axi_wstrb,

	output reg       mem_axi_bvalid = 0,
	input            mem_axi_bready,

	input            mem_axi_arvalid,
	output reg       mem_axi_arready = 0,
	input [31:0]     mem_axi_araddr,
	input [ 2:0]     mem_axi_arprot,

	output reg        mem_axi_rvalid = 0,
	input             mem_axi_rready,
	output reg [31:0] mem_axi_rdata,

	output reg tests_passed
);
    localparam [31:0] MEM_OCM_BASE = 32'h0000_0000;
    localparam [31:0] MEM_OCM_LEN = 32'h0003_0000;
    localparam [31:0] MEM_DDR_BASE = 32'h0010_0000;
    localparam [31:0] MEM_DDR_LEN = 32'h0010_0000;
    localparam [31:0] MEM_UART_SR = 32'hE000_002C;
    localparam [31:0] MEM_UART_FIFO = 32'hE000_0030;
    localparam [31:0] MEM_LEDS_BASE = 32'h4120_0000;
    
	reg [31:0]   mem_ocm [0:MEM_OCM_LEN/4-1] /* verilator public */;
	reg [31:0]   mem_ram [0:MEM_DDR_LEN/4-1] /* verilator public */;
	reg [31:0]   leds;
	reg verbose;
	initial verbose = $test$plusargs("verbose") || VERBOSE;

	reg axi_test;
	initial axi_test = $test$plusargs("axi_test") || AXI_TEST;

    initial mem_ram[0] = 0;
    always @*
        tests_passed = (mem_ram[0] == 123456789) && (leds != 0);
    initial leds = 0;

	reg [63:0] xorshift64_state = 64'd88172645463325252;

	task xorshift64_next;
		begin
			// see page 4 of Marsaglia, George (July 2003). "Xorshift RNGs". Journal of Statistical Software 8 (14).
			xorshift64_state = xorshift64_state ^ (xorshift64_state << 13);
			xorshift64_state = xorshift64_state ^ (xorshift64_state >>  7);
			xorshift64_state = xorshift64_state ^ (xorshift64_state << 17);
		end
	endtask

	reg [2:0] fast_axi_transaction = ~0;
	reg [4:0] async_axi_transaction = ~0;
	reg [4:0] delay_axi_transaction = 0;

	//always @(posedge clk) begin
	//	if (axi_test) begin
	//			xorshift64_next;
	//			{fast_axi_transaction, async_axi_transaction, delay_axi_transaction} <= xorshift64_state;
	//	end
	//end

	reg latched_raddr_en = 0;
	reg latched_waddr_en = 0;
	reg latched_wdata_en = 0;

	reg fast_raddr = 0;
	reg fast_waddr = 0;
	reg fast_wdata = 0;

	reg [31:0] latched_raddr;
	reg [31:0] latched_waddr;
	reg [31:0] latched_wdata;
	reg [ 3:0] latched_wstrb;
	reg        latched_rinsn;

	task handle_axi_arvalid; begin
		mem_axi_arready <= 1;
		latched_raddr = mem_axi_araddr;
		latched_rinsn = mem_axi_arprot[2];
		latched_raddr_en = 1;
		fast_raddr <= 1;
	end endtask

	task handle_axi_awvalid; begin
		mem_axi_awready <= 1;
		latched_waddr = mem_axi_awaddr;
		latched_waddr_en = 1;
		fast_waddr <= 1;
	end endtask

	task handle_axi_wvalid; begin
		mem_axi_wready <= 1;
		latched_wdata = mem_axi_wdata;
		latched_wstrb = mem_axi_wstrb;
		latched_wdata_en = 1;
		fast_wdata <= 1;
	end endtask

	task handle_axi_rvalid; begin
		if (verbose)
			$display("RD: ADDR=%08x %s", latched_raddr, latched_rinsn ? " INSN" : "");
		if (latched_raddr >= MEM_OCM_BASE && latched_raddr < (MEM_OCM_BASE + MEM_OCM_LEN)) begin
            // OCM access
			mem_axi_rdata <= mem_ocm[(latched_raddr - MEM_OCM_BASE) >> 2];
			mem_axi_rvalid <= 1;
			latched_raddr_en = 0;
        end else
        if (latched_raddr >= MEM_DDR_BASE && latched_raddr < (MEM_DDR_BASE + MEM_DDR_LEN)) begin
            // RAM access
            mem_axi_rdata <= mem_ram[(latched_raddr - MEM_DDR_BASE) >> 2];
            mem_axi_rvalid <= 1;
            latched_raddr_en = 0;
        end else
        if (latched_raddr == MEM_UART_SR) begin
            // UART0 SR access
            mem_axi_rdata <= 0;
            mem_axi_rvalid <= 1;
            latched_raddr_en = 0;
        end else
        if (latched_raddr == MEM_LEDS_BASE) begin
            // AXI GPIO 0 access
            mem_axi_rdata <= leds;
            mem_axi_rvalid <= 1;
            latched_raddr_en = 0;
		end else begin
			$display("OUT-OF-BOUNDS MEMORY READ FROM %08x", latched_raddr);
			$finish;
		end
	end endtask

	task handle_axi_bvalid; begin
		if (verbose)
			$display("WR: ADDR=%08x DATA=%08x STRB=%04b", latched_waddr, latched_wdata, latched_wstrb);
		if (latched_waddr >= MEM_OCM_BASE && latched_waddr < (MEM_OCM_BASE + MEM_OCM_LEN)) begin
			if (latched_wstrb[0]) mem_ocm[(latched_waddr - MEM_OCM_BASE) >> 2][ 7: 0] <= latched_wdata[ 7: 0];
			if (latched_wstrb[1]) mem_ocm[(latched_waddr - MEM_OCM_BASE) >> 2][15: 8] <= latched_wdata[15: 8];
			if (latched_wstrb[2]) mem_ocm[(latched_waddr - MEM_OCM_BASE) >> 2][23:16] <= latched_wdata[23:16];
			if (latched_wstrb[3]) mem_ocm[(latched_waddr - MEM_OCM_BASE) >> 2][31:24] <= latched_wdata[31:24];
		end else
		if (latched_waddr >= MEM_DDR_BASE && latched_waddr < (MEM_DDR_BASE + MEM_DDR_LEN)) begin
            if (latched_wstrb[0])
                mem_ram[(latched_waddr - MEM_DDR_BASE) >> 2][ 7: 0] <= latched_wdata[ 7: 0];
            if (latched_wstrb[1])
                mem_ram[(latched_waddr - MEM_DDR_BASE) >> 2][15: 8] <= latched_wdata[15: 8];
            if (latched_wstrb[2])
                mem_ram[(latched_waddr - MEM_DDR_BASE) >> 2][23:16] <= latched_wdata[23:16];
            if (latched_wstrb[3])
                mem_ram[(latched_waddr - MEM_DDR_BASE) >> 2][31:24] <= latched_wdata[31:24];
		end else
		if (latched_waddr == MEM_LEDS_BASE) begin
            if (latched_wstrb[0]) leds[ 7: 0] <= latched_wdata[ 7: 0];
            if (latched_wstrb[1]) leds[15: 8] <= latched_wdata[15: 8];
            if (latched_wstrb[2]) leds[23:16] <= latched_wdata[23:16];
            if (latched_wstrb[3]) leds[31:24] <= latched_wdata[31:24];
		end else
		if (latched_waddr == MEM_UART_FIFO) begin
		    // UART0 FIFO access
		    if (verbose) begin
                if (32 <= latched_wdata && latched_wdata < 128)
                    $display("OUT: '%c'", latched_wdata[7:0]);
                else
                    $display("OUT: %3d", latched_wdata);
            end else begin
                $write("%c", latched_wdata[7:0]);
`ifndef VERILATOR
                $fflush();
`endif
            end
		end else begin
			$display("OUT-OF-BOUNDS MEMORY WRITE TO %08x", latched_waddr);
			$finish;
		end
		mem_axi_bvalid <= 1;
		latched_waddr_en = 0;
		latched_wdata_en = 0;
	end endtask

	always @(negedge clk) begin
		if (mem_axi_arvalid && !(latched_raddr_en || fast_raddr) && async_axi_transaction[0]) handle_axi_arvalid;
		if (mem_axi_awvalid && !(latched_waddr_en || fast_waddr) && async_axi_transaction[1]) handle_axi_awvalid;
		if (mem_axi_wvalid  && !(latched_wdata_en || fast_wdata) && async_axi_transaction[2]) handle_axi_wvalid;
		if (!mem_axi_rvalid && latched_raddr_en && async_axi_transaction[3]) handle_axi_rvalid;
		if (!mem_axi_bvalid && latched_waddr_en && latched_wdata_en && async_axi_transaction[4]) handle_axi_bvalid;
	end

	always @(posedge clk) begin
		mem_axi_arready <= 0;
		mem_axi_awready <= 0;
		mem_axi_wready <= 0;

		fast_raddr <= 0;
		fast_waddr <= 0;
		fast_wdata <= 0;

		if (mem_axi_rvalid && mem_axi_rready) begin
			mem_axi_rvalid <= 0;
		end

		if (mem_axi_bvalid && mem_axi_bready) begin
			mem_axi_bvalid <= 0;
		end

		if (mem_axi_arvalid && mem_axi_arready && !fast_raddr) begin
			latched_raddr = mem_axi_araddr;
			latched_rinsn = mem_axi_arprot[2];
			latched_raddr_en = 1;
		end

		if (mem_axi_awvalid && mem_axi_awready && !fast_waddr) begin
			latched_waddr = mem_axi_awaddr;
			latched_waddr_en = 1;
		end

		if (mem_axi_wvalid && mem_axi_wready && !fast_wdata) begin
			latched_wdata = mem_axi_wdata;
			latched_wstrb = mem_axi_wstrb;
			latched_wdata_en = 1;
		end

		if (mem_axi_arvalid && !(latched_raddr_en || fast_raddr) && !delay_axi_transaction[0]) handle_axi_arvalid;
		if (mem_axi_awvalid && !(latched_waddr_en || fast_waddr) && !delay_axi_transaction[1]) handle_axi_awvalid;
		if (mem_axi_wvalid  && !(latched_wdata_en || fast_wdata) && !delay_axi_transaction[2]) handle_axi_wvalid;

		if (!mem_axi_rvalid && latched_raddr_en && !delay_axi_transaction[3]) handle_axi_rvalid;
		if (!mem_axi_bvalid && latched_waddr_en && latched_wdata_en && !delay_axi_transaction[4]) handle_axi_bvalid;
	end
endmodule

module testbench_picorv32 #(
    parameter AXI_TEST = 0,
	parameter VERBOSE = 0
) (
    input clk, resetn,
    output trap, tests_passed
);
	reg [31:0] irq;

	always @* begin
		irq = 0;
		irq[4] = &uut.picorv32_core.count_cycle[12:0];
		irq[5] = &uut.picorv32_core.count_cycle[15:0];
	end

	wire        mem_axi_awvalid;
	wire        mem_axi_awready;
	wire [31:0] mem_axi_awaddr;
	wire [ 2:0] mem_axi_awprot;

	wire        mem_axi_wvalid;
	wire        mem_axi_wready;
	wire [31:0] mem_axi_wdata;
	wire [ 3:0] mem_axi_wstrb;

	wire        mem_axi_bvalid;
	wire        mem_axi_bready;

	wire        mem_axi_arvalid;
	wire        mem_axi_arready;
	wire [31:0] mem_axi_araddr;
	wire [ 2:0] mem_axi_arprot;

	wire        mem_axi_rvalid;
	wire        mem_axi_rready;
	wire [31:0] mem_axi_rdata;
	
	wire trace_valid;
    wire [35:0] trace_data;
    integer trace_file;
    
    initial begin
        if ($test$plusargs("trace")) begin
            trace_file = $fopen("picorv32.trace", "w");
            repeat (10) @(posedge clk);
            while (!trap) begin
                @(posedge clk);
                if (trace_valid)
                    $fwrite(trace_file, "%x\n", trace_data);
            end
            $fclose(trace_file);
            $display("Finished writing picorv32.trace.");
        end
    end

	axi4_memory #(
		.AXI_TEST (AXI_TEST),
		.VERBOSE  (VERBOSE)
	) mem (
		.clk             (clk             ),
		.mem_axi_awvalid (mem_axi_awvalid ),
		.mem_axi_awready (mem_axi_awready ),
		.mem_axi_awaddr  (mem_axi_awaddr  ),
		.mem_axi_awprot  (mem_axi_awprot  ),

		.mem_axi_wvalid  (mem_axi_wvalid  ),
		.mem_axi_wready  (mem_axi_wready  ),
		.mem_axi_wdata   (mem_axi_wdata   ),
		.mem_axi_wstrb   (mem_axi_wstrb   ),

		.mem_axi_bvalid  (mem_axi_bvalid  ),
		.mem_axi_bready  (mem_axi_bready  ),

		.mem_axi_arvalid (mem_axi_arvalid ),
		.mem_axi_arready (mem_axi_arready ),
		.mem_axi_araddr  (mem_axi_araddr  ),
		.mem_axi_arprot  (mem_axi_arprot  ),

		.mem_axi_rvalid  (mem_axi_rvalid  ),
		.mem_axi_rready  (mem_axi_rready  ),
		.mem_axi_rdata   (mem_axi_rdata   ),

		.tests_passed    (tests_passed    )
	);

`ifdef RISCV_FORMAL
	wire        rvfi_valid;
	wire [63:0] rvfi_order;
	wire [31:0] rvfi_insn;
	wire        rvfi_trap;
	wire        rvfi_halt;
	wire        rvfi_intr;
	wire [4:0]  rvfi_rs1_addr;
	wire [4:0]  rvfi_rs2_addr;
	wire [31:0] rvfi_rs1_rdata;
	wire [31:0] rvfi_rs2_rdata;
	wire [4:0]  rvfi_rd_addr;
	wire [31:0] rvfi_rd_wdata;
	wire [31:0] rvfi_pc_rdata;
	wire [31:0] rvfi_pc_wdata;
	wire [31:0] rvfi_mem_addr;
	wire [3:0]  rvfi_mem_rmask;
	wire [3:0]  rvfi_mem_wmask;
	wire [31:0] rvfi_mem_rdata;
	wire [31:0] rvfi_mem_wdata;
`endif

	picorv32_axi #(
`ifndef SYNTH_TEST
`ifdef SP_TEST
		.ENABLE_REGS_DUALPORT(0),
`endif
`ifdef COMPRESSED_ISA
		.COMPRESSED_ISA(1),
`endif
		.ENABLE_MUL(1),
		.ENABLE_DIV(1),
		.ENABLE_IRQ(1),
		.ENABLE_TRACE(1)
`endif
	) uut (
		.clk            (clk            ),
		.resetn         (resetn         ),
		.trap           (trap           ),
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
		.irq            (irq            ),
`ifdef RISCV_FORMAL
		.rvfi_valid     (rvfi_valid     ),
		.rvfi_order     (rvfi_order     ),
		.rvfi_insn      (rvfi_insn      ),
		.rvfi_trap      (rvfi_trap      ),
		.rvfi_halt      (rvfi_halt      ),
		.rvfi_intr      (rvfi_intr      ),
		.rvfi_rs1_addr  (rvfi_rs1_addr  ),
		.rvfi_rs2_addr  (rvfi_rs2_addr  ),
		.rvfi_rs1_rdata (rvfi_rs1_rdata ),
		.rvfi_rs2_rdata (rvfi_rs2_rdata ),
		.rvfi_rd_addr   (rvfi_rd_addr   ),
		.rvfi_rd_wdata  (rvfi_rd_wdata  ),
		.rvfi_pc_rdata  (rvfi_pc_rdata  ),
		.rvfi_pc_wdata  (rvfi_pc_wdata  ),
		.rvfi_mem_addr  (rvfi_mem_addr  ),
		.rvfi_mem_rmask (rvfi_mem_rmask ),
		.rvfi_mem_wmask (rvfi_mem_wmask ),
		.rvfi_mem_rdata (rvfi_mem_rdata ),
		.rvfi_mem_wdata (rvfi_mem_wdata ),
`endif
		.trace_valid    (trace_valid    ),
		.trace_data     (trace_data     )
	);

`ifdef RISCV_FORMAL
	picorv32_rvfimon rvfi_monitor (
		.clock          (clk           ),
		.reset          (!resetn       ),
		.rvfi_valid     (rvfi_valid    ),
		.rvfi_order     (rvfi_order    ),
		.rvfi_insn      (rvfi_insn     ),
		.rvfi_trap      (rvfi_trap     ),
		.rvfi_halt      (rvfi_halt     ),
		.rvfi_intr      (rvfi_intr     ),
		.rvfi_rs1_addr  (rvfi_rs1_addr ),
		.rvfi_rs2_addr  (rvfi_rs2_addr ),
		.rvfi_rs1_rdata (rvfi_rs1_rdata),
		.rvfi_rs2_rdata (rvfi_rs2_rdata),
		.rvfi_rd_addr   (rvfi_rd_addr  ),
		.rvfi_rd_wdata  (rvfi_rd_wdata ),
		.rvfi_pc_rdata  (rvfi_pc_rdata ),
		.rvfi_pc_wdata  (rvfi_pc_wdata ),
		.rvfi_mem_addr  (rvfi_mem_addr ),
		.rvfi_mem_rmask (rvfi_mem_rmask),
		.rvfi_mem_wmask (rvfi_mem_wmask),
		.rvfi_mem_rdata (rvfi_mem_rdata),
		.rvfi_mem_wdata (rvfi_mem_wdata)
	);
`endif

	reg [1023:0] firmware_file;
	initial begin
		if (!$value$plusargs("firmware-picorv32=%s", firmware_file))
			firmware_file = "../../../firmware/tb-picorv32.hex";
		$readmemh(firmware_file, mem.mem_ocm);
	end

	integer cycle_counter;
	reg trap_q;
	always @(posedge clk) begin
        if (!resetn) begin
            cycle_counter <= 0;
            trap_q <= 0;
        end else if (!trap_q) begin
            cycle_counter <= cycle_counter + 1;
            if (trap) begin
`ifndef VERILATOR
                repeat (10) @(posedge clk);
`endif
                $display("PICORV32 TRAPPED after %1d clock cycles", cycle_counter);
                trap_q <= 1;
                if (tests_passed) begin
                    $display("ALL TESTS PASSED.");
                end else begin
                    $display("ERROR!");
                    if ($test$plusargs("noerror"))
                        $finish;
                    $stop;
                 end
            end
        end
    end

endmodule

module testbench_picodev #(
    parameter AXI_TEST = 0,
	parameter VERBOSE = 0,
	parameter CORES_COUNT = 4,
	parameter [31:0] PRIVATE_MEM_BASE = 32'h0002_0000,
    parameter [31:0] PRIVATE_MEM_OFFS = 32'h0000_4000,
    parameter [31:0] PRIVATE_MEM_LEN = 32'h0001_4000
) (
    input clk, resetn,
    output trap, tests_passed
);
    reg [31:0] irq;

	always @* begin
		irq = 0;
		irq[4] = &uut.device_single.device.GEN_CORE[0].core.count_cycle[12:0];
		irq[5] = &uut.device_single.device.GEN_CORE[0].core.count_cycle[15:0];
	end

    wire        mem_axi_awvalid;
	wire        mem_axi_awready;
	wire [31:0] mem_axi_awaddr;
	wire [ 2:0] mem_axi_awprot;

	wire        mem_axi_wvalid;
	wire        mem_axi_wready;
	wire [31:0] mem_axi_wdata;
	wire [ 3:0] mem_axi_wstrb;

	wire        mem_axi_bvalid;
	wire        mem_axi_bready;

	wire        mem_axi_arvalid;
	wire        mem_axi_arready;
	wire [31:0] mem_axi_araddr;
	wire [ 2:0] mem_axi_arprot;

	wire        mem_axi_rvalid;
	wire        mem_axi_rready;
	wire [31:0] mem_axi_rdata;
	
	wire trace_valid[CORES_COUNT-1:0];
    wire [35:0] trace_data[CORES_COUNT-1:0];
    integer trace_file[CORES_COUNT-1:0];
    
    genvar i;
    generate for (i = 0; i < CORES_COUNT; i = i + 1) begin
        initial begin
            string trace_fnm;
            if ($test$plusargs("trace")) begin
                trace_fnm = $sformatf("picodev_%1d.trace", i);
                trace_file[i] = $fopen(trace_fnm, "w");
                repeat (10) @(posedge clk);
                while (!trap) begin
                    @(posedge clk);
                    if (trace_valid[i])
                        $fwrite(trace_file[i], "%x\n", trace_data[i]);
                end
                $fclose(trace_file[i]);
                $display("Finished writing %s.", trace_fnm);
            end        
        end
    end endgenerate

    axi4_memory #(
		.AXI_TEST (AXI_TEST),
		.VERBOSE  (VERBOSE)
	) mem (
		.clk             (clk             ),
		.mem_axi_awvalid (mem_axi_awvalid ),
		.mem_axi_awready (mem_axi_awready ),
		.mem_axi_awaddr  (mem_axi_awaddr  ),
		.mem_axi_awprot  (mem_axi_awprot  ),

		.mem_axi_wvalid  (mem_axi_wvalid  ),
		.mem_axi_wready  (mem_axi_wready  ),
		.mem_axi_wdata   (mem_axi_wdata   ),
		.mem_axi_wstrb   (mem_axi_wstrb   ),

		.mem_axi_bvalid  (mem_axi_bvalid  ),
		.mem_axi_bready  (mem_axi_bready  ),

		.mem_axi_arvalid (mem_axi_arvalid ),
		.mem_axi_arready (mem_axi_arready ),
		.mem_axi_araddr  (mem_axi_araddr  ),
		.mem_axi_arprot  (mem_axi_arprot  ),

		.mem_axi_rvalid  (mem_axi_rvalid  ),
		.mem_axi_rready  (mem_axi_rready  ),
		.mem_axi_rdata   (mem_axi_rdata   ),

		.tests_passed    (tests_passed    )
	);
	
    picodevice_single_axi #(
		.ENABLE_TRACE    (1            ),
		.CORES_COUNT     (CORES_COUNT  ),
		.PRIVATE_MEM_BASE(32'h0002_0000),
        .PRIVATE_MEM_OFFS(32'h0000_4000),
        .PRIVATE_MEM_LEN (32'h0000_4000)
	) uut (
		.clk            (clk            ),
		.resetn         (resetn         ),
		.trap           (trap           ),
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
		
		.irq            (irq            ),
		.eoi            (               ),
		.trace_valid    (trace_valid    ),
		.trace_data     (trace_data     )
	);
	
	reg [1023:0] firmware_file;
    initial begin
        if (!$value$plusargs("firmware-picodev=%s", firmware_file))
            firmware_file = "../../../firmware/tb-picodev.hex";
        $readmemh(firmware_file, mem.mem_ocm);
    end
    
    integer cycle_counter;
    reg trap_q;
    always @(posedge clk) begin
        if (!resetn) begin
            cycle_counter <= 0;
            trap_q <= 0;
        end else if (!trap_q) begin
            cycle_counter <= cycle_counter + 1;
            if (trap) begin
`ifndef VERILATOR
                repeat (10) @(posedge clk);
`endif
                $display("PICODEV TRAPPED after %1d clock cycles", cycle_counter);
                trap_q <= 1;
                if (tests_passed) begin
                    $display("ALL TESTS PASSED.");
                end else begin
                    $display("ERROR!");
                    if ($test$plusargs("noerror"))
                        $finish;
                    $stop;
                end
            end
        end
    end
        
endmodule
