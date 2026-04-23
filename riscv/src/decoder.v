

`include "common.v"

module decoder(
    input wire [31:0] inst,
    input wire [31:0] inst_pc,
    input wire inst_is_compressed,

    output reg [31:0] decoded_inst, // Expanded to 32-bit RV32I
    output reg [31:0] decoded_pc,
    output reg [4:0] rs1,
    output reg [4:0] rs2,
    output reg [4:0] rd,
    output reg [31:0] imm,
    output reg [2:0] inst_type,
    output reg [6:0] opcode,
    output reg [2:0] funct3,
    output reg [6:0] funct7
);

    always @(*) begin
        decoded_pc = inst_pc;
        if (inst_is_compressed) begin
            // RV32C to RV32I expansion
            case (inst[1:0])
                2'b00: begin // Quadrant 0
                    case (inst[15:13])
                        3'b000: begin // C.ADDI4SPN -> addi rd', x2, nzuimm
                            inst_type = `INST_TYPE_ALU_IMM;
                            rd = {2'b01, inst[4:2]};
                            rs1 = 5'd2;
                            rs2 = 5'd0;
                            imm = {22'b0, inst[10:7], inst[12:11], inst[5], inst[6], 2'b00};
                            opcode = 7'b0010011;
                            funct3 = 3'b000;
                            funct7 = 7'b0;
                        end
                        3'b010: begin // C.LW -> lw rd', offset(rs1')
                            inst_type = `INST_TYPE_LOAD;
                            rd = {2'b01, inst[4:2]};
                            rs1 = {2'b01, inst[9:7]};
                            rs2 = 5'd0;
                            imm = {25'b0, inst[5], inst[12:10], inst[6], 2'b00};
                            opcode = 7'b0000011;
                            funct3 = 3'b010;
                            funct7 = 7'b0;
                        end
                        3'b110: begin // C.SW -> sw rs2', offset(rs1')
                            inst_type = `INST_TYPE_STORE;
                            rd = 5'd0;
                            rs1 = {2'b01, inst[9:7]};
                            rs2 = {2'b01, inst[4:2]};
                            imm = {25'b0, inst[5], inst[12:10], inst[6], 2'b00};
                            opcode = 7'b0100011;
                            funct3 = 3'b010;
                            funct7 = 7'b0;
                        end
                        default: begin
                            opcode = 7'b0;
                        end
                    endcase
                end
                2'b01: begin // Quadrant 1
                    case (inst[15:13])
                        3'b000: begin // C.NOP / C.ADDI
                            if (inst[11:7] == 5'b0 && inst[12] == 1'b0 && inst[6:2] == 5'b0) begin
                                // C.NOP
                                inst_type = `INST_TYPE_ALU_IMM;
                                rd = 5'd0; rs1 = 5'd0; rs2 = 5'd0; imm = 32'b0;
                                opcode = 7'b0010011; funct3 = 3'b000; funct7 = 7'b0;
                            end else begin
                                // C.ADDI
                                inst_type = `INST_TYPE_ALU_IMM;
                                rd = inst[11:7]; rs1 = inst[11:7]; rs2 = 5'd0;
                                imm = {{27{inst[12]}}, inst[6:2]};
                                opcode = 7'b0010011; funct3 = 3'b000; funct7 = 7'b0;
                            end
                        end
                        3'b001: begin // C.JAL (RV32C only) / C.ADDIW (RV64C only)
                            inst_type = `INST_TYPE_JAL;
                            rd = 5'd1; rs1 = 5'd0; rs2 = 5'd0;
                            imm = {{21{inst[12]}}, inst[8], inst[10:9], inst[6], inst[7], inst[2], inst[11], inst[5:3], 1'b0};
                            opcode = 7'b1101111; funct3 = 3'b000; funct7 = 7'b0;
                        end
                        3'b010: begin // C.LI
                            inst_type = `INST_TYPE_ALU_IMM;
                            rd = inst[11:7]; rs1 = 5'd0; rs2 = 5'd0;
                            imm = {{27{inst[12]}}, inst[6:2]};
                            opcode = 7'b0010011; funct3 = 3'b000; funct7 = 7'b0;
                        end
                        3'b011: begin
                            if (inst[11:7] == 5'd2) begin // C.ADDI16SP
                                inst_type = `INST_TYPE_ALU_IMM;
                                rd = 5'd2; rs1 = 5'd2; rs2 = 5'd0;
                                imm = {{23{inst[12]}}, inst[4:3], inst[5], inst[2], inst[6], 4'b0};
                                opcode = 7'b0010011; funct3 = 3'b000; funct7 = 7'b0;
                            end else begin // C.LUI
                                inst_type = `INST_TYPE_LUI;
                                rd = inst[11:7]; rs1 = 5'd0; rs2 = 5'd0;
                                imm = {{15{inst[12]}}, inst[6:2], 12'b0};
                                opcode = 7'b0110111; funct3 = 3'b000; funct7 = 7'b0;
                            end
                        end
                        3'b100: begin
                            case (inst[11:10])
                                2'b00: begin // C.SRLI
                                    inst_type = `INST_TYPE_ALU_IMM;
                                    rd = {2'b01, inst[9:7]}; rs1 = {2'b01, inst[9:7]}; rs2 = 5'd0;
                                    imm = {27'b0, inst[6:2]};
                                    opcode = 7'b0010011; funct3 = 3'b101; funct7 = 7'b0000000;
                                end
                                2'b01: begin // C.SRAI
                                    inst_type = `INST_TYPE_ALU_IMM;
                                    rd = {2'b01, inst[9:7]}; rs1 = {2'b01, inst[9:7]}; rs2 = 5'd0;
                                    imm = {27'b0, inst[6:2]};
                                    opcode = 7'b0010011; funct3 = 3'b101; funct7 = 7'b0100000;
                                end
                                2'b10: begin // C.ANDI
                                    inst_type = `INST_TYPE_ALU_IMM;
                                    rd = {2'b01, inst[9:7]}; rs1 = {2'b01, inst[9:7]}; rs2 = 5'd0;
                                    imm = {{27{inst[12]}}, inst[6:2]};
                                    opcode = 7'b0010011; funct3 = 3'b111; funct7 = 7'b0;
                                end
                                2'b11: begin
                                    rd = {2'b01, inst[9:7]}; rs1 = {2'b01, inst[9:7]}; rs2 = {2'b01, inst[4:2]};
                                    imm = 32'b0; opcode = 7'b0110011; funct7 = 7'b0;
                                    case ({inst[12], inst[6:5]})
                                        3'b000: begin // C.SUB
                                            inst_type = `INST_TYPE_ALU_REG; funct3 = 3'b000; funct7 = 7'b0100000;
                                        end
                                        3'b001: begin // C.XOR
                                            inst_type = `INST_TYPE_ALU_REG; funct3 = 3'b100;
                                        end
                                        3'b010: begin // C.OR
                                            inst_type = `INST_TYPE_ALU_REG; funct3 = 3'b110;
                                        end
                                        3'b011: begin // C.AND
                                            inst_type = `INST_TYPE_ALU_REG; funct3 = 3'b111;
                                        end
                                        default: opcode = 7'b0;
                                    endcase
                                end
                            endcase
                        end
                        3'b101: begin // C.J
                            inst_type = `INST_TYPE_JAL;
                            rd = 5'd0; rs1 = 5'd0; rs2 = 5'd0;
                            imm = {{21{inst[12]}}, inst[8], inst[10:9], inst[6], inst[7], inst[2], inst[11], inst[5:3], 1'b0};
                            opcode = 7'b1101111; funct3 = 3'b000; funct7 = 7'b0;
                        end
                        3'b110: begin // C.BEQZ
                            inst_type = `INST_TYPE_BRANCH;
                            rd = 5'd0; rs1 = {2'b01, inst[9:7]}; rs2 = 5'd0;
                            imm = {{24{inst[12]}}, inst[6:5], inst[2], inst[11:10], inst[4:3], 1'b0};
                            opcode = 7'b1100011; funct3 = 3'b000; funct7 = 7'b0;
                        end
                        3'b111: begin // C.BNEZ
                            inst_type = `INST_TYPE_BRANCH;
                            rd = 5'd0; rs1 = {2'b01, inst[9:7]}; rs2 = 5'd0;
                            imm = {{24{inst[12]}}, inst[6:5], inst[2], inst[11:10], inst[4:3], 1'b0};
                            opcode = 7'b1100011; funct3 = 3'b001; funct7 = 7'b0;
                        end
                        default: opcode = 7'b0;
                    endcase
                end
                2'b10: begin // Quadrant 2
                    case (inst[15:13])
                        3'b000: begin // C.SLLI
                            inst_type = `INST_TYPE_ALU_IMM;
                            rd = inst[11:7]; rs1 = inst[11:7]; rs2 = 5'd0;
                            imm = {26'b0, inst[6:2]};
                            opcode = 7'b0010011; funct3 = 3'b001; funct7 = 7'b0;
                        end
                        3'b010: begin // C.LWSP
                            inst_type = `INST_TYPE_LOAD;
                            rd = inst[11:7]; rs1 = 5'd2; rs2 = 5'd0;
                            imm = {24'b0, inst[3:2], inst[12], inst[6:4], 2'b00};
                            opcode = 7'b0000011; funct3 = 3'b010; funct7 = 7'b0;
                        end
                        3'b100: begin
                            if (inst[12] == 1'b0) begin
                                if (inst[6:2] == 5'b0) begin // C.JR
                                    inst_type = `INST_TYPE_JALR;
                                    rd = 5'd0; rs1 = inst[11:7]; rs2 = 5'd0; imm = 32'b0;
                                    opcode = 7'b1100111; funct3 = 3'b000; funct7 = 7'b0;
                                end else begin // C.MV
                                    inst_type = `INST_TYPE_ALU_REG;
                                    rd = inst[11:7]; rs1 = 5'd0; rs2 = inst[6:2];
                                    opcode = 7'b0110011; funct3 = 3'b000; funct7 = 7'b0;
                                end
                            end else begin
                                if (inst[6:2] == 5'b0) begin // C.JALR
                                    inst_type = `INST_TYPE_JALR;
                                    rd = 5'd1; rs1 = inst[11:7]; rs2 = 5'd0; imm = 32'b0;
                                    opcode = 7'b1100111; funct3 = 3'b000; funct7 = 7'b0;
                                end else begin // C.ADD
                                    inst_type = `INST_TYPE_ALU_REG;
                                    rd = inst[11:7]; rs1 = inst[11:7]; rs2 = inst[6:2];
                                    opcode = 7'b0110011; funct3 = 3'b000; funct7 = 7'b0;
                                end
                            end
                        end
                        3'b110: begin // C.SWSP
                            inst_type = `INST_TYPE_STORE;
                            rd = 5'd0; rs1 = 5'd2; rs2 = inst[6:2];
                            imm = {24'b0, inst[8:7], inst[12:9], 2'b00};
                            opcode = 7'b0100011; funct3 = 3'b010; funct7 = 7'b0;
                        end
                        default: opcode = 7'b0;
                    endcase
                end
                // ... more quadrants
                default: opcode = 7'b0;
            endcase
        end else begin
            // RV32I decoding
            opcode = inst[6:0];
            rd = inst[11:7];
            funct3 = inst[14:12];
            rs1 = inst[19:15];
            rs2 = inst[24:20];
            funct7 = inst[31:25];
            
            case (opcode)
                7'b0110011: inst_type = `INST_TYPE_ALU_REG;
                7'b0010011: inst_type = `INST_TYPE_ALU_IMM;
                7'b0000011: inst_type = `INST_TYPE_LOAD;
                7'b0100011: inst_type = `INST_TYPE_STORE;
                7'b1100011: inst_type = `INST_TYPE_BRANCH;
                7'b1101111: inst_type = `INST_TYPE_JAL;
                7'b1100111: inst_type = `INST_TYPE_JALR;
                7'b0110111: inst_type = `INST_TYPE_LUI;
                default: inst_type = 3'b111;
            endcase
            
            // Immediate generation
            case (opcode)
                7'b0010011, 7'b0000011, 7'b1100111: imm = {{21{inst[31]}}, inst[30:20]};
                7'b0100011: imm = {{21{inst[31]}}, inst[30:25], inst[11:7]};
                7'b1100011: imm = {{20{inst[31]}}, inst[7], inst[30:25], inst[11:8], 1'b0};
                7'b0110111, 7'b0010111: imm = {inst[31:12], 12'b0};
                7'b1101111: imm = {{12{inst[31]}}, inst[19:12], inst[20], inst[30:21], 1'b0};
                default: imm = 32'b0;
            endcase
        end
    end

endmodule

