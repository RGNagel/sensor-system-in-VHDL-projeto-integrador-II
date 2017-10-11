library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_textio.all;

entity pi_II is
	generic(word_len : integer := 8);   -- nº de letras da palavra
	port(
		KEY                                            : in    std_logic_vector(3 downto 0);
		CLOCK_50                                       : in    std_logic;
		-- EX_IO reference: DE2_115_User_manual.pdf (page 52/122)
		EX_IO                                          : inout std_logic_vector(6 downto 0);
		LEDR                                           : out   std_logic_vector(17 downto 0);
		HEX0, HEX1, HEX2, HEX3, HEX4, HEX5, HEX6, HEX7 : out   std_logic_vector(6 downto 0)
	);
end pi_II;

architecture interface of pi_II is
	component setDisplaysText
		generic(txt_len : integer := 8); -- nº de displays/letras
		port(
			txt                                            : in  string(1 to txt_len);
			HEX0, HEX1, HEX2, HEX3, HEX4, HEX5, HEX6, HEX7 : out std_logic_vector(6 downto 0)
		);
	end component;
	component freq_divider
		port(
			clk_in  : in  std_logic;
			reset   : in  std_logic;
			clk_out : out std_logic
		);
	end component;
	component sendTrigger
		port(
			clk_in : in  std_logic;
			start  : in  std_logic;
			pulse  : out std_logic
		);
	end component;
	component readEcho
		port(
			CLOCK_50 : in  std_logic;
			ECHO     : in  std_logic;   -- response from sensor
			--DIST     : out std_logic_vector(15 downto 0); -- measured distance
			dist_int : out integer;
			dist_dec : out integer
		);
	end component;
	component debouncer_pi
		port(clockIn   : in  std_logic;
		     buttonIn  : in  std_logic;
		     buttonOut : out std_logic
		    );
	end component;
	constant txt_len     : integer   := 8;
	signal start_trigger : std_logic := '1';
	signal reset         : std_logic := '0';
	signal clk_out       : std_logic;
	signal txt           : string(1 to txt_len);
	signal TRIG          : std_logic := '0';
	signal ECHO          : std_logic;   -- signal response from sensor
	--signal DIST          : std_logic_vector(15 downto 0); -- measured distance
	signal dist_int      : integer;
	signal dist_dec      : integer;
	type menu is (COR, ALTURA, ALTURA_X);
	signal opcao         : menu;
begin
	uut : freq_divider
		port map(
			clk_in  => CLOCK_50,
			reset   => reset,
			clk_out => clk_out
		);
	displays : setDisplaysText
		generic map(txt_len => txt_len)
		port map(
			txt  => txt,
			HEX0 => HEX0,
			HEX1 => HEX1,
			HEX2 => HEX2,
			HEX3 => HEX3,
			HEX4 => HEX4,
			HEX5 => HEX5,
			HEX6 => HEX6,
			HEX7 => HEX7
		);
	debouncer : debouncer_pi
		port map(
			clockIn   => CLOCK_50,
			buttonIn  => KEY(2),
			buttonOut => start_trigger  -- DOWN
		);
	st : sendTrigger
		port map(
			clk_in => CLOCK_50,
			start  => start_trigger,
			pulse  => EX_IO(3)
		);
	rTrigger : readEcho
		port map(
			CLOCK_50 => CLOCK_50,
			ECHO     => EX_IO(4),       -- here we receive signal pulse from sensor
			dist_int => dist_int,
			dist_dec => dist_dec
		);
	process(clk_out, KEY(0), KEY(1), KEY(2), dist_int)
		variable txt2               : string(1 to txt_len);
		variable word_pos           : integer := 0;
		variable first_cycle, blink : std_logic;
		variable x                  : integer := 0;
		variable dist_int_2	: integer := 0;
	begin
		if rising_edge(clk_out) then
			-- pisca pisca p/ debug do clock
			blink    := not (blink);
			LEDR(17) <= blink;

			if KEY(0) = '0' then
				txt         <= "--------";
				txt2        := "--------";
				first_cycle := '1';
				word_pos    := 0;
				opcao       <= COR;
			elsif KEY(1) = '0' then
				txt         <= "--------";
				txt2        := "--------";
				first_cycle := '1';
				word_pos    := 0;
				opcao       <= ALTURA;
			elsif dist_int > 0 then
				txt         <= "--------";
				txt2        := "--------";
				first_cycle := '1';
				word_pos    := 0;
				x           := 0;
				dist_int <= 0;
				dist_dec <= 0;
				opcao       <= ALTURA_X;
			end if;
			if first_cycle = '1' then
				case opcao is
					when COR =>
						case word_pos is
							when 0      => txt <= "-------C";
							when 1      => txt <= "------CO";
							when 2      => txt <= "-----COR";
							when 3      => first_cycle := '0';
							when others => txt <= "--------";
						end case;
					when ALTURA =>
						case word_pos is
							when 0      => txt <= "-------A";
							when 1      => txt <= "------AL";
							when 2      => txt <= "-----ALT";
							when 3      => txt <= "----ALTU";
							when 4      => txt <= "---ALTUR";
							when 5      => txt <= "--ALTURA";
							when 6      => first_cycle := '0';
							when others => txt <= "--------";
						end case;
					when ALTURA_X =>
						if x = 0 then
							txt2(txt_len)     := character'val(dist_dec);
							txt2(txt_len - 1) := ',';
							x                 := txt_len - 2;
							dist_int_2 := dist_int;
							while dist_int_2 > 0 and x > 0 loop
								txt2(x)  := character'val(dist_int_2 rem 10);
								dist_int_2 := dist_int_2/10;
								x        := x - 1;
							end loop;
							--txt_num           <= integer'image(dist_int) & "," & integer'image(dist_dec);
							first_cycle       := '1';
							txt <= txt2;
						end if;
				end case;
				word_pos := word_pos + 1;
			else
				for i in 1 to txt_len loop
					if i < txt_len then
						txt2(i) := txt(i + 1);
					else
						txt2(i) := txt(1);
					end if;
				end loop;
				txt <= txt2;
			end if;
		end if;                         -- end rising_edge
	end process;
end interface;
