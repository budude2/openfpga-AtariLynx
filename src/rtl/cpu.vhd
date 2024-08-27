library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.pexport.all;
use work.pBus_savestates.all;
use work.pReg_savestates.all;

entity cpu is
   port
   (
      clk            : in  std_logic;
      ce             : in  std_logic;
      reset          : in  std_logic;
         
      cpu_idle       : out std_logic;
      dma_active     : in  std_logic;
      cpu_sleep      : in  std_logic;
         
      bus_request    : out std_logic := '0';
      bus_rnw        : out std_logic := '0';
      bus_addr       : out unsigned(15 downto 0) := (others => '0');
      bus_datawrite  : out std_logic_vector(7 downto 0) := (others => '0');
      bus_dataread   : in  std_logic_vector(7 downto 0);
      bus_done       : in  std_logic;
   
      irqrequest_in  : in  std_logic;
      irqclear_in    : in  std_logic;
      irqdisabled    : out std_logic;
      irqpending     : out std_logic;
      irqfinish      : out std_logic := '0';
      
      load_savestate : in  std_logic;
      custom_PCAddr  : in  std_logic_vector(15 downto 0);
      custom_PCuse   : in  std_logic;
         
      cpu_done       : out std_logic := '0'; 
      cpu_export     : out cpu_export_type;
         
      -- savestates        
      SSBUS_Din      : in  std_logic_vector(SSBUS_buswidth-1 downto 0);
      SSBUS_Adr      : in  std_logic_vector(SSBUS_busadr-1 downto 0);
      SSBUS_wren     : in  std_logic;
      SSBUS_rst      : in  std_logic;
      SSBUS_Dout     : out std_logic_vector(SSBUS_buswidth-1 downto 0)
   );
end entity;

architecture arch of cpu is

   type CPU_Addressmode is
   (
      immediate,
      zeropage,
      zeropageXAddr,
      zeropageX,
      zeropageY,
      zeropageIndirect,
      zeropageYIndirect,
      absolute,
      absoluteX,
      absoluteY,
      absoluteIndirect,
      absoluteIndexIndirect,
      accu,
      stackpush,
      stackpop,
      stackpushdual,
      stackpopdual,
      INVALIDADDRESSMODE
   );

   type CPU_Opcode is
   (
      EOR,
      ADC,
      STA,
      LDA,
      SBC,
      JMP,
      OPBIT,
      OPAND,
      TSB,
      TRB,
      LDY,
      LDX,
      PHP,
      CLC,
      PHA,
      CLI,
      SEI,
      CLV,
      CLD,
      SED,
      SEC,
      NOP,
      STY,
      JSR,
      ASL,
      OPROL,
      LSR,
      OPROR,
      OPSTX,
      DEC,
      INC,
      RTI,
      RTS,
      ORA,
      BRK,
      BRANCH,
      LDS, -- artificial
      LDP, -- artificial
      COMPARE, -- artificial
      WRITEMEM, -- artificial
      IRQPUSH, -- artificial
      IRQLOADPC,
      INVALIDOPCODE
   );
   
   type CPU_state is
   (
      IDLE,
      DECODE,
      CALC,
      MEMREAD,
      MEMWRITE
   );
   
   signal PC               : unsigned(15 downto 0) := (others => '0');
   signal RegA             : unsigned(7 downto 0)  := (others => '0');
   signal RegX             : unsigned(7 downto 0)  := (others => '0');
   signal RegY             : unsigned(7 downto 0)  := (others => '0');
   signal RegS             : unsigned(7 downto 0)  := (others => '0');
   signal RegP             : unsigned(7 downto 0);
   signal FlagNeg          : std_logic := '0';
   signal FlagOvf          : std_logic := '0';
   signal FlagBrk          : std_logic := '0';
   signal FlagDez          : std_logic := '0';
   signal FlagIrq          : std_logic := '0';
   signal FlagZer          : std_logic := '0';
   signal FlagCar          : std_logic := '0';
                           
   signal sleep            : std_logic := '0';
   signal irqrequest       : std_logic := '0';
               
   -- instruction intermediates
   signal addressmode      : CPU_Addressmode;
   signal opcode           : CPU_Opcode;
   signal state            : CPU_state;
   signal instructionStep  : integer range 0 to 4;
   signal op8              : unsigned(7 downto 0);
   signal op16             : unsigned(15 downto 0);
   signal addrZP           : unsigned(7 downto 0);
   signal addrIndirect     : unsigned(15 downto 0);
   signal addrJMP          : unsigned(15 downto 0);
   signal addrLast         : unsigned(15 downto 0);
   signal branchtaken      : std_logic;
   signal isStore          : std_logic;
   signal opSecond         : unsigned(7 downto 0);
   signal opcodebyte_last  : std_logic_vector(7 downto 0) := (others => '0');
   signal irqstep          : integer range 0 to 4;

   -- savestates
   signal SS_CPU           : std_logic_vector(REG_SAVESTATE_CPU.upper downto REG_SAVESTATE_CPU.lower);
   signal SS_CPU_BACK      : std_logic_vector(REG_SAVESTATE_CPU.upper downto REG_SAVESTATE_CPU.lower);
   
   signal load_savestate_buffer : std_logic := '0';

   -- debug
   signal testcmd          : unsigned(31 downto 0);
   signal testpcsum        : unsigned(63 downto 0);

