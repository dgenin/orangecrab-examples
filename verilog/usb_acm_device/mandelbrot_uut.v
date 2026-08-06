module f_iter(
         input wire clk48,
         input wire signed [15:0] cr,
         input wire signed [15:0] ci,
         output reg [15:0] iter_counter_out = 0,
         input wire start_iter,
         output reg data_valid = 0);

    reg signed [15:0] res_r = 0;
    reg signed [15:0] res_i = 0;
    reg [20:0] res_r_sqr = 0;
    reg [20:0] res_i_sqr = 0;
    reg running = 0;
    reg [15:0] iter_counter = 0;

    always @(posedge clk48) begin
        if (start_iter) begin
            iter_counter <= 16'd200;
            iter_counter_out <= 16'd0;
            running = 1'b1;
            res_r <= 0;
            res_i <= 0;
        end;
        case (iter_counter)
            8'd0 : data_valid <= 0;
            8'd1 : begin data_valid <= 1; iter_counter <= 0; end
            default : begin
                // Right shift is necessary for fixed point multiplication
                // Scale is 1/(2**14)
                // Expression in curlies "manually" sign-extend the arguments in the expression
                // to ensure there are enough bits in the result to get the significant digits.
                // >>> is sign-extended right-shift, which is necessary to get the right sign.
                // TODO: Make a constant for the fixed point scale
                res_r_sqr = ({ {16{res_r[15]}}, res_r[15:0] }*{ {16{res_r[15]}}, res_r[15:0] })>>>13;
                res_i_sqr = ({ {16{res_i[15]}}, res_i[15:0] }*{ {16{res_i[15]}}, res_i[15:0] })>>>13;
                // 1<<14 is 1 in fixed point
                running = ((res_r_sqr + res_i_sqr) <= 20'h8000);
                if (running) begin
                    // Need to sign extend cr and ci for signed arithmetic to work
                    res_r <= res_r_sqr - res_i_sqr + { {16{cr[15]}}, cr[15:0] };
                    // Need to ensure there are enough bits for the result of res_r*res_i, before the right
                    // shift. Generally, that will be double the bit width of res_r/res_i
                    // NOTE: -1 in the shift accounts for the factor of 2 multiplication in the formula for imaginary part
                    res_i <= ((({ {16{res_r[15]}}, res_r[15:0] })*({ {16{res_i[15]}}, res_i[15:0] }))>>>(13-1)) + { {16{ci[15]}}, ci[15:0] };
                    iter_counter <= iter_counter - 1;
                end else begin
                    iter_counter_out <= iter_counter;
                    iter_counter <= 1;
                end
            end
        endcase
    end;
endmodule

module f_iter_pipe(
         input wire clk48,
         input wire signed [15:0] cr0, cr1, cr2,
         input wire signed [15:0] ci0, ci1, ci2,
         output reg [15:0] iter_counter_out0, iter_counter_out1, iter_counter_out2,
         input wire start_iter,
         output reg data_valid = 0);

    reg signed [15:0] res_r = 0;
    reg signed [15:0] res_i = 0;
    reg unsigned [1:0] phase_counter = 0;
    reg signed [31:0] res_r_1 = 0;
    reg signed [31:0] res_i_1 = 0;
    reg unsigned[15:0] iter_0 = 0;
    reg unsigned[15:0] iter_1 = 0;

    reg [31:0] r_sqr_0 = 0;
    reg [31:0] i_sqr_0 = 0;
    reg signed [31:0] r_i_prod_0 = 0;
    // reg running = 0;
    reg [15:0] iter_counter = 16'hFFFF;
    reg [2:0] done = 3'd0;
    reg [31:0] norm_1 = 0;

    always @(posedge clk48) begin
        if (start_iter) begin
            iter_counter <= 16'd0;
            iter_counter_out0 <= 16'h0;
            iter_counter_out1 <= 16'h0;
            iter_counter_out2 <= 16'h0;
            // running = 1'b1;
            // Clear all of the pipeline inputs
            res_r <= 16'h0;
            res_i <= 16'h0;
            res_r_1 <= 32'h0;
            res_i_1 <= 32'h0;
            r_sqr_0 <= 32'h0;
            i_sqr_0 <= 32'h0;
            iter_0 <= 16'h0;
            iter_1 <= 16'h0;
            r_i_prod_0 <= 32'h0;
            norm_1 = 32'h0;
            done <= 3'd0;
            phase_counter <= 2'd0;
        end;
        case (iter_counter)
            16'hFFFF : data_valid <= 0;
            default : 
                if ((done != 3'd7) && (iter_counter <= 16'hF000)) begin
                // if ((done != 4'd15) && (iter_counter <= 16'd5)) begin
                    // Phase 0
                    // NOTE: See concatenation and replication operator documentation
                    r_sqr_0 <= ({ {16{res_r[15]}}, res_r[15:0] }*{ {16{res_r[15]}}, res_r[15:0] })>>>13;
                    i_sqr_0 <= ({ {16{res_i[15]}}, res_i[15:0] }*{ {16{res_i[15]}}, res_i[15:0] })>>>13;
                    r_i_prod_0 <= ((({ {16{res_r[15]}}, res_r[15:0] })*({ {16{res_i[15]}}, res_i[15:0] }))>>>(13-1));
                    iter_0 <= iter_counter;

                    // Phase 1
                    norm_1 <= r_sqr_0 + i_sqr_0;
                    res_r_1 <= r_sqr_0 - i_sqr_0;
                    iter_1 <= iter_0;
                    // NOTE: The first index selects the point using the low bits of the iter_counter, which correspond
                    // to the order in which the points enter the pipeline. The second index is necessary for sign extension.
                    // NOTE: Phase 1 is manipulating data for cr0+ci0*i at iter_counter[1:0]==1 so the indices need to be rolled accordingly.
                    case (phase_counter)
                        2'd0 : res_i_1 <= r_i_prod_0 + { {16{ci2[15]}}, ci2[15:0] };
                        2'd1 : res_i_1 <= r_i_prod_0 + { {16{ci0[15]}}, ci0[15:0] };
                        2'd2 : res_i_1 <= r_i_prod_0 + { {16{ci1[15]}}, ci1[15:0] };
                    endcase
                    
                    // Phase 2
                    if (norm_1 >= 32'h8000) begin
                        case (phase_counter)
                            2'd0 : if (done[1] == 0) begin iter_counter_out1 <= iter_1; done[1] <= 1; end
                            2'd1 : if (done[2] == 0) begin iter_counter_out2 <= iter_1; done[2] <= 1; end
                            2'd2 : if (done[0] == 0) begin iter_counter_out0 <= iter_1; done[0] <= 1; end
                        endcase
                    end
                    if ((iter_counter > 16'd0) || (phase_counter > 16'd1)) begin
                        case (phase_counter)
                            2'd0 : res_r <= res_r_1 + { {16{cr1[15]}}, cr1[15:0] };
                            2'd1 : res_r <= res_r_1 + { {16{cr2[15]}}, cr2[15:0] };
                            2'd2 : res_r <= res_r_1 + { {16{cr0[15]}}, cr0[15:0] };
                        endcase
                        res_i <= res_i_1;
                    end
                    
                    if (phase_counter == 2'd2) begin
                        iter_counter <= iter_counter + 1;
                        phase_counter <= 2'd0;
                    end else begin
                        phase_counter <= phase_counter + 1;
                    end;
                end else begin
                    data_valid <= 1;
                    iter_counter <= 16'hFFFF;
                end
        endcase
    end
endmodule

module image_iter (
    input clk48,

    output reg [7:0] uart_in_data, 
    output wire uart_in_valid,
    input wire [15:0] tl_r, tl_i, step, width,
    input wire start_image,
    input wire uart_in_ready,
    output reg finished = 0
    );

    wire clk48;
    reg signed [15:0] c_r = 16'hFFFF;
    reg signed [15:0] c_i [11:0];
    wire [15:0] iter_counter [11:0];
    // width must be divisible by batch size, currently 6.
    reg [7:0] batch_counter = 0;
    reg [15:0] r_counter = 0;
    reg [15:0] i_counter = 0;
    `define IMAGE_ITER_IDLE 2'd0
    `define IMAGE_ITER_INIT 2'd1
    `define IMAGE_ITER_COMPUTE 2'd2
    `define IMAGE_ITER_SEND 2'd3
    reg [1:0] state = `IMAGE_ITER_IDLE;
    reg [15:0] p_r, p_i;
    reg start_iter = 0;
    wire [3:0] data_valid_in;
    reg [3:0] data_valid = 0;


    f_iter_pipe mandel_iter_0 (.clk48(clk48), .cr0(c_r), .cr1(c_r), .cr2(c_r), 
                               .ci0(c_i[0]), .ci1(c_i[1]), .ci2(c_i[2]),
                               .start_iter(start_iter), .data_valid(data_valid_in[0]),
                               .iter_counter_out0(iter_counter[0]), .iter_counter_out1(iter_counter[1]),
                               .iter_counter_out2(iter_counter[2]));

    f_iter_pipe mandel_iter_1 (.clk48(clk48), .cr0(c_r), .cr1(c_r), .cr2(c_r), 
                               .ci0(c_i[3]), .ci1(c_i[4]), .ci2(c_i[5]),
                               .start_iter(start_iter), .data_valid(data_valid_in[1]),
                               .iter_counter_out0(iter_counter[3]), .iter_counter_out1(iter_counter[4]),
                               .iter_counter_out2(iter_counter[5]));

    f_iter_pipe mandel_iter_2 (.clk48(clk48), .cr0(c_r), .cr1(c_r), .cr2(c_r), 
                               .ci0(c_i[6]), .ci1(c_i[7]), .ci2(c_i[8]),
                               .start_iter(start_iter), .data_valid(data_valid_in[2]),
                               .iter_counter_out0(iter_counter[6]), .iter_counter_out1(iter_counter[7]),
                               .iter_counter_out2(iter_counter[8]));

    f_iter_pipe mandel_iter_3 (.clk48(clk48), .cr0(c_r), .cr1(c_r), .cr2(c_r), 
                               .ci0(c_i[9]), .ci1(c_i[10]), .ci2(c_i[11]),
                               .start_iter(start_iter), .data_valid(data_valid_in[3]),
                               .iter_counter_out0(iter_counter[9]), .iter_counter_out1(iter_counter[10]),
                               .iter_counter_out2(iter_counter[11]));
    // for cr in range(0, tl_r):
    //    for ci in range(0, tl_i, 6):
    always @(posedge clk48) begin
        if (start_image) begin
            batch_counter <= 0;
            i_counter <= 0;
            r_counter <= 0;
            p_r <= tl_r;
            p_i <= tl_i;
            state <= `IMAGE_ITER_INIT;
        end
        case (state)
            `IMAGE_ITER_IDLE: begin finished <= 0; end
            `IMAGE_ITER_INIT: begin
                    case (batch_counter[3:0]) 
                        4'd0: begin
                            c_r <= p_r;
                            c_i[0] <= p_i;
                        end
                        4'd1: begin
                            c_i[1] <= p_i;
                        end
                        4'd2: begin
                            c_i[2] <= p_i;
                        end
                        4'd3: begin
                            c_i[3] <= p_i;
                        end
                        4'd4: begin
                            c_i[4] <= p_i;
                        end
                        4'd5: begin
                            c_i[5] <= p_i;
                        end
                        4'd6: begin
                            c_i[6] <= p_i;
                        end
                        4'd7: begin
                            c_i[7] <= p_i;
                        end
                        4'd8: begin
                            c_i[8] <= p_i;
                        end
                        4'd9: begin
                            c_i[9] <= p_i;
                        end
                        4'd10: begin
                            c_i[10] <= p_i;
                        end
                        4'd11: begin
                            c_i[11] <= p_i;
                            state <= `IMAGE_ITER_COMPUTE;
                        end
                        // 3'd6: begin
                        //     state <= `IMAGE_ITER_COMPUTE;
                        //     batch_counter <= 0;
                        // end
                        endcase;
                        if (batch_counter < 11) begin
                            batch_counter <= batch_counter + 1;
                        end else begin
                            batch_counter <= 0;
                        end
                        if (i_counter >= width) begin
                            i_counter <= 0;
                            r_counter <= r_counter + 1;
                            p_r <= p_r + step;
                            p_i <= tl_i;
                        end else begin
                            i_counter <= i_counter + 1;
                            p_i <= p_i + step;
                        end
                    end
            `IMAGE_ITER_COMPUTE: begin 
                        if (batch_counter == 0) begin
                            start_iter <= 1;
                            batch_counter <= 1; // Not used for batch counting here
                            data_valid <= 0;
                        end else if (start_iter) begin
                            start_iter <= 0;
                        end
                        data_valid <= data_valid | data_valid_in;
                        if (data_valid == 4'hf) begin
                            state <= `IMAGE_ITER_SEND;
                            batch_counter <= 0; // Not used for batch counting here
                            data_valid <= 0;
                        end
                    end
            `IMAGE_ITER_SEND: begin
                // HACK: Instead of honoring USB flow control correctly we are dropping
                //       the first two bytes in each batch on the client side.
                // WTF: Why is the first received twice on the client side!!!???
                //      The README for the USB-SERIAL logic seems to state that 
                //      uart_in_ready acts as an ACK, i.e., data is received if
                //      uart_in_ready & uart_in_valid on the same clock cycle.
                //      But this does not explain why the first byte (0xaa) is
                //      received twice.
                case (batch_counter)
                    5'd0 : begin uart_in_data <= 8'haa; uart_in_valid <= 1; end
                    5'd1 : uart_in_data <= iter_counter[0][15:8];
                    5'd2 : uart_in_data <= iter_counter[0][7:0];
                    5'd3 : uart_in_data <= iter_counter[1][15:8];
                    5'd4 : uart_in_data <= iter_counter[1][7:0];
                    5'd5 : uart_in_data <= iter_counter[2][15:8];
                    5'd6 : uart_in_data <= iter_counter[2][7:0];
                    5'd7 : uart_in_data <= iter_counter[3][15:8];
                    5'd8 : uart_in_data <= iter_counter[3][7:0];
                    5'd9 : uart_in_data <= iter_counter[4][15:8];
                    5'd10 : uart_in_data <= iter_counter[4][7:0];
                    5'd11 : uart_in_data <= iter_counter[5][15:8];
                    5'd12 : uart_in_data <= iter_counter[5][7:0];
                    5'd13 : uart_in_data <= iter_counter[6][15:8];
                    5'd14 : uart_in_data <= iter_counter[6][7:0];
                    5'd15 : uart_in_data <= iter_counter[7][15:8];
                    5'd16 : uart_in_data <= iter_counter[7][7:0];
                    5'd17 : uart_in_data <= iter_counter[8][15:8];
                    5'd18 : uart_in_data <= iter_counter[8][7:0];
                    5'd19 : uart_in_data <= iter_counter[9][15:8];
                    5'd20 : uart_in_data <= iter_counter[9][7:0];
                    5'd21 : uart_in_data <= iter_counter[10][15:8];
                    5'd22 : uart_in_data <= iter_counter[10][7:0];
                    5'd23 : uart_in_data <= iter_counter[11][15:8];
                    5'd24 : uart_in_data <= iter_counter[11][7:0];
                    5'd25 : begin
                        uart_in_valid <= 0;
                        // if ((r_counter > width) && (i_counter > width) && (data_valid == 3)) begin
                        if ((r_counter > width) && (i_counter > width)) begin
                            finished <= 1;
                            state <= `IMAGE_ITER_IDLE;
                        end else begin
                            state <= `IMAGE_ITER_INIT;
                        end
                        batch_counter <= 0;
                    end
                endcase;
                if ((batch_counter < 25) && (uart_in_ready)) begin
                    batch_counter <= batch_counter + 1;
                end
            end
        endcase 
    end
endmodule


module mandelbrot_uut (
        input clk48,

		output uart_out_ready,
  		input uart_out_valid,
  		input [7:0] uart_out_data,
  
  		output wire uart_in_valid,
  		input wire uart_in_ready,
		output wire [7:0] uart_in_data,
  	
        output rgb_led0_r,
        output rgb_led0_g,
        output rgb_led0_b
    );

    wire clk48;
    reg start_image = 0;
    wire finished;
    reg [15:0] tl_r, tl_i, width, step;

    image_iter steve (.clk48(clk48), .uart_in_data(uart_in_data), .uart_in_valid(uart_in_valid),
                      .tl_r(tl_r), .tl_i(tl_i), .step(step), .width(width), .start_image(start_image),
                      .uart_in_ready(uart_in_ready), .finished(finished));
    
    // Reader
    reg [3:0] reg_counter = 0;
    always @(posedge clk48) begin
        if (start_image) begin
            start_image <= 0;
            reg_counter <= 0;
        end;
        if (uart_out_valid) begin
            case (reg_counter)
                4'd0 : begin tl_r[15:8] <= uart_out_data; end
                4'd1 : begin tl_r[7:0] <= uart_out_data; end
                4'd2 : begin tl_i[15:8] <= uart_out_data; end
                4'd3 : begin tl_i[7:0] <= uart_out_data; end
                4'd4 : begin step[15:8] <= uart_out_data; end
                4'd5 : begin step[7:0] <= uart_out_data; end
                4'd6 : begin width[15:8] <= uart_out_data; end
                4'd7 : begin 
                        width[7:0] <= uart_out_data;
                        start_image <= 1;
                    end
                default: begin end
            endcase
            reg_counter <= reg_counter + 1;
        end
    end

    // Tying this to 0 causes reg_counter [0] to be 0 because of the assignment on line 52
    assign rgb_led0_r = 0;
    assign rgb_led0_b = 1;
    assign rgb_led0_g = 1;

    // LED
    reg [22:0] ledCounter;
    always @(posedge clk48) begin
        ledCounter <= ledCounter + 1;
    end
    // assign rgb_led0_g = ~data_valid;
    // assign rgb_led0_r = ~out_counter[ 1 ];
    // assign rgb_led0_b = ~out_counter[ 2 ];

    // Generate reset signal
    reg [5:0] reset_cnt = 0;
    wire reset = ~reset_cnt[5];
    always @(posedge clk48)
        reset_cnt <= reset_cnt + reset;

    // uart pipeline in
    assign uart_out_ready = 1;
  
endmodule