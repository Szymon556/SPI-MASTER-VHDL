
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;



entity master is
    Generic(
        B_SIZE : integer := 8;
        PRSC : integer := 100;
        DELAY_T : integer := 60;
        BUFF_SIZE : integer := 3
    );
    Port ( 
            clk : in std_logic;
            reset : in std_logic;
            -- Wejścia i wyjścia odpowiedzialne za komunikację z pozostałymi 
            -- modułami
            data_in : in std_logic_vector(B_SIZE - 1 downto 0);
            mode : in std_logic_vector(1 downto 0);
            start : in std_logic;
            data_out : out std_logic_vector(B_SIZE - 1 downto 0);
            data_valid : out std_logic;
            -- Komunikacja SPI
            MISO : in std_logic;
            SCLK :  out std_logic;
            MOSI :out std_logic;
            SS : out std_logic;
            test : out std_logic
    );
end master;

architecture Behavioral of master is
    
    type state_type is (IDLE,SET_SS,TRANSFER,SAVE);
    signal state_reg, state_next : state_type;
    
    signal SCLK_reg, SCLK_next : std_logic;
    signal SS_reg : std_logic;
    signal counter_reg: std_logic_vector(B_SIZE - 1 downto 0);
    signal delay_reg , delay_next : std_logic_vector(B_SIZE - 1 downto 0);
    
    signal MISO_transaction : std_logic;
    signal MOSI_transaction : std_logic;
    signal MOSI_done, MISO_done : std_logic;
    signal received_reg, received_next : std_logic_vector(B_SIZE - 1 downto 0);
    signal transfer_reg, transfer_next : std_logic_vector(B_SIZE - 1 downto 0);
    
    signal bit_counter_MISO, bit_counter_MISO_next : std_logic_vector(BUFF_SIZE - 1 downto 0);
    signal bit_counter_MOSI, bit_counter_MOSI_next : std_logic_vector(BUFF_SIZE - 1 downto 0);
    
    signal MOSI_reg,MOSI_next : std_logic;
    signal SCLK_prev : std_logic;
    signal rising_reg : std_logic;
    signal falling_reg : std_logic;
    
begin

   
    PRESCALLER : process(clk,reset) 
    begin
    if reset = '1' then
        counter_reg <= (others => '0');
    elsif clk'event and clk = '1' then
        if unsigned(counter_reg) = TO_UNSIGNED(PRSC, counter_reg'length) then
            counter_reg <= (others => '0'); 
        else
            counter_reg <= std_logic_vector(unsigned(counter_reg) + 1);
        end if;
    end if;
    end process;
    
   -- Aktualizacja zegara SPI, przy przepełnieniu licznik prescalera  
    SCLK_next <= not SCLK_reg when unsigned(counter_reg) = TO_UNSIGNED(PRSC, counter_reg'length)  else SCLK_reg;
    
   --Detekcja zbocza SCLK  
    rising_reg <= '1' when SCLK_prev = '1' and SCLK_reg = '0' else '0';
    falling_reg <= '1' when SCLK_prev = '0' and SCLK_reg = '1' else '0';
    
    MODE_SELECT : process(reset,mode,rising_reg, falling_reg)
    begin
        if reset = '1' then
            MISO_transaction <= '0';
            MOSI_transaction <= '0';
        else
            MISO_transaction <= '0';
            MOSI_transaction <= '0';
            if mode = "00" then
                if rising_reg = '1' then
                    MOSI_transaction <= '1';
                    MISO_transaction <= '0';
                elsif falling_reg = '1' then
                    MISO_transaction <= '1';
                    MOSI_transaction <= '0';
                end if;
            end if;
        end if;   
    end process;
    
    REGISTERS : process(clk, reset)
    begin
        if(reset = '1') then
            state_reg <= IDLE;
            SCLK_reg <= '0';
            SCLK_prev <= '0';
            received_reg <= (others => '0');
            transfer_reg <= (others => '0');
            bit_counter_MISO  <= (others => '0');
            delay_reg <= (others => '0');
            MOSI_reg <= '0';
        elsif clk'event and clk = '1' then
            state_reg <= state_next;
            transfer_reg <= transfer_next;
            received_reg <= received_next;
            bit_counter_MISO <= bit_counter_MISO_next;
            bit_counter_MOSI <= bit_counter_MOSI_next;
            MOSI_reg <= MOSI_next;
            delay_reg <= delay_next;
            SCLK_reg <= SCLK_next;
            SCLK_prev <= SCLK_reg;
        end if;
    end process;
    
    
    FSM : process(all)
    begin
        state_next <= state_reg;
        transfer_next <= transfer_reg;
        received_next <= received_reg;
        bit_counter_MISO_next <= bit_counter_MISO;
        delay_next <= delay_reg;
        MOSI_next <= MOSI_reg;
        SS_reg <= '1';
        data_valid <= '0';
        case state_reg is
            when IDLE =>
                if start = '1' then
                    delay_next <= (others => '0');
                    bit_counter_MISO_next <= (others => '0');
                    bit_counter_MOSI_next <= (others => '0');
                    transfer_next <= data_in;
                    state_next <= SET_SS;
                end if;
            when SET_SS =>
                SS_reg <= '0';
                -- dodanie opóżnienia, w celu poprawy stabilności komunikacji
                if signed(delay_reg) = DELAY_T then
                    -- specjalny przypadek gdzie trzba zaraz po ustawieniu SS, pobrać bit z MISO
                    if mode = "00" then
                        received_next <= MISO & received_reg(B_SIZE - 2 downto 0);
                        bit_counter_MISO_next <= std_logic_vector(unsigned(bit_counter_MISO) + 1);
                    end if;
                    state_next <= TRANSFER;
                else
                    delay_next <= std_logic_vector(unsigned(delay_reg) + 1);
                end if;
            when TRANSFER =>
                SS_reg <= '0';
                if MISO_transaction = '1'and MISO_done = '0' then
                    received_next <= MISO & received_reg(B_SIZE - 2 downto 0);
                    bit_counter_MISO_next <= std_logic_vector(unsigned(bit_counter_MISO) + 1);
                end if;
                if MOSI_transaction = '1'and  MOSI_done = '0'then
                    MOSI_next <= transfer_reg(B_SIZE - 1);
                    transfer_next <= transfer_reg(B_SIZE - 2 downto 0) & '0';
                    bit_counter_MOSI_next <= std_logic_vector(unsigned(bit_counter_MOSI) + 1);
                end if;
                if MISO_done = '1' and MOSI_done = '1' then
                    state_next <= SAVE;
                end if;
            when SAVE =>
                data_valid <= '1';
                state_next <= IDLE;
        end case;
    end process;
    
    -- Proces odpowiedzielany za sprawdzanie czy wysłaliśmy i odebraliśmy bajt danych
    CONTROL_TRANSFER : process(reset,bit_counter_MOSI,bit_counter_MISO)
    begin
        if reset = '1' then
            MOSI_done <= '0';
            MISO_done <= '0';
         else
            MOSI_done <= '0';
            MISO_done <= '0';
            if  bit_counter_MOSI = "111" then
                MOSI_done <= '1';
            end if;
            if bit_counter_MISO = "111" then
                MISO_done <= '1';   
            end if;        
        end if;
    end process;
    SS <= SS_reg;
    MOSI <= MOSI_reg;
    SCLK <= SCLK_reg;
    data_out <= received_reg;
    test <= rising_reg;
end Behavioral;
