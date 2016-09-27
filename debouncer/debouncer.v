module debouncer
	(
		input clk,
		input reset,
		input in,
		output reg out
	);
	
	parameter BOUNCE_COUNTER_WIDTH	= 21;
	parameter BOUNCE_TIME			= 1_250_000; // 10ms on 125MHz clock
	parameter GENERATE_PULSE		= 1;
	
	reg [BOUNCE_COUNTER_WIDTH-1:0] counter1;
	reg [BOUNCE_COUNTER_WIDTH-1:0] counter2;
	
	reg in_reg;
	reg [1:0] state;
	
	parameter ST_WAIT_ON	= 0;
	parameter ST_COUNT1		= 1;
	parameter ST_WAIT_OFF	= 2;
	parameter ST_COUNT2		= 3;
	
	always @(posedge clk, posedge reset) begin
		if(reset) begin
			counter1 <= 0;
			counter2 <= 0;
			out <= 0;
			in_reg <= 0;
			state <= ST_WAIT_ON;
		end
		else begin
			in_reg <= in;
			case(state)
				ST_WAIT_ON:
					begin
						if(in_reg) begin
							out <= 1;
							state <= ST_COUNT1;
						end
						else begin
							state <= ST_WAIT_ON;
						end
					end
				
				ST_COUNT1:
					begin
						if(GENERATE_PULSE) out <= 0;
						if(counter1 < BOUNCE_TIME) counter1 <= counter1 + 1;
						else begin
							out <= 0;
							counter1 <= 0;
							state <= ST_WAIT_OFF;
						end
					end
				
				ST_WAIT_OFF:
					begin
						if(in_reg==0) state <= ST_COUNT2;
						else state <= ST_WAIT_OFF;
					end
				
				ST_COUNT2:
					begin
						if(counter2 < BOUNCE_TIME) counter2 <= counter2 + 1;
						else begin
							counter2 <= 0;
							state <= ST_WAIT_ON;
						end
					end
				
				default:
					begin
						counter1 <= 0;
						counter2 <= 0;
						state <= ST_WAIT_ON;
					end
				
			endcase
		end
	end
	
endmodule
