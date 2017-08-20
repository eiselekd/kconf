all:

test:
	perl kconfcmp diff t/config-test-4.13.txt t/config-test-4.13.txt
	perl kconfcmp read t/linux-4.4.0/arch/arm64/Kconfig 2>&1 | tee t/parse.txt 
