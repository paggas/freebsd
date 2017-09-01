#! /bin/sh

# make_baseimg.sh - create base image file for tests needing VMs.
#
# make_baseimg.sh creates a base image file from source.  It needs to
# be pointed to the source directory.  It uses the source build system
# to create an image and then installs needed packages in it.
#
# make_baseimg.sh should be run as root.

name="make_baseimg.sh"

# Change this to point to the source directory.
sourcedir="${1}"

[ -z "${sourcedir}" ] && {
	echo "Usage: ${0} {sourcedir}" >&2
	exit 1
}

error () {
	echo "${name}: ${1}" >&2
}

error_exit () {
	error "${1}"
	exit 1
}

ncpu="$(sysctl -n hw.ncpu)"
baseimg="zroot/tests/pf/baseimg"
mountdir="/mnt/tests/pf/baseimg"

cd "${sourcedir}" || error_exit "Cannot access source directory ${sourcedir}."
#make -j "${ncpu}" buildworld || exit 1
#make -j "${ncpu}" buildkernel || exit 1

cd release || error_exit "Cannot access release/ directory in source directory."
# TODO Instead of make clean, use an alternative target directory.
#make clean || exit 1

sourcedir_canon="$(readlink -f ${sourcedir})"

# Force rebuilding by make release.
chflags -R noschg "/usr/obj${sourcedir_canon}/release" ||
	error_exit "Could not run chflags on \
/usr/obj${sourcedir_canon}/release, wrong object directory?"
rm -fr "/usr/obj${sourcedir_canon}/release" ||
	error_exit "Could not remove /usr/obj${sourcedir_canon}/release, \
wrong object directory?"

make release || error_exit "Cannot run 'make release'."
make vm-image \
     WITH_VMIMAGES="1" VMBASE="vm-tests-pf" \
     VMFORMATS="raw" VMSIZE="3G" ||
	error_exit "Cannot run 'make vm-image'."

cd "/usr/obj${sourcedir_canon}/release" ||
	error_exit "Cannot access /usr/obj${sourcedir_canon}/release, \
wrong object directory?"
zfs create -p "${baseimg}" ||
	error_exit "Cannot create ZFS dataset ${baseimg}, \
is 'zroot' available?"

zmountbase="$(zfs get -H -o value mountpoint "${baseimg}")" ||
	error_exit "Cannot get mountpoint of dataset ${baseimg}!"

install -o root -g wheel -m 0644 \
        "vm-tests-pf.raw" "${zmountbase}/img" ||
	error_exit "Cannot copy image file to ZFS dataset."

mkdir -p "${mountdir}" ||
	error_exit "Cannot create mountpoint ${mountdir}."
md="$(mdconfig ${zmountbase}/img)" ||
	error_exit "Cannot create memory disk for ${zmountbase}/img."
(
	mount "/dev/${md}p3" "${mountdir}" || {
		error "Cannot mount /dev/${md}p3 on ${mountdir}, \
image file malformed?"
		return 1
	}
	(
		chroot "${mountdir}" \
		       env ASSUME_ALWAYS_YES="yes" \
		       pkg install "python27" "scapy" || {
			error "Cannot install packages into image file, \
is there an active internet connection?"
			return 1
		}
	)
	status="$?"
	umount "${mountdir}"
	return "${status}"
)
status="$?"
mdconfig -du "${md}"
return "${status}"
