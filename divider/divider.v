`include "timescale.v"

module divider
    (
        input reset,
        input clk,

        input [15:0] a,
        input [15:0] b,
        output [15:0] r     // result have a 2 clocks latency
    );

    localparam base_table_size = 1024;
    localparam base_table_addr_width = $clog2(base_table_size);
    localparam base_table_width = 16;

    wire [base_table_addr_width-1:0] base_table_addr;
    wire [base_table_width-1:0] base_table_value;

    reg [15:0] a_reg;
    reg [15:0] b_subst;
    reg [15:0] b_reg;
    reg [2:0] ready_reg;
    wire [31:0] mul;

    always @(posedge clk, posedge reset) begin
        if(reset) begin
            a_reg <= 0;
            b_subst <= 0;
            b_reg <= 0;
        end
        else begin
            a_reg <= a;
            b_reg <= b;
            if(b >= 32769)                  b_subst <=  1;
            if((b >= 21847) & (b < 32769 )) b_subst <=  2;
            if((b >= 16385) & (b < 21847 )) b_subst <=  3;
            if((b >= 13109) & (b < 16385 )) b_subst <=  4;
            if((b >= 10924) & (b < 13109 )) b_subst <=  5;
            if((b >= 9364 ) & (b < 10924 )) b_subst <=  6;
            if((b >= 8193 ) & (b < 9364  )) b_subst <=  7;
            if((b >= 7283 ) & (b < 8193  )) b_subst <=  8;
            if((b >= 6555 ) & (b < 7283  )) b_subst <=  9;
            if((b >= 5959 ) & (b < 6555  )) b_subst <= 10;
            if((b >= 5463 ) & (b < 5959  )) b_subst <= 11;
            if((b >= 5043 ) & (b < 5463  )) b_subst <= 12;
            if((b >= 4683 ) & (b < 5043  )) b_subst <= 13;
            if((b >= 4371 ) & (b < 4683  )) b_subst <= 14;
            if((b >= 4097 ) & (b < 4371  )) b_subst <= 15;
            if((b >= 3857 ) & (b < 4097  )) b_subst <= 16;
            if((b >= 3642 ) & (b < 3857  )) b_subst <= 17;
            if((b >= 3451 ) & (b < 3642  )) b_subst <= 18;
            if((b >= 3278 ) & (b < 3451  )) b_subst <= 19;
            if((b >= 3122 ) & (b < 3278  )) b_subst <= 20;
            if((b >= 2980 ) & (b < 3122  )) b_subst <= 21;
            if((b >= 2851 ) & (b < 2980  )) b_subst <= 22;
            if((b >= 2732 ) & (b < 2851  )) b_subst <= 23;
            if((b >= 2623 ) & (b < 2732  )) b_subst <= 24;
            if((b >= 2522 ) & (b < 2623  )) b_subst <= 25;
            if((b >= 2429 ) & (b < 2522  )) b_subst <= 26;
            if((b >= 2342 ) & (b < 2429  )) b_subst <= 27;
            if((b >= 2261 ) & (b < 2342  )) b_subst <= 28;
            if((b >= 2186 ) & (b < 2261  )) b_subst <= 29;
            if((b >= 2116 ) & (b < 2186  )) b_subst <= 30;
            if((b >= 2049 ) & (b < 2116  )) b_subst <= 31;
            if((b >= 1987 ) & (b < 2049  )) b_subst <= 32;
            if((b >= 1929 ) & (b < 1987  )) b_subst <= 33;
            if((b >= 1874 ) & (b < 1929  )) b_subst <= 34;
            if((b >= 1822 ) & (b < 1874  )) b_subst <= 35;
            if((b >= 1773 ) & (b < 1822  )) b_subst <= 36;
            if((b >= 1726 ) & (b < 1773  )) b_subst <= 37;
            if((b >= 1682 ) & (b < 1726  )) b_subst <= 38;
            if((b >= 1640 ) & (b < 1682  )) b_subst <= 39;
            if((b >= 1600 ) & (b < 1640  )) b_subst <= 40;
            if((b >= 1562 ) & (b < 1600  )) b_subst <= 41;
            if((b >= 1526 ) & (b < 1562  )) b_subst <= 42;
            if((b >= 1491 ) & (b < 1526  )) b_subst <= 43;
            if((b >= 1458 ) & (b < 1491  )) b_subst <= 44;
            if((b >= 1426 ) & (b < 1458  )) b_subst <= 45;
            if((b >= 1396 ) & (b < 1426  )) b_subst <= 46;
            if((b >= 1367 ) & (b < 1396  )) b_subst <= 47;
            if((b >= 1339 ) & (b < 1367  )) b_subst <= 48;
            if((b >= 1312 ) & (b < 1339  )) b_subst <= 49;
            if((b >= 1287 ) & (b < 1312  )) b_subst <= 50;
            if((b >= 1262 ) & (b < 1287  )) b_subst <= 51;
            if((b >= 1238 ) & (b < 1262  )) b_subst <= 52;
            if((b >= 1215 ) & (b < 1238  )) b_subst <= 53;
            if((b >= 1193 ) & (b < 1215  )) b_subst <= 54;
            if((b >= 1172 ) & (b < 1193  )) b_subst <= 55;
            if((b >= 1151 ) & (b < 1172  )) b_subst <= 56;
            if((b >= 1131 ) & (b < 1151  )) b_subst <= 57;
            if((b >= 1112 ) & (b < 1131  )) b_subst <= 58;
            if((b >= 1094 ) & (b < 1112  )) b_subst <= 59;
            if((b >= 1076 ) & (b < 1094  )) b_subst <= 60;
            if((b >= 1059 ) & (b < 1076  )) b_subst <= 61;
            if((b >= 1042 ) & (b < 1059  )) b_subst <= 62;
            if((b >= 1025 ) & (b < 1042  )) b_subst <= 63;
            if( b == 1024)                  b_subst <= 64;
        end
    end

	lpm_mult mult
        (
            .clock (clk),
            .dataa (a_reg),
            .datab ((b_reg < 1024) ? base_table_value : b_subst),
            .result (mul),
            .aclr (reset),
            .clken (1'b1),
            .sum (1'b0)
        );
	defparam
        mult.lpm_widtha = base_table_width,
        mult.lpm_widthb = base_table_width,
        mult.lpm_widthp = base_table_width + base_table_width,
		mult.lpm_hint = "DEDICATED_MULTIPLIER_CIRCUITRY=YES,MAXIMIZE_SPEED=5",
		mult.lpm_pipeline = 1,
		mult.lpm_representation = "UNSIGNED",
		mult.lpm_type = "LPM_MULT";

    assign r = mul [31 -: 16] + 1;

	altsyncram	base_table
        (
            .address_a          (b[0 +: base_table_addr_width]),
            .clock0             (clk),
            .q_a                (base_table_value),
            .aclr0              (1'b0),
            .aclr1              (1'b0),
            .address_b          (1'b1),
            .addressstall_a     (1'b0),
            .addressstall_b     (1'b0),
            .byteena_a          (1'b1),
            .byteena_b          (1'b1),
            .clock1             (1'b1),
            .clocken0           (1'b1),
            .clocken1           (1'b1),
            .clocken2           (1'b1),
            .clocken3           (1'b1),
            .data_a             ({16{1'b1}}),
            .data_b             (1'b1),
            .eccstatus          (),
            .q_b                (),
            .rden_a             (1'b1),
            .rden_b             (1'b1),
            .wren_a             (1'b0),
            .wren_b             (1'b0)
        );
	defparam
        base_table.width_a                = base_table_width,
        base_table.numwords_a             = base_table_size,
        base_table.widthad_a              = base_table_addr_width,
        base_table.init_file              = "rtl/base_table.mif",
		base_table.address_aclr_a         = "NONE",
		base_table.clock_enable_input_a   = "BYPASS",
		base_table.clock_enable_output_a  = "BYPASS",
		base_table.intended_device_family = "Cyclone III",
		base_table.lpm_hint               = "ENABLE_RUNTIME_MOD=NO",
		base_table.lpm_type               = "altsyncram",
		base_table.operation_mode         = "ROM",
		base_table.outdata_aclr_a         = "NONE",
		base_table.outdata_reg_a          = "UNREGISTERED",
		base_table.width_byteena_a        = 1;

endmodule

