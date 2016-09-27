module keypad_scanner
    #(
        parameter keypad_rows = 4,                                      // number of keypad rows
        parameter keypad_cols = 4                                       // number of keypad cols
    )
    (
        // clock interface
        input           csi_clock_clk,
        input           csi_clock_reset,

        // slave interface
        input              avs_s0_write,
        input              avs_s0_read,
        input      [1:0]   avs_s0_address,
        input      [31:0]  avs_s0_writedata,
        output reg [31:0]  avs_s0_readdata,
        output reg         avs_s0_interrupt,

        output reg [keypad_rows - 1 : 0] rows,                          // to keypad rows
        input      [keypad_cols - 1 : 0] cols                           // from keypad columns
    );

    reg [keypad_rows * keypad_cols - 1 : 0] keypad_state;
    reg keypad_scan_complete;
    reg [keypad_rows * keypad_cols - 1 : 0] last_scan_result;
    reg [31:0] scan_period;
    reg [31:0] scan_cnt;
    reg [$clog2(keypad_rows) - 1 : 0] row;
    reg irq_en;
    integer i;

    wire reset = csi_clock_reset;
    wire clk = csi_clock_clk;

    localparam sr_msb = keypad_rows * keypad_cols - 1;

    always @(posedge clk, posedge reset) begin
        if(reset) begin
            keypad_state <= 0;
            keypad_scan_complete <= 0;
            scan_cnt <= 0;
            row <= 0;
            last_scan_result <= 0;
            avs_s0_readdata <= 0;
            avs_s0_interrupt <= 0;
            irq_en <= 0;
            scan_period <= 0;
        end
        else begin
            if(scan_cnt < scan_period-1) scan_cnt <= scan_cnt + 1;
            else begin
                keypad_state <= {cols, keypad_state[sr_msb -: sr_msb - keypad_cols + 1]};
                if(row < keypad_rows-1) row <= row + 1;
                else begin
                    row <= 0;
                    keypad_scan_complete <= 1;
                end
                scan_cnt <= 0;
            end

            if(keypad_scan_complete) keypad_scan_complete <= 0;

            last_scan_result <= keypad_scan_complete ? keypad_state : last_scan_result;
            if(avs_s0_write) begin
                case(avs_s0_address)
                    0: irq_en <= avs_s0_writedata;
                    2: scan_period <= avs_s0_writedata;
                endcase
            end
            if(avs_s0_read) begin
                case(avs_s0_address)
                    0: avs_s0_readdata <= irq_en;
                    1: avs_s0_readdata <= keypad_state;
                endcase
            end

            if(irq_en & keypad_scan_complete & ((keypad_state != last_scan_result) & (keypad_state != 0))) avs_s0_interrupt <= 1;
            if(~irq_en) avs_s0_interrupt <= 0;
        end
    end

    always @(*) for(i = 0; i < keypad_rows; i = i + 1) rows[i] <= (i == row) ? 1'b0 : 1'bz;

endmodule

