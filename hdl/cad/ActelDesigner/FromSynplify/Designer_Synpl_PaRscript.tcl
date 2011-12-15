new_design -name "nanoFIP"  -family "ProASIC3" 


set_device -die "A3P400" -speed "STD" -package "208 PQFP" -speed "STD" -voltage "1.5" -iostd "LVTTL" -temprange "COM" -voltrange "COM"

import_source -merge_timing "yes" -format "EDIF" -edif_flavor "GENERIC" {C:\ohr\cern-fip\trunk\hdl\cad\Synplify\nanofip.edn} -format "SDC" {C:\ohr\cern-fip\trunk\hdl\cad\ActelDesigner\FromSynplify\Designer_Synpl_TimeConstr.sdc}

compile

create_clock -name {uclk_i} -period 25 uclk_i
create_clock -name {wclk_i} -period 25 wclk_i

import_aux -format "PDC" {C:\ohr\cern-fip\trunk\hdl\cad\libero\nanoFip\constraint\Designer_Synpl_Pinout.pdc}

layout -incremental "OFF"

timer_get_clock_constraints -clock uclk_i
timer_get_clock_constraints -clock wclk_i

#close_design