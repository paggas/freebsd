# This test starts two virtual machines, the client and the server.
# It uses ping to send IPv4 fragmented echo requests traffic from the
# client machine to the server machine.  The machines are connected
# via three interfaces, of which two are used.  The client sents
# traffic to the server via the first two interfaces.  Scrub is
# activated on the first but not the second interface on the server
# pf.  Tcpdump is run on pflog on the server, capturing traffic in a
# pcap file, which is copied back to the client for examination.  By
# examining the captured packets, we can verify that reassembly occurs
# on one but not the other interface.

. "$(atf_get_srcdir)/files/pf_test_util.sh"

aprefix="10.135.213"

atf_init_test_cases ()
{
	atf_add_test_case "test"
}

atf_test_case "test" cleanup
test_head ()
{
	atf_set descr 'Scrub defrag on one \
of two interfaces and test difference.'
	atf_set "require.user" "root"
}
test_body ()
{
	rules="scrub in on vtnet1 all fragment reassemble
pass log (all to pflog0) on { vtnet1 vtnet2 }"
	# Load host modules.
	atf_check kldload -n nmdm
	# Set up networking.
	tap_create_auto client tapA "${aprefix}.1/28" \
			vtnet0 "${aprefix}.2/28"
	tap_create_auto server tapB "${aprefix}.17/28" \
			vtnet0 "${aprefix}.18/28"
	tap_create_auto client tapC "${aprefix}.33/28" \
			vtnet1 "${aprefix}.34/28"
	tap_create_auto server tapD "${aprefix}.35/28" \
			vtnet1 "${aprefix}.36/28"
	tap_create_auto client tapE "${aprefix}.49/28" \
			vtnet2 "${aprefix}.50/28"
	tap_create_auto server tapF "${aprefix}.51/28" \
			vtnet2 "${aprefix}.52/28"
	tap_create_auto client tapG "${aprefix}.65/28" \
			vtnet3 "${aprefix}.66/28"
	tap_create_auto server tapH "${aprefix}.67/28" \
			vtnet3 "${aprefix}.68/28"
	tapA="$(iface_from_label tapA)"
	tapB="$(iface_from_label tapB)"
	tapC="$(iface_from_label tapC)"
	tapD="$(iface_from_label tapD)"
	tapE="$(iface_from_label tapE)"
	tapF="$(iface_from_label tapF)"
	tapG="$(iface_from_label tapG)"
	tapH="$(iface_from_label tapH)"
	bridge_create_auto bridgeA "${tapC}" "${tapD}"
	bridge_create_auto bridgeB "${tapE}" "${tapF}"
	bridge_create_auto bridgeC "${tapG}" "${tapH}"
	# Start VMs.
	vm_create client "${tapA}" "${tapC}" "${tapE}" "${tapG}"
	vm_create server "${tapB}" "${tapD}" "${tapF}" "${tapH}"
	# Wait for VMs to start up and for their SSH deamons to start
	# listening.
	atf_check sleep 120
	# Start pf.
	atf_check $(ssh_cmd server) "kldload -n pf pflog"
	echo "${rules}" | atf_check -e ignore $(ssh_cmd server) "pfctl -ef -"
	# Enable forwarding.
	atf_check -o ignore $(ssh_cmd server) "sysctl net.inet.ip.forwarding=1"
	# Warm up connections, so that network discovery is complete.
	atf_check -o ignore $(ssh_cmd client) "ping -c3 ${aprefix}.36"
	atf_check -o ignore $(ssh_cmd client) "ping -c3 ${aprefix}.52"
	atf_check -o ignore $(ssh_cmd client) "ping -c3 ${aprefix}.68"
	# Upload test to VM.
	upload_file client "scrub.py" "test.py"
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
	# Debug.
	#atf_check sleep 900
	# Run test.
	# Run tcpdump for 15 seconds.
	atf_check daemon -p tcpdump.pid $(ssh_cmd server) \
		"cd /root && tcpdump -G 15 -W 1 -i pflog0 -w pflog.pcap"
	atf_check sleep 2
	# Alt 1: Generate traffic with scapy.
	# BEGIN
	# atf_check -o ignore $(ssh_cmd client) \
	# 	"cd /root && ${PYTHON2} test.py sendonly"
	# END
	# Alt 2: Generate traffic with ping.
	# BEGIN
	# Run ping with a packet size of 6000, which will cause
	# fragmentation.  By capturing on pflog0, packets to vtnet1 will
	# show up as unfragmented, while packets to vtnet2 will show up as
	# fragmented.  This will later be tested using scrub.py.
	atf_check -o ignore $(ssh_cmd client) \
		"ping -c3 -s6000 ${aprefix}.36"
	atf_check -o ignore $(ssh_cmd client) \
		"ping -c3 -s6000 ${aprefix}.52"
	# END
	# Wait for tcpdump to finish.
	atf_check sleep 15
	# Some extra time, to make sure tcpdump exits cleanly.
	atf_check sleep 3
	$(ssh_cmd server) "cat /root/pflog.pcap" > "pflog.pcap" ||
		atf_fail "Could not download pflog.pcap from server VM."
	$(ssh_cmd client) "cat > /root/pflog.pcap" < "pflog.pcap" ||
		atf_fail "Could not upload pflog.pcap to client VM."
	atf_check -o ignore $(ssh_cmd client) \
		"cd /root && ${PYTHON2} test.py testresult2"
}
test_cleanup ()
{
	# Stop VMs.
	vm_destroy client
	vm_destroy server
	# Tear down networking.
	iface_destroy_all
}
