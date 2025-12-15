----------------------------------------------------------------
-- Author: dong yue
-- Date: 2024/9/25
-- Email: y.dong@outlook.com
-- Description:
-- Version:
-----------------------------------------------------------------

library IEEE;                
use IEEE.STD_LOGIC_1164.ALL; 
use IEEE.NUMERIC_STD.ALL;

library work;
use work.my_dem_pkg.all;

entity interp_ctrl is
	port(
			sys_clk		: in std_logic;
			aresetn 	: in std_logic;
			samp_vld	: in std_logic;
			xI_t		: in std_logic_vector(24 downto 0);
			yI_t		: in std_logic_vector(24 downto 0);
			underflow   : in std_logic;
			cnt	 		: in std_logic_vector(24 downto 0);
			update_rdy : out std_logic;
			mu_next    : out signed(24 downto 0);
			W_next     : out signed(24 downto 0)
	
		);
end interp_ctrl;

architecture arch of interp_ctrl is

	component div_gen
		port (
				 aclk : in std_logic;
				 aresetn : in std_logic;
				 s_axis_divisor_tvalid : in std_logic;
				 s_axis_divisor_tdata : in std_logic_vector(31 downto 0);
				 s_axis_dividend_tvalid : in std_logic;
				 s_axis_dividend_tdata : in std_logic_vector(47 downto 0);
				 m_axis_dout_tvalid : out std_logic;
				 m_axis_dout_tdata : out std_logic_vector(79 downto 0) 
			 );
	end component;

	-- TLL gain is 2^10
	type signed_array_25 is array (natural range<>) of signed(24 downto 0);
	-- Q8.16
	constant Q_ONE		: signed(24 downto 0):= "0000000010000000000000000";
	constant Q_HALF_ONE	: signed(24 downto 0):= "0000000001000000000000000";
	constant MINIMAL	: signed(24 downto 0):= "0000000000000001000000000";
	-- agc REF = 64
	-- loop factor = 2^8
	-- K1 = -0.0098
	-- K2 = -3.2812e-05 
	constant K1			: signed(24 downto 0):=to_signed(-645, 25);
	constant K2			: signed(24 downto 0):=to_signed(-2, 25);
	signal mu_t  	: signed(24 downto 0):=Q_HALF_ONE;
	signal TED_buff_x	: signed_array_25(1 downto 0):=(others=>(others=>'0'));
	signal TED_buff_y	: signed_array_25(1 downto 0):=(others=>(others=>'0')); 
	signal err			: signed(49 downto 0):=(others=>'0'); 
	signal err_t		: signed(24 downto 0):=(others=>'0'); 
	signal vi			: signed(49 downto 0):=(others=>'0'); 
	signal vp			: signed(49 downto 0):=(others=>'0'); 
	signal v			: signed(49 downto 0):=(others=>'0'); 
	signal v_div		: signed(49 downto 0):=(others=>'0'); 
	signal v_div_t		: signed(24 downto 0):=(others=>'0'); 
	signal W			: signed(24 downto 0):=Q_HALF_ONE; --sps = 2;
	signal W_t			: signed(24 downto 0):=Q_HALF_ONE;
	signal dividend  	: std_logic_vector(47 downto 0):=(others=>'0');
	signal divisor   	: std_logic_vector(31 downto 0):=x"00000001";
	signal quotient  	: std_logic_vector(79 downto 0):=(others=>'0');
	signal cnt_reg		: std_logic_vector(24 downto 0):=(others=>'0');
	signal div_out_vld  : std_logic:='0';
	signal div_in_vld 	: std_logic:='0';
	signal calc_st 		: std_logic_vector(3 downto 0):=(others=>'0');
