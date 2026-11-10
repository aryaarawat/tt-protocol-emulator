module lane_ctrl (
    input logic clk,
    input logic rst_n,
    input logic ena,
    input logic restart,
    input logic tick_en,
    input logic [4:0] dly,
    input logic need_stall,
    input logic is_halt,
    output logic exec,
    output logic pc_adv,
    output logic pc_rst,
    output logic state,
    output logic [$clog2(dly)-1:0] count,
	output logic wrapped
)

typedef enum logic [2:0] {
    IDLE,
    RUN,
    STALL,
    DELAY,
    HALT
} state_t;

state_t curr, next;
logic done;

always_ff @(posedge clk) begin
    if (~rst_n)
        curr <= IDLE
    else
        curr <= next;
end

always_comb begin
    
    next = curr;
    exec = 1'b0;
    pc_adv = 1'b0;
    done = 1'b0;

    case(curr)
        IDLE:   if (ena) next = RUN;
        RUN:    if (is_halt) begin
                    next = HALT;
                    exec = 1;
                end
                else if (need_stall) begin
                    next = STALL;
                end
                else if (dly > 0) begin
                    next = DELAY;
                    exec = 1;
                    pc_adv = 1;
                    done = 1;
                end
                else begin
                    next = RUN;
                    exec = 1;
                    pc_adv = 1;
                    done = 1;
                end
        STALL:  if (need_stall) next = STALL;
                else if (~need_stall && dly > 0) begin
                    next = DELAY;
                    exec = 1;
                    pc_adv = 1;
                    done = 1;
                end
                else if (~need_stall && dly = 0) begin
                    next = RUN;
                    exec = 1;
                    pc_adv = 1;
                    done = 1;
                end
        DELAY:  if (count != 0 ) next = DELAY;
                else next = RUN;
        HALT:   if (restart) next = RUN;
                else next = HALT;
        default: next = IDLE;
    endcase
end

always_ff @(posedge clk or negedge rst_n) begin
	if(!rst_n)
		count <= ‘0;
else if (ena && count == N-1)
		count <= ‘0;
	else if (ena)
		count <= count + 1’b1;
end

always_comb begin
	if (ena && count == N-1)
		wrapped = 1’b1;
	else 
		wrapped = ‘0;
end

endmodule

