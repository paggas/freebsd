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
vmimg="${zdir}/baseimg.${vm}"
mountdir="/mnt/tests/pf/vm.${vm}"

# Make sure baseimg exists as a zvol.
make_baseimg () {
    [ -e "/dev/zvol/${baseimg}" ] && return
    tempdir="$(mktemp -d)"
    imgfile="${tempdir}/FreeBSD-11.0-RELEASE-amd64.raw"
    { fetch -o "${imgfile}.xz" \
    	    "https://download.freebsd.org/ftp/releases/VM-IMAGES/11.0-RELEASE/amd64/Latest/FreeBSD-11.0-RELEASE-amd64.raw.xz" &&
    	  unxz "${imgfile}.xz" ; } || return 1
    size="$(stat -f '%z' ${imgfile})"
    # Round up to multiple of 16M.
    [ "$(expr ${size} % 16777216)" = 0 ] ||
	{ size="$(expr \( \( $size / 16777216 \) + 1 \) \* 16777216)" ; }
    zfs create -p -V "${size}" "${baseimg}" &&
	dd bs=16M if="${imgfile}" of="/dev/zvol/${baseimg}"
    status="$?"
    rm -r "${tempdir}" && return "${status}"
}

write_sshlogin () {
    addr="$(grep -E "ifconfig_.*inet.*[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" \
                "vmctl.${vm}.rcappend" |
            sed -E "s/.*([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+).*/\1/" |
            head -n 1)" &&
	[ "x${addr}" '!=' "x" ] &&
	echo "root@${addr}" > "vmctl.${vm}.sshlogin"
}

case "${cmd}" in
    (create)
	# make -f "${PF_TEST_DIR}/files/vmctl.mk" \
	#      "/dev/zvol/${zdir}/baseimg"
	{ make_baseimg &&
	      zfs snap "${snap}" &&
	      zfs clone "${snap}" "${vmimg}" &&
	      ssh-keygen -q -P '' -f "vmctl.${vm}.id_rsa" &&
	      write_sshlogin &&
	      mkdir -p "${mountdir}" &&
	      mount "/dev/zvol/${vmimg}p3" "${mountdir}"; } || exit 1
	mkdir -p "${mountdir}/root/.ssh" &&
	    cat "vmctl.${vm}.id_rsa" >> \
		"${mountdir}/root/.ssh/authorized_keys" &&
	    echo "cloned_interfaces=\"${ifs}\"" >> \
		 "${mountdir}/etc/rc.conf" &&
	    cat "vmctl.${vm}.rcappend" >> \
		"${mountdir}/etc/rc.conf"
	appendstatus="$?"
	umount "${mountdir}" &&
	    rmdir "${mountdir}" &&
	    [ "x${appendstatus}" "!=" 'x0' ] &&
	    { ifsopt=''
	      for i in "${ifs}" ; do
		  ifsopt="${ifsopt} -t ${ifs}" ; done
	      daemon -p "vmctl.${vm}.pid" \
		     sh /usr/share/examples/bhyve/vmrun.sh $ifsopt \
		     -d "${vmimg}" -C "${console}" "${vm}" ; }
	;;
    (destroy)
	[ -e "vmctl.${vm}.pid" ] && kill "$(cat vmctl.${vm}.pid)"
	rm "vmctl.${vm}.id_rsa" \
	   "vmctl.${vm}.id_rsa.pub" \
	   "vmctl.${vm}.sshlogin"
	zfs destroy -R "${snap}"
	;;
    (*)
	echo "${usage}" >&2
	exit 1
	;;
esac
