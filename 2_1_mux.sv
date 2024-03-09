// `define SV_RAND_CHECK(r) \ 
//     do begin \
//         if(!(r)) begin \
//             $display("Randomization Failed"); \
//         $finish; \
//         end \
//     end while(0)

//////////////////////////////////////////////////
/////////// DESIGN
//////////////////////////////////////////////////

interface mux2to1;
    logic [7:0] in1, in2;
    logic sel;
    logic [7:0] out;
endinterface

module rtl(mux2to1 intf);
    assign intf.out = intf.sel ? intf.in1 : intf.in2;
endmodule

//////////////////////////////////////////////////
/////////// DV
//////////////////////////////////////////////////

class packet;
    rand logic [7:0] in1, in2;
    randc logic sel;
endclass


module dv;
    mux2to1 intf();
    rtl dut(.intf(intf));

    covergroup cg with function sample (logic sel);
        sel_cp: coverpoint sel{
            bins sel_0 ={0};
            bins sel_1 ={1};
        // bins auto[] = {[0:255]};  Automatically create bins for all values
        }
    endgroup

    packet p =new();
    cg cov =new();

    initial begin
        repeat (10) begin
            // SV_RAND_CHECK(p.randomize());
            if(!p.randomize()) begin
                $display("Randomization Failed");
                $finish;
            end
            
            intf.in1 = p.in1;
            intf.in2 = p.in2;
            intf.sel = p.sel;

            cov.sample(intf.sel)
            #5; 

            $display("Time: %0t | in1: %h, in2: %h, sel: %b -> out: %h",
                     $time, intf.in1, intf.in2, intf.sel, intf.out);
        end
        

        #10 $finish;
    end
    always @(intf.out) begin
        assert((intf.sel ? intf.in1 : intf.in2) == intf.out) 
        else $error("Mismatch in expected and actual MUX output.");
    end

endmodule
