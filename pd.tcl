### EEE-5390C: Full Custom VLSI Design
### Function: Performing Physical Design in 14nm Synopsys Technology

set design_path "./results/"
set design_name "riscv_core"

global design_name
global design_path

set design_file "${design_name}.v"
set sdc_file "${design_name}.sdc"
set lib_path "/home/net/local/SAED14nm_EDK_08_2024"

#cd $workpath

# Create library
set DESIGN_LIBRARY $design_name
set target_library " \
    $lib_path/SAED14nm_EDK_STD_RVT/liberty/nldm/base/saed14rvt_base_ss0p72v125c.db \
    $lib_path/SAED14nm_EDK_STD_RVT/liberty/nldm/base/saed14rvt_base_ff0p88vm40c.db \
    $lib_path/SAED14nm_EDK_STD_RVT/liberty/nldm/base/saed14rvt_base_tt0p8v25c.db"

set search_path "$search_path $design_path"
set link_library $target_library
create_lib $DESIGN_LIBRARY -technology "$lib_path/SAED14nm_EDK_TECH_DATA/tf/saed14nm_1p9m.tf"
set_ref_libs -library $DESIGN_LIBRARY -ref_libs "$lib_path/SAED14nm_EDK_STD_RVT/lef/saed14rvt.lef $lib_path/SAED14nm_EDK_SRAM/lef/saed14sram.lef"

# Read design
read_verilog -top $design_name "$design_path$design_file"
current_block $design_name
link_block -force
save_lib
commit_upf
associate_mv_cells -all
reset_design

# Define TLU+ files
set TLUPLUS_FILE(Cmax) "$lib_path/SAED14nm_EDK_TECH_DATA/tlup/saed14nm_1p9m_Cmax.tlup"
set TLUPLUS_FILE(Cmin) "$lib_path/SAED14nm_EDK_TECH_DATA/tlup/saed14nm_1p9m_Cmin.tlup"
set TLUPLUS_FILE(nominal) "$lib_path/SAED14nm_EDK_TECH_DATA/tlup/saed14nm_1p9m_Cnom.tlup"
set TLUPLUS_MAP_FILE "$lib_path/SAED14nm_EDK_TECH_DATA/map/saed14nm_tf_itf_tluplus.map"

# Define corners
set cornerData {
  {ss0p72v125c  ss  Cmax     0.99 125 0.72}
  {ff0p88vm40c  ff  Cmin     1.01 -40 0.88}
  {tt0p8v25c    tt  nominal  1.00 25  0.80}
}

foreach corner_data $cornerData {
    set corner_name            [lindex $corner_data 0]
    set corner_parasitic       [lindex $corner_data 2]
    create_corner  $corner_name
    current_corner $corner_name
    read_parasitic_tech -tlup $TLUPLUS_FILE($corner_parasitic) -layermap $TLUPLUS_MAP_FILE -name $corner_parasitic
    set_parasitic_parameters -corner $corner_name -library [file tail $DESIGN_LIBRARY] -early_spec $corner_parasitic -late_spec $corner_parasitic
    set_operating_conditions $corner_name 
}

report_corners -verbose

# Define scenarios
set scenarioData {
   " .*  ss0p72v125c    setup false {{-0.02 capture} { 0.02 launch} { 0.02 data}}"
   " .*  ff0p88vm40c    hold  false {{0.06 capture} { -0.06 launch} { 0.06 data}}"
   " .*  tt0p8v25c      leak  true  {}"
}

set mode func
create_mode $mode
foreach scenario $scenarioData {
   set corner_name    [lindex $scenario 1]
   set check_type     [lindex $scenario 2]
   set scenario_name ${mode}@${corner_name}.${check_type}
   create_scenario -name $scenario_name -mode $mode -corner $corner_name
   current_scenario $scenario_name
   read_sdc "$design_path$sdc_file"
}

