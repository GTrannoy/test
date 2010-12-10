-- Created by : G. Penacoba
-- Creation Date: Oct 2010
-- Description: Set the wdog and txerr signals according to the configuration
--				and schedule retrieved from text files.
-- Modified by:
-- Modification Date:
-- Modification consisted on:

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_textio.all;
use std.textio.all;
use work.tb_package.all;

entity transmission_meddler is
	port(
		txerr					: out std_logic;
		wdgn					: out std_logic
	);
end transmission_meddler;

architecture archi of transmission_meddler is

begin

	txerr					<= '0';
	wdgn					<= '1';

end archi;

