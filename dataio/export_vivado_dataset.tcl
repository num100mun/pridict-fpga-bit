# Tcl script to export routing information from a Vivado design
#
# The script produces three CSV files in the directory provided via the
# command line:
#   tiles.csv - tile_name,tile_type,x,y
#   pips.csv  - pip_name,tile_name
#   bits.csv  - pip_name,bit_index,value
#
# Usage:
#   vivado -mode tcl -source export_vivado_dataset.tcl -tclargs <out_dir>
#
# The implementation tries to be defensive so that it works across Vivado
# versions.  Missing information will simply be skipped.

# ---------------------------------------------------------------------------
# Utility helpers

proc csv_escape {s} {
    # Replace characters that could break CSV formatting
    return [string map {"," "\\," "\n" " " "\r" ""} $s]
}

proc parse_xy {name} {
    # Extract X/Y coordinates from a tile name like INT_X3Y42
    if {[regexp {X([0-9]+)Y([0-9]+)} $name -> x y]} {
        return [list $x $y]
    } else {
        return [list -1 -1]
    }
}

proc query_pip_bits {pip} {
    # Try multiple commands/properties to obtain configuration bits for a PIP.
    # Different Vivado versions expose this information through different APIs
    # so we attempt several options in order.

    if {![catch {set bits [get_pip_bit_coords -quiet $pip]}]} {
        # Newer Vivado: returns list of {index value} pairs
        return $bits
    }

    if {![catch {set bits [get_property BIT $pip]}]} {
        # Older Vivado: BIT property may contain similar information
        return $bits
    }

    return {}
}

# ---------------------------------------------------------------------------
# CSV generators

proc export_tiles {out_path} {
    set fh [open $out_path w]
    puts $fh "tile_name,tile_type,x,y"

    foreach tile [lsort [get_tiles]] {
        set name [get_property NAME $tile]
        set type [get_property TYPE $tile]
        lassign [parse_xy $name] x y
        puts $fh [format "%s,%s,%d,%d" [csv_escape $name] [csv_escape $type] $x $y]
    }

    close $fh
}

proc export_pips {out_path} {
    set fh [open $out_path w]
    puts $fh "pip_name,tile_name"

    foreach tile [lsort [get_tiles]] {
        set tname [get_property NAME $tile]
        if {[catch {set pips [get_pips -of_objects $tile]} err]} {
            puts "Warning: failed to query pips for $tname: $err"
            continue
        }
        foreach pip $pips {
            set pname [get_property NAME $pip]
            puts $fh [format "%s,%s" [csv_escape $pname] [csv_escape $tname]]
        }
    }

    close $fh
}

proc export_bits {out_path} {
    set fh [open $out_path w]
    puts $fh "pip_name,bit_index,value"

    foreach tile [lsort [get_tiles]] {
        if {[catch {set pips [get_pips -of_objects $tile]}]} {
            continue
        }
        foreach pip $pips {
            set pname [get_property NAME $pip]
            set bits [query_pip_bits $pip]
            set n [llength $bits]
            for {set i 0} {$i < $n} {incr i 2} {
                set bit_idx [lindex $bits $i]
                set bit_val [lindex $bits [expr {$i + 1}]]
                if {$bit_idx eq "" || $bit_val eq ""} {
                    continue
                }
                puts $fh [format "%s,%s,%s" [csv_escape $pname] $bit_idx $bit_val]
            }
        }
    }

    close $fh
}

# ---------------------------------------------------------------------------
# Entry point

if {[llength $argv] != 1} {
    puts "Usage: vivado -mode tcl -source export_vivado_dataset.tcl <out_dir>"
    exit 1
}

set out_dir [lindex $argv 0]
file mkdir $out_dir

export_tiles [file join $out_dir "tiles.csv"]
export_pips  [file join $out_dir "pips.csv"]
export_bits  [file join $out_dir "bits.csv"]

puts "Export finished to $out_dir"
