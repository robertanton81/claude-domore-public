#!/bin/sh
# M1a physical setup, step: the root-owned runtime folder, part 1 (Python and container).
# Decided 2026-09-29 (Decisions 5 and 26, R1 to R6). The consult, audit and review records
# are in the private working repository.
#
# What it does:
#   Stage A: download two archives into a private staging folder, check their SHA-256
#   and Apple's package signature, unpack them, remove the parts the supervisor never
#   runs, and precompile Python. Downloading, unpacking and compiling run as
#   admin-user without root rights; root only reads the results (hashes, signatures).
#   Every result must match a pin in this file, or the script stops. Until then it has
#   changed nothing outside the staging folder.
#   Stage B, as root: build the runtime folder inside a root-only folder, check every
#   file, folder, mode and signature there, write the manifest, then move it into
#   place as /opt/claude-domore in one step. Last, run live checks as the real accounts.
#
# Before you run it, check that the two URLs below are the official project places:
#   Python:    https://github.com/astral-sh/python-build-standalone  (release 20260924)
#   container: https://github.com/apple/container                    (release 1.5.0)
#
# Run only from the admin-user session, on a private copy that you read first:
#   copy 03-runtime-folder.sh into the admin account home (for example through a shared handover folder)
#   shasum -a 256 ~/03-runtime-folder.sh
#   less ~/03-runtime-folder.sh
#   sudo /bin/sh ~/03-runtime-folder.sh

set -eu

ADMIN=admin-user
SUP=_cdsupervisor
DAILY=daily-user
APPROVER=ai-approver
RT=/opt/claude-domore
INSTALL_TMP=/opt/.claude-domore-install
ADMIN_HOME=/Users/$ADMIN
STAGE=$ADMIN_HOME/cd-stage-03
# The path that the compiled bytecode records. It is the final Python folder.
PY_FINAL=/opt/claude-domore/python

# --- Pinned inputs. Claude computed these in the daily account from its own
# download, after checking SHA256SUMS and the GitHub build attestation (Python)
# and Apple's package signature (container). That is review evidence, not trust:
# what protects you is your own check of the URLs plus these exact hashes.

PY_URL='https://github.com/astral-sh/python-build-standalone/releases/download/20260924/cpython-3.14.7%2B20260924-aarch64-apple-darwin-install_only_stripped.tar.gz'
PY_SHA256=f0fb6b233971672dd7add4efa90f8c209a63253e457ffabd0148b9f734638319
CT_URL='https://github.com/apple/container/releases/download/1.5.0/container-1.5.0-installer-signed.pkg'
CT_SHA256=a24808cb202318fa1c3bbee0c6c6887fe1225fe899d7b687a0ddd939bd6573f8
CT_SIGNER='Developer ID Installer: Apple Inc. - Containerization (UPBK2H6LZM)'
CT_TEAM=UPBK2H6LZM
CT_BOM_ENTRIES=34

# Tree hashes (see tree_hash below). The first three are for the staged trees.
# RT_FILES and RT_DIRS cover the whole new runtime folder before the manifest is
# written: every regular file with its content, and the exact list of folders.
PY_SRC_TREE=06e40aa7c62dbec777a9daa7da75c5341bb0e42418928d5871b71d9fc8314896
PY_PYC_TREE=ee71162e1533992eb0a74b385a9e35f4e3078c69387379b84166254651a77c8d
CT_TREE=0d052141fa58173ffb4b7ff5dbcb44db770444a945135b9a637098d2287811b1
RT_FILES_TREE=b2c752e6ecb57a1f4fee82cc78cd8da887422afe4532755a122ecf91c5efb334
RT_DIRS_TREE=4092ac9492407f82a1846ccefbdfae67b069252b5bbe08902f8062ea99539579
OPENSSL_CNF_SHA256=da30188fce4590a9528e40da39f8a91f886a168709b17b075d9ac02edfc77ff4

