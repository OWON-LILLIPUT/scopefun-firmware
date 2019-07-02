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
    
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mavg is
    generic (
        MAX_MAVG_LEN_LOG  : integer := 2
    );
    port (
        i_clk         : in  std_logic;
        i_rst         : in  std_logic;
        -- input
        mavg_len_log  : in integer range 0 to MAX_MAVG_LEN_LOG;
        i_data_en     : in std_logic;
        i_data        : in std_logic_vector(9 downto 0);
        -- output
        o_data_valid  : out std_logic;
        o_data        : out std_logic_vector(9 downto 0));
end mavg;

architecture Behavioral of mavg is

type t_mavg is array (0 to 2**MAX_MAVG_LEN_LOG-1) of signed(9 downto 0);
signal p_mavg : t_mavg;
signal r_acc  : signed(10+MAX_MAVG_LEN_LOG-1 downto 0);  -- average accumulator
signal cnt_invalid : unsigned(MAX_MAVG_LEN_LOG-1 downto 0):= to_unsigned(0,MAX_MAVG_LEN_LOG);
signal cnt_valid : unsigned(MAX_MAVG_LEN_LOG-1 downto 0):= to_unsigned(0,MAX_MAVG_LEN_LOG);
signal i_data_valid : std_logic;

begin

mavg: process(i_clk)
begin     
 
    if(rising_edge(i_clk)) then
        o_data_valid <= i_data_valid;
--        if (i_rst='1') then
--            i_data_valid <= '0';
--            r_acc <= (others=>'0');
--            p_mavg <= (others=>(others=>'0'));
        if (i_data_en='1') then
            -- Moving average is enabled
            -- count when dataout will be valid
            if i_data_valid = '0' then
                if cnt_invalid = to_unsigned(2**mavg_len_log-1,cnt_invalid'LENGTH) then
                    i_data_valid <= '1';
                    cnt_invalid <= to_unsigned(0,cnt_invalid'LENGTH);
                else
                    i_data_valid <= '0';
                    cnt_invalid <= cnt_invalid + 1;
                end if;
            end if;
            p_mavg <= signed(i_data)&p_mavg(0 to p_mavg'length-2);
            r_acc <= r_acc + signed(i_data) - p_mavg(p_mavg'length-1);
        else
            -- Moving average is DISABLED
            i_data_valid <= '0';
            r_acc <= (others=>'0');
            p_mavg <= (others=>(others=>'0'));
        end if;
        o_data <= std_logic_vector(r_acc(10+mavg_len_log-1 downto mavg_len_log));  -- divide by 2^mavg_len
    end if;
    
end process mavg;

end Behavioral;