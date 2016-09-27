module lcd12864
    (
        // Avalon-MM Slave
        input         csi_clk,
        input         csi_reset_n,
        input         avs_chipselect,
        input [1:0]   avs_address,
        input         avs_write,
        input [31:0]  avs_writedata,
        input         avs_read,
        output [31:0] avs_readdata,  

        // lcd12864 interface
        output reg    lcd_e,
        output reg    lcd_rw, 
        output reg    lcd_rs,
        inout [7:0]   lcd_data_io
    );

    reg  [7:0] lcd_data_o;

    always@(posedge csi_clk, negedge csi_reset_n) begin
        if (!csi_reset_n) begin
            lcd_e      <= 1'b0;
            lcd_rw     <= 1'b0;
            lcd_rs     <= 1'b0;
            lcd_data_o <= 8'b0;
        end
        else if (avs_chipselect & avs_write) begin
            case (avs_address)
                0: lcd_e      <= avs_writedata[0];
                1: lcd_rw     <= avs_writedata[0];
                2: lcd_rs     <= avs_writedata[0];
                3: lcd_data_o <= avs_writedata[7:0];
            endcase
        end
    end

    reg  [7:0] readdata_r;
    wire [7:0] lcd_data_i;

    always@(posedge csi_clk)
        if (avs_chipselect & avs_read) begin
            if (avs_address == 3) readdata_r  <= lcd_data_i;
            else readdata_r  <= 8'b0;
        end
        else readdata_r <= 8'b0;

    assign avs_readdata = {24'b0, readdata_r}; 

    reg lcd_data_o_en;

    always@(posedge csi_clk)
        if (avs_chipselect & avs_write) lcd_data_o_en <= 1'b0;
        else if (avs_chipselect & avs_read) lcd_data_o_en <= 1'b1;

    assign lcd_data_i   = lcd_data_io;
    assign lcd_data_io  = lcd_data_o_en ? 8'bz : lcd_data_o;

endmodule
