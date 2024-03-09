//////////////////////////////////////////////////
/////////// DESIGN
//////////////////////////////////////////////////

module fourbitCounter(
    cnt_intf intf 
);
    always_ff @( posedge intf.clk or posedge intf.rst ) begin 
        if (intf.rst)
            intf.cnt <= 4'b0;
        else if(intf.en)
            intf.cnt <= intf.cnt +1;
    end
endmodule

interface cnt_intf;
    logic rst; 
    logic en;
    logic [3:0] cnt;
    logic clk;
    
endinterface

//////////////////////////////////////////////////
/////////// DV
//////////////////////////////////////////////////

class driver;
    virtual cnt_intf vif;
    int reset_duration = 10;

    function new(virtual cnt_intf vif);
        this.vif = vif;
    endfunction

    task reset(input int duration = reset_duration);
        vif.rst = 1'b1;
        #(duration) vif.rst = 1'b0;
    endtask

    task set_enable(input logic en);
        vif.en = en;
    endtask

endclass

class monitor;
    virtual cnt_intf vif;
    event count_event;

    function new(virtual cnt_intf vif);
        this.vif = vif;
    endfunction

    task run();
        forever begin
            @(posedge vif.clk);
            -> count_event; 
        end
    endtask
endclass

class scoreboard;
    virtual cnt_intf vif;
    int expected_cnt;

    function new(virtual cnt_intf vif);
        this.vif = vif;
        expected_cnt = 0;
    endfunction

    task check();
        forever begin
            if (vif.rst) begin
            expected_cnt = 0;
            $display("Reset detected. Expected counter reset to 0.");
        end
            else if (vif.en) begin
                expected_cnt = (expected_cnt + 1) % 16;
                if (vif.cnt !== expected_cnt) begin
                    $display("Mismatch detected after enable! Expected: %0d, Actual: %0d", expected_cnt, vif.cnt);
                    error_detected = 1;
                end else begin
                    $display("Match found after enable! Expected: %0d, Actual: %0d", expected_cnt, vif.cnt);
                end
            end
        end
    endtask
endclass

class coverage;
    virtual cnt_intf vif;
    covergroup cg_counter with function sample (logic [3:0] cnt);
        coverpoint cnt {
            bins all_bins [16] = {[0:15]};
        }
    endgroup

    function new(virtual cnt_intf vif);
        this.vif = vif;
        cg_counter = new();
    endfunction

    task sample();
        cg_counter.sample(vif.cnt);
    endtask
endclass

module top;
    cnt_intf intf;

    fourbitCounter dut(
        .intf(intf)
    );

    driver      drv = new(intf);
    monitor     mon = new(intf);
    scoreboard  sb  = new(intf);
    coverage    cov = new(intf);
    
    initial begin
        $fsdbDumpfile("dump.fsdb");
        $fsdbDumpvars;
        
        intf.clk = 0;
        forever #5 intf.clk = ~intf.clk;
    end

    initial begin
        fork
            mon.run();
            sb.check();
            forever begin
                @(mon.count_event);
                cov.sample();
            end
            drv.reset(10);
            drv.set_enable(1'b1);
        join_none
    end
    
    initial begin
        #1000;
        $finish;
    end
endmodule
