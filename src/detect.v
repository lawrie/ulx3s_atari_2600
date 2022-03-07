module detect_e0 (
  input        clk,
  input        reset,
  input        ena,
  input [14:0] addr,
  input [7:0]  data,
  output       hasMatch
);

reg m1, m2, m3, m4, m5, m6, m7, m8;

match_bytes #(.num_bytes(3), .pattern(24'h8DE01F)) match1 (
  .clk(clk),
  .ena(ena),
  .addr(addr),
  .data(data),
  .hasMatch(m1)
);

match_bytes #(.num_bytes(3), .pattern(24'h8DE05F)) match2 (
  .clk(clk),
  .ena(ena),
  .addr(addr),
  .data(data),
  .hasMatch(m2)
);

match_bytes #(.num_bytes(3), .pattern(24'h8DE9FF)) match3 (
  .clk(clk),
  .ena(ena),
  .addr(addr),
  .data(data),
  .hasMatch(m3)
);

match_bytes #(.num_bytes(3), .pattern(24'h0CE0FF)) match4 (
  .clk(clk),
  .ena(ena),
  .addr(addr),
  .data(data),
  .hasMatch(m4)
);

match_bytes #(.num_bytes(3), .pattern(24'hADE01F)) match5 (
  .clk(clk),
  .ena(ena),
  .addr(addr),
  .data(data),
  .hasMatch(m5)
);

match_bytes #(.num_bytes(3), .pattern(24'hADE9FF)) match6 (
  .clk(clk),
  .ena(ena),
  .addr(addr),
  .data(data),
  .hasMatch(m6)
);

match_bytes #(.num_bytes(3), .pattern(24'hADEDFF)) match7 (
  .clk(clk),
  .ena(ena),
  .addr(addr),
  .data(data),
  .hasMatch(m7)
);

match_bytes #(.num_bytes(3), .pattern(24'hADF3BF)) match8 (
  .clk(clk),
  .ena(ena),
  .addr(addr),
  .data(data),
  .hasMatch(m8)
);

assign hasMatch = m1 | m2 | m3 | m4 | m5 | m6 | m7 | m8;

endmodule

