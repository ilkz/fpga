`include "timescale.v"

module data_packer
    #(
        parameter nports = 8,
        parameter port_sizes = {8'd6, 8'd1, 8'd8, 8'd4, 8'd2, 8'd3, 8'd2, 8'd1},
        parameter max_port_size = 8 // max port size, bytes
    )
    (
        datain,
        port_ready,
        reset,
        clk,
        mode,       // 0 - forced mode (any port_ready[*] signal raise serialization),
                    // 1 - wait mode (packer will be wait for all port_ready[*] signals before serialization,
                    //     port_ready[*] signals can come in any order and time)
        byte,
        byte_ready,
        data_packed
    );

    function [max_port_size*nports*8-1 : 0] get_port_map (input integer nports);
        integer i, tmp;
        begin
            tmp = 0;
            get_port_map = 1'b0; // unsigned extend
            for (i = 0; i < nports; i = i + 1) begin
                get_port_map[i*8 +: 8] = tmp;
                tmp = tmp + port_sizes[i*8 +: 8];
            end
        end
    endfunction

    function integer get_ports_list (input integer nports);
        integer i;
        begin
            get_ports_list = 0;
            for (i = 0; i < nports; i = i + 1) get_ports_list = get_ports_list + port_sizes[i*8 +: 8];
        end
    endfunction

    localparam port_map         = get_port_map(nports);
    localparam total_bits_len   = get_ports_list(nports) * 8;

    input [total_bits_len - 1 : 0] datain;
    input [nports - 1 : 0] port_ready;
    input reset;
    input clk;
    input mode;

    output reg [7:0] byte;
    output reg byte_ready;
    output reg data_packed;

    reg [total_bits_len - 1 : 0] buffer;
    reg [nports - 1 : 0] ports_stored;
    reg [$clog2(max_port_size * nports) : 0] byte_cnt, offset;

    wire all_ports_stored = &ports_stored;
    wire serialize_en = byte_cnt > 0;
    wire serialization_done = {byte_ready, serialize_en} == 2'b10;

    integer n;
    genvar i, j;

    generate
        for(i = 0; i < nports; i = i + 1)
            begin: port
                localparam port_pos  = port_map[i*8 +: 8] * 8;
                localparam port_size = port_sizes[i*8 +: 8] * 8;

                always @(posedge clk, posedge reset) begin
                    if(reset) begin
                        buffer[port_pos +: port_size] <= 0;
                        ports_stored[i] <= 0;
                    end
                    else begin
                        if(port_ready[i]) begin
                            buffer[port_pos +: port_size] <= datain[port_pos +: port_size];
                            ports_stored[i] <= 1;
                        end
                        if(byte_ready) ports_stored[i] <= 0;
                        if(serialization_done) buffer[port_pos +: port_size] <= 0;
                    end
                end
            end
    endgenerate

    always @(posedge clk, posedge reset) begin
        if(reset) begin
            byte <= 0;
            byte_ready <= 0;
            data_packed <= 0;
            byte_cnt <= 0;
            offset <= 0;
        end
        else begin
            for(n = 0; n < nports; n = n + 1) begin
                if(port_ready[n] & !mode) begin
                    byte_cnt <= port_sizes[n*8 +: 8];
                    offset <= port_map[n*8 +: 8];
                end
            end

            if(mode & all_ports_stored) begin
                byte_cnt <= (total_bits_len >> 3);
                offset <= 0;
            end
            if(byte_cnt > 0) byte_cnt <= byte_cnt - 1;

            byte <= serialize_en ? buffer[((byte_cnt + offset - 1) * 8) +: 8] : byte;
            byte_ready <= serialize_en;
            data_packed <= serialization_done;
        end
    end

endmodule