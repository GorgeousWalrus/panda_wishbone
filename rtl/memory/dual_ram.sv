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
// Module name: dual_ram
// 
// Functionality: Simple ram with dual read, single write ports
//
// ------------------------------------------------------------

module dual_ram #(
    parameter SIZE = 1024
)(
    input logic           clk,
    input logic           rstn_i,
    // First port, read only
    input logic [31:0]    addra_i,
    input logic           ena_i,
    output logic [31:0]   douta_o,
    // Second port, read & write
    input logic [31:0]    addrb_i,
    input logic           enb_i,
    input logic [3:0]     web_i,
    input logic [31:0]    dinb_i,
    output logic [31:0]   doutb_o
);

logic [31:0]    addra;
logic [31:0]    addrb;

(*ram_style = "block" *) reg [31:0] data[SIZE];

initial begin
    data[0]      = 32'b000000010000_00000_000_00001_0010011;     // addi 16, x0, x1;
    data[1]      = 32'b000000000001_00010_000_00010_0010011;     // addi 1, x2, x2;
    data[2]      = 32'b1111111_00001_00010_100_11101_1100011;    // blt x2, x1, -2
    data[3]      = 32'b000000_00010_00000_010_11000_0100011;     // sw x2, 24+x0;
end

assign addra = $signed(addra_i >> 2);
assign addrb = $signed(addrb_i >> 2);

always_comb
begin
    if(ena_i)
        douta_o = data[addra];

    if(enb_i)
        doutb_o = data[addrb];
end

always_ff @(posedge clk, negedge rstn_i)
begin
    if(!rstn_i) begin
    end else begin
        if(enb_i) begin
            case(web_i)
                4'b1111:
                    data[addrb] <= dinb_i;
                
                4'b0011:
                    data[addrb][15:0] <= dinb_i[15:0];
                
                4'b0001:
                    data[addrb][7:0] <= dinb_i[7:0];
                
                default: begin
                end
            endcase
        end
    end
end

endmodule