# Code-directory hashes (CDHash) of the six Apple-signed container programs.
CT_CODE="bin/container com.apple.container.cli 786e32c0fbbaf5e93e266bf6070c8f640f4fe327
bin/container-apiserver com.apple.container.apiserver 45c7c6580126f39e08c6b9accf2b7bc304e7dca1
libexec/container/plugins/container-core-images/bin/container-core-images com.apple.container.container-core-images ee1fd7ea15c2a6fd8b27c8d5d32d46bbfb27e334
libexec/container/plugins/container-network-vmnet/bin/container-network-vmnet com.apple.container.container-network-vmnet fa56658c26dde50608884e5b2975c71fdfcd4799
libexec/container/plugins/container-runtime-linux/bin/container-runtime-linux com.apple.container.container-runtime-linux e0b452d0cf5130a080a495496041aca2d67eb731
libexec/container/plugins/machine-apiserver/bin/machine-apiserver com.apple.container.machine-apiserver 3e788370eb22c57cda2e38c2f5b3bc791ee8e4cc"

# Parts of the Python tree that the supervisor never runs. Tcl/Tk, tkinter, IDLE and
# turtle can load code through TCLLIBPATH and similar variables; pip and ensurepip
# install packages; the bin wrappers are shell scripts that find tools through PATH;
# libpython is not linked by python3.14; include, share and pkgconfig are build and
# manual data (and hold the only symlinks). The licence file stays.
PY_TRIM="bin/idle3 bin/idle3.14 bin/pip bin/pip3 bin/pip3.14 bin/pydoc3 bin/pydoc3.14
bin/python bin/python3 bin/python3-config bin/python3.14-config
lib/itcl4.3.8 lib/libtcl9.0.dylib lib/libtcl9tk9.0.dylib lib/tcl9 lib/tcl9.0 lib/thread3.0.6 lib/tk9.0
lib/libpython3.14.dylib lib/pkgconfig include share
lib/python3.14/tkinter lib/python3.14/idlelib lib/python3.14/turtledemo lib/python3.14/turtle.py
lib/python3.14/lib-dynload/_tkinter.cpython-314-darwin.so
lib/python3.14/site-packages/pip lib/python3.14/site-packages/pip-26.2.1.dist-info
lib/python3.14/ensurepip"

# Parts of the container tree that are removed: the updater downloads "latest" and can
# fall back to the unsigned package; the uninstaller assumes /usr/local; k8s is an
# optional CLI plugin.
CT_TRIM="bin/update-container.sh bin/uninstall-container.sh libexec/container/plugins/k8s"

if [ "$(/usr/bin/id -u)" -ne 0 ]; then
  echo "Run this with sudo." >&2
  exit 1
fi

# The script's own hash goes into the manifest; take it before the cd below.
case "$0" in
  03-runtime-folder.sh|*/03-runtime-folder.sh) ;;
  *) echo "Start this script from its file: sudo /bin/sh ~/03-runtime-folder.sh" >&2; exit 1 ;;
esac
if [ ! -f "$0" ]; then
  echo "Start this script from its file: sudo /bin/sh ~/03-runtime-folder.sh" >&2
  exit 1
fi
SCRIPT_SHA256=$(/usr/bin/shasum -a 256 "$0" | /usr/bin/cut -d' ' -f1)
case "$SCRIPT_SHA256" in
  *[!0-9a-f]*|'') echo "Cannot hash this script ($0)." >&2; exit 1 ;;
esac
if [ ${#SCRIPT_SHA256} -ne 64 ]; then
  echo "Cannot hash this script ($0)." >&2
  exit 1
fi

# Commands run as other accounts start in the current folder; / is safe for all.
cd /
umask 022

# --- Failure messages. STATE says how far the script got, so every exit can say
# truthfully what exists now and how to undo it.
STATE=none
on_exit() {
  status=$?
  case "$STATE" in
    staging)   echo "STOPPED in stage A (exit $status). Nothing outside $STAGE was changed." >&2
               echo "Remove it with: sudo rm -rf $STAGE" >&2 ;;
    private)   echo "STOPPED in stage B (exit $status), before $RT was created." >&2
               echo "Remove the leftovers with: sudo rm -rf $INSTALL_TMP $STAGE" >&2 ;;
    moving)    echo "STOPPED (exit $status) while moving the tree into place." >&2
               echo "Undo: sudo rm -rf $RT $INSTALL_TMP $STAGE   (this run created all three), then run the script again." >&2 ;;
    installed) echo "FAILED (exit $status): $RT exists, but it did not pass every check." >&2
               echo "Undo: sudo rm -rf $RT $RT.probe $INSTALL_TMP $STAGE   (this run created them), then run the script again." >&2 ;;
    cleanup)   echo "All checks passed and $RT is installed, but removing $STAGE failed." >&2
               echo "Remove it with: sudo rm -rf $STAGE" >&2 ;;
  esac
}
trap on_exit EXIT
trap 'exit 1' INT TERM HUP

