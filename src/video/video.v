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
  input  [6:0]  vga_data,
  output [15:0] vga_addr
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
  parameter VB  = 0;
  parameter VB2 = VB/2;
  parameter HB = 0;
  parameter HB2 = HB/2;
  parameter HA2 = HA/2;

  reg [23:0] palette [0:127];

  initial begin
    palette[0]   = 24'h000000;
    palette[1]   = 24'h444400;
    palette[2]   = 24'h702800;
    palette[3]   = 24'h841000;
    palette[4]   = 24'h880000;
    palette[5]   = 24'h78005c;
    palette[6]   = 24'h480078;
    palette[7]   = 24'h140084;
    palette[8]   = 24'h000088;
    palette[9]   = 24'h00187c;
    palette[10]  = 24'h002c5c;
    palette[11]  = 24'h00402c;
    palette[12]  = 24'h003c00;
    palette[13]  = 24'h143800;
    palette[14]  = 24'h2c3000;
    palette[15]  = 24'h442800;
    palette[16]  = 24'h404040;
    palette[17]  = 24'h646410;
    palette[18]  = 24'h844414;
    palette[19]  = 24'h983418;
    palette[20]  = 24'h9c2020;
    palette[21]  = 24'h8c2074;
    palette[22]  = 24'h602090;
    palette[23]  = 24'h302098;
    palette[24]  = 24'h1c209c;
    palette[25]  = 24'h1c3890;
    palette[26]  = 24'h1c4c78;
    palette[27]  = 24'h1c5c48;
    palette[28]  = 24'h205c20;
    palette[29]  = 24'h345c1c;
    palette[30]  = 24'h4c501c;
    palette[31]  = 24'h644818;
    palette[32]  = 24'h6c6c6c;
    palette[33]  = 24'h848424;
    palette[34]  = 24'h985c28;
    palette[35]  = 24'hac5030;
    palette[36]  = 24'hb03c3c;
    palette[37]  = 24'ha03c88;
    palette[38]  = 24'h783ca4;
    palette[39]  = 24'h4c3cac;
    palette[40]  = 24'h3840b0;
    palette[41]  = 24'h3854a8;
    palette[42]  = 24'h386890;
    palette[43]  = 24'h387c64;
    palette[44]  = 24'h407c40;
    palette[45]  = 24'h507c38;
    palette[46]  = 24'h687034;
    palette[47]  = 24'h846830;
    palette[48]  = 24'h909090;
    palette[49]  = 24'ha0a034;
    palette[50]  = 24'hac783c;
    palette[51]  = 24'hc06848;
    palette[52]  = 24'hc05858;
    palette[53]  = 24'hb0589c;
    palette[54]  = 24'h8c58b8;
    palette[55]  = 24'h6858c0;
    palette[56]  = 24'h505cc0;
    palette[57]  = 24'h5070bc;
    palette[58]  = 24'h5084ac;
    palette[59]  = 24'h509c80;
    palette[60]  = 24'h5c9c5c;
    palette[61]  = 24'h6c9850;
    palette[62]  = 24'h848c4c;
    palette[63]  = 24'ha08444;
    palette[64]  = 24'hb0b0b0;
    palette[65]  = 24'hb8b840;
    palette[66]  = 24'hbc8c4c;
    palette[67]  = 24'hd0805c;
    palette[68]  = 24'hd07070;
    palette[69]  = 24'hc070b0;
    palette[70]  = 24'ha070cc;
    palette[71]  = 24'h7c70d0;
    palette[72]  = 24'h6874d0;
    palette[73]  = 24'h6888cc;
    palette[74]  = 24'h689cc0;
    palette[75]  = 24'h68b494;
    palette[76]  = 24'h74b474;
    palette[77]  = 24'h84b468;
    palette[78]  = 24'h9ca864;
    palette[79]  = 24'hb89c58;
    palette[80]  = 24'hc8c8c8;
    palette[81]  = 24'hd0d050;
    palette[82]  = 24'hcca05c;
    palette[83]  = 24'he09470;
    palette[84]  = 24'he08888;
    palette[85]  = 24'hd084c0;
    palette[86]  = 24'hb484dc;
    palette[87]  = 24'h9488e0;
    palette[88]  = 24'h7c8ce0;
    palette[89]  = 24'h7c9cdc;
    palette[90]  = 24'h7cb4d4;
    palette[91]  = 24'h7cd0ac;
    palette[92]  = 24'h8cd08c;
    palette[93]  = 24'h9ccc7c;
    palette[94]  = 24'hb4c078;
    palette[95]  = 24'hd0b46c;
    palette[96]  = 24'hdcdcdc;
    palette[97]  = 24'he8e85c;
    palette[98]  = 24'hdcb468;
    palette[99]  = 24'heca880;
    palette[100] = 24'heca0a0;
    palette[101] = 24'hdc9c90;
    palette[102] = 24'hc49cec;
    palette[103] = 24'ha8a0ec;
    palette[104] = 24'h90a4ec;
    palette[105] = 24'h90b4ec;
    palette[106] = 24'h90cce8;
    palette[107] = 24'h90e4c0;
    palette[108] = 24'ha4e4a4;
    palette[109] = 24'hb4e490;
    palette[110] = 24'hccd488;
    palette[111] = 24'he8cc7c;
    palette[112] = 24'hececec;
    palette[113] = 24'hfcfc68;
    palette[114] = 24'hfcbc94;
    palette[115] = 24'hfcb4b4;
    palette[116] = 24'hecb0e0;
    palette[117] = 24'hd4b0fc;
    palette[118] = 24'hbcb4fc;
    palette[119] = 24'ha4b8fc;
    palette[120] = 24'ha4c8fc;
    palette[121] = 24'ha4e0fc;
    palette[122] = 24'hacfcd4;
    palette[123] = 24'hb8fcb8;
    palette[124] = 24'hc8fca4;
    palette[125] = 24'he0ec9c;
    palette[126] = 24'hfce08c;
    palette[127] = 24'hffffff;
  end

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

  wire [7:0] x = hc[9:2] - HB2;
  wire [7:0] y = vc[9:1] - VB2;

  wire h_border = (hc < HB || hc >= (HA - HB));
  wire v_border = (vc < VB || vc >= VA - VB);
  wire border = h_border || v_border;

  reg [23:0] pixels;

  // Read video memory
  always @(posedge clk) begin
    if (x < HA2) vga_addr <= y * 160 + x;
    pixels <= palette[vga_data];
  end

  wire [23:0] col = border ? 0 : pixels;

  wire [7:0] red = col[23:16];
  wire [7:0] green = col[15:8];
  wire [7:0] blue = col[7:0];

  assign vga_r = !vga_de ? 8'b0 : red;
  assign vga_g = !vga_de ? 8'b0 : green;
  assign vga_b = !vga_de ? 8'b0 : blue;

endmodule

