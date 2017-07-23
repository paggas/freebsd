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
	echo "ssh -i vmctl.${vm}.id_rsa ${sshlogin}"
}
