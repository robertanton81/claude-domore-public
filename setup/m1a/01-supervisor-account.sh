#!/bin/sh
# M1a physical setup, step: create the supervisor account and its data folder.
# Decided 2026-09-28 (Decision 26, "the supervisor account").
#
# Run only from the admin-user session, on a private copy that you read first:
#   copy 01-supervisor-account.sh into the admin account home (for example through a shared handover folder)
#   less ~/01-supervisor-account.sh
#   sudo /bin/sh ~/01-supervisor-account.sh
# The admin account never runs a file that the daily account can write, so it
# runs its own copy, not the file in the repository.

set -eu

NAME=_cdsupervisor
ID=350
DATA=/opt/claude-domore-data

if [ "$(/usr/bin/id -u)" -ne 0 ]; then
  echo "Run this with sudo." >&2
  exit 1
fi

# --- Checks before any change. Each one refuses and changes nothing.

refuse() { echo "$1 Nothing changed." >&2; exit 1; }

if /usr/bin/dscl . -read "/Users/$NAME" >/dev/null 2>&1; then refuse "User $NAME already exists."; fi
if /usr/bin/dscl . -read "/Groups/$NAME" >/dev/null 2>&1; then refuse "Group $NAME already exists."; fi

# The dscl output goes into a variable first, so that a dscl failure stops the
# script (set -e) instead of looking like "the id is free".
USER_IDS=$(/usr/bin/dscl . -list /Users UniqueID)
GROUP_IDS=$(/usr/bin/dscl . -list /Groups PrimaryGroupID)
if printf '%s\n' "$USER_IDS" | /usr/bin/awk -v id="$ID" '$2 == id { found = 1 } END { exit !found }'; then refuse "UID $ID is taken."; fi
if printf '%s\n' "$GROUP_IDS" | /usr/bin/awk -v id="$ID" '$2 == id { found = 1 } END { exit !found }'; then refuse "GID $ID is taken."; fi
if /usr/bin/id "$ID" >/dev/null 2>&1; then refuse "UID $ID resolves in some directory."; fi

# The parent of the data folder must be a real folder, owned by root, with no
# group or other write bit and no ACL.
if [ ! -d /opt ] || [ -L /opt ]; then refuse "/opt is missing or is a symlink."; fi
if [ "$(/usr/bin/stat -f %u /opt)" -ne 0 ]; then refuse "/opt is not owned by root."; fi
case "$(/usr/bin/stat -f %Sp /opt)" in
  d????w????|d???????w?) refuse "/opt is writable by group or others." ;;
esac
if /bin/ls -led /opt | /usr/bin/awk 'NR > 1 { found = 1 } END { exit !found }'; then refuse "/opt has an ACL."; fi
if [ -e "$DATA" ] || [ -L "$DATA" ]; then refuse "$DATA already exists."; fi

# --- Changes. If one fails, say what exists now and how to undo it.

on_exit() {
  status=$?
  if [ "$status" -ne 0 ]; then
    echo "" >&2
    echo "FAILED part way (exit $status). What exists now:" >&2
    /usr/bin/dscl . -read "/Users/$NAME" >/dev/null 2>&1 && echo "  user $NAME  -> undo: dscl . -delete /Users/$NAME" >&2
    /usr/bin/dscl . -read "/Groups/$NAME" >/dev/null 2>&1 && echo "  group $NAME -> undo: dscl . -delete /Groups/$NAME" >&2
    [ -d "$DATA" ] && echo "  folder $DATA -> undo: rmdir $DATA" >&2
    echo "Run the undo lines with sudo, then run this script again." >&2
  fi
}
trap on_exit EXIT

# The account's own group.
/usr/bin/dscl . -create "/Groups/$NAME"
/usr/bin/dscl . -create "/Groups/$NAME" Password '*'
/usr/bin/dscl . -create "/Groups/$NAME" RealName "claude-domore supervisor"
/usr/bin/dscl . -create "/Groups/$NAME" PrimaryGroupID "$ID"

# The account: no usable password, no login shell, hidden, home not writable.
# Password and shell are set before the ids, so a record with an id never
# exists without them.
/usr/bin/dscl . -create "/Users/$NAME"
/usr/bin/dscl . -create "/Users/$NAME" Password '*'
/usr/bin/dscl . -create "/Users/$NAME" UserShell /usr/bin/false
/usr/bin/dscl . -create "/Users/$NAME" NFSHomeDirectory /var/empty
/usr/bin/dscl . -create "/Users/$NAME" IsHidden 1
/usr/bin/dscl . -create "/Users/$NAME" RealName "claude-domore supervisor"
/usr/bin/dscl . -create "/Users/$NAME" UniqueID "$ID"
/usr/bin/dscl . -create "/Users/$NAME" PrimaryGroupID "$ID"
/usr/bin/dscacheutil -flushcache

# The data folder: owned by the account, mode 700, no ACL.
/bin/mkdir -m 700 "$DATA"
/usr/sbin/chown "$ID:$ID" "$DATA"
/bin/chmod -N "$DATA"

# --- Result. Expected values are in the comments.

echo "--- result"
# Expected: uid=350(_cdsupervisor) gid=350(_cdsupervisor). Extra groups such as
# everyone, localaccounts, _lpoperator and com.apple.sharepoint.group.* are
# normal for every local account (Apple's _www shows the same).
/usr/bin/id "$NAME"
# Expected: "user is not a member of the group", twice.
/usr/bin/dsmemberutil checkmembership -U "$NAME" -G staff
/usr/bin/dsmemberutil checkmembership -U "$NAME" -G admin
# Expected: Password: *, No such key: AuthenticationAuthority, a GeneratedUID,
# UserShell /usr/bin/false, NFSHomeDirectory /var/empty, IsHidden 1.
/usr/bin/dscl . -read "/Users/$NAME" Password AuthenticationAuthority GeneratedUID UniqueID PrimaryGroupID UserShell NFSHomeDirectory IsHidden
# Expected: Secure token is DISABLED.
/usr/sbin/sysadminctl -secureTokenStatus "$NAME" 2>&1
# Expected: /opt root wheel drwxr-xr-x; the data folder _cdsupervisor drwx------ with no "+".
/bin/ls -led /opt "$DATA"
echo "--- done"
