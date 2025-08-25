# export_one_cr.tcl
# 参数：<top.dcp> <out_dir> <CR_NAME 或 CLOCKREGION_AUTO>
set dcp   [lindex $argv 0]
set outd  [lindex $argv 1]
set CRARG [lindex $argv 2]
file mkdir $outd
open_checkpoint $dcp
set_part xc7s50fgga484-1

# 小工具
proc js {s} { regsub -all {"} $s {\"} }
proc site_xy {site} {
  set n [get_property NAME $site]
  if {[regexp {X([0-9]+)Y([0-9]+)} $n -> x y]} { return [list $x $y] }
  return [list -1 -1]
}

# 1) 选一个 clock region：若传 CLOCKREGION_AUTO，就选择 SLICE 最多的那个
set CRS [get_clock_regions]
if {$CRARG eq "CLOCKREGION_AUTO"} {
  set best_cr ""; set best_n 0
  foreach cr $CRS {
    set n [llength [get_sites -quiet -of_objects $cr -filter {SITE_TYPE =~ SLICE*}]]
    if {$n > $best_n} { set best_cr $cr; set best_n $n }
  }
  set CR $best_cr
} else {
  set CR [lsearch -inline $CRS $CRARG]
  if {$CR eq ""} { puts "ERROR: bad CR name $CRARG"; exit 1 }
}
puts "== Using clock region: $CR =="

# 2) 可选：把 CLB 原语限制到该 CR（生成“CR 内布局”的监督标签）
#    若你的 dcp 还未 place，这段会帮助在CR内完成放置；已放好可跳过 place_design
create_pblock pblock_oneCR
resize_pblock pblock_oneCR -reset
resize_pblock pblock_oneCR -add $CR
set clb_cells [get_cells -hier -filter {IS_PRIMITIVE && PRIMITIVE_LEVEL == LEAF && (REF_NAME =~ LUT* || REF_NAME =~ FD*)}]
add_cells_to_pblock pblock_oneCR $clb_cells
set_property EXCLUDE_PLACEMENT false [get_pblocks pblock_oneCR]

# 若需要实际在该CR内放置（未放置或想得到“CR内标签”时打开）
if {[llength [get_placed_cells -quiet]] == 0} {
  place_design -directive Explore
  phys_opt_design -directive Explore
}

# 3) 导出设备（仅该 CR 的 SLICE sites）
set fp_sites [open [file join $outd sites.csv] w]
puts $fp_sites "site,x,y,site_type,clock_region,slr,tile,tile_type"
set sites_in_cr [get_sites -of_objects $CR -filter {SITE_TYPE =~ SLICE*}]
foreach s $sites_in_cr {
  set name  [get_property NAME $s]
  set stype [get_property SITE_TYPE $s]
  set xy    [site_xy $s]
  set cr    [get_property NAME $CR]
  set slrs  [get_slrs -quiet -of_objects $s]
  set slr   [expr {[llength $slrs]>0 ? [get_property NAME [lindex $slrs 0]] : ""}]
  set tiles [get_tiles -quiet -of_objects $s]
  set tile  [expr {[llength $tiles]>0 ? [get_property NAME [lindex $tiles 0]] : ""}]
  set ttype [expr {[llength $tiles]>0 ? [get_property TYPE [lindex $tiles 0]] : ""}]
  puts $fp_sites [format "%s,%s,%s,%s,%s,%s,%s,%s" \
    $name [lindex $xy 0] [lindex $xy 1] $stype $cr $slr $tile $ttype]
}
close $fp_sites

# 4) 导出电路（cells.jsonl，含邻接 & 标签 site；仅导出落在该 CR 的 CLB 单元）
set fp_cells [open [file join $outd cells.jsonl] w]
foreach c $clb_cells {
  # 只收集“最终落在该CR”的 cell（若还未place，请先执行 place_design）
  set s [get_sites -quiet -of_objects $c]
  if {[llength $s] == 0} { continue }
  set s [lindex $s 0]
  if {[lsearch -exact $sites_in_cr $s] < 0} { continue }

  set cname [get_property NAME $c]
  set ref   [get_property REF_NAME $c]
  set fixed [get_property IS_LOC_FIXED $c]
  set site  [get_property NAME $s]
  set xy    [site_xy $s]

  # 邻接（截断到128）
  set neigh {}
  foreach p [get_pins -quiet -of_objects $c] {
    foreach n [get_nets -quiet -of_objects $p] {
      foreach q [get_pins -quiet -of_objects $n] {
        set cc [get_cells -quiet -of_objects $q]
        if {$cc ne "" && $cc ne $c} { lappend neigh [get_property NAME $cc] }
      }
    }
  }
  set neigh [lsort -unique $neigh]
  set neigh [lrange $neigh 0 128]

  puts $fp_cells [format "{%s}" [join [list \
    "\"cell\":\"[js $cname]\"" \
    "\"ref\":\"[js $ref]\"" \
    "\"fixed\":%s" \
    "\"label_site\":\"[js $site]\"" \
    "\"label_xy\":[%s,%s]" \
    "\"neighbors\":[%s]" \
  ] ,]] [expr {$fixed ? "true" : "false"}] [lindex $xy 0] [lindex $xy 1] \
    [join [lmap x $neigh {format "\"%s\"" $x}] ,]]
}
close $fp_cells

# 5) 导出约束：pblock & 已固定单元（便于生成动作掩码）
set fp_con [open [file join $outd constraints.jsonl] w]
puts $fp_con "{\"kind\":\"clock_region\",\"name\":\"[get_property NAME $CR]\"}"
puts $fp_con "{\"kind\":\"pblock\",\"name\":\"pblock_oneCR\",\"exclude\":false}"
foreach c [get_cells -hier] {
  set isfixed [get_property IS_LOC_FIXED $c]
  set loc [get_property LOC $c]
  if {$isfixed || $loc ne ""} {
    puts $fp_con [format "{\"kind\":\"fixed_cell\",\"cell\":\"%s\",\"loc\":\"%s\",\"is_fixed\":%s}" \
      [js [get_property NAME $c]] [js $loc] [expr {$isfixed ? "true":"false"}]]
  }
}
close $fp_con

# 补一份清单
set nsites [llength $sites_in_cr]
set ncells [llength [get_cells -quiet -of_objects [get_pblocks pblock_oneCR]]]
puts "== Export done. Sites in CR: $nsites ; Cells in pblock: $ncells =="
exit
