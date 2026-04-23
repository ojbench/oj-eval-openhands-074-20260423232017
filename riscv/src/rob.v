

`include "common.v"

module rob(
    input wire clk,
    input wire rst,
    input wire rdy,

    // From Decoder (Issue)
    input wire issue_en,
    input wire [4:0] issue_rd,
    input wire [31:0] issue_pc,
    output wire [`ROB_ADDR_WIDTH-1:0] issue_rob_id,
    output wire rob_full,

    // From Execution Units (Writeback)
    input wire wb_en,
    input wire [`ROB_ADDR_WIDTH-1:0] wb_rob_id,
    input wire [31:0] wb_value,
    input wire wb_jump_en,
    input wire [31:0] wb_jump_target,

    // To Commit
    output reg commit_en,
    output reg [4:0] commit_rd,
    output reg [31:0] commit_value,
    output reg [`ROB_ADDR_WIDTH-1:0] commit_rob_id,
    
    // Branch misprediction
    output reg branch_mispredicted,
    output reg [31:0] branch_target_pc,

    // For Register Status / RAT
    input wire [`ROB_ADDR_WIDTH-1:0] query_rob_id,
    output wire query_ready,
    output wire [31:0] query_value
);

    reg [4:0] rd [`ROB_SIZE-1:0];
    reg [31:0] value [`ROB_SIZE-1:0];
    reg [31:0] pc [`ROB_SIZE-1:0];
    reg [1:0] status [`ROB_SIZE-1:0];
    reg jump_en [`ROB_SIZE-1:0];
    reg [31:0] jump_target [`ROB_SIZE-1:0];

    reg [`ROB_ADDR_WIDTH-1:0] head;
    reg [`ROB_ADDR_WIDTH-1:0] tail;
    reg [5:0] count;

    assign rob_full = (count == `ROB_SIZE);
    assign issue_rob_id = tail;

    assign query_ready = (status[query_rob_id] == `ROB_READY);
    assign query_value = value[query_rob_id];

    always @(posedge clk) begin
        if (rst) begin
            head <= 0;
            tail <= 0;
            count <= 0;
            commit_en <= 0;
            branch_mispredicted <= 0;
            for (integer i = 0; i < `ROB_SIZE; i = i + 1) status[i] <= `ROB_IDLE;
        end else if (rdy) begin
            // Issue
            if (issue_en && !rob_full) begin
                rd[tail] <= issue_rd;
                pc[tail] <= issue_pc;
                status[tail] <= `ROB_WAITING;
                tail <= tail + 1;
                count <= count + 1;
            end

            // Writeback
            if (wb_en) begin
                value[wb_rob_id] <= wb_value;
                jump_en[wb_rob_id] <= wb_jump_en;
                jump_target[wb_rob_id] <= wb_jump_target;
                status[wb_rob_id] <= `ROB_READY;
            end

            // Commit
            if (count > 0 && status[head] == `ROB_READY) begin
                commit_en <= 1;
                commit_rd <= rd[head];
                commit_value <= value[head];
                commit_rob_id <= head;
                
                // Handle branch misprediction (simplified)
                // In a real CPU, we'd compare jump_target with predicted target
                // Here we just assume if jump_en is set, we might need to redirect
                // This needs more sophisticated branch prediction logic
                
                head <= head + 1;
                count <= count - 1;
                status[head] <= `ROB_IDLE;
            end else begin
                commit_en <= 0;
            end
        end
    end

endmodule

