# This test starts two virtual machines, the client and the server.
# It uses scapy to send IPv6 fragmented traffic from the client
# machine to the server machine.  The machines are connected via three
# interfaces.  The client sents traffic to the server via the first
# two interfaces with the client itself as the destination, which the
# server forwards via the third interface back to the client.  Scrub
# is activated on the first but not the second interface on the server
# pf.  Tcpdump is run on pflog on the server, capturing traffic in a
# pcap file, which is copied back to the client for examination.  By
# examining the captured packets, we can verify that reassembly occurs
# on one but not the other interface.

. "$(atf_get_srcdir)/files/pf_test_util.sh"

atf_init_test_cases ()
{
    atf_add_test_case "scrub_forward6"
}

atf_test_case "scrub_forward6" cleanup
scrub_forward6_head ()
{
    atf_set descr 'Scrub defrag with forward on one \
of two interfaces and test difference, IPv6 version.'
    atf_set "require.user" "root"
}
scrub_forward6_body ()
{
    rules="scrub in on vtnet1 all fragment reassemble
pass log (all to pflog0) on { vtnet1 vtnet2 }"
    # Set up networking.
    # Need at least one IPv4 interface per VM for SSH autoconf.
    tap_create client tap19302 10.135.213.1/28 vtnet0 10.135.213.2/28
    tap_create server tap19303 10.135.213.17/28 vtnet0 10.135.213.18/28
    # tap6_create client tap19302 fd22:27ca:58fe::/64 \
    #             vtnet0 fd22:27ca:58fe::1/64
    # tap6_create server tap19303 fd22:27ca:58fe:1::/64 \
    #             vtnet0 fd22:27ca:58fe:1::1/64
    tap6_create client tap19304 fd22:27ca:58fe:2::/64 \
                vtnet1 fd22:27ca:58fe:2::1/64
    tap6_create server tap19305 fd22:27ca:58fe:2::2/64 \
                vtnet1 fd22:27ca:58fe:2::3/64
    tap6_create client tap19306 fd22:27ca:58fe:3::/64 \
                vtnet2 fd22:27ca:58fe:3::1/64
    tap6_create server tap19307 fd22:27ca:58fe:3::2/64 \
                vtnet2 fd22:27ca:58fe:3::3/64
    tap6_create client tap19308 fd22:27ca:58fe:4::/64 \
                vtnet3 fd22:27ca:58fe:4::1/64
    tap6_create server tap19309 fd22:27ca:58fe:4::2/64 \
                vtnet3 fd22:27ca:58fe:4::3/64
    bridge_create bridge6555 tap19304 tap19305
    bridge_create bridge6556 tap19306 tap19307
    bridge_create bridge6557 tap19308 tap19309
    # Start VMs.
    vm_create client tap19302 tap19304 tap19306 tap19308
    vm_create server tap19303 tap19305 tap19307 tap19309
    # Wait for VMs to start up and for their SSH deamons to start
    # listening.
    atf_check sleep 120
    # Debug
    #atf_check sleep 900
    # Start pf.
    atf_check $(ssh_cmd server) "kldload -n pf pflog"
    echo "${rules}" | atf_check -e ignore $(ssh_cmd server) "pfctl -ef -"
    # Enable forwarding.
    atf_check -o ignore $(ssh_cmd server) "sysctl net.inet6.ip6.forwarding=1"
    # Warm up connections, so that network discovery is complete.
    atf_check -o ignore $(ssh_cmd client) "ping6 -c3 fd22:27ca:58fe:2::3"
    atf_check -o ignore $(ssh_cmd client) "ping6 -c3 fd22:27ca:58fe:3::3"
    atf_check -o ignore $(ssh_cmd client) "ping6 -c3 fd22:27ca:58fe:4::3"
    # Upload test to VM.
    upload_file client "scrub6.py" "test.py"
    upload_file client "util.py"
    (
        client_ether1="$(vm_ether client vtnet1)" || return 1
        client_ether2="$(vm_ether client vtnet2)" || return 1
        server_ether1="$(vm_ether server vtnet1)" || return 1
        server_ether2="$(vm_ether server vtnet2)" || return 1
        echo "\
LOCAL_MAC_1='${client_ether1}'
LOCAL_MAC_2='${client_ether2}'
REMOTE_MAC_1='${server_ether1}'
REMOTE_MAC_2='${server_ether2}'
LOCAL_ADDR6_1='fd22:27ca:58fe:2::1'
LOCAL_ADDR6_2='fd22:27ca:58fe:3::1'
LOCAL_ADDR6_3='fd22:27ca:58fe:4::1'
REMOTE_ADDR6_1='fd22:27ca:58fe:2::3'
REMOTE_ADDR6_2='fd22:27ca:58fe:3::3'
REMOTE_ADDR6_3='fd22:27ca:58fe:4::3'
LOCAL_IF_1='vtnet1'
LOCAL_IF_2='vtnet2'
LOCAL_IF_3='vtnet3'" | \
            $(ssh_cmd client) "cat > /root/conf.py"
    ) || atf_fail "Could not upload conf.py to VM."
    # Run test.
    # Run tcpdump for 15 seconds.
    atf_check daemon -p tcpdump.pid $(ssh_cmd server) \
              "cd /root && tcpdump -G 15 -W 1 -i pflog0 -w pflog.pcap"
    atf_check sleep 2
    # Alt 1: Generate traffic with scapy.
    # BEGIN
    # atf_check -o ignore $(ssh_cmd client) \
    #           "cd /root && ${PYTHON2} test.py sendonly"
    # END
    # Alt 2: Generate traffic with ping6.
    # BEGIN
    # Run ping6 with a packet size of 6000, which will cause
    # fragmentation.  By capturing on pflog0, packets to vtnet1 will
    # show up as unfragmented, while packets to vtnet2 will show up as
    # fragmented.  This will later be tested using scrub6.py.
    atf_check -o ignore $(ssh_cmd client) \
              "ping6 -c3 -s6000 fd22:27ca:58fe:2::3"
    atf_check -o ignore $(ssh_cmd client) \
              "ping6 -c3 -s6000 fd22:27ca:58fe:3::3"
    # END
    # Wait for tcpdump to finish.
    atf_check sleep 15
    # Some extra time, to make sure tcpdump exits cleanly.
    atf_check sleep 3
    #atf_check kill "$(cat tcpdump.pid)"
    $(ssh_cmd server) "cat /root/pflog.pcap" > "pflog.pcap" ||
        atf_fail "Could not download pflog.pcap from server VM."
    $(ssh_cmd client) "cat > /root/pflog.pcap" < "pflog.pcap" ||
        atf_fail "Could not upload pflog.pcap to client VM."
    # Debug.
    #cp -a "pflog.pcap" ~paggas
    atf_check -o ignore $(ssh_cmd client) \
              "cd /root && ${PYTHON2} test.py testresult2"
}
scrub_forward6_cleanup ()
{
    # Stop VMs.
    vm_destroy client
    vm_destroy server
    # Tear down networking.
    ifconfig bridge6555 destroy
    ifconfig bridge6556 destroy
    ifconfig bridge6557 destroy
    ifconfig tap19302 destroy
    ifconfig tap19303 destroy
    ifconfig tap19304 destroy
    ifconfig tap19305 destroy
    ifconfig tap19306 destroy
    ifconfig tap19307 destroy
    ifconfig tap19308 destroy
    ifconfig tap19309 destroy
}
