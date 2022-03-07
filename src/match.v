module match_bytes
(
  input         clk,
  input  [14:0] addr,
  input         ena,
  input  [7:0]  data,
  output reg    hasMatch
);

parameter [7:0] num_bytes;
parameter [(num_bytes*8)-1:0] pattern;
parameter [7:0] needmatches=8'b1;

reg [(num_bytes*8)-1:0] lastPattern;
reg [7:0] curMatch;

always @(posedge clk) begin
  if (ena) begin
    begin
      // use address 0 as reset
      if (addr == 15'b0) begin
        curMatch <= 8'b0;
        hasMatch <= 0;
        lastPattern <= data;
      end else begin
        lastPattern <= {lastPattern[(num_bytes * 8) - 9:0],data};
        if (lastPattern == pattern) begin
          curMatch <= curMatch + 8'b1;
          if (curMatch == (needmatches - 8'b1)) hasMatch <= 1;
        end
      end
    end
  end
end

endmodule: match_bytes
