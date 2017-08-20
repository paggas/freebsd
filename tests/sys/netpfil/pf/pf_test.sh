# Make will add a shebang line at the top of this file.

# These tests connect to a remote test machine, load a rules file,
# possibly start some services, and run some tests.  The tests cleanup
# the test machine in the end.
#
# SSH root access to the test machine is required for the tests to
# work.

. "$(atf_get_srcdir)/files/pf_test_util.sh"

# Starts two instances of nc on the remote machine, listening on two
# different ports, of which one port is blocked-with-return by the
# remote pf.  The test tries then to connect to the two instances from
# the local machine.  The test succeeds if one connection succeeds but
# the other one fails.
atf_test_case remote_block_return cleanup
remote_block_return_head () {
    atf_set descr 'Block-with-return a port and test that it is blocked.'
}
remote_block_return_body () {
    block_port=50000
    pass_port=50001
    rules="block return in on vtnet1 proto tcp to port ${block_port}"
    # Set up networking.
    atf_check ifconfig tap19302 create inet 10.169.0.1/24 link0
    atf_check ifconfig tap19303 create inet 10.169.1.1/24 link0
    atf_check ifconfig tap19304 create inet 10.169.2.1/24 link0
    atf_check ifconfig tap19305 create inet 10.169.3.1/24 link0
    atf_check ifconfig bridge6555 create addm tap19303 addm tap19305
    # Create VM configuration.
    echo "\
ifconfig_vtnet0=\"inet 10.169.0.2/24\"
ifconfig_vtnet1=\"inet 10.169.1.2/24\"" > vmctl.client.rcappend
    echo "\
ifconfig_vtnet0=\"inet 10.169.2.2/24\"
ifconfig_vtnet1=\"inet 10.169.3.2/24\"" > vmctl.server.rcappend
    # Start VMs.
    atf_check -e ignore \
              vmctl.sh create client "zroot/tests/pf" \
	      /dev/nmdmtests-pf1B tap19302 tap19303
    atf_check -e ignore \
              vmctl.sh create server "zroot/tests/pf" \
	      /dev/nmdmtests-pf2B tap19304 tap19305
    ssh_cmd_client="$(ssh_cmd client)"
    ssh_cmd_server="$(ssh_cmd server)"
    atf_check [ "x${ssh_cmd_client}" '!=' "x" ]
    atf_check [ "x${ssh_cmd_server}" '!=' "x" ]
    # Debug
    atf_check sleep 900
    # Wait for VMs to start up and for their SSH deamons to start
    # listening.
    atf_check sleep 60
    # Start pf.
    atf_check ${ssh_cmd_server} "kldload -n pf"
    echo "${rules}" | atf_check -e ignore ${ssh_cmd_server} "pfctl -ef -"
    # Start test.
    atf_check daemon -p nc.block.pid ${ssh_cmd_server} "nc -l ${block_port}"
    atf_check daemon -p nc.pass.pid ${ssh_cmd_server} "nc -l ${pass_port}"
    atf_check -s exit:1 -e empty ${ssh_cmd_client} \
	      "nc -z ${REMOTE_ADDR_1} ${block_port}"
    atf_check -s exit:0 -e ignore ${ssh_cmd_client} \
	      "nc -z ${REMOTE_ADDR_1} ${pass_port}"
}
remote_block_return_cleanup () {
    # Stop test.
    [ -e nc.block.pid ] && kill "$(cat nc.block.pid)"
    [ -e nc.pass.pid ] && kill "$(cat nc.pass.pid)"
    # # Stop pf.
    # $(ssh_cmd server) "pfctl -dFa ;
    #                    kldunload -n pf ;
    # 		       true"
    # Stop VMs.
    vmctl.sh destroy client "zroot/tests/pf"
    vmctl.sh destroy server "zroot/tests/pf"
    # Tear down networking.
    ifconfig bridge6555 destroy
    ifconfig tap19302 destroy
    ifconfig tap19303 destroy
    ifconfig tap19304 destroy
    ifconfig tap19305 destroy
}

