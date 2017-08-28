#! /bin/sh

# make_baseimg.sh - create base image file for tests needing VMs.
#
# make_baseimg.sh creates a base image file from source.  It needs to
# be pointed to the source directory.  It uses the source build system
# to create an image and then installs needed packages in it.
#
# make_baseimg.sh should be run as root.

# Change this to point to the source directory.
sourcedir="${1}"

[ -z "${sourcedir}" ] && {
    echo "Usage: ${0} {sourcedir}" >&2
    exit 1
}

ncpu="$(sysctl -n hw.ncpu)"
baseimg="zroot/tests/pf/baseimg"
zmountbase="$(zfs get -H -o value mountpoint "${baseimg}")" || exit 1
mountdir="/mnt/tests/pf/baseimg"

cd "${sourcedir}" || exit 1
make -j "${ncpu}" buildworld || exit 1
make -j "${ncpu}" buildkernel || exit 1

cd release || exit 1
# TODO Instead of make clean, use an alternative target directory.
make clean || exit 1
rm -r "/usr/obj${sourcedir_canon}/release" # force rebuilding by make release
make release || exit 1
make vm-image \
     WITH_VMIMAGES="1" VMBASE="vm-tests-pf" \
     VMFORMATS="raw" VMSIZE="3G" || exit 1
sourcedir_canon="$(readlink -f ${sourcedir})"

cd "/usr/obj${sourcedir_canon}/release" || exit 1
zfs create -p "${baseimg}" || exit 1
cp -ai vm-tests-pf.raw "${zmountbase}/img" || exit 1

mkdir -p "${mountdir}" || exit 1
md="$(mdconfig ${zmountbase}/img)" || exit 1
(
    mount "/dev/${md}p3" "${mountdir}" || return 1
    (
        chroot "${mountdir}" \
               env ASSUME_ALWAYS_YES="yes" \
               pkg install "python2.7" "scapy" || return 1
    )
    status="$?"
    umount "${mountdir}"
    return "${status}"
)
status="$?"
mdconfig -du "${md}"
return "${status}"