refuse() { echo "$1 Nothing changed." >&2; exit 1; }
stop()   { echo "STOPPED: $1" >&2; exit 1; }

# Runs a command as the admin account, without root rights, with a fixed environment.
as_admin() { /usr/bin/sudo -u "$ADMIN" /usr/bin/env -i HOME="$ADMIN_HOME" PATH=/usr/bin:/bin:/usr/sbin:/sbin LC_ALL=C "$@"; }

sha256_of() { /usr/bin/shasum -a 256 "$1" | /usr/bin/cut -d' ' -f1; }

# tree_hash <folder> src|pyc|all: one SHA-256 over the sorted lines "<sha256>  ./<path>"
# of the regular files in the folder. src leaves out __pycache__, pyc takes only it.
# A find failure makes the whole result fail.
tree_hash() {
  (
    cd "$1" || exit 1
    case "$2" in
      src) list=$(/usr/bin/find . -type f ! -path '*/__pycache__/*' -print) || exit 1 ;;
      pyc) list=$(/usr/bin/find . -type f -path '*/__pycache__/*' -print) || exit 1 ;;
      all) list=$(/usr/bin/find . -type f -print) || exit 1 ;;
      noman) list=$(/usr/bin/find . -type f ! -path './manifest/*' -print) || exit 1 ;;
    esac
    printf '%s\n' "$list" | LC_ALL=C /usr/bin/sort | while IFS= read -r f; do
      printf '%s  %s\n' "$(/usr/bin/shasum -a 256 "$f" | /usr/bin/cut -d' ' -f1)" "$f"
    done | /usr/bin/shasum -a 256 | /usr/bin/cut -d' ' -f1
  )
}

# dirs_hash <folder>: one SHA-256 over the sorted list of folders in the folder.
dirs_hash() {
  (
    cd "$1" || exit 1
    list=$(/usr/bin/find . -type d -print) || exit 1
    printf '%s\n' "$list" | LC_ALL=C /usr/bin/sort | /usr/bin/shasum -a 256 | /usr/bin/cut -d' ' -f1
  )
}

# check_code <folder>: every container program has Apple's signature, its own
# identifier, the Containerization team, and the pinned CDHash.
check_code() {
  printf '%s\n' "$CT_CODE" | while read -r f id cdh; do
    req="identifier \"$id\" and anchor apple generic and certificate 1[field.1.2.840.113635.100.6.2.6] exists and certificate leaf[field.1.2.840.113635.100.6.1.13] exists and certificate leaf[subject.OU] = \"$CT_TEAM\""
    /usr/bin/codesign --verify --strict -R="$req" "$1/$f" 2>/dev/null || { echo "signature check failed: $f"; exit 1; }
    got=$(/usr/bin/codesign -dvvv "$1/$f" 2>&1 | /usr/bin/awk -F= '/^CDHash=/{print $2}')
    [ "$got" = "$cdh" ] || { echo "CDHash of $f is $got, expected $cdh"; exit 1; }
  done
}

# The pinned OpenSSL config: comments only, so it adds no provider, engine or include
# directive (OpenSSL's built-in default provider still applies).
write_openssl_cnf() {
  printf '%s\n' "# claude-domore: pinned OpenSSL config. It is empty on purpose: it loads no providers," "# engines or includes. The launcher sets OPENSSL_CONF to this file."
}

# bad_entries <folder>: lists any entry with a wrong owner, mode, ACL, link or type.
bad_entries() {
  /usr/bin/find "$1" \( ! -user root -o ! -group wheel -o -perm -g+w -o -perm -o+w -o -perm -4000 -o -perm -2000 -o -perm -1000 \
    -o \( ! -type f ! -type d \) -o \( -type f -links +1 \) -o -acl \
    -o \( -type d ! -perm 755 \) -o \( -type f ! -perm 644 ! -perm 755 \) \) -print
}