atf_test_case remote_block_drop cleanup
remote_block_drop_head () {
    atf_set descr 'Block-with-drop a port and test that it is blocked.'
}
remote_block_drop_body () {
    block_port=50000
    pass_port=50001
    rules="block drop in on ${REMOTE_IF_1} proto tcp to port ${block_port}"
    # Prepare pf.
    atf_check ssh "${SSH_0}" "kldload -n pf"
    echo "${rules}" | atf_check -e ignore ssh "${SSH_0}" "pfctl -ef -"
    # Setup test listeners.
    atf_check daemon -p nc.block.pid ssh "${SSH_0}" "nc -l ${block_port}"
    atf_check daemon -p nc.pass.pid ssh "${SSH_0}" "nc -l ${pass_port}"
    # Run test.
    atf_check -s exit:1 -e empty nc -z -w 4 "${REMOTE_ADDR_1}" "${block_port}"
    atf_check -s exit:0 -e ignore nc -z "${REMOTE_ADDR_1}" "${pass_port}"
}
remote_block_drop_cleanup () {
    [ -e nc.block.pid ] && kill "$(cat nc.block.pid)"
    [ -e nc.pass.pid ] && kill "$(cat nc.pass.pid)"
    ssh "${SSH_0}" "pfctl -dFa ;
               	  kldunload -n pf ;
 		  true"
}

# This test uses 2 interfaces to connect to the test machine,
# $REMOTE_IF_1 and $REMOTE_IF_2.  The test machine is doing reassembly
# on one of the two interfaces.  We send one echo request on each
# interface of size 3000, which will be fragmented before being sent.
# We capture the traffic on the test machine's pflog and transfer the
# capture file to the host machine for processing.  The capture file
# should show a reassembled echo request packet on one interface and
# the original fragmented set of packets on the other.
atf_test_case remote_scrub_todo cleanup
remote_scrub_todo_head () {
    atf_set descr 'Scrub on one of two interfaces and test difference.'
}
remote_scrub_todo_body () {
    # files to be used in local directory: tempdir.var tcpdump.pid
    # files to be used in remote temporary directory: pflog.pcap
    rules="scrub in on $REMOTE_IF_1 all fragment reassemble
           pass log (all, to pflog0) on { $REMOTE_IF_1 $REMOTE_IF_2 }"
    atf_check ssh "$SSH_0" 'kldload -n pf pflog'
    echo "$rules" | atf_check -e ignore ssh "$SSH_0" 'pfctl -ef -'
    atf_check -o save:tempdir.var ssh "$SSH_0" 'mktemp -dt pf_test.tmp'
    #atf_check_equal 0 "$?"
    tempdir="$(cat tempdir.var)"
    timeout=5
    atf_check daemon -p tcpdump.pid ssh "$SSH_0" \
	   "timeout $timeout tcpdump -U -i pflog0 -w $tempdir/pflog.pcap"
    (cd "$(atf_get_srcdir)/files" &&
    	atf_check python2 scrub6.py sendonly)
    # Wait for tcpdump to pick up everything.
    atf_check sleep "$(expr "$timeout" + 2)"
    # Not sure if following will work with atf_check
    atf_check scp "$SSH_0:$tempdir/pflog.pcap" ./
    # TODO following will be removed when the test is complete, but
    # since processing isn't implemented yet, we just save the file
    # for now.
    atf_check cp pflog.pcap "$(atf_get_srcdir)/"
    # TODO process pflog.pcap for verification
}
remote_scrub_todo_cleanup () {
    kill "$(cat tcpdump.pid)"
    tempdir="$(cat tempdir.var)"
    ssh "$SSH_0" "rm -r \"$tempdir\" ; pfctl -dFa"
}

