library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

use work.pRegisterBus.all;
use work.pReg_suzy.all;
use work.pBus_savestates.all;
use work.pReg_savestates.all; 

entity math is
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
         
      -- savestates        
      SSBUS_Din      : in  std_logic_vector(SSBUS_buswidth-1 downto 0);
      SSBUS_Adr      : in  std_logic_vector(SSBUS_busadr-1 downto 0);
      SSBUS_wren     : in  std_logic;
      SSBUS_rst      : in  std_logic;
      SSBUS_Dout     : out std_logic_vector(SSBUS_buswidth-1 downto 0)
   );
end entity;

architecture arch of math is

   -- register
   signal Reg_SPRSYS          : std_logic_vector(SPRSYS.upper downto SPRSYS.lower);
   signal Reg_MATHD           : std_logic_vector(MATHD .upper downto MATHD .lower);
   signal Reg_MATHC           : std_logic_vector(MATHC .upper downto MATHC .lower);
   signal Reg_MATHB           : std_logic_vector(MATHB .upper downto MATHB .lower);
   signal Reg_MATHA           : std_logic_vector(MATHA .upper downto MATHA .lower);
   signal Reg_MATHP           : std_logic_vector(MATHP .upper downto MATHP .lower);
   signal Reg_MATHN           : std_logic_vector(MATHN .upper downto MATHN .lower);
   signal Reg_MATHH           : std_logic_vector(MATHH .upper downto MATHH .lower);
   signal Reg_MATHG           : std_logic_vector(MATHG .upper downto MATHG .lower);
   signal Reg_MATHF           : std_logic_vector(MATHF .upper downto MATHF .lower);
   signal Reg_MATHE           : std_logic_vector(MATHE .upper downto MATHE .lower);
   signal Reg_MATHM           : std_logic_vector(MATHM .upper downto MATHM .lower);
   signal Reg_MATHL           : std_logic_vector(MATHL .upper downto MATHL .lower);
   signal Reg_MATHK           : std_logic_vector(MATHK .upper downto MATHK .lower);
   signal Reg_MATHJ           : std_logic_vector(MATHJ .upper downto MATHJ .lower);
                              
   signal Reg_SPRSYS_BACK     : std_logic_vector(SPRSYS.upper downto SPRSYS.lower);
   signal Reg_MATHD_BACK      : std_logic_vector(MATHD .upper downto MATHD .lower);
   signal Reg_MATHC_BACK      : std_logic_vector(MATHC .upper downto MATHC .lower);
   signal Reg_MATHB_BACK      : std_logic_vector(MATHB .upper downto MATHB .lower);
   signal Reg_MATHA_BACK      : std_logic_vector(MATHA .upper downto MATHA .lower);
   signal Reg_MATHP_BACK      : std_logic_vector(MATHP .upper downto MATHP .lower);
   signal Reg_MATHN_BACK      : std_logic_vector(MATHN .upper downto MATHN .lower);
   signal Reg_MATHH_BACK      : std_logic_vector(MATHH .upper downto MATHH .lower);
   signal Reg_MATHG_BACK      : std_logic_vector(MATHG .upper downto MATHG .lower);
   signal Reg_MATHF_BACK      : std_logic_vector(MATHF .upper downto MATHF .lower);
   signal Reg_MATHE_BACK      : std_logic_vector(MATHE .upper downto MATHE .lower);
   signal Reg_MATHM_BACK      : std_logic_vector(MATHM .upper downto MATHM .lower);
   signal Reg_MATHL_BACK      : std_logic_vector(MATHL .upper downto MATHL .lower);
   signal Reg_MATHK_BACK      : std_logic_vector(MATHK .upper downto MATHK .lower);
   signal Reg_MATHJ_BACK      : std_logic_vector(MATHJ .upper downto MATHJ .lower);
   
   signal Reg_MATHD_written   : std_logic;
   signal Reg_MATHC_written   : std_logic;
   signal Reg_MATHB_written   : std_logic;
   signal Reg_MATHA_written   : std_logic;
   signal Reg_MATHP_written   : std_logic;
   signal Reg_MATHN_written   : std_logic;
   signal Reg_MATHH_written   : std_logic;
   signal Reg_MATHG_written   : std_logic;
   signal Reg_MATHF_written   : std_logic;
   signal Reg_MATHE_written   : std_logic;
   signal Reg_MATHM_written   : std_logic;
   signal Reg_MATHL_written   : std_logic;
   signal Reg_MATHK_written   : std_logic;
   signal Reg_MATHJ_written   : std_logic;
   
   type t_reg_wired_or is array(0 to 14) of std_logic_vector(7 downto 0);
   signal reg_wired_or : t_reg_wired_or;   
   
   signal SPRSYS_SignedMath   : std_logic;
   signal SPRSYS_ACCUMULATE   : std_logic;
   
   -- internal
   signal accu_overflow : std_logic := '0';
   
   signal start_convert : std_logic := '0';
   signal convert_ab    : std_logic := '0';
   signal start_mul     : std_logic := '0';
   signal start_accu    : std_logic := '0';
   signal start_div     : std_logic := '0';
   signal div_working   : std_logic := '0';
   
   signal MATHWORKING   : std_logic := '0';
   signal MATHWARNING   : std_logic := '0';
   signal MATHCARRY     : std_logic := '0';
   
   signal sign_AB       : std_logic := '0';
   signal sign_CD       : std_logic := '0';
   
   signal mulresult     : unsigned(31 downto 0);
   
   -- internal divider
   constant bits_per_cycle : integer := 1;
   
   signal divnew    : std_logic := '0';
   signal done      : std_logic := '0';
   signal dividend  : unsigned(31 downto 0);
   signal divisor   : unsigned(31 downto 0);
   signal quotient  : unsigned(31 downto 0);
   signal remainder : unsigned(31 downto 0);
   
   signal dividend_u  : unsigned(dividend'length downto 0);
   signal divisor_u   : unsigned(divisor'length downto 0);
   signal quotient_u  : unsigned(quotient'length downto 0);
   signal Akku        : unsigned (divisor'left + 1 downto divisor'right);
   signal QPointer    : integer range quotient_u'range;
   signal done_buffer : std_logic := '0';
   
   -- savestates
   type t_ss_wired_or is array(0 to 1) of std_logic_vector(63 downto 0);
   signal ss_wired_or : t_ss_wired_or;
   
   signal SS_MATH1          : std_logic_vector(REG_SAVESTATE_MATH1.upper downto REG_SAVESTATE_MATH1.lower);
   signal SS_MATH2          : std_logic_vector(REG_SAVESTATE_MATH2.upper downto REG_SAVESTATE_MATH2.lower);
   signal SS_MATH1_BACK     : std_logic_vector(REG_SAVESTATE_MATH1.upper downto REG_SAVESTATE_MATH1.lower);
   signal SS_MATH2_BACK     : std_logic_vector(REG_SAVESTATE_MATH2.upper downto REG_SAVESTATE_MATH2.lower);

   
begin 

   iSS_MATH1 : entity work.eReg_SS generic map ( REG_SAVESTATE_MATH1 ) port map (clk, SSBUS_Din, SSBUS_Adr, SSBUS_wren, SSBUS_rst, ss_wired_or(0), SS_MATH1_BACK, SS_MATH1); 
   iSS_MATH2 : entity work.eReg_SS generic map ( REG_SAVESTATE_MATH2 ) port map (clk, SSBUS_Din, SSBUS_Adr, SSBUS_wren, SSBUS_rst, ss_wired_or(1), SS_MATH2_BACK, SS_MATH2); 


   iReg_SPRSYS : entity work.eReg generic map ( SPRSYS) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or( 0), Reg_SPRSYS_BACK, Reg_SPRSYS);  
   iReg_MATHD  : entity work.eReg generic map ( MATHD ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or( 1), Reg_MATHD_BACK,  Reg_MATHD,  Reg_MATHD_written);  
   iReg_MATHC  : entity work.eReg generic map ( MATHC ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or( 2), Reg_MATHC_BACK,  Reg_MATHC,  Reg_MATHC_written);  
   iReg_MATHB  : entity work.eReg generic map ( MATHB ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or( 3), Reg_MATHB_BACK,  Reg_MATHB,  Reg_MATHB_written);  
   iReg_MATHA  : entity work.eReg generic map ( MATHA ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or( 4), Reg_MATHA_BACK,  Reg_MATHA,  Reg_MATHA_written);  
   iReg_MATHP  : entity work.eReg generic map ( MATHP ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or( 5), Reg_MATHP_BACK,  Reg_MATHP,  Reg_MATHP_written);  
   iReg_MATHN  : entity work.eReg generic map ( MATHN ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or( 6), Reg_MATHN_BACK,  Reg_MATHN,  Reg_MATHN_written);  
   iReg_MATHH  : entity work.eReg generic map ( MATHH ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or( 7), Reg_MATHH_BACK,  Reg_MATHH,  Reg_MATHH_written);  
   iReg_MATHG  : entity work.eReg generic map ( MATHG ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or( 8), Reg_MATHG_BACK,  Reg_MATHG,  Reg_MATHG_written);  
   iReg_MATHF  : entity work.eReg generic map ( MATHF ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or( 9), Reg_MATHF_BACK,  Reg_MATHF,  Reg_MATHF_written);  
   iReg_MATHE  : entity work.eReg generic map ( MATHE ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(10), Reg_MATHE_BACK,  Reg_MATHE,  Reg_MATHE_written);  
   iReg_MATHM  : entity work.eReg generic map ( MATHM ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(11), Reg_MATHM_BACK,  Reg_MATHM,  Reg_MATHM_written);  
   iReg_MATHL  : entity work.eReg generic map ( MATHL ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(12), Reg_MATHL_BACK,  Reg_MATHL,  Reg_MATHL_written);  
   iReg_MATHK  : entity work.eReg generic map ( MATHK ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(13), Reg_MATHK_BACK,  Reg_MATHK,  Reg_MATHK_written);  
   iReg_MATHJ  : entity work.eReg generic map ( MATHJ ) port map (clk, RegBus_Din, RegBus_Adr, RegBus_wren, RegBus_rst, reg_wired_or(14), Reg_MATHJ_BACK,  Reg_MATHJ,  Reg_MATHJ_written);  

   process (reg_wired_or)
      variable wired_or : std_logic_vector(7 downto 0);
   begin
      wired_or := reg_wired_or(0);
      for i in 1 to (reg_wired_or'length - 1) loop
         wired_or := wired_or or reg_wired_or(i);
      end loop;
      RegBus_Dout <= wired_or;
   end process;
   
   process (ss_wired_or)
      variable wired_or : std_logic_vector(63 downto 0);
   begin
      wired_or := ss_wired_or(0);
      for i in 1 to (ss_wired_or'length - 1) loop
         wired_or := wired_or or ss_wired_or(i);
      end loop;
      SSBUS_Dout <= wired_or;
   end process;
   
   MATHWORKING <= '0'; -- unused
   MATHCARRY   <= '0'; -- unused
   
   Reg_SPRSYS_BACK <= MATHWORKING & MATHWARNING & MATHCARRY & "00000";
   
   SPRSYS_SignedMath <= Reg_SPRSYS(7);
   SPRSYS_ACCUMULATE <= Reg_SPRSYS(6);
   
   
   SS_MATH1_BACK(0) <= sign_AB;    
   SS_MATH1_BACK(1) <= sign_CD;    
   SS_MATH1_BACK(2) <= MATHWARNING;
   SS_MATH1_BACK(3) <= start_mul; 
   SS_MATH1_BACK(4) <= start_accu;
   SS_MATH1_BACK(5) <= start_div; 
   SS_MATH1_BACK(6) <= div_working; 
   SS_MATH1_BACK(7) <= '0'; -- unused
   
   SS_MATH1_BACK(15 downto  8) <= Reg_MATHD_BACK;
   SS_MATH1_BACK(23 downto 16) <= Reg_MATHC_BACK;
   SS_MATH1_BACK(31 downto 24) <= Reg_MATHB_BACK;
   SS_MATH1_BACK(39 downto 32) <= Reg_MATHA_BACK;
   SS_MATH1_BACK(47 downto 40) <= Reg_MATHP_BACK;
   SS_MATH1_BACK(55 downto 48) <= Reg_MATHN_BACK;
   SS_MATH1_BACK(63 downto 56) <= Reg_MATHH_BACK;
   SS_MATH2_BACK( 7 downto  0) <= Reg_MATHG_BACK;
   SS_MATH2_BACK(15 downto  8) <= Reg_MATHF_BACK;
   SS_MATH2_BACK(23 downto 16) <= Reg_MATHE_BACK;
   SS_MATH2_BACK(31 downto 24) <= Reg_MATHM_BACK;
   SS_MATH2_BACK(39 downto 32) <= Reg_MATHL_BACK;
   SS_MATH2_BACK(47 downto 40) <= Reg_MATHK_BACK;
   SS_MATH2_BACK(55 downto 48) <= Reg_MATHJ_BACK;
   
   process (clk)
      variable sign          : std_logic;
      variable valueTMP      : unsigned(15 downto 0);
      variable valueCHECK    : unsigned(15 downto 0);
      variable valueMUL      : unsigned(31 downto 0);
      variable valueACCU     : unsigned(31 downto 0);
      variable valAB         : unsigned(15 downto 0);
      variable valCD         : unsigned(15 downto 0);
      variable valEFGH       : unsigned(31 downto 0);
      variable valJKLM       : unsigned(31 downto 0);
      variable valNP         : unsigned(15 downto 0);
   begin
      if rising_edge(clk) then
      
         divnew <= '0';
      
         if (reset = '1') then

            Reg_MATHD_BACK <= SS_MATH1(15 downto  8); -- (others => '0');
            Reg_MATHC_BACK <= SS_MATH1(23 downto 16); -- (others => '0');
            Reg_MATHB_BACK <= SS_MATH1(31 downto 24); -- (others => '0');
            Reg_MATHA_BACK <= SS_MATH1(39 downto 32); -- (others => '0');
            Reg_MATHP_BACK <= SS_MATH1(47 downto 40); -- (others => '0');
            Reg_MATHN_BACK <= SS_MATH1(55 downto 48); -- (others => '0');
            Reg_MATHH_BACK <= SS_MATH1(63 downto 56); -- (others => '0');
            Reg_MATHG_BACK <= SS_MATH2( 7 downto  0); -- (others => '0');
            Reg_MATHF_BACK <= SS_MATH2(15 downto  8); -- (others => '0');
            Reg_MATHE_BACK <= SS_MATH2(23 downto 16); -- (others => '0');
            Reg_MATHM_BACK <= SS_MATH2(31 downto 24); -- (others => '0');
            Reg_MATHL_BACK <= SS_MATH2(39 downto 32); -- (others => '0');
            Reg_MATHK_BACK <= SS_MATH2(47 downto 40); -- (others => '0');
            Reg_MATHJ_BACK <= SS_MATH2(55 downto 48); -- (others => '0');
            
            sign_AB        <= SS_MATH1(0); -- '0'
            sign_CD        <= SS_MATH1(1); -- '0'
            MATHWARNING    <= SS_MATH1(2); -- '0'
            
            start_mul     <= SS_MATH1(3); -- '0' 
            start_accu    <= SS_MATH1(4); -- '0'
            start_div     <= SS_MATH1(5) or SS_MATH1(6); -- '0' - if division wasn't finished (div_working), start it again when loading savestate
            div_working   <= '0'; -- '0'
      
         elsif (ce = '1') then
         
            -- register access
            if (Reg_MATHD_written = '1') then Reg_MATHD_BACK <= Reg_MATHD; end if;
            if (Reg_MATHC_written = '1') then Reg_MATHC_BACK <= Reg_MATHC; end if;
            if (Reg_MATHB_written = '1') then Reg_MATHB_BACK <= Reg_MATHB; end if;
            if (Reg_MATHA_written = '1') then Reg_MATHA_BACK <= Reg_MATHA; end if;
            if (Reg_MATHP_written = '1') then Reg_MATHP_BACK <= Reg_MATHP; end if;
            if (Reg_MATHN_written = '1') then Reg_MATHN_BACK <= Reg_MATHN; end if;
            if (Reg_MATHH_written = '1') then Reg_MATHH_BACK <= Reg_MATHH; end if;
            if (Reg_MATHG_written = '1') then Reg_MATHG_BACK <= Reg_MATHG; end if;
            if (Reg_MATHF_written = '1') then Reg_MATHF_BACK <= Reg_MATHF; end if;
            if (Reg_MATHE_written = '1') then Reg_MATHE_BACK <= Reg_MATHE; end if;
            if (Reg_MATHM_written = '1') then Reg_MATHM_BACK <= Reg_MATHM; end if;
            if (Reg_MATHL_written = '1') then Reg_MATHL_BACK <= Reg_MATHL; end if;
            if (Reg_MATHK_written = '1') then Reg_MATHK_BACK <= Reg_MATHK; end if;
            if (Reg_MATHJ_written = '1') then Reg_MATHJ_BACK <= Reg_MATHJ; end if;
         
            start_convert <= '0';
         
            if (Reg_MATHD_written = '1') then Reg_MATHC_BACK <= (others => '0'); start_convert <= '1'; convert_ab <= '0'; end if;
            if (Reg_MATHC_written = '1') then start_convert <= '1'; convert_ab <= '0'; end if;
            if (Reg_MATHB_written = '1') then Reg_MATHA_BACK <= (others => '0'); end if;
            if (Reg_MATHA_written = '1') then start_convert <= '1'; convert_ab <= '1'; start_mul <= '1'; end if;
            if (Reg_MATHP_written = '1') then Reg_MATHN_BACK <= (others => '0'); end if;
            if (Reg_MATHH_written = '1') then Reg_MATHG_BACK <= (others => '0'); end if;
            if (Reg_MATHF_written = '1') then Reg_MATHE_BACK <= (others => '0'); end if;
            if (Reg_MATHE_written = '1') then start_div <= '1'; end if;
            if (Reg_MATHM_written = '1') then Reg_MATHL_BACK <= (others => '0'); MATHWARNING <= '0'; end if;
            if (Reg_MATHK_written = '1') then Reg_MATHJ_BACK <= (others => '0'); end if;
            
            valAB   := unsigned(Reg_MATHA_BACK) & unsigned(Reg_MATHB_BACK);
            valCD   := unsigned(Reg_MATHC_BACK) & unsigned(Reg_MATHD_BACK);
            valEFGH := unsigned(Reg_MATHE_BACK) & unsigned(Reg_MATHF_BACK) & unsigned(Reg_MATHG_BACK) & unsigned(Reg_MATHH_BACK);
            valJKLM := unsigned(Reg_MATHJ_BACK) & unsigned(Reg_MATHK_BACK) & unsigned(Reg_MATHL_BACK) & unsigned(Reg_MATHM_BACK);
            valNP   := unsigned(Reg_MATHN_BACK) & unsigned(Reg_MATHP_BACK);
            
            -- convert sign
            if (start_convert = '1') then
               if (SPRSYS_SignedMath = '1') then
               
                  valueTMP := valCD;
                  if (convert_ab = '1') then
                     valueTMP := valAB;
                  end if;
                  
                  -- 0x8000 = positive bug
                  sign := '1';
                  valueCHECK := valueTMP - 1;
                  if (valueCHECK(15) = '1') then
                     valueTMP := not valueTMP;
                     valueTMP := valueTMP + 1;
                     sign := '0';
                     if (convert_ab = '1') then
                        Reg_MATHA_BACK <= std_logic_vector(valueTMP(15 downto 8));
                        Reg_MATHB_BACK <= std_logic_vector(valueTMP( 7 downto 0));
                     else
                        Reg_MATHC_BACK <= std_logic_vector(valueTMP(15 downto 8));
                        Reg_MATHD_BACK <= std_logic_vector(valueTMP( 7 downto 0));
                     end if;
                     
                  end if;
                  
                  if (convert_ab = '1') then
                     sign_AB <= sign;
                  else
                     sign_CD <= sign;
                  end if;
                  
               end if;
            end if;
            
            -- Multiply
            if (start_mul = '1' and start_convert = '0') then
               start_mul <= '0';
            
               valueMUL := valAB * valCD;
               
               if (SPRSYS_SignedMath = '1' and sign_AB /= sign_CD) then
                  valueMUL := not valueMUL;
                  valueMUL := valueMUL + 1;
               end if;
               
               Reg_MATHE_BACK <= std_logic_vector(valueMUL(31 downto 24));
               Reg_MATHF_BACK <= std_logic_vector(valueMUL(23 downto 16));
               Reg_MATHG_BACK <= std_logic_vector(valueMUL(15 downto 8));
               Reg_MATHH_BACK <= std_logic_vector(valueMUL( 7 downto 0));
            
               if (SPRSYS_ACCUMULATE = '1') then
                  mulresult  <= valueMUL;
                  start_accu <= '1';
               end if;
            
            end if;
            
            -- accumulate
            if (start_accu = '1') then
               start_accu <= '0';
               
               valueACCU := valJKLM + mulresult;
         
               --if ((resultACCU(31)) /= (valJKLM(31))) -- doesn't this set overflow bit?
               Reg_MATHJ_BACK <= std_logic_vector(valueACCU(31 downto 24));
               Reg_MATHK_BACK <= std_logic_vector(valueACCU(23 downto 16));
               Reg_MATHL_BACK <= std_logic_vector(valueACCU(15 downto 8));
               Reg_MATHM_BACK <= std_logic_vector(valueACCU( 7 downto 0));
               
            end if;
            
            -- divide
            if (start_div = '1' and start_convert = '0') then
               start_div   <= '0';
               div_working <= '1';
               
               dividend <= valEFGH;
               divisor  <= x"0000" & valNP;
            
               if (valNP /= x"0000") then
                  divnew <= '1'; 
               else
                  MATHWARNING <= '1';
                  Reg_MATHA_BACK <= x"FF";
                  Reg_MATHB_BACK <= x"FF";
                  Reg_MATHC_BACK <= x"FF";
                  Reg_MATHD_BACK <= x"FF";
               
                  Reg_MATHJ_BACK <= x"00";
                  Reg_MATHK_BACK <= x"00";
                  Reg_MATHL_BACK <= x"00";
                  Reg_MATHM_BACK <= x"00";
               end if;               

            end if;
            
            if (done = '1') then
               div_working <= '0';
               Reg_MATHA_BACK <= std_logic_vector(quotient(31 downto 24));
               Reg_MATHB_BACK <= std_logic_vector(quotient(23 downto 16));
               Reg_MATHC_BACK <= std_logic_vector(quotient(15 downto 8));
               Reg_MATHD_BACK <= std_logic_vector(quotient( 7 downto 0));
               
               Reg_MATHJ_BACK <= std_logic_vector(remainder(31 downto 24));
               Reg_MATHK_BACK <= std_logic_vector(remainder(23 downto 16));
               Reg_MATHL_BACK <= std_logic_vector(remainder(15 downto 8));
               Reg_MATHM_BACK <= std_logic_vector(remainder( 7 downto 0));
            end if;
            
         end if;
      end if;
   end process;
   
      process (clk) is
      variable XPointer    : integer range dividend_u'range;
      variable QPointerNew : integer range quotient_u'range;
      variable AkkuNew     : unsigned (divisor'left + 1 downto divisor'right);
      variable Rdy_i       : std_logic;
      variable Q_bits      : std_logic_vector(bits_per_cycle-1 downto 0);
      variable Diff        : unsigned (AkkuNew'range);
   begin
      if rising_edge(clk) then

         if (ce = '1') then
            done_buffer <= '0';
         end if;
         
         -- == Initialize loop ===============================================
         if divnew = '1' then
            
            dividend_u  <= '0' & dividend;
            divisor_u   <= '0' & divisor;
            
            QPointerNew := quotient_u'left;
            XPointer    := dividend_u'left;
            Rdy_i       := '0';
            --AkkuNew     := (Akku'left downto 1 => '0') & dividend(XPointer);
            AkkuNew     := (others => '0');
         -- == Repeat for every Digit in Q ===================================
         elsif Rdy_i = '0' then
            AkkuNew := Akku;
            QPointerNew := QPointer;        
            
            for i in 1 to bits_per_cycle loop
             
               -- Calculate output digit and new Akku ---------------------------
               Diff := AkkuNew - divisor_u;
               if Diff(Diff'left) = '0' then              -- Does Y fit in Akku?
                  Q_bits(bits_per_cycle-i)   := '1';                         -- YES: Digit is '1'
                  AkkuNew := unsigned(shift_left(Diff,1));--      Diff -> Akku
               else                                       --    
                  Q_bits(bits_per_cycle-i)   := '0';                         -- NO : Digit is '0'
                  AkkuNew := unsigned(Shift_left(AkkuNew,1));--      Shift Akku
               end if;
               -- ---------------------------------------------------------------
               if XPointer > dividend'right then                 -- divisor read completely?
                  XPointer := XPointer - 1;               -- NO : Put next digit
                  AkkuNew(AkkuNew'right) := dividend_u(XPointer);  --      in Akku         
               else
                  AkkuNew(AkkuNew'right) := '0'        ;  -- YES: Read Zeros (post point)      
               end if;
               -- ---------------------------------------------------------------
               if QPointerNew > quotient'right then                 -- Has this been the last cycle?
                  QPointerNew := QPointerNew - 1;               -- NO : Prepare next cycle
               else                                       -- 
                  Rdy_i := '1';                             -- YES: work done
                  done_buffer <= '1';
               end if;
               
            end loop; 
            
            quotient_u(QPointer downto QPointer-(bits_per_cycle-1)) <= unsigned(Q_bits);
         end if;
         
         QPointer  <= QPointerNew;
         Akku      <= AkkuNew;

         if (ce = '1') then
            quotient  <= quotient_u(quotient'left downto 0);
            remainder <= AkkuNew(remainder'left + 1 downto remainder'right + 1);
            done      <= done_buffer;
         end if;
            
      end if;
   end process;
  

end architecture;





