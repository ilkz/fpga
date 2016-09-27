module dcfifo_to_qsys
    #(
        parameter FIFO_SIZE = 256,
        parameter FIFO_USEDW_WIDTH = 8,
        parameter FIFO_WIDTH = 16
    )
    (
        // clock & reset interfaces
        input           avalon_clk,
        input           avalon_reset,

        // slave interface
        input              avs_s0_write,
        input              avs_s0_read,
        input      [1:0]   avs_s0_address,
        input      [31:0]  avs_s0_writedata,
        output reg [31:0]  avs_s0_readdata,
        output reg         avs_s0_interrupt,

        // fifo interface (write side)
        input dcfifo_wrclk,
        input [FIFO_WIDTH-1:0] dcfifo_data,
        input dcfifo_wrreq,
        output [FIFO_USEDW_WIDTH-1:0] dcfifo_wrusedw,
        output dcfifo_wrempty,
        output dcfifo_wrfull
    );

    wire reset = avalon_reset;
    wire clk = avalon_clk;

    wire [FIFO_WIDTH-1:0] dcfifo_out;
    wire [$clog2(FIFO_SIZE)-1:0] dcfifo_rdusedw;
    wire dcfifo_rdempty;
    wire dcfifo_rdfull;

    reg irq_en;
    reg dcfifo_rdreq;

    always @(posedge clk, posedge reset) begin
        if(reset) begin
            avs_s0_readdata <= 0;
            avs_s0_interrupt <= 0;
            irq_en <= 0;
            dcfifo_rdreq <= 0;
        end
        else begin
            if(avs_s0_write) begin
                case(avs_s0_address)
                    0: irq_en <= avs_s0_writedata[0];
                    1: dcfifo_rdreq <= avs_s0_writedata[0];
                endcase
            end
            if(avs_s0_read) begin
                case(avs_s0_address)
                    0: avs_s0_readdata <= {dcfifo_rdusedw, dcfifo_rdfull, dcfifo_rdempty, irq_en};
                    1: avs_s0_readdata[FIFO_WIDTH-1:0] <= dcfifo_out;
                endcase
            end

            if(dcfifo_rdreq) dcfifo_rdreq <= 0;

            if(irq_en & !dcfifo_rdempty) avs_s0_interrupt <= 1;
            if(~irq_en) avs_s0_interrupt <= 0;
        end
    end

    dcfifo	dcfifo
        (
            .aclr           (reset),

            .wrclk          (dcfifo_wrclk),
            .data           (dcfifo_data),
            .wrreq          (dcfifo_wrreq),
            .wrusedw        (dcfifo_wrusedw),
            .wrempty        (dcfifo_wrempty),
            .wrfull         (dcfifo_wrfull),

            .rdclk          (clk),
            .rdreq          (dcfifo_rdreq),
            .q              (dcfifo_out),
            .rdempty        (dcfifo_rdempty),
            .rdusedw        (dcfifo_rdusedw),
            .rdfull         (dcfifo_rdfull)
        );
    defparam
        dcfifo.lpm_width = FIFO_WIDTH,
        dcfifo.lpm_numwords = FIFO_SIZE,
        dcfifo.lpm_widthu = $clog2(FIFO_SIZE),
        dcfifo.intended_device_family = "Cyclone III", 
        dcfifo.lpm_showahead = "OFF",
        dcfifo.lpm_type = "dcfifo",
        dcfifo.overflow_checking = "ON",
        dcfifo.underflow_checking = "ON",
        dcfifo.use_eab = "ON",
        dcfifo.rdsync_delaypipe = 4,
        dcfifo.wrsync_delaypipe = 4;

endmodule

