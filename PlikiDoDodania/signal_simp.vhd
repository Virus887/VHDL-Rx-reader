library ieee;
use     ieee.std_logic_1164.all;
entity SERIAL_RX is
  generic (
    F_ZEGARA		:natural := 20_000_000;	    -- czestotliwosc zegata w [Hz]
    L_BODOW		    :natural := 5_000_000;			-- predkosc nadawania w [bodach]
    B_SLOWA		    :natural := 8;				-- liczba bitow slowa danych (5-8)
    B_PARZYSTOSCI	:natural := 1;				-- liczba bitow parzystosci (0-1)
    B_STOPOW		:natural := 2;				-- liczba bitow stopu (1-2)
    N_RX		    :boolean := FALSE;			-- negacja logiczna sygnalu szeregowego
    N_SLOWO		    :boolean := FALSE			-- negacja logiczna slowa danych
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
  
  shared variable flag_wait        :std_logic := '1';
  shared variable flag_start       :std_logic := '0';
  shared variable flag_data        :std_logic := '0';
  shared variable flag_even        :std_logic := '0';
  shared variable flag_stop        :std_logic := '0';
  

  constant T                        :positive := F_ZEGARA/L_BODOW;	    -- czas jednego bodu - liczba taktów zegara
  shared variable   time_counter  	        :natural range 0 to T;			    -- licznik czasu jednego bodu
  shared variable   buf_counter  	        :natural range 0 to B_SLOWA-1;		-- licznik odebranych bitow danych lub stopu
  shared variable   even_counter  	        :natural range 0 to B_SLOWA-1;		-- licznik odebranych 'jedynek' w serii danych
  shared variable   stop_counter  	        :natural range 0 to B_STOPOW-1;		-- licznik odczekanych stopów w stanie 'STOP'
  
 
  signal   buf	    :std_logic_vector(SLOWO'range);		                -- rejestr kolejno odebranych bitow danych
  signal   error	:std_logic  := '0';				                    -- rejestr (flaga) wykrytego bledu odbioru


begin

   process (R, C) is					
   begin							

--------------RESET--------------------
   
   if (R = '1') then            
        R1 <=  '0';
        R2 <= '0';
        flag_wait := '1';
        flag_start := '0';
        flag_data := '0';
        flag_even := '0';
        flag_stop := '0';
        time_counter := 0;
        buf_counter := 0;
        even_counter := 0;
        stop_counter := 0;
        SLOWO <= (others => 'U');
        GOTOWE <= '0';
        BLAD <= '0';
        buf <= (others => '0');
        error <= '0';
    
-------------------WYKRYCIE ZBOCZA ZEGARA-----------------------------
    
   elsif rising_edge(C) then  
   
       if (N_RX) then          ---------------------------------------
          R1 <= not(RX);       -- Wykrywanie narastaj¹cego zbocza 
       else                    -- na RX poprzez R1 i R2.
          R1 <= RX;            --
       end if;                 --
       R2 <= R1;               ---------------------------------------
                                              
 -----------------------CZEKANIE--------------------------------------
       if (flag_wait = '1') then	       --
           if (R1 = '1' and R2 = '0') then -- narastaj¹ce zbocze na RX
                flag_wait := '0';          ---------------------------
                flag_start := '1';         -- przechodzimy w stan start
                flag_data := '0';
                flag_even := '0';
                flag_stop := '0';
                time_counter := 0;					
                buf_counter := 0;		
                GOTOWE <= '0';
                SLOWO <= (others => 'U');
                BLAD <= '0';			
                buf <= (others => '0');												
           end if;	
  
-------------------------START----------------------------------------       				
       elsif (flag_start = '1') then
            if (time_counter /= T/2) then
                time_counter := time_counter +1;
            else
                time_counter := 0;
                flag_wait := '0';
                flag_start := '0';
                flag_data := '1';
                flag_even := '0';
                flag_stop := '0';
                if (N_RX) then             ------------------------
                   if(not(RX) = '0') then  -- Jeœli na starcie
                      error <= '1';        -- (RX = '0') to b³¹d.
                   end if;                 --
                else                       --
                   if(RX = '0') then       --
                      error <= '1';        --
                   end if;                 --
                end if;                    -------------------------
            end  if;
    
--------------------------DANA--------------------------------------    
       elsif (flag_data = '1') then
            if(time_counter /= T) then
                time_counter := time_counter + 1;
            else
                if(N_RX) then                       -----------------
                    buf(buf_counter) <= not(RX);    -- Odczyt danej
                else                                --
                    buf(buf_counter) <= RX;         --
                end if;                             -----------------
                time_counter := 0;          
                if(buf_counter /= B_SLOWA-1) then
                    buf_counter := buf_counter + 1;         ---------    
                    if(N_RX) then                           -- Zliczanie
                       if (not(RX) = '1') then              -- jedynek
                          even_counter := even_counter + 1; -- w 
                       end if;                              -- s³owie
                    else                                    --
                       if (RX = '1') then                   --
                          even_counter := even_counter + 1; --
                       end if;                              --------
                    end if;
                else
                    buf_counter := 0;
                    flag_wait := '0';
                    flag_start := '0';
                    flag_data := '0';
                    flag_even := '1';
                    flag_stop := '0';
                 end if;
              end if;
  
-----------------------PARZYSTOŒÆ-----------------------------------
        elsif (flag_even = '1') then
           if (time_counter /= T) then				
                time_counter := time_counter + 1;		
           else							
                time_counter := 0;
                if (B_PARZYSTOSCI = 1) then          --------------
                    if (even_counter mod 2 /= 0) then-- Sprawdzenie
                       error <= '1';				 -- parzystoœci	
                    end if;                          --
                else                                 --
                    if (even_counter mod 2 = 0) then --
                       error <= '1';		         --			
                    end if; 	                     --------------
                end if;				
                flag_wait := '0';
                flag_start := '0';
                flag_data := '0';
                flag_even := '0';
                flag_stop := '1';
           end if;			
	
-------------------------STOP---------------------------------------
        elsif (flag_stop = '1') then					
            if (time_counter /= T) then				
                 time_counter := time_counter + 1;			
            else							
                 time_counter := 0;	
                 stop_counter := stop_counter + 1;				      
                 if (stop_counter /= B_STOPOW-1) then	
                    stop_counter := stop_counter+1;
                    if (N_RX) then
                        if (not(RX) /= '0') then		
                           error <= '1';			
                        end if;
                    else 
                        if (RX /= '0') then		
                           error <= '1';			
                        end if;
                    end if;											
                 else                                          --------------
                    if(N_RX) then                              -- 
                       if (error = '0' and not(RX) = '0') then --                                       
                          if (N_SLOWO = TRUE) then			   --
                            SLOWO <= not(buf);                 --
                          else                                 --     
                            SLOWO <= buf;			           --
                          end if;			                   --	
                          GOTOWE <= '1';	                   --				
                       else					                   -- 
                         SLOWO <= (others => '0');		       --
                         BLAD <= '1';			               --
                       end if;	                               -- Zwrócenie
                    else                                       -- danych
                       if (error = '0' and RX = '0') then	   --                                       
                          if (N_SLOWO = TRUE) then		       --	
                            SLOWO <= not(buf);                 --
                          else                                 --
                            SLOWO <= buf;		               --	
                          end if;			                   --	
                          GOTOWE <= '1';	                   --				
                       else					                   --
                         SLOWO <= (others => '0');		       --
                         BLAD <= '1';			               --
                       end if;	                               --------------
                    end if;								
                 flag_wait := '1';
                 flag_start := '0';
                 flag_data := '0';
                 flag_even := '0';
                 flag_stop := '0';			
                 end if;					
          end if;				
       end if;				
     end if;

   end process;						
   
end behavioural;