`default_nettype none
module atari_2600
#(
  parameter c_diag         = 1,
  parameter c_speed        = 3,
  parameter c_lcd_hex      = 1   // SPI LCD HEX decoder
)
(
  // Main clock, 25MHz
  input         clk_25mhz,
  // Buttons
  input [6:0]   btn,
  // Switches
  input [3:0]   sw,
  // HDMI
  output [3:0]  gpdi_dp, 
  output [3:0]  gpdi_dn,
  // Audio
  output  [3:0] audio_l, 
  output  [3:0] audio_r,
  // ESP32 passthru
  input         ftdi_txd,
  output        ftdi_rxd,
  input         wifi_txd,
  output        wifi_rxd,  // SPI from ESP32
  // GPIO
  inout  [27:0] gp,gn,
  // SPI display
  output        oled_csn,
  output        oled_clk,
  output        oled_mosi,
  output        oled_dc,
  output        oled_resn,
  // SPI control
  input         wifi_gpio16,
  input         wifi_gpio5,
  output        wifi_gpio0,
  inout         sd_clk, sd_cmd,
  inout   [3:0] sd_d,
  // Leds
  output reg [7:0]  led
);

  // Passthru to ESP32 micropython serial console
  assign wifi_rxd = ftdi_txd;
  assign ftdi_rxd = wifi_txd;

  // ===============================================================
  // System Clock generation (25MHz)
  // ===============================================================
  wire locked;

  wire [3:0] clocks;
  ecp5pll
  #(
      .in_hz( 25*1000000),
    .out0_hz(125*1000000),
    .out1_hz( 25*1000000),
    .out2_hz( 18.9*1000000),
    .out2_tol_hz(1000000)
  )
  ecp5pll_inst
  (
    .clk_i(clk_25mhz),
    .clk_o(clocks),
    .locked(locked)
  );
  wire clk_hdmi  = clocks[0];
  wire clk_vga   = clocks[1];
  wire clk_sys  = clocks[2];

  // ===============================================================
  // Joystick for OSD control and games
  // ===============================================================
  reg [6:0] r_btn;
  always @(posedge clk_sys)
    r_btn <= btn;

  // ===============================================================
  // Clock Enable Generation
  // ===============================================================
  reg [c_speed:0] clk_counter = 0;
  wire cpu_enable = clk_counter == 0;
  wire tia_enable = clk_counter >= 5 && clk_counter <= 7;
  wire clk_cpu = clk_counter[c_speed];

  always @(posedge clk_sys) begin
    clk_counter <= clk_counter + 1;
  end

  // ===============================================================
  // Reset generation
  // ===============================================================
  reg [15:0] pwr_up_reset_counter = 0; // hold reset low for ~1ms
  reg [7:0]  r_cpu_control;
  wire       pwr_up_reset_n = &pwr_up_reset_counter;
  wire       reset = pwr_up_reset_n || r_cpu_control[0];

  always @(posedge clk_25mhz) begin
    if (pwr_up_reset_n) pwr_up_reset_counter <= pwr_up_reset_counter + 1;
  end

  // ===============================================================
  // Chip selects
  // ===============================================================
  wire ram_cs = cpu_address[12] == 0 && cpu_address[9] == 0 && cpu_address[7] == 1;
  wire tia_cs = cpu_address[12] == 0 && cpu_address[7] == 0;
  wire pia_cs = cpu_address[12] == 0 && cpu_address[9] == 1 && cpu_address[7] == 1;
  wire rom_cs = cpu_address[12] == 1;

  // ===============================================================
  // 6502 CPU
  // ===============================================================
  wire [7:0]  rom_out;
  wire [7:0]  ram_out;
  wire [7:0]  pia_dat_o;
  wire [7:0]  tia_dat_o;
  wire [7:0]  cpu_din;
  wire [7:0]  cpu_dout;
  wire [15:0] cpu_address;
  wire        rnw;
  wire        stall_cpu;
  wire        spi_load = r_cpu_control[1];

  chip_6502 aholme_cpu (
    .clk(clk_sys),
    .phi(clk_cpu),
    .res(~reset),
    .so(1'b0),
    .rdy(!stall_cpu && !spi_load),
    .nmi(1'b1),
    .irq(1'b1),
    .rw(rnw),
    .dbi(cpu_din),
    .dbo(cpu_dout),
    .ab(cpu_address)
  );

  // ===============================================================
  // Address multiplexer
  // ===============================================================
  assign cpu_din = tia_cs ? tia_dat_o :
                   pia_cs ? pia_dat_o :
                   ram_cs ? ram_out :
                   rom_cs ? rom_out : 8'h0;

  // ===============================================================
  // TIA
  // ===============================================================
  wire [15:0] vid_dout;
  wire [16:0] vid_out_addr;
  wire        vid_wr;
  wire [127:0] tia_diag;

  tia tia_ram (
    .clk_i(clk_sys),
    .rst_i(reset),
    .stb_i(tia_cs),
    .we_i(!rnw),
    .adr_i(cpu_address[5:0]),
    .dat_i(cpu_dout),
    .dat_o(tia_dat_o),
    .buttons({~r_btn[6:1], r_btn[0]}),
    .audio_left(audio_l),
    .audio_right(audio_r),
    .stall_cpu(stall_cpu),
    .enable_i(tia_enable),
    .cpu_enable_i(cpu_enable),
    .cpu_clk_i(clk_cpu),
    .vid_out(vid_dout),
    .vid_addr(vid_out_addr),
    .vid_wr(vid_wr),
    .diag(tia_diag)
  );

  // ===============================================================
  // PIA
  // ===============================================================
  pia pia (
    .clk_i(clk_cpu),
    .rst_i(reset),
    .stb_i(pia_cs),
    .we_i(!rnw),
    .adr_i(cpu_address[6:0]),
    .dat_i(cpu_dout),
    .dat_o(pia_dat_o),
    .buttons({~r_btn[6:1], r_btn[0]}),
    .sw(sw),
    .diag(led)
  );

  // ===============================================================
  // ROM
  // ===============================================================
  wire        spi_ram_wr, spi_ram_rd;
  wire [31:0] spi_ram_addr;
  wire  [7:0] spi_ram_di;
  wire  [7:0] spi_ram_do = ram_out;
  wire irq;

  assign sd_d[3] = 1'bz; // FPGA pin pullup sets SD card inactive at SPI bus

  dprom #(
    .DATA_WIDTH(8),
    .DEPTH(4 * 1024),
    .MEM_INIT_FILE("../roms/rom.mem")
  ) rom (
    .clk(clk_sys),
    .addr(cpu_address[11:0]),
    .dout(rom_out),
    .addr_b(spi_ram_addr[11:0]),
    .we_b(spi_ram_wr && spi_ram_addr[31:24] == 0),
    .din_b(spi_ram_di)
  );

  // ===============================================================
  // RAM
  // ===============================================================
  ram #(
    .DATA_WIDTH(8),
    .DEPTH(128)
  ) ram (
    .clk(clk_sys),
    .addr(spi_ram_rd ? spi_ram_addr[6:0] : cpu_address[6:0]),
    .dout(ram_out),
    .din(cpu_dout),
    .we(!rnw && ram_cs)
  );

  // ===============================================================
  // Screen memory
  // ===============================================================
  wire [6:0]  vram_out;
  wire [6:0]  vram_in;
  wire [15:0] vram_addr;
  
  dpram #(
    .DATA_WIDTH(7),
    .DEPTH(160 * 240)
  ) vram (
    .clk_a(clk_sys),
    .addr_a(vid_out_addr),
    .din_a(vid_dout),
    .we_a(vid_wr),
    .clk_b(clk_vga),
    .addr_b(vram_addr),
    .dout_b(vram_out),
  );

  // ===============================================================
  // SPI Slave for RAM and CPU control
  // ===============================================================
  spi_ram_btn
  #(
    .c_sclk_capable_pin(1'b0),
    .c_addr_bits(32)
  )
  spi_ram_btn_inst
  (
    .clk(clk_sys),
    .csn(~wifi_gpio5),
    .sclk(wifi_gpio16),
    .mosi(sd_d[1]), // wifi_gpio4
    .miso(sd_d[2]), // wifi_gpio12
    .btn(r_btn),
    .irq(irq),
    .wr(spi_ram_wr),
    .rd(spi_ram_rd),
    .addr(spi_ram_addr),
    .data_in(spi_ram_do),
    .data_out(spi_ram_di)
  );

  assign wifi_gpio0 = ~irq;

  always @(posedge clk_sys) begin
    if (spi_ram_wr && spi_ram_addr[31:24] == 8'hFF) begin
      r_cpu_control <= spi_ram_di;
    end
  end

  // ===============================================================
  // SPI Slave for OSD display
  // ===============================================================
  wire [7:0] osd_vga_r, osd_vga_g, osd_vga_b;  
  wire osd_vga_hsync, osd_vga_vsync, osd_vga_blank;
  wire vga_de;
  wire [7:0] red, green, blue;
  wire hsync, vsync;

  spi_osd
  #(
    .c_start_x(62), .c_start_y(80),
    .c_chars_x(64), .c_chars_y(20),
    .c_init_on(0),
    .c_char_file("osd.mem"),
    .c_font_file("font_bizcat8x16.mem")
  )
  spi_osd_inst
  (
    .clk_pixel(clk_vga), .clk_pixel_ena(1),
    .i_r(red),
    .i_g(green),
    .i_b(blue),
    .i_hsync(~hsync), .i_vsync(~vsync), .i_blank(~vga_de),
    .i_csn(~wifi_gpio5), .i_sclk(wifi_gpio16), .i_mosi(sd_d[1]), // .o_miso(),
    .o_r(osd_vga_r), .o_g(osd_vga_g), .o_b(osd_vga_b),
    .o_hsync(osd_vga_hsync), .o_vsync(osd_vga_vsync), .o_blank(osd_vga_blank)
  );

  video vga (
    .clk(clk_vga),
    .vga_r(red),
    .vga_g(green),
    .vga_b(blue),
    .vga_de(vga_de),
    .vga_hs(hsync),
    .vga_vs(vsync),
    .vga_addr(vram_addr),
    .vga_data(vram_out)
  );

  // Convert VGA to HDMI
  HDMI_out vga2dvid (
    .pixclk(clk_vga),
    .pixclk_x5(clk_hdmi),
    .red(osd_vga_r),
    .green(osd_vga_g),
    .blue(osd_vga_b),
    .vde(~osd_vga_blank),
    .hSync(~osd_vga_hsync),
    .vSync(~osd_vga_vsync),
    .gpdi_dp(gpdi_dp),
    .gpdi_dn(gpdi_dn)
  );

  // ===============================================================
  // LCD diagnostics
  // ===============================================================
  generate
  if(c_lcd_hex) begin
  // SPI DISPLAY
  reg [255:0] r_display;
  // HEX decoder does printf("%16X\n%16X\n", r_display[63:0], r_display[127:64]);
  always @(posedge clk_sys)
    r_display <= {16'b0, ram_out, rom_out, cpu_din, cpu_dout, cpu_address, tia_diag};

  parameter c_color_bits = 16;
  wire [7:0] x;
  wire [7:0] y;
  wire [c_color_bits-1:0] color;
  hex_decoder_v
  #(
    .c_data_len(256),
    .c_row_bits(4),
    .c_grid_6x8(1), // NOTE: TRELLIS needs -abc9 option to compile
    .c_font_file("hex_font.mem"),
    .c_color_bits(c_color_bits)
  )
  hex_decoder_v_inst
  (
    .clk(clk_vga),
    .data(r_display),
    .x(x[7:1]),
    .y(y[7:1]),
    .color(color)
  );

  wire next_pixel;
  reg [c_color_bits-1:0] r_color;
  wire w_oled_csn;

  always @(posedge clk_vga)
    if(next_pixel) r_color <= color;

  lcd_video #(
    .c_clk_mhz(25),
    .c_init_file("st7789_linit_xflip.mem"),
    .c_clk_phase(0),
    .c_clk_polarity(1),
    .c_init_size(38)
  ) lcd_video_inst (
    .clk(clk_vga),
    .reset(r_btn[5]),
    .x(x),
    .y(y),
    .next_pixel(next_pixel),
    .color(r_color),
    .spi_clk(oled_clk),
    .spi_mosi(oled_mosi),
    .spi_dc(oled_dc),
    .spi_resn(oled_resn),
    .spi_csn(w_oled_csn)
  );

  //assign oled_csn = w_oled_csn; // 8-pin ST7789: oled_csn is connected to CSn
  assign oled_csn = 1; // 7-pin ST7789: oled_csn is connected to BLK (backlight enable pin)
  end
  endgenerate

  // ===============================================================
  // LEDs
  // ===============================================================

  reg        led1;
  reg        led2;
  reg        led3;
  reg        led4;
  reg        led5;
  reg        led6;
  reg        led7;
  reg        led8;

  always @(posedge clk_sys) begin
    led1 <= reset;      // red
    led2 <= cpu_enable; // yellow
    led3 <= stall_cpu;  // green
    led4 <= rnw;        // blue
    led5 <= tia_cs;     // red
    led6 <= pia_cs;     // yellow
    led7 <= tia_enable; // green
    led8 <= 0;  // blue
  end

  //assign led = {led8, led7, led6, led5, led4, led3, led2, led1};

  // ===============================================================
  // Led diagnostics
  // ===============================================================
  reg [15:0] diag16;

  generate
    genvar i;
    if (c_diag) begin
      for(i = 0; i < 4; i = i+1) begin
        assign gn[17-i] = diag16[8+i];
        assign gp[17-i] = diag16[12+i];
        assign gn[24-i] = diag16[i];
        assign gp[24-i] = diag16[4+i];
      end
    end
  endgenerate

  always @(posedge clk_sys) begin
    if (rom_cs) diag16 <= cpu_address;
  end

endmodule
