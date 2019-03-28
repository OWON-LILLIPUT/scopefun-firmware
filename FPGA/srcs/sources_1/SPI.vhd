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
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity SPI is
    generic (
           SPI_LENGTH : integer -- NUMBER OF BITS TRANSFERED
    );
    Port ( clk : in  std_logic;								      -- input clock
           rst : in std_logic;                                    -- reset spi_interface
           clk_divide : in std_logic_vector (4 downto 0);	      -- input clock divide (0 to 31)
           spi_data : in  std_logic_vector (SPI_LENGTH-1 downto 0); -- data for writing to SI port
           spi_write_trig : in std_logic;					      -- trigger for starting write to SI port
           sck_idle_value : in std_logic;                         -- value of sck when not sending bytes
           spi_busy : out std_logic;						      -- SPI is busy writing data
           cs : out  std_logic;								      -- SPI out signal CS#
           sck : out  std_logic;							      -- SPI out signal SCK 
           si : out  std_logic                                    -- SPI out signal SI 
      );							
end SPI;

architecture Behavioral of SPI is

signal spi_state : std_logic_vector (1 downto 0):="00";

CONSTANT SPI_A: STD_LOGIC_VECTOR (1 downto 0) := "00";
CONSTANT SPI_B: STD_LOGIC_VECTOR (1 downto 0) := "01";
CONSTANT SPI_C: STD_LOGIC_VECTOR (1 downto 0) := "10";
CONSTANT SPI_D: STD_LOGIC_VECTOR (1 downto 0) := "11";

signal clk_cnt : integer range 0 to (2*SPI_LENGTH)-1 := 0;
signal spi_cnt : integer range 0 to SPI_LENGTH-1 := SPI_LENGTH-1;

signal spi_busy_i : std_logic := '0';
signal spi_busy_i_d : std_logic := '0';
signal sck_i : std_logic := '0';
signal spi_write_trig_d : std_logic := '0';
signal start_spi_write : std_logic := '0';
signal rst_d : std_logic := '0';
signal reset : std_logic := '0';
signal spi_idle_wait_cnt : integer range 0 to 3 := 0;

attribute mark_debug: boolean;

attribute mark_debug of spi_state : signal is true;
attribute mark_debug of spi_cnt : signal is true;
attribute mark_debug of spi_idle_wait_cnt : signal is true;

begin

	sck <= sck_i;

clk_enable_generate: process(clk) 

begin

	-- generate clk_enable signal for SCK:
	-- sck [period] = 2 * clk * (clk_divide + 1)
	-- Example if clk = 20 ns, clk_divide = 9
	--------> sck = 2 * 20 ns * 10 = 400 ns

	if rising_edge (clk) then
		if clk_cnt = to_integer(unsigned(clk_divide)) then
			clk_cnt <= 0;
		else
			clk_cnt <= clk_cnt + 1;
		end if;
	end if;
	
end process;

spi_signals_generate: process(clk)

begin

	if rising_edge (clk) then

        rst_d <= rst;
        if rst_d = '0' and rst = '1' then
            reset <= '1';
        end if;
		-- monitor spi_write_trig transition from '0' to '1'	
		spi_write_trig_d <= spi_write_trig;
		if spi_write_trig_d = '0' and spi_write_trig = '1' then
			start_spi_write <= '1';
			spi_busy <= '1';
		end if;	
			
		-- clk_enable
		if clk_cnt = 0 then
			
	    -- monitor spi_busy_i transition from '1' to '0'
        -- and reset spi_busy signal
        spi_busy_i_d <= spi_busy_i;
        if spi_busy_i_d = '1' and spi_busy_i = '0' then
            spi_busy <= '0';
        end if;
				
			case spi_state(1 downto 0) is
		
			when SPI_A =>		-- "IDLE STATE"
	
				spi_busy_i <= '0';
				si <= spi_data(SPI_LENGTH-1);
                if (start_spi_write = '1') then
                    sck_i <= '0';
                    cs <= '0';
                    start_spi_write <= '0';
                    spi_state <= SPI_B;
                elsif (reset = '1') then
                    reset <= '0';
                    spi_state <= SPI_C;
                    sck_i <= sck_idle_value;
                    cs <= '1';	         
                else
				    cs <= '1';
				    sck_i <= sck_idle_value;
                    spi_state <= SPI_A;
                end if;
				
			when SPI_B =>		-- "SPI DATA WRITING STATE"

                spi_busy_i <= '1';
                reset <= '0';
                start_spi_write <= '0';
                cs <= '0';
                sck_i <= NOT(sck_i);
                si <= spi_data(spi_cnt);
                if sck_i = '0' then
                    if spi_cnt = 0 then
                        spi_cnt <= SPI_LENGTH-1;
                        spi_state <= SPI_D;
                    else
                        spi_cnt <= spi_cnt - 1;
                        spi_state <= SPI_B;
                    end if;
                end if;
                
            when SPI_C =>      -- "SPI RESET"
                
                -- wirte spi data only 3 sck cycles to reset SPI
                spi_busy_i <= '1';
                reset <= '0';
                cs <= '0';
                sck_i <= NOT(sck_i);
                si <= spi_data(spi_cnt);
                if sck_i = '0' then
                    if spi_cnt = SPI_LENGTH-3 then
                        spi_cnt <= SPI_LENGTH-1;
                        spi_state <= SPI_D;
                    else
                        spi_cnt <= spi_cnt - 1;
                        spi_state <= SPI_C;
                    end if;
                end if;
            
            when SPI_D =>    -- "WAIT in IDLE STATE after each SPI write sequence"
                
                spi_busy_i <= '1';
                sck_i <= sck_idle_value;
                reset <= '0';
                cs <= '1';
                if spi_idle_wait_cnt = 3 then
                    spi_idle_wait_cnt <= 0;
                    spi_state <= SPI_A;
                else
                    spi_state <= SPI_D;
                    spi_idle_wait_cnt <= spi_idle_wait_cnt + 1;
                end if;
			
			when others =>

				cs <= '1';
				sck_i <= '0';
				si <= '0';
			    spi_idle_wait_cnt <= 0;
			    reset <= '0';
				spi_busy_i <= '1';
				spi_state <= SPI_A;
			
			end case;
			
		end if; -- //clk_cnt
	end if; -- //clk
					  
end process;

end Behavioral;

