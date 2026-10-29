#!@MEMO_PREFIX@/bin/sh

@MEMO_PREFIX@@MEMO_SUB_PREFIX@/libexec/firmware
@MEMO_PREFIX@@MEMO_SUB_PREFIX@/sbin/pwd_mkdb -p @MEMO_PREFIX@/etc/master.passwd >/dev/null 2>&1
@MEMO_PREFIX@/Library/dpkg/info/debianutils.postinst configure 99999
@MEMO_PREFIX@/Library/dpkg/info/apt.postinst configure 999999
@MEMO_PREFIX@/Library/dpkg/info/dash.postinst configure 999999
@MEMO_PREFIX@/Library/dpkg/info/zsh.postinst configure 999999
@MEMO_PREFIX@/Library/dpkg/info/bash.postinst configure 999999
@MEMO_PREFIX@/Library/dpkg/info/vi.postinst configure 999999
@MEMO_PREFIX@/Library/dpkg/info/openssh-server.extrainst_ install @SSH_STRAP@

@MEMO_PREFIX@@MEMO_SUB_PREFIX@/sbin/pwd_mkdb -p @MEMO_PREFIX@/etc/master.passwd

@MEMO_PREFIX@@MEMO_SUB_PREFIX@/bin/chsh -s @MEMO_PREFIX@@MEMO_SUB_PREFIX@/bin/zsh mobile
@MEMO_PREFIX@@MEMO_SUB_PREFIX@/bin/chsh -s @MEMO_PREFIX@@MEMO_SUB_PREFIX@/bin/zsh root

PASSWORD1="${RELAXIN_DEFAULT_PASSWORD:-}"
if [ -z "$PASSWORD1" ] && [ -z "$NO_PASSWORD_PROMPT" ]; then
    PASSWORDS=""
    PASSWORD2=""
    while [ -z "$PASSWORD1" ] || [ ! "$PASSWORD1" = "$PASSWORD2" ]; do
            PASSWORDS="$(@MEMO_PREFIX@@MEMO_SUB_PREFIX@/bin/uialert -b "${RELAXIN_PASSWORD_BODY:-In order to use command line tools after jailbreaking, you will need to set a terminal passcode. (This cannot be empty)}" --secure "${RELAXIN_PASSWORD_FIELD:-Password}" --secure "${RELAXIN_REPEAT_PASSWORD_FIELD:-Repeat Password}" -p "${RELAXIN_SET_PASSWORD_BUTTON:-Set}" "${RELAXIN_SET_PASSWORD_TITLE:-Set Password}")"
            PASSWORD1="$(printf "%s\n" "$PASSWORDS" | @MEMO_PREFIX@@MEMO_SUB_PREFIX@/bin/sed -n '1 p')"
            PASSWORD2="$(printf "%s\n" "$PASSWORDS" | @MEMO_PREFIX@@MEMO_SUB_PREFIX@/bin/sed -n '2 p')"
    done
fi
if [ -n "$PASSWORD1" ]; then
    printf "%s\n" "$PASSWORD1" | @MEMO_PREFIX@@MEMO_SUB_PREFIX@/sbin/pw usermod mobile -h 0 || exit $?
fi

rm -f @MEMO_PREFIX@/prep_bootstrap.sh
