`timescale 1ns / 1ps

module i2c_apb_wrapper #
(
    parameter ADDR_WIDTH = 8,
    parameter DATA_WIDTH = 32
)
(
    input  wire                   pclk,
    input  wire                   presetn,
    input  wire [ADDR_WIDTH-1:0]  paddr,
    input  wire                   psel,
    input  wire                   penable,
    input  wire                   pwrite,
    input  wire [DATA_WIDTH-1:0]  pwdata,
    output reg  [DATA_WIDTH-1:0]  prdata,
    output wire                   pready,

    input  wire scl_i, output wire scl_o, output wire scl_t,
    input  wire sda_i, output wire sda_o, output wire sda_t
);

    reg [6:0]  reg_i2c_addr;
    reg [15:0] reg_prescale;
    reg [7:0]  reg_ctrl;      // Latch command bits: [0]:start, [2]:read, [3]:write, [5]:stop [cite: 75-77]
    reg        reg_cmd_valid;
    
    wire [7:0] i2c_rx_data;
    wire i2c_rx_valid, i2c_busy, i2c_missed_ack;

    wire apb_write_setup = psel && pwrite && penable;
    assign pready = 1'b1;

    // --- WRITE PATH --- [cite: 81-85]
    always @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            reg_i2c_addr  <= 7'd0;
            reg_prescale  <= 16'd250; 
            reg_ctrl      <= 8'd0;
            reg_cmd_valid <= 1'b0;
        end else begin
            reg_cmd_valid <= 1'b0; 
            if (apb_write_setup) begin
                case (paddr[7:0])
                    8'h00: begin 
                        reg_cmd_valid <= 1'b1;
                        reg_ctrl      <= pwdata[7:0]; // Latch bits 
                    end
                    8'h04: reg_i2c_addr  <= pwdata[6:0];
                    8'h08: reg_prescale  <= pwdata[15:0];
                endcase
            end
        end
    end

    // --- READ PATH (Synchronous Fix) --- 
    always @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            prdata <= 32'd0;
        end else begin
            case (paddr[7:0])
                8'h00: prdata <= {24'd0, reg_ctrl};
                8'h04: prdata <= {25'd0, reg_i2c_addr};
                8'h08: prdata <= {16'd0, reg_prescale};
                8'h10: prdata <= {24'd0, i2c_rx_data};
                8'h14: prdata <= {28'd0, 1'b0, 1'b0, i2c_missed_ack, i2c_busy};
                default: prdata <= 32'd0;
            endcase
        end
    end

    i2c_master_top #(.FIFO_DEPTH(64)) i2c_sys_inst (
        .clk(pclk), .rst(!presetn),
        .s_axis_data_tdata(pwdata[7:0]),
        .s_axis_data_tvalid(apb_write_setup && (paddr[7:0] == 8'h0C)),
        .s_axis_data_tready(),
        .s_axis_data_tlast(pwdata[8]),
        .s_axis_cmd_address(reg_i2c_addr),
        .s_axis_cmd_start(reg_ctrl[0]), 
        .s_axis_cmd_read(reg_ctrl[2]),
        .s_axis_cmd_write(reg_ctrl[3]),
        .s_axis_cmd_write_multiple(reg_ctrl[4]),
        .s_axis_cmd_stop(reg_ctrl[5]),
        .s_axis_cmd_valid(reg_cmd_valid),
        .s_axis_cmd_ready(),
        .m_axis_data_tdata(i2c_rx_data), .m_axis_data_tvalid(i2c_rx_valid),
        .m_axis_data_tready(1'b1), .m_axis_data_tlast(),
        .scl_i(scl_i), .scl_o(scl_o), .scl_t(scl_t),
        .sda_i(sda_i), .sda_o(sda_o), .sda_t(sda_t),
        .prescale(reg_prescale), .busy(i2c_busy), .missed_ack(i2c_missed_ack),
        .stop_on_idle(1'b0)
    );
endmodule
