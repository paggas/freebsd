# /usr/bin/env python2

import scapy.all as sp
import scapy.layers.pflog

import itertools as it
import multiprocessing as mp
import random, sys, time

import conf, util

raw_200 = ('abcdefghijklmnopqrstuvwxyz' * 9)[random.randrange(26):][:200]
raw_300 = ('abcdefghijklmnopqrstuvwxyz' * 13)[random.randrange(26):][:300]
raw_500 = ('abcdefghijklmnopqrstuvwxyz' * 21)[random.randrange(26):][:500]

ether1 = sp.Ether(src=conf.LOCAL_MAC_1, dst=conf.REMOTE_MAC_1)
ether2 = sp.Ether(src=conf.LOCAL_MAC_2, dst=conf.REMOTE_MAC_2)
ip1 = sp.IP(src=conf.LOCAL_ADDR_1,
            dst=conf.LOCAL_ADDR_3, id=random.randrange(1 << 16))
ip2 = sp.IP(src=conf.LOCAL_ADDR_2,
            dst=conf.LOCAL_ADDR_3, id=random.randrange(1 << 16))
icmp = sp.ICMP(type='echo-request',
               id=random.randrange(1 << 16), seq=random.randrange(1 << 16))

RAWSIZE = '200'

if RAWSIZE == '200':
    p1 = ether1 / ip1 / icmp / raw_200
    p2 = ether2 / ip2 / icmp / raw_200
    fragsize = 125
elif RAWSIZE == '300':
    p1 = ether1 / ip1 / icmp / raw_300
    p2 = ether2 / ip2 / icmp / raw_300
    fragsize = 200
elif RAWSIZE == '500':
    p1 = ether1 / ip1 / icmp / raw_500
    p2 = ether2 / ip2 / icmp / raw_500
    fragsize = 300
else:
    print >>sys.stderr, '%s: Invalid RAWSIZE set.' % __name__
    exit(1)

def sendonly():
    time.sleep(1)
    sp.sendp(sp.fragment(p1, fragsize), iface=conf.LOCAL_IF_1, verbose=False)
    sp.sendp(sp.fragment(p2, fragsize), iface=conf.LOCAL_IF_2, verbose=False)

def testresult2():
    '''testresult2() - test result using sets

    This function is used if traffic is generated using ping.'''
    sniffed = sp.sniff(offline='pflog.pcap')
    packets = [(p[sp.IP].src, p[sp.IP].dst, util.isfrag(p))
               for p in sniffed if sp.IP in p]
    print '==== BEGIN packets ===='
    print packets
    print '==== END packets ===='
    withfrag = set((src, dst)
                   for (src, dst, isfrag) in packets if isfrag)
    withoutfrag = set((src, dst)
                      for (src, dst, isfrag) in packets if not isfrag)
    # By running set() above, we can count the amount of different
    # (src, dst) combinations for packets with and without
    # fragmentation.  Packets to and from REMOTE_ADDR_1 as well as
    # from REMOTE_ADDR_2 will be unfragmented, while packets to
    # REMOTE_ADDR_2 will be fragmented.
    pairs = [
        (conf.LOCAL_ADDR_1, conf.REMOTE_ADDR_1),
        (conf.REMOTE_ADDR_1, conf.LOCAL_ADDR_1),
        (conf.LOCAL_ADDR_2, conf.REMOTE_ADDR_2),
        (conf.REMOTE_ADDR_2, conf.LOCAL_ADDR_2),
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

sniffed = sp.sniff(iface=conf.LOCAL_IF_3, timeout=5)

sender.join()

# for i, p in it.izip(it.count(), sniffed):
#     print '==== Packet', i, '===='
#     p.show()
#     print

def debug1(p):
    ''''Debug1.'''
    layers = []
    while p:
        layers.append(type(p))
        p = p.payload
    return tuple(layers)

success1, success2 = False, False

defr = util.Defragmenter()
pp1, pp2 = p1.payload, p2.payload # IP layer
k1, k2 = util.pkey(pp1), util.pkey(pp2)
for p in sniffed:
    print debug1(p) # Debug.
    pp = defr.more(p)
    if pp is None:
        continue
    k = util.pkey(pp)

    # Success for interface 1 if packet received in 1 fragment,
    # i.e. scrub active on remote side.
    if not success1:
        # print 'success1 == False'
        success1 = (k == k1 and defr.stats[k] == 1 and
                    str(pp.payload) == str(pp1.payload))
        # print 'success1 ==', success1

    # Success for interface 2 if packet received in 2 fragments,
    # i.e. no scrub on remote side.
    if not success2:
        # print 'success2 == False'
        success2 = (k == k2 and defr.stats[k] == 2 and
                    str(pp.payload) == str(pp2.payload))
        # print 'success2 ==', success2

# print 'success1 ==', success1
# print 'success2 ==', success2

if not (success1 and success2):
    exit(1)
