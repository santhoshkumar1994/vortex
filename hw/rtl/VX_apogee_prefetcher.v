`include "VX_define.vh"

module VX_apogee_prefetcher #(
    parameter ENTRIES   = 4,
    parameter SIZE      = 10   
) (
    input  wire                     clk,
    input  wire                     valid_in,
    input  wire                     is_dup_in,
    input  wire [`NW_BITS-1:0]      wid_in,
    input  wire [`NUM_THREADS-1:0]  tmask_in,
    input  wire [31:0]              pc_in,
    input  wire [ENTRIES-1:0][31:0] addr_in,
    input  wire [`LSU_BITS-1:0]     type_in,
    input  wire [`NR_BITS-1:0]      rd_in,
    input  wire                     wb_in,
    input  wire [ENTRIES-1:0][31:0] data_in,
    output wire                     valid_out,
    output wire                     is_dup_out,
    output wire [`NW_BITS-1:0]      wid_out,
    output wire [`NUM_THREADS-1:0]  tmask_out,
    output wire [31:0]              pc_out,
    output wire [ENTRIES-1:0][31:0] addr_out,
    output wire [`LSU_BITS-1:0]     type_out,
    output wire [`NR_BITS-1:0]      rd_out,
    output wire                     wb_out,
    output wire [ENTRIES-1:0][31:0] data_out
);

    `UNUSED_VAR(is_dup_in);
    `UNUSED_VAR(full);

    `IGNORE_WARNINGS_BEGIN

    reg         ready_r;
    reg [2:0]   action_in_r;
    reg [71:0]  table_row_in;
    reg [71:0]  table_row_out;
    reg [31:0]  table_addr_in;
    reg [31:0]  new_offset;
    reg [3:0]   num_active_threads;
    
    reg         valid_out_r;
    reg [31:0]  prefetch_addr_r;    
    
    wire        action_out;
    wire        full;
    wire        done;

    VX_table #(
        .N      (SIZE),
        .ADDRW  (32),
        .DATAW  (32 + 32 + 4 + 4)
    ) foa_table (
        .valid      (valid_in),
        .ready      (ready_r),
        .addr_in    (table_addr_in),
        .action_in  (action_in_r),
        .data_in    (table_row_in),
        .action_out (action_out),
        .data_out   (table_row_out),
        .full       (full),
        .done       (done)
    );

    reg [2:0] next_state;
    reg [3:0] iteration;

    `IGNORE_WARNINGS_END

    /*
    States:
    0 -> Idle
    1 -> Check if present
    2 -> Update the offset for the existing entry
    3 -> Iterate over threads
    4 -> Finish and generate the prefetch request    
    */

    // The state numbering is not correct. Work on that.

    always @(clk) begin
        if (clk == 1'b1) begin
            if (valid_in & wb_in) begin
                iteration = 0;
                next_state = 1;
                table_addr_in = pc_in;
                action_in_r = 3'b000;
                ready_r = 1;
            end else begin
                valid_out_r = 0;
            end
        end
    end

    always @(done) begin
        if (done == 1'b1) begin
            ready_r = 0;
            if (next_state == 1) begin
                if (action_out == 1'b1) begin // Already present in table, so get the entry
                    next_state = 2;
                    table_addr_in = pc_in;
                    action_in_r = 3'b100;
                    ready_r = 1;
                end else begin // Entry not in table, so add the entry
                    next_state = 3;
                    table_row_in = {addr_in[iteration], 32'b0, 4'b0, iteration};
                    action_in_r = 3'b001;
                    ready_r = 1;
                end
            end else if (next_state == 2) begin // Compute and update offset
                new_offset = (addr_in[iteration] - table_row_out[71:40]) / ({28'b0, iteration} - {28'b0, table_row_out[3:0]});
                table_row_in = table_row_out;

                next_state = 3;
                if (table_row_out[39:8] == 32'b0) begin // Offset was 0
                    table_row_in[39:8] = new_offset;
                    table_row_in[7:4]  = 4'b1;
                    ready_r = 1;                
                end else begin
                    if (table_row_out[39:8] == new_offset) begin
                        table_row_in[7:4] = table_row_in[7:4] + 1; // Increasing the confidence                                
                    end else begin
                        table_addr_in[7:4] = 4'b0;
                    end

                    ready_r = 1;                
                end
            end else if (next_state == 3) begin // Iterate over threads
                if (iteration == ENTRIES - 1) begin // Last iteration
                    num_active_threads = 0;
                    for (integer i = 0; i < ENTRIES; i++)
                        if (tmask_in[i] == 1'b1)
                            num_active_threads = num_active_threads + 1;

                    next_state = 4;
                    action_in_r = 3'b100;
                    table_addr_in = pc_in;
                    ready_r = 1;
                end else begin
                    iteration = iteration + 1;
                    next_state = 1;
                    table_addr_in = pc_in;
                    action_in_r = 3'b000;
                    ready_r = 1;
                end
            end else if (next_state == 4) begin // Finish and generate the prefetch request
                if (table_row_out[7:4] > 1)
                    prefetch_addr_r = table_row_out[71:40] + table_row_out[39:8] * num_active_threads;
                    valid_out_r = 1;
                next_state = 0;
            end
        end
    end
    
    /*always @(posedge clk) begin
        if (valid_in & wb_in) begin
            for (integer i = 0; i < ENTRIES; i++)
                if (tmask_in[i] == 1'b1) begin
                    table_addr_in = pc_in;
                    action_in_r = 3'b000;
                    ready_r = 1;

                    @(posedge done);
                    ready_r = 0;

                    if (action_out == 1'b1) begin // Entry already present in table
                        action_in_r = 3'b010;
                        ready_r = 1;

                        @(posedge done);
                        ready_r = 0;

                        new_offset = (addr[i] - table_row_out[71:40]) / (i - table_row_out[3:0]);
                        table_row_in = table_row_out;
                        
                        if (table_row_out[39:8] == 32'b0) begin // Offset was 0
                            table_row_in[39:8] = new_offset;
                            table_row_in[7:4]  = 4'b1;
                            ready_r = 1;

                            @(posedge done);
                            ready_r = 0;
                        end else begin
                            if (table_row_out[39:8] == new_offset) begin
                                table_row_in[7:4] = table_row_in[7:4] + 1; // Increasing the confidence                                
                            end else begin
                                table_addr_in[7:4] = 4'b0;
                            end

                            ready_r = 1;
                            @(posedge done);
                            ready_r = 0;
                        end

                    end else begin // Entry not present in table
                        table_row_in = {addr_in, 32'b0, 4'b0, i};
                        action_in_r = 3'b001;
                        ready_r = 1;

                        @(posedge done);
                        ready_r = 0;
                    end
                end

            num_active_threads = 0;
            for (integer i = 0; i < ENTRIES; i++)
                if (tmask_in[i] == 1'b1)
                    num_active_threads = num_active_threads + 1;

            action_in_r = 3'b100;
            table_addr_in = pc_in;
            ready_r = 1;

            @(posedge done);
            ready_r = 0;

            if (table_row_out[7:4] > 1)
                prefetch_addr_r = table_row_out[71:40] + table_row_out[39:8] * num_active_threads;
                valid_out_r = 1;
        end else begin
            valid_out_r = 0;
        end
    end*/

    assign valid_out = valid_out_r & wb_in;
    assign addr_out = {prefetch_addr_r, {(ENTRIES-1){32'b0}}};
    assign tmask_out = {1'b1, {(ENTRIES - 1) {1'b0}}};
    assign pc_out = pc_in;
    assign wid_out = wid_in;
    assign type_out = type_in;
    assign rd_out = rd_in;
    assign wb_out = wb_in;
    assign data_out = data_in;
    assign is_dup_out = 1'b0;

endmodule
