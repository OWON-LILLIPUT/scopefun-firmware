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


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity fifo_16x20b_tb is
end fifo_16x20b_tb;

architecture Behavioral of fifo_16x20b_tb is

    constant CLK1_TO_CLK2_SKEW : time := 3.8 ns;

    component fifo_16x20b is
    port (
        clk_wr : in std_logic;
        clk_rd : in std_logic;
        we   : in std_logic;
        di  : in std_logic_vector(19 downto 0);
        do  : out std_logic_vector(19 downto 0));
    end component;
    
    signal clk_wr : std_logic := '0';
    signal clk_rd : std_logic := '0';
    signal we : std_logic := '0';
    signal di : std_logic_vector(19 downto 0) := std_logic_vector(to_unsigned(0,20));
    signal do : std_logic_vector(19 downto 0) := std_logic_vector(to_unsigned(0,20));
    signal do_synced : std_logic_vector(19 downto 0) := std_logic_vector(to_unsigned(0,20));
    
    constant clk_period : time := 4 ns;
    
    signal inf_loop : std_logic := '1';
    signal cnt : integer range 0 to 15 := 0;
    
begin

    test_fifo_16x20b : fifo_16x20b
    port map (  
        clk_wr => clk_wr,
        clk_rd => clk_rd,
        we => we,
        di => di,
        do => do
        );
        
   -- Clock process definitions
    clk1_process : process
    begin
         clk_wr <= '0';
         wait for clk_period/2;
         clk_wr <= '1';
         wait for clk_period/2;
    end process;

    clk2_process : process
    begin
         wait for CLK1_TO_CLK2_SKEW;
            while inf_loop = '1' loop 
                clk_rd <= '0';
                wait for clk_period/2;
                clk_rd <= '1';
                wait for clk_period/2;
            end loop;
    end process;
    
    data_feed_proc: process
        variable di_tmp : integer range 0 to 1023 := 0;
    begin
        for i in 1 to 3 loop
            wait until rising_edge(clk_wr);
        end loop;
        while inf_loop = '1' loop
            wait until rising_edge(clk_wr);
            if di_tmp = 1023 then
                di_tmp := 0;
            else
                di_tmp := di_tmp + 1;
            end if;
            di <= std_logic_vector(to_unsigned(di_tmp,20));
            if cnt = 15 then
                we <= '1';
            else
                cnt <= cnt + 1;
            end if;
        end loop;
    end process;

    data_read_proc: process
        variable di_tmp : integer range 0 to 1023 := 0;
    begin
        for i in 1 to 3 loop
            wait until rising_edge(clk_rd);
        end loop;
        while inf_loop = '1' loop
            wait until rising_edge(clk_wr);
            do_synced <= do;
        end loop;
    end process;

end Behavioral;
