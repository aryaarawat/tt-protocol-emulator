module lane_decode (
    input  logic [23:0] instr,
    input  logic        tx_empty,    
    input  logic        x_zero,     

    output logic [4:0]  dly,
    output logic        need_stall,
    output logic        is_halt,
    output logic        halt_irq,

    output logic        pc_jump,     
    output logic [6:0]  pc_target,
    output logic        x_load,      
    output logic [7:0]  x_val,
    output logic        x_dec,       
    output logic        osr_load,    
    output logic        fifo_pop,    
    output logic        out_en,      
    output logic [5:0]  out_n,       
    output logic        drive_en,    
    output logic [4:0]  drive_pin,
    output logic [1:0]  drive_act,   
    output logic        drive_mask  

    localparam logic [4:0] OP_NOP   = 5'd0;
    localparam logic [4:0] OP_JMP   = 5'd1;
    localparam logic [4:0] OP_DRIVE = 5'd6;
    localparam logic [4:0] OP_OUT   = 5'd7;
    localparam logic [4:0] OP_PULL  = 5'd9;
    localparam logic [4:0] OP_SET   = 5'd12;
    localparam logic [4:0] OP_HALT  = 5'd21;

    localparam logic [3:0] COND_ALWAYS = 4'd0;
    localparam logic [3:0] COND_XDEC   = 4'd2;

    localparam logic [2:0] DST_PINS = 3'd0;   
    localparam logic [2:0] DST_X    = 3'd0;   

    logic [4:0]  op;
    logic [10:0] arg;
    assign op  = instr[23:19];
    assign dly = instr[18:14];

    assign arg = instr[10:0];

    logic [3:0] jmp_cond;   assign jmp_cond = arg[10:7];
    logic [2:0] dst;        assign dst      = arg[10:8];
    logic [4:0] n_field;    assign n_field  = arg[7:3];

    assign pc_target  = arg[6:0];
    assign x_val      = arg[7:0];
    assign drive_pin  = arg[10:6];
    assign drive_act  = arg[5:4];
    assign drive_mask = arg[3];
    assign out_n      = (n_field == 5'd0) ? 6'd32 : {1'b0, n_field};
    assign halt_irq   = (op == OP_HALT) && arg[10];

    always_comb begin
        need_stall = 1'b0;
        is_halt    = 1'b0;
        pc_jump    = 1'b0;
        x_load     = 1'b0;
        x_dec      = 1'b0;
        osr_load   = 1'b0;
        fifo_pop   = 1'b0;
        out_en     = 1'b0;
        drive_en   = 1'b0;

        case (op)
            OP_NOP: ;  

            OP_JMP: begin
                if (jmp_cond == COND_ALWAYS)
                    pc_jump = 1'b1;
                else if (jmp_cond == COND_XDEC) begin
                    x_dec   = 1'b1;          
                    pc_jump = !x_zero;       
                end
                else
                    is_halt = 1'b1;          
            end

            OP_DRIVE: drive_en = 1'b1;

            OP_OUT: begin
                if (dst == DST_PINS) out_en  = 1'b1;
                else                 is_halt = 1'b1;
            end

            OP_PULL: begin
                if (tx_empty)
                    need_stall = 1'b1;       
                else begin
                    osr_load = 1'b1;
                    fifo_pop = 1'b1;
                end
            end

            OP_SET: begin
                if (dst == DST_X) x_load  = 1'b1;
                else              is_halt = 1'b1;
            end

            OP_HALT: is_halt = 1'b1;

            default: is_halt = 1'b1;         
        endcase
    end

endmodule