#!/bin/sh
# M1a physical setup, step: create the exchange folders and the socket folder.
# Design: docs/design/architecture.md, "The input socket and the exchange folders"
# (Decision 26, part 26d).
#
#   /opt/claude-domore-exchange/   root:wheel 755   only root can add, rename or replace a child
#     socket/        _cdsupervisor 700  + "search" for daily-user and ai-approver
#                                        (they pass through to the socket; they cannot list or write)
#     evidence/      _cdsupervisor 700  + read for daily-user (the daily account)
#     inbox-view/    _cdsupervisor 700  + read for ai-approver (the approval account)
#
# The socket file itself, and its ACL entry, are made by the supervisor when it
# binds the socket (M1a code; M1a check 2 tests whether macOS honours that ACL).
#
# Run only from the admin-user session, on a private copy that you read first:
#   copy 02-exchange-folders.sh into the admin account home (for example through a shared handover folder)
#   shasum -a 256 ~/02-exchange-folders.sh
#   less ~/02-exchange-folders.sh
#   sudo /bin/sh ~/02-exchange-folders.sh

set -eu

SUP=_cdsupervisor
DAILY=daily-user
APPROVER=ai-approver
PARENT=/opt/claude-domore-exchange

if [ "$(/usr/bin/id -u)" -ne 0 ]; then
  echo "Run this with sudo." >&2
  exit 1
fi

# Commands run as other accounts start in the current folder. Start in /, which
# every account can enter (the admin's home would give a harmless getcwd warning).
cd /

# --- Checks before any change. Each one refuses and changes nothing.

refuse() { echo "$1 Nothing changed." >&2; exit 1; }

for account in "$SUP" "$DAILY" "$APPROVER"; do
  /usr/bin/dscl . -read "/Users/$account" UniqueID >/dev/null 2>&1 || refuse "Account $account does not exist."
done
# Both callers must be standard accounts. The answer is captured first, so
# that a dsmemberutil failure stops the script (set -e).
for account in "$DAILY" "$APPROVER"; do
  MEMBERSHIP=$(/usr/bin/dsmemberutil checkmembership -U "$account" -G admin)
  if [ "$MEMBERSHIP" != "user is not a member of the group" ]; then
    refuse "$account is an admin, or its membership is unknown ($MEMBERSHIP); it must be a standard account."
  fi
done

if [ ! -d /opt ] || [ -L /opt ]; then refuse "/opt is missing or is a symlink."; fi
OPT_UID=$(/usr/bin/stat -f %u /opt)
if [ "$OPT_UID" != 0 ]; then refuse "/opt is not owned by root."; fi
case "$(/usr/bin/stat -f %Sp /opt)" in
  d????w????|d???????w?) refuse "/opt is writable by group or others." ;;
esac
if /bin/ls -led /opt | /usr/bin/awk 'NR > 1 { found = 1 } END { exit !found }'; then refuse "/opt has an ACL."; fi
if [ -e "$PARENT" ] || [ -L "$PARENT" ]; then refuse "$PARENT already exists."; fi

# --- Changes. If one fails, say what exists now and how to undo it.

on_exit() {
  status=$?
  if [ "$status" -ne 0 ] && [ -d "$PARENT" ]; then
    echo "" >&2
    echo "FAILED (exit $status). $PARENT exists now, but it is not correct." >&2
    echo "Undo (it holds only empty folders): sudo rm -r $PARENT" >&2
    echo "Then run this script again." >&2
  fi
}
trap on_exit EXIT

# The parent: root-owned, so no other account can create, rename or replace a child.
/bin/mkdir -m 755 "$PARENT"
/usr/sbin/chown root:wheel "$PARENT"
/bin/chmod -N "$PARENT"

make_child() {
  /bin/mkdir -m 700 "$PARENT/$1"
  /usr/sbin/chown "$SUP:$SUP" "$PARENT/$1"
  /bin/chmod -N "$PARENT/$1"
}

# A reader gets two entries: one for folders (list and pass through), and one
# that only new files take (read, no execute).
add_reader() {
  /bin/chmod +a "user:$2 allow list,search,readattr,readextattr,readsecurity,directory_inherit" "$PARENT/$1"
  /bin/chmod +a "user:$2 allow read,readattr,readextattr,readsecurity,file_inherit,directory_inherit,only_inherit" "$PARENT/$1"
}

make_child socket
/bin/chmod +a "user:$DAILY allow search" "$PARENT/socket"
/bin/chmod +a "user:$APPROVER allow search" "$PARENT/socket"

make_child evidence
add_reader evidence "$DAILY"

make_child inbox-view
add_reader inbox-view "$APPROVER"

# --- Result. Expected values are in the comments.

echo "--- result"
# Expected: the parent root wheel drwxr-xr-x with no ACL lines.
# socket: _cdsupervisor drwx------+ with "allow search" for daily-user and ai-approver.
# evidence: _cdsupervisor drwx------+ with two daily-user entries.
# inbox-view: _cdsupervisor drwx------+ with two ai-approver entries.
/bin/ls -led "$PARENT" "$PARENT/socket" "$PARENT/evidence" "$PARENT/inbox-view"

# --- Live checks. Root runs each command as the named account (sudo -u needs
# no password for root), and only with root-owned tools.

echo "--- live checks"
FAILS=0
# expect: "allowed" or "denied"
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
as() { user=$1; shift; /usr/bin/sudo -u "$user" "$@"; }

check denied  "$DAILY lists socket/"         as "$DAILY"    /bin/ls "$PARENT/socket"
check denied  "$APPROVER lists socket/"      as "$APPROVER" /bin/ls "$PARENT/socket"
check allowed "$DAILY lists evidence/"       as "$DAILY"    /bin/ls "$PARENT/evidence"
check denied  "$APPROVER lists evidence/"    as "$APPROVER" /bin/ls "$PARENT/evidence"
check denied  "$DAILY lists inbox-view/"     as "$DAILY"    /bin/ls "$PARENT/inbox-view"
check allowed "$APPROVER lists inbox-view/"  as "$APPROVER" /bin/ls "$PARENT/inbox-view"
for folder in socket evidence inbox-view; do
  check denied "$DAILY writes $folder/"      as "$DAILY"    /usr/bin/touch "$PARENT/$folder/probe-write"
  check denied "$APPROVER writes $folder/"   as "$APPROVER" /usr/bin/touch "$PARENT/$folder/probe-write"
done

# Inheritance: a file that the supervisor creates inside a folder is readable
# by that folder's one reader only.
as "$SUP" /bin/sh -c "echo probe > '$PARENT/evidence/probe' && echo probe > '$PARENT/inbox-view/probe'"
check allowed "$DAILY reads a new evidence file"        as "$DAILY"    /bin/cat "$PARENT/evidence/probe"
check denied  "$APPROVER reads a new evidence file"     as "$APPROVER" /bin/cat "$PARENT/evidence/probe"
check allowed "$APPROVER reads a new inbox-view file"   as "$APPROVER" /bin/cat "$PARENT/inbox-view/probe"
check denied  "$DAILY reads a new inbox-view file"      as "$DAILY"    /bin/cat "$PARENT/inbox-view/probe"
/bin/ls -le "$PARENT/evidence/probe" "$PARENT/inbox-view/probe"
as "$SUP" /bin/rm -f "$PARENT/evidence/probe" "$PARENT/inbox-view/probe"

if [ "$FAILS" -ne 0 ]; then
  echo "--- $FAILS check(s) FAILED"
  exit 1
fi
echo "--- all checks passed"
echo "--- done"
