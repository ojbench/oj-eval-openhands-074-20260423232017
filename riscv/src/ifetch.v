

`include "common.v"

module ifetch(
    input wire clk,
    input wire rst,
    input wire rdy,

    // From ROB (branch misprediction)
    input wire branch_mispredicted,
    input wire [31:0] branch_target_pc,

    // From Decoder (stall if full)
    input wire decoder_full,

    // To Decoder
    output reg inst_ready,
    output reg [31:0] inst,
    output reg [31:0] inst_pc,
    output reg inst_is_compressed,

    // Memory interface
    output reg [31:0] mem_a,
    input wire [7:0] mem_din,
    output reg mem_rd
);

    reg [31:0] pc;
    reg [31:0] next_pc;

    // Simple instruction buffer to handle 16-bit alignment and mixed lengths
    reg [7:0] buffer [0:7];
    reg [3:0] buffer_count;
    reg [31:0] buffer_pc;

    // State machine for fetching
    localparam STATE_IDLE = 2'd0;
    localparam STATE_FETCHING = 2'd1;
    reg [1:0] state;

    always @(posedge clk) begin
        if (rst) begin
            pc <= 32'h0;
            state <= STATE_IDLE;
            buffer_count <= 0;
            inst_ready <= 0;
            mem_rd <= 0;
        end else if (rdy) begin
            if (branch_mispredicted) begin
                pc <= branch_target_pc;
                buffer_count <= 0;
                inst_ready <= 0;
                state <= STATE_IDLE;
                mem_rd <= 0;
            end else begin
                // Instruction fetching logic
                // This is a simplified version, a real one would be more complex
                // to handle memory latency and buffer management.
                
                if (!decoder_full && !inst_ready) begin
                    // Try to provide an instruction from buffer
                    if (buffer_count >= 2) begin
                        if (buffer[0][1:0] != 2'b11) begin
                            // Compressed instruction
                            inst <= {16'h0, buffer[1], buffer[0]};
                            inst_pc <= buffer_pc;
                            inst_is_compressed <= 1;
                            inst_ready <= 1;
                            
                            // Shift buffer
                            buffer[0] <= buffer[2];
                            buffer[1] <= buffer[3];
                            buffer[2] <= buffer[4];
                            buffer[3] <= buffer[5];
                            buffer_count <= buffer_count - 2;
                            buffer_pc <= buffer_pc + 2;
                        end else if (buffer_count >= 4) begin
                            // Normal instruction
                            inst <= {buffer[3], buffer[2], buffer[1], buffer[0]};
                            inst_pc <= buffer_pc;
                            inst_is_compressed <= 0;
                            inst_ready <= 1;
                            
                            // Shift buffer
                            buffer[0] <= buffer[4];
                            buffer[1] <= buffer[5];
                            buffer[2] <= buffer[6];
                            buffer[3] <= buffer[7];
                            buffer_count <= buffer_count - 4;
                            buffer_pc <= buffer_pc + 4;
                        end
                    end
                end else if (inst_ready) begin
                    inst_ready <= 0;
                end

                // Fetch more bytes if buffer is not full
                if (buffer_count <= 4 && state == STATE_IDLE) begin
                    mem_a <= pc;
                    mem_rd <= 1;
                    state <= STATE_FETCHING;
                end else if (state == STATE_FETCHING) begin
                    buffer[buffer_count] <= mem_din;
                    buffer_count <= buffer_count + 1;
                    pc <= pc + 1;
                    state <= STATE_IDLE;
                    mem_rd <= 0;
                end
            end
        end
    end

endmodule

