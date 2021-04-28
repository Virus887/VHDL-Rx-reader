library ieee;
use     ieee.std_logic_1164.all;
use     ieee.std_logic_unsigned.all;
use     ieee.std_logic_misc.all;

entity SERIAL_RX is
  generic (
    F_ZEGARA		:natural := 20_000_000;			-- czestotliwosc zegata w [Hz]
    L_BODOW		:natural := 9600;			-- predkosc nadawania w [bodach]
    B_SLOWA		:natural := 8;				-- liczba bitow slowa danych (5-8)
    B_PARZYSTOSCI	:natural := 1;				-- liczba bitow parzystosci (0-1)
    B_STOPOW		:natural := 2;				-- liczba bitow stopu (1-2)
    N_RX		:boolean := FALSE;			-- negacja logiczna sygnalu szeregowego
    N_SLOWO		:boolean := FALSE			-- negacja logiczna slowa danych
  );
  port (
    R		:in  std_logic;					-- sygnal resetowania
    C		:in  std_logic;					-- zegar taktujacy
    RX		:in  std_logic;					-- odebrany sygnal szeregowy
    SLOWO	:out std_logic_vector(B_SLOWA-1 downto 0);	-- odebrane slowo danych
    GOTOWE	:out std_logic;					-- flaga potwierdzenia odbioru
    BLAD	:out std_logic					-- flaga wykrycia bledu w odbiorze
  );
end SERIAL_RX;

architecture behavioural of SERIAL_RX is

  signal   input	:std_logic_vector(0 to 1);		-- podwojny rejestr sygnalu RX
  signal   R1,R2    :std_logic_vector(0 to 1);
  type     ETAP		is (CZEKANIE, START, DANA, PARZYSTOSC, STOP); -- lista etapow pracy odbiornika
  signal   state		:ETAP;					-- rejestr maszyny stanow odbiornika

  constant T		:positive := F_ZEGARA/L_BODOW-1;	-- czas jednego bodu - liczba taktów zegara
  signal   time_counter  	:natural range 0 to T;			-- licznik czasu jednego bodu
  signal   buf_counter  	:natural range 0 to B_SLOWA-1;		-- licznik odebranych bitow danych lub stopu
  
  signal   buf	    :std_logic_vector(SLOWO'range);		-- rejestr kolejno odebranych bitow danych
  signal   error	:std_logic;				-- rejestr (flaga) wykrytego bledu odbioru

begin

   process (R, C) is						-- proces odbiornika
   begin							-- cialo procesu odbiornika

   R1 <= input;
   R2 <= R1;
   
   if (R = '1') then 
    input <= (others => '0');
    R1 <= (others => '0');
    R2 <= (others => '0');
    state <= CZEKANIE;
    time_counter <= 0;
    buf_counter <= 0;
    buf <= (others => '0');
    error <= '0';
    
    
   elsif rising_edge(C) then 
   
    case state is
        when CZEKANIE =>					
           time_counter <= 0;					
           buf_counter <= 0;					
           buf   <= (others => '0');				
           error <= '0';					
           if (input(1)='0' and input(0)='1') then	
             state   <= START;					
           end if;					
        when START =>
            if (time_counter /= T/2) then
                time_counter <= time_counter +1;
            else
                time_counter <= 0;
                state <= DANA;
                if(input(1) = '0') then
                    error <= '1';
                end if;
            end  if;
    
        when DANA =>
            if(time_counter /= T) then
                time_counter <= time_counter + 1;
            else
                buf(buf'left) <= input(1);
                buf(buf'left -1 downto 0) <= buf(buf'left downto 0);
                time_counter <= 0;
                
                if(buf_counter /= B_SLOWA-1) then
                    buf_counter <= buf_counter + 1;
                else
                    buf_counter <= 0;
                    if(B_PARZYSTOSCI = 1) then
                        state <= PARZYSTOSC;
                    else
                        state <= STOP;
                    end if;
                end if;
            end if;
    
        when PARZYSTOSC =>
           if (time_counter /= T) then				
             time_counter <= time_counter + 1;		
           else							
                 time_counter <= 0;					
             state <= STOP;				
             if ((input(1) = XOR_REDUCE(buf)) = N_SLOWO) then
                   error <= '1';					
             end if; 					
           end if;			
	   
        when STOP =>						
            if (time_counter /= T) then				
             time_counter <= time_counter + 1;			
            else							
                 time_counter <= 0;					
            
             if (buf_counter /= B_STOPOW-1) then			
               buf_counter <= buf_counter + 1;				
               if (input(1) /= '0') then		
                     error <= '1';			
               end if; 					
             else					
               if (error = '0' and input(1) = '0') then	
                     SLOWO <= buf;				
                     if (N_SLOWO = TRUE) then			
                       SLOWO <= not(buf);				
                     end if;				
                     GOTOWE <= '1';					
               else					
                     SLOWO <= (others => '0');		
                     BLAD <= '1';			
               end if;					
               state <= CZEKANIE;			
             end if;					
            end if;				
    end case;
   end if;

   end process;						
   
end behavioural;