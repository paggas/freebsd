# $FreeBSD$

PACKAGE=	tests

TESTSDIR=	${TESTSBASE}/sys/netpfil/pf
BINDIR=		${TESTSDIR}

ATF_TESTS_SH=	pf_test_block_drop \
		pf_test_block_return \
		pf_test_scrub_forward \
		pf_test_scrub_forward6

${PACKAGE}FILES+=	README
SUBDIR+=		files

.include <bsd.test.mk>
