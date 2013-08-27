module oldland_debug(input wire		clk,
		     input wire		dbg_clk,
		     input wire [1:0]	addr,
		     input wire [31:0]	din,
		     output wire [31:0]	dout,
		     input wire		wr_en,
		     input wire		req,
		     output wire	ack,
		     /* Execution control signals. */
		     output reg		run,
		     input wire		stopped,
		     /* Memory read/write signals. */
		     output wire [31:0] mem_addr,
		     output reg [1:0]	mem_width,
		     output wire [31:0] mem_wr_val,
		     input wire [31:0]	mem_rd_val,
		     output reg		mem_wr_en,
		     output reg		mem_access,
		     input wire		mem_compl,
		     /* GPR read/write signals. */
		     output wire [3:0]	dbg_reg_sel,
		     input wire [31:0]	dbg_reg_val,
		     output wire [31:0]	dbg_reg_wr_val,
		     output reg		dbg_reg_wr_en,
		     /* PC read/write signals. */
		     input wire [31:0]	dbg_pc,
		     output reg		dbg_pc_wr_en,
		     output wire [31:0]	dbg_pc_wr_val);

localparam STATE_IDLE		= 4'b0000;
localparam STATE_LOAD_CMD	= 4'b0001;
localparam STATE_LOAD_ADDR	= 4'b0010;
localparam STATE_LOAD_DATA	= 4'b0011;
localparam STATE_WAIT_STOPPED	= 4'b0100;
localparam STATE_STEP		= 4'b0101;
localparam STATE_COMPL		= 4'b0110;
localparam STATE_STORE_REG_RVAL	= 4'b0111;
localparam STATE_WRITE_REG	= 4'b1111;
localparam STATE_WAIT_RMEM	= 4'b1110;
localparam STATE_WAIT_WMEM	= 4'b1100;
localparam STATE_EXECUTE	= 4'b1000;

localparam CMD_HALT		= 4'h0;
localparam CMD_RUN		= 4'h1;
localparam CMD_STEP		= 4'h2;
localparam CMD_READ_REG		= 4'h3;
localparam CMD_WRITE_REG	= 4'h4;
localparam CMD_RMEM32		= 4'h5;
localparam CMD_RMEM16		= 4'h6;
localparam CMD_RMEM8		= 4'h7;
localparam CMD_WMEM32		= 4'h8;
localparam CMD_WMEM16		= 4'h9;
localparam CMD_WMEM8		= 4'ha;

reg [1:0]	ctl_addr = 2'b00;
reg [31:0]	ctl_din = 32'b0;
wire [31:0]	ctl_dout;
reg		ctl_wr_en = 1'b0;

reg [3:0]	state = STATE_IDLE;
reg [3:0]	next_state = STATE_IDLE;

reg [3:0]	debug_cmd = 4'b0;
reg [31:0]	debug_addr = 32'b0;
reg [31:0]	debug_data = 32'b0;

wire		req_sync;	/*
				 * Synchronized from debug to CPU clock.
				 */
reg		ack_internal;	/*
				 * CPU clock, will be synchronized to debug
				 * clock.
				 */

dc_ram		#(.addr_bits(2),
		  .data_bits(32))
		dbg_ram(.clk_a(dbg_clk),
			.addr_a(addr),
			.din_a(din),
			.dout_a(dout),
			.wr_en_a(wr_en),
			.clk_b(clk),
			.addr_b(ctl_addr),
			.din_b(ctl_din),
			.dout_b(ctl_dout),
			.wr_en_b(ctl_wr_en));

sync2ff		sync_req(.dst_clk(clk),
			 .din(req),
			 .dout(req_sync));

sync2ff		sync_ack(.dst_clk(dbg_clk),
			 .din(ack_internal),
			 .dout(ack));

initial begin
	ack_internal = 1'b0;
	run = 1'b1;
	dbg_reg_wr_en = 1'b0;
	dbg_pc_wr_en = 1'b0;
	mem_wr_en = 1'b0;
	mem_access = 1'b0;
end

assign dbg_reg_sel = debug_addr[3:0];
assign dbg_pc_wr_val = debug_data;
assign dbg_reg_wr_val = debug_data;
assign mem_addr = debug_addr;
assign mem_wr_val = debug_data;

always @(*) begin
	mem_width = 2'b10;
	mem_wr_en = 1'b0;

	case (debug_cmd)
	CMD_WMEM32: begin
		mem_width = 2'b10;
		mem_wr_en = 1'b1;
	end
	CMD_WMEM16: begin
		mem_width = 2'b01;
		mem_wr_en = 1'b1;
	end
	CMD_WMEM8: begin
		mem_width = 2'b00;
		mem_wr_en = 1'b1;
	end
	CMD_RMEM32: mem_width = 2'b10;
	CMD_RMEM16: mem_width = 2'b01;
	CMD_RMEM8: mem_width = 2'b00;
	endcase
