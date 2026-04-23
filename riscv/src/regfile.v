


`include "common.v"

module regfile(
    input wire clk,
    input wire rst,
    input wire rdy,

    // From Decoder (Read)
    input wire [4:0] rs1,
    input wire [4:0] rs2,
    output wire [31:0] rs1_val,
    output wire [31:0] rs2_val,
    output wire [`ROB_ADDR_WIDTH-1:0] rs1_rob_id,
    output wire [`ROB_ADDR_WIDTH-1:0] rs2_rob_id,
    output wire rs1_ready,
    output wire rs2_ready,

    // From Decoder (Issue/Rename)
    input wire issue_en,
    input wire [4:0] issue_rd,
    input wire [`ROB_ADDR_WIDTH-1:0] issue_rob_id,

    // From ROB (Commit)
    input wire commit_en,
    input wire [4:0] commit_rd,
    input wire [31:0] commit_value,
    input wire [`ROB_ADDR_WIDTH-1:0] commit_rob_id
);

    reg [31:0] regs [31:0];
    reg [`ROB_ADDR_WIDTH-1:0] rat [31:0];
    reg busy [31:0];

    assign rs1_val = regs[rs1];
    assign rs2_val = regs[rs2];
    assign rs1_rob_id = rat[rs1];
    assign rs2_rob_id = rat[rs2];
    assign rs1_ready = !busy[rs1];
    assign rs2_ready = !busy[rs2];

    always @(posedge clk) begin
        if (rst) begin
            for (integer i = 0; i < 32; i = i + 1) begin
                regs[i] <= 0;
                busy[i] <= 0;
            end
        end else if (rdy) begin
            // Commit
            if (commit_en && commit_rd != 0) begin
                regs[commit_rd] <= commit_value;
                if (busy[commit_rd] && rat[commit_rd] == commit_rob_id) begin
                    busy[commit_rd] <= 0;
                end
            end

            // Issue
            if (issue_en && issue_rd != 0) begin
                rat[issue_rd] <= issue_rob_id;
                busy[issue_rd] <= 1;
            end
        end
    end

endmodule


