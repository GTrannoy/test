-- Version: 8.6 SP1 8.6.1.3

library ieee;
use ieee.std_logic_1164.all;
library proasic3;
use proasic3.all;

entity DualClkRAM is 
    port( DINA : in std_logic_vector(7 downto 0); DOUTA : out 
        std_logic_vector(7 downto 0); DINB : in std_logic_vector(
        7 downto 0); DOUTB : out std_logic_vector(7 downto 0); 
        ADDRA : in std_logic_vector(8 downto 0); ADDRB : in 
        std_logic_vector(8 downto 0);RWA, RWB, BLKA, BLKB, CLKA, 
        CLKB, RESET : in std_logic) ;
end DualClkRAM;


architecture DEF_ARCH of  DualClkRAM is

    component RAM4K9
    generic (MEMORYFILE:string := "");

        port(ADDRA11, ADDRA10, ADDRA9, ADDRA8, ADDRA7, ADDRA6, 
        ADDRA5, ADDRA4, ADDRA3, ADDRA2, ADDRA1, ADDRA0, ADDRB11, 
        ADDRB10, ADDRB9, ADDRB8, ADDRB7, ADDRB6, ADDRB5, ADDRB4, 
        ADDRB3, ADDRB2, ADDRB1, ADDRB0, DINA8, DINA7, DINA6, 
        DINA5, DINA4, DINA3, DINA2, DINA1, DINA0, DINB8, DINB7, 
        DINB6, DINB5, DINB4, DINB3, DINB2, DINB1, DINB0, WIDTHA0, 
        WIDTHA1, WIDTHB0, WIDTHB1, PIPEA, PIPEB, WMODEA, WMODEB, 
        BLKA, BLKB, WENA, WENB, CLKA, CLKB, RESET : in std_logic := 
        'U'; DOUTA8, DOUTA7, DOUTA6, DOUTA5, DOUTA4, DOUTA3, 
        DOUTA2, DOUTA1, DOUTA0, DOUTB8, DOUTB7, DOUTB6, DOUTB5, 
        DOUTB4, DOUTB3, DOUTB2, DOUTB1, DOUTB0 : out std_logic) ;
    end component;

    component VCC
        port( Y : out std_logic);
    end component;

    component GND
        port( Y : out std_logic);
    end component;

    signal VCC_1_net, GND_1_net : std_logic ;
    begin   

    VCC_2_net : VCC port map(Y => VCC_1_net);
    GND_2_net : GND port map(Y => GND_1_net);
    A9D8DualClkRAM_R0C0 : RAM4K9
      port map(ADDRA11 => GND_1_net, ADDRA10 => GND_1_net, 
        ADDRA9 => GND_1_net, ADDRA8 => ADDRA(8), ADDRA7 => 
        ADDRA(7), ADDRA6 => ADDRA(6), ADDRA5 => ADDRA(5), 
        ADDRA4 => ADDRA(4), ADDRA3 => ADDRA(3), ADDRA2 => 
        ADDRA(2), ADDRA1 => ADDRA(1), ADDRA0 => ADDRA(0), 
        ADDRB11 => GND_1_net, ADDRB10 => GND_1_net, ADDRB9 => 
        GND_1_net, ADDRB8 => ADDRB(8), ADDRB7 => ADDRB(7), 
        ADDRB6 => ADDRB(6), ADDRB5 => ADDRB(5), ADDRB4 => 
        ADDRB(4), ADDRB3 => ADDRB(3), ADDRB2 => ADDRB(2), 
        ADDRB1 => ADDRB(1), ADDRB0 => ADDRB(0), DINA8 => 
        GND_1_net, DINA7 => DINA(7), DINA6 => DINA(6), DINA5 => 
        DINA(5), DINA4 => DINA(4), DINA3 => DINA(3), DINA2 => 
        DINA(2), DINA1 => DINA(1), DINA0 => DINA(0), DINB8 => 
        GND_1_net, DINB7 => DINB(7), DINB6 => DINB(6), DINB5 => 
        DINB(5), DINB4 => DINB(4), DINB3 => DINB(3), DINB2 => 
        DINB(2), DINB1 => DINB(1), DINB0 => DINB(0), WIDTHA0 => 
        VCC_1_net, WIDTHA1 => VCC_1_net, WIDTHB0 => VCC_1_net, 
        WIDTHB1 => VCC_1_net, PIPEA => VCC_1_net, PIPEB => 
        VCC_1_net, WMODEA => GND_1_net, WMODEB => GND_1_net, 
        BLKA => BLKA, BLKB => BLKB, WENA => RWA, WENB => RWB, 
        CLKA => CLKA, CLKB => CLKB, RESET => RESET, DOUTA8 => 
        OPEN , DOUTA7 => DOUTA(7), DOUTA6 => DOUTA(6), DOUTA5 => 
        DOUTA(5), DOUTA4 => DOUTA(4), DOUTA3 => DOUTA(3), 
        DOUTA2 => DOUTA(2), DOUTA1 => DOUTA(1), DOUTA0 => 
        DOUTA(0), DOUTB8 => OPEN , DOUTB7 => DOUTB(7), DOUTB6 => 
        DOUTB(6), DOUTB5 => DOUTB(5), DOUTB4 => DOUTB(4), 
        DOUTB3 => DOUTB(3), DOUTB2 => DOUTB(2), DOUTB1 => 
        DOUTB(1), DOUTB0 => DOUTB(0));
end DEF_ARCH;