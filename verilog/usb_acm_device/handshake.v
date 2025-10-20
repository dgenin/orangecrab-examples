module handshake_test ();
    reg clk = 1'b0;
    reg reset = 1'b1;
    always #1 clk <= !clk;
    reg data_valid;
    reg data_ready;
    reg internal_data_ready;
    reg [7:0] data;
    reg [7:0] internal_data;

    initial begin
        #1 
        data_valid <= 0;
        data_ready <= 0;
        internal_data_ready <= 0;
        data <= 0;
        internal_data <= 0;
        $dumpfile("dump.vcd"); $dumpvars;
        #5
        reset <= 1'b0;
        #100
        $finish();
    end;

    always @(posedge clk) begin
        if (reset) begin
            internal_data_ready <= 1'b1;
            data_valid <= 1'b1;
            data <= 8'b0;
        end else begin
            if (internal_data_ready) begin
                data_valid <= 1'b1;
                internal_data_ready <= 1'b0;
            end
            if (data_valid & data_ready) begin
                data_valid <= 1'b0;
                data <= data + 1;
                internal_data_ready <= 1'b1;
            end
        end
    end

    always @(posedge clk) begin
        if (reset) begin
            data_ready <= 1'b1;
        end else begin
            // if (data_valid) begin
            //     data_ready <= 1'b0;
            // end
            if (data_valid) begin
                internal_data <= data;
                data_ready <= 1'b1;
            end
        end
    end

endmodule