// ------------------------ Disclaimer -----------------------
// No warranty of correctness, synthesizability or 
// functionality of this code is given.
// Use this code under your own risk.
// When using this code, copy this disclaimer at the top of 
// Your file
//
// (c) Luca Hanel 2020
//
// ------------------------------------------------------------
//
// Module name: wishbone_interconnect
// 
// Functionality: My try at a wishbone interconnect
//                sm: slave->master signals
//                ms: master->slave signals
//                mi: master->interconnect signals
//                im: interconnect->master signals
//
// Tests: Single master, single slave                           SUCCESS
//        Single master, multi slave                            SUCCESS
//        Multi master, multi slave, non-simultaneous           SUCCESS
//        Multi master, multi slave, simultaneous read          SUCCESS
//        Multi master, multi slave, simultaneous write         SUCCESS
//        Multi master, multi slave, simultaneous read+write    SUCCESS
//
// TODO: If a slave takes more than one cycle to assert ack and the master
//       changes meanwhile but the new master talks to the same slave, it
//       can happen that the new master gets the ack&data of the old interaction
//
// ------------------------------------------------------------

`include "wb_intf.sv"

module wb_xbar
#(
    parameter TAGSIZE = 2,
    parameter WB_ADDR_W = 32,
    parameter WB_SLV_SEL_W = 4,
    parameter N_SLAVE,
    parameter N_MASTER
)(
/* verilator lint_off UNDRIVEN */
    input logic                     clk_i,
    input logic                     rst_i,       // Active high (as per spec)
    
    // MASTERS
    wb_bus_t.slave                   wb_slave_port[N_MASTER],
    // SLAVES
    wb_bus_t.master                  wb_master_port[N_SLAVE]
);

// master signals
logic [N_MASTER-1:0][31:0]        ms_dat_i;  // master->interconnect data
logic [N_MASTER-1:0][TAGSIZE-1:0] ms_tgd_i;  // data in tag 
logic [N_MASTER-1:0][31:0]        ms_adr_i;  // master->interconnect address
logic [N_MASTER-1:0][TAGSIZE-1:0] ms_tga_i;  // address tag
logic [N_MASTER-1:0]              ms_cyc_i;  // transaction cycle in progress
logic [N_MASTER-1:0][TAGSIZE-1:0] ms_tgc_i;  // transaction cycle tag
logic [N_MASTER-1:0][3:0]         ms_sel_i;  // select where the data on the data bus (8-bit granularity assumed)
logic [N_MASTER-1:0]              ms_stb_i;  // strobe out, valid data transfer. Slave responds with ack, err or retry to assertion
logic [N_MASTER-1:0]              ms_we_i;   // write enable
logic [N_MASTER-1:0]              mi_lock_i; // lock the interconnect
logic [31:0]                      sm_dat_o;  // interconnect -> master data
logic [TAGSIZE-1:0]               sm_tgd_o;  // data out tag
logic                             sm_ack_o;  // slave ack
logic                             sm_err_o;  // slave encountered error
logic                             sm_rty_o;  // retry request from slave
logic [N_MASTER-1:0]              im_gnt_o; // Grant master the bus

// slave signals
logic [N_SLAVE-1:0][31:0]        sm_dat_i;  // Data from slave
logic [N_SLAVE-1:0][TAGSIZE-1:0] sm_tgd_i;  // data tag
logic [N_SLAVE-1:0]              sm_ack_i;  // slave ack
logic [N_SLAVE-1:0]              sm_err_i;  // slave encountered error
logic [N_SLAVE-1:0]              sm_rty_i;  // retry request from slave
logic [31:0]                     ms_dat_o; // data to slave
logic [TAGSIZE-1:0]              ms_tgd_o; // data tag
logic [31:0]                     ms_adr_o; // addr to slave
logic [TAGSIZE-1:0]              ms_tga_o; // addr tag
logic [N_SLAVE-1:0]              ms_cyc_o; // Transaction cycle in progress
logic [TAGSIZE-1:0]              ms_tgc_o; // cyc tag
logic [3:0]                      ms_sel_o; // select where the data on the data bus (8-bit granularity assumed)
logic [N_SLAVE-1:0]              ms_stb_o; // strobe out, valid data transmission
logic                            ms_we_o;  // write enable


genvar ii;

// connect master signals to local signals
for(ii = 0; ii < N_MASTER; ii = ii + 1) begin
    // inputs
    assign ms_dat_i[ii]  = wb_slave_port[ii].wb_dat_ms;
    assign ms_tgd_i[ii]  = wb_slave_port[ii].wb_tgd_ms;
    assign ms_adr_i[ii]  = wb_slave_port[ii].wb_adr;
    assign ms_tga_i[ii]  = wb_slave_port[ii].wb_tga;
    assign ms_cyc_i[ii]  = wb_slave_port[ii].wb_cyc;
    assign ms_tgc_i[ii]  = wb_slave_port[ii].wb_tgc;
    assign ms_sel_i[ii]  = wb_slave_port[ii].wb_sel;
    assign ms_stb_i[ii]  = wb_slave_port[ii].wb_stb;
    assign ms_we_i[ii]   = wb_slave_port[ii].wb_we;
    assign mi_lock_i[ii] = wb_slave_port[ii].wb_lock;
    // outputs
    assign wb_slave_port[ii].wb_dat_sm = sm_dat_o;
    assign wb_slave_port[ii].wb_tgd_sm = sm_tgd_o;
    assign wb_slave_port[ii].wb_ack = sm_ack_o;
    assign wb_slave_port[ii].wb_err = sm_err_o;
    assign wb_slave_port[ii].wb_rty = sm_rty_o;
    assign wb_slave_port[ii].wb_gnt = im_gnt_o[ii];
end

// connect slave signals to local signals
for(ii = 0; ii < N_SLAVE; ii = ii + 1) begin
    // inputs
    assign sm_dat_i[ii] = wb_master_port[ii].wb_dat_sm;
    assign sm_tgd_i[ii] = wb_master_port[ii].wb_tgd_sm;
    assign sm_ack_i[ii] = wb_master_port[ii].wb_ack;
    assign sm_err_i[ii] = wb_master_port[ii].wb_err;
    assign sm_rty_i[ii] = wb_master_port[ii].wb_rty;
    // outputs
    assign wb_master_port[ii].wb_dat_ms = ms_dat_o;
    assign wb_master_port[ii].wb_tgd_ms = ms_tgd_o;
    assign wb_master_port[ii].wb_adr = ms_adr_o;
    assign wb_master_port[ii].wb_tga = ms_tga_o;
    assign wb_master_port[ii].wb_cyc = ms_cyc_o[ii];
    assign wb_master_port[ii].wb_tgc = ms_tgc_o;
    assign wb_master_port[ii].wb_sel = ms_sel_o;
    assign wb_master_port[ii].wb_stb = ms_stb_o[ii];
    assign wb_master_port[ii].wb_we  = ms_we_o;
end


logic [$clog2(N_SLAVE)-1:0]      slave_select;
logic [N_MASTER-1:0] master_arbiter_n;
logic [N_MASTER-1:0] master_arbiter_q;
logic [31:0]         ms_adr;
logic                ms_cyc;
logic                ms_stb;

logic                locked_n;
logic                locked_q;

assert property (@(posedge clk_i) $onehot0(master_arbiter_q));

// Master arbiter select block
// sets master_arbiter to one-hot or 0
always_comb
begin
    master_arbiter_n = master_arbiter_q;
    locked_n         = locked_q;

    // Free the bus if not used
    if((master_arbiter_q & ms_cyc_i) == 'b0) begin
        master_arbiter_n = 'b0;
        locked_n         = 1'b0;
    end

    // Give the bus to the highest priority (LSB) master
    for(int i = N_MASTER-1; i >= 0; i = i - 1) begin
        if(ms_cyc_i[i] && !locked_q) begin
            master_arbiter_n = 'b0 | (1 << i);
            locked_n         = mi_lock_i[i]; // lock the bus if requested
        end
    end
end

// Master arbiter
always_comb
begin
    im_gnt_o = 'b0;
    ms_dat_o = '0;
    ms_adr   = '0;
    ms_tgd_o = '0;
    ms_tga_o = '0;
    ms_cyc   = '0;
    ms_tgc_o = '0;
    ms_sel_o = '0;
    ms_stb   = '0;
    ms_we_o  = '0;
    for(int i = 0; i < N_MASTER; i = i + 1) begin
        if(master_arbiter_q == (1 << i)) begin
            // Give the master the bus
            im_gnt_o[i] = 1'b1;
            // mux the data from master to slave
            ms_dat_o = ms_dat_i[i];
            ms_adr   = ms_adr_i[i];
            ms_tgd_o = ms_tgd_i[i];
            ms_tga_o = ms_tga_i[i];
            ms_cyc   = ms_cyc_i[i];
            ms_tgc_o = ms_tgc_i[i];
            ms_sel_o = ms_sel_i[i];
            ms_stb   = ms_stb_i[i];
            ms_we_o  =  ms_we_i[i];
        end
    end
end

// slave select
/* verilator lint_off WIDTH */
assign slave_select = ms_adr[WB_ADDR_W-1: WB_ADDR_W - WB_SLV_SEL_W];
/* verilator lint_on WIDTH */

// Slave arbiter
always_comb
begin
    ms_cyc_o = 'b0;
    ms_stb_o = 'b0;
    ms_adr_o = 'b0;

    ms_adr_o[WB_ADDR_W-WB_SLV_SEL_W-1:0] = ms_adr[WB_ADDR_W-WB_SLV_SEL_W-1:0];
    
    ms_cyc_o[slave_select] = ms_cyc;
    ms_stb_o[slave_select] = ms_stb;

    sm_ack_o = sm_ack_i[slave_select];
    sm_dat_o = sm_dat_i[slave_select];
    sm_tgd_o = sm_tgd_i[slave_select];
    sm_err_o = sm_err_i[slave_select];
    sm_rty_o = sm_rty_i[slave_select];
end

always_ff @(posedge clk_i, posedge rst_i)
begin
    if(rst_i) begin
        
    end else begin
        locked_q         <= locked_n;
        master_arbiter_q <= master_arbiter_n;
    end
end

endmodule