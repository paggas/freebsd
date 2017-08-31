# $FreeBSD$

TESTSDIR=	${TESTSBASE}/sys/netpfil/pf/files
BINDIR=		${TESTSDIR}

FILES=		pf_test_conf.sh pf_test_util.sh \
		scrub_forward.py scrub6.py conf.py util.py \
		make_baseimg.sh vmctl.sh \
		test_block_drop.sh \
		test_block_return.sh \
		test_scrub_forward.sh \
		test_scrub_forward6.sh

FILESMODE_make_baseimg.sh=	0555
FILESMODE_vmctl.sh=		0555

.include <bsd.progs.mk>
