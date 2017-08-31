# Make will add a shebang line at the top of this file.

# These tests connect to a remote test machine, load a rules file,
# possibly start some services, and run some tests.  The tests cleanup
# the test machine in the end.
#
# SSH root access to the test machine is required for the tests to
# work.

. "$(atf_get_srcdir)/files/pf_test_util.sh"

# Load all tests.  Filenames must match test names, e.g. test foobar
# will be in file "test_foobar.sh".
find -x "$(atf_get_srcdir)/files" -name "test_*.sh" > "alltests.txt"
alltests="$(cat alltests.txt)"
for i in ${alltests} ; do
	. "${i}"
done

atf_init_test_cases () {
	alltests="$(cat alltests.txt)"
	for i in ${alltests} ; do
		test="$(echo "${i}" | sed -E 's:^.*/test_([^/]*)\.sh\$:\1:')"
		atf_add_test_case "${test}"
	done
}

# Old tests kept here for future reference.

# This test uses 2 interfaces to connect to the test machine,
# $REMOTE_IF_1 and $REMOTE_IF_2.  The test machine is doing reassembly
# on one of the two interfaces.  We send one echo request on each
# interface of size 3000, which will be fragmented before being sent.
# We capture the traffic on the test machine's pflog and transfer the
# capture file to the host machine for processing.  The capture file
# should show a reassembled echo request packet on one interface and
# the original fragmented set of packets on the other.
# atf_test_case remote_scrub_todo cleanup
# remote_scrub_todo_head () {
#	 atf_set descr 'Scrub on one of two interfaces and test difference.'
# }
# remote_scrub_todo_body () {
#	 # files to be used in local directory: tempdir.var tcpdump.pid
#	 # files to be used in remote temporary directory: pflog.pcap
#	 rules="scrub in on $REMOTE_IF_1 all fragment reassemble
#			pass log (all, to pflog0) on { $REMOTE_IF_1 $REMOTE_IF_2 }"
#	 atf_check ssh "$SSH_0" 'kldload -n pf pflog'
#	 echo "$rules" | atf_check -e ignore ssh "$SSH_0" 'pfctl -ef -'
#	 atf_check -o save:tempdir.var ssh "$SSH_0" 'mktemp -dt pf_test.tmp'
#	 #atf_check_equal 0 "$?"
#	 tempdir="$(cat tempdir.var)"
#	 timeout=5
#	 atf_check daemon -p tcpdump.pid ssh "$SSH_0" \
# 	   "timeout $timeout tcpdump -U -i pflog0 -w $tempdir/pflog.pcap"
#	 (cd "$(atf_get_srcdir)/files" &&
#	 	atf_check python2 scrub6.py sendonly)
#	 # Wait for tcpdump to pick up everything.
#	 atf_check sleep "$(expr "$timeout" + 2)"
#	 # Not sure if following will work with atf_check
#	 atf_check scp "$SSH_0:$tempdir/pflog.pcap" ./
#	 # Following will be removed when the test is complete, but
#	 # since processing isn't implemented yet, we just save the file
#	 # for now.
#	 atf_check cp pflog.pcap "$(atf_get_srcdir)/"
#	 # Process pflog.pcap for verification
# }
# remote_scrub_todo_cleanup () {
#	 kill "$(cat tcpdump.pid)"
#	 tempdir="$(cat tempdir.var)"
#	 ssh "$SSH_0" "rm -r \"$tempdir\" ; pfctl -dFa"
# }

# atf_test_case scrub_pflog cleanup
# scrub_pflog_head () {
#	 atf_set descr 'Scrub defrag with pflog on one \
# of two interfaces and test difference.'
# }
# scrub_pflog_body () {
#	 pair_create 0 1
#	 rules="scrub in on ${PAIR_0_IF_A} all fragment reassemble
#			pass log (all to ${PFLOG_IF}) on { ${PAIR_0_IF_A} ${PAIR_1_IF_A} }"
#	 cd "$(atf_get_srcdir)"
#	 # Enable pf.
#	 atf_check kldload -n pf pflog
#	 atf_check ifconfig pflog0 up
#	 echo "$rules" | atf_check -e ignore pfctl -ef -
#	 # Run test.
#	 cd files
#	 atf_check python2 scrub_pflog.py
# }
# scrub_pflog_cleanup () {
#	 pfctl -dFa
#	 ifconfig pflog0 down
#	 kldunload -n pf pflog
#	 pair_destroy 0 1
# }
