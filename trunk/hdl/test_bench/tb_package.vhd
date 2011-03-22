library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;


package tb_package is

constant max_frame_length		: integer := 131;
subtype byte_count_type			is integer range 0 to max_frame_length-1;
type vector_type				is array (max_frame_length-1 downto 0) of std_logic_vector(7 downto 0);
constant reset_max_latency				: time := 2 ms;

subtype byte_slice is integer range 0 to 7;
subtype byte_width is integer range 8 downto 1;
subtype jitter_time	is time range 0 fs to 1 ms;

component hex_byte_transcriber
	port(
		input		: in std_logic_vector(7 downto 0);
		output		: out string (1 to 2)
	);
end component;

component bin_byte_transcriber
	port(
		input		: in std_logic_vector(7 downto 0);
		output		: out string (1 to 8)
	);
end component;

end tb_package;

package body tb_package is
end tb_package;
