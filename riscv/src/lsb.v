




`include "common.v"

module lsb(
    input wire clk,
    input wire rst,
    input wire rdy,

    // From Decoder (Issue)
    input wire issue_en,
    input wire [2:0] issue_inst_type,
    input wire [2:0] issue_funct3,
    input wire [31:0] issue_imm,
    input wire [`ROB_ADDR_WIDTH-1:0] issue_rob_id,
    
    input wire [31:0] rs1_val,
    input wire rs1_ready,
    input wire [`ROB_ADDR_WIDTH-1:0] rs1_rob_id,
    
    input wire [31:0] rs2_val,
    input wire rs2_ready,
    input wire [`ROB_ADDR_WIDTH-1:0] rs2_rob_id,

    // From CDB
    input wire cdb_en,
    input wire [`ROB_ADDR_WIDTH-1:0] cdb_rob_id,
    input wire [31:0] cdb_value,

    // From ROB (Commit for Stores)
    input wire commit_en,
    input wire [`ROB_ADDR_WIDTH-1:0] commit_rob_id,

    // To Memory Controller
    output reg mem_en,
    output reg mem_wr,
    output reg [31:0] mem_addr,
    output reg [7:0] mem_dout,
    input wire [7:0] mem_din,
    input wire mem_done,

    // To CDB
    output reg wb_en,
    output reg [31:0] wb_value,
    output reg [`ROB_ADDR_WIDTH-1:0] wb_rob_id,

    output wire lsb_full
);

    reg busy [`LSB_SIZE-1:0];
    reg [2:0] inst_type [`LSB_SIZE-1:0];
    reg [2:0] funct3 [`LSB_SIZE-1:0];
    reg [31:0] imm [`LSB_SIZE-1:0];
    reg [`ROB_ADDR_WIDTH-1:0] rob_id [`LSB_SIZE-1:0];
    reg committed [`LSB_SIZE-1:0];

    reg [31:0] v1 [`LSB_SIZE-1:0];
    reg [31:0] v2 [`LSB_SIZE-1:0];
    reg [`ROB_ADDR_WIDTH-1:0] q1 [`LSB_SIZE-1:0];
    reg [`ROB_ADDR_WIDTH-1:0] q2 [`LSB_SIZE-1:0];
    reg r1 [`LSB_SIZE-1:0];
    reg r2 [`LSB_SIZE-1:0];

    reg [`LSB_ADDR_WIDTH-1:0] head;
    reg [`LSB_ADDR_WIDTH-1:0] tail;
    reg [5:0] count;

    assign lsb_full = (count == `LSB_SIZE);

    always @(posedge clk) begin
        if (rst) begin
            head <= 0;
            tail <= 0;
            count <= 0;
            mem_en <= 0;
            wb_en <= 0;
            for (integer i = 0; i < `LSB_SIZE; i = i + 1) begin
                busy[i] <= 0;
                committed[i] <= 0;
            end
        end else if (rdy) begin
            // CDB Monitoring
            if (cdb_en) begin
                for (integer i = 0; i < `LSB_SIZE; i = i + 1) begin
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

            // Commit Monitoring (for Stores)
            if (commit_en) begin
                for (integer i = 0; i < `LSB_SIZE; i = i + 1) begin
                    if (busy[i] && rob_id[i] == commit_rob_id) begin
                        committed[i] <= 1;
                    end
                end
            end

            // Issue
            if (issue_en && !lsb_full) begin
                busy[tail] <= 1;
                inst_type[tail] <= issue_inst_type;
                funct3[tail] <= issue_funct3;
                imm[tail] <= issue_imm;
                rob_id[tail] <= issue_rob_id;
                committed[tail] <= (issue_inst_type == `INST_TYPE_LOAD); // Loads are "committed" immediately in LSB

                if (rs1_ready) begin
                    v1[tail] <= rs1_val;
                    r1[tail] <= 1;
                end else if (cdb_en && rs1_rob_id == cdb_rob_id) begin
                    v1[tail] <= cdb_value;
                    r1[tail] <= 1;
                end else begin
                    q1[tail] <= rs1_rob_id;
                    r1[tail] <= 0;
                end

                if (rs2_ready) begin
                    v2[tail] <= rs2_val;
                    r2[tail] <= 1;
                end else if (cdb_en && rs2_rob_id == cdb_rob_id) begin
                    v2[tail] <= cdb_value;
                    r2[tail] <= 1;
                end else begin
                    q2[tail] <= rs2_rob_id;
                    r2[tail] <= 0;
                end

                tail <= tail + 1;
                count <= count + 1;
            end

            // Memory Access (Simplified)
            if (count > 0 && busy[head] && r1[head] && r2[head] && committed[head]) begin
                // Execute Load/Store
                // This needs a state machine to handle multi-byte access
                // For now, just a placeholder
                mem_en <= 1;
                mem_wr <= (inst_type[head] == `INST_TYPE_STORE);
                mem_addr <= v1[head] + imm[head];
                mem_dout <= v2[head][7:0];
                
                if (mem_done) begin
                    if (inst_type[head] == `INST_TYPE_LOAD) begin
                        wb_en <= 1;
                        wb_value <= {24'b0, mem_din}; // Simplified
                        wb_rob_id <= rob_id[head];
                    end else begin
                        wb_en <= 0;
                    end
                    busy[head] <= 0;
                    head <= head + 1;
                    count <= count - 1;
                    mem_en <= 0;
                end
            end else begin
                mem_en <= 0;
                wb_en <= 0;
            end
        end
    end

endmodule



