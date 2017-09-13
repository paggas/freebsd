# pf_test_util.sh - utility functions.

. "$(atf_get_srcdir)/files/pf_test_conf.sh"

PF_TEST_DIR="$(atf_get_srcdir)"
#export PF_TEST_DIR

PATH="${PF_TEST_DIR}/files:${PATH}"
export PATH

# pair_create () {
#	 for i in "$@" ; do
# 	ifpair="epair${i}"
# 	addra="PAIR_${i}_ADDR_A"
# 	addrb="PAIR_${i}_ADDR_B"
# 	netmask="PAIR_${i}_NETMASK"
# 	addr6a="PAIR_${i}_ADDR6_A"
# 	addr6b="PAIR_${i}_ADDR6_B"
# 	prefixlen="PAIR_${i}_PREFIXLEN"
# 	ifconfig "${ifpair}" create
# 	eval "ifconfig ${ifpair}a inet \$${addra} netmask \$${netmask}"
# 	eval "ifconfig ${ifpair}a inet6 \$${addr6a} prefixlen \$${prefixlen}"
# 	eval "ifconfig ${ifpair}b inet \$${addrb} netmask \$${netmask}"
# 	eval "ifconfig ${ifpair}b inet6 \$${addr6b} prefixlen \$${prefixlen}"
#	 done
# }

# pair_destroy () {
#	 for i in "$@" ; do
# 	ifpair="epair${i}"
# 	ifconfig "${ifpair}a" destroy
#	 done
# }

# scp_cmd () {
#	 vm="${1}" &&
# 	sshlogin="$(cat vmctl.${vm}.sshlogin)" &&
# 	echo "scp -q -o StrictHostKeyChecking=no \
# -i vmctl.${vm}.id_rsa ${sshlogin}"
# }

# ssh_cmd - print SSH command for connecting to virtual machine.
ssh_cmd ()
{
	vm="${1}"
	sshlogin="$(cat vmctl.${vm}.sshlogin)" || {
		echo "Could not read SSH login info for VM ${vm}!" >&2
		return 1
	}
	echo "ssh -q -o StrictHostKeyChecking=no \
-i vmctl.${vm}.id_rsa ${sshlogin}"
}

# ssh_login () {
#	 vm="${1}"
#	 cat "vmctl.${vm}.sshlogin"
# }

# tap_create - configure tap interface on host machine with matching
#              vtnet interface on virtual machine.
tap_create ()
{
	vm="${1}"
	tap="${2}"
	tap_inet="${3}"
	vtnet="${4}"
	vtnet_inet="${5}"
	atf_check ifconfig "${tap}" create inet "${tap_inet}" link0
	echo "ifconfig_${vtnet}=\"inet ${vtnet_inet}\"" >> \
		"vmctl.${vm}.rcappend"
}

# tap_create_auto - same as tap_create but allocate tap interface
#                   automatically.  Also print new interface name.
tap_create_auto ()
{
	vm="${1}"
	tap_label="${2}"
	tap_inet="${3}"
	vtnet="${4}"
	vtnet_inet="${5}"
	tap="$(ifconfig tap create)"
	atf_check ifconfig "${tap}" inet "${tap_inet}" link0
	echo "ifconfig_${vtnet}=\"inet ${vtnet_inet}\"" >> \
		"vmctl.${vm}.rcappend"
	echo "${tap}" >> pf_test_util.interfaces
	echo "${tap}" > "pf_test_util.label.${tap_label}"
}

# tap6_create - configure tap interface on host machine with matching
#               vtnet interface on virtual machine, IPv6 version.
tap6_create ()
{
	vm="${1}"
	tap="${2}"
	tap_inet6="${3}"
	vtnet="${4}"
	vtnet_inet6="${5}"
	atf_check ifconfig "${tap}" create inet6 "${tap_inet6}" link0
	{
		echo "ifconfig_${vtnet}=\"inet 0.0.0.0/8\""
		echo "ifconfig_${vtnet}_ipv6=\"inet6 ${vtnet_inet6}\""
	} >> "vmctl.${vm}.rcappend"
}

