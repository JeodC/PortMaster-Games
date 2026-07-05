# Shared product-retrieval helpers for HarbourMasters ports.
#
# Sourced by each port's src/retrieve-products.txt. The retrieve script runs
# on the host (not in the build container) after the build completes, with
# cwd = RHH-Ports repo root.
#
# Provides:
#   retrieve_init                — set up SRCDIR/DESTDIR/PROJECT_BUILD/PROJECT_SRC
#   copy_binary                  — copy the main port binary from build dir
#   copy_o2r                     — copy the generated .o2r (warn if missing)
#   copy_extra                   — copy any extra build-dir file (e.g. gamecontrollerdb.txt)
#   replace_libs                 — replace DESTDIR/libs with PROJECT_BUILD/libs
#   package_soh_extractor_zip    — SoH-style assets/extractor.zip
#   package_2ship_extractor_zip  — 2s2h-style assets/extractor.zip (with ZAPD.out)
#   package_torch_assets         — Torch-style tools/torch + tools/assets.zip + tools/config.yml

set -e

# retrieve_init <SRCDIR> <DESTDIR>
#
# Sets globals: SRCDIR, DESTDIR, PROJECT_SRC, PROJECT_BUILD.
# Cd's into DESTDIR (matches the build_port.sh contract).
retrieve_init() {
    SRCDIR=$1
    DESTDIR=$2
    PROJECT_SRC="$SRCDIR/project"
    PROJECT_BUILD="$PROJECT_SRC/build"

    if [[ -z "$DESTDIR" || ! -d "$DESTDIR" ]]; then
        echo "retrieve_init: DESTDIR not found: $DESTDIR"
        exit 1
    fi
    cd "$DESTDIR"
}

# copy_binary <build-relative-path>
#   Copies $PROJECT_BUILD/<rel> to $DESTDIR/<basename>.
copy_binary() {
    local rel=$1
    local src="$PROJECT_BUILD/$rel"
    if [[ ! -f "$src" ]]; then
        echo "copy_binary: ERROR: $src not found"
        exit 1
    fi
    cp "$src" "$DESTDIR/"
}

# copy_binary_opt <build-relative-path>
#   Same as copy_binary, but only warns if the file is missing (used for
#   optional debug artifacts like Spaghettify.pdb that some upstream cmake
#   configs may stop producing).
copy_binary_opt() {
    local rel=$1
    local src="$PROJECT_BUILD/$rel"
    if [[ -f "$src" ]]; then
        cp "$src" "$DESTDIR/"
    else
        echo "copy_binary_opt: $src not found, skipping"
    fi
}

# copy_o2r <build-relative-path>
#   Same shape as copy_binary; warns (does not error) if absent.
copy_o2r() {
    local rel=$1
    local src="$PROJECT_BUILD/$rel"
    if [[ -f "$src" ]]; then
        cp "$src" "$DESTDIR/"
    else
        echo "copy_o2r: WARNING: no .o2r at $src"
    fi
}

# copy_extra <build-relative-path> [<dest-name>]
copy_extra() {
    local rel=$1
    local dest=${2:-$(basename "$rel")}
    local src="$PROJECT_BUILD/$rel"
    if [[ ! -f "$src" ]]; then
        echo "copy_extra: ERROR: $src not found"
        exit 1
    fi
    cp "$src" "$DESTDIR/$dest"
}

# replace_libs
#   Wipe DESTDIR/libs and replace with PROJECT_BUILD/libs.
replace_libs() {
    rm -rf "$DESTDIR/libs"
    cp -r "$PROJECT_BUILD/libs" "$DESTDIR/"
}

copy_tcc_runtime() {
    local src="$PROJECT_BUILD/.tcc"
    if [[ ! -d "$src" ]]; then
        echo "copy_tcc_runtime: WARNING: no .tcc at $src"
        return 0
    fi
    rm -rf "$DESTDIR/.tcc"
    cp -r "$src" "$DESTDIR/.tcc"
}

# package_soh_extractor_zip <extractor-src-rel> <xml-src-rel>
#   Contents of <extractor-src> at the zip root + the <xml-src> directory itself.
package_soh_extractor_zip() {
    local extractor_rel=$1 xml_rel=$2
    local extractor_src="$PROJECT_SRC/$extractor_rel"
    local xml_src="$PROJECT_SRC/$xml_rel"

    if [[ ! -d "$extractor_src" || ! -d "$xml_src" ]]; then
        echo "package_soh_extractor_zip: WARNING: extractor or xml dir missing, skipping"
        return 0
    fi

    local stage="$DESTDIR/assets/tmp_zip"
    mkdir -p "$DESTDIR/assets"
    rm -rf "$stage"
    mkdir -p "$stage"

    cp -r "$extractor_src/." "$stage/"
    cp -r "$xml_src" "$stage/"

    (cd "$stage" && zip -r "$DESTDIR/assets/extractor.zip" ./*)
    rm -rf "$stage"
}

# package_2ship_extractor_zip <extractor-src-rel> <xml-src-rel> <zapd-build-rel>
#   extractor/ subdir containing ZAPD.out + contents of <extractor-src>, plus
#   the <xml-src> dir at zip root.
package_2ship_extractor_zip() {
    local extractor_rel=$1 xml_rel=$2 zapd_rel=$3
    local extractor_src="$PROJECT_SRC/$extractor_rel"
    local xml_src="$PROJECT_SRC/$xml_rel"
    local zapd_bin="$PROJECT_BUILD/$zapd_rel"

    if [[ ! -d "$extractor_src" || ! -d "$xml_src" ]]; then
        echo "package_2ship_extractor_zip: WARNING: extractor or xml dir missing, skipping"
        return 0
    fi

    local stage="$DESTDIR/assets/tmp_zip"
    mkdir -p "$DESTDIR/assets"
    rm -rf "$stage"
    mkdir -p "$stage/extractor"

    if [[ -f "$zapd_bin" ]]; then
        cp "$zapd_bin" "$stage/extractor/ZAPD.out"
    else
        echo "package_2ship_extractor_zip: WARNING: ZAPD not found at $zapd_bin"
    fi
    cp -r "$extractor_src"/* "$stage/extractor/"
    cp -r "$xml_src" "$stage/"

    (cd "$stage" && zip -r "$DESTDIR/assets/extractor.zip" ./*)
    rm -rf "$stage"
}

# package_torch_assets <project-asset-dirs...>
#   Stage tools/torch + tools/config.yml (if present), zip the listed asset
#   dirs into tools/assets.zip. Preserves any non-staged files already in
#   DESTDIR/tools (otrgen, portVersion, etc.).
package_torch_assets() {
    mkdir -p "$DESTDIR/tools"

    local torch_bin="$PROJECT_BUILD/TorchExternal/src/TorchExternal-build/torch"
    if [[ -f "$torch_bin" ]]; then
        cp "$torch_bin" "$DESTDIR/tools/torch"
    else
        echo "package_torch_assets: WARNING: torch binary not found at $torch_bin"
    fi

    rm -f "$DESTDIR/tools/assets.zip" "$DESTDIR/tools/config.yml"

    if [[ -f "$PROJECT_SRC/config.yml" ]]; then
        cp "$PROJECT_SRC/config.yml" "$DESTDIR/tools/"
    fi

    (cd "$PROJECT_SRC" && zip -r "$DESTDIR/tools/assets.zip" "$@")
}
