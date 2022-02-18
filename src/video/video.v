`default_nettype none
module video (
  input         clk,
  input         reset,
  output [7:0]  vga_r,
  output [7:0]  vga_b,
  output [7:0]  vga_g,
  output        vga_hs,
  output        vga_vs,
  output        vga_de,
  input  [7:0]  vga_data,
  output [13:0] vga_addr,
  input [4:0]   border_color
);

  parameter HA = 640;
  parameter HS  = 96;
  parameter HFP = 16;
  parameter HBP = 48;
  parameter HT  = HA + HS + HFP + HBP;

  parameter VA = 480;
  parameter VS  = 2;
  parameter VFP = 11;
  parameter VBP = 31;
  parameter VT  = VA + VS + VFP + VBP;

  reg [9:0] hc = 0;
  reg [9:0] vc = 0;

  // Set horizontal and vertical counters, and process interrupts
  always @(posedge clk) begin
    if (hc == HT - 1) begin
      hc <= 0;
      if (vc == VT - 1) vc <= 0;
      else vc <= vc + 1;
    end else hc <= hc + 1;
  end

  assign vga_hs = !(hc >= HA + HFP && hc < HA + HFP + HS);
  assign vga_vs = !(vc >= VA + VFP && vc < VA + VFP + VS);
  assign vga_de = !(hc >= HA || vc >= VA);

  wire [7:0] vb = 0;
  wire [6:0] vb2 = 0;

  wire [7:0] hb = 0;

  wire [9:0] x = hc - hb;
  wire [7:0] y = vc[9:1] - vb2;

  wire [9:0] x8 = x + 8;
  wire [7:0] y1 = y + 1;

  wire h_border = (hc < hb || hc >= (HA - hb));
  wire v_border = (vc < vb || vc >= VA - vb);
  wire border = h_border || v_border;

  reg [15:0] pixels;

  // Read video memory
  always @(posedge clk) begin
    if (x < HA - 8) vga_addr <= y * 320 + x;
    if (x[2:0] == 7) pixels <= vga_data;
  end

  wire [15:0] col = border ? border_color : pixels;

  wire [7:0] red = {col[1511], 3'b0};
  wire [7:0] green = {col[10:5], 2'b0};
  wire [7:0] blue = {col[4:0], 3'b0};

  assign vga_r = !vga_de ? 8'b0 : red;
  assign vga_g = !vga_de ? 8'b0 : green;
  assign vga_b = !vga_de ? 8'b0 : blue;

endmodule

