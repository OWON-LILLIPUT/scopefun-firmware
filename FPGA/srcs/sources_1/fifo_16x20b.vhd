----------------------------------------------------------------------------------
--    Copyright (C) 2019 Dejan Priversek
--
--    This program is free software: you can redistribute it and/or modify
--    it under the terms of the GNU General Public License as published by
--    the Free Software Foundation, either version 3 of the License, or
--    (at your option) any later version.
--
--    This program is distributed in the hope that it will be useful,
--    but WITHOUT ANY WARRANTY; without even the implied warranty of
--    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--    GNU General Public License for more details.
--
--    You should have received a copy of the GNU General Public License
--    along with this program.  If not, see <http://www.gnu.org/licenses/>.
----------------------------------------------------------------------------------

--
-- Shallow FIFO for ADC data capture (clk1, clk2 from same clock source, but different phase)
--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity fifo_16x20b is
    port (
        clk_wr : in std_logic;
        clk_rd : in std_logic;
        we   : in std_logic;
        di  : in std_logic_vector(19 downto 0);
        do  : out std_logic_vector(19 downto 0));
end fifo_16x20b;

architecture Behavioral of fifo_16x20b is

constant DATA_DEPTH : integer := 16;
constant DATA_WIDTH : integer := 20;

signal addr1 : integer range 0 to 15 := 0;
signal addr2 : integer range 0 to 15 := 15;
signal enb : std_logic := '0';
signal enb_d : std_logic := '0';
signal enb_dd : std_logic := '0';
signal enable_in : std_logic := '0';
signal enable_out : std_logic := '0';
signal cnt : integer range 0 to 7 := 0;
signal we_d : std_logic;
signal we_dd : std_logic;

type ram_type is array (DATA_DEPTH-1 downto 0) of std_logic_vector (DATA_WIDTH-1 downto 0);
signal RAM : ram_type := (others => (others => '0'));

ATTRIBUTE ram_style: string;
ATTRIBUTE ram_style OF ram: SIGNAL IS "distributed";

-- attribute strings
attribute KEEP: boolean;
attribute ASYNC_REG: boolean;
-- assign KEEP and ASYNC_REG
attribute KEEP of enb: signal is true;
attribute KEEP of enb_d: signal is true;
attribute KEEP of enb_dd: signal is true;
attribute ASYNC_REG of enb: signal is true;
attribute ASYNC_REG of enb_d: signal is true;
attribute ASYNC_REG of enb_dd: signal is true;
attribute KEEP of we_d: signal is true;
attribute KEEP of we_dd: signal is true;
attribute ASYNC_REG of we_d: signal is true;
attribute ASYNC_REG of we_dd: signal is true;

begin

clk_wr_side_write:process (clk_wr)
begin
    if (rising_edge(clk_wr)) then
        we_d <= we;
        we_dd <= we_d;
        if we_dd = '0' and we_d = '1' then
            enable_in <= '1';
        end if;
        if (enable_in = '1') then
            RAM(addr1) <= di;
            if addr1 = 15 then
                addr1 <= 0;
            else
                addr1 <= addr1 + 1;
            end if;
            if cnt = 3 then
                enb <= '1';
            else
                cnt <= cnt + 1;
            end if;
        end if;
     end if;
end process;
  
clk_rd_side_read:process (clk_rd)
begin
    if (rising_edge(clk_rd)) then
        enb_d <= enb;
        enb_dd <= enb_d;
        if enb_dd = '0' and enb_d = '1' then
            enable_out <= '1';
        end if;
        if enable_out = '1' then
            if addr2 = 15 then
                addr2 <= 0;
            else
                addr2 <= addr2 + 1;
            end if;
            do <= RAM(addr2);
        end if;
    end if;
end process;

end Behavioral;