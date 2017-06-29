# atf-sh, to be sourced by run.sh

# Keep description string without whitespace, or problems might occur
# with the eval expressions in the main file!

pf0001_descr () { echo "pass" ; }
pf0002_descr () { echo "return" ; }
pf0003_descr () { echo "flags" ; }
pf0004_descr () { echo "port" ; }
pf0005_descr () { echo "var" ; }
pf0006_descr () { echo "assign" ; }
pf0007_descr () { echo "modulate" ; }
pf0008_descr () { echo "extern" ; }
pf0009_descr () { echo "interfaces" ; }
pf0010_descr () { echo "return var" ; }
pf0011_descr () { echo "icmp type" ; }
pf0012_descr () { echo "from not" ; }
pf0013_descr () { echo "quick any" ; }
pf0014_descr () { echo "quick on" ; }
pf0016_descr () { echo "no state" ; }
pf0018_descr () { echo "test list" ; }
pf0019_descr () { echo "evil good in" ; }
pf0020_descr () { echo "evil good out" ; }
pf0022_descr () { echo "set" ; }
pf0023_descr () { echo "block on not" ; }
pf0024_descr () { echo "pass assign" ; }
pf0025_descr () { echo "antispoof" ; }
pf0026_descr () { echo "block bracket" ; }
pf0028_descr () { echo "block quick" ; }
pf0030_descr () { echo "line continuation" ; }
pf0031_descr () { echo "block policy" ; }
pf0032_descr () { echo "pass to any" ; }
pf0034_descr () { echo "probability" ; }
pf0035_descr () { echo "match on tos" ; }
pf0038_descr () { echo "user" ; }
pf0039_descr () { echo "random ordered opts" ; }
pf0040_descr () { echo "block pass" ; }
pf0041_descr () { echo "anchor" ; }
pf0047_descr () { echo "label" ; }
pf0048_descr () { echo "table" ; }
pf0049_descr () { echo "network broadcast" ; }
pf0050_descr () { echo "double macro set" ; }
pf0052_descr () { echo "set optimization" ; }
pf0053_descr () { echo "pass to label" ; }
pf0055_descr () { echo "set timeout" ; }
pf0056_descr () { echo "bracket opts" ; }
pf0057_descr () { echo "double assign" ; }
pf0060_descr () { echo "netmask multicast" ; }
pf0061_descr () { echo "dynaddr with netmask" ; }
pf0065_descr () { echo "antispoof label" ; }
pf0067_descr () { echo "tag regress" ; }
pf0069_descr () { echo "pass tag regress" ; }
pf0070_descr () { echo "block out tag regress" ; }
pf0071_descr () { echo "block in tag regress" ; }
pf0072_descr () { echo "binat to tag regress" ; }
pf0074_descr () { echo "synproxy" ; }
pf0075_descr () { echo "tag ssh" ; }
pf0077_descr () { echo "dynaddr netmask" ; }
pf0078_descr () { echo "table regress" ; }
pf0079_descr () { echo "no route" ; }
pf0081_descr () { echo "ip list table list" ; }
pf0082_descr () { echo "pass from table" ; }
pf0084_descr () { echo "source track" ; }
pf0085_descr () { echo "tag macro expansion" ; }
pf0087_descr () { echo "rule reordering" ; }
pf0088_descr () { echo "duplicate rules" ; }
pf0089_descr () { echo "tcp connection tracking" ; }
pf0090_descr () { echo "log bracket" ; }
pf0091_descr () { echo "nested anchor" ; }
pf0092_descr () { echo "comments" ; }
pf0094_descr () { echo "ipv6 range" ; }
pf0095_descr () { echo "include" ; }
pf0096_descr () { echo "varset" ; }
pf0097_descr () { echo "divert to" ; }
pf0098_descr () { echo "pass all" ; }
pf0100_descr () { echo "anchor paths" ; }
pf0101_descr () { echo "prio" ; }
pf0102_descr () { echo "mixed af" ; }
pf0104_descr () { echo "localhost divert to" ; }
pf1001_descr () { echo "binat" ; }
pf1002_descr () { echo "set timeout interval" ; }
pf1003_descr () { echo "altq" ; }
pf1004_descr () { echo "altq cbq codel" ; }
