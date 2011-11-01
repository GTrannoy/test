
-- 
-- Definition of  VCC
-- 
--      11/01/11 18:58:16
--      
--      Precision Rad-Tolerant , 2010a_Update2.254
-- 

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.VITAL_Timing.all;

entity VCC is 
   port (
      Y : OUT std_logic) ;attribute RTLC_TECH_CELL: boolean;
   attribute RTLC_TECH_CELL of 
      VCC : entity is true;
      end VCC ;

architecture NETLIST of VCC is       
      begin
      end NETLIST ;
      

-- 
-- Definition of  GND
-- 
--      11/01/11 18:58:16
--      
--      Precision Rad-Tolerant , 2010a_Update2.254
-- 

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.VITAL_Timing.all;

entity GND is 
   port (
      Y : OUT std_logic) ;attribute RTLC_TECH_CELL: boolean;
   attribute RTLC_TECH_CELL of 
      GND : entity is true;
      end GND ;

architecture NETLIST of GND is       
      begin
      end NETLIST ;
      

-- 
-- Definition of  RAM4K9
-- 
--      11/01/11 18:58:16
--      
--      Precision Rad-Tolerant , 2010a_Update2.254
-- 

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.VITAL_Timing.all;

entity RAM4K9 is 
   generic (MEMORYFILE : string := "NONE") ;
   
   port (
      DOUTA0 : OUT std_logic ;
      DOUTA1 : OUT std_logic ;
      DOUTA2 : OUT std_logic ;
      DOUTA3 : OUT std_logic ;
      DOUTA4 : OUT std_logic ;
      DOUTA5 : OUT std_logic ;
      DOUTA6 : OUT std_logic ;
      DOUTA7 : OUT std_logic ;
      DOUTA8 : OUT std_logic ;
      DOUTB0 : OUT std_logic ;
      DOUTB1 : OUT std_logic ;
      DOUTB2 : OUT std_logic ;
      DOUTB3 : OUT std_logic ;
      DOUTB4 : OUT std_logic ;
      DOUTB5 : OUT std_logic ;
      DOUTB6 : OUT std_logic ;
      DOUTB7 : OUT std_logic ;
      DOUTB8 : OUT std_logic ;
      ADDRA0 : IN std_logic ;
      ADDRA1 : IN std_logic ;
      ADDRA2 : IN std_logic ;
      ADDRA3 : IN std_logic ;
      ADDRA4 : IN std_logic ;
      ADDRA5 : IN std_logic ;
      ADDRA6 : IN std_logic ;
      ADDRA7 : IN std_logic ;
      ADDRA8 : IN std_logic ;
      ADDRA9 : IN std_logic ;
      ADDRA10 : IN std_logic ;
      ADDRA11 : IN std_logic ;
      ADDRB0 : IN std_logic ;
      ADDRB1 : IN std_logic ;
      ADDRB2 : IN std_logic ;
      ADDRB3 : IN std_logic ;
      ADDRB4 : IN std_logic ;
      ADDRB5 : IN std_logic ;
      ADDRB6 : IN std_logic ;
      ADDRB7 : IN std_logic ;
      ADDRB8 : IN std_logic ;
      ADDRB9 : IN std_logic ;
      ADDRB10 : IN std_logic ;
      ADDRB11 : IN std_logic ;
      BLKA : IN std_logic ;
      WENA : IN std_logic ;
      PIPEA : IN std_logic ;
      WMODEA : IN std_logic ;
      WIDTHA1 : IN std_logic ;
      WIDTHA0 : IN std_logic ;
      BLKB : IN std_logic ;
      WENB : IN std_logic ;
      PIPEB : IN std_logic ;
      WMODEB : IN std_logic ;
      WIDTHB1 : IN std_logic ;
      WIDTHB0 : IN std_logic ;
      DINA0 : IN std_logic ;
      DINA1 : IN std_logic ;
      DINA2 : IN std_logic ;
      DINA3 : IN std_logic ;
      DINA4 : IN std_logic ;
      DINA5 : IN std_logic ;
      DINA6 : IN std_logic ;
      DINA7 : IN std_logic ;
      DINA8 : IN std_logic ;
      DINB0 : IN std_logic ;
      DINB1 : IN std_logic ;
      DINB2 : IN std_logic ;
      DINB3 : IN std_logic ;
      DINB4 : IN std_logic ;
      DINB5 : IN std_logic ;
      DINB6 : IN std_logic ;
      DINB7 : IN std_logic ;
      DINB8 : IN std_logic ;
      RESET : IN std_logic ;
      CLKA : IN std_logic ;
      CLKB : IN std_logic) ;attribute RTLC_TECH_CELL: boolean;
   attribute RTLC_TECH_CELL of 
      RAM4K9 : entity is true;
      end RAM4K9 ;

architecture NETLIST of RAM4K9 is       
      begin
      end NETLIST ;
      
