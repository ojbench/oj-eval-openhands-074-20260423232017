
`ifndef COMMON_V
`define COMMON_V

// Instruction types
`define INST_TYPE_ALU_REG 3'd0
`define INST_TYPE_ALU_IMM 3'd1
`define INST_TYPE_LOAD    3'd2
`define INST_TYPE_STORE   3'd3
`define INST_TYPE_BRANCH  3'd4
`define INST_TYPE_JAL     3'd5
`define INST_TYPE_JALR    3'd6
`define INST_TYPE_LUI     3'd7

// ROB entry status
`define ROB_IDLE      2'd0
`define ROB_WAITING   2'd1
`define ROB_READY     2'd2
`define ROB_COMMITTED 2'd3

// RS entry status
`define RS_IDLE    1'b0
`define RS_BUSY    1'b1

// LSB entry status
`define LSB_IDLE    1'b0
`define LSB_BUSY    1'b1

`define ROB_SIZE 16
`define ROB_ADDR_WIDTH 4
`define RS_SIZE 16
`define RS_ADDR_WIDTH 4
`define LSB_SIZE 16
`define LSB_ADDR_WIDTH 4

`endif
