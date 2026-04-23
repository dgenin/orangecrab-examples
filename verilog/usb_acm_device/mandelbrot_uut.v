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
         input wire signed [15:0] cr0, cr1, cr2, cr3,
         input wire signed [15:0] ci0, ci1, ci2, ci3,
         output reg [15:0] iter_counter_out0, iter_counter_out1, iter_counter_out2, iter_counter_out3 = 0,
         input wire start_iter,
         output reg data_valid = 0);

    reg signed [15:0] res_r = 0;
    reg signed [15:0] res_i = 0;
    reg unsigned [1:0] phase_counter = 0;
    reg signed [31:0] res_r_1 = 0;
    reg signed [31:0] res_i_1 = 0;
    reg signed [31:0] res_r_2 = 0;
    reg signed [31:0] res_i_2 = 0;
    reg unsigned[15:0] iter_0 = 0;
    reg unsigned[15:0] iter_1 = 0;

    reg [31:0] r_sqr_0 = 0;
    reg [31:0] i_sqr_0 = 0;
    reg signed [31:0] r_i_prod_0 = 0;
    // reg running = 0;
    reg [15:0] iter_counter = 16'hFFFF;
    reg [3:0] done = 4'd0;
    reg [31:0] norm_1 = 0;

    always @(posedge clk48) begin
        if (start_iter) begin
            iter_counter <= 16'd0;
            iter_counter_out0 <= 16'h0;
            iter_counter_out1 <= 16'h0;
            iter_counter_out2 <= 16'h0;
            iter_counter_out3 <= 16'h0;
            // running = 1'b1;
            // Clear all of the pipeline inputs
            res_r <= 16'h0;
            res_i <= 16'h0;
            res_r_1 <= 32'h0;
            res_i_1 <= 32'h0;
            res_r_2 <= 32'h0;
            res_i_2 <= 32'h0;
            r_sqr_0 <= 32'h0;
            i_sqr_0 <= 32'h0;
            iter_0 <= 16'h0;
            iter_1 <= 16'h0;
            r_i_prod_0 <= 32'h0;
            norm_1 = 32'h0;
            done <= 4'd0;
            phase_counter <= 2'd0;
        end;
        case (iter_counter)
            16'hFFFF : data_valid <= 0;
            default : 
                if ((done != 4'd15) && (iter_counter <= 16'd800)) begin
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
                        2'd0 : res_i_1 <= r_i_prod_0 + { {16{ci3[15]}}, ci3[15:0] };
                        2'd1 : res_i_1 <= r_i_prod_0 + { {16{ci0[15]}}, ci0[15:0] };
                        2'd2 : res_i_1 <= r_i_prod_0 + { {16{ci1[15]}}, ci1[15:0] };
                        2'd3 : res_i_1 <= r_i_prod_0 + { {16{ci2[15]}}, ci2[15:0] };
                    endcase
                    
                    // Phase 2
                    if (norm_1 >= 21'h8000) begin
                        case (phase_counter)
                            2'd0 : if (done[2] == 0) begin iter_counter_out2 <= iter_1; done[2] <= 1; end
                            2'd1 : if (done[3] == 0) begin iter_counter_out3 <= iter_1; done[3] <= 1; end
                            2'd2 : if (done[0] == 0) begin iter_counter_out0 <= iter_1; done[0] <= 1; end
                            2'd3 : if (done[1] == 0) begin iter_counter_out1 <= iter_1; done[1] <= 1; end
                        endcase
                    end
                    case (phase_counter)
                        2'd0 : res_r_2 <= res_r_1 + { {16{cr2[15]}}, cr2[15:0] };
                        2'd1 : res_r_2 <= res_r_1 + { {16{cr3[15]}}, cr3[15:0] };
                        2'd2 : res_r_2 <= res_r_1 + { {16{cr0[15]}}, cr0[15:0] };
                        2'd3 : res_r_2 <= res_r_1 + { {16{cr1[15]}}, cr1[15:0] };
                    endcase
                    res_i_2 <= res_i_1;
                    
                    // Phase 3
                    // Do not propagate invalid results until the pipeline is fully initialized
                    if ((iter_counter > 16'd0) || (phase_counter > 16'd2)) begin
                        res_r <= res_r_2[15:0];
                        res_i <= res_i_2[15:0];
                    end
                    if (phase_counter == 2'd3) begin
                        iter_counter <= iter_counter + 1;
                    end;

                    phase_counter <= phase_counter + 1;
                end else begin
                    data_valid <= 1;
                    iter_counter <= 16'hFFFF;
                end
        endcase
    end
endmodule

module mandelbrot_uut (
        input  clk48,

		output uart_out_ready,
  		input uart_out_valid,
  		input [7:0] uart_out_data,
  
  		output reg uart_in_valid = 0,
  		input uart_in_ready,
		output reg [7:0] uart_in_data,
  	
        output rgb_led0_r,
        output rgb_led0_g,
        output rgb_led0_b
    );

	// Code your design here
    // Mandelbrot input registers
    reg signed [15:0] cr = 16'hFFFF;
    reg signed [15:0] ci [4:0];
    wire [15:0] iter_counter [4:0];
    // wire [4:0] data_valid_in;
    wire [0:0] data_valid_in;
    // reg [4:0] data_valid = 5'd0;
    reg [0:0] data_valid = 1'd0;
    reg data_ready = 0;
    reg start_iter = 0;
    reg [15:0] clock_counter = 16'd0;

    // genvar i;
    // generate
    //     begin
    //         for (i=0; i<5; i = i + 1) begin : mandel_iter_maker
    //             f_iter mandel_iter (.clk48(clk48), .cr(cr), .ci(ci[i]), .start_iter(start_iter), .data_valid(data_valid_in[i]), .iter_counter_out(iter_counter[i]));
    //         end
    //     end
    // endgenerate;

    f_iter_pipe mandel_iter (.clk48(clk48), .cr0(cr), .cr1(cr), .cr2(cr), .cr3(cr),
                               .ci0(ci[0]), .ci1(ci[1]), .ci2(ci[2]), .ci3(ci[3]),
                               .start_iter(start_iter), .data_valid(data_valid_in[0]),
                               .iter_counter_out0(iter_counter[0]), .iter_counter_out1(iter_counter[1]),
                               .iter_counter_out2(iter_counter[2]), .iter_counter_out3(iter_counter[3]));

    // Reader
    reg [3:0] reg_counter = 0;
    always @(posedge clk48) begin
        if (start_iter) begin
            start_iter <= 0;
            reg_counter <= 0;
        end;
        if (uart_out_valid) begin
            case (reg_counter)
                4'd0 : begin cr[15:8] <= uart_out_data; end
                4'd1 : begin cr[7:0] <= uart_out_data; end
                4'd2 : begin ci[0][15:8] <= uart_out_data; end
                4'd3 : begin ci[0][7:0] <= uart_out_data; end
                4'd4 : begin ci[1][15:8] <= uart_out_data; end
                4'd5 : begin ci[1][7:0] <= uart_out_data; end
                4'd6 : begin ci[2][15:8] <= uart_out_data; end
                4'd7 : begin ci[2][7:0] <= uart_out_data; end
                4'd8 : begin ci[3][15:8] <= uart_out_data; end
                4'd9 : begin ci[3][7:0] <= uart_out_data; end
                4'd10 : begin ci[4][15:8] <= uart_out_data; end
                4'd11 : begin
                            ci[4][7:0] <= uart_out_data;
                            start_iter <= 1;
                        end
                default: begin end
            endcase
            reg_counter <= reg_counter + 1;
        end
    end

    reg [3:0] out_counter = 4'd11;
    // Consumer
    always @(posedge clk48) begin
        if (start_iter)
            begin
                clock_counter <= 0;
            end
        else
            begin
                clock_counter <= clock_counter + 1;
            end
        // if (uart_in_ready && (out_counter < 4'd8)) begin
        // This for-loop makes the timing but
        // the naive simpler data_valid <= data_valid | data_valid_in
        // does not!?
        // for(int i = 0; i < 1; i = i + 1) begin
        //     data_valid[i] <= data_valid[i] | data_valid_in[i];
        // end
        data_valid[0] <= data_valid[0] | data_valid_in[0];
        if (out_counter > 4'd12) begin
            // if (data_valid == 5'd1) begin
            if (data_valid == 1'd1) begin
                out_counter <= 0;
                // data_valid <= 5'd0;
                data_valid <= 1'd0;
            end;
        end
        else begin
            case (out_counter)
                // 1'd0 : begin uart_in_valid = 1; uart_in_data <= iter_counter[out_counter[3:1]][15:8]; end
                // 1'd1 : uart_in_data <= iter_counter[out_counter[3:1]][7:0];
                4'd0 : begin uart_in_data <= 8'd0; uart_in_valid = 1; end
                4'd1 : uart_in_data <= iter_counter[0][15:8];
                4'd2 : uart_in_data <= iter_counter[0][7:0];
                4'd3 : uart_in_data <= iter_counter[1][15:8];
                4'd4 : uart_in_data <= iter_counter[1][7:0];
                4'd5 : uart_in_data <= iter_counter[2][15:8];
                4'd6 : uart_in_data <= iter_counter[2][7:0];
                4'd7 : uart_in_data <= iter_counter[3][15:8];
                4'd8 : uart_in_data <= iter_counter[3][7:0];
                4'd9 : uart_in_data <= iter_counter[4][15:8];
                4'd10 : uart_in_data <= iter_counter[4][7:0];
                4'd11 : uart_in_valid <= 0;
            endcase;
            out_counter <= out_counter + 1;
        end;
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
    // Why is uart_in_ready always low???
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