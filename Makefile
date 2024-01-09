# Build Geth as follows:
#
# - make               -- create non-SGX no-debug-log manifest
# - make SGX=1         -- create SGX no-debug-log manifest
# - make SGX=1 DEBUG=1 -- create SGX debug-log manifest
#
# Any of these invocations clones Geth' git repository and builds Geth in
# default configuration.
#
# Use `make clean` to remove Gramine-generated files and `make distclean` to
# additionally remove the cloned Geth git repository.

################################# CONSTANTS ###################################

# directory with arch-specific libraries, used by Geth
# the below path works for Debian/Ubuntu; for CentOS/RHEL/Fedora, you should
# overwrite this default like this: `ARCH_LIBDIR=/lib64 make`
ARCH_LIBDIR ?= /lib/$(shell $(CC) -dumpmachine)

ENCLAVE_SIZE ?= 16G

MBEDTLS_PATH = https://github.com/ARMmbed/mbedtls/archive/mbedtls-3.3.0.tar.gz

GPP = g++ -std=c++17
GORUN = env GO111MODULE=on go run
SRCDIR = go-ethereum

GOMODCACHE = $(shell go env GOMODCACHE)

SRCDIR = go-ethereum

.PHONY: all
all: geth geth.manifest geth.manifest.sgx geth.sig

############################## GETH ARGUMENTS #################################

geth.args:
	gramine-argv-serializer \
		./geth \
		    --datadir=/go-ethereum/geth-network/miner \
		    --networkid=15 \
		    --port=30305 \
			--verbosity=3 \
			--nodiscover \
			--nat=none \
			--http \
			--http.api=eth,net,engine,admin \
			--http.port=8552 \
			--http.corsdomain=* \
			--http.addr=0.0.0.0 \
			--http.api=personal,eth,net,web3,txpool,miner,admin \
			--authrpc.vhosts=* \
            --authrpc.addr=0.0.0.0 \
            --ws \
            --ws.api=engine,eth,web3,net,debug \
            --authrpc.jwtsecret=/etc/jwt.hex \
			--rpc.allow-unprotected-txs \
			--authrpc.port=8553 \
			--allow-insecure-unlock \
			--keystore=/go-ethereum/geth-network/miner/keystore/ \
			--unlock=0x88aaEdAdB70a1ed0Cbbb744214f7CC4Ad8D429b2 \
			--password=/go-ethereum/geth-network/miner/keystore/pw1.txt \
			--mine \
            --miner.etherbase 0x88aaEdAdB70a1ed0Cbbb744214f7CC4Ad8D429b2 \
		> $@

############################## GETH EXECUTABLE ###############################

#POW not support, so can't use this command line 
#--mine \
#--miner.etherbase 0x88aaEdAdB70a1ed0Cbbb744214f7CC4Ad8D429b2 \

$(SRCDIR)/build/bin/geth:
	cd $(SRCDIR) && \
		go build -ldflags "-extldflags '-Wl,-z,stack-size=0x800000,-fuse-ld=gold'" -tags urfave_cli_no_docs -trimpath -v -o $(PWD)/$(SRCDIR)/build/bin/geth ./cmd/geth

################################## GETH INIT #################################

CFLAGS += $(shell pkg-config --cflags mbedtls_gramine)
LDFLAGS += -ldl -Wl,--enable-new-dtags $(shell pkg-config --libs mbedtls_gramine)

##################### REMOTE ATTESTATION CLIENT ##############################

mbedtls:
	wget $(MBEDTLS_PATH) -O mbedtls.tgz
	mkdir mbedtls
	tar -xvzf mbedtls.tgz -C mbedtls --strip-components 1
	rm mbedtls.tgz

attest: attest.c mbedtls
	C_INCLUDE_PATH=mbedtls/include $(CC) $< $(CFLAGS) $(LDFLAGS) -o $@

################################ GETH MANIFEST ###############################

RA_TYPE		?= dcap
ISVPRODID	?= 0
ISVSVN		?= 0

geth.manifest: geth.manifest.template geth.args
	gramine-manifest \
		-Darch_libdir=$(ARCH_LIBDIR) \
		-Dentrypoint="./geth" \
		-Disvprodid=$(ISVPRODID) \
		-Disvsvn=$(ISVSVN) \
		-Denclave_size=$(ENCLAVE_SIZE) \
		$< >$@

geth.manifest.sgx geth.sig: sgx_sign
	@:

.INTERMEDIATE: sgx_sign
sgx_sign: geth.manifest
	gramine-sgx-sign \
		--manifest $< \
		--output $<.sgx

########################### COPIES OF EXECUTABLES #############################

geth: $(SRCDIR)/build/bin/geth
	cp  $< $@

############################## RUNNING TESTS ##################################

.PHONY: check
check: all
	./run-tests.sh > TEST_STDOUT 2> TEST_STDERR
	@grep -q "Success 1/4" TEST_STDOUT
	@grep -q "Success 2/4" TEST_STDOUT
	@grep -q "Success 3/4" TEST_STDOUT
	@grep -q "Success 4/4" TEST_STDOUT
ifeq ($(SGX),1)
	@grep -q "Success SGX quote" TEST_STDOUT
endif

################################## CLEANUP ####################################

.PHONY: clean
clean:
	$(RM) *.manifest *.manifest.sgx *.sig *.args OUTPUT* *.PID TEST_STDOUT TEST_STDERR

.PHONY: distclean
distclean: clean
	$(RM) -rf  geth geth_init mbedtls attest