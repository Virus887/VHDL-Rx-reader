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
	
  signal   R1,R2    :std_logic;				
  
  shared variable flag_czekanie    :std_logic := '1';
  shared variable flag_start       :std_logic := '0';
  shared variable flag_dana        :std_logic := '0';
  shared variable flag_parzystosc  :std_logic := '0';
  shared variable flag_stop        :std_logic := '0';
  

  constant T                        :positive := F_ZEGARA/L_BODOW;	    -- czas jednego bodu - liczba taktów zegara
  signal   time_counter  	        :natural range 0 to T;			    -- licznik czasu jednego bodu
  signal   buf_counter  	        :natural range 0 to B_SLOWA-1;		-- licznik odebranych bitow danych lub stopu
  signal   even_counter  	        :natural range 0 to B_SLOWA-1;		-- licznik odebranych bitow danych lub stopu
  signal   stop_counter  	        :natural range 0 to B_STOPOW-1;		-- licznik odebranych bitow danych lub stopu
  
  
  
  signal   buf	    :std_logic_vector(SLOWO'range);		-- rejestr kolejno odebranych bitow danych
  signal   error	:std_logic;				            -- rejestr (flaga) wykrytego bledu odbioru


begin

   process (R, C) is						-- proces odbiornika
   begin							-- cialo procesu odbiornika


   
   if (R = '1') then 
        R1 <=  '0';
        R2 <= '0';
        flag_czekanie := '1';
        flag_start := '0';
        flag_dana := '0';
        flag_parzystosc := '0';
        flag_stop := '0';
        time_counter <= 0;
        buf_counter <= 0;
        even_counter <= 0;
        stop_counter <= 0;
        buf <= (others => '0');
        error <= '0';
    
   elsif rising_edge(C) then  
      R1 <= RX;
      R2 <= R1;       
       if (flag_czekanie = '1') then	--sytuacja czekanie
           if (R1 = '1' and R2 = '0') then -- narastaj¹ce zbocze
                flag_czekanie := '0';
                flag_start := '1';
                flag_dana := '0';
                flag_parzystosc := '0';
                flag_stop := '0';
                time_counter <= 0;					
                buf_counter <= 0;					
                buf <= (others => '0');												
           end if;	
           				
       elsif (flag_start = '1') then
            if (time_counter /= T/2) then
                time_counter <= time_counter +1;
            else
                time_counter <= 0;
                flag_czekanie := '0';
                flag_start := '0';
                flag_dana := '1';
                flag_parzystosc := '0';
                flag_stop := '0';
                if(RX = '0') then
                    error <= '1';
                end if;
            end  if;
    
       elsif (flag_dana = '1') then
            if(time_counter /= T) then
                time_counter <= time_counter + 1;
            else
                buf(buf_counter) <= RX;
                time_counter <= 0;             
                if(buf_counter /= B_SLOWA-1) then
                    buf_counter <= buf_counter + 1;
                    if (RX = '1') then 
                        even_counter <= even_counter +1;
                    end if;
                else
                    buf_counter <= 0;
                    if(B_PARZYSTOSCI = 1) then
                        flag_czekanie := '0';
                        flag_start := '0';
                        flag_dana := '0';
                        flag_parzystosc := '1';
                        flag_stop := '0';
                    else
                        flag_czekanie := '0';
                        flag_start := '0';
                        flag_dana := '0';
                        flag_parzystosc := '0';
                        flag_stop := '1';
                    end if;
                 end if;
              end if;
    
        elsif (flag_parzystosc = '1') then
           if (time_counter /= T) then				
                time_counter <= time_counter + 1;		
           else							
                time_counter <= 0;					
                flag_czekanie := '0';
                flag_start := '0';
                flag_dana := '0';
                flag_parzystosc := '0';
                flag_stop := '1';				
                if (even_counter mod 2 /= 0) then
                   error <= '1';					
                end if; 					
           end if;			
	   
        elsif (flag_stop = '1') then					
            if (time_counter /= T) then				
                 time_counter <= time_counter + 1;			
            else							
                 time_counter <= 0;	
                 stop_counter <= stop_counter + 1;				      
                 if (stop_counter /= B_STOPOW-1) then	
                    stop_counter <= stop_counter+1;						
                    if (RX /= '0') then		
                       error <= '1';			
                    end if; 					
                 else					
                   if (error = '0' and RX = '0') then	
                         				
                         if (N_SLOWO = TRUE) then			
                           SLOWO <= not(buf);
                         else 
                           SLOWO <= buf;			
                         end if;				
                         GOTOWE <= '1';					
                   else					
                     SLOWO <= (others => '0');		
                     BLAD <= '1';			
               end if;					
                flag_czekanie := '1';
                flag_start := '0';
                flag_dana := '0';
                flag_parzystosc := '0';
                flag_stop := '0';			
             end if;					
          end if;				
       end if;				
   end if;

   end process;						
   
end behavioural;