# tap6_create_auto - same as tap6_create but allocate tap interface
#                    automatically.  Also print new interface name.
tap6_create_auto ()
{
	vm="${1}"
	tap_label="${2}"
	tap_inet6="${3}"
	vtnet="${4}"
	vtnet_inet6="${5}"
	tap="$(ifconfig tap create)"
	atf_check ifconfig "${tap}" inet6 "${tap_inet6}" link0
	{
		echo "ifconfig_${vtnet}=\"inet 0.0.0.0/8\""
		echo "ifconfig_${vtnet}_ipv6=\"inet6 ${vtnet_inet6}\""
	} >> "vmctl.${vm}.rcappend"
	echo "${tap}" >> pf_test_util.interfaces
	echo "${tap}" > "pf_test_util.label.${tap_label}"
}

# bridge_create - create bridge interface for communication between
#                 virtual machines.
bridge_create ()
{
	iface="${1}"
	shift 1 || atf_fail "bridge_create(): No bridge interface specified."
	atf_check ifconfig "${iface}" create
	for i in "$@" ; do
		atf_check ifconfig "${iface}" addm "${i}"
		atf_check ifconfig "${iface}" stp "${i}"
	done
	atf_check ifconfig "${iface}" up
}

# bridge_create_auto - same as bridge_create but allocate bridge interface
#                      automatically.  Also print new interface name.
bridge_create_auto ()
{
	iface_label="${1}"
	shift 1 || atf_fail "bridge_create(): No bridge interface specified."
	iface="$(ifconfig bridge create)"
	for i in "$@" ; do
		atf_check ifconfig "${iface}" addm "${i}"
		atf_check ifconfig "${iface}" stp "${i}"
	done
	atf_check ifconfig "${iface}" up
	echo "${iface}" >> pf_test_util.interfaces
	echo "${iface}" > "pf_test_util.label.${iface_label}"
}

# iface_from_label - get interface name from label
iface_from_label ()
{
	if [ -z "${1}" ] ; then
		atf_fail "iface_from_label(): No interface specified."
	fi
	cat "pf_test_util.label.${1}"
}

# iface_destroy_all - destroy all interfaces created by *_create_auto
#                     functions.
iface_destroy_all ()
{
	cat pf_test_util.interfaces |
		while read iface ; do
			ifconfig "${iface}" destroy
		done
}

# vm_create - create and start a virtual machine.
vm_create ()
{
	vm="${1}"
	shift 1 || atf_fail "vm_create(): No VM specified."
	# Rest of arguments is network (tap) interfaces.
	#echo "==== BEGIN ${vm} ====" >&2
	#cat "vmctl.${vm}.rcappend" >&2
	#echo "==== END ${vm} ====" >&2
	vmctl.sh create "${vm}" "zroot/tests/pf" \
			"/dev/nmdmtests-pf-${vm}B" "$@"
	case "$?" in
		(0) ;;
		(2) atf_fail "VM did not start, bhyve support lacking?" ;;
		(*) atf_fail "vm_create(): vmctl.sh error." ;;
	esac
	# If all went well, valid SSH configuration should have been
	# created.
	ssh_cmd_vm="$(ssh_cmd "${vm}")"
	atf_check [ "x${ssh_cmd_vm}" '!=' "x" ]
}

# vm_destroy - stop and erase a virtual machine.
vm_destroy ()
{
	vm="${1}"
	vmctl.sh destroy "${vm}" "zroot/tests/pf"
}

# vm_ether - get Ethernet address of interface of virtual machine.
vm_ether ()
{
	vm="${1}"
	iface="${2}"
	ssh_cmd_vm="$(ssh_cmd "${vm}")" || return 1
	ether_pattern="\
[0-9a-f][0-9a-f]:[0-9a-f][0-9a-f]:[0-9a-f][0-9a-f]:\
[0-9a-f][0-9a-f]:[0-9a-f][0-9a-f]:[0-9a-f][0-9a-f]"
	${ssh_cmd_vm} ifconfig "${iface}" |
		grep -i 'ether' | grep -io "${ether_pattern}"
}

# upload_file - Upload file to virtual machine.
upload_file ()
{
	vm="${1}"
	file="${2}"
	filename="${3}"
	if [ -z "${filename}" ] ; then
		filename="${file}"
	fi
	{
		cat "$(atf_get_srcdir)/files/${file}" |
			$(ssh_cmd "${vm}") "cat > /root/${filename}"
	} || atf_fail "upload_file(): Could not upload ${file} as ${filename}"
}
