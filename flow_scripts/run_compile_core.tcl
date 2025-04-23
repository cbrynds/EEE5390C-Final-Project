####### Design Setup ########
set module riscv_soc 
set outDir "./results"
define_design_lib work -path ./WORK

####### Synopsys 14nm #######
# ran on huskey.eecs.ucf.edu
set target_library "/home1/local/SAED14nm_EDK_08_2024/SAED14nm_EDK_STD_RVT/liberty/nldm/base/saed14rvt_base_ss0p72v125c.db"
set link_library "/home1/local/SAED14nm_EDK_08_2024/SAED14nm_EDK_STD_RVT/liberty/nldm/base/saed14rvt_base_ss0p72v125c.db" 

####### Load Design and Elaborate #######
####### Update this portion to include the SoC RTL files ######
####### Make sure that the synthesized design is riscv_soc ####
#analyze -format verilog -autoread ../core/core/rv32imsu/ 
analyze -format verilog { 
../riscv_soc_master/core/core/rv32imsu/riscv_decode.v
../riscv_soc_master/core/core/rv32imsu/riscv_lsu.v
../riscv_soc_master/core/core/rv32imsu/riscv_regfile.v
../riscv_soc_master/core/core/rv32imsu/riscv_defs.v
../riscv_soc_master/core/core/rv32imsu/riscv_muldiv.v
../riscv_soc_master/core/core/rv32imsu/riscv_alu.v
../riscv_soc_master/core/core/rv32imsu/riscv_csr.v
../riscv_soc_master/core/core/rv32imsu/riscv_mmu_arb.v
../riscv_soc_master/core/core/rv32imsu/riscv_core.v
../riscv_soc_master/core/core/rv32imsu/riscv_mmu.v
../riscv_soc_master/core/core/rv32imsu/riscv_fetch.v
../riscv_soc_master/core/core/rv32imsu/riscv_exec.v
../riscv_soc_master/soc/axi4_arb.v
../riscv_soc_master/soc/axi4lite_axi4_conv.v
../riscv_soc_master/soc/axi4_lite_tap.v
../riscv_soc_master/soc/axi4_retime.v
../riscv_soc_master/soc/dport_bridge.v
../riscv_soc_master/soc/gpio_defs.v
../riscv_soc_master/soc/gpio.v
../riscv_soc_master/soc/icache_data_ram.v
../riscv_soc_master/soc/icache_tag_ram.v
../riscv_soc_master/soc/icache.v
../riscv_soc_master/soc/irq_ctrl_defs.v
../riscv_soc_master/soc/irq_ctrl.v
../riscv_soc_master/soc/riscv_soc.v
../riscv_soc_master/soc/riscv_top.v
../riscv_soc_master/soc/soc.v
../riscv_soc_master/soc/spi_lite_defs.v
../riscv_soc_master/soc/spi_lite.v
../riscv_soc_master/soc/timer_defs.v
../riscv_soc_master/soc/timer.v
../riscv_soc_master/soc/uart_lite_defs.v
../riscv_soc_master/soc/uart_lite.v
}
set top $module
elaborate -lib work $top
current_design $top
link

####### Design Flattening #######
#set_flatten true
#uniquify -force
#ungroup -flatten -all

####### Design Specification ####
source ./ss_0p9v_125c.tcl
current_design $top

####### Compile and Optimize ####
compile -area_effort high -boundary_optimization
change_names -rule verilog
group_path -name reg2reg -from [all_registers] -to [all_registers]

####### Design Exports ##########
write -hierarchy -format verilog -output "./${outDir}/${module}.v"
write_sdc "./${outDir}/${module}.sdc"
write -hierarchy -format ddc -output ./${outDir}/${module}.ddc

####### Design Reporting ##########
report_timing -group reg2reg -max_paths 1000 -path_type full_clock_expanded -slack_lesser_than 0 > reg2reg_golden_timing.rpt
report_qor > qor_report.rpt
report_power > power_report.rpt
