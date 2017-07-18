# You need to source pf_test_conf.sh before sourcing this file.
#
# Utility functions.

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
