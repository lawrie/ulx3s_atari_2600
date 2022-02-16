`default_nettype none
module atari_2600
#(
  parameter pal = 1 // 0:NTSC 1:PAL
)
(
  // Main clock, 25MHz
  input         clk_25mhz,
  // Buttons
  input [6:0]   btn,
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
  // SPI control
  input         wifi_gpio16,
  input         wifi_gpio5,
  output        wifi_gpio0,
  inout         sd_clk, sd_cmd,
  inout   [3:0] sd_d,
  // Leds
  output [7:0]  led
);

  // passthru to ESP32 micropython serial console
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
    .out2_hz( 19*1000000),
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
  wire clk_cpu  = clocks[2];

  // ===============================================================
  // Joystick for OSD control and games
  // ===============================================================

  reg [6:0] r_btn;
  always @(posedge clk_cpu)
    r_btn <= btn;

  // ===============================================================
  // Clock Enable Generation
  // ===============================================================
  wire enable;

  // ===============================================================
  // Reset generation
  // ===============================================================

  reg [15:0] pwr_up_reset_counter = 0; // hold reset low for ~1ms
  wire       pwr_up_reset_n = &pwr_up_reset_counter;
  wire       reset;

  // ===============================================================
  // 6502 CPU
  // ===============================================================

  wire [7:0]  cpu_din;
  wire [7:0]  cpu_dout;
  wire [15:0] cpu_address;
  wire        rnw_c;
  wire        ready;
  wire        stall_cpu;
  wire        nmi_n;
  wire        irq_n;

  chip_6502 aholme_cpu (
    .clk(clk_cpu),
    .phi(clk_cpu & enable),
    .res(~reset),
    .so(1'b0),
    .rdy(ready),
    .nmi(nmi_n),
    .irq(irq_n),
    .rw(rnw_c),
    .dbi(cpu_din),
    .dbo(cpu_dout),
    .ab(cpu_address)
  );

  ///////////////////////////////////////////////////////////////////////////
  ///
  /// TIA
  ///
  ///////////////////////////////////////////////////////////////////////////
  ///////////////////////////////////////////////////////////////////////////
  wire tia_stb_i;
  wire tia_we_i;
  wire [15:0] tia_adr_i;
  wire [7:0] tia_dat_i;
  wire tia_ack_o;
  wire [7:0] tia_dat_o;
  wire [7:0] dummy_leds;

  tia tia_ram (
    .clk_i(clk_cpu),
    .rst_i(reset),
    .stb_i(tia_stb_i),
    .we_i(tia_we_i),
    .adr_i(tia_adr_i[6:0]),
    .dat_i(tia_dat_i),
    .ack_o(tia_ack_o),
    .dat_o(tia_dat_o),
    .buttons(r_btn),
    .leds(dummy_leds),
    .audio_left(audio_l),
    .audio_right(audio_r),
    .stall_cpu(stall_cpu),
    .nreset(~reset),
    .cmd_data(),
    .write_edge(),
    .dout()
  );

  ///////////////////////////////////////////////////////////////////////////
  ///////////////////////////////////////////////////////////////////////////
  ///
  /// PIA
  ///
  ///////////////////////////////////////////////////////////////////////////
  ///////////////////////////////////////////////////////////////////////////
  wire pia_stb_i;
  wire pia_we_i;
  wire [15:0] pia_adr_i;
  wire [7:0] pia_dat_i;
  wire pia_ack_o;
  wire [7:0] pia_dat_o;

  pia pia (
    .clk_i(clk_cpu),
    .rst_i(reset),
    .stb_i(pia_stb_i),
    .we_i(pia_we_i),
    .adr_i(pia_adr_i[6:0]),
    .dat_i(pia_dat_i),
    .ack_o(pia_ack_o),
    .dat_o(pia_dat_o),
    .buttons(r_btn),
    .ready(ready)
  );

  wire [7:0] rom_out;

  dprom #(
    .DATA_WIDTH(8),
    .DEPTH(4 * 1024),
    .MEM_INIT_FILE("../roms/rom.mem")
  ) rom (
    .clk(clk_cpu),
    .addr(cpu_address),
    .dout(rom_out)
  );

  // ===============================================================
  // SPI Slave for RAM and CPU control
  // ===============================================================
  
  wire        spi_ram_wr, spi_ram_rd;
  wire [31:0] spi_ram_addr;
  wire  [7:0] spi_ram_di;
  wire  [7:0] spi_ram_do;

  assign sd_d[3] = 1'bz; // FPGA pin pullup sets SD card inactive at SPI bus

  wire irq;
  spi_ram_btn
  #(
    .c_sclk_capable_pin(1'b0),
    .c_addr_bits(32)
  )
  spi_ram_btn_inst
  (
    .clk(clk_vga),
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

  reg [7:0] R_cpu_control;
  always @(posedge clk_cpu) begin
    if (spi_ram_wr && spi_ram_addr[31:24] == 8'hFF) begin
      R_cpu_control <= spi_ram_di;
    end
  end

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
    .i_r({red,   {4{red[0]}}   }),
    .i_g({green, {4{green[0]}} }),
    .i_b({blue,  {4{blue[0]}}  }),
    .i_hsync(~hsync), .i_vsync(~vsync), .i_blank(~vga_de),
    .i_csn(~wifi_gpio5), .i_sclk(wifi_gpio16), .i_mosi(sd_d[1]), // .o_miso(),
    .o_r(osd_vga_r), .o_g(osd_vga_g), .o_b(osd_vga_b),
    .o_hsync(osd_vga_hsync), .o_vsync(osd_vga_vsync), .o_blank(osd_vga_blank)
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

  always @(posedge clk_cpu) begin
    led1 <= 0;  // red
    led2 <= 0;  // yellow
    led3 <= 0;  // green
    led4 <= 0;  // blue
    led5 <= 0;  // red
    led6 <= 0;  // yellow
    led7 <= 0;  // green
    led8 <= 0;  // blue
  end

  // Diagnostics
  assign led = {led8, led7, led6, led5, led4, led3, led2, led1};

endmodule
