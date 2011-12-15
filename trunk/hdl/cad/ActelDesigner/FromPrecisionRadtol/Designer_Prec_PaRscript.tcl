new_design -name "nanoFIP"  -family "ProASIC3" 

set_device -die "A3P400" -speed "STD" -package "208 PQFP" -speed "STD" -voltage "1.5" -iostd "LVTTL" -temprange "COM" -voltrange "COM"

import_source -merge_timing "yes" -format "EDIF" -edif_flavor "GENERIC" {C:\ohr\cern-fip\trunk\hdl\cad\PrecisionRadtol\nanofip_impl_1\nanofip.edf} -format "SDC" {C:\ohr\cern-fip\trunk\hdl\cad\ActelDesigner\FromPrecisionRadtol\Designer_Prec_TimeConstr.sdc}

compile

create_clock -name {uclk_i} -period 25 uclk_i
create_clock -name {wclk_i} -period 25 wclk_i

import_aux -format pdc {C:\ohr\cern-fip\trunk\hdl\cad\ActelDesigner\FromPrecisionRadtol\Designer_Prec_Pinout.pdc}

layout -incremental "OFF"

timer_get_clock_constraints -clock uclk_i
timer_get_clock_constraints -clock wclk_i

#close_design

