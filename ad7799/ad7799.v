`include "timescale.v"

module ad7799
    (
        input reset,
        input sys_clk,
        input phy_clk,

        input rdreq,
        input wrreq,
        input [2:0] rs,
        input [23:0] din,

        input reset_req,        // reset request
        input single_conv_req,  // single conversion request
        input cont_conv_req,    // continuous conversion request
        input conv_mode,        // continuous read mode: 0 - request mode, 1 - automatic mode

        output [23:0] dout,
        (*noprune, preserve*) output reg ready,
        (*noprune, preserve*) output reg busy,

        output phy_sclk,
        output reg phy_csn,
        output reg phy_din,
        input phy_dout
    );

    localparam SIZE_8BIT = 5'd7;
    localparam SIZE_16BIT = 5'd15;
    localparam SIZE_24BIT = 5'd23;
    localparam SIZE_32BIT = 5'd31;

    localparam AD_COMM_REG = 3'd0;     // during write
    localparam AD_STATUS_REG = 3'd0;   // during read
    localparam AD_MODE_REG = 3'd1;
    localparam AD_CONFIG_REG = 3'd2;
    localparam AD_DATA_REG = 3'd3;
    localparam AD_ID_REG = 3'd4;
    localparam AD_IO_REG = 3'd5;
    localparam AD_OFFSET_REG = 3'd6;
    localparam AD_FS_REG = 3'd7;
    
    localparam ST_FREE          = 0;
    localparam ST_SHIFT_BITS    = 1;
    localparam ST_WAIT_RDY      = 2;
    localparam ST_DUMMY_CYCLE   = 3;

    reg [2:0] state;
    reg [4:0] bit_cnt, bit_cnt_pending;
    reg [31:0] comm_reg;
    reg [23:0] txbuf;
    (*noprune, preserve*) reg [23:0] rxbuf;
    reg select_buf;
    reg is_rdreq;
    reg conv_mode_reg;
    reg single_conv_pending;
    reg cread_enabled;
    reg phy_sclk_en;
    reg rxbuf_shift_en;
    reg wait_for_ready;
    reg is_bits_shifting;
    reg phy_dout_reg;

    wire ready_for_rx = select_buf & is_rdreq;

    always @(posedge phy_clk, posedge reset) begin
        if(reset) begin
            ready <= 0;
            busy <= 0;
            phy_din <= 0;
            phy_csn <= 1;
            state <= ST_FREE;
            bit_cnt <= 0;
            bit_cnt_pending <= 0;
            comm_reg <= 0;
            txbuf <= 0;
            select_buf <= 0;
            is_rdreq <= 0;
            phy_sclk_en <= 0;
            rxbuf_shift_en <= 0;
            single_conv_pending <= 0;
            conv_mode_reg <= 0;
            cread_enabled <= 0;

            wait_for_ready <= 0;
            is_bits_shifting <= 0;
        end
        else begin
            case (state)
                ST_FREE:
                    begin
                        if(wrreq | rdreq | single_conv_req | cont_conv_req | reset_req) begin
                            busy <= 1;

                             // latch inputs to flags
                            is_rdreq <= rdreq;
                            single_conv_pending <= single_conv_req;
                            conv_mode_reg <= conv_mode;
                            cread_enabled <= conv_mode;

                            if(reset_req) begin
                                comm_reg <= {32'hFFFFFFFF};
                                bit_cnt <= SIZE_32BIT;
                            end
                            else begin
                                comm_reg <= {24'd0, 1'b0, rdreq ? 1'b1 : 1'b0, (wrreq | rdreq) ? rs : 3'd1, 3'd0};
                                bit_cnt <= SIZE_8BIT;
                            end

                            if(wrreq | rdreq)           txbuf[23:0] <= din;
                            else if(single_conv_req)    txbuf[15:0] <= {12'h300, din[3:0]};    // single conversion mode, user update rate din[3:0]
                            else if(cont_conv_req)      txbuf[15:0] <= {12'h100, din[3:0]};    // continuous conversion mode, user update rate din[3:0]

                            if(wrreq | rdreq) begin
                                case(rs)
                                    AD_COMM_REG, AD_STATUS_REG, AD_ID_REG, AD_IO_REG:   bit_cnt_pending <= SIZE_8BIT;
                                    AD_MODE_REG, AD_CONFIG_REG:                         bit_cnt_pending <= SIZE_16BIT;
                                    AD_DATA_REG, AD_OFFSET_REG, AD_FS_REG:              bit_cnt_pending <= SIZE_24BIT;
                                endcase
                            end
                            else if(single_conv_req | cont_conv_req) bit_cnt_pending <= SIZE_16BIT;

                            is_bits_shifting <= 1;
                            state <= ST_SHIFT_BITS;
                        end
                    end

                ST_SHIFT_BITS:
                    begin
                        if(bit_cnt == 0) begin
                            if(bit_cnt_pending > 0) begin
                                select_buf <= 1;
                                bit_cnt <= bit_cnt_pending;
                                bit_cnt_pending <= 0;
                            end
                            else begin
                                if(single_conv_pending | (cont_conv_req & !conv_mode_reg)) begin
                                    is_bits_shifting <= 0;
                                    wait_for_ready <= 1;
                                    state <= ST_DUMMY_CYCLE; //ST_WAIT_RDY; // go to dummy cycle for compensate phy_dout input register latency
                                end
                                else if(cont_conv_req & conv_mode_reg) begin // enter to cread mode
                                    comm_reg <= {24'd0, 8'h5C}; // cread = 1
                                    bit_cnt <= SIZE_8BIT;
                                    conv_mode_reg <= 0;
                                end
                                else begin
                                    busy <= 0;
                                    is_bits_shifting <= 0;
                                    state <= ST_FREE;
                                end
                                select_buf <= 0;
                                is_rdreq <= 0;
                            end
                        end
                        else bit_cnt <= bit_cnt - 1;
                    end

                ST_WAIT_RDY:
                    begin
                        if(!phy_dout_reg) begin
                            comm_reg <= {24'd0, 8'h58}; // select data register (also is the command for exit from cread mode)
                            bit_cnt <= SIZE_8BIT;
                            if(single_conv_pending | cont_conv_req) begin
                                bit_cnt_pending <= SIZE_24BIT;
                                is_rdreq <= 1;
                            end
                            single_conv_pending <= 0;
                            is_bits_shifting <= 1;
                            wait_for_ready <= 0;
                            state <= ST_SHIFT_BITS;
                        end
                        else if(!single_conv_pending & !cont_conv_req & !cread_enabled) begin
                            busy <= 0;
                            wait_for_ready <= 0;
                            state <= ST_FREE;
                        end
                    end

                ST_DUMMY_CYCLE:
                    begin
                        state <= ST_WAIT_RDY;
                    end
            endcase

            rxbuf_shift_en <= ready_for_rx;
            phy_sclk_en <= ~is_bits_shifting;
            phy_csn <= ~(is_bits_shifting | wait_for_ready);
            phy_din <= is_bits_shifting ? (select_buf ? (is_rdreq ? 1'b1 : txbuf[bit_cnt]) : comm_reg[bit_cnt]) : 1'b1;
            ready <= {rxbuf_shift_en, ready_for_rx} == 2'b10;
        end
    end

    wire phy_clkn = ~phy_clk;

    always @(posedge phy_clkn, posedge reset) begin
        if(reset) phy_dout_reg <= 0;
        else phy_dout_reg <= phy_dout;
    end

    always @(posedge phy_clk, posedge reset) begin
        if(reset) rxbuf <= 0;
        else rxbuf <= rxbuf_shift_en ? {rxbuf[22:0], phy_dout_reg} : rxbuf;
    end

    assign dout = rxbuf;
    assign phy_sclk = phy_sclk_en ? 1'b0 : ~phy_clk;

endmodule

