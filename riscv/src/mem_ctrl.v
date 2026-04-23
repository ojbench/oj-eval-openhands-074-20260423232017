
`include "common.v"

module mem_ctrl(
    input wire clk,
    input wire rst,
    input wire rdy,

    // From Ifetch
    input wire if_en,
    input wire [31:0] if_addr,
    output reg [7:0] if_data,
    output reg if_done,

    // From LSB
    input wire lsb_en,
    input wire lsb_wr,
    input wire [31:0] lsb_addr,
    input wire [7:0] lsb_din,
    output reg [7:0] lsb_dout,
    output reg lsb_done,

    // To RAM
    output reg [31:0] mem_a,
    output reg [7:0] mem_dout,
    output reg mem_wr,
    input wire [7:0] mem_din
);

    // Simple arbitration: LSB has priority over Ifetch
    always @(*) begin
        if (lsb_en) begin
            mem_a = lsb_addr;
            mem_dout = lsb_din;
            mem_wr = lsb_wr;
            lsb_dout = mem_din;
            lsb_done = 1'b1; // In this simple model, it's done immediately
            if_done = 1'b0;
            if_data = 8'h0;
        end else if (if_en) begin
            mem_a = if_addr;
            mem_dout = 8'h0;
            mem_wr = 1'b0;
            if_data = mem_din;
            if_done = 1'b1;
            lsb_done = 1'b0;
            lsb_dout = 8'h0;
        end else begin
            mem_a = 32'h0;
            mem_dout = 8'h0;
            mem_wr = 1'b0;
            if_done = 1'b0;
            if_data = 8'h0;
            lsb_done = 1'b0;
            lsb_dout = 8'h0;
        end
    end

endmodule
