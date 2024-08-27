library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

use work.pRegisterBus.all;
use work.pReg_mikey.all;
use work.pBus_savestates.all;
use work.pReg_savestates.all; 

entity serial is
   port 
   (
      clk            : in  std_logic;
      ce             : in  std_logic;
      reset          : in  std_logic;
                     
      RegBus_Din     : in  std_logic_vector(BUS_buswidth-1 downto 0);
      RegBus_Adr     : in  std_logic_vector(BUS_busadr-1 downto 0);
      RegBus_wren    : in  std_logic;
      RegBus_rst     : in  std_logic;
      RegBus_Dout    : out std_logic_vector(BUS_buswidth-1 downto 0);   
      
      serdat_read    : in  std_logic;
      serialNewTx    : in  std_logic;
      
      irq_serial     : out std_logic := '0';
         
      -- savestates        
      SSBUS_Din      : in  std_logic_vector(SSBUS_buswidth-1 downto 0);
      SSBUS_Adr      : in  std_logic_vector(SSBUS_busadr-1 downto 0);
      SSBUS_wren     : in  std_logic;
      SSBUS_rst      : in  std_logic;
      SSBUS_Dout     : out std_logic_vector(SSBUS_buswidth-1 downto 0)
   );
end entity;

architecture arch of serial is

   -- register
   signal Reg_SERCTL : std_logic_vector(SERCTL.upper downto SERCTL.lower) := (others => '0');
   signal Reg_SERDAT : std_logic_vector(SERDAT.upper downto SERDAT.lower) := (others => '0');

   type t_reg_wired_or is array(0 to 1) of std_logic_vector(7 downto 0);
   signal reg_wired_or : t_reg_wired_or;   
   
   signal Reg_SERCTL_BACK    : std_logic_vector(7 downto 0);
   
   signal Reg_SERCTL_written : std_logic;
   signal Reg_SERDAT_written : std_logic;
   
   -- register details
   signal TXINTEN  : std_logic;  -- B7 = TXINTEN transmitter interrupt enable
	signal RXINTEN  : std_logic;  -- B6 = RXINTEN receive interrupt enable
                                 -- B5 = 0 (for future compatibility)
	--signal PAREN    : std_logic;  -- B4 = PAREN xmit parity enable(if 0, PAREVEN is the bit sent)
	--signal RESETERR : std_logic;  -- B3 = RESETERR reset all errors
	--signal TXOPEN   : std_logic;  -- B2 = TXOPEN 1 open collector driver, 0 = TTL driver
	signal TXBRK    : std_logic;  -- B1 = TXBRK send a break (for as long as the bit is set)
	--signal PAREVEN  : std_logic;  -- B0 = PAREVEN

   -- internal and readback
	signal TXRDY    : std_logic;  -- B7 = TXRDY transmitter buffer empty
	signal RXRDY    : std_logic;  -- B6 = RXRDY receive character ready
	signal TXEMPTY  : std_logic;  -- B5 = TXEMPTY transmitter totaiy done
	signal PARERR   : std_logic;  -- B4 = PARERR received parity error
	signal OVERRUN  : std_logic;  -- B3 = 0VERRUN received overrun error
	signal FRAMERR  : std_logic;  -- B2 = FRAMERR received framing error
	signal RXBRK    : std_logic;  -- B1 = RXBRK break recieved(24 bit periods)
	signal PARBIT   : std_logic;  -- B0 = PARBIT 9th bit
   
   -- internal
   signal uartTXCount : signed(7 downto 0) := (others => '0');
   signal uartRXCount : signed(7 downto 0) := (others => '0'); 
   signal uartRXBytes : signed(7 downto 0) := (others => '0');
   
   -- savestates
   signal SS_SERIAL          : std_logic_vector(REG_SAVESTATE_SERIAL.upper downto REG_SAVESTATE_SERIAL.lower);
   signal SS_SERIAL_BACK     : std_logic_vector(REG_SAVESTATE_SERIAL.upper downto REG_SAVESTATE_SERIAL.lower);

