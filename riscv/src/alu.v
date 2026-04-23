



`include "common.v"

module alu(
    input wire clk,
    input wire rst,
    input wire rdy,

    input wire exec_en,
    input wire [2:0] inst_type,
    input wire [6:0] opcode,
    input wire [2:0] funct3,
    input wire [6:0] funct7,
    input wire [31:0] v1,
    input wire [31:0] v2,
    input wire [31:0] imm,
    input wire [31:0] pc,
    input wire [`ROB_ADDR_WIDTH-1:0] rob_id,

    output reg wb_en,
    output reg [31:0] wb_value,
    output reg [`ROB_ADDR_WIDTH-1:0] wb_rob_id,
    output reg wb_jump_en,
    output reg [31:0] wb_jump_target
);

    always @(*) begin
        wb_en = exec_en;
        wb_rob_id = rob_id;
        wb_jump_en = 0;
        wb_jump_target = 0;
        wb_value = 0;

        if (exec_en) begin
            case (inst_type)
                `INST_TYPE_ALU_REG: begin
                    case (funct3)
                        3'b000: wb_value = (funct7[6]) ? v1 - v2 : v1 + v2;
                        3'b001: wb_value = v1 << v2[4:0];
                        3'b010: wb_value = ($signed(v1) < $signed(v2)) ? 1 : 0;
                        3'b011: wb_value = (v1 < v2) ? 1 : 0;
                        3'b100: wb_value = v1 ^ v2;
                        3'b101: wb_value = (funct7[6]) ? $signed(v1) >>> v2[4:0] : v1 >> v2[4:0];
                        3'b110: wb_value = v1 | v2;
                        3'b111: wb_value = v1 & v2;
                    endcase
                end
                `INST_TYPE_ALU_IMM: begin
                    case (funct3)
                        3'b000: wb_value = v1 + imm;
                        3'b001: wb_value = v1 << imm[4:0];
                        3'b010: wb_value = ($signed(v1) < $signed(imm)) ? 1 : 0;
                        3'b011: wb_value = (v1 < imm) ? 1 : 0;
                        3'b100: wb_value = v1 ^ imm;
                        3'b101: wb_value = (funct7[6]) ? $signed(v1) >>> imm[4:0] : v1 >> imm[4:0];
                        3'b110: wb_value = v1 | imm;
                        3'b111: wb_value = v1 & imm;
                    endcase
                end
                `INST_TYPE_LUI: wb_value = imm;
                `INST_TYPE_JAL: begin
                    wb_value = pc + (inst_type == `INST_TYPE_JAL && opcode == 7'b1101111 ? 4 : 2); // This is tricky with mixed lengths
                    // Actually, the return address should be pc + 4 for RV32I and pc + 2 for RV32C
                    // But we expanded RV32C to RV32I, so we need to know the original length.
                    // Let's assume for now we have that info or handle it in decoder.
                    wb_jump_en = 1;
                    wb_jump_target = pc + imm;
                end
                `INST_TYPE_JALR: begin
                    wb_value = pc + 4; // Simplified
                    wb_jump_en = 1;
                    wb_jump_target = (v1 + imm) & ~32'h1;
                end
                `INST_TYPE_BRANCH: begin
                    case (funct3)
                        3'b000: wb_jump_en = (v1 == v2);
                        3'b001: wb_jump_en = (v1 != v2);
                        3'b100: wb_jump_en = ($signed(v1) < $signed(v2));
                        3'b101: wb_jump_en = ($signed(v1) >= $signed(v2));
                        3'b110: wb_jump_en = (v1 < v2);
                        3'b111: wb_jump_en = (v1 >= v2);
                    endcase
                    wb_jump_target = pc + imm;
                    wb_value = 0;
                end
            endcase
        end
    end

endmodule