begin

   iSS_CPU : entity work.eReg_SS generic map ( REG_SAVESTATE_CPU ) port map (clk, SSBUS_Din, SSBUS_Adr, SSBUS_wren, SSBUS_rst, SSBUS_Dout, SS_CPU_BACK, SS_CPU);  

   RegP <= FlagNeg & FlagOvf & '1' & FlagBrk & FlagDez & FlagIrq & FlagZer & FlagCar;

   cpu_idle <= '1' when state = IDLE else '0';
   
   irqdisabled <= FlagIrq;
   irqpending  <= irqrequest;

   process (clk)
   begin
      if rising_edge(clk) then
         if (reset = '1') then
            irqrequest <= SS_CPU(56); -- '0';
         else 
            if (irqrequest_in = '1') then
               irqrequest <= '1';
            elsif (irqclear_in = '1') then
               irqrequest <= '0';
            end if;
            if (ce = '1' and state = IDLE and (dma_active = '0' and cpu_sleep = '0') and (FlagIrq = '0' and (irqrequest_in = '1' or irqrequest = '1'))) then
               irqrequest <= '0';
            end if;
         end if;
      end if;
   end process;

   SS_CPU_BACK(15 downto  0) <= std_logic_vector(  PC);
   SS_CPU_BACK(23 downto 16) <= std_logic_vector(RegA);
   SS_CPU_BACK(31 downto 24) <= std_logic_vector(RegX);
   SS_CPU_BACK(39 downto 32) <= std_logic_vector(RegY);
   SS_CPU_BACK(47 downto 40) <= std_logic_vector(RegS);
   SS_CPU_BACK(55 downto 48) <= std_logic_vector(RegP);
   SS_CPU_BACK(          56) <= irqrequest;

   process (clk)
      variable opcodebyte : std_logic_vector(7 downto 0);
      variable aaa : integer range 0 to 7;
      variable bbb : integer range 0 to 7;
      variable cc  : integer range 0 to 3;
      variable writeback    : std_logic;
      variable checkFlagsNZ : std_logic;
      variable calcresult   : unsigned(7 downto 0);
      variable result9      : unsigned(8 downto 0);
      variable rhigh        : unsigned(4 downto 0);
      variable rlow         : unsigned(4 downto 0);
   begin
      if rising_edge(clk) then
         
         cpu_done    <= '0';
         
         if (load_savestate = '1') then
            load_savestate_buffer <= '1';
         end if;
      
         if (reset = '1') then
         
            load_savestate_buffer <= '0';
            if (load_savestate_buffer = '1') then
               PC           <= unsigned(SS_CPU(15 downto  0));
            elsif (custom_PCuse = '1') then
               PC           <= unsigned(custom_PCAddr);
            else
               PC           <= x"FF80";
            end if;
            
            RegA            <= unsigned(SS_CPU(23 downto 16)); -- (others => '0');
            RegX            <= unsigned(SS_CPU(31 downto 24)); -- (others => '0');
            RegY            <= unsigned(SS_CPU(39 downto 32)); -- (others => '0');
            RegS            <= unsigned(SS_CPU(47 downto 40)); -- x"FF";
            FlagNeg         <= SS_CPU(55); -- '0';
            FlagOvf         <= SS_CPU(54); -- '0';
            FlagBrk         <= SS_CPU(52); -- '0';
            FlagDez         <= SS_CPU(51); -- '0';
            FlagIrq         <= SS_CPU(50); -- '1';
            FlagZer         <= SS_CPU(49); -- '1';
            FlagCar         <= SS_CPU(48); -- '0';
                            
            sleep           <= '0';
            state           <= IDLE;
            opcodebyte_last <= (others => '0');
            
            testcmd         <= (others => '0');
            testpcsum       <= (others => '0');
            
         elsif (ce = '1') then
         
            bus_request <= '0';
            irqfinish   <= '0';
            
            --if (testcmd(31) = '1' or testpcsum(63) = '1') then
            --   bus_rnw <= '0';
            --end if;
         
            case state is
            
               when IDLE =>
                  if (dma_active = '0' and cpu_sleep = '0') then
                     if (FlagIrq = '0' and (irqrequest_in = '1' or irqrequest = '1')) then
                        state           <= CALC;
                        addressmode     <= stackpushdual;         
                        instructionStep <= 2; 
                        opcode          <= IRQPUSH;
                        op16            <= PC;
                     else
                        state       <= DECODE;
                        bus_request <= '1';
                        bus_rnw     <= '1';
                        bus_addr    <= PC;
                        PC          <= PC  + 1;
                        
                        testcmd     <= testcmd + 1;
                        testpcsum   <= testpcsum + PC;
                     end if;
                  end if;
                  
               when DECODE =>
                  if (bus_done = '1') then
                     
                     state <= CALC;
                  
                     opcodebyte := bus_dataread;
                     opcodebyte_last <= opcodebyte;
                     aaa := to_integer(unsigned(opcodebyte(7 downto 5))); -- opcode
                     bbb := to_integer(unsigned(opcodebyte(4 downto 2))); -- addressing
                     cc  := to_integer(unsigned(opcodebyte(1 downto 0))); -- opcode group
                  
                     instructionStep <= 0;
                     opcode          <= INVALIDOPCODE;
                     addressmode     <= INVALIDADDRESSMODE;
                     op16            <= (others => '0');
                     isStore         <= '0';
                     branchtaken     <='0';

                     -- special commands first
                     if (opcodebyte = x"00")    then addressmode<=stackpushdual;         instructionStep<=2; opcode<=BRK; op16<= PC + 1;              -- BRK
                     elsif (opcodebyte = x"20") then addressmode<=absolute;              instructionStep<=3; opcode<=JSR;                             -- JSR abs
                     elsif (opcodebyte = x"40") then addressmode<=stackpop;              instructionStep<=1; opcode<=RTI;                             -- RTI
                     elsif (opcodebyte = x"60") then addressmode<=stackpopdual;          instructionStep<=2; opcode<=RTS;                             -- RTS
                                             
                     -- 65c02                         
                     elsif (opcodebyte = x"12") then addressmode<=zeropageIndirect;      instructionStep<=4; opcode<=ORA;                             -- ORA zp
                     elsif (opcodebyte = x"32") then addressmode<=zeropageIndirect;      instructionStep<=4; opcode<=OPAND;                             -- AND zp
                     elsif (opcodebyte = x"52") then addressmode<=zeropageIndirect;      instructionStep<=4; opcode<=EOR;                             -- EOR zp
                     elsif (opcodebyte = x"72") then addressmode<=zeropageIndirect;      instructionStep<=4; opcode<=ADC;                             -- ADC zp
                     elsif (opcodebyte = x"92") then addressmode<=zeropageIndirect;      instructionStep<=4; opcode<=STA; isStore<='1'; op8<=RegA;    -- STA zp  
                     elsif (opcodebyte = x"B2") then addressmode<=zeropageIndirect;      instructionStep<=4; opcode<=LDA;                             -- LDA zp 
                     elsif (opcodebyte = x"D2") then addressmode<=zeropageIndirect;      instructionStep<=4; opcode<=COMPARE; opSecond<=RegA;         -- CMP zp 
                     elsif (opcodebyte = x"F2") then addressmode<=zeropageIndirect;      instructionStep<=4; opcode<=SBC;                             -- SBC zp
                  
                     elsif (opcodebyte = x"7C") then addressmode<=absoluteIndexIndirect; instructionStep<=4; opcode<=JMP;                             -- JMP abs,X
                                             
                     elsif (opcodebyte = x"89") then addressmode<=immediate;             instructionStep<=1; opcode<=OPBIT;                             -- BIT #    
                     elsif (opcodebyte = x"34") then addressmode<=zeropageX;             instructionStep<=2; opcode<=OPBIT;                             -- BIT zp,X 
                     elsif (opcodebyte = x"3C") then addressmode<=absoluteX;             instructionStep<=3; opcode<=OPBIT;                             -- BIT abs,X
                                                      
                     elsif (opcodebyte = x"04") then addressmode<=zeropage;              instructionStep<=2; opcode<=TSB;                             -- TSB zp 
                     elsif (opcodebyte = x"0C") then addressmode<=absolute;              instructionStep<=3; opcode<=TSB;                             -- TSB abs
                                                                                                
                     elsif (opcodebyte = x"14") then addressmode<=zeropage;              instructionStep<=2; opcode<=TRB;                             -- TRB zp
                     elsif (opcodebyte = x"1C") then addressmode<=absolute;              instructionStep<=3; opcode<=TRB;                             -- TRB abs
                  
                     elsif (opcodebyte = x"64") then addressmode<=zeropage;              instructionStep<=2;              isStore<= '1'; op8<=x"00";  -- STZ zp
                     elsif (opcodebyte = x"9C") then addressmode<=absolute;              instructionStep<=3;              isStore<= '1'; op8<=x"00";  -- STZ abs
                     elsif (opcodebyte = x"74") then addressmode<=zeropageX;             instructionStep<=2;              isStore<= '1'; op8<=x"00";  -- STZ zp,X
                     elsif (opcodebyte = x"9E") then addressmode<=absoluteX;             instructionStep<=3;              isStore<= '1'; op8<=x"00";  -- STZ abs,X
                  
                     elsif (opcodebyte = x"80") then addressmode<=immediate;             instructionStep<=1; opcode<=BRANCH; branchtaken<='1';        -- BRA
                  
                     elsif (opcodebyte = x"1A") then                                                         opcode<=LDA; op8<=RegA + 1;              -- INC A
                     elsif (opcodebyte = x"3A") then                                                         opcode<=LDA; op8<=RegA - 1;              -- DEC A
                     elsif (opcodebyte = x"5A") then addressmode<=stackpush;             instructionStep<=1;              op8<=RegY;                  -- PHY
                     elsif (opcodebyte = x"7A") then addressmode<=stackpop;              instructionStep<=1; opcode<=LDY;                             -- PLY
                     elsif (opcodebyte = x"DA") then addressmode<=stackpush;             instructionStep<=1;              op8<=RegX;                  -- PHX
                     elsif (opcodebyte = x"FA") then addressmode<=stackpop;              instructionStep<=1; opcode<=LDX;                             -- PLX

                     elsif (opcodebyte(4 downto 0) = "10000") then -- branches

                        case opcodebyte(7 downto 6) is
                           when "00" => if (FlagNeg = opcodebyte(5)) then branchtaken<='1'; end if;
                           when "01" => if (FlagOvf = opcodebyte(5)) then branchtaken<='1'; end if;
                           when "10" => if (FlagCar = opcodebyte(5)) then branchtaken<='1'; end if;
                           when "11" => if (FlagZer = opcodebyte(5)) then branchtaken<='1'; end if;
                           when others => null;
                        end case;
                        opcode<=BRANCH;
                        addressmode<=immediate;
                        instructionStep<=1;

                     elsif (opcodebyte(3 downto 0) = x"8") then -- single byte instructions
                     
                        case opcodebyte(7 downto 4) is
                           when x"0" => opcode<=PHP; addressmode<=stackpush; instructionStep<=1; op8<=RegP; 
                           when x"1" => opcode<=CLC; FlagCar<='0'; 
                           when x"2" => opcode<=LDP; addressmode<=stackpop; instructionStep<=1; 
                           when x"3" => opcode<=SEC; FlagCar<='1'; 
                           when x"4" => opcode<=PHA; addressmode<=stackpush; instructionStep<=1; op8<=RegA; 
                           when x"5" => opcode<=CLI; FlagIrq<='0'; 
                           when x"6" => opcode<=LDA; addressmode<=stackpop; instructionStep<=1;  -- PLA
                           when x"7" => opcode<=SEI; FlagIrq<='1'; 
                           when x"8" => opcode<=LDY; op8<=RegY - 1;  -- DEY
                           when x"9" => opcode<=LDA; op8<=RegY;  -- TYA
                           when x"A" => opcode<=LDY; op8<=RegA;  -- TAY
                           when x"B" => opcode<=CLV; FlagOvf<='0'; 
                           when x"C" => opcode<=LDY; op8<=RegY + 1;  -- INY
                           when x"D" => opcode<=CLD; FlagDez<='0'; 
                           when x"E" => opcode<=LDX; op8<=RegX + 1;  -- INX
                           when x"F" => opcode<=SED; FlagDez<='1'; 
                           when others => null;
                        end case;
                     
                     elsif (opcodebyte(3 downto 0) = x"A" and opcodebyte(7) = '1') then -- more single byte instructions
                     
                        case opcodebyte(7 downto 4) is
                           when x"8" => opcode<=LDA; op8<=RegX;  -- TXA
                           when x"9" => opcode<=LDS; op8<=RegX;  -- TXS
                           when x"A" => opcode<=LDX; op8<=RegA;  -- TAX
                           when x"B" => opcode<=LDX; op8<=RegS;  -- TSX
                           when x"C" => opcode<=LDX; op8<=RegX - 1;  -- DEX
                           when x"D" => opcode<=INVALIDOPCODE; 
                           when x"E" => opcode<=NOP; 
                           when x"F" => opcode<=INVALIDOPCODE; 
                           when others => null;
                        end case;
                     
                     else
                     
                        case (cc) is
                           when 0 =>
                              case (bbb) is
                                 when 0 => addressmode<=immediate; instructionStep<=1; 
                                 when 1 => addressmode<=zeropage; instructionStep<=2; 
                                 when 2 => addressmode<=INVALIDADDRESSMODE; 
                                 when 3 => addressmode<=absolute; instructionStep<=3; 
                                 when 4 => addressmode<=INVALIDADDRESSMODE; 
                                 when 5 => addressmode<=zeropageX; instructionStep<=2; 
                                 when 6 => addressmode<=INVALIDADDRESSMODE; 
                                 when 7 => addressmode<=absoluteX; instructionStep<=3; 
                              end case;
                              
                              case (aaa) is
                                 when 0 => opcode<=INVALIDOPCODE; 
                                 when 1 => opcode<=OPBIT; 
                                 when 2 => opcode<=JMP; 
                                 when 3 => opcode<=JMP; addressmode<=absoluteIndirect; instructionStep<=4;  -- JMPA
                                 when 4 => opcode<=STY; isStore<='1'; op8<=RegY; 
                                 when 5 => opcode<=LDY; 
                                 when 6 => opcode<=COMPARE; opSecond<=RegY;  --CPY
                                 when 7 => opcode<=COMPARE; opSecond<=RegX;  --CPX
                              end case;
                           
                           when 1 =>
                              case (bbb) is
                                 when 0 => addressmode<=zeropageXAddr; instructionStep<=4; 
                                 when 1 => addressmode<=zeropage; instructionStep<=2; 
                                 when 2 => addressmode<=immediate; instructionStep<=1; 
                                 when 3 => addressmode<=absolute; instructionStep<=3; 
                                 when 4 => addressmode<=zeropageYIndirect; instructionStep<=4; 
                                 when 5 => addressmode<=zeropageX; instructionStep<=2; 
                                 when 6 => addressmode<=absoluteY; instructionStep<=3; 
                                 when 7 => addressmode<=absoluteX; instructionStep<=3; 
                              end case;
                              
                              case (aaa) is
                                 when 0 => opcode<=ORA; 
                                 when 1 => opcode<=OPAND; 
                                 when 2 => opcode<=EOR; 
                                 when 3 => opcode<=ADC; 
                                 when 4 => opcode<=STA; isStore<='1'; op8<=RegA; 
                                 when 5 => opcode<=LDA; 
                                 when 6 => opcode<=COMPARE; opSecond<=RegA;  -- CMP
                                 when 7 => opcode<=SBC; 
                              end case;
                     
                           when 2 =>
                              case (bbb) is
                                 when 0 => addressmode<=immediate; instructionStep<=1; 
                                 when 1 => addressmode<=zeropage; instructionStep<=2; 
                                 when 2 => addressmode<=accu; op8<=RegA; 
                                 when 3 => addressmode<=absolute; instructionStep<=3; 
                                 when 4 => addressmode<=INVALIDADDRESSMODE; 
                                 when 5 => addressmode<=zeropageX; instructionStep<=2; 
                                 when 6 => addressmode<=INVALIDADDRESSMODE; 
                                 when 7 => addressmode<=absoluteX; instructionStep<=3; 
                              end case;
                              
                              case (aaa) is
                                 when 0 => opcode<=ASL; 
                                 when 1 => opcode<=OPROL; 
                                 when 2 => opcode<=LSR; 
                                 when 3 => opcode<=OPROR; 
                                 when 4 => opcode<=OPSTX; 
                                    isStore<='1'; 
                                    op8<=RegX; 
                                    if (bbb = 5) then addressmode<=zeropageY; end if;
                                    
                                 when 5 =>
                                    opcode<=LDX;
                                    if (bbb = 5) then addressmode<=zeropageY; end if;
                                    if (bbb = 7) then addressmode<=absoluteY; end if;
                                    
                                 when 6 => opcode<=DEC; 
                                 when 7 => opcode<=INC; 
                              end case;
                           
                           when 3 =>
                              case (bbb) is
                                 when 0 => addressmode<=INVALIDADDRESSMODE; 
                                 when 1 => addressmode<=INVALIDADDRESSMODE; 
                                 when 2 => addressmode<=INVALIDADDRESSMODE; 
                                 when 3 => addressmode<=INVALIDADDRESSMODE; 
                                 when 4 => addressmode<=INVALIDADDRESSMODE; 
                                 when 5 => addressmode<=INVALIDADDRESSMODE; 
                                 when 6 => addressmode<=INVALIDADDRESSMODE; 
                                 when 7 => addressmode<=INVALIDADDRESSMODE; 
                              end case;
                              
                              case (aaa) is
                                 when 0 => opcode<=INVALIDOPCODE; 
                                 when 1 => opcode<=INVALIDOPCODE; 
                                 when 2 => opcode<=INVALIDOPCODE; 
                                 when 3 => opcode<=INVALIDOPCODE; 
                                 when 4 => opcode<=INVALIDOPCODE; 
                                 when 5 => opcode<=INVALIDOPCODE; 
                                 when 6 => opcode<=INVALIDOPCODE; 
                                 when 7 => opcode<=INVALIDOPCODE; 
                              end case;
                           
                        end case;

                     end if;

                  end if;
                  
               when CALC =>
                  
                  if (instructionStep > 0) then
                  
                     -- defaults, overwritten if required
                     state         <= MEMREAD;
                     bus_request   <= '1';
                     bus_rnw       <= '1';
                     bus_addr      <= PC;
                     bus_datawrite <= std_logic_vector(op8);
                  
                     case (addressmode) is
                     
                        when immediate =>
                           if (instructionStep = 1) then PC <= PC + 1; end if;
                  
                        when absolute | absoluteX | absoluteY =>
                           if (instructionStep = 3) then PC <= PC + 1; end if;
                           if (instructionStep = 2) then PC <= PC + 1; end if;
                           if (instructionStep = 1) then
                              addrLast <= op16;
                              bus_addr <= op16;
                              if (addressmode = absoluteX) then bus_addr <= op16 + RegX; addrLast <= op16 + RegX; end if;
                              if (addressmode = absoluteY) then bus_addr <= op16 + RegY; addrLast <= op16 + RegY; end if;
                              if (isStore = '1') then opcode <= WRITEMEM; bus_rnw <= '0'; state <= MEMWRITE; end if;
                           end if;
                                 
                        when absoluteIndirect | absoluteIndexIndirect =>
                           if (instructionStep = 4) then PC <= PC + 1; end if;
                           if (instructionStep = 3) then PC <= PC + 1; end if;
                           if (instructionStep = 2) then bus_addr <= addrJMP; end if;
                           if (instructionStep = 1) then bus_addr <= addrJMP + 1; end if;
                  
                        when stackpop =>
                           RegS <= RegS + 1;
                           bus_addr <= resize(RegS + 1, 16) + 16#100#; 
                  
                        when stackpopdual =>
                           if (instructionStep = 2) then RegS <= RegS + 1; bus_addr <= resize(RegS + 1, 16) + 16#100#; end if;
                           if (instructionStep = 1) then RegS <= RegS + 1; bus_addr <= resize(RegS + 1, 16) + 16#100#; end if; 
                  
                        when stackpush =>
                           bus_addr <= resize(RegS, 16) + 16#100#;
                           state    <= MEMWRITE;
                           RegS     <= RegS - 1;
                           bus_rnw  <= '0';
 
                        when stackpushdual =>
                           bus_rnw <= '0'; bus_addr <= resize(RegS, 16) + 16#100#; RegS <= RegS - 1; state <= MEMWRITE;
                           if (instructionStep = 2) then bus_datawrite <= std_logic_vector(op16(15 downto 8)); end if;
                           if (instructionStep = 1) then bus_datawrite <= std_logic_vector(op16( 7 downto 0)); end if;
                           
                        when zeropage | zeropageX | zeropageY =>
                           if (instructionStep = 2) then PC <= PC + 1; end if;
                           if (instructionStep = 1) then
                              addrLast <= resize(addrZP, 16);
                              bus_addr <= resize(addrZP, 16);
                              if (addressmode = zeropageX) then bus_addr <= resize(addrZP + RegX, 16); addrLast <= resize(addrZP + RegX, 16); end if;
                              if (addressmode = zeropageY) then bus_addr <= resize(addrZP + RegY, 16); addrLast <= resize(addrZP + RegY, 16); end if;
                              if (isStore = '1') then opcode <= WRITEMEM; bus_rnw <= '0'; state <= MEMWRITE; end if;
                           end if;
                  
                        when zeropageXAddr | zeropageIndirect =>
                           if (instructionStep = 4) then PC <= PC + 1; end if;
                           if (instructionStep = 3) then bus_addr <= resize(addrZP, 16); end if;
                           if (instructionStep = 2) then bus_addr <= resize(addrZP, 16) + 1; end if;
                           if (instructionStep = 1) then
                              if (isStore = '1') then opcode <= WRITEMEM; bus_rnw <= '0'; state <= MEMWRITE; end if;
                              addrLast<= op16;
                              bus_addr<= op16;
                           end if;
                  
                        when zeropageYIndirect =>
                           if (instructionStep = 4) then PC <= PC + 1; end if;
                           if (instructionStep = 3) then bus_addr <= resize(addrZP, 16); end if;
                           if (instructionStep = 2) then bus_addr <= resize(addrZP, 16) + 1; end if;
                           if (instructionStep = 1) then
                              addrLast <= op16 + RegY;
                              bus_addr <= op16 + RegY;
                              if (isStore = '1') then opcode <= WRITEMEM; bus_rnw <= '0'; state <= MEMWRITE; end if;
                           end if;
                  
                        when INVALIDADDRESSMODE | ACCU =>
                           null;
                  
                     end case;   
                     
                        
                  else

                     state    <= IDLE;
                     cpu_done <= '1';
                     
                     checkFlagsNZ := '0';
                     writeback    := '0';
                     calcresult   := op8; -- overwritten if required
                     
                     case (opcode) is
                     
                        -- register loads
                        when LDA => RegA <= op8; checkFlagsNZ := '1';
                        when LDY => RegY <= op8; checkFlagsNZ := '1';
                        when LDX => RegX <= op8; checkFlagsNZ := '1';
                        when LDS => RegS <= op8; 
                        when LDP => 
                           FlagNeg <= op8(7);
                           FlagOvf <= op8(6);
                           FlagBrk <= op8(4);
                           FlagDez <= op8(3);
                           FlagIrq <= op8(2);
                           FlagZer <= op8(1);
                           FlagCar <= op8(0);
                     
                        -- ALU
                        when ORA   => calcresult := RegA or  op8; RegA <= calcresult; checkFlagsNZ := '1';
                        when OPAND => calcresult := RegA and op8; RegA <= calcresult; checkFlagsNZ := '1';
                        when EOR   => calcresult := RegA xor op8; RegA <= calcresult; checkFlagsNZ := '1';
                     
                        when ASL => 
                           FlagCar <= op8(7); 
                           calcresult := op8(6 downto 0) & '0'; 
                           checkFlagsNZ := '1'; 
                           op8 <= calcresult;
                           if (addressmode = accu) then RegA <= calcresult;
                           else writeback := '1'; end if; 
                        when OPROL => 
                           FlagCar <= op8(7); 
                           calcresult := op8(6 downto 0) & FlagCar; 
                           checkFlagsNZ := '1';
                           op8 <= calcresult;
                           if (addressmode = accu) then RegA <= calcresult;
                           else writeback := '1'; end if;
                        when LSR =>
                           FlagCar <= op8(0); 
                           calcresult := '0' & op8(7 downto 1); 
                           checkFlagsNZ := '1';
                           op8 <= calcresult;
                           if (addressmode = accu) then RegA <= calcresult;
                           else writeback := '1'; end if;
                        when OPROR => 
                           FlagCar <= op8(0); 
                           calcresult := FlagCar & op8(7 downto 1);
                           checkFlagsNZ := '1';
                           op8 <= calcresult;
                           if (addressmode = accu) then RegA <= calcresult;
                           else writeback := '1'; end if;
                        
                        when DEC => 
                           calcresult := op8 - 1; 
                           checkFlagsNZ := '1'; 
                           op8 <= calcresult;
                           writeback := '1';
                           
                        when INC => 
                           calcresult := op8 + 1;
                           checkFlagsNZ := '1';
                           op8 <= calcresult;                           
                           writeback := '1';
                     
                        when TSB => 
                           if ((op8 and RegA) = 0) then FlagZer <= '1'; else FlagZer <= '0'; end if;
                           calcresult := op8 or RegA;
                           op8 <= calcresult;
                           writeback := '1';
                           
                        when TRB => 
                           if ((op8 and RegA) = 0) then FlagZer <= '1'; else FlagZer <= '0'; end if;
                           calcresult := op8 and (not RegA); 
                           op8 <= calcresult;
                           writeback := '1';
                     
                        when ADC => 
                           if (FlagDez = '1') then
                              rlow := resize(RegA(3 downto 0), 5) + resize(op8(3 downto 0), 5);
                              if (FlagCar = '1') then rlow := rlow + 1; end if;
                              rhigh := resize(RegA(7 downto 4), 5) + resize(op8(7 downto 4), 5);
                              if (rlow > 9) then
                                 rhigh := rhigh + 1;
                                 rlow := rlow + 6;
                              end if;
                              if ((not (RegA(7) xor op8(7)) and (RegA(7) xor rhigh(3))) = '1') then FlagOvf <= '1'; else FlagOvf <= '0'; end if;
                              if (rhigh > 9) then rhigh := rhigh + 6; end if;
                              FlagCar <= rhigh(4);
                              calcresult := rhigh(3 downto 0) & rlow(3 downto 0);
                              RegA <= calcresult;
                           else
                              result9 := resize(RegA, 9) + resize(op8, 9);
                              if (FlagCar = '1') then result9 := result9 + 1; end if;
                              if ((not (RegA(7) xor op8(7)) and (RegA(7) xor result9(7))) = '1') then FlagOvf <= '1'; else FlagOvf <= '0'; end if;
                              FlagCar <= result9(8);
                              RegA <= result9(7 downto 0);
                              calcresult := result9(7 downto 0);
                           end if;
                           checkFlagsNZ := '1';
                           
                        when SBC =>
                           if (FlagDez = '1') then
                              result9 := resize(RegA, 9) - resize(op8, 9);
                              if (FlagCar = '0') then result9 := result9 - 1; end if;
                              rlow := resize(RegA(3 downto 0), 5) - resize(op8(3 downto 0), 5);
                              if (FlagCar = '0') then rlow := rlow - 1; end if;
                              rhigh := resize(RegA(7 downto 4), 5) - resize(op8(7 downto 4), 5);
                              if (((RegA(7) xor op8(7)) and (RegA(7) xor result9(7))) = '1') then FlagOvf <= '1'; else FlagOvf <= '0'; end if;
                              if (rlow(4) = '1') then rlow := rlow - 6; end if;
                              if (rlow(4) = '1') then rhigh := rhigh - 1; end if;
                              if (rhigh(4) = '1') then rhigh := rhigh - 6; end if;
                              FlagCar <= not result9(8);
                              calcresult := rhigh(3 downto 0) & rlow(3 downto 0);
                              RegA <= calcresult;
                           else
                              result9 := resize(RegA, 9) - resize(op8, 9);
                              if (FlagCar = '0') then result9 := result9 - 1; end if;
                              if (((RegA(7) xor op8(7)) and (RegA(7) xor result9(7))) = '1') then FlagOvf <= '1'; else FlagOvf <= '0'; end if;
                              FlagCar <= not result9(8);
                              RegA <= result9(7 downto 0);
                              calcresult := result9(7 downto 0);
                           end if;
                           checkFlagsNZ := '1';
                           
                        when OPBIT =>
                           if (opcodebyte_last /= x"89") then -- Set to bit 6+7 of the memory value
                              FlagNeg <= op8(7);
                              FlagOvf <= op8(6);
                           end if;
                           if ((RegA and op8) = 0) then FlagZer <= '1'; else FlagZer <= '0'; end if;
                           
                        when COMPARE =>
                           if (opSecond >= op8) then FlagCar <= '1'; else FlagCar <= '0'; end if;
                           calcresult := opSecond - op8;
                           checkFlagsNZ := '1';
                           
                        -- branches
                        when BRANCH =>
                           if (branchtaken = '1') then
                              PC <= PC + unsigned(resize((signed(op8)), 16));
                           end if;
                           
                        when JMP =>
                           PC <= op16;
                           
                        when JSR =>
                           PC <= op16;
                           op16 <= PC - 1;
                           instructionStep <= 2;
                           addressmode <= stackpushdual;   
                           state <= calc;
                           opcode <= NOP;
                           cpu_done <= '0';
                           
                        when RTI =>
                           FlagNeg <= op8(7);
                           FlagOvf <= op8(6);
                           FlagBrk <= op8(4);
                           FlagDez <= op8(3);
                           FlagIrq <= op8(2);
                           FlagZer <= op8(1);
                           FlagCar <= op8(0);
                           addressmode <= stackpopdual; 
                           instructionStep <= 2; 
                           opcode <= JMP;
                           state <= calc;
                           cpu_done <= '0';
                           if (op8(4) = '0') then -- not FlagBrk
                              irqfinish <= '1';
                           end if;
                           
                        when RTS =>
                           PC <= op16 + 1;
                                 
                        when BRK =>
                           FlagDez <= '0';
                           FlagIrq <= '1';
                           instructionStep <= 1;
                           addressmode <= stackpush;
                           state <= calc;
                           cpu_done <= '0';
                           opcode <= IRQLOADPC;
                           op8 <= RegP or x"10";

                        when WRITEMEM =>
                           null;
                           
                        when IRQPUSH =>
                           state             <= calc;
                           opcode            <= IRQLOADPC;
                           cpu_done          <= '0';
                           addressmode       <= stackpush;             
                           instructionStep   <= 1;              
                           op8               <= RegP and x"EF";
                           FlagIrq           <= '1';
                           FlagDez           <= '0';
                           
                        when IRQLOADPC =>
                           PC                <= x"FFFE";
                           state             <= calc;
                           cpu_done          <= '0';
                           opcode            <= JMP;
                           addressmode       <= absolute;              
                           instructionStep   <= 3;  
                           
                        when others => null;
                           
                     end case;
                     
                     if (checkFlagsNZ = '1') then
                        if (calcresult = 0) then FlagZer <= '1'; else FlagZer <= '0'; end if;
                        FlagNeg <= calcresult(7);
                     end if;
                  
                     if (writeback = '1') then
                        opcode        <= WRITEMEM;
                        state         <= MEMWRITE;
                        cpu_done      <= '0';
                        bus_request   <= '1';
                        bus_addr      <= addrLast;
                        bus_datawrite <= std_logic_vector(calcresult);
                        bus_rnw       <= '0';
                     end if;
                  
                  end if;
                  
               when MEMWRITE =>
                  if (bus_done = '1') then
                     state <= CALC;
                     if (instructionStep > 0) then
                        instructionStep <= instructionStep - 1;
                     end if;
                  end if;
                  
               when MEMREAD =>
                  if (bus_done = '1') then
                     state <= CALC;
                     if (instructionStep > 0) then
                        instructionStep <= instructionStep - 1;
                     end if;

                     case (addressmode) is
                     
                        when immediate =>
                           if (instructionStep = 1) then op8 <= unsigned(bus_dataread); end if;
                  
                        when absolute | absoluteX | absoluteY =>
                           if (instructionStep = 3) then op16(7 downto 0)  <= unsigned(bus_dataread); end if;
                           if (instructionStep = 2) then 
                              op16(15 downto 8) <= unsigned(bus_dataread); 
                              if (opcode = JMP or opcode = JSR) then instructionStep <= 0; end if;
                           end if;
                           if (instructionStep = 1) then op8 <= unsigned(bus_dataread); end if;
                  
                        when absoluteIndirect =>
                           if (instructionStep = 4) then addrJMP(7 downto 0)  <= unsigned(bus_dataread); end if;
                           if (instructionStep = 3) then addrJMP(15 downto 8) <= unsigned(bus_dataread); end if;
                           if (instructionStep = 2) then op16(7 downto 0)  <= unsigned(bus_dataread); end if;
                           if (instructionStep = 1) then op16(15 downto 8) <= unsigned(bus_dataread); end if;
                           
                        
                        when absoluteIndexIndirect =>
                           if (instructionStep = 4) then addrJMP(7 downto 0)  <= unsigned(bus_dataread); end if;
                           if (instructionStep = 3) then addrJMP <= (unsigned(bus_dataread) & addrJMP(7 downto 0)) + RegX; end if;
                           if (instructionStep = 2) then op16(7 downto 0)  <= unsigned(bus_dataread); end if;
                           if (instructionStep = 1) then op16(15 downto 8) <= unsigned(bus_dataread); end if;
                           
                        when stackpop =>
                           op8 <= unsigned(bus_dataread);
                  
                        when stackpopdual =>
                           if (instructionStep = 2) then op16(7 downto 0)  <= unsigned(bus_dataread); end if;
                           if (instructionStep = 1) then op16(15 downto 8) <= unsigned(bus_dataread); end if;
                  
                        when zeropage | zeropageX | zeropageY =>
                           if (instructionStep = 2) then addrZP <= unsigned(bus_dataread); end if;
                           if (instructionStep = 1) then op8 <= unsigned(bus_dataread); end if;

                        when zeropageXAddr =>
                           if (instructionStep = 4) then addrZP <= unsigned(bus_dataread) + RegX; end if;
                           if (instructionStep = 3) then op16(7 downto 0)  <= unsigned(bus_dataread); end if;
                           if (instructionStep = 2) then op16(15 downto 8) <= unsigned(bus_dataread); end if;
                           if (instructionStep = 1) then op8 <= unsigned(bus_dataread); end if;
                  
                        when zeropageIndirect | zeropageYIndirect =>
                           if (instructionStep = 4) then addrZP <= unsigned(bus_dataread); end if;
                           if (instructionStep = 3) then op16(7 downto 0)  <= unsigned(bus_dataread); end if;
                           if (instructionStep = 2) then op16(15 downto 8) <= unsigned(bus_dataread); end if;
                           if (instructionStep = 1) then op8 <= unsigned(bus_dataread); end if;
                          
                        when others => null; -- store codes
                  
                     end case;   
                     
                  end if;
         
            end case;
         
         
         end if;
      end if;
   end process;

   cpu_export.PC              <= PC;             
   cpu_export.RegA            <= RegA;           
   cpu_export.RegX            <= RegX;           
   cpu_export.RegY            <= RegY;           
   cpu_export.RegS            <= RegS;           
   cpu_export.RegP            <= RegP;           
   cpu_export.FlagNeg         <= FlagNeg;        
   cpu_export.FlagOvf         <= FlagOvf;        
   cpu_export.FlagBrk         <= FlagBrk;        
   cpu_export.FlagDez         <= FlagDez;        
   cpu_export.FlagIrq         <= FlagIrq;        
   cpu_export.FlagZer         <= FlagZer;        
   cpu_export.FlagCar         <= FlagCar;        
   cpu_export.sleep           <= sleep;          
   cpu_export.irqrequest      <= irqrequest or irqrequest_in;     
   cpu_export.opcodebyte_last <= opcodebyte_last;

end architecture;












