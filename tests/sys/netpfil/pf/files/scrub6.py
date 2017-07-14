# /usr/bin/env python2

import scapy.all as sp

import itertools as it
import multiprocessing as mp
import random, sys, time

import conf, util

raw_500 = ('abcdefghijklmnopqrstuvwxyz' * 22)[random.randrange(26):][:500]

ether1 = sp.Ether(src=conf.LOCAL_MAC_1, dst=conf.REMOTE_MAC_1)
ether2 = sp.Ether(src=conf.LOCAL_MAC_2, dst=conf.REMOTE_MAC_2)
ip1 = sp.IPv6(src=conf.LOCAL_ADDR6_1, dst=conf.LOCAL_ADDR6_3)
ip2 = sp.IPv6(src=conf.LOCAL_ADDR6_2, dst=conf.LOCAL_ADDR6_3)
icmp = sp.ICMPv6EchoRequest(id=random.randrange(1 << 16),
                            seq=random.randrange(1 << 16), data=raw_500)

p1 = ether1 / ip1 / icmp
p2 = ether2 / ip2 / icmp
tofrag1 = ether1 / ip1 / sp.IPv6ExtHdrFragment() / icmp
tofrag2 = ether2 / ip2 / sp.IPv6ExtHdrFragment() / icmp

def sendpackets():
    time.sleep(1)
    sp.sendp(sp.fragment6(tofrag1, 400), iface=conf.LOCAL_IF_1, verbose=False)
    sp.sendp(sp.fragment6(tofrag2, 400), iface=conf.LOCAL_IF_2, verbose=False)

if len(sys.argv) < 2:
    exit('No command given')

if sys.argv[1] == 'sendonly':
    sendpackets()
    exit()
else:
    exit('Bad command: %s' % repr(sys.argv[1]))

# Following sniff-and-reassembly code kept for future usage.

sender = mp.Process(target=sendpackets)
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
