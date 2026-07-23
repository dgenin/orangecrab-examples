module mandelbrot_test();
    reg clk48 = 1'b0;
    reg uart_out_valid = 1'b0;
    reg [7:0] uart_out_data = 8'b0;
    wire uart_in_valid;
    wire [7:0] uart_in_data;
    wire uart_out_ready;
    reg uart_in_ready = 1'b1;

    always #1 clk48 <= !clk48;

    mandelbrot_uut uut (.clk48(clk48),
                        .uart_out_ready(uart_out_ready),
                        .uart_out_valid(uart_out_valid),
                        .uart_out_data(uart_out_data),
                        .uart_in_ready(uart_in_ready),
                        .uart_in_valid(uart_in_valid),
                        .uart_in_data(uart_in_data));

    initial begin
// '0xe0', '0x0', '0xe8', '0x0', '0xe8', '0x6', '0xe8', '0xb', '0xe8', '0x10', '0xe8', '0x15'
        $dumpfile("dump.vcd"); $dumpvars;
        #10
        uart_in_ready = 1'b1;
        uart_out_valid = 1'b1;
        uart_out_data = 8'h0e;
        #2
        uart_out_data = 8'h00;
        #2
        uart_out_data = 8'he8;
        #2
        uart_out_data = 8'h00;
        #2
        uart_out_data = 8'he8;
        #2
        uart_out_data = 8'h00;
        #2
        uart_out_data = 8'he8;
        #2
        uart_out_data = 8'h00;
        #2
        uart_out_data = 8'he8;
        #2
        uart_out_data = 8'h00;
        #2
        uart_out_data = 8'he8;
        #2
        uart_out_data = 8'h00;
        #2
        uart_out_data = 8'hcc;
        #2
        uart_out_valid = 1'b0;
        #1000
        $finish();
    end;

endmodule;