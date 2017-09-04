# /usr/bin/env python2

import scapy.all as sp
import scapy.layers.pflog

import itertools as it
import multiprocessing as mp
import pickle, random, sys, time

import conf, util

# Data persistent in order to be able to test result later.
try:
    data = pickle.load(open('test.pickle'))
except IOError:
    data = {
        'raw_500': ('abcdefghijklmnopqrstuvwxyz' * 22)[random.randrange(26):][:500],
        'id_rand': random.randrange(1 << 16),
        'seq_rand': random.randrange(1 << 16)
    }
    f = open('test.pickle', 'w')
    pickle.dump(data, f)
    f.close()

raw_500, id_rand, seq_rand = data['raw_500'], data['id_rand'], data['seq_rand']

ether1 = sp.Ether(src=conf.LOCAL_MAC_1, dst=conf.REMOTE_MAC_1)
ether2 = sp.Ether(src=conf.LOCAL_MAC_2, dst=conf.REMOTE_MAC_2)
ip1 = sp.IPv6(src=conf.LOCAL_ADDR6_1, dst=conf.LOCAL_ADDR6_3)
ip2 = sp.IPv6(src=conf.LOCAL_ADDR6_2, dst=conf.LOCAL_ADDR6_3)
icmp = sp.ICMPv6EchoRequest(id=id_rand, seq=seq_rand, data=raw_500)

p1 = ether1 / ip1 / icmp
p2 = ether2 / ip2 / icmp
tofrag1 = ether1 / ip1 / sp.IPv6ExtHdrFragment() / icmp
tofrag2 = ether2 / ip2 / sp.IPv6ExtHdrFragment() / icmp

def sendonly():
    time.sleep(1)
    sp.sendp(sp.fragment6(tofrag1, 400), iface=conf.LOCAL_IF_1, verbose=False)
    sp.sendp(sp.fragment6(tofrag2, 400), iface=conf.LOCAL_IF_2, verbose=False)

def testresult1():
    '''testresult1() - test result using Defragmenter6

    This function is used if traffic is generated using sendonly().'''
    success1, success2 = False, False

    defr = util.Defragmenter6()
    pp1, pp2 = p1.payload, p2.payload # IPv6 layer

    sniffed = sp.sniff(offline='pflog.pcap')

    for p in sniffed:
        pp_nfrag = defr.more(p)
        if pp_nfrag is None:
            print 'CONTINUE'
            continue
        pp, nfrag = pp_nfrag
        print 'SHOW'
        pp.show()

        # At this point, pp is a packet that has been reassembled from
        # sniffed packets.  We can use nfrag to check how many sniffed
        # packets it was reassembled from.

        # Success for interface 1 if packet received in 1 fragment,
        # i.e. scrub active on remote side.
        success1 = success1 or (nfrag == 1 and
                                (pp.src, pp.dst) == (pp1.src, pp1.dst) and
                                str(pp.payload) == str(pp1.payload))

        # Success for interface 2 if packet received in 2 fragments,
        # i.e. no scrub on remote side.
        success2 = success2 or (nfrag == 2 and
                                (pp.src, pp.dst) == (pp2.src, pp2.dst) and
                                str(pp.payload) == str(pp2.payload))

    if not (success1 and success2):
        exit(1)
        
def testresult2():
    '''testresult2() - test result using sets

    This function is used if traffic is generated using ping6.'''
    sniffed = sp.sniff(offline='pflog.pcap')
    packets = [(p[sp.IPv6].src, p[sp.IPv6].dst,
                sp.IPv6ExtHdrFragment in p) for p in sniffed]
    withfrag = set((src, dst)
                   for (src, dst, isfrag) in packets if isfrag)
    withoutfrag = set((src, dst)
                      for (src, dst, isfrag) in packets if not isfrag)
    # By running set() above, we can count the amount of different
    # (src, dst) combinations for packets with and without
    # fragmentation.  Packets to and from REMOTE_ADDR6_1 as well as
    # from REMOTE_ADDR6_2 will be unfragmented, while packets to
    # REMOTE_ADDR6_2 will be fragmented.
    pairs = [
        (conf.LOCAL_ADDR6_1, conf.REMOTE_ADDR6_1),
        (conf.REMOTE_ADDR6_1, conf.LOCAL_ADDR6_1),
        (conf.LOCAL_ADDR6_2, conf.REMOTE_ADDR6_2),
        (conf.REMOTE_ADDR6_2, conf.LOCAL_ADDR6_2),
    ]
    withfrag_correct = set([pairs[2]])
    withoutfrag_correct = set([pairs[0], pairs[1], pairs[3]])
    withfrag_success = (withfrag == withfrag_correct)
    withoutfrag_success = (withoutfrag == withoutfrag_correct)
    if not (withfrag_success and withoutfrag_success):
        exit(1)

if len(sys.argv) < 2:
    exit('%s: No command given.' % sys.argv[0])

if sys.argv[1] == 'sendonly':
    sendonly()
elif sys.argv[1] == 'testresult1':
    testresult1()
elif sys.argv[1] == 'testresult2':
    testresult2()
else:
    exit('%s: Bad command: %s.' % (sys.argv[0], repr(sys.argv[1])))
exit()

# Following sniff-and-reassembly code kept for future usage.

sender = mp.Process(target=sendonly)
sender.start()

sniffed = sp.sniff(iface=conf.LOCAL_IF_3, timeout=10)

sender.join()

for i, p in it.izip(it.count(), sniffed):
    show = []
    while type(p) != sp.NoPayload:
        if type(p) == sp.IPv6:
            show.append(('IPv6', p.src, p.dst))
        elif type(p) == sp.IPv6ExtHdrFragment:
            show.append(('Fragment', p.id, p.offset, p.m))
        elif type(p) == sp.ICMPv6EchoRequest:
            show.append(('Echo-Request', p.data))
        elif type(p) == sp.Raw:
            show.append(('Raw', p.load))
        p = p.payload
    print 'Packet', i, ':', show

success1, success2 = False, False

defr = util.Defragmenter6()
pp1, pp2 = p1.payload, p2.payload # IPv6 layer
for p in sniffed:
    pp_nfrag = defr.more(p)
    if pp_nfrag is None:
        continue
    pp, nfrag = pp_nfrag

    # At this point, pp is a packet that has been reassembled from
    # sniffed packets.  We can use nfrag to check how many sniffed
    # packets it was reassembled from.

    # Success for interface 1 if packet received in 1 fragment,
    # i.e. scrub active on remote side.
    success1 = success1 or (nfrag == 1 and
                            (pp.src, pp.dst) == (pp1.src, pp1.dst) and
                            str(pp.payload) == str(pp1.payload))

    # Success for interface 2 if packet received in 2 fragments,
    # i.e. no scrub on remote side.
    success2 = success2 or (nfrag == 2 and
                            (pp.src, pp.dst) == (pp2.src, pp2.dst) and
                            str(pp.payload) == str(pp2.payload))

if not (success1 and success2):
    exit(1)
