


`include "common.v"

module cpu(
  input  wire                 clk_in,			// system clock signal
  input  wire                 rst_in,			// reset signal
	input  wire					        rdy_in,			// ready signal, pause cpu when low

  input  wire [ 7:0]          mem_din,		// data input bus
  output wire [ 7:0]          mem_dout,		// data output bus
  output wire [31:0]          mem_a,			// address bus (only 17:0 is used)
  output wire                 mem_wr,			// write/read signal (1 for write)
	
	input  wire                 io_buffer_full, // 1 if uart buffer is full
	
	output wire [31:0]			dbgreg_dout		// cpu register output (debugging demo)
);

// CDB
wire cdb_en;
wire [31:0] cdb_value;
wire [`ROB_ADDR_WIDTH-1:0] cdb_rob_id;

// Ifetch to Decoder
wire inst_ready;
wire [31:0] inst;
wire [31:0] inst_pc;
wire inst_is_compressed;

// Decoder to Issue
wire [31:0] decoded_inst;
wire [31:0] decoded_pc;
wire [4:0] rs1, rs2, rd;
wire [31:0] imm;
wire [2:0] inst_type;
wire [6:0] opcode;
wire [2:0] funct3;
wire [6:0] funct7;

// ROB
wire rob_full;
wire [`ROB_ADDR_WIDTH-1:0] issue_rob_id;
wire branch_mispredicted;
wire [31:0] branch_target_pc;
wire commit_en;
wire [4:0] commit_rd;
wire [31:0] commit_value;
wire [`ROB_ADDR_WIDTH-1:0] commit_rob_id;

// Regfile
wire [31:0] rs1_val, rs2_val;
wire [`ROB_ADDR_WIDTH-1:0] rs1_rob_id, rs2_rob_id;
wire rs1_ready, rs2_ready;

// RS
wire rs_full;
wire exec_en;
wire [2:0] exec_inst_type;
wire [6:0] exec_opcode;
wire [2:0] exec_funct3;
wire [6:0] exec_funct7;
wire [31:0] exec_v1, exec_v2, exec_imm, exec_pc;
wire [`ROB_ADDR_WIDTH-1:0] exec_rob_id;

// ALU
wire alu_wb_en;
wire [31:0] alu_wb_value;
wire [`ROB_ADDR_WIDTH-1:0] alu_wb_rob_id;
wire alu_wb_jump_en;
wire [31:0] alu_wb_jump_target;

// LSB
wire lsb_full;
wire lsb_wb_en;
wire [31:0] lsb_wb_value;
wire [`ROB_ADDR_WIDTH-1:0] lsb_wb_rob_id;
wire lsb_mem_en, lsb_mem_wr;
wire [31:0] lsb_mem_addr;
wire [7:0] lsb_mem_dout;

// Memory Controller
wire if_mem_rd;
wire [31:0] if_mem_a;
wire [7:0] if_mem_din;
wire if_mem_done;
wire lsb_mem_done;
wire [7:0] lsb_mem_din;

// Issue Logic
wire issue_en = inst_ready && !rob_full && !rs_full && !lsb_full;

ifetch if0(
    .clk(clk_in), .rst(rst_in), .rdy(rdy_in),
    .branch_mispredicted(branch_mispredicted), .branch_target_pc(branch_target_pc),
    .decoder_full(rob_full || rs_full || lsb_full),
    .inst_ready(inst_ready), .inst(inst), .inst_pc(inst_pc), .inst_is_compressed(inst_is_compressed),
    .mem_a(if_mem_a), .mem_din(if_mem_din), .mem_rd(if_mem_rd)
);

decoder dec0(
    .inst(inst), .inst_pc(inst_pc), .inst_is_compressed(inst_is_compressed),
    .decoded_inst(decoded_inst), .decoded_pc(decoded_pc),
    .rs1(rs1), .rs2(rs2), .rd(rd), .imm(imm),
    .inst_type(inst_type), .opcode(opcode), .funct3(funct3), .funct7(funct7)
);

rob rob0(
    .clk(clk_in), .rst(rst_in), .rdy(rdy_in),
    .issue_en(issue_en), .issue_rd(rd), .issue_pc(decoded_pc),
    .issue_rob_id(issue_rob_id), .rob_full(rob_full),
    .wb_en(cdb_en), .wb_rob_id(cdb_rob_id), .wb_value(cdb_value),
    .wb_jump_en(alu_wb_jump_en), .wb_jump_target(alu_wb_jump_target),
    .commit_en(commit_en), .commit_rd(commit_rd), .commit_value(commit_value), .commit_rob_id(commit_rob_id),
    .branch_mispredicted(branch_mispredicted), .branch_target_pc(branch_target_pc),
    .query_rob_id(0), .query_ready(), .query_value()
);

