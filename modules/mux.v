`include "timescale.v"

module mux
    #(
        parameter CHANNELS_USED = 3,
        parameter DATA_WIDTH = 16,
        parameter FIFO_SIZE = 64,
        parameter SLIP_SIZE = 1         // how many words to slip when reading the one channel
    )
    (
        input reset,
        input clk,

        output reg [CHANNELS_USED-1:0] channel_rdreq,
        input [(DATA_WIDTH * CHANNELS_USED)-1:0] channel_data,
        input [CHANNELS_USED-1:0] channel_empty,

        input fifo_rdclk,
        input fifo_rdreq,
        output [DATA_WIDTH-1:0] fifo_out,
        output [$clog2(FIFO_SIZE)-1:0] fifo_usedw,
        output fifo_empty,
        output fifo_full
    );

    integer ch;
    reg [$clog2(CHANNELS_USED)-1:0] channel, channel_reg0, channel_reg1;
    reg common_fifo_wrreq, common_fifo_wrreq_reg0;
    reg [$clog2(SLIP_SIZE):0] slip;
    reg [(DATA_WIDTH * CHANNELS_USED)-1:0] databuf;
    wire common_fifo_wrfull;

    always @(posedge clk, posedge reset) begin
        if(reset) begin
            channel_rdreq <= 0;
            common_fifo_wrreq <= 0;
            channel <= 0;
            channel_reg0 <= 0;
            channel_reg1 <= 0;
            slip <= SLIP_SIZE;
            databuf <= 0;
        end
        else begin
            if(!channel_empty[channel] & !common_fifo_wrfull) begin
                if(slip > 0) begin
                    slip <= slip - 1;
                    channel_rdreq[channel] <= 1;
                end
                else begin
                    slip <= SLIP_SIZE;
                    channel_rdreq[channel] <= 0;
                end
            end
            else begin
                if(channel == (CHANNELS_USED - 1)) channel <= 0;
                else channel <= channel + 1;
            end

            channel_reg0 <= channel;
            channel_reg1 <= channel_reg0;
            common_fifo_wrreq <= |channel_rdreq;
            common_fifo_wrreq_reg0 <= common_fifo_wrreq;
            databuf <= channel_data;
        end
    end

	dcfifo common_fifo
        (
            .aclr           (reset),

            .wrclk          (clk),
            .data           (channel_data[channel_reg1*DATA_WIDTH +: DATA_WIDTH]),
            .wrreq          (common_fifo_wrreq),
            .wrfull         (common_fifo_wrfull),

            .rdclk          (fifo_rdclk),
            .rdreq          (fifo_rdreq),
            .q              (fifo_out),
            .rdempty        (fifo_empty),
            .rdusedw        (fifo_usedw),
            .rdfull         (fifo_full)
        );
	defparam
        common_fifo.lpm_width = DATA_WIDTH,
        common_fifo.lpm_numwords = FIFO_SIZE,
        common_fifo.lpm_widthu = $clog2(FIFO_SIZE),
		common_fifo.intended_device_family = "Cyclone III", 
		common_fifo.lpm_showahead = "OFF",
		common_fifo.lpm_type = "dcfifo",
		common_fifo.overflow_checking = "ON",
		common_fifo.underflow_checking = "ON",
		common_fifo.use_eab = "ON",
        common_fifo.rdsync_delaypipe = 4,
		common_fifo.wrsync_delaypipe = 4;

endmodule