atf_test_case remote_scrub_forward cleanup
remote_scrub_forward_head () {
    atf_set descr 'Scrub defrag with forward on one \
of two interfaces and test difference.'
}
remote_scrub_forward_body () {
    rules="scrub in on ${REMOTE_IF_1} all fragment reassemble
           pass log (all to pflog0) on { ${REMOTE_IF_1} ${REMOTE_IF_2} }"
    cd "$(atf_get_srcdir)"
    # Enable pf.
    atf_check ssh "${SSH_0}" "kldload -n pf"
    echo "${rules}" | atf_check -e ignore ssh "${SSH_0}" "pfctl -ef -"
    # Enable forwarding.
    atf_check -o ignore ssh "${SSH_0}" "sysctl net.inet.ip.forwarding=1"
    # Warm up connections, so that network discovery is complete.
    atf_check -o ignore ping -c3 "${REMOTE_ADDR_1}"
    atf_check -o ignore ping -c3 "${REMOTE_ADDR_2}"
    atf_check -o ignore ping -c3 "${REMOTE_ADDR_3}"
    # Run test.
    cd files &&
	atf_check python2 scrub_forward.py &&
	cd ..
}
remote_scrub_forward_cleanup () {
    ssh "${SSH_0}" "pfctl -dFa ;
                  sysctl net.inet.ip.forwarding=0"
}

atf_test_case remote_scrub_forward6 cleanup
remote_scrub_forward6_head () {
    atf_set descr 'Scrub defrag with forward on one \
of two interfaces and test difference, IPv6 version.'
}
remote_scrub_forward6_body () {
    rules="scrub in on $REMOTE_IF_1 all fragment reassemble
           pass log (all, to pflog0) on { $REMOTE_IF_1 $REMOTE_IF_2 }"
    cd "$(atf_get_srcdir)"
    # Enable pf.
    atf_check ssh "$SSH_0" kldload -n pf
    echo "$rules" | atf_check -e ignore ssh "$SSH_0" pfctl -ef -
    # Enable forwarding.
    atf_check -o ignore ssh "$SSH_0" sysctl net.inet6.ip6.forwarding=1
    # Warm up connections, so that network discovery is complete.
    atf_check -o ignore ping6 -c3 "$REMOTE_ADDR6_1"
    atf_check -o ignore ping6 -c3 "$REMOTE_ADDR6_2"
    atf_check -o ignore ping6 -c3 "$REMOTE_ADDR6_3"
    # Run test.
    cd files &&
	atf_check python2 scrub_forward6.py &&
	cd ..
}
remote_scrub_forward6_cleanup () {
    ssh "$SSH_0" "pfctl -dFa ;
                sysctl net.inet6.ip6.forwarding=0"
}

atf_test_case scrub_pflog cleanup
scrub_pflog_head () {
    atf_set descr 'Scrub defrag with pflog on one \
of two interfaces and test difference.'
}
scrub_pflog_body () {
    pair_create 0 1
    rules="scrub in on ${PAIR_0_IF_A} all fragment reassemble
           pass log (all to ${PFLOG_IF}) on { ${PAIR_0_IF_A} ${PAIR_1_IF_A} }"
    cd "$(atf_get_srcdir)"
    # Enable pf.
    atf_check kldload -n pf pflog
    atf_check ifconfig pflog0 up
    echo "$rules" | atf_check -e ignore pfctl -ef -
    # Run test.
    cd files
    atf_check python2 scrub_pflog.py
}
scrub_pflog_cleanup () {
    pfctl -dFa
    ifconfig pflog0 down
    kldunload -n pf pflog
    pair_destroy 0 1
}

atf_init_test_cases () {
    atf_add_test_case remote_block_return
    atf_add_test_case remote_block_drop
    atf_add_test_case remote_scrub_todo
    atf_add_test_case remote_scrub_forward
    atf_add_test_case remote_scrub_forward6
    atf_add_test_case scrub_pflog
}
