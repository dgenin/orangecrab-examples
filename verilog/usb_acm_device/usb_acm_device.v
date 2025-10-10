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

    mandelbrot_uut uut (.clk48(clk48),
                    .uart_out_ready(uart_out_ready),
                    .uart_out_valid(uart_out_valid),
                    .uart_out_data(uart_out_data),
                    .uart_in_ready(uart_in_ready),
                    .uart_in_valid(uart_in_valid),
                    .uart_in_data(uart_in_data));


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