# rt_intact: the installed folder is exactly the checked tree plus its manifest,
# and Python's parent-folder search finds nothing. Prints the first problem.
rt_intact() {
  [ ! -e /opt/lib ] && [ ! -L /opt/lib ] && [ ! -e "$RT/lib" ] && [ ! -L "$RT/lib" ] || { echo "a lib folder exists above Python"; return 1; }
  got=$(dirs_hash "$RT") && [ "$got" = "$RT_DIRS_TREE" ] || { echo "folder list differs"; return 1; }
  got=$(tree_hash "$RT" noman) && [ "$got" = "$RT_FILES_TREE" ] || { echo "files differ"; return 1; }
  got=$(sha256_of "$RT/manifest/files.sha256") && [ "$got" = "$RT_FILES_TREE" ] || { echo "manifest differs"; return 1; }
  got=$(bad_entries "$RT") && [ -z "$got" ] || { echo "owner, mode, ACL, link or type: $got"; return 1; }
}

# --- Checks before any change. Each one refuses and changes nothing.

[ "${SUDO_USER:-}" = "$ADMIN" ] || refuse "Run this with sudo from the $ADMIN session (SUDO_USER is '${SUDO_USER:-}')."
for account in "$ADMIN" "$SUP" "$DAILY" "$APPROVER"; do
  /usr/bin/dscl . -read "/Users/$account" UniqueID >/dev/null 2>&1 || refuse "Account $account does not exist."
done
for account in "$DAILY" "$APPROVER"; do
  MEMBERSHIP=$(/usr/bin/dsmemberutil checkmembership -U "$account" -G admin)
  [ "$MEMBERSHIP" = "user is not a member of the group" ] || refuse "$account is an admin, or its membership is unknown ($MEMBERSHIP)."
done

if [ ! -d /opt ] || [ -L /opt ]; then refuse "/opt is missing or is a symlink."; fi
OPT_UID=$(/usr/bin/stat -f %u /opt)
[ "$OPT_UID" = 0 ] || refuse "/opt is not owned by root."
OPT_MODE=$(/usr/bin/stat -f %Sp /opt) || refuse "Cannot read the mode of /opt."
case "$OPT_MODE" in
  d????w????|d???????w?) refuse "/opt is writable by group or others." ;;
esac
OPT_ACL=$(/usr/bin/find /opt -maxdepth 0 -acl -print) || refuse "Cannot read the ACL of /opt."
[ -z "$OPT_ACL" ] || refuse "/opt has an ACL."
# Python searches every parent folder for lib/python314.zip; none may exist.
if [ -e /opt/lib ] || [ -L /opt/lib ]; then refuse "/opt/lib exists (Python would search it)."; fi
for p in "$RT" "$INSTALL_TMP" "$STAGE"; do
  if [ -e "$p" ] || [ -L "$p" ]; then refuse "$p already exists (remove it first: sudo rm -rf $p)."; fi
done

# --- Stage A: download, check and prepare. Unpacking and compiling run as the admin
# account without root rights. Root only reads the results.

echo "--- stage A: download and check"
STATE=staging
as_admin /bin/mkdir -m 700 "$STAGE"
as_admin /bin/mkdir -m 700 "$STAGE/ctx" "$STAGE/py"
as_admin /bin/mkdir -m 755 "$STAGE/ct"

write_openssl_cnf | as_admin /bin/sh -c 'umask 022; /bin/cat > "$1"' _ "$STAGE/openssl.cnf"
GOT=$(sha256_of "$STAGE/openssl.cnf")
[ "$GOT" = "$OPENSSL_CNF_SHA256" ] || stop "staged openssl.cnf SHA-256 is $GOT, expected $OPENSSL_CNF_SHA256."

# curl: -q (first) ignores any curl config file; env -i removed proxy variables.
as_admin /usr/bin/curl -q --proto '=https' --tlsv1.2 -fsSL -o "$STAGE/python.tar.gz" "$PY_URL" || stop "Python download failed."
as_admin /usr/bin/curl -q --proto '=https' --tlsv1.2 -fsSL -o "$STAGE/container.pkg" "$CT_URL" || stop "container download failed."

GOT=$(sha256_of "$STAGE/python.tar.gz")
[ "$GOT" = "$PY_SHA256" ] || stop "Python archive SHA-256 is $GOT, expected $PY_SHA256."
echo "ok  Python archive SHA-256 matches"
GOT=$(sha256_of "$STAGE/container.pkg")
[ "$GOT" = "$CT_SHA256" ] || stop "container package SHA-256 is $GOT, expected $CT_SHA256."
echo "ok  container package SHA-256 matches"

