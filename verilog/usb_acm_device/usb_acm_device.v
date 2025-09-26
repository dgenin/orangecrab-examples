module f_iter(
         input wire [15:0] zr,
         input wire [15:0] zi,
         input wire [15:0] cr,
         input wire [15:0] ci,
         output reg [15:0] res_r,
         output reg [15:0] res_i,
         inout wire start_iter,
         inout wire data_valid);
//         output reg valid);

    reg [7:0] iter_counter = 0;

    always @(posedge clk48) begin
        if (start_iter) begin
            start_iter <= 0;
            iter_counter <= 1;
        end;
        if (iter_counter > 0) begin
//            res_r <= zr*zr - zi*zi + cr;
//            res_i <= 2*zr*zi + ci;
            res_r <= 16'h4142;
            res_i <= 16'h4344;
            iter_counter <= iter_counter - 1;
        end
        else begin
            // data_valid <= 1;
        end;
    end


endmodule



/*
 *  Create USB device on the OrangeCrab using verilog
 */


module usb_acm_device (
        input  clk48,

        inout  usb_d_p,
        inout  usb_d_n,
        output usb_pullup,

        output rgb_led0_r,
        output rgb_led0_g,
        output rgb_led0_b
    );

    // Mandelbrot input registers
    reg [15:0] cr = 16'hFFFF;
    reg [15:0] ci;
    // reg [7:0] reg2;
    // reg [7:0] reg3;
    reg [15:0] res_r, res_i;
    reg [2:0] reg_counter = 0;
    reg [15:0] zr = 0, zi = 0;
    reg data_valid = 0, data_ready = 0;
    reg start_iter = 0;

    // Reader
    always @(posedge clk48) begin
//        if (start_iter) begin
//            start_iter <= 0;
//        end;
        if (uart_out_valid) begin
            case (reg_counter)
                3'd0 : cr[15:8] <= uart_out_data;
                3'd1 : cr[7:0] <= uart_out_data;
                3'd2 : ci[15:8] <= uart_out_data;
                3'd3 : ci[7:0] <= uart_out_data;
                3'd4 : res_r[15:8] <= uart_out_data;
                3'd5 : res_r[7:0] <= uart_out_data;
                3'd6 : res_i[15:8] <= uart_out_data;
                3'd7 : begin
                        res_i[7:0] <= uart_out_data;
                        start_iter <= 1;
                        data_valid <= 1;
                    end
            endcase
            reg_counter <= reg_counter + 1;
        end
    end

    f_iter mandel_iter (.zr(zr), .zi(zi), .cr(cr), .ci(ci), .res_r(res_r), .res_i(res_i), .start_iter(start_iter), .data_valid(data_valid));

    reg [3:0] out_counter = 4'd9;
    reg [5:0] data_valid_counter = 0;

    // Consumer
    always @(posedge clk48) begin
        // What is the deal with uart_in_ready? It doesn't ever appear to go high.
        // if (uart_in_ready && (out_counter < 4'd8)) begin
        if (out_counter > 4'd8) begin
            if (data_valid) begin
                // data_valid <= 0;
                out_counter <= 0;
            end;
        end
        else begin
            case (out_counter)
                4'd0 : begin uart_in_data <= cr[15:8]; uart_in_valid <= 1; end
                4'd1 : uart_in_data <= cr[7:0];
                4'd2 : uart_in_data <= ci[15:8];
                4'd3 : uart_in_data <= ci[7:0];
                4'd4 : uart_in_data <= res_r[15:8];
                4'd5 : uart_in_data <= res_r[7:0];
                4'd6 : uart_in_data <= res_i[15:8];
                4'd7 : uart_in_data <= res_i[7:0];
                4'd8 : begin uart_in_valid <= 0; uart_in_data <= 8'd10; end
            endcase;
            if (uart_in_ready && uart_in_valid) begin
                out_counter <= out_counter + 1;
            end;
        end;
        if (data_valid) begin data_valid_counter <= data_valid_counter + 1; end;
//        if (data_valid_counter > 60) begin data_valid <= 0; data_valid_counter <= 0; end; 
    end

    wire clk48;

    // Tying this to 0 causes reg_counter [0] to be 0 because of the assignment on line 52
    // assign rgb_led0_r = 0;
    // assign rgb_led0_b = 1;
    // assign rgb_led0_g = 1;

    // LED
    reg [22:0] ledCounter;
    always @(posedge clk48) begin
        ledCounter <= ledCounter + 1;
    end
    // Why is uart_in_ready always low???
    assign rgb_led0_g = ~data_valid;
    assign rgb_led0_r = ~start_iter;
    assign rgb_led0_b = ~out_counter[ 2 ];

    // Generate reset signal
    reg [5:0] reset_cnt = 0;
    wire reset = ~reset_cnt[5];
    always @(posedge clk48)
        reset_cnt <= reset_cnt + reset;

    // uart pipeline in
    wire [7:0] uart_out_data;
    wire [7:0] uart_in_data;
    // assign uart_in_data[1:0] = reg_counter;
    // assign uart_in_data[7:2] = 6'd16;
    // assign uart_in_data = cr;
    // assign uart_out_data = uart_in_data;
    wire uart_in_valid;
    wire uart_in_ready;
    wire uart_out_valid;
    wire uart_out_ready = 1;


    wire usb_p_in;
    wire usb_n_in;

    wire usb_p_tx;
    wire usb_n_tx;
    wire usb_p_rx;
    wire usb_n_rx;
    wire usb_tx_en;

    // usb uart - this instantiates the entire USB device.
    usb_uart_core uart (
        .clk_48mhz  (clk48),
        .reset      (reset),

        // pins
        .usb_p_tx(usb_p_tx),
        .usb_n_tx(usb_n_tx),
        .usb_p_rx(usb_p_rx),
        .usb_n_rx(usb_n_rx),
        .usb_tx_en(usb_tx_en),

        // uart pipeline in
        .uart_in_data( uart_in_data ),
        .uart_in_valid( uart_in_valid ),
        .uart_in_ready( uart_in_ready ),

        .uart_out_data( uart_out_data ),
        .uart_out_valid( uart_out_valid ),
        .uart_out_ready( uart_out_ready  )
    );

    // USB Host Detect Pull Up
    assign usb_pullup = 1'b1;

    assign usb_p_rx = usb_tx_en ? 1'b1 : usb_p_in;
    assign usb_n_rx = usb_tx_en ? 1'b0 : usb_n_in;

    BB io_p( .I( usb_p_tx ), .T( !usb_tx_en ), .O( usb_p_in ), .B( usb_d_p ) );
    BB io_n( .I( usb_n_tx ), .T( !usb_tx_en ), .O( usb_n_in ), .B( usb_d_n ) );

endmodule