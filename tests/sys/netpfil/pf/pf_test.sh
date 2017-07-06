# Make will add a shebang line at the top of this file.

# These tests connect to a remote test machine, load a rules file,
# possibly start some services, and run some tests.  The tests cleanup
# the test machine in the end.
#
# SSH root access to the test machine is required for the tests to
# work.

. "$(atf_get_srcdir)/files/pf_test_conf.sh"

# Starts two instances of nc on the remote machine, listening on two
# different ports, of which one port is blocked-with-return by the
# remote pf.  The test tries then to connect to the two instances from
# the local machine.  The test succeeds if one connection succeeds but
# the other one fails.
atf_test_case block_return cleanup
block_return_head () {
    atf_set descr 'Block-with-return a port and test that it is blocked.'
}
block_return_body () {
    rules="block return in on $REMOTE_IF_1 proto tcp to port 50000"
    atf_check ssh "$SSH" kldload -n pf
    echo "$rules" | atf_check -e ignore ssh "$SSH" pfctl -ef -
    atf_check daemon -p nc.50000.pid ssh "$SSH" nc -l 50000
    atf_check daemon -p nc.50001.pid ssh "$SSH" nc -l 50001
    atf_check -s exit:1 -e empty  nc -z "$REMOTE_ADDR_1" 50000
    atf_check -s exit:0 -e ignore nc -z "$REMOTE_ADDR_1" 50001
}
block_return_cleanup () {
    atf_check -e ignore ssh "$SSH" pfctl -dFa
    [ -e nc.50000.pid ] && kill `cat nc.50000.pid`
    [ -e nc.50001.pid ] && kill `cat nc.50001.pid`
}

atf_test_case block_drop cleanup
block_drop_head () {
    atf_set descr 'Block-with-drop a port and test that it is blocked.'
}
block_drop_body () {
    rules="block drop in on $REMOTE_IF_1 proto tcp to port 50000"
    atf_check ssh "$SSH" kldload -n pf
    echo "$rules" | atf_check -e ignore ssh "$SSH" pfctl -ef -
    atf_check daemon -p nc.50000.pid ssh "$SSH" nc -l 50000
    atf_check daemon -p nc.50001.pid ssh "$SSH" nc -l 50001
    atf_check -s exit:1 -e empty  nc -z -w 4 "$REMOTE_ADDR_1" 50000
    atf_check -s exit:0 -e ignore nc -z "$REMOTE_ADDR_1" 50001
}
block_drop_cleanup () {
    atf_check -e ignore ssh "$SSH" pfctl -dFa
    [ -e nc.50000.pid ] && kill `cat nc.50000.pid`
    [ -e nc.50001.pid ] && kill `cat nc.50001.pid`
}

# # This test uses 2 interfaces to connect to the test machine,
# # $REMOTE_IF_1 and $REMOTE_IF_2.  The test machine is doing reassembly
# # on one of the two interfaces.  We send one echo request on each
# # interface of size 3000, which will be fragmented before being sent.
# # We capture the traffic on the test machine's pflog and transfer the
# # capture file to the host machine for processing.  The capture file
# # should show a reassembled echo request packet on one interface and
# # the original fragmented set of packets on the other.
# atf_test_case scrub_todo cleanup
# scrub_todo_head () {
#     atf_set descr 'Scrub on one of two interfaces and test difference.'
# }
# scrub_todo_body () {
#     # files to be used in local directory: tempdir.var tcpdump.pid
#     # files to be used in remote temporary directory: pflog.pcap
#     rules="scrub in on $REMOTE_IF_1 all fragment reassemble
#            pass log (all, to pflog0) on { $REMOTE_IF_1 $REMOTE_IF_2 }"
#     atf_check ssh "$SSH" kldload -n pf pflog
#     echo "$rules" | atf_check -e ignore ssh "$SSH" pfctl -ef -
#     # TODO not sure why this doesn't work with atf_check
#     #atf_check -o file:tempdir.var ssh "$SSH" mktemp -dt pf_test.tmp
#     ssh "$SSH" mktemp -dt pf_test.tmp > tempdir.var
#     tempdir="`cat tempdir.var`"
#     atf_check daemon -p tcpdump.pid \
# 	      ssh "$SSH" tcpdump -U -i pflog0 -w "$tempdir/pflog.pcap"
#     atf_check -o ignore ping -c1 -s3000 "$REMOTE_ADDR_1"
#     atf_check -o ignore ping -c1 -s3000 "$REMOTE_ADDR_2"
#     sleep 2 # wait for tcpdump to pick up everything
#     kill "`cat tcpdump.pid`"
#     sleep 2 # wait for tcpdump to write out everything
#     atf_check scp "$SSH:$tempdir/pflog.pcap" ./
#     # TODO following will be removed when the test is complete, but
#     # since processing isn't implemented yet, we just save the file
#     # for now.
#     atf_check cp pflog.pcap "$(atf_get_srcdir)/"
#     # TODO process pflog.pcap for verification
# }
# scrub_todo_cleanup () {
#     kill "`cat tcpdump.pid`"
#     tempdir="`cat tempdir.var`"
#     ssh "$SSH" "rm -r \"$tempdir\" ;
#                 pfctl -dFa"
# }

atf_test_case scrub_forward cleanup
scrub_forward_head () {
    atf_set descr 'Scrub defrag with forward on one \
of two interfaces and test difference.'
}
scrub_forward_body () {
    rules="scrub in on $REMOTE_IF_1 all fragment reassemble
           pass log (all, to pflog0) on { $REMOTE_IF_1 $REMOTE_IF_2 }"
    cd "$(atf_get_srcdir)"
    atf_check ssh "$SSH" kldload -n pf
    echo "$rules" | atf_check -e ignore ssh "$SSH" pfctl -ef -
    atf_check -o ignore ssh "$SSH" sysctl net.inet.ip.forwarding=1
    cd files &&
	atf_check python2 scrub.py &&
	cd ..
}
scrub_forward_cleanup () {
    ssh "$SSH" "pfctl -dFa ;
                sysctl net.inet.ip.forwarding=0"
}

atf_test_case scrub_forward6 cleanup
scrub_forward6_head () {
    atf_set descr 'Scrub defrag with forward on one \
of two interfaces and test difference, IPv6 version.'
}
scrub_forward6_body () {
    rules="scrub in on $REMOTE_IF_1 all fragment reassemble
           pass log (all, to pflog0) on { $REMOTE_IF_1 $REMOTE_IF_2 }"
    cd "$(atf_get_srcdir)"
    atf_check ssh "$SSH" kldload -n pf
    echo "$rules" | atf_check -e ignore ssh "$SSH" pfctl -ef -
    atf_check -o ignore ssh "$SSH" sysctl net.inet6.ip6.forwarding=1
    cd files &&
	atf_check python2 scrub6.py &&
	cd ..
}
scrub_forward6_cleanup () {
    ssh "$SSH" "pfctl -dFa ;
                sysctl net.inet6.ip6.forwarding=0"
}

atf_init_test_cases () {
    atf_add_test_case block_return
    atf_add_test_case block_drop
    # atf_add_test_case scrub_todo
    atf_add_test_case scrub_forward
    atf_add_test_case scrub_forward6
}