begin      

	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if samp_vld = '1' then
				TED_buff_x(0) <= signed(xI_t);
				TED_buff_x(1) <= TED_buff_x(0);
				TED_buff_y(0) <= signed(yI_t);
				TED_buff_y(1) <= TED_buff_y(0);
			end if;
		end if;
	end process; 

	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if aresetn = '0' then
				calc_st <= "0000";
			else
				case calc_st is
					when "0000" =>
						if (samp_vld = '1') and (underflow = '1') then
							calc_st <= "0001";
						end if;
					when "0001" =>
							calc_st <= "0010";
					when "0010" =>
							calc_st <= "0011";
					when "0011" =>
							calc_st <= "0100";
					when "0100" =>
							calc_st <= "0101";
					when "0101" =>
							calc_st <= "0110";
					when "0110" =>
							calc_st <= "0111";
					when "0111" =>
							calc_st <= "1000";
					when "1000" =>
							calc_st <= "1001";
					when "1001" =>
							calc_st <= "1010";
					when "1010" =>
						if div_out_vld = '1' then
							calc_st <= "0000";
						end if;
					when others => null;
				end case;
			end if;
		end if;
	end process;

	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if aresetn = '0' then
				err <= (others=>'0'); 
				vp <= (others=>'0'); 
				vi <= (others=>'0'); 
				v <= (others=>'0'); 
				W <= Q_HALF_ONE;
				W_t <= Q_HALF_ONE;
				dividend <= (others=>'0'); 
				divisor  <= x"00000001";
				mu_t <= Q_HALF_ONE;
				update_rdy <= '0';
			else
				case calc_st is
					when "0000" =>
						update_rdy <= '0';
						if (samp_vld = '1') and (underflow = '1') then
							err <= TED_buff_x(0)*(TED_buff_x(1) - signed(xI_t)) + TED_buff_y(0)*(TED_buff_y(1) - signed(yI_t));
						end if;
						if samp_vld = '1' then
							cnt_reg <= cnt;
						end if;
					when "0001" =>
						if err(49 downto 40) = "0000000000" or err(49 downto 40) = "1111111111" then
							err_t(24 downto 16) <= err(40 downto 32);
						elsif err(49) = '0' then
							err_t(24 downto 16) <= "011111111";
						elsif err(49) = '1' then
							err_t(24 downto 16) <= "100000001";
						end if;
						err_t(15 downto 0) <= err(31 downto 16);
					when "0010" =>
						vp <= K1 * err_t;
					when "0011" =>
						vi <= vi + K2 * err_t;
					when "0100" =>
						v <= vp + vi;
					when "0101" =>
						v_div <= resize(v(49 downto 8), v_div'length); -- sign-extend to full width
					when "0110" =>
						v_div_t(24 downto 16) <= v_div(40 downto 32);
						v_div_t(15 downto 0)  <= v_div(31 downto 16);
					when "0111" =>
						W <= Q_HALF_ONE + v_div_t;
					when "1000" =>
						if  W /= to_signed(0, W'length) then 
							W_t <= W ;
						else 
							W_t <= MINIMAL;
						end if;
					when "1001" =>
						dividend(40 downto 0) <= cnt_reg & "0000000000000000";
						divisor(24 downto 0)  <= std_logic_vector(W_t);
						div_in_vld <= '1';
					when "1010" =>
						div_in_vld <= '0';
						if div_out_vld = '1' then
							update_rdy <= '1';
							if quotient(72 downto 56) = "00000000000000000" or quotient(72 downto 56) = "11111111111111111" then
								mu_t <= signed(quotient(56 downto 32));
							elsif quotient(72) = '0' then
								mu_t <= Q_ONE; -- 1 - 1/2
							elsif quotient(72) = '1' then 
								mu_t <= MINIMAL;
							end if;
						end if;
					when others => null;
				end case;
			end if;
		end if;
	end process; 

	mu_next <= mu_t;  
	W_next  <= W_t;   

	u_div_gen: div_gen
	port map(
				aclk 						=> sys_clk,
				aresetn 					=> aresetn,
				s_axis_divisor_tvalid 		=> div_in_vld,
				s_axis_divisor_tdata 		=> divisor,
				s_axis_dividend_tvalid 		=> div_in_vld,
				s_axis_dividend_tdata 		=> dividend,
				m_axis_dout_tvalid 			=> div_out_vld,
				m_axis_dout_tdata 			=> quotient
			);

END ARCH;