begin 

   iSS_SERIAL : entity work.eReg_SS generic map ( REG_SAVESTATE_SERIAL ) port map (clk, SSBUS_Din, SSBUS_Adr, SSBUS_wren, SSBUS_rst, SSBUS_Dout, SS_SERIAL_BACK, SS_SERIAL); 


   iReg_SERCTL  : entity work.eReg generic map ( SERCTL ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(0), Reg_SERCTL_BACK , Reg_SERCTL, Reg_SERCTL_written );  
   iReg_SERDAT  : entity work.eReg generic map ( SERDAT ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(1), Reg_SERDAT      , Reg_SERDAT, Reg_SERDAT_written );  
  
   process (reg_wired_or)
      variable wired_or : std_logic_vector(7 downto 0);
   begin
      wired_or := reg_wired_or(0);
      for i in 1 to (reg_wired_or'length - 1) loop
         wired_or := wired_or or reg_wired_or(i);
      end loop;
      RegBus_Dout <= wired_or;
   end process;
   
   TXINTEN  <= Reg_SERCTL(7);
   RXINTEN  <= Reg_SERCTL(6);      
   --PAREN    <= Reg_SERCTL(4); -- unused
   --RESETERR <= Reg_SERCTL(3); -- unused
   --TXOPEN   <= Reg_SERCTL(2); -- unused
   TXBRK    <= Reg_SERCTL(1);
   --PAREVEN  <= Reg_SERCTL(0); -- unused
   
   
   irq_serial <= '1' when ((uartTXCount < 0 and TXINTEN = '1') or (RXRDY = '1' and RXINTEN = '1')) else '0';
   
   Reg_SERCTL_BACK(7) <= TXRDY;  
   Reg_SERCTL_BACK(6) <= RXRDY;  
   Reg_SERCTL_BACK(5) <= TXEMPTY;
   Reg_SERCTL_BACK(4) <= PARERR; 
   Reg_SERCTL_BACK(3) <= OVERRUN;
   Reg_SERCTL_BACK(2) <= FRAMERR;
   Reg_SERCTL_BACK(1) <= RXBRK;  
   Reg_SERCTL_BACK(0) <= PARBIT; 
   
   SS_SERIAL_BACK( 7 downto  0) <= std_logic_vector(uartTXCount);
   SS_SERIAL_BACK(15 downto  8) <= std_logic_vector(uartRXCount);
   SS_SERIAL_BACK(23 downto 16) <= std_logic_vector(uartRXBytes);
   
   SS_SERIAL_BACK(24) <= TXRDY;
   SS_SERIAL_BACK(25) <= RXRDY;
   SS_SERIAL_BACK(26) <= TXEMPTY;
   SS_SERIAL_BACK(27) <= PARERR;
   SS_SERIAL_BACK(28) <= OVERRUN;
   SS_SERIAL_BACK(29) <= FRAMERR;
   SS_SERIAL_BACK(30) <= RXBRK;
   SS_SERIAL_BACK(31) <= PARBIT;

   process (clk)
      variable loopback   : std_logic;
      variable newRXBytes : signed(7 downto 0);
   begin
      if rising_edge(clk) then

         if (reset = '1') then
         
            uartTXCount <= signed(SS_SERIAL( 7 downto  0)); -- to_signed(-1, 8);
            uartRXCount <= signed(SS_SERIAL(15 downto  8)); -- to_signed(-1, 8);
            uartRXBytes <= signed(SS_SERIAL(23 downto 16)); -- to_signed( 0, 8);
            
            TXRDY       <= SS_SERIAL(24); -- '1';
            RXRDY       <= SS_SERIAL(25); -- '0';
            TXEMPTY     <= SS_SERIAL(26); -- '1';
            PARERR      <= SS_SERIAL(27); -- '0';
            OVERRUN     <= SS_SERIAL(28); -- '0';
            FRAMERR     <= SS_SERIAL(29); -- '0';
            RXBRK       <= SS_SERIAL(30); -- '0';
            PARBIT      <= SS_SERIAL(31); -- '0';

         elsif (ce = '1') then
         
            loopback   := '0';
            newRXBytes := uartRXBytes;
         
            -- newTX
            if (serialNewTx = '1') then
               if (uartTXCount = 0) then
                  if (TXBRK = '1') then
                     uartTXCount <= to_signed(11, 8);
                     
                     --loopback
                     if (uartRXBytes < 32) then
                        if (uartRXBytes = 0) then 
                           uartRXCount <= to_signed(11, 8);
                        end if;
                        newRXBytes := newRXBytes + 1;
                     end if;
                  else
                     uartTXCount <= to_signed(-1, 8);
                  end if;
               elsif (uartTXCount > 0) then
                  uartTXCount <= uartTXCount - 1;
               end if;
            
               if (uartRXCount = 0) then
                  if (newRXBytes > 0) then
                     newRXBytes := newRXBytes - 1;
                     if (newRXBytes > 0) then
                        uartRXCount <= to_signed(55, 8);
                     else
                        uartRXCount <= to_signed(-1, 8);
                     end if;
            
                     if (RXRDY = '1') then 
                        OVERRUN <= '1';
                     end if;
                     RXRDY <= '1';
                  end if;
               elsif (uartRXCount > 0) then
                  uartRXCount <= uartRXCount - 1;
               end if;
            end if;
            uartRXBytes <= newRXBytes;
            
            -- writeCTL
            if (Reg_SERCTL_written = '1') then
               
               if (Reg_SERCTL(1) = '1') then
                  uartTXCount <= to_signed(11, 8);
                  loopback    := '1';
               end if;
               
               if (Reg_SERCTL(3) = '1') then
                  FRAMERR <= '0';
                  OVERRUN <= '0';
               end if;
               
            end if;
            
            if (Reg_SERDAT_written = '1') then
               uartTXCount <= to_signed(11, 8);
               loopback    := '1';
            end if;
            
            -- read
            if (serdat_read = '1') then
               RXRDY <= '0';
            end if;

            --loopback
            if (loopback = '1') then
               if (uartRXBytes < 32) then
                  if (uartRXBytes = 0) then 
                     uartRXCount <= to_signed(11, 8);
                  end if;
                  uartRXBytes <= uartRXBytes + 1;
               end if;
            end if;

         end if;
         
      end if;
   end process;
  

end architecture;