SIG=$(as_admin /usr/sbin/pkgutil --check-signature "$STAGE/container.pkg") || stop "pkgutil --check-signature failed."
printf '%s\n' "$SIG" | /usr/bin/grep -qF "Status: signed by a developer certificate issued by Apple for distribution" || stop "container package: not signed for distribution."
printf '%s\n' "$SIG" | /usr/bin/grep -qF "Notarization: trusted by the Apple notary service" || stop "container package: not notarized."
printf '%s\n' "$SIG" | /usr/bin/grep -qF "1. $CT_SIGNER" || stop "container package: signer is not '$CT_SIGNER'."
echo "ok  container package signed by $CT_SIGNER and notarized"

# The package must hold exactly Bom, PackageInfo and Payload (no install scripts).
TOC=$(as_admin /usr/bin/xar -tf "$STAGE/container.pkg") || stop "xar cannot list the container package."
TOC=$(printf '%s\n' "$TOC" | LC_ALL=C /usr/bin/sort | /usr/bin/tr '\n' ' ')
[ "$TOC" = "Bom PackageInfo Payload " ] || stop "container package holds '$TOC', expected 'Bom PackageInfo Payload'."
as_admin /usr/bin/xar -xf "$STAGE/container.pkg" -C "$STAGE/ctx" || stop "xar cannot unpack the container package."
# lsbom exits 0 even for a missing or broken Bom; the entry count below is the real guard.
BOMLIST=$(as_admin /usr/bin/lsbom -p fMUG "$STAGE/ctx/Bom") || stop "lsbom cannot read the container Bom."
[ "$(printf '%s\n' "$BOMLIST" | /usr/bin/wc -l | /usr/bin/tr -d ' ')" = "$CT_BOM_ENTRIES" ] || stop "container Bom does not have $CT_BOM_ENTRIES entries."
BAD=$(printf '%s\n' "$BOMLIST" | /usr/bin/awk -F'\t' '$2 !~ /^[d-]rwxr-xr-x *$/ || $3 != "root" || $4 != "wheel"')
[ -z "$BAD" ] || stop "container Bom has unexpected modes or owners: $BAD"
as_admin /bin/sh -c 'cd "$1" && /bin/pax -rz -f "$2"' _ "$STAGE/ct" "$STAGE/ctx/Payload" || stop "pax cannot unpack the container payload."
as_admin /bin/sh -c '
  cd "$1" || exit 1
  list=$(/usr/bin/lsbom -f -p fc "$2") || exit 1
  [ -n "$list" ] || exit 1
  TAB=$(printf "\t")
  printf "%s\n" "$list" | while IFS="$TAB" read -r f c; do
    got=$(/usr/bin/cksum "$f" | /usr/bin/awk "{print \$1}")
    [ "$got" = "$c" ] || { echo "Bom checksum mismatch: $f"; exit 1; }
  done' _ "$STAGE/ct" "$STAGE/ctx/Bom" || stop "container payload does not match its Bom."
for p in $CT_TRIM; do as_admin /bin/rm -rf "$STAGE/ct/$p" || stop "cannot remove $p from the container tree."; done
check_code "$STAGE/ct" || stop "container code signature check failed."
echo "ok  6 container programs: Apple signature, identifiers and CDHashes match"

as_admin /usr/bin/tar -xzf "$STAGE/python.tar.gz" -C "$STAGE/py" || stop "tar cannot unpack the Python archive."
[ "$(/bin/ls "$STAGE/py")" = "python" ] || stop "Python archive does not have the single top folder 'python'."
for p in $PY_TRIM; do as_admin /bin/rm -rf "$STAGE/py/python/$p" || stop "cannot remove $p from the Python tree."; done
as_admin /usr/bin/find "$STAGE/py/python" -name __pycache__ -type d -prune -exec /bin/rm -rf {} + || stop "cannot remove old bytecode."
# Precompile with checked hashes and the pinned OpenSSL config. -s/-p record the
# final path in each .pyc file.
as_admin OPENSSL_CONF="$STAGE/openssl.cnf" /bin/sh -c 'cd / && "$1/bin/python3.14" -I -X disable-remote-debug -m compileall -q -f -j 0 --invalidation-mode checked-hash -s "$1" -p "$2" "$1/lib/python3.14"' _ "$STAGE/py/python" "$PY_FINAL" \
  || stop "Python precompile failed."

