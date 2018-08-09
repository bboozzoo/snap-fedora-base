# The set of packages to install inside the base snap
seed_packages=filesystem coreutils bash util-linux glibc-minimal-langpack
unseed_packages=
# The Fedora release we are building the base snap with
release=29

# The rest should be unchanged
dnf_opts += --setopt=install_weak_deps=False
dnf_opts += --setopt=tsflags=nodocs
dnf_opts += --assumeyes
dnf_opts += --releasever=$(release)
dnf_opts += --config=fedora.conf

.PHONY: snap
.ONESHELL: snap
snap: dnf_opts += --cacheonly
snap:
	# Copy the cache directory to the prime directory where we prepare our snap.
	sudo rsync -a $(CURDIR)/cache/ $(CURDIR)/prime/

	# Install the required packages into the prime directory.
	# XXX: install the filesystem package first as otherwise the info package just hangs.
	sudo dnf $(dnf_opts) --installroot=$(CURDIR)/prime install filesystem glibc-minimal-langpack
	sudo dnf $(dnf_opts) --installroot=$(CURDIR)/prime install $(seed_packages)

	# Remove packages we don't want in the base snap.
	# sudo dnf $(dnf_opts) --installroot=$(CURDIR)/prime remove $(unseed_packages)
	# Install the /meta/snap.yaml file
	sudo install -d $(CURDIR)/prime/meta
	sudo install -m 644 snap.yaml $(CURDIR)/prime/meta/

	# Install mount points for snapd integration:
	#  - /snap where snaps are exposed
	#  - /var/snap where system-wide per-snap state is exposed
	#  - /var/lib/snapd where snapd state is exposed:
	#  - /usr/lib/snapd where snapd.snap (snapd itself) is exposed
	sudo install -d $(CURDIR)/prime/{snap,var/snap,var/lib/snapd,usr/lib/snapd}

	# Remove log and cache files.
	sudo rm -rf $(CURDIR)/prime/var/log/*
	sudo rm -rf $(CURDIR)/prime/var/cache/dnf
	sudo rm -rf $(CURDIR)/prime/var/tmp/*

	# Remove build-id files.
	sudo rm -rf $(CURDIR)/prime/usr/lib/.build-id

	# Remove RPM and DNF meta-data
	sudo rm -rf $(CURDIR)/prime/var/lib/{rpm,dnf}

	# Remove everything in the /etc directory, leaving a few empty integration
	# points (for bind mounting):
	#  - /etc/nsswitch.conf
	#  - /etc/alternatives (directory)
	#  - /etc/ssl (directory)
	sudo rm -rf $(CURDIR)/prime/etc/*
	sudo install -d $(CURDIR)/prime/etc/{alternatives,ssl}
	sudo touch $(CURDIR)/prime/etc/nsswitch.conf

	# Make all of the files in the snap owner-writable. This is works around a
	# bug in the store: https://bugs.launchpad.net/snapstore/+bug/1786071
	sudo chmod -R -v +w $(CURDIR)/prime

	# Neuter all the setuid root executables that are flagged by store review.
	# Eventually this can be reviewed and decided upon (if said executable
	# should exist and should be +s) but for the purpose of iteration is not
	# done at this moment.
	sudo chmod -s \
		$(CURDIR)/prime/usr/bin/{chage,gpasswd,mount,newgidmap,newgrp,newuidmap,su,umount,write} \
		$(CURDIR)/prime/usr/libexec/utempter/utempter \
		$(CURDIR)/prime/usr/sbin/pam_timestamp_check \
		$(CURDIR)/prime/usr/sbin/unix_chkpwd

	# Create the squashfs file
	sudo mksquashfs ./prime fedora29.snap -noappend -comp xz -no-xattrs -no-fragments

.PHONY: cache
cache: dnf_opts += --downloadonly
cache: dnf_opts += --installroot=$(CURDIR)/cache
cache:
	install -d -m 755 $(CURDIR)/cache
	dnf $(dnf_opts) makecache
	# I'd use pseudo/fakeroot but they both seem broken
	sudo dnf $(dnf_opts) install $(seed_packages)

.PHONY: clean
clean:
	sudo rm -rf prime
	sudo rm -f fedora29.snap

.PHONY: distclean
distclean:
	sudo rm -rf cache
