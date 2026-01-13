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

entity tll_new is
	port(
			sys_clk		: in std_logic;
			aresetn 	: in std_logic;
			samp_vld	: in std_logic;
			samp_i		: in std_logic_vector(8 downto 0);
			samp_q		: in std_logic_vector(8 downto 0);
			en_sym 		: out std_logic;
			sym_i		: out std_logic_vector(24 downto 0);
			sym_q		: out std_logic_vector(24 downto 0)
		);
end tll_new;

architecture arch of tll_new is

	component interp_ctrl
	port(
			sys_clk		: in std_logic;
			aresetn 	: in std_logic;
			samp_vld	: in std_logic;
			xI_t		: in std_logic_vector(24 downto 0);
			yI_t		: in std_logic_vector(24 downto 0);
			underflow   : in std_logic;
			update_rdy 	: out std_logic;
			cnt	 		: in std_logic_vector(24 downto 0);
			mu_next		: out signed(24 downto 0);
			W_next		: out signed(24 downto 0)
		);
	end component;

	constant Q_ONE		: signed(24 downto 0):= "0000000010000000000000000";
	constant Q_HALF_ONE	: signed(24 downto 0):= "0000000001000000000000000";
	constant MINIMAL	: signed(24 downto 0):= "0000000000000001000000000";
	signal samp_i_q		: std_logic_vector(24 downto 0):=(others=>'0');
	signal samp_q_q		: std_logic_vector(24 downto 0):=(others=>'0');
	signal samp_i_d		: std_logic_vector(24 downto 0):=(others=>'0');
	signal samp_q_d		: std_logic_vector(24 downto 0):=(others=>'0');
	signal cnt			: signed(24 downto 0):=Q_ONE;
	signal cnt_in			: signed(24 downto 0):=Q_ONE;
	signal xI			: signed(49 downto 0):=(others=>'0');
	signal yI			: signed(49 downto 0):=(others=>'0');
	signal underflow	: std_logic:='1';
	signal mu			: signed(24 downto 0):=Q_HALF_ONE;
	signal W			: signed(24 downto 0):=Q_HALF_ONE; --sps = 2;
	signal mu_next		: signed(24 downto 0):=Q_HALF_ONE;
	signal W_next		: signed(24 downto 0):=Q_HALF_ONE; --sps = 2;
	signal xI_t			: std_logic_vector(24 downto 0):=(others=>'0');
	signal yI_t			: std_logic_vector(24 downto 0):=(others=>'0');
	signal update_rdy 	: std_logic:='0';

begin      

	-- int to q8.16
	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if samp_vld = '1' then 
				samp_i_q(24 downto 16) <= samp_i(8 downto 0);
				samp_q_q(24 downto 16) <= samp_q(8 downto 0);
				samp_i_q(15 downto 0) <= (others=>'0'); 
				samp_q_q(15 downto 0) <= (others=>'0'); 
				samp_i_d <= samp_i_q ;
				samp_q_d <= samp_q_q ;
			end if;
		end if;
	end process; 

	process(sys_clk)
		variable cnt_next :signed(24 downto 0):= (others=>'0');
	begin
		if rising_edge(sys_clk) then
			if aresetn = '0' then
				cnt <= Q_ONE;
				xI <= (others=>'0'); 
				yI <= (others=>'0'); 
				en_sym <= '0';
				sym_i  <= (others=>'0');
				sym_q  <= (others=>'0'); 
				cnt_in <= Q_ONE;
				cnt_next := (others=>'0'); 
				underflow <= '1';
			else
				-- linear interpolator
				if samp_vld = '1' then
					xI <= (Q_ONE - mu) * signed(samp_i_d) + mu * signed(samp_i_q);
					yI <= (Q_ONE - mu) * signed(samp_q_d) + mu * signed(samp_q_q);
					cnt_next := cnt - W;
					cnt_in <= cnt;
					if (cnt_next(cnt_next'high) = '1') then
						cnt_next := Q_ONE + cnt_next;
						underflow <= '1';
					else
						underflow <= '0';
					end if;
					cnt <= cnt_next;
					if xI(49 downto 40) = "0000000000" or xI(49 downto 40) = "1111111111" then
						xI_t(24 downto 16) <= std_logic_vector(xI(40 downto 32));
					elsif xI(49) = '0' then
						xI_t(24 downto 16) <= "011111111";
					elsif xI(49) = '1' then
						xI_t(24 downto 16) <= "100000001";
					end if;
					if yI(49 downto 40) = "0000000000" or yI(49 downto 40) = "1111111111" then
						yI_t(24 downto 16) <= std_logic_vector(yI(40 downto 32));
					elsif yI(49) = '0' then
						yI_t(24 downto 16) <= "011111111";
					elsif yI(49) = '1' then
						yI_t(24 downto 16) <= "100000001";
					end if;
					xI_t(15 downto 0) <= std_logic_vector(xI(31 downto 16));
					yI_t(15 downto 0) <= std_logic_vector(yI(31 downto 16));
					if underflow = '1' then
						en_sym <= '1';
						sym_i  <= xI_t;
						sym_q  <= yI_t;
					else
						en_sym <= '0';
					end if;
				end if;
			end if;
		end if;
	end process; 

	u_interp_ctrl: interp_ctrl
	port map(
			sys_clk		=> sys_clk,
			aresetn 	=> aresetn,
			samp_vld	=> samp_vld,
			xI_t		=> xI_t,
			yI_t		=> yI_t,
			underflow   => underflow,
			update_rdy 	=> update_rdy,
			cnt	 		=> std_logic_vector(cnt_in),
			mu_next		=> mu_next,
			W_next		=> W_next
		);

	process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if update_rdy = '1' then
				mu <= mu_next;
				W  <= W_next;
			end if;
		end if;
	end process; 
	

END ARCH;
