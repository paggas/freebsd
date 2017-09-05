# This test starts two virtual machines, the client and the server.
# It uses scapy to send IPv4 fragmented traffic from the client
# machine to the server machine.  The machines are connected via three
# interfaces.  The client sents traffic to the server via the first
# two interfaces with the client itself as the destination, which the
# server forwards via the third interface back to the client.  Scrub
# is activated on the first but not the second interface on the server
# pf.  By examining the forwarded packets as received on the client,
# we can verify that reassembly occurs on one but not the other
# interface.

. "$(atf_get_srcdir)/files/pf_test_util.sh"

aprefix="10.135.213"

atf_init_test_cases ()
{
    atf_add_test_case "scrub_forward"
}

atf_test_case "scrub_forward" cleanup
scrub_forward_head ()
{
    atf_set descr 'Scrub defrag with forward on one \
of two interfaces and test difference.'
    atf_set "require.user" "root"
}
scrub_forward_body ()
{
    rules="scrub in on vtnet1 all fragment reassemble
pass log (all to pflog0) on { vtnet1 vtnet2 }"
    # Load host modules.
    atf_check kldload -n nmdm
    # Set up networking.
    tap_create client tap19302 "${aprefix}.1/28" vtnet0 "${aprefix}.2/28"
    tap_create server tap19303 "${aprefix}.17/28" vtnet0 "${aprefix}.18/28"
    tap_create client tap19304 "${aprefix}.33/28" vtnet1 "${aprefix}.34/28"
    tap_create server tap19305 "${aprefix}.35/28" vtnet1 "${aprefix}.36/28"
    tap_create client tap19306 "${aprefix}.49/28" vtnet2 "${aprefix}.50/28"
    tap_create server tap19307 "${aprefix}.51/28" vtnet2 "${aprefix}.52/28"
    tap_create client tap19308 "${aprefix}.65/28" vtnet3 "${aprefix}.66/28"
    tap_create server tap19309 "${aprefix}.67/28" vtnet3 "${aprefix}.68/28"
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
    atf_check $(ssh_cmd server) "kldload -n pf"
    echo "${rules}" | atf_check -e ignore $(ssh_cmd server) "pfctl -ef -"
    # Enable forwarding.
    atf_check -o ignore $(ssh_cmd server) "sysctl net.inet.ip.forwarding=1"
    # Warm up connections, so that network discovery is complete.
    atf_check -o ignore $(ssh_cmd client) "ping -c3 ${aprefix}.36"
    atf_check -o ignore $(ssh_cmd client) "ping -c3 ${aprefix}.52"
    atf_check -o ignore $(ssh_cmd client) "ping -c3 ${aprefix}.68"
    # Upload test to VM.
    upload_file client "scrub_forward.py" "test.py"
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
LOCAL_ADDR_1='${aprefix}.34'
LOCAL_ADDR_2='${aprefix}.50'
LOCAL_ADDR_3='${aprefix}.66'
REMOTE_ADDR_1='${aprefix}.36'
REMOTE_ADDR_2='${aprefix}.52'
REMOTE_ADDR_3='${aprefix}.68'
LOCAL_IF_1='vtnet1'
LOCAL_IF_2='vtnet2'
LOCAL_IF_3='vtnet3'" | \
            $(ssh_cmd client) "cat > /root/conf.py"
    ) || atf_fail "Could not upload conf.py to VM."
    # Run test.
    atf_check -o ignore $(ssh_cmd client) "cd /root && ${PYTHON2} test.py"
}
scrub_forward_cleanup ()
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
