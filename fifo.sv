//////////////////////////////////////////////////
/////////// DESIGN
//////////////////////////////////////////////////
interface fifo_intf #(parameter DATA_WIDTH =8, DEPTH =16);
    logic rst, clk;
    logic wr_en, rd_en;

    logic [DATA_WIDTH -1:0] data_in;
    logic [DATA_WIDTH -1:0] data_out;

    logic full, empty;
endinterface

module fifo #(
    parameter DATA_WIDTH =8, DEPTH =16
)(
    fifo_intf intf
);
    reg [DATA_WIDTH -1:0] fifo_mem [0: DEPTH-1];
    logic [$clog2[DEPTH] -1:0] rd_ptr, wr_ptr;
    logic [$clog2[DEPTH]:0] cnt; // using one more bit to counter OVERFLOW
    
    // Just Trying using wires
    wire clk = intf.clk;
    wire rst = intf.rst;
    wire wr_en = intf.wr_en;
    wire rd_en = intf.rd_en;
    wire [DATA_WIDTH -1:0] data_in = intf.data_in;

    assign intf.full = (cnt == DEPTH);
    assign intf.empty = (cnt == 0);

    always_ff @(posedge clk or posedge rst) begin
        if(rst) begin 
            rd_ptr <= 0;
            wr_ptr <= 0;
            cnt    <= 0;
            for (int i; i < DEPTH; i++) 
                fifo_mem[i] <= {DATA_WIDTH{1'b0}};
        end else if(wr_en && !intf.full) begin
            fifo_mem[wr_ptr] <= data_in;
            wr_ptr <= (wr_ptr +1)% DEPTH;
            cnt <= cnt +1;
        end
    end
    always_ff @(posedge clk or posedge rst) begin
        if(rst) begin 
            intf.data_out <= {DATA_WIDTH{1'b0}};
        end else if(rd_en && !intf.empty) begin
            intf.data_out <= fifo_mem[rd_ptr];
            rd_ptr <= (rd_ptr +1)%DEPTH;
            cnt <= cnt -1;
        end
    end
endmodule
//////////////////////////////////////////////////
/////////// DV
//////////////////////////////////////////////////
class driver;
    virtual fifo_intf vif;

    function new(virtual fifo_intf vif);
        this.vif =vif;
    endfunction

    task reset(input int duration = reset_duration); //Have to set a DEFAULT VALUE 
        vif.rst =1'b1;
        #(duration) vif.rst =1'b0;
    endtask

    task read();
        @(posedge vif.clk);
        vif.rd_en =1;
        @(posedge vif.clk);
        vif.rd_en =0;
    endtask

    task write(input logic [DATA_WIDTH -1:0] data_in);
        @(posedge vif.clk);
        vif.wr_en =1;
        vif.data_in =data_in;
        @(posedge vif.clk);
        vif.wr_en =0;
    endtask
endclass

class monitor;
    virtual fifo_intf vif;
    scoreboard sb; 

    function new(virtual fifo_intf vif, scoreboard sb);
        this.vif = vif;
        this.sb = sb;
    endfunction

    task run();
        forever begin
            @(posedge vif.clk);
            if (vif.rd_en) begin
                $display("%t: Read operation detected. Data read: %h", $time, vif.data_out);
                sb.add_actual_data(vif.data_out); // Pass the actual data read to the scoreboard
            end if (vif.wr_en) begin
                $display("%t: Write operation detected. Data written: %h", $time, vif.data_in);
            end
        end
    endtask
endclass

class scoreboard;

    bit [7:0] expected_data_queue[$]; 

    int total_checks = 0;
    int total_mismatches = 0;

    function void add_expected_data(bit [7:0] data);
        expected_data_queue.push_back(data);
    endfunction

    function void check_actual_data(bit [7:0] data);
        if (expected_data_queue.size() > 0) begin
            bit [7:0] expected_data = expected_data_queue.pop_front();
            total_checks++; 

            if (expected_data !== data) begin
                $display("Mismatch @ %t: Expected %h, Got %h", $time, expected_data, data);
                total_mismatches++;
            end else begin
                $display("Match @ %t: Data %h", $time, data);
            end
        end else begin
            $display("Error: Unexpected read operation with no expected data available. Actual data: %h", data);
        end
    endfunction

    // Summary report
    function void report();
        $display("Scoreboard Summary: Total Checks = %d, Total Mismatches = %d", total_checks, total_mismatches);
        if (total_mismatches == 0) begin
            $display("Verification PASSED: All data matches expected outcomes.");
        end else begin
            $display("Verification FAILED: Detected data mismatches.");
        end
    endfunction

endclass


module dv();

    parameter DATA_WIDTH = 8, DEPTH = 16;
    
    fifo_intf #(.DATA_WIDTH(DATA_WIDTH), .DEPTH(DEPTH)) intf();
    fifo #(.DATA_WIDTH(DATA_WIDTH), .DEPTH(DEPTH)) DUT(.intf(intf));

    driver     drv(intf);
    monitor    mon(intf);
    scoreboard sb();

    covergroup cg with function sample();
        coverpoint intf.rst {
            bins reset = {1};
            bins nreset = {0};
        }
        coverpoint intf.wr_en {
            bins write = {1};
            bins no_write = {0};
        }
        coverpoint intf.rd_en {
            bins read = {1};
            bins no_read = {0};
        }
        // cross intf.wr_en, intf.rd_en {
        //     bins write_then_read = binsof(intf.wr_en.write) && binsof(intf.rd_en.read);
        //     bins write_only = binsof(intf.wr_en.write) && binsof(intf.rd_en.no_read);
        //     bins read_only = binsof(intf.wr_en.no_write) && binsof(intf.rd_en.read);
        //     bins idle = binsof(intf.wr_en.no_write) && binsof(intf.rd_en.no_read);
        // }
    endgroup

    initial begin 
        $fsdbDumpfile("dump.fsdb");
        $fsdbDumpvars;

        intf.clk = 0;
        forever #5 intf.clk = ~intf.clk;
    end

    initial begin
        drv.reset(10);
        @(negedge intf.clk);
        repeat(100) begin
            fork // parallel start, Sequential Execution
                begin 
                    // automatic : runtime, freshinstance each time a block is executed in recursions.
                    logic [DATA_WIDTH -1:0] data = $urandom_range{0, 2**DATA_WIDTH -1};
                    drv.write(data);
                    sb.add_expected_data(data);
                end
                begin
                    if(!urandom_range(0,1)) 
                        drv.read();
                end
            join_any
            @(posedge intf.clk); // Synchornizing operations..
        end 
        #10 $finish;
    end
endmodule