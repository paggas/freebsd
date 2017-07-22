#! /bin/sh

cmd="${1}"
vm="${2}"
console="${3}"
shift 3
ifs="$@"

echo "DEBUG: vmctl: ZROOT=${ZROOT}"

baseimg="${ZROOT}/tests/pf/baseimg"
snap="${ZROOT}/tests/pf/baseimg@${vm}"
vmimg="${ZROOT}/tests/pf/baseimg.${vm}"
mountdir="/mnt/tests/pf/vm.${vm}"

case "${cmd}" in
    (create)
	# make -f "${PF_TEST_DIR}/files/vmctl.mk" \
	#      "/dev/zvol/${ZROOT}/tests/pf/baseimg"
	{ make_baseimg &&
	      zfs snap "${snap}" &&
	      zfs clone "${snap}" "${vmimg}" &&
	      ssh-keygen -f "conf.${vm}.id_rsa" &&
	      write_sshlogin &&
	      mount "/dev/zvol/${vmimg}p3" "${mountdir}"; } || exit 1
	cat "conf.${vm}.id_rsa" >> \
	    "${mountdir}/root/.ssh/authorized_keys" &&
	    echo "cloned_interfaces=\"${ifs}\"" >> \
		 "${mountdir}/etc/rc.conf" &&
	    cat "conf.${vm}.rcappend" >> \
		"${mountdir}/etc/rc.conf"
	appendstatus="$?"
	umount "${mountdir}" &&
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
	rm "conf.${vm}.id_rsa" \
	   "conf.${vm}.id_rsa.pub" \
	   "conf.${vm}.sshlogin"
	zfs destroy -R "${snap}"
	;;
    (*)
	echo "Usage: ${0} {create|destroy} {vm} {console} {if1 if2 ...}" >&2
	exit 1
	;;
esac
