#0
#SITE_ID __UGPB_ISV_internal_use
set PB_version 3.3.0
if { ![info exists mom_sim_post_builder_version] || \
 [string compare "$PB_version" $mom_sim_post_builder_version] > 0 } {
 set __msg "ERROR :\n\
 \nThe VNC needs to be created with Post Builder v$PB_version or newer\
 \nin order to work with \"vnc_base_v330_tcl.txt\"!"
 catch { SIM_mtd_reset }
 MOM_abort $__msg
}
set mom_sim_vnc_base_version $PB_version
if { ![info exists sim_mtd_initialized] } {
 set sim_mtd_initialized 0
}
if { $sim_mtd_initialized == 0 } {
 source "[MOM_ask_env_var UGII_CAM_POST_DIR]sim_high_level_sv_commands.tcl"
 set sim_prev_tool_name "undefined"
 set sim_prev_zcs "undefined"
 set sim_feedrate_mode  "RAPID"
 if { ![info exists mom_sim_vnc_msg_only] || !$mom_sim_vnc_msg_only } {
  if [llength [info commands "MOM_before_output_save"]] {
   rename MOM_before_output_save ""
  }
  if [llength [info commands "MOM_before_output"]] {
   rename MOM_before_output MOM_before_output_save
   } else {

#=======================================================================
proc MOM_before_output_save {} {}
}

#=======================================================================
proc MOM_before_output {} {
  global mom_sim_csys_set
  global mom_sim_buffer
  global mom_sim_message
  MOM_before_output_save
  global mom_o_buffer
  global mom_sim_o_buffer
  if 0 {
   global mom_sim_prev_o_buffer
   if [info exists mom_sim_prev_o_buffer] {
    set mom_sim_o_buffer $mom_sim_prev_o_buffer
    } else {
    set mom_sim_o_buffer ""
   }
   set mom_sim_prev_o_buffer $mom_o_buffer
   } else {
   set mom_sim_o_buffer $mom_o_buffer
  }
  lappend mom_sim_buffer $mom_sim_o_buffer
  if $mom_sim_csys_set {
   if { ![info exists mom_sim_buffer] } {
    set mom_sim_message "> $mom_sim_o_buffer"
    PB_CMD_vnc__send_message
    VNC_sim_nc_block $mom_sim_o_buffer
    } else {
    foreach mom_sim_o_buffer $mom_sim_buffer {
     set mom_sim_message "> $mom_sim_o_buffer"
     PB_CMD_vnc__send_message
     VNC_sim_nc_block $mom_sim_o_buffer
    }
    unset mom_sim_buffer
   }
   } else {
   set mom_sim_message ">  buffered block:$mom_sim_o_buffer"
   PB_CMD_vnc__send_message
   VNC_sim_nc_block $mom_sim_o_buffer
  }
 }
} ;# mom_sim_vnc_msg_only

#=======================================================================
proc PB_VNC_sync { } {
  if [llength [info commands "PB_CMD_vnc__sync"]] {
   PB_CMD_vnc__sync
  }
 }

#=======================================================================
proc PB_sim_debug_msg { args } {
  PB_VNC_output_debug_msg $args
 }

#=======================================================================
proc PB_VNC_output_debug_msg { args } {
  global mom_sim_isv_debug
  global mom_sim_isv_debug_msg_file
  if { ![info exists mom_sim_isv_debug_msg_file] || \
   [string match "" [string trim $mom_sim_isv_debug_msg_file]] } {
   return
  }
  set proc_name "[lindex [info level -2] 0] [lindex [info level -1] 0]"
  if [string match "listing_device" $mom_sim_isv_debug_msg_file] {
   if [llength [info commands "MOM_output_to_listing_device"]] {
    if [llength $args] {
     set str [format "%-60s %s" "\[$proc_name\]" ">[join $args]<"]
     } else {
     set str [format "%-60s" "\[$proc_name\]"]
    }
    MOM_output_to_listing_device $str
   }
   return
  }
  if { ![info exists mom_sim_isv_debug] } {
   if [catch {set mom_sim_isv_debug [open "$mom_sim_isv_debug_msg_file" w]} ] {
    return
   }
  }
  if [llength $args] {
   puts $mom_sim_isv_debug "\[$proc_name\] >[join $args]<"
   } else {
   puts $mom_sim_isv_debug "\[$proc_name\]"
  }
  flush $mom_sim_isv_debug
 }

#=======================================================================
proc VNC_sim_nc_block { block_buffer } {
  global mom_sim_control_out mom_sim_control_in
  global mom_sim_word_separator mom_sim_word_separator_len
  global mom_sim_end_of_block mom_sim_end_of_block_len
  global mom_sim_address
  global mom_sim_pos mom_sim_prev_pos
  global mom_sim_nc_register
  global mom_sim_tool_junction
  global mom_sim_message
  global mom_sim_csys_set
  if { ![info exists block_buffer] } {
   return
  }
  if 0 {
   set o_buff [string trim $block_buffer]
   set blk_len [string length $o_buff]
   if { $mom_sim_end_of_block_len > 0 } {
    set end_idx [expr $blk_len - $mom_sim_end_of_block_len]
    set o_buff [string range $o_buff 0 $end_idx]
   }
   } else {
   set o_buff $block_buffer
   set blk_len [string length $o_buff]
   if { $mom_sim_end_of_block_len > 0 } {
    set end_idx [expr $blk_len - 1 - $mom_sim_end_of_block_len]
    set o_buff [string range $o_buff 0 $end_idx]
   }
  }
  if [string match "" [string trim $o_buff]] {
   return
  }
  set pat "^$mom_sim_address(N,leader)\[0-9\]*\[\.\]?\[0-9\]*"
  set cmd [concat regexp -indices \{$pat\} \$o_buff match]
  if { [eval $cmd] == 1 } {
   if { [lindex $match 0] == 0 } {
    set next_idx [expr [lindex $match 1] + $mom_sim_word_separator_len + 1]
    set o_buff [string range $o_buff $next_idx end]
   }
  }
  if [string match "" [string trim $o_buff]] {
   return
  }
  global mom_sim_control_var_leader
  if { ![string match "" $mom_sim_control_var_leader] } {
   set pat "^$mom_sim_control_var_leader\[0-9\]*\[\=\]?\[0-9\]*\[\.,\]?\[0-9\]*"
   set cmd [concat regexp -indices \{$pat\} \$o_buff match]
   if { [eval $cmd] == 1 } {
    set word_list [split $o_buff =]
    set var [lindex $word_list 0]
    set val [lindex $word_list 1]
    set mom_sim_nc_register($var) $val
    return
   }
  }
  set out_len [string length $mom_sim_control_out]
  set in_len  [string length $mom_sim_control_in]
  set vnc_msg 0
  if { $out_len > 0 && $in_len > 0 } {
   if { [string first "$mom_sim_control_out" $o_buff] == 0 && \
    [string last "$mom_sim_control_in" $o_buff] > 0 } {
    set vnc_msg 1
   }
   } elseif { $out_len > 0 } {
   if { [string first "$mom_sim_control_out" $o_buff] == 0 } {
    set vnc_msg 1
   }
  }
  if $vnc_msg {
   set o_buff [string range $o_buff $out_len end]
   set o_buff [string range $o_buff 0 [expr [string length $o_buff] - $in_len - 1]]
   set o_buff [string trim $o_buff]
   global mom_sim_vnc_msg_prefix
   if [info exists mom_sim_vnc_msg_prefix] {
    if [string match "$mom_sim_vnc_msg_prefix*" $o_buff] {
     set len [string length "$mom_sim_vnc_msg_prefix"]
     set o_buff [string range $o_buff $len end]
     set o_buff [string trim $o_buff]
    }
   }
   set idx [string first "==" $o_buff]
   if { $idx > 0 } {
    set key [string range $o_buff 0 [expr $idx - 1]]
    set word [string range $o_buff [expr $idx + 2] end]
    set word [string trim $word \"]
    VNC_set_param_per_msg $key $word
   }
   } else {
   global mom_sim_o_buffer
   set mom_sim_o_buffer $o_buff
   global mom_sim_motion_begun
   if { ![info exists mom_sim_motion_begun] } {
    set mom_sim_motion_begun 0
   }
   if { $mom_sim_csys_set == 0 } {
    return
   }
   PB_CMD_vnc__G_mode_code
   set mom_sim_nc_register(RETURN_HOME) 0
   set mom_sim_nc_register(FROM_HOME)   0
   set mom_sim_nc_register(SET_LOCAL)   0
   set mom_sim_nc_register(MCS_MOVE)    0
   set mom_sim_nc_register(RESET_WCS)   0
   PB_CMD_vnc__G_misc_code
   PB_CMD_vnc__G_plane_code
   PB_CMD_vnc__G_adjust_code
   for {set i 0} {$i < 8} {incr i} {
    set mom_sim_prev_pos($i) $mom_sim_pos($i)
   }
   set simulate_block [VNC_parse_motion_word $o_buff]
   if { $mom_sim_nc_register(MCS_MOVE) && \
    [string match "ABS" $mom_sim_nc_register(INPUT)] } {
    set mom_sim_nc_register(WORK_OFFSET) [list]
    global mom_sim_wcs_offsets
    foreach coord $mom_sim_wcs_offsets($mom_sim_nc_register(WCS)) {
     lappend mom_sim_nc_register(WORK_OFFSET) $coord
    }
   }
   if $mom_sim_nc_register(SET_LOCAL) {
    if 0 {
     set mom_sim_nc_register(LOCAL_OFFSET) [list]
     for {set i 0} {$i < 5} {incr i} {
      lappend mom_sim_nc_register(LOCAL_OFFSET) $mom_sim_pos($i)
     }
    }
    global mom_sim_offset_pt
    for {set i 0} {$i < 5} {incr i} {
     if [info exists mom_sim_offset_pt($i)] {
      set mom_sim_nc_register(LOCAL_OFFSET) \
      [lreplace $mom_sim_nc_register(LOCAL_OFFSET) $i $i $mom_sim_offset_pt($i)]
     }
    }
    set simulate_block 0
   }
   if $mom_sim_nc_register(RESET_WCS) {
    if [llength [info commands "PB_CMD_vnc__reset_coordinate"]] {
     PB_CMD_vnc__reset_coordinate
     } else {
     global mom_sim_offset_pt
     set mom_sim_message " Local Offset before : $mom_sim_nc_register(LOCAL_OFFSET)"
     PB_CMD_vnc__send_message
     if [info exists mom_sim_offset_pt] {
      set mom_sim_message "   offset pt : [array get mom_sim_offset_pt]"
      PB_CMD_vnc__send_message
     }
     for {set i 0} {$i < 5} {incr i} {
      if [info exists mom_sim_offset_pt($i)] {
       if $mom_sim_motion_begun {
        set coord $mom_sim_prev_pos($i)
        set offset [expr $mom_sim_offset_pt($i) - $coord]
        set mom_sim_nc_register(LOCAL_OFFSET) \
        [lreplace $mom_sim_nc_register(LOCAL_OFFSET) $i $i $offset]
       }
      }
     }
     set mom_sim_message " Local Offset after : $mom_sim_nc_register(LOCAL_OFFSET)"
     PB_CMD_vnc__send_message
    }
    set simulate_block 0
   }
   if $mom_sim_nc_register(RETURN_HOME) {
    PB_CMD_vnc__return_home
    set simulate_block 0
   }
   if $mom_sim_nc_register(FROM_HOME) {
    PB_CMD_vnc__from_home
    set simulate_block 0
   }
   PB_CMD_vnc__M_misc_code
   PB_CMD_vnc__G_motion_code
   if [string match "CYCLE_*" $mom_sim_nc_register(MOTION)] {
    set simulate_block 1
   }
   PB_CMD_vnc__G_feed_code
   PB_CMD_vnc__G_spin_code
   PB_CMD_vnc__M_spindle_code
   PB_CMD_vnc__M_coolant_code
   global mom_sim_other_nc_codes
   global mom_sim_simulate_block
   set mom_sim_simulate_block $simulate_block
   if [llength [info commands "PB_CMD_vnc__sim_other_devices"]] {
    set cb_cmd "PB_CMD_vnc__sim_other_devices"
    } elseif [llength [info commands "PB_CMD_vnc____sim_other_devices"]] {
    set cb_cmd "PB_CMD_vnc____sim_other_devices"
    } else {
    set cb_cmd ""
   }
   foreach code $mom_sim_other_nc_codes {
    VNC_parse_nc_block block_buffer $code $cb_cmd
   }
   if { $mom_sim_simulate_block == 0 } {
    set simulate_block 0
   }
   if { $simulate_block } {
    PB_CMD_vnc__sim_motion
    set mom_sim_motion_begun 1
    } else {
   }
   global mom_sim_prog_rewind_stop_code
   if { [info exists mom_sim_prog_rewind_stop_code] && \
    ![string match "" $mom_sim_prog_rewind_stop_code] } {
    VNC_parse_nc_block o_buff $mom_sim_prog_rewind_stop_code VNC_rewind_stop_program
   }
  }
 }

#=======================================================================
proc PB_VNC_init_sim_vars {} {
  global mom_sim_nc_register
  global mom_sim_control_var_leader
  set mom_sim_control_var_leader    ""
  PB_CMD_vnc__init_sim_vars
  global mom_sim_vnc_msg_only
  if { [info exists mom_sim_vnc_msg_only] && $mom_sim_vnc_msg_only } {
   return
  }
  global mom_sim_current_junction
  if { ![info exists mom_sim_current_junction] } {
   VNC_set_ref_jct ""
  }
  global mom_sim_prev_o_buffer
  if [info exists mom_sim_prev_o_buffer] {
   unset mom_sim_prev_o_buffer
  }
  if 0 {
   global mom_sim_output_unit
   set mom_sim_nc_register(UNIT)           $mom_sim_output_unit
   set mom_sim_nc_register(DEF_UNIT)       $mom_sim_nc_register(UNIT)
   if { $mom_sim_nc_register(UNIT) == "MM" } {
    SIM_set_mtd_units "MM"
    } else {
    SIM_set_mtd_units "INCH"
   }
  }
  if [info exists mom_sim_nc_register(REF_INT_PT_X)] {
   unset mom_sim_nc_register(REF_INT_PT_X)
  }
  if [info exists mom_sim_nc_register(REF_INT_PT_Y)] {
   unset mom_sim_nc_register(REF_INT_PT_Y)
  }
  if [info exists mom_sim_nc_register(REF_INT_PT_Z)] {
   unset mom_sim_nc_register(REF_INT_PT_Z)
  }
  if [info exists mom_sim_nc_register(REF_INT_PT_4)] {
   unset mom_sim_nc_register(REF_INT_PT_4)
  }
  if [info exists mom_sim_nc_register(REF_INT_PT_5)] {
   unset mom_sim_nc_register(REF_INT_PT_5)
  }
  global mom_sim_home_pos
  if { ![info exists mom_sim_nc_register(REF_PT)] } {
   lappend mom_sim_nc_register(REF_PT) $mom_sim_home_pos(0) \
   $mom_sim_home_pos(1) \
   $mom_sim_home_pos(2) \
   0.0 0.0
  }
 }

#=======================================================================
proc VNC_reset_controller {} {
  PB_CMD_vnc__reset_controller
 }

#=======================================================================
proc PB_VNC_pass_csys_data {} {
  global mom_sim_zcs_base
  global mom_csys_matrix
  global mom_sim_result
  global mom_sim_csys_set
  if $mom_sim_csys_set {
   return
  }
  PB_CMD_vnc__pass_csys_data
 }

#=======================================================================
proc PB_VNC_pass_head_data {} {
  if [llength [info commands "PB_CMD_vnc__pass_head_data"]] {
   PB_CMD_vnc__pass_head_data
   } else {
   PB_CMD_vnc__pass_head_param
  }
 }

#=======================================================================
proc PB_VNC_pass_msys_data {} {
  global mom_sim_csys_set
  if $mom_sim_csys_set {
   return
  }
  PB_CMD_vnc__pass_msys_data
 }

#=======================================================================
proc PB_VNC_pass_tool_data {} {
  if [llength [info commands "PB_CMD_vnc__pass_tool_data"]] {
   PB_CMD_vnc__pass_tool_data
   } else {
   PB_CMD_vnc__pass_tool_param
  }
 }

#=======================================================================
proc PB_VNC_pass_spindle_data {} {
  if [llength [info commands "PB_CMD_vnc__pass_spindle_data"]] {
   PB_CMD_vnc__pass_spindle_data
  }
 }

#=======================================================================
proc VNC_set_param_per_msg { key word } {
  global mom_sim_msg_key mom_sim_msg_word
  set mom_sim_msg_key  $key
  set mom_sim_msg_word $word
  PB_CMD_vnc__set_param_per_msg
 }

#=======================================================================
proc VNC_create_tmp_jct {} {
  if [llength [info commands "PB_CMD_vnc__create_tmp_jct"]] {
   if { ![catch {PB_CMD_vnc__create_tmp_jct} ] } {
    return
   }
  }
  global mom_sim_tool_junction mom_sim_current_junction
  global mom_sim_curr_jct_matrix mom_sim_curr_jct_origin
  global mom_sim_tool_loaded
  if { ![string match "$mom_sim_tool_junction" "$mom_sim_current_junction"] } {
   global mom_sim_result
   global mom_sim_tmp_tool_jct_index
   if { ![info exists mom_sim_tmp_tool_jct_index] } {
    set mom_sim_tmp_tool_jct_index 0
   }
   SIM_ask_is_junction_exist __SIM_TMP_TOOL_JCT__$mom_sim_tmp_tool_jct_index
   if { $mom_sim_result == 1 } {
    incr mom_sim_tmp_tool_jct_index
   }
   set tmp_tool_jct "__SIM_TMP_TOOL_JCT__$mom_sim_tmp_tool_jct_index"
   eval SIM_create_junction $tmp_tool_jct $mom_sim_tool_loaded \
   $mom_sim_curr_jct_origin $mom_sim_curr_jct_matrix
   SIM_set_current_ref_junction $tmp_tool_jct
   set mom_sim_tool_junction $tmp_tool_jct
   set mom_sim_current_junction $mom_sim_tool_junction
   if { ![catch {set pos [SIM_ask_last_position_zcs]} ] } {
    global mom_sim_pos
    set mom_sim_pos(0) [lindex $pos 0]
    set mom_sim_pos(1) [lindex $pos 1]
    set mom_sim_pos(2) [lindex $pos 2]
   }
  }
 }

#=======================================================================
proc VNC_parse_motion_word { o_buff } {
  global mom_sim_address mom_sim_pos mom_sim_prev_pos
  global mom_sim_nc_register
  global mom_sim_message
  global mom_sim_x_double mom_sim_i_double
  global mom_sim_y_double mom_sim_j_double
  global mom_sim_x_factor mom_sim_y_factor mom_sim_z_factor
  global mom_sim_i_factor mom_sim_j_factor mom_sim_k_factor
  global mom_sim_incr_linear_addrs
  set addr_list {X Y Z fourth_axis fifth_axis I J K R K_cycle S F}
  if { ![info exists mom_sim_x_double] } {
   set mom_sim_x_double 1
  }
  if { ![info exists mom_sim_y_double] } {
   set mom_sim_y_double 1
  }
  if { ![info exists mom_sim_i_double] } {
   set mom_sim_i_double 1
  }
  if { ![info exists mom_sim_j_double] } {
   set mom_sim_j_double 1
  }
  if { ![info exists mom_sim_x_factor] } {
   set mom_sim_x_factor 1
  }
  if { ![info exists mom_sim_y_factor] } {
   set mom_sim_y_factor 1
  }
  if { ![info exists mom_sim_z_factor] } {
   set mom_sim_z_factor 1
  }
  if { ![info exists mom_sim_i_factor] } {
   set mom_sim_i_factor 1
  }
  if { ![info exists mom_sim_j_factor] } {
   set mom_sim_j_factor 1
  }
  if { ![info exists mom_sim_k_factor] } {
   set mom_sim_k_factor 1
  }
  global mom_sim_offset_pt
  if { $mom_sim_nc_register(SET_LOCAL) || \
   $mom_sim_nc_register(RESET_WCS) } {
   if [info exists mom_sim_offset_pt] {
    unset mom_sim_offset_pt
   }
  }
  set handle_incr_register 0
  if [info exists mom_sim_incr_linear_addrs] {
   set incr_addr_len [llength $mom_sim_incr_linear_addrs]
   if { $incr_addr_len > 0 } {
    set handle_incr_register 1
    set n1 [llength $addr_list]
    set n2 [expr $n1 + 1]
    set n3 [expr $n2 + 1]
    set n4 [expr $n3 + 1]
    set n5 [expr $n4 + 1]
    set addr_list [concat $addr_list $mom_sim_incr_linear_addrs]
   }
  }
  set simulate_block 0
  global mom_sim_pos_zcs
  set mom_sim_pos_zcs(0) $mom_sim_pos(0)
  set mom_sim_pos_zcs(1) $mom_sim_pos(1)
  set mom_sim_pos_zcs(2) $mom_sim_pos(2)
  set mom_sim_pos_zcs(3) $mom_sim_pos(3)
  set mom_sim_pos_zcs(4) $mom_sim_pos(4)
  global mom_sim_control_var_leader
  set i 0
  foreach addr $addr_list {
   if { ![info exists mom_sim_address($addr,leader)] } {
    set addr_leader [string trim $addr]
    if { [string length $addr_leader] == 1  &&  ![string match "-" $addr_leader] } {
     set mom_sim_address($addr,leader) $addr_leader
     } else {
     set mom_sim_message "Unknown Address \"$addr\" will not be processed!"
     PB_CMD_vnc__send_message
     incr i
     continue
    }
   }
   if [info exists mom_sim_address($addr,leader)] {
    if [string match "" $mom_sim_control_var_leader] {
     set pat "$mom_sim_address($addr,leader)\[-\+\]?\[0-9\]*\[\.,\]?\[0-9\]*"
     } else {
     set pat "$mom_sim_address($addr,leader)\[-\+\]?$mom_sim_control_var_leader?\[0-9\]*\[\.,\]?\[0-9\]*"
    }
    set cmd [concat regexp -indices \{$pat\} \$o_buff match]
    if { [eval $cmd] == 1 } {
     set idx [expr [lindex $match 0] + [string length $mom_sim_address($addr,leader)]]
     set val [string range $o_buff $idx [lindex $match 1]]
     set val [string trim $val]
     set val_is_negative 0
     if [string match "-*" $val] {
      set val [string trimleft $val -]
      set val_is_negative 1
      } elseif [string match "+*" $val] {
      set val [string trimleft $val +]
     }
     if { ![string match "" $mom_sim_control_var_leader] && \
      [string match "$mom_sim_control_var_leader*" $val] } {
      set val [string trimright $val .]
      set val $mom_sim_nc_register($val)
     }
     if [string match "*.*" $val] {
      set val [string trim $val 0]
      if [string match "." $val] {
       set val 0.0
      }
      } else {
      if [info exists mom_sim_address($addr,format)] {
       global mom_sim_format
       set fmt $mom_sim_address($addr,format)
       if { $mom_sim_format($fmt,lead_zero) == 0  && \
        $mom_sim_format($fmt,trail_zero) == 0 } {
        } else {
        set tmp_val [string trimleft $val 0]
        if [string match "" $tmp_val] {
         set val 0.0
         } else {
         if { $mom_sim_format($fmt,trail_zero) == 1 } {
          set n_frac $mom_sim_format($fmt,fraction)
          } elseif { $mom_sim_format($fmt,lead_zero) == 1 } {
          set frac [string range $val $mom_sim_format($fmt,integer) end]
          set n_frac [string length $frac]
         }
         set val [expr $tmp_val / pow(10,$n_frac)]
        }
       }
      } ;# Valid format
     } ;# No decimal point
     if [string match "" $val] {
      return 0
     }
     if $val_is_negative {
      set val [expr -1 * $val]
     }
     switch $addr {
      X {
       set val [expr $val * $mom_sim_x_factor / $mom_sim_x_double]
      }
      Y {
       set val [expr $val * $mom_sim_y_factor / $mom_sim_y_double]
      }
      Z {
       set val [expr $val * $mom_sim_z_factor]
      }
      I {
       set val [expr $val * $mom_sim_i_factor / $mom_sim_i_double]
      }
      J {
       set val [expr $val * $mom_sim_j_factor / $mom_sim_j_double]
      }
      K {
       set val [expr $val * $mom_sim_k_factor]
      }
     }
     set mom_sim_nc_register($addr) $val
     if { $addr == "I" ||  $addr == "J" || $addr == "K" || $addr == "R" } {
      set mom_sim_pos($i) $val
      set simulate_block 1
      if { ![string match "R" $addr] } {
       global mom_sim_heidenhain_iso_circle
       if { ![info exists mom_sim_heidenhain_iso_circle] } {
        set prev_motion_mode $mom_sim_nc_register(MOTION)
        PB_CMD_vnc__G_motion_code
        if { ![string match "CIRCULAR_*" $mom_sim_nc_register(MOTION)] } {
         set mom_sim_heidenhain_iso_circle 1
         } else {
         set mom_sim_heidenhain_iso_circle 0
        }
        set mom_sim_nc_register(MOTION) $prev_motion_mode
       }
       if $mom_sim_heidenhain_iso_circle {
        set simulate_block 0
       }
      }
      } else {
      if $handle_incr_register {
       if { [lsearch $mom_sim_incr_linear_addrs "$addr"] >= 0 } {
        if { ![string match "" $val] && [expr {$val != 0.0}] } {
         set simulate_block 1
         if $mom_sim_nc_register(RESET_WCS) {
          set val [expr -1 * $val]
         }
         if 0 {
          switch $i {
           9 {
            set mom_sim_pos(0) [expr $mom_sim_pos_zcs(0) + $val]
           }
           10 {
            set mom_sim_pos(1) [expr $mom_sim_pos_zcs(1) + $val]
           }
           11 {
            set mom_sim_pos(2) [expr $mom_sim_pos_zcs(2) + $val]
           }
          }
         }
         if [expr $i == $n1] {
          set mom_sim_pos(0) [expr $mom_sim_pos_zcs(0) + $val]
         }
         if [expr $i == $n2] {
          set mom_sim_pos(1) [expr $mom_sim_pos_zcs(1) + $val]
         }
         if [expr $i == $n3] {
          set mom_sim_pos(2) [expr $mom_sim_pos_zcs(2) + $val]
         }
         if [expr $i == $n4] {
          set mom_sim_pos(3) [expr $mom_sim_pos_zcs(3) + $val]
         }
         if [expr $i == $n5] {
          set mom_sim_pos(4) [expr $mom_sim_pos_zcs(4) + $val]
         }
        }
       }
      } ;# Handle incr addrs
      if { $i < 9 } {
       if [string match "INC" $mom_sim_nc_register(INPUT)] {
        if $mom_sim_nc_register(RESET_WCS) {
         set val [expr -1 * $val]
        }
        if { $i < 3 } {
         set mom_sim_pos($i) [expr $mom_sim_pos_zcs($i) + $val]
         } else {
         set mom_sim_pos($i) [expr $mom_sim_pos($i) + $val]
        }
        } else {
        set offset [expr [lindex $mom_sim_nc_register(LOCAL_OFFSET) $i] + \
        [lindex $mom_sim_nc_register(WORK_OFFSET) $i] ]
        set mom_sim_pos($i) [expr $offset + $val]
       }
       if [expr {$mom_sim_pos($i) != $mom_sim_prev_pos($i)}] {
        set simulate_block 1
       }
      }
      if { $mom_sim_nc_register(SET_LOCAL) || \
       $mom_sim_nc_register(RESET_WCS) } {
       switch $i {
        "0" {
         set mom_sim_offset_pt(0)  $mom_sim_pos(0)
        }
        "1" {
         set mom_sim_offset_pt(1)  $mom_sim_pos(1)
        }
        "2" {
         set mom_sim_offset_pt(2)  $mom_sim_pos(2)
        }
        "3" {
         set mom_sim_offset_pt(3)  $mom_sim_pos(3)
        }
        "4" {
         set mom_sim_offset_pt(4)  $mom_sim_pos(4)
        }
       }
       if $handle_incr_register {
        if [expr $i == $n1] {
         set mom_sim_offset_pt(0)  $mom_sim_pos(0)
        }
        if [expr $i == $n2] {
         set mom_sim_offset_pt(1)  $mom_sim_pos(1)
        }
        if [expr $i == $n3] {
         set mom_sim_offset_pt(2)  $mom_sim_pos(2)
        }
        if [expr $i == $n4] {
         set mom_sim_offset_pt(3)  $mom_sim_pos(3)
        }
        if [expr $i == $n5] {
         set mom_sim_offset_pt(4)  $mom_sim_pos(4)
        }
       }
      }
      if { $mom_sim_nc_register(RETURN_HOME) || \
       $mom_sim_nc_register(FROM_HOME) } {
       switch $i {
        "0" {
         set mom_sim_nc_register(REF_INT_PT_X) $mom_sim_pos(0)
         set mom_sim_message "$i (REF_INT_PT_X) $o_buff"
         PB_CMD_vnc__send_message
        }
        "1" {
         set mom_sim_nc_register(REF_INT_PT_Y) $mom_sim_pos(1)
         set mom_sim_message "$i (REF_INT_PT_Y) $o_buff"
         PB_CMD_vnc__send_message
        }
        "2" {
         set mom_sim_nc_register(REF_INT_PT_Z) $mom_sim_pos(2)
         set mom_sim_message "$i (REF_INT_PT_Z) $o_buff"
         PB_CMD_vnc__send_message
        }
        "3" {
         set mom_sim_nc_register(REF_INT_PT_4) $mom_sim_pos(3)
         set mom_sim_message "$i (REF_INT_PT_4) $o_buff"
         PB_CMD_vnc__send_message
        }
        "4" {
         set mom_sim_nc_register(REF_INT_PT_5) $mom_sim_pos(4)
         set mom_sim_message "$i (REF_INT_PT_5) $o_buff"
         PB_CMD_vnc__send_message
        }
       }
       if $handle_incr_register {
        if [expr $i == $n1] {
         set mom_sim_nc_register(REF_INT_PT_X) $mom_sim_pos(0)
         set mom_sim_message "$i (REF_INT_PT_X) $o_buff"
         PB_CMD_vnc__send_message
        }
        if [expr $i == $n2] {
         set mom_sim_nc_register(REF_INT_PT_Y) $mom_sim_pos(1)
         set mom_sim_message "$i (REF_INT_PT_Y) $o_buff"
         PB_CMD_vnc__send_message
        }
        if [expr $i == $n3] {
         set mom_sim_nc_register(REF_INT_PT_Z) $mom_sim_pos(2)
         set mom_sim_message "$i (REF_INT_PT_Z) $o_buff"
         PB_CMD_vnc__send_message
        }
        if [expr $i == $n4] {
         set mom_sim_nc_register(REF_INT_PT_4) $mom_sim_pos(3)
         set mom_sim_message "$i (REF_INT_PT_4) $o_buff"
         PB_CMD_vnc__send_message
        }
        if [expr $i == $n5] {
         set mom_sim_nc_register(REF_INT_PT_5) $mom_sim_pos(4)
         set mom_sim_message "$i (REF_INT_PT_5) $o_buff"
         PB_CMD_vnc__send_message
        }
       }
      }
     }
     } else {
     if { $i < 3 } {
      if { ![string match "CYCLE_*" $mom_sim_nc_register(MOTION)] || \
       [string match "CYCLE_OFF" $mom_sim_nc_register(MOTION)] } {
       set mom_sim_pos($i) $mom_sim_pos_zcs($i)
      }
     }
    }
   }
   incr i
  }
  set mom_sim_message "** Parse $o_buff  --  $mom_sim_pos(4) $mom_sim_prev_pos(4) simulate : $simulate_block **"
  PB_CMD_vnc__send_message
  return $simulate_block
 }

#=======================================================================
proc VNC_parse_nc_code { o_buff addr_leader args } {
  set status [VNC_parse_nc_block o_buff $addr_leader [join $args]]
  return $status
 }

#=======================================================================
proc VNC_parse_nc_block { O_BUFF word args } {
  upvar $O_BUFF o_buff
  global mom_sim_word_separator mom_sim_word_separator_len
  global mom_sim_nc_address
  global mom_sim_nc_word
  global mom_sim_nc_code
  set mom_sim_nc_address "$word"
  set mom_sim_nc_word    "$word"
  set mom_sim_nc_code    ""
  set status 0
  set word [string trim $word]
  if { ![string length $word] } {
   if { [llength $args] > 0 } {
    set exec_cb [string trim [lindex $args 0]]
    } else {
    set exec_cb ""
   }
   set mom_sim_nc_code "$o_buff"
   if { ![string match "" $exec_cb] } {
    if [llength [info commands "$exec_cb"]] {
     eval "$exec_cb"
    }
   }
   return $status
  }
  if { ![string match "*$word*" $o_buff] } {
   return $status
  }
  set pat "$word\[-\+\]?\[0-9\]*\[\.,\]?\[0-9\]*"
  set local_buff $o_buff
  set code_found 1
  while { $code_found } {
   set cmd [concat regexp -indices \{$pat\} \$local_buff match]
   if { [eval $cmd] == 1 } {
    set idx [expr [lindex $match 0] + [string length $word]]
    set val [string range $local_buff $idx [lindex $match 1]]
    set mom_sim_nc_code [string trim $val]
    if { [string length $mom_sim_nc_code] == 0 } {
     set status 1
     } else {
     set status 2
    }
    if { $status == 2 } {
     set _pat "\[0-9\]+\[\.,\]?\[0-9\]*"
     set _cmd [concat regexp -indices \{$_pat\} \$word _match]
     if { [eval $_cmd] == 1 } {
      set status 0
     }
    }
    if { $status != 0 } {
     if { [llength $args] > 0 } {
      set exec_cb [string trim [lindex $args 0]]
      } else {
      set exec_cb ""
     }
     if { ![string match "" $exec_cb] } {
      if [llength [info commands "$exec_cb"]] {
       eval "$exec_cb"
      }
      } else {
     }
    }
    set leader [string range $local_buff 0 [expr [lindex $match 0] - 1]]
    set idx [expr [lindex $match 1] + $mom_sim_word_separator_len + 1]
    set local_buff "$leader[string range $local_buff $idx end]"
    if { ![string match "*$word*" $local_buff] } {
     set code_found 0
    }
    if { $status == 0 } {
     if { $mom_sim_word_separator_len > 0 } {
      if [string match "*$mom_sim_word_separator" $local_buff] {
       set local_buff $local_buff$word$val
       } else {
       set local_buff $local_buff$mom_sim_word_separator$word$val
      }
      } else {
      set local_buff $local_buff$word$val
     }
    }
    PB_VNC_output_debug_msg "$o_buff  ($word)  $local_buff"
    } else {
    set code_found 0
   }
  }
  set o_buff $local_buff
  return $status
 }

#=======================================================================
proc MOM_SIM_initialize_mtd {} {
  global sim_mtd_initialized
  SIM_mtd_init NC_CONTROLLER_MTD_EVENT_HANDLER
  set sim_mtd_initialized 1
 }

#=======================================================================
proc MOM_SIM_exit_mtd { } {
  SIM_mtd_reset
 }

#=======================================================================
proc PB_VNC_start_of_program { } {
  global mom_sim_vnc_msg_only
  if { [info exists mom_sim_vnc_msg_only] && $mom_sim_vnc_msg_only } {
   PB_VNC_init_sim_vars
   return
  }
  SIM_set_duration_callback_fct "VNC_CalculateDurationTime"
  SIM_start_of_simulation
  PB_VNC_init_sim_vars
  if [llength [info commands "PB_CMD_vnc__start_of_program"]] {
   PB_CMD_vnc__start_of_program
  }
 }

#=======================================================================
proc PB_VNC_start_of_path { } {
  global mom_sim_vnc_msg_only
  if { [info exists mom_sim_vnc_msg_only] && $mom_sim_vnc_msg_only } {
   return
  }
  if [llength [info commands "PB_CMD_vnc__start_of_path"]] {
   PB_CMD_vnc__start_of_path
  }
 }

#=======================================================================
proc PB_VNC_end_of_path { } {
  global mom_sim_vnc_msg_only
  if { [info exists mom_sim_vnc_msg_only] && $mom_sim_vnc_msg_only } {
   return
  }
  global mom_sim_prev_o_buffer
  MOM_before_output
  if [info exists mom_sim_prev_o_buffer] {
   unset mom_sim_prev_o_buffer
  }
  SIM_update
  if [llength [info commands "PB_CMD_vnc__end_of_path"]] {
   PB_CMD_vnc__end_of_path
  }
 }

#=======================================================================
proc PB_VNC_end_of_program { } {
  global mom_sim_vnc_msg_only
  if { [info exists mom_sim_vnc_msg_only] && $mom_sim_vnc_msg_only } {
   return
  }
  MOM_before_output
  if [llength [info commands "PB_CMD_vnc__end_of_program"]] {
   PB_CMD_vnc__end_of_program
  }
  global mom_sim_isv_debug
  if [info exists mom_sim_isv_debug] {
   close $mom_sim_isv_debug
   unset mom_sim_isv_debug
  }
  SIM_end_of_simulation
 }

#=======================================================================
proc PB_VNC_set_kinematics {} {
  global mom_sim_zcs_base
  global mom_sim_csys_matrix
  lappend  origin [ SIM_convert_sim_to_mtd_units $mom_sim_csys_matrix(9)  ]
  lappend  origin [ SIM_convert_sim_to_mtd_units $mom_sim_csys_matrix(10) ]
  lappend  origin [ SIM_convert_sim_to_mtd_units $mom_sim_csys_matrix(11) ]
  for {set i 0} {$i < 9} {incr i}  {
   lappend mtx $mom_sim_csys_matrix($i)
  }
  set zcs_name [ SIM_create_zcs_junction CURRENT_ZCS_JCT "$mom_sim_zcs_base" $origin  $mtx ]
  SIM_update_current_zcs $zcs_name
  global mom_sim_advanced_kinematic_jct
  set reload_kinematics 0
  if [info exists mom_sim_advanced_kinematic_jct] {
   VNC_reload_kinematics
   } else {
   global mom_sim_reverse_4th_table mom_sim_reverse_5th_table
   if { [info exists mom_sim_reverse_4th_table] && $mom_sim_reverse_4th_table } {
    global mom_kin_4th_axis_type mom_kin_4th_axis_rotation
    global mom_kin_4th_axis_min_limit mom_kin_4th_axis_max_limit
    if { [info exists mom_kin_4th_axis_type]  &&  \
     [string toupper $mom_kin_4th_axis_type] == "TABLE" } {
     if { $mom_kin_4th_axis_rotation == "standard" } {
      set mom_kin_4th_axis_rotation "reverse"
      } else {
      set mom_kin_4th_axis_rotation "standard"
      set tmp $mom_kin_4th_axis_min_limit
      set mom_kin_4th_axis_min_limit [expr -1 * $mom_kin_4th_axis_max_limit]
      set mom_kin_4th_axis_max_limit [expr -1 * $tmp]
     }
     set reload_kinematics 1
    }
   }
   if { [info exists mom_sim_reverse_4th_table] && $mom_sim_reverse_4th_table } {
    global mom_kin_5th_axis_type mom_kin_5th_axis_rotation
    global mom_kin_5th_axis_min_limit mom_kin_5th_axis_max_limit
    if { [info exists mom_kin_5th_axis_type]  &&  \
     [string toupper $mom_kin_5th_axis_type] == "TABLE" } {
     if { $mom_kin_5th_axis_rotation == "standard" } {
      set mom_kin_5th_axis_rotation "reverse"
      } else {
      set mom_kin_5th_axis_rotation "standard"
      set tmp $mom_kin_5th_axis_min_limit
      set mom_kin_5th_axis_min_limit [expr -1 * $mom_kin_5th_axis_max_limit]
      set mom_kin_5th_axis_max_limit [expr -1 * $tmp]
     }
     set reload_kinematics 1
    }
   }
  }
  if $reload_kinematics {
   MOM_reload_kinematics
  }
 }

#=======================================================================
proc VNC_restore_pos_no_sim {} {
  global mom_sim_pos mom_sim_prev_pos mom_sim_simulate_block
  for {set i 0} {$i < 8} {incr i} {
   set mom_sim_pos($i) $mom_sim_prev_pos($i)
  }
  set mom_sim_simulate_block 0
 }

#=======================================================================
proc PB_VNC_send_message { message } {
  global mom_sim_vnc_msg_only
  if { [info exists mom_sim_vnc_msg_only] && $mom_sim_vnc_msg_only } {
   return
  }
  SIM_feedback_message "MTD" "$message"
 }

#=======================================================================
proc PB_CMD_vnc__send_message {} {
  global mom_sim_message
  PB_VNC_send_message "$mom_sim_message"
 }

#=======================================================================
proc VNC_CalculateDurationTime { linear_or_angular delta } {
  if [llength [info commands "PB_CMD_vnc__calculate_duration_time"]] {
   global mom_sim_motion_linear_or_angular mom_sim_travel_delta
   global mom_sim_duration_time
   set mom_sim_motion_linear_or_angular $linear_or_angular
   set mom_sim_travel_delta $delta
   PB_CMD_vnc__calculate_duration_time
   return $mom_sim_duration_time
  }
  global mom_feed_rate
  global sim_feedrate_mode
  global mom_sim_nc_register
  if { $linear_or_angular == "ANGULAR" } {
   return 0
  }
  if { $sim_feedrate_mode == "RAPID" } {
   set feed $mom_sim_rapid_feed_rate
   } else {
   set feed $mom_feed_rate
  }
  set length [expr abs($delta)]
  if {[expr abs($feed)] < 0.00001 || $length < 0.00001 } {
   set time 0
   } else {
   set time [expr ($length / $feed) * 60.0]
  }
  return $time
 }

#=======================================================================
proc VNC_ask_feedrate_mode { } {
  if [llength [info commands "PB_CMD_vnc__ask_feedrate_mode"]] {
   if { ![catch {set feed_units [PB_CMD_vnc__ask_feedrate_mode]} ] } {
    return $feed_units
   }
  }
  global mom_feed_rate_mode
  if [info exists mom_feed_rate_mode] {
   switch $mom_feed_rate_mode {
    IPM     { set feed_units "INCH_PER_MIN" }
    MMPM    { set feed_units "MM_PER_MIN"}
    IPR     { set feed_units "INCH_PER_REV" }
    MMPR    { set feed_units "MM_PER_REV" }
    FRN     { set feed_units "MM_PER_100REV" }
    default { set feed_units "UNKNOWN FEEDRATE UNITS" }
   }
   } else {
   set feed_units "UNKNOWN FEEDRATE UNITS"
  }
  return $feed_units
 }

#=======================================================================
proc VNC_ask_speed_mode { } {
  if [llength [info commands "PB_CMD_vnc__ask_speed_mode"]] {
   if { ![catch {set speed_units [PB_CMD_vnc__ask_speed_mode]} ] } {
    return $speed_units
   }
  }
  global mom_spindle_mode
  if [info exists mom_spindle_mode] {
   switch $mom_spindle_mode {
    RPM     { set speed_units "REV_PER_MIN" }
    default { set speed_units "UNKNOWN SPEED UNITS" }
   }
   } else {
   set speed_units "UNKNOWN SPEED UNITS"
  }
  return $speed_units
 }

#=======================================================================
proc VNC_set_feedrate_mode { cutting_mode } {
  if [llength [info commands "PB_CMD_vnc__set_feedrate_mode"]] {
   global mom_sim_cutting_mode
   set mom_sim_cutting_mode $cutting_mode
   if { ![catch {PB_CMD_vnc__set_feedrate_mode} res] } {
    return
   }
  }
  global mom_feed_rate
  global sim_feedrate_mode
  SIM_set_cutting_mode $cutting_mode
  set sim_feedrate_mode $cutting_mode
  if { $cutting_mode == "RAPID" } {
   SIM_set_feed $mom_feed_rate [VNC_ask_feedrate_mode]
   } else {
   SIM_set_feed $mom_feed_rate [VNC_ask_feedrate_mode]
  }
 }

#=======================================================================
proc VNC_unmount_tool { tool_ug_name } {
  global sim_prev_tool_name
  global mom_sim_result sim_tool_change_pos
  if { $tool_ug_name  != "undefined" } {
   SIM_ask_kim_comp_name_by_id "TOOL" $tool_ug_name
   set t_name $mom_sim_result
   SIM_unmount_tool "2.0" $t_name
   SIM_update
   set sim_prev_tool_name "undefined"
  }
 }

#=======================================================================
proc VNC_tool_change {} {
  PB_CMD_vnc__tool_change
 }

#=======================================================================
proc VNC_rewind_stop_program {} {
  PB_CMD_vnc__rewind_stop_program
 }

#=======================================================================
proc VNC_rapid_move {} {
  PB_CMD_vnc__rapid_move
 }

#=======================================================================
proc VNC_linear_move {} {
  PB_CMD_vnc__linear_move
 }

#=======================================================================
proc VNC_nurbs_move {} {
  PB_CMD_vnc__nurbs_move
 }

#=======================================================================
proc VNC_circular_move { direction args } {
  global mom_sim_circular_dir
  if {$direction == "CLW"} {
   set mom_sim_circular_dir -1.0
   } else {
   set mom_sim_circular_dir 1.0
  }
  if 0 {
   global mom_sim_circular_plane
   if [llength $args] {
    set mom_sim_circular_plane [lindex $args 0]
    } else {
    set mom_sim_circular_plane "XY"
   }
  }
  PB_CMD_vnc__circular_move
 }

#=======================================================================
proc VNC_cycle_move {} {
  global mom_sim_nc_register
  if [string match "CYCLE_OFF" $mom_sim_nc_register(MOTION)] {
   set mom_sim_nc_register(MOTION) RAPID
   } elseif [string match "CYCLE_START" $mom_sim_nc_register(MOTION)] {
   PB_CMD_vnc__cycle_move
   } elseif [string match "CYCLE_*" $mom_sim_nc_register(MOTION)] {
   PB_CMD_vnc__cycle_set
  }
 }

#=======================================================================
proc VNC_set_ref_jct { sim_tool_name } {
  global mom_sim_spindle_jct
  set sim_tool_name [string trim $sim_tool_name]
  if { $sim_tool_name != "" && $sim_tool_name != "undefined" } \
  {
   set ref_jct $sim_tool_name@SIM_TOOL_TIP
   } else {
   set ref_jct "$mom_sim_spindle_jct"
  }
  SIM_set_current_ref_junction $ref_jct
  global mom_sim_current_junction
  if [info exists mom_sim_current_junction] {
   if { ![catch {set pos [SIM_ask_last_position_zcs]} ] } {
    global mom_sim_pos
    set mom_sim_pos(0) [lindex $pos 0]
    set mom_sim_pos(1) [lindex $pos 1]
    set mom_sim_pos(2) [lindex $pos 2]
   }
  }
  set mom_sim_current_junction $ref_jct
 }

#=======================================================================
proc VNC_coolant_on { } {
  global sim_coolant_status
  set sim_coolant_status "ON"
  SIM_set_coolant "ON"
 }

#=======================================================================
proc VNC_coolant_off { } {
  global sim_coolant_status
  set sim_coolant_status "OFF"
  SIM_set_coolant "OFF"
 }

#=======================================================================
proc VNC_concat_coord_list { args } {
  global mom_sim_nc_axes
  set args [join $args]
  set coord [list]
  foreach { axis val } $args {
   if { [lsearch $mom_sim_nc_axes $axis] >= 0 } {
    if { ![string match "" $val] } {
     lappend coord $axis $val
    }
   }
  }
  return $coord
 }

#=======================================================================
proc VNC_move_linear_zcs { mode args } {
  if { $mode != "CURRENT" } {
   VNC_set_feedrate_mode $mode
  }
  set coord [VNC_concat_coord_list $args]
  global mom_sim_reverse_4th_table
  global mom_sim_reverse_5th_table
  global mom_sim_lg_axis
  if { [info exists mom_sim_reverse_4th_table]  && \
   $mom_sim_reverse_4th_table == 1 } {
   global mom_kin_4th_axis_type
   global mom_kin_4th_axis_rotation
   if { [info exists mom_kin_4th_axis_type]  &&  [string toupper $mom_kin_4th_axis_type] == "TABLE" } {
    if { $mom_kin_4th_axis_rotation == "standard" } {
     set 4th [lsearch $coord $mom_sim_lg_axis(4)]
     if { $4th >= 0 } {
      set 4th [expr $4th + 1]
      set 4th_val [lindex $coord $4th]
      set coord [lreplace $coord $4th $4th [expr -1 * $4th_val]]
     }
    }
   }
  }
  if { [info exists mom_sim_reverse_5th_table]  && \
   $mom_sim_reverse_5th_table == 1 } {
   global mom_kin_5th_axis_type
   global mom_kin_5th_axis_rotation
   if { [info exists mom_kin_5th_axis_type]  &&  [string toupper $mom_kin_5th_axis_type] == "TABLE" } {
    if { $mom_kin_5th_axis_rotation == "standard" } {
     set 5th [lsearch $coord $mom_sim_lg_axis(5)]
     if { $5th >= 0 } {
      set 5th [expr $5th + 1]
      set 5th_val [lindex $coord $5th]
      set coord [lreplace $coord $5th $5th [expr -1 * $5th_val]]
     }
    }
   }
  }
  eval SIM_move_linear_zcs $coord
 }

#=======================================================================
proc VNC_set_post_kinematics { zcs_jct X_axis Y_axis Z_axis \
  {4th_axis ""} {5th_axis ""} \
  {pivot_jct ""} {gauge_jct ""} } {
  SIM_set_post_kinematics $zcs_jct $X_axis $Y_axis $Z_axis  $4th_axis $5th_axis $pivot_jct $gauge_jct
 }

#=======================================================================
proc VNC_machine_tool_model_exists { } {
  global sim_mtd_initialized
  return $sim_mtd_initialized
 }

#=======================================================================
proc VNC_pause { args } {
  global env
  if { [info exists env(PB_SUPPRESS_UGPOST_DEBUG)]  &&  $env(PB_SUPPRESS_UGPOST_DEBUG) == 1 } {
   return
  }
  set cam_aux_dir  [MOM_ask_env_var UGII_CAM_AUXILIARY_DIR]
  global tcl_platform
  if [string match "*windows*" $tcl_platform(platform)] {
   set ug_wish "ugwish.exe"
   } else {
   set ug_wish ugwish
  }
  if { [file exists ${cam_aux_dir}$ug_wish] && [file exists ${cam_aux_dir}mom_pause.tcl] } {
   set title ""
   set msg ""
   if { [llength $args] == 1 } {
    set msg [lindex $args 0]
   }
   if { [llength $args] > 1 } {
    set title [lindex $args 0]
    set msg [lindex $args 1]
   }
   exec ${cam_aux_dir}$ug_wish ${cam_aux_dir}mom_pause.tcl $title $msg
  }
 }

#=======================================================================
proc VNC_trace { args } {
  set start_idx 2
  set str ""
  set level [info level]
  for {set i $start_idx} {$i < $level} {incr i} {
   set str "${str}[lindex [info level $i] 0]\n"
  }
  return $str
 }

#=======================================================================
proc VNC_reload_kinematics {} {
  if [llength [info commands "PB_CMD_vnc__reload_kinematics"]] {
   if { ![catch {PB_CMD_vnc__reload_kinematics} ] } {
    return
   }
  }
  global mom_sim_mt_axis
  global sim_prev_zcs
  global mom_sim_num_machine_axes mom_sim_advanced_kinematic_jct
  set current_zcs "$mom_sim_advanced_kinematic_jct"
  if { [VNC_machine_tool_model_exists]  &&  $sim_prev_zcs != $current_zcs } {
   if { $mom_sim_num_machine_axes == 4 } {
    VNC_set_post_kinematics $current_zcs $mom_sim_mt_axis(X) \
    $mom_sim_mt_axis(Y) \
    $mom_sim_mt_axis(Z) \
    $mom_sim_mt_axis(4)
    } elseif { $mom_sim_num_machine_axes == 5 } {
    VNC_set_post_kinematics $current_zcs $mom_sim_mt_axis(X) \
    $mom_sim_mt_axis(Y) \
    $mom_sim_mt_axis(Z) \
    $mom_sim_mt_axis(4) \
    $mom_sim_mt_axis(5)
   }
   set sim_prev_zcs $current_zcs
  }
  MOM_reload_kinematics
 }
} ;# mom_mtd_initialized