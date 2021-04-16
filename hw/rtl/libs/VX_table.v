`include "VX_platform.vh"

module VX_table #(
    parameter N     = 4,
    parameter ADDRW = 4,
    parameter DATAW = 4
) (
    input wire valid,
    input wire ready,

    input  wire [ADDRW-1:0]     addr_in,
    input  wire [2:0]           action_in,
    input  wire [DATAW-1:0]     data_in,
    output wire                 action_out,
    output wire [DATAW-1:0]     data_out,

    output wire full,
    output wire done
);

    reg [N-1:0][DATAW-1:0] row_contents;
    reg [N-1:0] row_valid;
    
    reg action_out_r;
    reg done_r;
    reg full_r;
    reg sim_break_r;
    reg [DATAW-1:0] data_out_r;

    initial begin
        full_r = 1'b0;
        done_r = 1'b0;
        row_valid = 0;
        sim_break_r = 1'b0;
    end

    always @(posedge ready) begin
        if (valid) begin
            // action == 000 -> is_present
            // action == 001 -> add
            // action == 010 -> update
            // action == 011 -> remove
            // action == 100 -> get row
            if (action_in == 3'b000) begin
                action_out_r = 1'b0;
                for (integer i = 0; i < N; i++)
                    if (row_valid[i] == 1'b1)
                        if (row_contents[i] == addr_in)
                            action_out_r = 1'b1;
                done_r = 1'b1;
            end

            // Code for add
            if (action_in == 3'b001) begin
                for (integer i = 0; i < N; i++)
                    if (~sim_break_r)
                        if (row_valid[i] == 1'b0) begin
                            row_contents[i] = data_in;
                            row_valid[i] = 1'b1;
                            sim_break_r = 1'b1;
                        end
                sim_break_r = 1'b0;

                // Checking if the table is full
                for (integer i = 0; i < N; i++)
                    if (~sim_break_r)
                        if (row_valid[i] == 1'b0)
                            sim_break_r = 1'b1;

                full_r = ~sim_break_r;
                sim_break_r = 1'b0;
                done_r = 1'b1;
            end

            // Code for udpate
            if (action_in == 3'b010) begin
                for (integer i = 0; i < N; i++)
                    if (~sim_break_r)
                        if (row_valid[i] == 1'b1)
                            if (row_contents[i] == addr_in) begin
                                row_contents[i] = data_in;
                                sim_break_r = 1'b1;
                            end
                sim_break_r = 1'b0;
                done_r = 1'b1;
            end

            // Code for remove
            if (action_in == 3'b011) begin
                for (integer i = 0; i < N; i++)
                    if (~sim_break_r)
                        if (row_valid[i] == 1'b1)
                            if (row_contents[i] == addr_in) begin
                                row_valid[i] = 1'b0;
                                sim_break_r = 1'b1;
                            end 
                sim_break_r = 1'b0;
                full_r = 1'b0;
                done_r = 1'b1;
            end

            // Code for retrieval
            if (action_in == 3'b100) begin
                for (integer i = 0; i < N; i++)
                    if (~sim_break_r)
                        if (row_valid[i] == 1'b1)
                            if (row_contents[i] == addr_in) begin
                                data_out_r = row_contents[i];
                                sim_break_r = 1'b1;
                            end
                sim_break_r = 1'b0;
                done_r = 1'b1;
            end
        end
    end

    assign action_out = action_out_r;
    assign done = done_r;
    assign data_out = data_out_r;
    assign full = full_r;

endmodule