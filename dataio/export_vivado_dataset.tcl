proc write_file {path content} {
    set fn [open $path "w"]
    puts $fh $content
    close $fh
}

proc csv_escape {s} {
    return [string map {"," "\\," "\n" " " "\r" ""} $s]
}

proc parse_xy {name} {
    if{[regexp {X([0-9]+)Y([0-9]+)} $name -> x y]} {
        return [list $x $y]
    } else {
        return [list -1 -1]
    }
}



proc export_tiles {out_path} {
    set lines "tile_name, tile_type, x, y \n"


}