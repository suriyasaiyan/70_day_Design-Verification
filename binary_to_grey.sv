//////////////////////////////////////////////////
/////////// DESIGN
//////////////////////////////////////////////////

interface b_to_g_inf;
    logic binary_in[31:0];
    logic grey_out[31:0];
endinterface 

module rtl(
    b_to_g_inf intf
)
    assign intf.grey_out[31] = intf.binary_in[31];
    genvar i;
    generate
        for(i = 0; i < 31; i++)
            assign intf.grey_out[i] = (intf.binary_in[i]^intf.binary_in[i+1]);
    endgenerate
endmodule

//////////////////////////////////////////////////
/////////// DV
//////////////////////////////////////////////////

module dv;
    b_to_g_inf intf();
    rtl DUT(.intf(intf));
    
    // Just using RAND 
    class packet;
        rand logic [31:0]in;
    endclass
    packet p = new();

    covergroup cg @(intf.binary_in);
        coverpoint intf.binary_in{
            bins low = {0:15};
            bins high = {16:31};
        }
    endgroup
    cg cov = new();

    initial begin
        repeat(3) begin
            assert(p.randomize()) else begin
                $display("Randomization Failed");
                $finish;
            end

            intf.binary_in = p.in;
            #5; cov.sample();
            $display("Time: %0t, binary_in: %h, grey_out: %h", $time, 
                        intf.binary_in, intf.grey_out);
        end 
        #10 $finish;
    end

    always @(intf.grey_out) begin
        logic [31:0] expected_grey_out;
        expected_grey_out[31] = intf.binary_in[31];
        for(int i =0; i <31; i++) begin
            expected_grey_out[i] = intf.binary_in[i]^intf.binary_in[i+1];
        end

        assert(intf.grey_out == expected_grey_out) else begin
            $error("mismatch at time %t: Binary: %h Grey: %h Exp_grey: %h"
                    , $time, intf.binary_in, intf.grey_out, expected_grey_out);
        end
    end
endmodule