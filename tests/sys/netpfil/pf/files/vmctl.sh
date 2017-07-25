#! /bin/sh

# vmctl.sh - control a VM for tests.
#
# vmctl.sh runs all necessary zfs commands, only receiving the
# directory name from the caller.  All network configuration visible
# to the VM is received through the vmctl.${vm}.rcappend file.  The
# first interface specified in the ${ifs} list is the one for which
# SSH is setup.

cmd="${1}"
vm="${2}"
zdir="${3}"
console="${4}"
shift 4
ifs="$@"

usage="\
Usage: ${0} \"create\" {vm} {zdir} {console} {if1 if2 ...}
       ${0} \"destroy\" {vm} {zdir}"

baseimg="${zdir}/baseimg"
snap="${zdir}/baseimg@${vm}"
vmimg="${zdir}/vm.${vm}"
mountdir="/mnt/tests/pf/vm.${vm}"

# Make sure baseimg exists as a zvol.
make_baseimg () {
    [ -e "/dev/zvol/${baseimg}" ] && return
    tempdir="$(mktemp -d)"
    (
        # Download image file.
        imgfile="${tempdir}/FreeBSD-11.0-RELEASE-amd64.raw"
        # fetch -o "${imgfile}.xz" \
        #       "https://download.freebsd.org/ftp/releases/VM-IMAGES/11.0-RELEASE/amd64/Latest/FreeBSD-11.0-RELEASE-amd64.raw.xz" \
        #     || return 1
        # TODO Use local copy of above for now.
        cp -ai "/var/tmp/FreeBSD-11.0-RELEASE-amd64.raw.xz" \
           "${imgfile}.xz" || return 1
        unxz "${imgfile}.xz" || return 1
        size="$(stat -f '%z' ${imgfile})"
        # Round up to multiple of 16M.
        [ "$(expr ${size} % 16777216)" = 0 ] ||
            size="$(expr \( \( $size / 16777216 \) + 1 \) \* 16777216)"
        # Copy image file to zvol.
        zfs create -p -V "${size}" "${baseimg}" || return 1
        dd bs=16M if="${imgfile}" of="/dev/zvol/${baseimg}" || return 1
    )
    status="$?"
    rm -r "${tempdir}"
    return "${status}"
}

# Install system on VM.
make_install () {
    # TODO Copy pf binary files from host to VM.  Quick fix while we
    # use official images, will do proper system installs in the
    # future.
    cp -a "/boot/kernel/pf.ko" \
       "${mountdir}/boot/kernel/pf.ko" || return 1
    cp -a "/sbin/pfctl" \
       "${mountdir}/sbin/pfctl" || return 1
}

write_sshlogin () {
    addr="$(grep -E "ifconfig_.*inet.*[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" \
                "vmctl.${vm}.rcappend" |
            sed -E "s/.*[^0-9]([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+).*/\1/" |
            head -n 1)" || return 1
    [ "x${addr}" '!=' "x" ] || return 1
    echo "root@${addr}" > "vmctl.${vm}.sshlogin" || return 1
}

case "${cmd}" in
    (create)
        make_baseimg || exit 1
        zfs snap "${snap}" || exit 1
        zfs clone "${snap}" "${vmimg}" || exit 1
        ssh-keygen -q -P '' -f "vmctl.${vm}.id_rsa" || exit 1
        write_sshlogin || exit 1
        mkdir -p "${mountdir}" || exit 1
        mount "/dev/zvol/${vmimg}p3" "${mountdir}" || exit 1
        (
            make_install || return 1
            (
                umask 0177 || return 1
                mkdir -p "${mountdir}/root/.ssh" || return 1
                cat "vmctl.${vm}.id_rsa" >> \
                    "${mountdir}/root/.ssh/authorized_keys"
            ) || return 1
            echo "PermitRootLogin without-password" >> \
                 "${mountdir}/etc/ssh/sshd_config" || return 1
            echo "sshd_enable=\"YES\"" >> \
                 "${mountdir}/etc/rc.conf" || return 1
            cat "vmctl.${vm}.rcappend" >> \
                "${mountdir}/etc/rc.conf" || return 1
        )
        appendstatus="$?"
        umount "${mountdir}"
        rmdir "${mountdir}"
        [ "x${appendstatus}" = 'x0' ] || return 1
        (
            ifsopt=''
            for i in ${ifs} ; do
                ifsopt="${ifsopt} -t ${i}" ; done
            daemon -p "vmctl.${vm}.pid" \
                   sh /usr/share/examples/bhyve/vmrun.sh ${ifsopt} \
                   -d "/dev/zvol/${vmimg}" -C "${console}" \
                   "tests-pf-${vm}"
        )
        ;;
    (destroy)
        bhyvectl --destroy --vm="tests-pf-${vm}"
        [ -e "vmctl.${vm}.pid" ] && kill "$(cat vmctl.${vm}.pid)"
        rm "vmctl.${vm}.id_rsa" \
           "vmctl.${vm}.id_rsa.pub" \
           "vmctl.${vm}.sshlogin"
        # TODO Sleep a bit before destroying dataset, so that it
        # doesn't show up as "busy".
        sleep 5
        zfs destroy -R "${snap}"
        ;;
    (*)
        echo "${usage}" >&2
        exit 1
        ;;
esac
