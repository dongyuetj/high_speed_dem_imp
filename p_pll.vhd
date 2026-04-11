----------------------------------------------------------------
-- Entity: p_pll
-- Author: Dong Yue
-- Date: 2026-04-11 16:30:46
----------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity p_pll is
	generic(N:integer:=4);
    Port (
        sys_clk 	 : in  std_logic;
        rst_n   	 : in  std_logic;
		symb_en 	 : in std_logic_vector(N-1 downto 0):=(others=>'0');
		symb_i  	 : in std_logic_array_8(N-1 downto 0):=(others=>(others=>'0'));
		symb_q  	 : in std_logic_array_8(N-1 downto 0):=(others=>(others=>'0'));
		sync_symb_en : out std_logic_vector(N-1 downto 0):=(others=>'0');
		sync_symb_i  : out std_logic_array_16(N-1 downto 0):=(others=>(others=>'0'));
		sync_symb_q  : out std_logic_array_16(N-1 downto 0):=(others=>(others=>'0'));
    );
end p_pll;

architecture rtl of p_pll is


begin


    process(sys_clk)
    begin
        if rising_edge(sys_clk) then
            if rst_n = '0' then
                -- reset logic
            else
                -- main logic
            end if;
        end if;
    end process;

end rtl;


