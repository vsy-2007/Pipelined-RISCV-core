#include <verilated.h>
#include <verilated_vcd_c.h>
#include "Vtopmodule.h"
#include "Vtopmodule___024root.h"
#include <iostream>
#include <iomanip>
#include <memory>

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);

    // Instantiate the hardware core
    auto top = std::make_unique<Vtopmodule>();

    // Setup waveform tracing
    Verilated::traceEverOn(true);
    auto tfp = std::make_unique<VerilatedVcdC>();
    top->trace(tfp.get(), 99);
    tfp->open("waveform.vcd");

    // Core Initialization & Reset Sequence
    top->clk = 0;
    top->reset = 0;
    top->eval();
    tfp->dump(0);

    // Assert reset for 2 full clock cycles
    // for (int i = 0; i < 2; i++) {
    //     top->clk = 1; top->eval(); tfp->dump(i * 10 + 5);
    //     top->clk = 0; top->eval(); tfp->dump(i * 10 + 10);
    // }
    // top->reset = 0;

    std::cout << "----------------------------------------------------------\n";
    std::cout << "[SIM] Reset released. Running indefinitely...\n";
    std::cout << "----------------------------------------------------------\n";
    std::cout << std::left << std::setw(10) << "CYCLE"
    << std::setw(16) << "PC (HEX)"
    << "INSTRUCTION\n";
    std::cout << "----------------------------------------------------------\n";

    uint64_t cycle = 0;
    bool simulation_halted = false;
    uint32_t final_pc = 0;
    uint32_t final_x3 = 0;

    // Indefinite Simulation Loop
    while (!Verilated::gotFinish()) {
        // Clock Edge Rising
        top->clk = 1;
        top->eval();
        tfp->dump(cycle * 10 + 5);
        // Capture raw data directly from your debug ports
        uint32_t current_pc   = top->current_pc_debug;
        uint32_t current_inst = top->current_inst_debug;
        // Extract real 32-bit instruction data and handle presentation swapping
        uint32_t raw_inst = top->current_inst_debug;
        uint32_t clean_inst = ((raw_inst >> 24) & 0xFF) |
        ((raw_inst >> 8)  & 0xFF00) |
        ((raw_inst << 8)  & 0xFF0000) |
        ((raw_inst << 24) & 0xFF000000);

        // Explicitly mask and enforce strict 32-bit PC variables
        uint32_t clean_pc = (uint32_t)(top->current_pc_debug & 0xFFFFFFFF);

        // Output with fixed character-width structures to prevent data merging
        std::cout << "#" << std::left << std::setw(9) << std::dec << cycle
        << "0x" << std::right << std::setw(8) << std::hex << std::setfill('0') << clean_pc
        << "    0x" << std::setw(8) << std::hex << std::setfill('0') << clean_inst
        << std::setfill(' ') << "\n";

        // Tightened Environment Trap Detection Rule:
        // Exclusively intercept real termination hooks:
        // ECALL  = 0x00000073
        // EBREAK = 0x00100073
        if (top->sim_halt) {
            // Read the internal target verification register x3 safely
            final_x3 = top->rootp->topmodule__DOT__regfile1__DOT__reg_file[3];
            final_pc = current_pc;
            simulation_halted = true;
            break;
        }

        // Clock Edge Falling
        top->clk = 0;
        top->eval();
        tfp->dump(cycle * 10 + 10);

        cycle++;
    }

    tfp->close();

    // Verification Reporting Dashboard
    if (simulation_halted) {
        std::cout << "----------------------------------------------------------\n";
        std::cout << " [SIM STATUS] Target Exit Environment Trap Execution Caught!\n";
        std::cout << " Halted at Cycle:  " << std::dec << cycle << "\n";
        std::cout << " Final PC value:   0x" << std::hex << final_pc << "\n";
        std::cout << " Register x3 (gp): 0x" << std::hex << final_x3 << "\n";
        std::cout << "----------------------------------------------------------\n";

        if (final_x3 == 1) {
            std::cout << " VERIFICATION: [PASSED] - Core executed successfully.\n";
        } else {
            std::cout << " VERIFICATION: [FAILED] - Stopped at Test Case ID: " << std::dec << final_x3 << "\n";
        }
        std::cout << "----------------------------------------------------------\n";
    }

    return 0;
}
