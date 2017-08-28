# Utility functions.

. "$(atf_get_srcdir)/files/pf_test_conf.sh"

PF_TEST_DIR="$(atf_get_srcdir)"
export PF_TEST_DIR

PATH="${PF_TEST_DIR}/files:${PATH}"
export PATH

pair_create () {
    for i in "$@" ; do
	ifpair="epair${i}"
	addra="PAIR_${i}_ADDR_A"
	addrb="PAIR_${i}_ADDR_B"
	netmask="PAIR_${i}_NETMASK"
	addr6a="PAIR_${i}_ADDR6_A"
	addr6b="PAIR_${i}_ADDR6_B"
	prefixlen="PAIR_${i}_PREFIXLEN"
	ifconfig "${ifpair}" create
	eval "ifconfig ${ifpair}a inet \$${addra} netmask \$${netmask}"
	eval "ifconfig ${ifpair}a inet6 \$${addr6a} prefixlen \$${prefixlen}"
	eval "ifconfig ${ifpair}b inet \$${addrb} netmask \$${netmask}"
	eval "ifconfig ${ifpair}b inet6 \$${addr6b} prefixlen \$${prefixlen}"
    done
}

pair_destroy () {
    for i in "$@" ; do
	ifpair="epair${i}"
	ifconfig "${ifpair}a" destroy
    done
}

ssh_cmd () {
    vm="${1}" &&
	sshlogin="$(cat vmctl.${vm}.sshlogin)" &&
	echo "ssh -q -o StrictHostKeyChecking=no \
-i vmctl.${vm}.id_rsa ${sshlogin}"
}

tap_create () {
    vm="${1}"
    tap="${2}"
    tap_inet="${3}"
    vtnet="${4}"
    vtnet_inet="${5}"
    atf_check ifconfig "${tap}" create inet "${tap_inet}" link0
    echo "ifconfig_${vtnet}=\"inet ${vtnet_inet}\"" >> "vmctl.${vm}.rcappend"
}

bridge_create () {
    iface="${1}"
    shift 1 || atf_fail "bridge_create"
    atf_check ifconfig "${iface}" create
    for i in "$@" ; do
        atf_check ifconfig "${iface}" addm "${i}"
        atf_check ifconfig "${iface}" stp "${i}"
    done
    atf_check ifconfig "${iface}" up
}

vm_create () {
    vm="${1}"
    shift 1 || atf_fail "vm_create"
    # Rest of arguments is network (tap) interfaces.
    atf_check -e ignore \
              vmctl.sh create "${vm}" "zroot/tests/pf" \
              "/dev/nmdmtests-pf-${vm}B" "$@"
    ssh_cmd_vm="$(ssh_cmd ${vm})"
    atf_check [ "x${ssh_cmd_vm}" '!=' "x" ]
}

vm_destroy () {
    vm="${1}"
    vmctl.sh destroy "${vm}" "zroot/tests/pf"
}