end

always @(*) begin
	ctl_addr = 2'b00;
	ctl_wr_en = 1'b0;
	dbg_pc_wr_en = 1'b0;
	dbg_reg_wr_en = 1'b0;
	mem_access = 1'b0;

	case (state)
	STATE_IDLE: begin
		next_state = req_sync ? STATE_LOAD_CMD : STATE_IDLE;
		ctl_addr = 2'b00;
	end
	STATE_LOAD_CMD: begin
		next_state = STATE_LOAD_ADDR;
		ctl_addr = 2'b01;
	end
	STATE_LOAD_ADDR: begin
		next_state = STATE_LOAD_DATA;
		ctl_addr = 2'b10;
	end
	STATE_LOAD_DATA: begin
		next_state = STATE_EXECUTE;
	end
	STATE_EXECUTE: begin
		case (debug_cmd)
		CMD_HALT: next_state = STATE_WAIT_STOPPED;
		CMD_RUN: next_state = STATE_COMPL;
		CMD_STEP: next_state = STATE_STEP;
		CMD_READ_REG: next_state = STATE_STORE_REG_RVAL;
		CMD_WRITE_REG: next_state = STATE_WRITE_REG;
		CMD_RMEM8: begin
			next_state = STATE_WAIT_RMEM;
			mem_access = 1'b1;
		end
		CMD_RMEM16: begin
			next_state = STATE_WAIT_RMEM;
			mem_access = 1'b1;
		end
		CMD_RMEM32: begin
			next_state = STATE_WAIT_RMEM;
			mem_access = 1'b1;
		end
		CMD_WMEM8: begin
			next_state = STATE_WAIT_WMEM;
			mem_access = 1'b1;
		end
		CMD_WMEM16: begin
			next_state = STATE_WAIT_WMEM;
			mem_access = 1'b1;
		end
		CMD_WMEM32: begin
			next_state = STATE_WAIT_WMEM;
			mem_access = 1'b1;
		end
		default: next_state = STATE_COMPL;
		endcase
	end
	STATE_WRITE_REG: begin
		if (debug_addr[4])
			dbg_pc_wr_en = 1'b1;
		else
			dbg_reg_wr_en = 1'b1;
		next_state = STATE_COMPL;
	end
	STATE_WAIT_WMEM: begin
		mem_access = ~mem_compl;
		next_state = mem_compl ? STATE_COMPL : STATE_WAIT_WMEM;
	end
	STATE_WAIT_RMEM: begin
		mem_access = ~mem_compl;
		if (mem_compl) begin
			ctl_addr = 2'b11;
			ctl_wr_en = 1'b1;
			ctl_din = mem_rd_val;
			next_state = STATE_COMPL;
		end else begin
			next_state = STATE_WAIT_RMEM;
		end
	end
	STATE_STEP: begin
		next_state = STATE_WAIT_STOPPED;
	end
	STATE_WAIT_STOPPED: begin
		next_state = stopped ? STATE_COMPL : STATE_WAIT_STOPPED;
	end
	STATE_STORE_REG_RVAL: begin
		ctl_addr = 2'b11;
		ctl_wr_en = 1'b1;
		ctl_din = debug_addr[4] ? dbg_pc : dbg_reg_val;
		next_state = STATE_COMPL;
	end
	STATE_COMPL: begin
		next_state = req_sync ? STATE_COMPL : STATE_IDLE;
	end
	default: begin
		next_state = STATE_IDLE;
	end
	endcase
end

always @(posedge clk) begin
	ack_internal <= 1'b0;
	dbg_reg_wr_en <= 1'b0;

	case (state)
	STATE_IDLE: begin
	end
	STATE_LOAD_CMD: begin
		debug_cmd <= ctl_dout[3:0];
	end
	STATE_LOAD_ADDR: begin
		debug_addr <= ctl_dout;
	end
	STATE_LOAD_DATA: begin
		debug_data <= ctl_dout;
	end
	STATE_EXECUTE: begin
		case (debug_cmd)
		CMD_HALT: run <= 1'b0;
		CMD_RUN: run <= 1'b1;
		CMD_STEP: run <= 1'b1;
		default: begin
		end
		endcase
	end
	STATE_STEP: begin
		run <= 1'b0;
	end
	STATE_COMPL: begin
		ack_internal <= 1'b1;
	end
	default: begin
	end
	endcase
end

always @(posedge clk)
	state <= next_state;

endmodule
