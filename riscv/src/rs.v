


`include "common.v"

module rs(
    input wire clk,
    input wire rst,
    input wire rdy,

    // From Decoder (Issue)
    input wire issue_en,
    input wire [2:0] issue_inst_type,
    input wire [6:0] issue_opcode,
    input wire [2:0] issue_funct3,
    input wire [6:0] issue_funct7,
    input wire [31:0] issue_imm,
    input wire [31:0] issue_pc,
    input wire [`ROB_ADDR_WIDTH-1:0] issue_rob_id,
    
    input wire [31:0] rs1_val,
    input wire rs1_ready,
    input wire [`ROB_ADDR_WIDTH-1:0] rs1_rob_id,
    
    input wire [31:0] rs2_val,
    input wire rs2_ready,
    input wire [`ROB_ADDR_WIDTH-1:0] rs2_rob_id,

    // From CDB (Common Data Bus)
    input wire cdb_en,
    input wire [`ROB_ADDR_WIDTH-1:0] cdb_rob_id,
    input wire [31:0] cdb_value,

    // To Execution Unit
    output reg exec_en,
    output reg [2:0] exec_inst_type,
    output reg [6:0] exec_opcode,
    output reg [2:0] exec_funct3,
    output reg [6:0] exec_funct7,
    output reg [31:0] exec_v1,
    output reg [31:0] exec_v2,
    output reg [31:0] exec_imm,
    output reg [31:0] exec_pc,
    output reg [`ROB_ADDR_WIDTH-1:0] exec_rob_id,

    output wire rs_full
);

    reg busy [`RS_SIZE-1:0];
    reg [2:0] inst_type [`RS_SIZE-1:0];
    reg [6:0] opcode [`RS_SIZE-1:0];
    reg [2:0] funct3 [`RS_SIZE-1:0];
    reg [6:0] funct7 [`RS_SIZE-1:0];
    reg [31:0] imm [`RS_SIZE-1:0];
    reg [31:0] pc [`RS_SIZE-1:0];
    reg [`ROB_ADDR_WIDTH-1:0] rob_id [`RS_SIZE-1:0];

    reg [31:0] v1 [`RS_SIZE-1:0];
    reg [31:0] v2 [`RS_SIZE-1:0];
    reg [`ROB_ADDR_WIDTH-1:0] q1 [`RS_SIZE-1:0];
    reg [`ROB_ADDR_WIDTH-1:0] q2 [`RS_SIZE-1:0];
    reg r1 [`RS_SIZE-1:0];
    reg r2 [`RS_SIZE-1:0];

    integer i;
    reg [4:0] free_idx;
    reg [4:0] ready_idx;
    reg found_free;
    reg found_ready;

    assign rs_full = (free_idx == `RS_SIZE);

    always @(*) begin
        free_idx = `RS_SIZE;
        found_free = 0;
        for (i = 0; i < `RS_SIZE; i = i + 1) begin
            if (!busy[i] && !found_free) begin
                free_idx = i;
                found_free = 1;
            end
        end

        ready_idx = `RS_SIZE;
        found_ready = 0;
        for (i = 0; i < `RS_SIZE; i = i + 1) begin
            if (busy[i] && r1[i] && r2[i] && !found_ready) begin
                ready_idx = i;
                found_ready = 1;
            end
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < `RS_SIZE; i = i + 1) busy[i] <= 0;
            exec_en <= 0;
        end else if (rdy) begin
            // CDB Monitoring
            if (cdb_en) begin
                for (i = 0; i < `RS_SIZE; i = i + 1) begin
                    if (busy[i]) begin
                        if (!r1[i] && q1[i] == cdb_rob_id) begin
                            v1[i] <= cdb_value;
                            r1[i] <= 1;
                        end
                        if (!r2[i] && q2[i] == cdb_rob_id) begin
                            v2[i] <= cdb_value;
                            r2[i] <= 1;
                        end
                    end
                end
            end

            // Issue
            if (issue_en && !rs_full) begin
                busy[free_idx] <= 1;
                inst_type[free_idx] <= issue_inst_type;
                opcode[free_idx] <= issue_opcode;
                funct3[free_idx] <= issue_funct3;
                funct7[free_idx] <= issue_funct7;
                imm[free_idx] <= issue_imm;
                pc[free_idx] <= issue_pc;
                rob_id[free_idx] <= issue_rob_id;

                if (rs1_ready) begin
                    v1[free_idx] <= rs1_val;
                    r1[free_idx] <= 1;
                end else if (cdb_en && rs1_rob_id == cdb_rob_id) begin
                    v1[free_idx] <= cdb_value;
                    r1[free_idx] <= 1;
                end else begin
                    q1[free_idx] <= rs1_rob_id;
                    r1[free_idx] <= 0;
                end

                if (rs2_ready) begin
                    v2[free_idx] <= rs2_val;
                    r2[free_idx] <= 1;
                end else if (cdb_en && rs2_rob_id == cdb_rob_id) begin
                    v2[free_idx] <= cdb_value;
                    r2[free_idx] <= 1;
                end else begin
                    q2[free_idx] <= rs2_rob_id;
                    r2[free_idx] <= 0;
                end
            end

            // Dispatch to Execution Unit
            if (found_ready) begin
                exec_en <= 1;
                exec_inst_type <= inst_type[ready_idx];
                exec_opcode <= opcode[ready_idx];
                exec_funct3 <= funct3[ready_idx];
                exec_funct7 <= funct7[ready_idx];
                exec_v1 <= v1[ready_idx];
                exec_v2 <= v2[ready_idx];
                exec_imm <= imm[ready_idx];
                exec_pc <= pc[ready_idx];
                exec_rob_id <= rob_id[ready_idx];
                busy[ready_idx] <= 0;
            end else begin
                exec_en <= 0;
            end
        end
    end

endmodule


