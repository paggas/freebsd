# Starts two virtual machines, the client and the server.  Starts two
# instances of nc on the server, listening on two different ports, of
# which one port is blocked-with-return by pf.  The client tries then
# to connect to the two instances.  The test succeeds if one
# connection succeeds but the other one fails.
atf_test_case block_return cleanup
block_return_head () {
	atf_set descr 'Block-with-return a port and test that it is blocked.'
	atf_set "require.user" "root"
}
block_return_body () {
	block_port="50000"
	pass_port="50001"
	rules="block return in on vtnet1 proto tcp to port ${block_port}"
	# Set up networking.
	tap_create client tap19302 10.135.213.1/28 vtnet0 10.135.213.2/28
	tap_create client tap19303 10.135.213.33/28 vtnet1 10.135.213.35/28
	tap_create server tap19304 10.135.213.17/28 vtnet0 10.135.213.18/28
	tap_create server tap19305 10.135.213.34/28 vtnet1 10.135.213.36/28
	bridge_create bridge6555 tap19303 tap19305
	# Start VMs.
	vm_create client tap19302 tap19303
	vm_create server tap19304 tap19305
	# Debug
	#atf_check sleep 900
	# Wait for VMs to start up and for their SSH deamons to start
	# listening.
	atf_check sleep 60
	# Start pf.
	atf_check $(ssh_cmd server) "kldload -n pf"
	echo "${rules}" | atf_check -e ignore $(ssh_cmd server) "pfctl -ef -"
	# Start test.
	atf_check daemon -p nc.block.pid $(ssh_cmd server) "nc -l ${block_port}"
	atf_check daemon -p nc.pass.pid $(ssh_cmd server) "nc -l ${pass_port}"
	remote_addr_1="10.135.213.36"
	atf_check -s exit:1 -e empty $(ssh_cmd client) \
		  "nc -z ${remote_addr_1} ${block_port}"
	atf_check -s exit:0 -e ignore $(ssh_cmd client) \
		  "nc -z ${remote_addr_1} ${pass_port}"
}
block_return_cleanup () {
	# Stop test.
	[ -e nc.block.pid ] && kill "$(cat nc.block.pid)"
	[ -e nc.pass.pid ] && kill "$(cat nc.pass.pid)"
	# # Stop pf.
	# $(ssh_cmd server) "pfctl -dFa ;
	#					kldunload -n pf ;
	# 			   true"
	# Stop VMs.
	vm_destroy client
	vm_destroy server
	# Tear down networking.
	ifconfig bridge6555 destroy
	ifconfig tap19302 destroy
	ifconfig tap19303 destroy
	ifconfig tap19304 destroy
	ifconfig tap19305 destroy
}
