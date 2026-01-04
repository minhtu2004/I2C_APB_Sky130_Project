`timescale 1ns / 1ps

module i2c_master_top #
(
    parameter DATA_WIDTH = 8,
    parameter FIFO_DEPTH = 64
)
(
    input  wire                   clk,
    input  wire                   rst,

    // TX Path: Interface to load data into FIFO [cite: 56-57]
    input  wire [DATA_WIDTH-1:0]  s_axis_data_tdata,
    input  wire                   s_axis_data_tvalid,
    output wire                   s_axis_data_tready,
    input  wire                   s_axis_data_tlast,

    // I2C Command Interface [cite: 57-59]
    input  wire [6:0]             s_axis_cmd_address,
    input  wire                   s_axis_cmd_start,
    input  wire                   s_axis_cmd_read,
    input  wire                   s_axis_cmd_write,
    input  wire                   s_axis_cmd_write_multiple,
    input  wire                   s_axis_cmd_stop,
    input  wire                   s_axis_cmd_valid,
    output wire                   s_axis_cmd_ready,

    // I2C Read Data Interface (Master to Host) [cite: 60]
    output wire [7:0]             m_axis_data_tdata,
    output wire                   m_axis_data_tvalid,
    input  wire                   m_axis_data_tready,
    output wire                   m_axis_data_tlast,

    // Physical I2C Interface [cite: 61-62]
    input  wire                   scl_i,
    output wire                   scl_o,
    output wire                   scl_t,
    input  wire                   sda_i,
    output wire                   sda_o,
    output wire                   sda_t,

    // Configuration & Status [cite: 62-63]
    input  wire [15:0]            prescale,
    input  wire                   stop_on_idle,
    output wire                   busy,
    output wire                   missed_ack
);

    // Internal signals between FIFO and I2C Master [cite: 64-67]
    wire [DATA_WIDTH-1:0] fifo_to_i2c_tdata;
    wire                  fifo_to_i2c_tvalid;
    wire                  fifo_to_i2c_tready;
    wire                  fifo_to_i2c_tlast;

    // TX FIFO Instantiation [cite: 67-68]
    axis_fifo #(
        .DEPTH(FIFO_DEPTH),
        .DATA_WIDTH(DATA_WIDTH),
        .KEEP_ENABLE(0),
        .LAST_ENABLE(1),
        .PIPELINE_OUTPUT(2)
    ) tx_fifo_inst (
        .clk(clk), .rst(rst),
        .s_axis_tdata(s_axis_data_tdata),
        .s_axis_tkeep(1'b1),
        .s_axis_tvalid(s_axis_data_tvalid),
        .s_axis_tready(s_axis_data_tready),
        .s_axis_tlast(s_axis_data_tlast),
        .s_axis_tid(8'd0), .s_axis_tdest(8'd0), .s_axis_tuser(1'b0),
        .m_axis_tdata(fifo_to_i2c_tdata),
        .m_axis_tvalid(fifo_to_i2c_tvalid),
        .m_axis_tready(fifo_to_i2c_tready),
        .m_axis_tlast(fifo_to_i2c_tlast),
        .m_axis_tkeep(), .m_axis_tid(), .m_axis_tdest(), .m_axis_tuser(),
        .status_overflow(), .status_bad_frame(), .status_good_frame(), .status_full(), .status_empty()
    );

    // I2C Master Core Instantiation [cite: 69-71]
    i2c_master i2c_master_inst (
        .clk(clk), .rst(rst),
        .s_axis_cmd_address(s_axis_cmd_address),
        .s_axis_cmd_start(s_axis_cmd_start),
        .s_axis_cmd_read(s_axis_cmd_read),
        .s_axis_cmd_write(s_axis_cmd_write),
        .s_axis_cmd_write_multiple(s_axis_cmd_write_multiple),
        .s_axis_cmd_stop(s_axis_cmd_stop),
        .s_axis_cmd_valid(s_axis_cmd_valid),
        .s_axis_cmd_ready(s_axis_cmd_ready),
        .s_axis_data_tdata(fifo_to_i2c_tdata),
        .s_axis_data_tvalid(fifo_to_i2c_tvalid),
        .s_axis_data_tready(fifo_to_i2c_tready),
        .s_axis_data_tlast(fifo_to_i2c_tlast),
        .m_axis_data_tdata(m_axis_data_tdata),
        .m_axis_data_tvalid(m_axis_data_tvalid),
        .m_axis_data_tready(m_axis_data_tready),
        .m_axis_data_tlast(m_axis_data_tlast),
        .scl_i(scl_i), .scl_o(scl_o), .scl_t(scl_t),
        .sda_i(sda_i), .sda_o(sda_o), .sda_t(sda_t),
        .busy(busy), .bus_control(), .bus_active(), .missed_ack(missed_ack),
        .prescale(prescale), .stop_on_idle(stop_on_idle)
    );
endmodule