GOT=$(tree_hash "$STAGE/py/python" src) || stop "cannot hash the Python tree."
[ "$GOT" = "$PY_SRC_TREE" ] || stop "Python tree (sources) is $GOT, expected $PY_SRC_TREE."
GOT=$(tree_hash "$STAGE/py/python" pyc) || stop "cannot hash the Python bytecode."
[ "$GOT" = "$PY_PYC_TREE" ] || stop "Python tree (bytecode) is $GOT, expected $PY_PYC_TREE."
GOT=$(tree_hash "$STAGE/ct" all) || stop "cannot hash the container tree."
[ "$GOT" = "$CT_TREE" ] || stop "container tree is $GOT, expected $CT_TREE."
echo "ok  trimmed trees match the pinned tree hashes (Python sources, Python bytecode, container)"

# --- Stage B, as root. The new tree is built inside a folder that only root can
# enter, and becomes visible as $RT only after every check below has passed.

echo "--- stage B: build and check inside $INSTALL_TMP (root only)"
STATE=private
NEW=$INSTALL_TMP/claude-domore
/bin/mkdir -m 700 "$INSTALL_TMP"
/usr/sbin/chown root:wheel "$INSTALL_TMP"
/bin/chmod -N "$INSTALL_TMP"
/bin/mkdir -m 755 "$NEW"
/usr/bin/ditto --noextattr --noqtn --noacl --norsrc "$STAGE/py/python" "$NEW/python"
/usr/bin/ditto --noextattr --noqtn --noacl --norsrc "$STAGE/ct" "$NEW/container"
/bin/mkdir -m 755 "$NEW/etc" "$NEW/approval-policy" "$NEW/manifest"
# Root writes the config itself, in a folder that only root can reach.
write_openssl_cnf > "$NEW/etc/openssl.cnf"
/usr/sbin/chown -R root:wheel "$NEW"
/bin/chmod -R go-w "$NEW"
/bin/chmod -R -N "$NEW"
/usr/bin/find "$NEW" -type d -exec /bin/chmod 755 {} +
/bin/chmod 644 "$NEW/etc/openssl.cnf"

# Gate: every check here stops the script. Nothing from the new tree runs before all
# of them pass.
GOT=$(sha256_of "$NEW/etc/openssl.cnf")
[ "$GOT" = "$OPENSSL_CNF_SHA256" ] || stop "installed openssl.cnf SHA-256 is $GOT, expected $OPENSSL_CNF_SHA256."
GOT=$(tree_hash "$NEW/python" src) || stop "cannot hash the new Python tree."
[ "$GOT" = "$PY_SRC_TREE" ] || stop "new Python sources are $GOT, expected $PY_SRC_TREE."
GOT=$(tree_hash "$NEW/python" pyc) || stop "cannot hash the new Python bytecode."
[ "$GOT" = "$PY_PYC_TREE" ] || stop "new Python bytecode is $GOT, expected $PY_PYC_TREE."
GOT=$(tree_hash "$NEW/container" all) || stop "cannot hash the new container tree."
[ "$GOT" = "$CT_TREE" ] || stop "new container tree is $GOT, expected $CT_TREE."
GOT=$(tree_hash "$NEW" all) || stop "cannot hash the new runtime folder."
[ "$GOT" = "$RT_FILES_TREE" ] || stop "new runtime folder files are $GOT, expected $RT_FILES_TREE (an extra or missing file)."
GOT=$(dirs_hash "$NEW") || stop "cannot list the folders of the new runtime folder."
[ "$GOT" = "$RT_DIRS_TREE" ] || stop "new runtime folder list is $GOT, expected $RT_DIRS_TREE (an extra or missing folder)."
check_code "$NEW/container" || stop "new container signatures do not match."
BAD=$(bad_entries "$NEW") || stop "cannot inspect the new runtime folder."
[ -z "$BAD" ] || stop "unexpected owner, mode, ACL, link or file type: $BAD"
echo "ok  new runtime folder: files, folders, modes, owners, signatures and openssl.cnf match"

