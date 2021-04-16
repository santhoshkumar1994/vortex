`include "VX_define.vh"

module VX_next_line_prefetcher #(
    parameter ENTRIES = 4
) (
    input  wire                         valid,
    input  wire                         wb,
    input  wire [ENTRIES - 1:0][31:0]   addr_in,
    output wire                         prefetch_valid,
    output wire [ENTRIES - 1:0][31:0]   addr_out 
);

    for (genvar i = 0; i < ENTRIES; i++) begin
        assign addr_out[i] = addr_in[i] + `DCACHE_LINE_SIZE;
    end

    assign prefetch_valid = wb & valid;

endmodule