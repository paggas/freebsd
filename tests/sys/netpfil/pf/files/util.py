# python2

import scapy.all as sp

def pkey(packet):
    '''Packet key.'''
    return (packet.src, packet.dst, packet.proto, packet.id)

class Defragmenter(object):
    def __init__(self):
        self.frags = dict()
        self.stats = dict()
    def more(self, packet):
        '''Add fragmented packet, return whole packet if complete.'''

        # Find IP layer.
        p = packet
        while p.name != 'NoPayload':
            if p.name == 'IP':
                break
            p = p.payload
        else:
            return

        # # Return directly if not fragmented.
        # if not ((p.flags & 1) or p.frag): # & 1 for MF
        #     return p

        # Add fragment to its packet group.
        key, val = pkey(p), (p.frag, p)
        if key in self.frags:
            self.frags[key].append(val)
            self.stats[key] += 1
        else:
            self.frags[key] = [val]
            self.stats[key] = 1
        frag = self.frags[key]
        frag.sort()

        # Now all fragments in the group are sorted,
        # go through them and connect them.
        i = 0
        while i + 1 < len(frag):
            f1, p1 = frag[i]
            f2, p2 = frag[i + 1]
            len1, len2 = len(p1.payload), len(p2.payload)
            if len1 == (f2 - f1) * 8:
                header1 = sp.IP(tos=p1.tos, flags=p1.flags, ttl=p1.ttl,
                                src=p1.src, dst=p1.dst,
                                proto=p1.proto, id=p1.id)
                # Now copy MF flag from p2.
                header1.flags = (header1.flags & ~1) | (p2.flags & 1)
                p = header1 / (str(p1.payload) + str(p2.payload))
                frag[i:i + 2] = [(f1, p)]
            else:
                i += 1

        # Return packet if complete.
        p = frag[0][1]
        isfirst, islast = (not p.frag), (not (p.flags & 1))
        if len(frag) == 1 and isfirst and islast:
            del self.frags[key]
            return p
