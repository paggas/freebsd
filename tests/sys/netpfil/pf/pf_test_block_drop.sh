# Starts two virtual machines, the client and the server.  Starts two
# instances of nc on the server, listening on two different ports, of
# which one port is blocked-with-drop by pf.  The client tries then
# to connect to the two instances.  The test succeeds if one
# connection succeeds but the other one fails.
#
# This test is almost the same as block_return, with the difference
# that filtered packets are dropped instead of returned (ICMP or RST
# packet returned).

. "$(atf_get_srcdir)/files/pf_test_util.sh"

aprefix="10.135.213"

atf_init_test_cases ()
{
	atf_add_test_case "test"
}

atf_test_case "test" cleanup
test_head ()
{
	atf_set descr 'Block-with-drop a port and test that it is blocked.'
	atf_set "require.user" "root"
}
test_body ()
{
	block_port="50000"
	pass_port="50001"
	rules="block drop in on vtnet1 proto tcp to port ${block_port}"
	# Initialize test.
	init_test
	# Set up networking.
	tap_auto client tapA "${aprefix}.1/28" \
				vtnet0 "${aprefix}.2/28"
	tap_auto client tapB "${aprefix}.33/28" \
				vtnet1 "${aprefix}.35/28"
	tap_auto server tapC "${aprefix}.17/28" \
				vtnet0 "${aprefix}.18/28"
	tap_auto server tapD "${aprefix}.34/28" \
				vtnet1 "${aprefix}.36/28"
	bridge_auto bridgeA tapB tapD
	# Start VMs.
	vm_create client tapA tapB
	vm_create server tapC tapD
	# Debug
	#atf_check sleep 900
	# Wait for VMs to start up and for their SSH deamons to start
	# listening.
	atf_check sleep 60
	# Start pf.
	atf_check $(ssh_cmd server) "kldload -n pf"
	echo "${rules}" | atf_check -e ignore $(ssh_cmd server) "pfctl -ef -"
	# Start test.
	atf_check daemon -p nc.block.pid $(ssh_cmd server) \
		"nc -l ${block_port}"
	atf_check daemon -p nc.pass.pid $(ssh_cmd server) \
		"nc -l ${pass_port}"
	remote_addr_1="${aprefix}.36"
	atf_check -s exit:1 -e empty $(ssh_cmd client) \
		"nc -z -w 4 ${remote_addr_1} ${block_port}"
	atf_check -s exit:0 -e ignore $(ssh_cmd client) \
		"nc -z ${remote_addr_1} ${pass_port}"
}
test_cleanup ()
{
	# Stop test.
	[ -e nc.block.pid ] && kill "$(cat nc.block.pid)"
	[ -e nc.pass.pid ] && kill "$(cat nc.pass.pid)"
	# # Stop pf.
	# $(ssh_cmd server) "pfctl -dFa ;
	#     kldunload -n pf ;
	#     true"
	# Stop VMs.
	vm_destroy client
	vm_destroy server
	# Tear down networking.
	iface_destroy_all
}
