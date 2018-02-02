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
	parameter VERBOSE = 0,
	parameter CORES_COUNT = 1
);
	reg clk = 1;
	reg resetn = 0;
	wire trap;

	always #5 clk = ~clk;

	initial begin
		repeat (100) @(posedge clk);
		resetn <= 1;
	end

	initial begin
		if ($test$plusargs("vcd")) begin
			$dumpfile("testbench.vcd");
			$dumpvars(0, testbench);
		end
		repeat (1000000) @(posedge clk);
		$display("TIMEOUT");
		$finish;
	end

	wire trace_valid[CORES_COUNT-1:0];
	wire [35:0] trace_data[CORES_COUNT-1:0];
//	string trace_file_name[CORES_COUNT-1:0];
	integer trace_file[CORES_COUNT-1:0];

    genvar i;
    generate
    for (i = 0; i < CORES_COUNT; i = i + 1) begin
        initial begin
            string trace_file_name;
            
            trace_file_name = $sformatf("testbench.trace%1d", i);
            $display("Opening %s", trace_file_name);
            trace_file[i] = $fopen(trace_file_name, "w");
            repeat (10) @(posedge clk);
            while (!trap) begin
                @(posedge clk);
                if (trace_valid[i])
                    $fwrite(trace_file[i], "%x\n", trace_data[i]);
            end
            $fclose(trace_file[i]);
            $display("Finished writing %s.", trace_file_name);        
        end
    end
    endgenerate

	picodevice_tb_wrapper #(
		.AXI_TEST (AXI_TEST),
		.VERBOSE  (VERBOSE)
	) top (
		.clk(clk),
		.resetn(resetn),
		.trap(trap),
		.trace_valid(trace_valid),
		.trace_data(trace_data)
	);
endmodule
`endif

module picodevice_tb_wrapper #(
	parameter AXI_TEST = 0,
	parameter VERBOSE = 0,
	parameter CORES_COUNT = 1
) (
	input clk,
	input resetn,
	output trap,
	output trace_valid[CORES_COUNT-1:0],
	output [35:0] trace_data[CORES_COUNT-1:0]
);
    integer cycle_counter;
	wire tests_passed;
	reg [15:0] irq;
    
	always @* begin
		irq = {14'h0, &cycle_counter[15:0], &cycle_counter[12:0]}; 
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
	
	
	

	picodevice #(
		.ENABLE_TRACE(1          ),
		.CORES_COUNT (CORES_COUNT)
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
		if (!$value$plusargs("firmware=%s", firmware_file))
			firmware_file = "D:/MGR/vivado-projects/pico-devel/repo/firmware/build/pico-testbench.hex";
		$readmemh(firmware_file, mem.mem_ocm);
	end

	
	always @(posedge clk) begin
		cycle_counter <= resetn ? cycle_counter + 1 : 0;
		if (resetn && trap) begin
`ifndef VERILATOR
			repeat (10) @(posedge clk);
