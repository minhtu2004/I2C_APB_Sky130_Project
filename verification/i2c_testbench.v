`timescale 1ns / 1ps

module tb_i2c_apb_system;

    // APB Signals
    reg         PCLK = 0;
    reg         PRESETn = 0;
    reg [7:0]   PADDR = 0;
    reg         PSEL = 0;
    reg         PENABLE = 0;
    reg         PWRITE = 0;
    reg [31:0]  PWDATA = 0;
    wire [31:0] PRDATA;
    wire        PREADY;

    // I2C Physical Pins
    wire scl_i, scl_o, scl_t;
    wire sda_i, sda_o, sda_t;

    // DUT
    i2c_apb_wrapper dut (
        .pclk(PCLK), .penable(PENABLE), .pready(PREADY), .presetn(PRESETn),
        .psel(PSEL), .pwrite(PWRITE), .paddr(PADDR), .prdata(PRDATA),
        .pwdata(PWDATA), .scl_i(scl_i), .scl_o(scl_o), .scl_t(scl_t),
        .sda_i(sda_i), .sda_o(sda_o), .sda_t(sda_t)
    );

    // I2C Bus Pull-up & Mock Slave Logic
    reg sda_slave_drive = 1'bz;
    assign sda_i = (sda_o === 1'b0 || sda_slave_drive === 1'b0) ? 1'b0 : 1'b1;
    assign scl_i = (scl_o === 1'b0) ? 1'b0 : 1'b1;

    reg [3:0] bit_cnt = 0;
    always @(posedge scl_i or negedge PRESETn) begin
        if (!PRESETn) bit_cnt <= 0;
        else if (bit_cnt == 9) bit_cnt <= 1;
        else bit_cnt <= bit_cnt + 1;
    end
    always @(negedge scl_i) begin
        if (bit_cnt == 8) sda_slave_drive <= 1'b0; // Send ACK
        else sda_slave_drive <= 1'bz;
    end

    // Clock
    always #5 PCLK = ~PCLK;

    // APB Write Task
    task apb_write(input [7:0] addr, input [31:0] data);
        begin
            @(posedge PCLK); PADDR = addr; PWDATA = data; PWRITE = 1; PSEL = 1;
            @(posedge PCLK); PENABLE = 1;
            wait(PREADY === 1'b1);
            @(posedge PCLK); PSEL = 0; PENABLE = 0;
        end
    endtask

    initial begin
        $dumpfile("i2c_gls_fixed.vcd");
        $dumpvars(0, tb_i2c_apb_system);

        // 1. Reset chip
        PRESETn = 0; #500 PRESETn = 1; #500;

        // 2. CONFIG: Nạp Prescale (0x08)
        $display("[%t] CONFIG: Set Prescale", $time);
        apb_write(32'h08, 32'd20);

        // 3. CONFIG: Nạp I2C Address (0x04) - Slave 0x50
        $display("[%t] CONFIG: Set Slave Address 0x50", $time);
        apb_write(32'h04, 32'h50);

        // 4. DATA: Nạp dữ liệu 0xAA vào FIFO (0x0C)
        $display("[%t] DATA: Load 0xAA to TX FIFO", $time);
        apb_write(32'h0C, 32'hAA);

        // 5. COMMAND: Phát START + WRITE (0x00)
        // Bit 0 = Start, Bit 3 = Write. Giá trị 0x09 (00001001)
        $display("[%t] COMMAND: START + WRITE", $time);
        apb_write(32'h00, 32'h09);

        #2000000;
        $display("[%t] FINISH: Simulation complete", $time);
        $finish;
    end
endmodule
