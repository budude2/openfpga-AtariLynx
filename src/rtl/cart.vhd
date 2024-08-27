library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

use work.pRegisterBus.all;
use work.pReg_mikey.all;
use work.pReg_suzy.all;
use work.pBus_savestates.all;
use work.pReg_savestates.all; 

entity cart is  -- cart1 missing!
   port 
   (
      clk            : in  std_logic;
      ce             : in  std_logic;
      reset          : in  std_logic;
      
      hasHeader      : in  std_logic;
      bank0size      : in  std_logic_vector(15 downto 0);
      bank1size      : in  std_logic_vector(15 downto 0);
                     
      RegBus_Din     : in  std_logic_vector(BUS_buswidth-1 downto 0);
      RegBus_Adr     : in  std_logic_vector(BUS_busadr-1 downto 0);
      RegBus_wren    : in  std_logic;
      RegBus_rst     : in  std_logic;
      RegBus_Dout    : out std_logic_vector(BUS_buswidth-1 downto 0);   
      
      cart_strobe0   : in  std_logic;
      cart_strobe1   : in  std_logic;
      cart_wait      : out std_logic;
      cart_idle      : out std_logic;
      
      rom_addr       : out std_logic_vector(19 downto 0);
      rom_byte       : in  std_logic_vector( 7 downto 0);
      rom_req        : out std_logic;
      rom_ack        : in  std_logic;
         
      -- savestates        
      SSBUS_Din      : in  std_logic_vector(SSBUS_buswidth-1 downto 0);
      SSBUS_Adr      : in  std_logic_vector(SSBUS_busadr-1 downto 0);
      SSBUS_wren     : in  std_logic;
      SSBUS_rst      : in  std_logic;
      SSBUS_Dout     : out std_logic_vector(SSBUS_buswidth-1 downto 0)
   );
end entity;

architecture arch of cart is

   -- register
   signal Reg_SYSCTL1 : std_logic_vector(SYSCTL1.upper downto SYSCTL1.lower) := (others => '0');
   signal Reg_IODIR   : std_logic_vector(IODIR  .upper downto IODIR  .lower) := (others => '0');
   signal Reg_IODAT   : std_logic_vector(IODAT  .upper downto IODAT  .lower) := (others => '0');

   type t_reg_wired_or is array(0 to 4) of std_logic_vector(7 downto 0);
   signal reg_wired_or : t_reg_wired_or;   
   
   signal RCART0_readback : std_logic_vector(7 downto 0);
   signal RCART1_readback : std_logic_vector(7 downto 0);
   signal IODAT_readback  : std_logic_vector(7 downto 0);
   
   signal Reg_SYSCTL1_written : std_logic;
   
   signal cartStrobeEna    : std_logic;
   
   -- internal
   signal MaskBank0        : std_logic_vector(18 downto 0);
   signal ShiftCount0      : integer range 0 to 11;
   signal CountMask0       : std_logic_vector(10 downto 0);
         
   signal cartCnt          : unsigned(10 downto 0);
   signal cartShift        : unsigned(7 downto 0);
   signal cartStrobeLast   : std_logic;
   
   signal cart_addr        : std_logic_vector(18 downto 0);
   signal cart_addr_1      : std_logic_vector(18 downto 0);
   signal cart_data        : std_logic_vector(7 downto 0);
   
   signal readqueue        : std_logic;
   signal readwait         : std_logic;
   
   -- savestates
   signal SS_CART          : std_logic_vector(REG_SAVESTATE_CART.upper downto REG_SAVESTATE_CART.lower);
   signal SS_CART_BACK     : std_logic_vector(REG_SAVESTATE_CART.upper downto REG_SAVESTATE_CART.lower);

   -- debug
   signal testcnt          : unsigned(31 downto 0);
   signal testsum          : unsigned(31 downto 0);

   
