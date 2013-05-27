module sim_dp_ram(input wire clk,
		  input wire [31:0] i_addr,
		  output reg [31:0] i_data,
		  input wire [31:0] d_addr,
		  input wire [3:0] d_bytesel,
		  input wire [31:0] d_wr_val,
		  input wire d_wr_en,
		  output reg [31:0] d_data);

reg [7:0] ram [127:0];
reg [8 * 128:0] ram_filename;

initial begin
	if (!$value$plusargs("ramfile=%s", ram_filename) ||
	    ram_filename == 0) begin
		$display("+ramfile=PATH_TO_ram.hex required");
		$finish;
	end
	$readmemh(ram_filename, ram);
	i_data = 32'hffffffff;
	d_data = 32'h00000000;
end

always @(posedge clk) begin
	i_data <= { ram[i_addr + 3],
		    ram[i_addr + 2],
		    ram[i_addr + 1],
		    ram[i_addr + 0] };
	if (d_wr_en) begin
		if (d_bytesel[3])
			ram[d_addr + 3] <= d_wr_val[31:24];
		if (d_bytesel[2])
			ram[d_addr + 2] <= d_wr_val[23:16];
		if (d_bytesel[1])
			ram[d_addr + 1] <= d_wr_val[15:8];
		if (d_bytesel[0])
			ram[d_addr + 3] <= d_wr_val[7:0];
	end else begin
		if (d_bytesel[3])
			d_data[31:24] <= ram[d_addr + 3];
		if (d_bytesel[2])
			d_data[23:16] <= ram[d_addr + 2];
		if (d_bytesel[1])
			d_data[15:8] <= ram[d_addr + 1];
		if (d_bytesel[0])
			d_data[7:0] <= ram[d_addr + 0];
	end
end

endmodule