# The manifest: every installed file with its hash, plus where it came from.
( cd "$NEW" && /usr/bin/find . -type f ! -path './manifest/*' -print | LC_ALL=C /usr/bin/sort | while IFS= read -r f; do
    printf '%s  %s\n' "$(/usr/bin/shasum -a 256 "$f" | /usr/bin/cut -d' ' -f1)" "$f"
  done ) > "$NEW/manifest/files.sha256"
{
  echo "claude-domore runtime folder, part 1 (Python and container)"
  echo "built_utc: $(/bin/date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "macos: $(/usr/bin/sw_vers -productVersion) build $(/usr/bin/sw_vers -buildVersion)"
  echo "script_sha256: $SCRIPT_SHA256"
  echo "python_url: $PY_URL"
  echo "python_sha256: $PY_SHA256"
  echo "python_version: CPython 3.14.7, python-build-standalone 20260924, aarch64-apple-darwin, install_only_stripped"
  echo "python_bundled: OpenSSL 3.5.8, SQLite 3.53.1"
  echo "python_evidence: SHA256SUMS match and gh attestation verify (SLSA provenance, release.yml on main of astral-sh/python-build-standalone), checked by Claude in the daily account"
  echo "python_trimmed: $(printf '%s' "$PY_TRIM" | /usr/bin/tr '\n' ' ')"
  echo "python_tree_src: $PY_SRC_TREE"
  echo "python_tree_pyc: $PY_PYC_TREE (compileall --invalidation-mode checked-hash)"
  echo "container_url: $CT_URL"
  echo "container_sha256: $CT_SHA256"
  echo "container_signer: $CT_SIGNER (pkgutil --check-signature, checked by root on the admin's download)"
  echo "container_trimmed: $CT_TRIM"
  echo "container_tree: $CT_TREE"
  printf '%s\n' "$CT_CODE" | while read -r f id cdh; do echo "container_cdhash: $f $id $cdh"; done
  echo "openssl_cnf_sha256: $OPENSSL_CNF_SHA256"
  echo "runtime_files_tree: $RT_FILES_TREE"
  echo "runtime_dirs_tree: $RT_DIRS_TREE"
} > "$NEW/manifest/provenance.txt"
/usr/sbin/chown root:wheel "$NEW/manifest/files.sha256" "$NEW/manifest/provenance.txt"
/bin/chmod 644 "$NEW/manifest/files.sha256" "$NEW/manifest/provenance.txt"
# files.sha256 holds exactly the lines that RT_FILES_TREE hashes.
GOT=$(sha256_of "$NEW/manifest/files.sha256")
[ "$GOT" = "$RT_FILES_TREE" ] || stop "the manifest does not match the checked tree."

# Make it visible in one step. $RT must still be absent, or mv would put the tree
# inside it.
if [ -e "$RT" ] || [ -L "$RT" ]; then stop "$RT appeared during the run; not moving the tree."; fi
STATE=moving
/bin/mv "$NEW" "$RT"
STATE=installed
/bin/rmdir "$INSTALL_TMP"
# Gate after the move: nothing runs from $RT unless it is exactly the checked tree.
PROBLEM=$(rt_intact) || stop "$RT after the move: $PROBLEM"
echo "ok  moved into place as $RT and checked again"

# --- Live checks. Root runs each command as the named account (sudo -u needs no
# password for root), with a fixed environment. These are install checks, not the
# M1a checks: V1 and test 29a still run later, through the real launcher.

echo "--- live checks"
FAILS=0
# check allowed|denied <description> <command>: for access tests.
check() {
  expect=$1; desc=$2; shift 2
  if "$@" >/dev/null 2>&1; then got=allowed; else got=denied; fi
  if [ "$got" = "$expect" ]; then
    echo "PASS  $desc: $got"
  else
    echo "FAIL  $desc: $got, expected $expect"
    FAILS=$((FAILS + 1))
  fi
}
# verify <description> <command>: PASS when the command succeeds.
verify() {
  desc=$1; shift
  if "$@" >/dev/null 2>&1; then
    echo "PASS  $desc"
  else
    echo "FAIL  $desc"
    FAILS=$((FAILS + 1))
  fi
}
as() { user=$1; shift; /usr/bin/sudo -u "$user" /usr/bin/env -i HOME=/var/empty PATH=/usr/bin:/bin:/usr/sbin:/sbin LC_ALL=C "$@"; }

