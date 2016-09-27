`include "timescale.v"
`include "defines.v"

//
// STK642 stepper motor driver
//

module motor_driver
    #(
        parameter sys_clk_freq_hz   = 50_000_000,
        parameter motor_clk_freq_hz_max = 16'd 50_000       // value must be casted to 16-bit width
    )
    (
        // internal (system) ports
        input sys_reset,
        input sys_clk,

        input [15:0] v,         // motor speed, [steps/sec], signed
        input [15:0] n,         // number of steps to move
        input enable,           // enable moving
        input [2:0] psc,        // motor step prescaler:
                                //      0: 1/1
                                //      1: 1/2
                                //      2: 1/4
                                //      3: 1/8
                                //      4: 1/16
        input current,          // motor current selection (full/middle)
        input use_sensor,       // move to sensor (in this case "n" value will be ignored)
        input motor_reset,      // motor reset

        output busy,            // motor is moving
        output reg ready,       // moving done (single pulse)
        output reg error,       // error detected while moving

        // external (device) ports
        output reg cwb,         // motor cw/ccw flag
        output clock,           // motor clock
        output reg rst,         // motor reset
        output en,              // motor current enable
        output reg cur,         // motor current selection
        input fault,            // motor fault flag
        input sensor            // sensor input
    );

    // ------------------------------------------------------------------------
    //                          sys_clk signals
    // ------------------------------------------------------------------------
    localparam clkdiv = sys_clk_freq_hz / motor_clk_freq_hz_max - 1;
    localparam clkdiv_width = $clog2(clkdiv);

    reg [15+4:0] num_steps;             // width = 16(n) + 4(psc)
    reg [clkdiv_width-1:0] clkdiv_cnt;
    reg enable_reg;
    reg processing;
    reg direction;
    reg processing_done_reg;
    reg stop_at_sensor;
    reg motor_reset_req;
    reg fault_detected_reg;

    wire [15:0] tick_period;
    wire start = {enable_reg, enable} == 2'b01;



    // ------------------------------------------------------------------------
    //                          motor_clk signals
    // ------------------------------------------------------------------------
    reg motor_clk;
    reg processing_done;
    reg [15+4:0] steps_cnt;         // see "num_steps" definition for details
    reg motor_enable;
    reg fault_detected;
    reg [15:0] motor_clk_cnt;

    wire motor_clk_ref;



    // ------------------------------------------------------------------------
    //                          sys_clk logic
    // ------------------------------------------------------------------------
    assign busy = processing | motor_reset_req;

    always @(posedge sys_clk, posedge sys_reset) begin
        if(sys_reset) begin
            enable_reg <= 0;
            processing <= 0;
            direction <= 0;
            ready <= 0;
            num_steps <= 0;
            processing_done_reg <= 0;
            stop_at_sensor <= 0;
            motor_reset_req <= 0;
            fault_detected_reg <= 0;
            error <= 0;
        end
        else begin
            if(motor_reset) begin
                motor_reset_req <= 1;
            end
            if(start) begin
                if(use_sensor) stop_at_sensor <= 1;
                processing <= 1;
                direction <= v[15];
                num_steps <=    (psc == 0) ? n :
                                (psc == 1) ? n << 1 :
                                (psc == 2) ? n << 2 :
                                (psc == 3) ? n << 3 :
                                (psc == 4) ? n << 4 :
                                0;
            end
            if({processing_done_reg, processing_done} == 2'b01) begin
                processing <= 0;
                motor_reset_req <= 0;
                stop_at_sensor <= 0;
                ready <= 1;
            end
            if(ready) ready <= 0;
            processing_done_reg <= processing_done;
            fault_detected_reg <= fault_detected;
            enable_reg <= enable;
            error <= {fault_detected_reg, fault_detected} == 2'b01;
        end
    end

    always @(posedge sys_clk, posedge sys_reset) begin
        if(sys_reset) begin
            clkdiv_cnt <= 0;
        end
        else begin
            if(clkdiv_cnt == 0) clkdiv_cnt <= clkdiv;
            else clkdiv_cnt <= clkdiv_cnt - 1;
        end
    end

    assign motor_clk_ref = clkdiv_cnt[clkdiv_width-1];

    divider div // calculate ticks_period = motor_clk_freq_hz_max / v
        (
            .reset  (sys_reset),
            .clk    (sys_clk),

            .a      (motor_clk_freq_hz_max),
            .b      ({1'd0, v[14:0]}),
            .r      (tick_period)
        );

    // ------------------------------------------------------------------------
    //                          motor_clk logic
    // ------------------------------------------------------------------------
    always @(posedge motor_clk_ref, posedge sys_reset) begin
        if(sys_reset) begin
            motor_clk <= 0;
            motor_clk_cnt <= 0;
        end
        else begin
            if(motor_clk_cnt == 0) motor_clk_cnt <= tick_period - 1;
            else motor_clk_cnt <= motor_clk_cnt - 1;

            if(motor_clk_cnt >= (tick_period >> 1)) motor_clk <= 1;
            else motor_clk <= 0;
        end
    end

    always @(posedge motor_clk, posedge sys_reset) begin
        if(sys_reset) begin
            steps_cnt <= 0;
            processing_done <= 0;
            motor_enable <= 0;
            cur <= 0;
            cwb <= 0;
            rst <= 1;
            fault_detected <= 0;
        end
        else begin
            if(processing) begin
                if(stop_at_sensor) begin
                    if(sensor) begin
                        motor_enable <= 0;
                        processing_done <= 1;
                    end
                    else begin
                        motor_enable <= 1;
                    end
                end
                else begin
                    if(steps_cnt < num_steps) begin
                        steps_cnt <= steps_cnt + 1;
                        motor_enable <= 1;
                    end
                    else begin
                        steps_cnt <= 0;
                        motor_enable <= 0;
                        processing_done <= 1;
                    end
                end
            end
            if(motor_reset_req) begin
                rst <= 0;
                processing_done <= 1;
            end
            if(fault) begin
                motor_enable <= 0;
                fault_detected <= 1;
                processing_done <= 1;
            end
            if(processing_done) begin
                processing_done <= 0;
                rst <= 1;
            end
            if(fault_detected) fault_detected <= 0;
            cur <= current;
            cwb <= direction;
        end
    end

    assign clock = motor_clk;
    assign en = motor_enable;

endmodule

