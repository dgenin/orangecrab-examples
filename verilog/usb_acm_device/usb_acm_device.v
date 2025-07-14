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
    reg [15:0] reg0;
    reg [15:0] reg1;
    // reg [7:0] reg2;
    // reg [7:0] reg3;
    reg [31:0] out_reg;
    reg [2:0] reg_counter = 0;

    // Getting an extra character at the start of a burst 
    always @(negedge clk48) begin
          if ((uart_in_valid == 1) && (uart_in_ready == 1)) begin
            case (reg_counter)
                3'd0 : begin reg0[15:8] <= uart_out_data; uart_in_data <= uart_out_data; end
                3'd1 : begin reg0[7:0] <= uart_out_data; uart_in_data <= uart_out_data; end
                3'd2 : begin reg1[15:8] <= uart_out_data; uart_in_data <= uart_out_data; end
                3'd3 : begin reg1[7:0] <= uart_out_data; uart_in_data <= uart_out_data; end
                // The multiplier can't keep up so the highest byte is sent a full `always` cycle later
                3'd4 : begin out_reg <= reg0*reg1; uart_in_data <= out_reg[31:24];  end
//                3'd5 : uart_in_data <= out_reg[31:24];
                3'd5 : uart_in_data <= out_reg[23:16];
                3'd6 : uart_in_data <= out_reg[15:8];
                3'd7 : uart_in_data <= out_reg[7:0];
            endcase 
            reg_counter <= reg_counter + 1;
        end
    end
        

    wire clk48;

    // Tying this to 0 causes reg_counter [0] to be 0 because of the assignment on line 52
    // assign rgb_led0_r = 0;
    // assign rgb_led0_b = 1;
    assign rgb_led0_g = 1;

    // LED
    reg [22:0] ledCounter;
    always @(posedge clk48) begin
        ledCounter <= ledCounter + 1;
    end
    // assign rgb_led0_g = ~ledCounter[ 22 ];
    assign rgb_led0_r = ~reg_counter[ 0 ];
    assign rgb_led0_b = ~reg_counter[ 1 ];

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
    // assign uart_in_data = reg0;
    // assign uart_out_data = uart_in_data;
    wire uart_in_valid;
    wire uart_in_ready;


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
        .uart_out_valid( uart_in_valid ),
        .uart_out_ready( uart_in_ready  )
    );

    // USB Host Detect Pull Up
    assign usb_pullup = 1'b1;

    assign usb_p_rx = usb_tx_en ? 1'b1 : usb_p_in;
    assign usb_n_rx = usb_tx_en ? 1'b0 : usb_n_in;

    BB io_p( .I( usb_p_tx ), .T( !usb_tx_en ), .O( usb_p_in ), .B( usb_d_p ) );
    BB io_n( .I( usb_n_tx ), .T( !usb_tx_en ), .O( usb_n_in ), .B( usb_d_n ) );

endmodule
