# Fedora Base Snap

This repository contains tools for building a Fedora (currently F29) Base Snap

# FAQ

Q: What is a base snap?
A: A base snap is a compressed, read-only file system image used by snapd to
   provide a root file system for applications packaged in the snap format.

Q: Who is doing this work?
A: The work on the Fedora base snap is done by _Neal Gompa_ and _Zygmunt
   Krynicki_ with the official blessing of the Fedora Server SIG.

Q: Is it official?
A: It is meant to be but won't be really official until the hand-off process
   and until it is built from the Fedora project infrastructure compose process.

Q: How to use this snap?
A: The snap is meant for early adopters who wish to experiment with making
   application snaps based on Fedora technologies. As with any other base snap
   all it takes is a `base: fedora29` declaration in a `meta/snap.yaml` file.
   Currently snapcraft doesn't yet support building snaps in the RPM world
   so all application snaps need to be built manually, with other tools.
   The presence of this snap simply allows us to work on the remaining part
   of the tooling stack to eventually make this fully automatic.

   For some inspiration you can look at the `hello-fedora` snap, available in a
   sibling git repository as well as in the snap store.

Q: Is the `fedora29` snap supported?
A: Not at this time, it will only become supported once the hand-off to the
   Fedora infrastructure team is complete. Then it will simply be produced out of
   updated RPMs as they arrive into the archive.

Q: Which architectures are available?
A: Currently only `x86_64` and `i686`, once the hand-off is complete all 
   architectures supported by snapd itself should be supported.

Q: Which packages are included in the `fedora29` snap?
A: Currently those are `filesystem`, `coreutils`, `bash` `glibc-minimal-langpack`
   along with their non-weak dependencies.

Q: How big is this snap?
A: It is about 18MB

Q: Is it stable?
A: No, we still haven't decided on the final set of files we want to ship. As
   the snap matures it will move from `edge` towards `candidate`. It will
   become stable only after Fedora 29 itself is released.

Q: Is the ABI stable?
A: Perhaps, but this is not validated automatically yet. In the future the snap
   store will be able to check that subsequent revisions of a snap are ABI
   compatible but this is not the case yet.

Q: How do I build this locally?
A: Just `sudo make`, you can also `sudo make cache`, go offline and then `sudo make`
   as many times as you like (for those long flights while you are offline).

Q: How do I make new releases into the snap store?
A: Currently only _Zygmunt Kryncki_ can do it. Once the hand-off process is
   complete it will be in the hands of the Fedora infrastructure team and it
   will be built automatically.

Q: Why is the license MIT?
A: The aggregate license is MIT, individual constituent packages have their own license.

Q: How is this snap built?
A: The snap is built out of vanilla binary RPMs downloaded with `dnf` from the
   Fedora mirror network. There is some minimal post-processing (removal of log
   files, removal of RPM and DNF cache, removal of .build-id files, removal of
   everything in /etc, addition of snapd integration mount points, etc. For
   details please look at the makefile, we tried to document the action and
   intent of all the operations.

Q: Why is the snap built manually and not with a `snapcraft.yaml` files?
A: Because snapcraft cannot yet build anything out of RPM components. This work
   is meant to break the catch-22 dependency cycle so that snapcraft itself can
   be improved to support RPM-based distributions.

Q: Can I use this snap on Debian, OpenSUSE, Arch or Ubuntu?
A: *Yes*, although we found a bug while doing this work so you may need to wait
   for snapd 2.35 to ship before it is working everywhere.
   Specifically we need this pull request to be merged into snapd
   https://github.com/snapcore/snapd/pull/5620

Q: Why is it called `fedora29` and not just `fedora`
A: This mimics the `core16` and `core18` names for the existing Ubuntu Core
   snaps. In addition this means that you can trivially install both fedora29 and
   fedora30 and run applications that require either of the bases at the same
   time.