regfile rf0(
    .clk(clk_in), .rst(rst_in), .rdy(rdy_in),
    .rs1(rs1), .rs2(rs2), .rs1_val(rs1_val), .rs2_val(rs2_val),
    .rs1_rob_id(rs1_rob_id), .rs2_rob_id(rs2_rob_id), .rs1_ready(rs1_ready), .rs2_ready(rs2_ready),
    .issue_en(issue_en), .issue_rd(rd), .issue_rob_id(issue_rob_id),
    .commit_en(commit_en), .commit_rd(commit_rd), .commit_value(commit_value), .commit_rob_id(commit_rob_id)
);

rs rs0(
    .clk(clk_in), .rst(rst_in), .rdy(rdy_in),
    .issue_en(issue_en && inst_type != `INST_TYPE_LOAD && inst_type != `INST_TYPE_STORE),
    .issue_inst_type(inst_type), .issue_opcode(opcode), .issue_funct3(funct3), .issue_funct7(funct7),
    .issue_imm(imm), .issue_pc(decoded_pc), .issue_rob_id(issue_rob_id),
    .rs1_val(rs1_val), .rs1_ready(rs1_ready), .rs1_rob_id(rs1_rob_id),
    .rs2_val(rs2_val), .rs2_ready(rs2_ready), .rs2_rob_id(rs2_rob_id),
    .cdb_en(cdb_en), .cdb_rob_id(cdb_rob_id), .cdb_value(cdb_value),
    .exec_en(exec_en), .exec_inst_type(exec_inst_type), .exec_opcode(exec_opcode),
    .exec_funct3(exec_funct3), .exec_funct7(exec_funct7),
    .exec_v1(exec_v1), .exec_v2(exec_v2), .exec_imm(exec_imm), .exec_pc(exec_pc),
    .exec_rob_id(exec_rob_id), .rs_full(rs_full)
);

alu alu0(
    .clk(clk_in), .rst(rst_in), .rdy(rdy_in),
    .exec_en(exec_en), .inst_type(exec_inst_type), .opcode(exec_opcode),
    .funct3(exec_funct3), .funct7(exec_funct7),
    .v1(exec_v1), .v2(exec_v2), .imm(exec_imm), .pc(exec_pc), .rob_id(exec_rob_id),
    .wb_en(alu_wb_en), .wb_value(alu_wb_value), .wb_rob_id(alu_wb_rob_id),
    .wb_jump_en(alu_wb_jump_en), .wb_jump_target(alu_wb_jump_target)
);

lsb lsb0(
    .clk(clk_in), .rst(rst_in), .rdy(rdy_in),
    .issue_en(issue_en && (inst_type == `INST_TYPE_LOAD || inst_type == `INST_TYPE_STORE)),
    .issue_inst_type(inst_type), .issue_funct3(funct3), .issue_imm(imm), .issue_rob_id(issue_rob_id),
    .rs1_val(rs1_val), .rs1_ready(rs1_ready), .rs1_rob_id(rs1_rob_id),
    .rs2_val(rs2_val), .rs2_ready(rs2_ready), .rs2_rob_id(rs2_rob_id),
    .cdb_en(cdb_en), .cdb_rob_id(cdb_rob_id), .cdb_value(cdb_value),
    .commit_en(commit_en), .commit_rob_id(commit_rob_id),
    .mem_en(lsb_mem_en), .mem_wr(lsb_mem_wr), .mem_addr(lsb_mem_addr), .mem_dout(lsb_mem_dout),
    .mem_din(lsb_mem_din), .mem_done(lsb_mem_done),
    .wb_en(lsb_wb_en), .wb_value(lsb_wb_value), .wb_rob_id(lsb_wb_rob_id),
    .lsb_full(lsb_full)
);

mem_ctrl mc0(
    .clk(clk_in), .rst(rst_in), .rdy(rdy_in),
    .if_en(if_mem_rd), .if_addr(if_mem_a), .if_data(if_mem_din), .if_done(if_mem_done),
    .lsb_en(lsb_mem_en), .lsb_wr(lsb_mem_wr), .lsb_addr(lsb_mem_addr), .lsb_din(lsb_mem_dout),
    .lsb_dout(lsb_mem_din), .lsb_done(lsb_mem_done),
    .mem_a(mem_a), .mem_dout(mem_dout), .mem_wr(mem_wr), .mem_din(mem_din)
);

assign cdb_en = alu_wb_en || lsb_wb_en;
assign cdb_value = alu_wb_en ? alu_wb_value : lsb_wb_value;
assign cdb_rob_id = alu_wb_en ? alu_wb_rob_id : lsb_wb_rob_id;

endmodule


