#!/usr/bin/awk -f

BEGIN {
    RS = ";"
    count = 0
}

# Capture every `private static string[] NAME = new[] { "F1", "F2", ... }`
# definition into the `arrays` table. RS=";" makes each statement one record,
# so multi-line array bodies stay together.
/private[ \t]+static[ \t]+string\[\][ \t]+[A-Za-z_]/ {
    line = $0
    sub(/.*string\[\][ \t]+/, "", line)
    if (match(line, /[A-Za-z_][A-Za-z0-9_]*/)) {
        name = substr(line, RSTART, RLENGTH)
        # Skip to the array body to avoid picking up quoted words from comments
        # that appear before the array definition (RS=";" lumps preceding text
        # into this record).
        body = $0
        if (match(body, /new\[\][ \t]*[{]/)) {
            body = substr(body, RSTART + RLENGTH)
        }
        files = ""
        while (match(body, /"[^"]*"/)) {
            file = substr(body, RSTART + 1, RLENGTH - 2)
            files = (files == "") ? file : files " " file
            body = substr(body, RSTART + RLENGTH)
        }
        if (name != "" && files != "") {
            arrays[name] = files
        }
    }
}

# Parse the fileTargets dictionary, which sits in a single statement of the
# form `{ "SOURCE", <expr> }, { "SOURCE", <expr> }, ...` where <expr> is a
# bare array name or a combination like `langFiles.Concat(langAchiev).ToArray()`
# (introduced upstream in v1.9.5). Every identifier in <expr> that names a
# known array contributes its files; unknown identifiers (Concat, ToArray)
# are ignored.
/Dictionary<string,[ \t]*string\[\]>[ \t]+fileTargets/ {
    body = $0
    while (match(body, /[{][ \t\n]*"[^"]+"[^{}]*[}]/)) {
        pair = substr(body, RSTART, RLENGTH)
        body = substr(body, RSTART + RLENGTH)
        if (match(pair, /"[^"]+"/)) {
            source = substr(pair, RSTART + 1, RLENGTH - 2)
            rest = substr(pair, RSTART + RLENGTH)
            files = ""
            while (match(rest, /[A-Za-z_][A-Za-z0-9_]*/)) {
                aname = substr(rest, RSTART, RLENGTH)
                rest = substr(rest, RSTART + RLENGTH)
                if (aname in arrays) {
                    files = (files == "") ? arrays[aname] : files " " arrays[aname]
                }
            }
            if (source != "" && files != "") {
                print source "\t" files
                count++
            }
        }
    }
}

END {
    if (count < 5) {
        print "parse_targets: too few entries (" count "); upstream format may have changed" > "/dev/stderr"
        exit 1
    }
}