## Floorplan ##
# Floorplan Initialization
initialize_floorplan -shape R -side_ratio 1.0 -core_utilization 0.50 -core_offset {5 5 5 5}
## Power RAIL
remove_pg_via_master_rules -all
remove_pg_strategy_via_rules -all
remove_pg_regions -all
remove_pg_patterns -all
remove_pg_strategies -all

create_net -power VDD
create_net -ground VSS
connect_pg_net -net VDD [get_pins -physical_context *VDD]
connect_pg_net -net VSS [get_pins -physical_context *VSS]
### POWER RINGS
create_pg_ring_pattern ring_pat -horizontal_layer {M9} -horizontal_width 0.18 -horizontal_spacing 0.18 -vertical_layer M8 -vertical_width 0.18 -vertical_spacing 0.18
set_pg_strategy ring_strat -core -pattern {{name: ring_pat} {nets: {VDD VSS}} {offset: {3 3}}  {parameters: {M9 10 2 M8 10 2 true}}} -extension {{stop: design_boundary}}
set_pg_strategy_via_rule ring_strat_via -via_rule { {{intersection: undefined} {via_master: nil}}}
compile_pg -strategies ring_strat -via_rule ring_strat_via

### Power Rails
create_pg_std_cell_conn_pattern rail_pat_m1 -layers M1 -rail_width 0.096
set_pg_strategy rail_strat_m1 -core -pattern  { {name: rail_pat_m1} {nets: VDD VSS} }
set_pg_strategy_via_rule rail_rule_m1 -via_rule { {{intersection: undefined} {via_master: nil}} }
compile_pg -strategies rail_strat_m1 -via_rule rail_rule_m1

### Power Mesh
create_pg_mesh_pattern mesh_pattern -layers {{{vertical_layer: M6} {width: 0.12} {pitch: 50} {offset: 20}} {{horizontal_layer: M5} {width: 0.6} {pitch: 50} {offset: 20}}}
set_pg_strategy mesh_strat -core -pattern {{pattern: mesh_pattern} {nets: {VDD VSS}}} -extension {{stop: outermost_ring}}
compile_pg -strategies mesh_strat
associate_mv_cells

### Pin placement
set_block_pin_constraints -allowed_layers {M3 M4} -pin_spacing 2 -sides {1 3} -width {0.056} -length {0.4} -self -allow_feedthroughs true
place_pins -self

# Power Network Setup
connect_pg_net -net VDD [get_pins -physical_context *VDD]
connect_pg_net -net VSS [get_pins -physical_context *VSS]
save_block -as floorplan 

## Placement ##
current_scenario func@ss0p72v125c.setup 
set_app_options -name place.coarse.continue_on_missing_scandef -value true
place_opt
save_block -as placeopt
report_congestion
report_utilization

## Clock-Tree-Synthesis ##
current_scenario func@ss0p72v125c.setup
check_clock_tree
report_clock_settings
synthesize_clock_tree -cts_only
report_clock_qor
synthesize_clock_tree -cto_only ;# Balance Tree
report_clock_qor
compute_clock_latency
update_timing -force -full
route_group -all_clock_nets -reuse_existing_global_route true -max_detail_route_iterations 10
synthesize_clock_trees -postroute -routed_clock_stage detail
report_clock_qor
save_block -as cts 
clock_opt -from build_clock -to route_clock
clock_opt -from final_opto
route_group -all_clock_nets
save_block -as clockopt 
report_clock_timing -type summary
report_clock_qor

## Routing ##
route_opt

# Generate Reports & Outputs
connect_pg_net
report_qor > "$design_path/qor.rpt"
save_block -as routeopt

## Saving/Exporting Design ##
write_verilog "./results/${design_name}.pd.v"
write_parasitics -output "./${design_name}.pd.spef"
write_sdc -output "./results/${design_name}.pd.sdc"
write_def "./results/${design_name}.pd.def"
write_gds "./results/${design_name}.pd.gds" -hierarchy all -merge_gds_top_cell $design_name
