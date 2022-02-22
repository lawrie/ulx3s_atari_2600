/*
 * Simple Atari 2600 PIA module.
 */
`default_nettype none
module pia (
  input                           clk_i,
  input                           rst_i,

  input                           stb_i,
  input                           we_i,
  input [6:0]                     adr_i,
  input [7:0]                     dat_i,

  output reg [7:0]                dat_o,

  input [6:0]                     buttons,
  input [3:0]                     sw,
  output reg [7:0]                diag
);

  // Button numbers
  localparam UP = 3, RIGHT = 6, LEFT = 5, DOWN = 4, SELECT = 2, RESET = 0, FIRE = 1;

  wire valid_cmd = !rst_i && stb_i;
  wire valid_write_cmd = valid_cmd && we_i;
  wire valid_read_cmd = valid_cmd && !we_i;

  reg [7:0]  intim;
  reg [23:0] time_counter;
  reg [7:0]  reset_timer;
  reg [10:0] interval;
  reg [7:0]  swa_dir, swb_dir;

  always @(posedge clk_i) begin
    if (rst_i) begin
      interval <= 0;
      reset_timer <= 0;
      time_counter <= 0;
      intim <= 0;
    end else begin
      reset_timer <= 0;

      if (valid_read_cmd) begin
        case (adr_i) 
          7'h00: begin dat_o <= {buttons[6:3], buttons[6:3]}; end// SWCHA
          7'h01: dat_o <= swa_dir; // SWACNT
          7'h02: dat_o <= {6'h3f, buttons[SELECT], buttons[RESET]}; // SWCHB
          7'h03: dat_o <= {2'b0, swb_dir[5:4], 1'b0, swb_dir[2], 2'b0}; // SWBCNT
          7'h04: dat_o <= intim; // INTIM
        endcase
      end

      if (valid_write_cmd) begin
        case (adr_i)
          7'h01: swa_dir <= dat_i;
          7'h03: swb_dir <= dat_i; 
          7'h14: begin interval <= 1; reset_timer <= dat_i; end // TIM1T
          7'h15: begin interval <= 8; reset_timer <= dat_i; end  // TIM8T
          7'h16: begin interval <= 64; reset_timer <= dat_i; end // TIM64T
          7'h17: begin interval <= 1024; reset_timer <= dat_i; end // T1024T
        endcase
      end

      if (reset_timer > 0) begin
        time_counter <= 0;
        intim <= reset_timer;
      end else begin
        time_counter <= time_counter + 1;
      end

      if (time_counter == interval - 1) begin
        if (intim == 0) interval <= 1;
        intim <= intim - 1;
        time_counter <= 0;
      end
    end
  end
   
endmodule
