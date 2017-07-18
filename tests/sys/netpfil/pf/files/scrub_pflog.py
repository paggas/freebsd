# /usr/bin/env python2

import multiprocessing as mp
import scapy.layers.pflog
import scapy.all as sp
import conf
import time
import random
import itertools as it

import util

raw_500 = ('abcdefghijklmnopqrstuvwxyz' * 22)[random.randrange(26):][:500]

ether1 = sp.Ether(src=conf.PAIR_0_MAC_A, dst=conf.PAIR_0_MAC_B)
ether2 = sp.Ether(src=conf.PAIR_1_MAC_A, dst=conf.PAIR_1_MAC_B)
ip1 = sp.IP(src=conf.PAIR_0_ADDR_A,
            dst=conf.PAIR_0_ADDR_B, id=random.randrange(1 << 16))
ip2 = sp.IP(src=conf.PAIR_1_ADDR_A,
            dst=conf.PAIR_1_ADDR_B, id=random.randrange(1 << 16))
icmp = sp.ICMP(type='echo-request',
               id=random.randrange(1 << 16), seq=random.randrange(1 << 16))

p1 = ether1 / ip1 / icmp / raw_500
p2 = ether2 / ip2 / icmp / raw_500

def sendpackets():
    time.sleep(1)
    sp.sendp(sp.fragment(p1, 300), iface=conf.PAIR_0_IF_A, verbose=False)
    sp.sendp(sp.fragment(p2, 300), iface=conf.PAIR_1_IF_A, verbose=False)

sender = mp.Process(target=sendpackets)
sender.start()

sniffed = sp.sniff(iface=conf.PFLOG_IF, timeout=5)
#sniffed = sp.sniff(iface=conf.PAIR_1_IF_B, timeout=5)

sender.join()

for i, p in it.izip(it.count(), sniffed):
    if sp.IP in p:
        print '==== Packet', i, '===='
        p.show()
        print

success1, success2 = False, False

defr = util.Defragmenter()
pp1, pp2 = p1.payload, p2.payload # IP layer
k1, k2 = util.pkey(pp1), util.pkey(pp2)
for p in sniffed:
    pp = defr.more(p)
    if pp is None:
        continue
    k = util.pkey(pp)

    # Success for interface 1 if packet received in 1 fragment,
    # i.e. scrub active on remote side.
    success1 = success1 or (k == k1 and defr.stats[k] == 1 and
                            str(pp.payload) == str(pp1.payload))

    # Success for interface 2 if packet received in 2 fragments,
    # i.e. no scrub on remote side.
    success2 = success2 or (k == k2 and defr.stats[k] == 2 and
                            str(pp.payload) == str(pp2.payload))

if not (success1 and success2):
    exit(1)