`endif
			$display("TRAP after %1d clock cycles", cycle_counter);
			if (tests_passed) begin
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
endmodule

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
	reg [31:0]   mem_ocm [0: 256*1024/4-1] /* verilator public */;
	reg [31:0]   mem_ram [0:1024*1024/4-1] /* verilator public */;
	reg verbose;
	initial verbose = $test$plusargs("verbose") || VERBOSE;

	reg axi_test;
	initial axi_test = $test$plusargs("axi_test") || AXI_TEST;

	initial tests_passed = 0;

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

	always @(posedge clk) begin
		if (axi_test) begin
				xorshift64_next;
				{fast_axi_transaction, async_axi_transaction, delay_axi_transaction} <= xorshift64_state;
		end
	end

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
		if (latched_raddr < 256*1024) begin
            // OCM access
			mem_axi_rdata <= mem_ocm[latched_raddr >> 2];
			mem_axi_rvalid <= 1;
			latched_raddr_en = 0;
        end else
        if (latched_raddr >= 32'h0010_0000 && latched_raddr < 32'h0020_0000) begin
            // RAM access
            mem_axi_rdata <= mem_ram[latched_raddr >> 2];
            mem_axi_rvalid <= 1;
            latched_raddr_en = 0;
        end else
        if (latched_raddr == 32'hE000_002C) begin
            // UART0 SR access
            mem_axi_rdata <= 0;
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
		if (latched_waddr < 256*1024) begin
			if (latched_wstrb[0]) mem_ocm[latched_waddr >> 2][ 7: 0] <= latched_wdata[ 7: 0];
			if (latched_wstrb[1]) mem_ocm[latched_waddr >> 2][15: 8] <= latched_wdata[15: 8];
			if (latched_wstrb[2]) mem_ocm[latched_waddr >> 2][23:16] <= latched_wdata[23:16];
			if (latched_wstrb[3]) mem_ocm[latched_waddr >> 2][31:24] <= latched_wdata[31:24];
		end else
		if (latched_waddr >= 32'h0010_0000 && latched_waddr < 32'h0020_0000) begin
            if (latched_wstrb[0]) mem_ram[latched_waddr[23:0] >> 2][ 7: 0] <= latched_wdata[ 7: 0];
            if (latched_wstrb[1]) mem_ram[latched_waddr[23:0] >> 2][15: 8] <= latched_wdata[15: 8];
            if (latched_wstrb[2]) mem_ram[latched_waddr[23:0] >> 2][23:16] <= latched_wdata[23:16];
            if (latched_wstrb[3]) mem_ram[latched_waddr[23:0] >> 2][31:24] <= latched_wdata[31:24];
		end else
		if (latched_waddr == 32'hE000_0030) begin
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
		end else
        if (latched_waddr == 32'h0030_0000) begin
            $display("REPORTED TIMER COUNT: %1d", latched_wdata);
        end else
        if (latched_waddr == 32'h0020_0000) begin
            if (latched_wdata == 123456789)
                tests_passed = 1;
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





module tb_picorv32_pcpi_fork ();

	reg clk, resetn;
	reg pcpi_valid;
	reg [31:0] pcpi_insn;
	wire pcpi_wr;
	wire signed [31:0] pcpi_rd;
	wire pcpi_wait, pcpi_ready;
	
	reg child_start, child_stop;
	wire child_resetn, child_valid, child_wen;
	wire [4:0] child_rd;
	wire [31:0] child_pc, child_data;
	reg child_ready, child_cplt;
	
	wire fork_dma_req;
	reg fork_dma_done;
	
	wire parent_cplt;
	
	reg [31:0] fork_data;
	wire [4:0] fork_rs;
	
	always @* begin
		fork_data[31:5] = 'b0;
		fork_data[4:0] = fork_rs;
	end
	
	always begin
		child_ready = 0;
		child_cplt = 0;
		@(posedge child_resetn);
		#25;
		if (child_start) begin
		  child_ready = 1;
		  @(posedge child_valid);
		  child_ready = 0;
		  @(posedge child_stop);
		  child_cplt = 1;
		end
		@(negedge child_resetn);
	end

	always begin
		fork_dma_done = 0;
		@(posedge fork_dma_req);
		#50
		fork_dma_done = 1;
		@(negedge fork_dma_req);
	end
	
	always
		#5 clk = !clk;
	
	initial begin
		clk = 0;
		resetn = 0;
		pcpi_valid = 0;
		pcpi_insn = 0;
		pcpi_insn[6:0] = 7'b0101011;
		child_start = 0;
		child_stop = 0;
		#50;
		resetn = 1;
		
		#25;
		
		$display("testing instruction coreid");
		pcpi_insn[14:12] = 3'b000;
		@(posedge clk);
		pcpi_valid = 1;
		@(posedge pcpi_wait);
		@(posedge pcpi_ready);
		$display("pcpi_rd = %.8X", pcpi_rd);
		if (pcpi_rd != 32'h1234_5678) begin
		  $display("FAIL");
		  $finish;
		end
		//@(posedge clk);
		pcpi_valid = 0;
		
		#25;
		
		$display("testing instruction fork, child disabled");
		pcpi_insn[14:12] = 3'b100;
		@(posedge clk);
		pcpi_valid = 1;
		@(posedge pcpi_wait);
		@(posedge pcpi_ready);
		$display("pcpi_rd = %.8X", pcpi_rd);
		if (pcpi_rd != -1) begin
		  $display("FAIL");
		  $finish;
		end
		//@(posedge clk);
		pcpi_valid = 0;
		
		#25;
		
		$display("testing instruction fork, child enabled");
		child_start = 1;
		pcpi_insn[14:12] = 3'b100;
		@(posedge clk)
		pcpi_valid = 1;
		@(posedge pcpi_wait);
		@(posedge pcpi_ready);
		$display("pcpi_rd = %.8X", pcpi_rd);
		if (pcpi_rd != 0) begin
		  $display("FAIL");
          $finish;
		end
		//@(posedge clk);
		child_start = 0;
		pcpi_valid = 0;
		
		#25;
		
		$display("testing instruction fork, child already running");
        pcpi_insn[14:12] = 3'b100;
        @(posedge clk);
        pcpi_valid = 1;
        @(posedge pcpi_wait);
        @(posedge pcpi_ready);
        $display("pcpi_rd = %.8X", pcpi_rd);
        if (pcpi_rd != -1) begin
            $display("FAIL");
            $finish;
        end
        //@(posedge clk);
        pcpi_valid = 0;
        
        #25;
		
		$display("testing instruction join, child running");
		pcpi_insn[14:12] = 3'b101;
		@(posedge clk)
		pcpi_valid = 1;
		@(posedge pcpi_wait);
		#100;
		child_stop = 1;
		@(posedge pcpi_ready);
		//@(posedge clk);
		child_stop = 0;
		pcpi_valid = 0;
		
		#25;
		
		$display("testing instruction join, child not running");
        pcpi_insn[14:12] = 3'b101;
        @(posedge clk)
        pcpi_valid = 1;
        @(posedge pcpi_wait);
        @(posedge pcpi_ready);
        //@(posedge clk);
        pcpi_valid = 0;
        
        #25;
        
        $display("testing instruction fork, child enabled");
        child_start = 1;
        pcpi_insn[14:12] = 3'b100;
        @(posedge clk)
        pcpi_valid = 1;
        @(posedge pcpi_wait);
        @(posedge pcpi_ready);
        $display("pcpi_rd = %.8X", pcpi_rd);
        if (pcpi_rd != 0) begin
            $display("FAIL");
            $finish;
        end
        //@(posedge clk);
        child_start = 0;
        pcpi_valid = 0;
        
        #25;
        
        $display("testing instruction join, child already completed");
        pcpi_insn[14:12] = 3'b101;
        child_stop = 1;
        #25;
        @(posedge clk)
        pcpi_valid = 1;
        @(posedge pcpi_wait);
        @(posedge pcpi_ready);
        //@(posedge clk);
        child_stop = 0;
        pcpi_valid = 0;
        
        #25;
        
        $display("testing instruction exit");
        pcpi_insn[14:12] = 3'b110;
        @(posedge clk)
        pcpi_valid = 1;
        @(posedge pcpi_wait);
        @(posedge parent_cplt);
        #25;
        resetn = 0;
        
        #50 $display("DONE");
		#25 $finish;
	end
	
	initial begin
		#10000;
		$display("TIMEOUT");
		$finish;
	end
	

	picorv32_pcpi_fork dut (
		.clk(clk), .resetn(resetn),
		
		.pcpi_valid(pcpi_valid   ),
		.pcpi_insn (pcpi_insn    ),
		.pcpi_rs1  (32'h0000_0000),
		.pcpi_rs2  (32'h0000_0000),
		.pcpi_wr   (pcpi_wr      ),
		.pcpi_rd   (pcpi_rd      ),
		.pcpi_wait (pcpi_wait    ),
		.pcpi_ready(pcpi_ready   ),
		
		.child_resetn(child_resetn),
		.child_ready (child_ready ),
		.child_valid (child_valid ),
		.child_pc    (child_pc    ),
		.child_cplt  (child_cplt  ),
		.child_rd    (child_rd    ),
		.child_data  (child_data  ),
		.child_wen   (child_wen   ),
		
		.dma_req (fork_dma_req ),
		.dma_done(fork_dma_done),
		
		.parent_cplt(parent_cplt),
		
		.cpu_next_pc(32'h0000_0004),
		.cpu_rd     (32'h0000_0001),
		.cpu_rs     (fork_rs      ),
		.cpu_data   (fork_data    )
	);

endmodule