PY="$RT/python/bin/python3.14"
PYCHECK='
import sys, sqlite3, ssl, hashlib, json, subprocess, socket, ctypes
rt = sys.argv[1]
assert sys.prefix == rt and sys.exec_prefix == rt, sys.prefix
assert all(p.startswith(rt + "/") for p in sys.path), sys.path
assert sys.flags.isolated == 1 and not sys.is_remote_debug_enabled()
assert sqlite3.sqlite_version == "3.53.1", sqlite3.sqlite_version
assert ssl.OPENSSL_VERSION.startswith("OpenSSL 3.5.8"), ssl.OPENSSL_VERSION
assert hashlib.sha256(b"").hexdigest().startswith("e3b0c442")
ssl.create_default_context(cafile="/private/etc/ssl/cert.pem")
try:
    import tkinter
    raise SystemExit("tkinter is still present")
except ModuleNotFoundError:
    pass
'

is_user()          { [ "$(as "$1" /usr/bin/id -un)" = "$1" ]; }
bytecode_fresh()   {
  out=$(as "$SUP" OPENSSL_CONF="$RT/etc/openssl.cnf" "$PY" -I -X disable-remote-debug -v -c 'import json, sqlite3, ssl, hashlib, subprocess, socket, ctypes' 2>&1) || return 1
  ! printf '%s' "$out" | /usr/bin/grep -q 'could not create'
}
container_version() {
  out=$(as "$SUP" CONTAINER_INSTALL_ROOT="$RT/container" "$RT/container/bin/container" --version 2>&1) || return 1
  printf '%s' "$out" | /usr/bin/grep -q '1\.5\.0.*d265d66'
}

# Positive controls: each account really runs commands through "as".
for account in "$DAILY" "$SUP" "$APPROVER"; do
  verify "$account runs commands through sudo -u (positive control)" is_user "$account"
done
verify "$SUP runs Python with the pinned config (versions, paths, no tkinter, remote debug off)" \
  as "$SUP" OPENSSL_CONF="$RT/etc/openssl.cnf" "$PY" -I -X disable-remote-debug -c "$PYCHECK" "$RT/python"
verify "$SUP Python finds valid bytecode for a sample of imports (no 'could not create')" bytecode_fresh
verify "$SUP runs container --version (1.5.0, commit d265d66; an install smoke test, not V1)" container_version

# Write probes: a new file in each folder, and a change to existing files.
for account in "$DAILY" "$SUP" "$APPROVER"; do
  for dir in "$RT" "$RT/python/bin" "$RT/python/lib/python3.14" "$RT/python/lib/python3.14/__pycache__" \
             "$RT/python/lib/python3.14/site-packages" "$RT/python/lib/python3.14/lib-dynload" \
             "$RT/container/bin" "$RT/etc" "$RT/approval-policy" "$RT/manifest"; do
    verify "probe target $dir exists" [ -d "$dir" ]
    check denied "$account creates a file in $dir" as "$account" /usr/bin/touch "$dir/probe-write"
  done
  for file in "$RT/python/bin/python3.14" "$RT/etc/openssl.cnf" "$RT/container/bin/container" "$RT/manifest/files.sha256"; do
    verify "probe target $file exists" [ -f "$file" ]
    check denied "$account opens $file for writing" as "$account" /bin/sh -c ': >> "$1"' _ "$file"
  done
done
# Renames last: if one ever succeeded, it could not hide the other probes' results.
for account in "$DAILY" "$SUP" "$APPROVER"; do
  check denied "$account renames $RT/etc" as "$account" /bin/mv "$RT/etc" "$RT/etc.probe"
  check denied "$account renames $RT" as "$account" /bin/mv "$RT" "$RT.probe"
done

# After the probes, the whole folder must be unchanged, and no probe copy may exist.
verify "$RT unchanged after the probes (files, folders, manifest, modes)" rt_intact
verify "no $RT.probe left by a rename probe" [ ! -e "$RT.probe" ]

if [ "$FAILS" -ne 0 ]; then
  echo "--- $FAILS check(s) FAILED"
  exit 1
fi

echo "live_checks: passed $(/bin/date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$RT/manifest/provenance.txt"
STATE=cleanup
/bin/rm -rf "$STAGE"
STATE=done
echo "--- all checks passed"
echo "--- manifest: $RT/manifest/files.sha256 ($(/usr/bin/wc -l < "$RT/manifest/files.sha256" | /usr/bin/tr -d ' ') files)"
echo "--- done"
