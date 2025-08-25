

proc run_one_design {name top srcdir part out_dir jobs do_impl} {
  # puts "==== [$name] top=$top ===="
  set dir [file dirname $srcdir]/$top
  puts $srcdir  
  # set proj_dir [file join $out_dir $name]
  # file mkdir $proj_dir

  # # 收集源/约束
  # set SRCS [collect_sources $srcdir]
  # if {[llength $SRCS] == 0} {
  #   puts "WARN: $name has no HDL sources under $srcdir, skip."
  #   return
  # }
  # set XDCS [collect_xdcs $xdc_glob $srcdir]


  # create_project -force $name $proj_dir -part $part
  # set_property target_language Verilog [current_project]
  # add_files -norecurse $SRCS
  # if {[llength $XDCS] > 0} { add_files -fileset constrs_1 $XDCS }
  # update_compile_order -fileset sources_1

  # set_property top $top [current_fileset]

  # # 运行综合
  # launch_runs synth_1 -jobs $jobs
  # wait_on_run synth_1
  # if {![string match "synth_1" [current_run -synthesis]]} {
  #   open_run synth_1
  # } else {
  #   open_run synth_1
  # }

  # # 输出综合 DCP
  # set dcp_synth [file join $proj_dir "${name}_synth.dcp"]
  # write_checkpoint -force $dcp_synth
  # puts "WROTE: $dcp_synth"

  # if {$do_impl} {
  #   # 只跑到放置/物理优化即可；无需完整布线
  #   # 方式1：项目 Run 到 phys_opt_design
  #   reset_run impl_1
  #   launch_runs impl_1 -to_step phys_opt_design -jobs $jobs
  #   wait_on_run impl_1
  #   open_run impl_1

  #   # 输出放置后 DCP
  #   set dcp_placed [file join $proj_dir "${name}_placed.dcp"]
  #   write_checkpoint -force $dcp_placed
  #   puts "WROTE: $dcp_placed"
  # }

  # close_project
}



proc _split_line {line} {
  set s [string trim $line]
  if {$s eq ""} { return {} }
  if {[string match "#*" $s]} { return {} }
  set s [string map {"," " "} $s]
  regsub -all {\s+} $s " " s
  return [split $s " "]
}

# proc read_design_list {list_file} {
#   set L {}
#   set fp [open $list_file r]
#   while {[gets $fp line] >= 0} {
#     set toks [_split_line $line]
#     if {[llength $toks] < 3} { continue }
#     set name    [lindex $toks 0]
#     set top     [lindex $toks 1]
#     set srcdir  [file normalize [lindex $toks 2]]
#     set xdcglob ""
#     if {[llength $toks] >= 4} { set xdcglob [lindex $toks 3] }
#     lappend L [list $name $top $srcdir $xdcglob]
#   }
#   close $fp
#   return $L
# }

proc discover_designs {root_dir} {
  # root_dir 下的每个一级子目录视为一个设计；top=目录名
  set L {}
  foreach d [glob -nocomplain -types f $root_dir/*] {
    set name [file tail $d]
    set top  [file rootname $name]
    lappend L [list $name $top [file normalize $d] ]
  }
  return $L
}


#寻找当前目录下可用的.v文件
# proc collect_sources {src_dir} {
#   set exts {*.v *.sv *.vh *.vhd *.vhdl}
#   set files {}
#   foreach e $exts {
#     set lst [glob -nocomplain -types f -directory $src_dir -tails -path $src_dir -types f -recursive $e]
#     # glob -recursive 在部分版本不可用；退化为手工递归：
#     if {[llength $lst] == 0} {
#       # 手动收集
#       foreach f [exec find $src_dir -type f -name $e] {
#         lappend files [file normalize $f]
#       }
#     } else {
#       foreach f $lst { lappend files [file normalize [file join $src_dir $f]] }
#     }
#   }
#   return [lsort -unique $files]
# }


proc usage {} {
  puts "Usage:"
  puts "  vivado -mode batch -source build_dcp_batch.tcl -tclargs \\ "
  puts "    -part <xc7s50fgga484-1> -out </abs/out_dir> -jobs <N> -impl <0|1> (one of -list or -root)"
  puts "    [-list </abs/designs.tsv>]           # 推荐：清单文件"
  puts "    [-root </abs/src_root_dir>]          # 自动模式：src_root 下每个子目录一个设计"
  puts ""
  puts "designs.tsv format (space/tab/comma separated):"
  puts "  name  top  src_dir"
}

proc main {} {
  set cwd [pwd]
  set PART "xc7s50fgga484-1"
  set OUT_DIR "dcp"
  set JOBS 8
  set DO_IMPL 1
  set LIST_FILE ""
  set ROOT_DIR "$cwd/dataset/verilog"
  set argcnt [llength $::argv]
  
  # for {set i 0} {$i < $argcnt} {incr i} {
  #   set a [lindex $::argv $i]
  #   switch -- $a {
  #     -part       { incr i; set PART     [lindex $::argv $i] }
  #     -out        { incr i; set OUT_DIR  [file normalize [lindex $::argv $i]] }
  #     -jobs       { incr i; set JOBS     [lindex $::argv $i] }
  #     -impl       { incr i; set DO_IMPL  [lindex $::argv $i] }
  #     -list       { incr i; set LIST_FILE [file normalize [lindex $::argv $i]] }
  #     -root       { incr i; set ROOT_DIR [file normalize [lindex $::argv $i]] }
  #     default     { }
  #   }
  # }
  if {$OUT_DIR eq "" || ($LIST_FILE eq "" && $ROOT_DIR eq "")} {
    usage
    exit 1
  }
  file mkdir $OUT_DIR
  if {$LIST_FILE ne ""} {
    set DESIGNS [read_design_list $LIST_FILE]
  } else {
    set DESIGNS [discover_designs $ROOT_DIR]
  }
  if {[llength $DESIGNS] == 0} {
    puts "No designs found. Check -list or -root."
    exit 2
  }

  puts "PART   : $PART"
  puts "OUTDIR : $OUT_DIR"
  puts "JOBS   : $JOBS"
  puts "IMPL   : $DO_IMPL"
  puts "COUNT  : [llength $DESIGNS] designs"
  foreach item $DESIGNS {
    lassign $item NAME TOP SRCDIR
    catch { run_one_design $NAME $TOP $SRCDIR $PART $OUT_DIR $JOBS $DO_IMPL } err
    if {$err ne ""} {
      puts "ERROR on $NAME: $err"
    }
  }


}



