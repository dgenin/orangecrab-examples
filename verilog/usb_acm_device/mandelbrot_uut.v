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
                res_r_sqr = ({ {16{res_r[15]}}, res_r[15:0] }*{ {16{res_r[15]}}, res_r[15:0] })>>>13;
                res_i_sqr = ({ {16{res_i[15]}}, res_i[15:0] }*{ {16{res_i[15]}}, res_i[15:0] })>>>13;
                // 1<<14 is 1 in fixed point
                running = ((res_r_sqr + res_i_sqr) <= 20'h8000);
                if (running) begin
                    // Need to sign extend cr and ci for signed arithmetic to work
                    res_r <= res_r_sqr - res_i_sqr + { {16{cr[15]}}, cr[15:0] };
                    // Need to ensure there are enough bits for the result of res_r*res_i, before the right
                    // shift. Generally, that will be double the bit width of res_r/res_i
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
    reg signed [15:0] ci_0, ci_1, ci_2, ci_3;
    reg [3:0] reg_counter = 0;
    wire [15:0] iter_counter_0, iter_counter_1, iter_counter_2, iter_counter_3, iter_counter_4;
    wire data_valid_0, data_valid_1, data_valid_2, data_valid_3, data_valid_4;
    reg [3:0] data_valid;
    reg data_ready = 0;
    reg start_iter = 0;
    reg [15:0] clock_counter = 16'd0;

    f_iter mandel_iter_0 (.clk48(clk48), .cr(cr), .ci(ci_0), .start_iter(start_iter), .data_valid(data_valid_0), .iter_counter_out(iter_counter_0));
    f_iter mandel_iter_1 (.clk48(clk48), .cr(cr), .ci(ci_1), .start_iter(start_iter), .data_valid(data_valid_1), .iter_counter_out(iter_counter_1));
    f_iter mandel_iter_2 (.clk48(clk48), .cr(cr), .ci(ci_2), .start_iter(start_iter), .data_valid(data_valid_2), .iter_counter_out(iter_counter_2));
    f_iter mandel_iter_3 (.clk48(clk48), .cr(cr), .ci(ci_3), .start_iter(start_iter), .data_valid(data_valid_3), .iter_counter_out(iter_counter_3));
    // f_iter mandel_iter_4 (.clk48(clk48), .cr(cr), .ci(ci_3), .start_iter(start_iter), .data_valid(data_valid_4), .iter_counter_out(iter_counter_4));

    // Reader
    always @(posedge clk48) begin
        if (start_iter) begin
            start_iter <= 0;
            reg_counter <= 0;
        end;
        if (uart_out_valid) begin
            case (reg_counter)
                4'd0 : begin cr[15:8] <= uart_out_data; end
                4'd1 : begin cr[7:0] <= uart_out_data; end
                4'd2 : begin ci_0[15:8] <= uart_out_data; end
                4'd3 : begin ci_0[7:0] <= uart_out_data; end
                4'd4 : begin ci_1[15:8] <= uart_out_data; end
                4'd5 : begin ci_1[7:0] <= uart_out_data; end
                4'd6 : begin ci_2[15:8] <= uart_out_data; end
                4'd7 : begin ci_2[7:0] <= uart_out_data; end
                4'd8 : begin ci_3[15:8] <= uart_out_data; end
                4'd9 : begin
                            ci_3[7:0] <= uart_out_data;
                            start_iter <= 1;
                        end
                default: begin end
            endcase
            reg_counter <= reg_counter + 1;
        end
    end

    reg [3:0] out_counter = 4'd9;

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
        if (data_valid_0) begin
            data_valid[0] <= 1;
        end
        if (data_valid_1) begin
            data_valid[1] <= 1;
        end
        if (data_valid_2) begin
            data_valid[2] <= 1;
        end
        if (data_valid_3) begin
            data_valid[3] <= 1;
        end
        if (out_counter > 4'd10) begin
            if (data_valid == 4'd15) begin
                out_counter <= 0;
                data_valid <= 2'd0;
            end;
        end
        else begin
            case (out_counter)
                4'd0 : begin uart_in_data <= cr[15:8]; uart_in_valid = 1; end
                4'd1 : uart_in_data <= iter_counter_0[15:8];
                4'd2 : uart_in_data <= iter_counter_0[7:0];
                4'd3 : uart_in_data <= iter_counter_1[15:8];
                4'd4 : uart_in_data <= iter_counter_1[7:0];
                4'd5 : uart_in_data <= iter_counter_2[15:8];
                4'd6 : uart_in_data <= iter_counter_2[7:0];
                4'd7 : uart_in_data <= iter_counter_3[15:8];
                4'd8 : uart_in_data <= iter_counter_3[7:0];
                4'd9 : uart_in_data <= 8'd66;
                4'd10 : uart_in_valid <= 0;
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