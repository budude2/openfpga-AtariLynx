`default_nettype none

module core_top (

  //
  // physical connections
  //

  ///////////////////////////////////////////////////
  // clock inputs 74.25mhz. not phase aligned, so treat these domains as asynchronous

  input   wire            clk_74a, // mainclk1
  input   wire            clk_74b, // mainclk1 

  ///////////////////////////////////////////////////
  // cartridge interface
  // switches between 3.3v and 5v mechanically
  // output enable for multibit translators controlled by pic32

  // GBA AD[15:8]
  inout   wire    [7:0]   cart_tran_bank2,
  output  wire            cart_tran_bank2_dir,

  // GBA AD[7:0]
  inout   wire    [7:0]   cart_tran_bank3,
  output  wire            cart_tran_bank3_dir,

  // GBA A[23:16]
  inout   wire    [7:0]   cart_tran_bank1,
  output  wire            cart_tran_bank1_dir,

  // GBA [7] PHI#
  // GBA [6] WR#
  // GBA [5] RD#
  // GBA [4] CS1#/CS#
  //     [3:0] unwired
  inout   wire    [7:4]   cart_tran_bank0,
  output  wire            cart_tran_bank0_dir,

  // GBA CS2#/RES#
  inout   wire            cart_tran_pin30,
  output  wire            cart_tran_pin30_dir,
  // when GBC cart is inserted, this signal when low or weak will pull GBC /RES low with a special circuit
  // the goal is that when unconfigured, the FPGA weak pullups won't interfere.
  // thus, if GBC cart is inserted, FPGA must drive this high in order to let the level translators
  // and general IO drive this pin.
  output  wire            cart_pin30_pwroff_reset,

  // GBA IRQ/DRQ
  inout   wire            cart_tran_pin31,
  output  wire            cart_tran_pin31_dir,

  // infrared
  input   wire            port_ir_rx,
  output  wire            port_ir_tx,
  output  wire            port_ir_rx_disable, 

  // GBA link port
  inout   wire            port_tran_si,
  output  wire            port_tran_si_dir,
  inout   wire            port_tran_so,
  output  wire            port_tran_so_dir,
  inout   wire            port_tran_sck,
  output  wire            port_tran_sck_dir,
  inout   wire            port_tran_sd,
  output  wire            port_tran_sd_dir,
   
  ///////////////////////////////////////////////////
  // cellular psram 0 and 1, two chips (64mbit x2 dual die per chip)

  output  wire    [21:16] cram0_a,
  inout   wire    [15:0]  cram0_dq,
  input   wire            cram0_wait,
  output  wire            cram0_clk,
  output  wire            cram0_adv_n,
  output  wire            cram0_cre,
  output  wire            cram0_ce0_n,
  output  wire            cram0_ce1_n,
  output  wire            cram0_oe_n,
  output  wire            cram0_we_n,
  output  wire            cram0_ub_n,
  output  wire            cram0_lb_n,

  output  wire    [21:16] cram1_a,
  inout   wire    [15:0]  cram1_dq,
  input   wire            cram1_wait,
  output  wire            cram1_clk,
  output  wire            cram1_adv_n,
  output  wire            cram1_cre,
  output  wire            cram1_ce0_n,
  output  wire            cram1_ce1_n,
  output  wire            cram1_oe_n,
  output  wire            cram1_we_n,
  output  wire            cram1_ub_n,
  output  wire            cram1_lb_n,

  ///////////////////////////////////////////////////
  // sdram, 512mbit 16bit

  output  wire    [12:0]  dram_a,
  output  wire    [1:0]   dram_ba,
  inout   wire    [15:0]  dram_dq,
  output  wire    [1:0]   dram_dqm,
  output  wire            dram_clk,
  output  wire            dram_cke,
  output  wire            dram_ras_n,
  output  wire            dram_cas_n,
  output  wire            dram_we_n,

  ///////////////////////////////////////////////////
  // sram, 1mbit 16bit

  output  wire    [16:0]  sram_a,
  inout   wire    [15:0]  sram_dq,
  output  wire            sram_oe_n,
  output  wire            sram_we_n,
  output  wire            sram_ub_n,
  output  wire            sram_lb_n,

  ///////////////////////////////////////////////////
  // vblank driven by dock for sync in a certain mode

  input   wire            vblank,

  ///////////////////////////////////////////////////
  // i/o to 6515D breakout usb uart

  output  wire            dbg_tx,
  input   wire            dbg_rx,

  ///////////////////////////////////////////////////
  // i/o pads near jtag connector user can solder to

  output  wire            user1,
  input   wire            user2,

  ///////////////////////////////////////////////////
  // RFU internal i2c bus 

  inout   wire            aux_sda,
  output  wire            aux_scl,

  ///////////////////////////////////////////////////
  // RFU, do not use
  output  wire            vpll_feed,

  //
  // logical connections
  //

  ///////////////////////////////////////////////////
  // video, audio output to scaler
  output  wire    [23:0]  video_rgb,
  output  wire            video_rgb_clock,
  output  wire            video_rgb_clock_90,
  output  wire            video_de,
  output  wire            video_skip,
  output  wire            video_vs,
  output  wire            video_hs,
      
  output  wire            audio_mclk,
  input   wire            audio_adc,
  output  wire            audio_dac,
  output  wire            audio_lrck,

  ///////////////////////////////////////////////////
  // bridge bus connection
  // synchronous to clk_74a
  output  wire            bridge_endian_little,
  input   wire    [31:0]  bridge_addr,
  input   wire            bridge_rd,
  output  reg     [31:0]  bridge_rd_data,
  input   wire            bridge_wr,
  input   wire    [31:0]  bridge_wr_data,

  ///////////////////////////////////////////////////
  // controller data
  // 
  // key bitmap:
  //   [0]    dpad_up
  //   [1]    dpad_down
  //   [2]    dpad_left
  //   [3]    dpad_right
  //   [4]    face_a
  //   [5]    face_b
  //   [6]    face_x
  //   [7]    face_y
  //   [8]    trig_l1
  //   [9]    trig_r1
  //   [10]   trig_l2
  //   [11]   trig_r2
  //   [12]   trig_l3
  //   [13]   trig_r3
  //   [14]   face_select
  //   [15]   face_start
  //   [31:28] type
  // joy values - unsigned
  //   [ 7: 0] lstick_x
  //   [15: 8] lstick_y
  //   [23:16] rstick_x
  //   [31:24] rstick_y
  // trigger values - unsigned
  //   [ 7: 0] ltrig
  //   [15: 8] rtrig
  //
  input   wire    [31:0]  cont1_key,
  input   wire    [31:0]  cont2_key,
  input   wire    [31:0]  cont3_key,
  input   wire    [31:0]  cont4_key,
  input   wire    [31:0]  cont1_joy,
  input   wire    [31:0]  cont2_joy,
  input   wire    [31:0]  cont3_joy,
  input   wire    [31:0]  cont4_joy,
  input   wire    [15:0]  cont1_trig,
  input   wire    [15:0]  cont2_trig,
  input   wire    [15:0]  cont3_trig,
  input   wire    [15:0]  cont4_trig
);

// not using the IR port, so turn off both the LED, and
// disable the receive circuit to save power
assign port_ir_tx = 0;
assign port_ir_rx_disable = 1;

// bridge endianness
assign bridge_endian_little = 0;

// cart is unused, so set all level translators accordingly
// directions are 0:IN, 1:OUT
assign cart_tran_bank3[7:2]    = 6'hzz;
assign cart_tran_bank3[0]      = 1'hz;
assign cart_tran_bank3_dir     = 1'b1; // Set to output for rumble cart
assign cart_tran_bank2         = 8'hzz;
assign cart_tran_bank2_dir     = 1'b0;
assign cart_tran_bank1         = 8'hzz;
assign cart_tran_bank1_dir     = 1'b0;
assign cart_tran_bank0[7]      = 1'hz;
assign cart_tran_bank0[5:4]    = 2'hz;
assign cart_tran_bank0_dir     = 1'b1; // Set to output for rumble cart
assign cart_tran_pin30         = 1'b0; // reset or cs2, we let the hw control it by itself
assign cart_tran_pin30_dir     = 1'bz;
assign cart_pin30_pwroff_reset = 1'b0;  // hardware can control this
assign cart_tran_pin31         = 1'bz;      // input
assign cart_tran_pin31_dir     = 1'b0;  // input

assign port_tran_sd     = 1'bz;
assign port_tran_sd_dir = 1'b0;     // SD is input and not used
assign video_skip       = 1'b0;

// tie off the rest of the pins we are not using
assign cram0_a     = 'h0;
assign cram0_dq    = {16{1'bZ}};
assign cram0_clk   = 0;
assign cram0_adv_n = 1;
assign cram0_cre   = 0;
assign cram0_ce0_n = 1;
assign cram0_ce1_n = 1;
assign cram0_oe_n  = 1;
assign cram0_we_n  = 1;
assign cram0_ub_n  = 1;
assign cram0_lb_n  = 1;

assign cram1_a     = 'h0;
assign cram1_dq    = {16{1'bZ}};
assign cram1_clk   = 0;
assign cram1_adv_n = 1;
assign cram1_cre   = 0;
assign cram1_ce0_n = 1;
assign cram1_ce1_n = 1;
assign cram1_oe_n  = 1;
assign cram1_we_n  = 1;
assign cram1_ub_n  = 1;
assign cram1_lb_n  = 1;

assign sram_a      = 'h0;
assign sram_dq     = {16{1'bZ}};
assign sram_oe_n   = 1;
assign sram_we_n   = 1;
assign sram_ub_n   = 1;
assign sram_lb_n   = 1;

assign dbg_tx      = 1'bZ;
assign user1       = 1'bZ;
assign aux_scl     = 1'bZ;
assign vpll_feed   = 1'bZ;

//
// host/target command handler
//
wire            reset_n;                // driven by host commands, can be used as core-wide reset
wire    [31:0]  cmd_bridge_rd_data;
    
// bridge host commands
// synchronous to clk_74a
wire            status_boot_done  = pll_core_locked_s; 
wire            status_setup_done = pll_core_locked_s; // rising edge triggers a target command
wire            status_running    = reset_n;           // we are running as soon as reset_n goes high

wire            dataslot_requestread;
wire    [15:0]  dataslot_requestread_id;
wire            dataslot_requestread_ack = 1;
wire            dataslot_requestread_ok  = 1;

wire            dataslot_requestwrite;
wire    [15:0]  dataslot_requestwrite_id;
wire    [31:0]  dataslot_requestwrite_size;
wire            dataslot_requestwrite_ack = 1;
wire            dataslot_requestwrite_ok  = 1;

wire            dataslot_update;
wire    [15:0]  dataslot_update_id;
wire    [31:0]  dataslot_update_size;

wire            dataslot_allcomplete;

wire     [31:0] rtc_epoch_seconds;
wire     [31:0] rtc_date_bcd;
wire     [31:0] rtc_time_bcd;
wire            rtc_valid;

wire            savestate_supported   = 1;
wire    [31:0]  savestate_addr        = 32'h40000000;
wire    [31:0]  savestate_size        = 49968 + cart_ram_size_bytes; // 32768 + 16384 + 160 + 128 + 528 + cart_ram_size_bytes
wire    [31:0]  savestate_maxloadsize = savestate_size;

wire            savestate_start;
wire            savestate_start_ack;
wire            savestate_start_busy;
wire            savestate_start_ok;
wire            savestate_start_err;

wire            savestate_load;
wire            savestate_load_ack;
wire            savestate_load_busy;
wire            savestate_load_ok;
wire            savestate_load_err;

wire            osnotify_inmenu;

// bridge target commands
// synchronous to clk_74a

reg             target_dataslot_read;       
reg             target_dataslot_write;
reg             target_dataslot_getfile;    // require additional param/resp structs to be mapped
reg             target_dataslot_openfile;   // require additional param/resp structs to be mapped

wire            target_dataslot_ack;        
wire            target_dataslot_done;
wire    [2:0]   target_dataslot_err;

reg     [15:0]  target_dataslot_id;
reg     [31:0]  target_dataslot_slotoffset;
reg     [31:0]  target_dataslot_bridgeaddr;
reg     [31:0]  target_dataslot_length;

wire    [31:0]  target_buffer_param_struct; // to be mapped/implemented when using some Target commands
wire    [31:0]  target_buffer_resp_struct;  // to be mapped/implemented when using some Target commands
    
// bridge data slot access
// synchronous to clk_74a

wire    [9:0]   datatable_addr;
wire            datatable_wren;
wire    [31:0]  datatable_data;
wire    [31:0]  datatable_q;

wire            bw_en;

core_bridge_cmd icb (
  .clk                        ( clk_74a                    ),
  .reset_n                    ( reset_n                    ),

  .bridge_endian_little       ( bridge_endian_little       ),
  .bridge_addr                ( bridge_addr                ),
  .bridge_rd                  ( bridge_rd                  ),
  .bridge_rd_data             ( cmd_bridge_rd_data         ),
  .bridge_wr                  ( bridge_wr                  ),
  .bridge_wr_data             ( bridge_wr_data             ),
  
  .status_boot_done           ( status_boot_done           ),
  .status_setup_done          ( status_setup_done          ),
  .status_running             ( status_running             ),

  .dataslot_requestread       ( dataslot_requestread       ),
  .dataslot_requestread_id    ( dataslot_requestread_id    ),
  .dataslot_requestread_ack   ( dataslot_requestread_ack   ),
  .dataslot_requestread_ok    ( dataslot_requestread_ok    ),

  .dataslot_requestwrite      ( dataslot_requestwrite      ),
  .dataslot_requestwrite_id   ( dataslot_requestwrite_id   ),
  .dataslot_requestwrite_size ( dataslot_requestwrite_size ),
  .dataslot_requestwrite_ack  ( dataslot_requestwrite_ack  ),
  .dataslot_requestwrite_ok   ( dataslot_requestwrite_ok   ),

  .dataslot_update            ( dataslot_update            ),
  .dataslot_update_id         ( dataslot_update_id         ),
  .dataslot_update_size       ( dataslot_update_size       ),
  
  .dataslot_allcomplete       ( dataslot_allcomplete       ),

  .rtc_epoch_seconds          ( rtc_epoch_seconds          ),
  .rtc_date_bcd               ( rtc_date_bcd               ),
  .rtc_time_bcd               ( rtc_time_bcd               ),
  .rtc_valid                  ( rtc_valid                  ),
  
  .savestate_supported        ( savestate_supported        ),
  .savestate_addr             ( savestate_addr             ),
  .savestate_size             ( savestate_size             ),
  .savestate_maxloadsize      ( savestate_maxloadsize      ),

  .savestate_start            ( savestate_start            ),
  .savestate_start_ack        ( savestate_start_ack        ),
  .savestate_start_busy       ( savestate_start_busy       ),
  .savestate_start_ok         ( savestate_start_ok         ),
  .savestate_start_err        ( savestate_start_err        ),

  .savestate_load             ( savestate_load             ),
  .savestate_load_ack         ( savestate_load_ack         ),
  .savestate_load_busy        ( savestate_load_busy        ),
  .savestate_load_ok          ( savestate_load_ok          ),
  .savestate_load_err         ( savestate_load_err         ),

  .osnotify_inmenu            ( osnotify_inmenu            ),
  
  .target_dataslot_read       ( target_dataslot_read       ),
  .target_dataslot_write      ( target_dataslot_write      ),
  .target_dataslot_getfile    ( target_dataslot_getfile    ),
  .target_dataslot_openfile   ( target_dataslot_openfile   ),
  
  .target_dataslot_ack        ( target_dataslot_ack        ),
  .target_dataslot_done       ( target_dataslot_done       ),
  .target_dataslot_err        ( target_dataslot_err        ),

  .target_dataslot_id         ( target_dataslot_id         ),
  .target_dataslot_slotoffset ( target_dataslot_slotoffset ),
  .target_dataslot_bridgeaddr ( target_dataslot_bridgeaddr ),
  .target_dataslot_length     ( target_dataslot_length     ),

  .target_buffer_param_struct ( target_buffer_param_struct ),
  .target_buffer_resp_struct  ( target_buffer_resp_struct  ),
  
  .datatable_addr             ( datatable_addr             ),
  .datatable_wren             ( datatable_wren             ),
  .datatable_data             ( datatable_data             ),
  .datatable_q                ( datatable_q                ),

  .bw_en                      ( bw_en                      )

);

//! ------------------------------------------------------------------------
//! Reset Handler (Thanks boogerman!)
//! ------------------------------------------------------------------------
reg  [31:0] reset_counter;
reg         reset_timer;
reg         core_reset   = 0;

always_ff @(posedge clk_74a) begin
  if(reset_timer) begin
    reset_counter <= 32'd8000;
    core_reset    <= 0;
  end
  else begin
    if (reset_counter == 32'h0) begin
      core_reset <= 0;
    end
    else begin
      reset_counter <= reset_counter - 1;
      core_reset    <= 1;
    end
  end
end

// for bridge write data, we just broadcast it to all bus devices
// for bridge read data, we have to mux it
// add your own devices here
always_comb begin
  casex(bridge_addr)
    32'h2xxxxxxx: begin bridge_rd_data = save_rd_data;                end
    32'h4xxxxxxx: begin bridge_rd_data = save_state_bridge_read_data; end
    32'hF8xxxxxx: begin bridge_rd_data = cmd_bridge_rd_data;          end
    32'hF1000000: begin bridge_rd_data = int_bridge_read_data;        end
    32'hF2000000: begin bridge_rd_data = int_bridge_read_data;        end
    default:      begin bridge_rd_data = 0;                           end
  endcase
end

reg [31:0] boot_settings = 32'h0;
reg [31:0] run_settings  = 32'h0;
logic [31:0] int_bridge_read_data;

always_ff @(posedge clk_74a) begin
  reset_timer <= 0; //! Always default this to zero

  if(bridge_wr) begin
    case (bridge_addr)
      32'hF0000000: begin /*         RESET ONLY          */ reset_timer <= 1; end //! Reset Core Command
      32'hF1000000: begin boot_settings  <= bridge_wr_data; reset_timer <= 1; end //! System Settings
      32'hF2000000: begin run_settings   <= bridge_wr_data;                   end //! Runtime settings
    endcase
  end

  if(bridge_rd) begin
    case (bridge_addr)
      32'hF1000000: begin int_bridge_read_data  <= boot_settings;  end //! System Settings
      32'hF2000000: begin int_bridge_read_data  <= run_settings;   end //! Runtime settings
    endcase
  end
end

logic clk_sys, clk_ram, clk_ram_90, clk_vid, clk_vid_90;
logic pll_core_locked, pll_core_locked_s, reset_n_s, external_reset_s;
logic [31:0] cont1_key_s, cont2_key_s, cont3_key_s, cont4_key_s;
logic [31:0] boot_settings_s, run_settings_s;

synch_3               s01 (pll_core_locked, pll_core_locked_s,  clk_ram);
synch_3               s02 (reset_n,         reset_n_s,          clk_sys);
synch_3               s03 (core_reset,      external_reset_s,   clk_sys);
synch_3 #(.WIDTH(32)) s04 (cont1_key,       cont1_key_s,        clk_sys);
synch_3 #(.WIDTH(32)) s05 (cont2_key,       cont2_key_s,        clk_sys);
synch_3 #(.WIDTH(32)) s06 (cont3_key,       cont3_key_s,        clk_sys);
synch_3 #(.WIDTH(32)) s07 (cont4_key,       cont4_key_s,        clk_sys);
synch_3 #(.WIDTH(32)) s08 (boot_settings,   boot_settings_s,    clk_sys);
synch_3 #(.WIDTH(32)) s09 (run_settings,    run_settings_s,     clk_sys);

logic sgb_en, rumble_en, originalcolors, ff_snd_en, ff_en, sgb_border_en, gba_en;
logic [1:0] tint;

always_comb begin
  // These settings trigger a reset
  sgb_en         = boot_settings_s[0];
  gba_en         = boot_settings_s[1];

  // These settings don't
  rumble_en      = run_settings_s[0];
  originalcolors = run_settings_s[1];
  ff_snd_en      = run_settings_s[2];
  ff_en          = run_settings_s[3];
  sgb_border_en  = run_settings_s[4];
  tint           = run_settings_s[6:5];
end

mf_pllbase mp1
(
  .refclk   ( clk_74a         ),
  .rst      ( 0               ),
  
  .outclk_0 ( clk_ram         ),
  .outclk_1 ( clk_sys         ),
  .outclk_2 ( clk_vid         ),
  .outclk_3 ( clk_vid_90      ),
  
  .locked   ( pll_core_locked )
);

data_loader #(
  .ADDRESS_MASK_UPPER_4   ( 4'h1  ),
  .OUTPUT_WORD_SIZE       ( 2     ),
  .WRITE_MEM_CLOCK_DELAY  ( 20    )
) data_loader (
  .clk_74a              ( clk_74a               ),
  .clk_memory           ( clk_sys               ),

  .bridge_wr            ( bridge_wr             ),
  .bridge_endian_little ( bridge_endian_little  ),
  .bridge_addr          ( bridge_addr           ),
  .bridge_wr_data       ( bridge_wr_data        ),

  .write_en             ( ioctl_wr              ),
  .write_addr           ( ioctl_addr            ),
  .write_data           ( ioctl_dout            )
);

reg ioctl_download = 0;

always_ff @(posedge clk_74a) begin
  if      (dataslot_requestwrite) ioctl_download <= 1;
  else if (dataslot_allcomplete)  ioctl_download <= 0;
end

endmodule
