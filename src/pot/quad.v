`default_nettype none
module quad (
  input            clk,
  input            quad1,
  input            quad2,
  output reg [6:0] pos
);

reg [2:0] r_quad1, r_quad2;

always @(posedge clk) r_quad1 <= {r_quad1[1:0], quad1};
always @(posedge clk) r_quad2 <= {r_quad2[1:0], quad2};

always @(posedge clk) begin
  if(r_quad1[2] ^ r_quad1[1] ^ r_quad2[2] ^ r_quad2[1]) begin
    if(r_quad1[2] ^ r_quad2[1]) begin
      if (~&pos) pos <= pos + 1;
    end else begin
      if (|pos) pos <= pos - 1;
    end
  end
end

endmodule

