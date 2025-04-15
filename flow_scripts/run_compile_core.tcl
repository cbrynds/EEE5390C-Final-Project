####### Design Setup ########
set module riscv_soc 
set outDir "./results"
define_design_lib work -path ./WORK

####### Synopsys 14nm #######
set target_library "/home/net/local/SAED14nm_EDK_08_2024/SAED14nm_EDK_STD_RVT/liberty/nldm/base/saed14rvt_base_ss0p72v125c.db"
set link_library "/home/net/local/SAED14nm_EDK_08_2024/SAED14nm_EDK_STD_RVT/liberty/nldm/base/saed14rvt_base_ss0p72v125c.db" 

####### Load Design and Elaborate #######
####### Update this portion to include the SoC RTL files ######
####### Make sure that the synthesized design is riscv_soc ####
#analyze -format verilog -autoread ../core/core/rv32imsu/ 
analyze -format verilog { 
../core/rv32imsu/riscv_decode.v
../core/rv32imsu/riscv_lsu.v
../core/rv32imsu/riscv_regfile.v
../core/rv32imsu/riscv_defs.v
../core/rv32imsu/riscv_muldiv.v
../core/rv32imsu/riscv_alu.v
../core/rv32imsu/riscv_csr.v
../core/rv32imsu/riscv_mmu_arb.v
../core/rv32imsu/riscv_core.v
../core/rv32imsu/riscv_mmu.v
../core/rv32imsu/riscv_fetch.v
../core/rv32imsu/riscv_exec.v
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
