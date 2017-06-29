# Make will add a shebang line at the top of this file.

# These tests connect to a remote test machine, load a rules file,
# possibly start some services, and run some tests.  The tests cleanup
# the test machine in the end.
#
# SSH root access to the test machine is required for the tests to
# work.

. "$(atf_get_srcdir)/pf_test.conf.sh"

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
    rules="block return in on $REMOTE_IF proto tcp to port 50000"
    atf_check ssh "$SSH" kldload -n pf
    echo "$rules" | atf_check -e ignore ssh "$SSH" pfctl -ef -
    atf_check daemon -p nc.50000.pid ssh "$SSH" nc -l 50000
    atf_check daemon -p nc.50001.pid ssh "$SSH" nc -l 50001
    atf_check -s exit:1 -e empty  nc -z "$REMOTE_ADDR" 50000
    atf_check -s exit:0 -e ignore nc -z "$REMOTE_ADDR" 50001
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
    rules="block drop in on $REMOTE_IF proto tcp to port 50000"
    atf_check ssh "$SSH" kldload -n pf
    echo "$rules" | atf_check -e ignore ssh "$SSH" pfctl -ef -
    atf_check daemon -p nc.50000.pid ssh "$SSH" nc -l 50000
    atf_check daemon -p nc.50001.pid ssh "$SSH" nc -l 50001
    atf_check -s exit:1 -e empty  nc -z -w 4 "$REMOTE_ADDR" 50000
    atf_check -s exit:0 -e ignore nc -z "$REMOTE_ADDR" 50001
}
block_drop_cleanup () {
    atf_check -e ignore ssh "$SSH" pfctl -dFa
    [ -e nc.50000.pid ] && kill `cat nc.50000.pid`
    [ -e nc.50001.pid ] && kill `cat nc.50001.pid`
}

atf_init_test_cases () {
    atf_add_test_case block_return
    atf_add_test_case block_drop
}
