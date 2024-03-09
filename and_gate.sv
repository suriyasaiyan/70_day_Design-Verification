//////////////////////////////////////////////////
/////////// DESIGN
//////////////////////////////////////////////////

module and_gate(
    input logic a, b,
    output logic out
);
    assign out = a & b;
endmodule

interface and_gate_if;
    logic a;
    logic b;
    logic out;
endinterface

//////////////////////////////////////////////////
/////////// DV
//////////////////////////////////////////////////

class and_gate_driver;
    virtual and_gate_if vif;

    function new(virtual and_gate_if vif);
        this.vif = vif;
    endfunction

    task drive(input logic a, input logic b);
        vif.a = a;
        vif.b = b;
    endtask
endclass
class and_gate_monitor;
    virtual and_gate_if vif;

    function new(virtual and_gate_if vif);
        this.vif = vif;
    endfunction

    task monitor();
        forever begin
            @(vif.a or vif.b);
            $display("Time: %0t, a: %0b, b: %0b, out: %0b", $time, vif.a, vif.b, vif.out);
        end
    endtask
endclass
class and_gate_scoreboard;
    virtual and_gate_if vif;

    function new(virtual and_gate_if vif);
        this.vif = vif;
    endfunction

    task check();
        logic expected;
        forever begin
            @(vif.out);
            expected = vif.a & vif.b;
            if (vif.out !== expected) $display("Mismatch at time %0t", $time);
        end
    endtask
endclass

class and_gate_coverage;
    virtual and_gate_if vif;
    covergroup cg_without_auto_sampling; // Removed the automatic sampling event
        cp_a: coverpoint vif.a {
            bins low = {0};
            bins high = {1};
        }
        cp_b: coverpoint vif.b {
            bins low = {0};
            bins high = {1};
        }
        cp_out: coverpoint vif.out {
            bins low = {0};
            bins high = {1};
        }
        cp_a_b_cross: cross cp_a, cp_b; // Cross coverage of a and b
    endgroup

    function new(virtual and_gate_if vif);
        this.vif = vif;
        cg_without_auto_sampling = new(); // Instantiate the covergroup without the sampling event
    endfunction

    // Sample the covergroup manually
    task sample();
        cg_without_auto_sampling.sample();
    endtask
endclass


module and_gate_tb;
    and_gate_if intf();

    and_gate dut (
        .a(intf.a),
        .b(intf.b),
        .out(intf.out)
    );

    and_gate_driver driver = new(intf);
    and_gate_monitor monitor = new(intf);
    and_gate_scoreboard scoreboard = new(intf);
    and_gate_coverage coverage = new(intf);

    initial begin
        // FSDB Dumping Commands
        $fsdbDumpfile("dump.fsdb");
        $fsdbDumpvars;

        fork
            monitor.monitor();
            scoreboard.check();
        join_none

        // Test Cases
        driver.drive(0, 0); #20; coverage.sample(); // Expected output: 0
        driver.drive(0, 1); #20; coverage.sample(); // Expected output: 0
        driver.drive(1, 0); #20; coverage.sample(); // Expected output: 0
        driver.drive(1, 1); #20; coverage.sample(); // Expected output: 1

        $finish;
    end
endmodule