begin 

   iSS_CART : entity work.eReg_SS generic map ( REG_SAVESTATE_CART ) port map (clk, SSBUS_Din, SSBUS_Adr, SSBUS_wren, SSBUS_rst, SSBUS_Dout, SS_CART_BACK, SS_CART); 


   iReg_SYSCTL1 : entity work.eReg generic map ( SYSCTL1 ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(0), Reg_SYSCTL1, Reg_SYSCTL1, Reg_SYSCTL1_written);  
   iReg_IODIR   : entity work.eReg generic map ( IODIR   ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(1), Reg_IODIR  , Reg_IODIR);  
   iReg_IODAT   : entity work.eReg generic map ( IODAT   ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(2), IODAT_readback  , Reg_IODAT);  
   iReg_RCART0  : entity work.eReg generic map ( RCART0  ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(3), RCART0_readback);  
   iReg_RCART1  : entity work.eReg generic map ( RCART1  ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(4), RCART1_readback);  
  
   process (reg_wired_or)
      variable wired_or : std_logic_vector(7 downto 0);
   begin
      wired_or := reg_wired_or(0);
      for i in 1 to (reg_wired_or'length - 1) loop
         wired_or := wired_or or reg_wired_or(i);
      end loop;
      RegBus_Dout <= wired_or;
   end process;
   
   IODAT_readback(7 downto 5) <= "000";
   IODAT_readback(0) <= Reg_IODAT(0) when (Reg_IODIR(0) = '1') else '1';
   IODAT_readback(1) <= Reg_IODAT(1) when (Reg_IODIR(1) = '1') else '1';
   IODAT_readback(2) <= Reg_IODAT(2) when (Reg_IODIR(2) = '1') else '0'; -- UART special case
   IODAT_readback(3) <= Reg_IODAT(3) when (Reg_IODIR(3) = '1') else '1';
   IODAT_readback(4) <= Reg_IODAT(4) when (Reg_IODIR(4) = '1') else '1';
   
   RCART0_readback <= cart_data;
   RCART1_readback <= (others => '0'); -- todo!
   
   cartStrobeEna <= Reg_SYSCTL1(0);
   
   cart_idle <= '1' when (readwait = '0' and readqueue = '0') else '0';
   
   
   MaskBank0   <= std_logic_vector(to_unsigned( 16#FFFF#, 19)) when bank0size = x"0100" else
                  std_logic_vector(to_unsigned(16#1FFFF#, 19)) when bank0size = x"0200" else
                  std_logic_vector(to_unsigned(16#3FFFF#, 19)) when bank0size = x"0400" else
                  std_logic_vector(to_unsigned(16#7FFFF#, 19)) when bank0size = x"0800" else
                  (others => '0');
                  
   ShiftCount0 <=  8 when bank0size = x"0100" else
                   9 when bank0size = x"0200" else
                  10 when bank0size = x"0400" else
                  11 when bank0size = x"0800" else
                  0;
                  
   CountMask0  <= std_logic_vector(to_unsigned( 16#FF#, 11)) when bank0size = x"0100" else
                  std_logic_vector(to_unsigned(16#1FF#, 11)) when bank0size = x"0200" else
                  std_logic_vector(to_unsigned(16#3FF#, 11)) when bank0size = x"0400" else
                  std_logic_vector(to_unsigned(16#7FF#, 11)) when bank0size = x"0800" else
                  (others => '0');
   
   SS_CART_BACK( 7 downto 0) <= std_logic_vector(cartShift);
   SS_CART_BACK(18 downto 8) <= std_logic_vector(cartCnt);
   SS_CART_BACK(         19) <= cartStrobeLast;
   
   
   process (clk)
   begin
      if rising_edge(clk) then
      
         rom_req <= '0';
         if (rom_ack = '1') then
            cart_data <= rom_byte;
            readwait  <= '0';
            testsum   <= testsum + unsigned(rom_byte) + 1;
         end if;
         
         --if (testcnt = x"FFFFFFFF" or testsum = x"FFFFFFFF") then
         --   readwait <= '0';
         --end if;
         
         if (reset = '1') then
         
            cartShift      <= unsigned(SS_CART( 7 downto 0)); --(others => '0');  
            cartCnt        <= unsigned(SS_CART(18 downto 8)); --(others => '0');     
            cartStrobeLast <= SS_CART(         19); --'0';
            readqueue      <= '0';  
            readwait       <= '0'; 
            
            testcnt        <= (others => '0');
            testsum        <= (others => '0');
         else   
         
            if (ce = '1') then
            
               cart_wait   <= readwait;
               
               cart_addr   <= std_logic_vector((resize(cartShift, 19) sll ShiftCount0) + (cartCnt and unsigned(CountMask0))) and MaskBank0;
               cart_addr_1 <= cart_addr;
               
               if (readqueue = '1' and readwait = '0') then
                  readqueue <= '0';
                  readwait  <= '1';
                  rom_req   <= '1';
                  if (hasHeader = '1') then
                     rom_addr  <= std_logic_vector(resize(unsigned(cart_addr), 20) + 64);
                  else
                     rom_addr  <= '0' & cart_addr;
                  end if;
               end if;
            
               cartStrobeLast <= cartStrobeEna;
               if (cart_addr /= cart_addr_1 or cartStrobeEna /= cartStrobeLast) then
                  readqueue <= '1';
               end if;
            
               testcnt <= testcnt + 1;
         
               if (cart_strobe0 = '1' and cartStrobeEna = '0') then
                  cartCnt <= cartCnt + 1;
               end if;
                  
               if (Reg_SYSCTL1_written = '1') then
                  if (cartStrobeEna = '1') then
                     cartCnt <= (others => '0');
                  end if;
                  
                  if (cartStrobeEna = '1' and cartStrobeLast = '0') then
                     cartShift <= cartShift(6 downto 0) & Reg_IODAT(1);
                  end if;
            
               end if;
               
            end if;
            
         end if;
      end if;
   end process;
  

end architecture;





