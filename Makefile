# The set of packages to install inside the base snap
seed_packages=filesystem coreutils bash glibc-minimal-langpack
# The list of architectures we wish to build for
arch_list=i686 x86_64 armhfp aarch64
# The Fedora release we are building the base snap with
release=30
version:=$(shell date +%Y.%m.%d)

# NOTE: The rest should of the file should be OK as-is, unchanged

# Options we always pass to dnf
dnf_opts += --setopt=install_weak_deps=False
dnf_opts += --setopt=tsflags=nodocs
dnf_opts += --assumeyes
dnf_opts += --releasever=$(release)
dnf_opts += --config=fedora.conf

# Ensure we are invoked as root (or seem to).
ifneq ($(shell id -u),0)
$(error This makefile needs to be run as root (or working fakeroot))
endif

# The native architecture
my_arch:=$(shell uname -m)

# Fedora to snap store architecture mappings
arch_mapping[x86_64]=amd64
arch_mapping[i686]=i386
arch_mapping[armhfp]=armhf
arch_mapping[aarch64]=arm64

# Ensure we have a mapping for the architectures we choose to build for
$(foreach arch,$(arch_list),$(if $(arch_mapping[$(arch)]),,$(error Please provide snap store architecture equivalent for $(arch))))

# Build all the base snap for the current architecture by default
.PHONY: all
all: fedora$(release)_$(version)_$(my_arch).snap

# This is how you build a fedora base snap
fedora$(release)_$(version)_%.snap: arch=$*
fedora$(release)_$(version)_%.snap: cache=$(CURDIR)/cache.$(arch)
fedora$(release)_$(version)_%.snap: prime=$(CURDIR)/prime.$(arch)
$(foreach arch,$(arch_list),fedora$(release)_$(version)_$(arch).snap): fedora$(release)_$(version)_%.snap: cache.% Makefile
	# Copy the cache directory to the prime directory where we prepare our snap.
	rsync -a $(cache)/ $(prime)/

	dnf $(dnf_opts) --forcearch=$(arch) --cacheonly --installroot=$(prime) install $(seed_packages)

	# Install the /meta/snap.yaml file, replacing the @ARCH@ and @VERSION@ fields as appropriate
	install -d $(prime)/meta
	sed -e 's/@VERSION@/$(version)/g' -e 's/@ARCH@/$(arch_mapping[$(arch)])/g' snap.yaml.in > $(prime)/meta/snap.yaml

	# Install mount points for snapd integration:
	#  - /snap where snaps are exposed
	#  - /var/snap where system-wide per-snap state is exposed
	#  - /var/lib/snapd where snapd state is exposed:
	#  - /usr/lib/snapd where snapd.snap (snapd itself) is exposed
	install -d $(prime)/{snap,var/snap,var/lib/snapd,usr/lib/snapd}

	# Remove log and cache files.
	rm -rf $(prime)/var/log/*
	rm -rf $(prime)/var/cache/dnf
	rm -rf $(prime)/var/tmp/*

	# Remove build-id files.
	rm -rf $(prime)/usr/lib/.build-id

	# Remove RPM and DNF meta-data
	rm -rf $(prime)/var/lib/{rpm,dnf}

	# Remove everything in the /etc directory, leaving a few empty integration
	# points (for bind mounting):
	#  - /etc/alternatives (directory)
	#  - /etc/ssl (directory)
	rm -rf $(prime)/etc/*
	install -d $(prime)/etc/{alternatives,ssl}

	# Integration points for bind mounts:
	# - /usr/share/fonts
	# - /usr/local/share/fonts
	# - /var/cache/fontconfig
	#   NOTE: Fedora uses /usr/lib/fontconfig/cache, however
	#   /etc/fonts/fonts.conf from the host is visible within the mount ns of
	#   the snap, thus per host's confguration, the cache may reside in
	#   /var/cache/fontconfig
	install -d $(prime)/usr/share/fonts
	install -d $(prime)/usr/local/share/fonts
	install -d $(prime)/var/cache/fontconfig

	# Neuter all the setuid root executables that are flagged by store review.
	# Eventually this can be reviewed and decided upon (if said executable
	# should exist and should be +s) but for the purpose of iteration is not
	# done at this moment.
	chmod -R -s $(prime)

	# Create the squashfs file
	mksquashfs $(prime) $@ -noappend -comp xz -no-xattrs -no-fragments

# The cache target just makes the process work off-line.
# Good for testing during boring flights
.PHONY: cache
cache: $(foreach arch,$(arch_list),cache.$(arch))

# This is how you cache data for a given architecture.
cache.%: cache=$(CURDIR)/cache.$*
cache.%: arch=$*
$(foreach arch,$(arch_list),cache.$(arch)): cache.%:
	install -d -m 755 $@
	dnf $(dnf_opts) --forcearch=$(arch) --installroot=$(cache) makecache
	dnf $(dnf_opts) --forcearch=$(arch) --installroot=$(cache) --downloadonly install $(seed_packages)
	touch $@

# The clean target removes the working directories, but not the cache.
.PHONY: clean
clean:
	rm -rf $(foreach arch,$(arch_list),prime.$(arch))
	rm -f  $(foreach arch,$(arch_list),fedora$(release)_$(version)_$(arch).snap)

# The distclean target removes the cache and everything clean would remove.
.PHONY: distclean
distclean: clean
	rm -rf $(foreach arch,$(arch_list),cache.$(arch))
