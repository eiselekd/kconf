all:

test:
	perl kconfcmp read t/linux-4.4.0/arch/arm64/Kconfig
	perl kconfcmp diff t/config-test-4.13.txt t/config-test-4.13.txt
