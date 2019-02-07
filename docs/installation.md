# Installing CoreOS

This short guide will help you configure and install CoreOS on your machine. Installing is a quick process -- CoreOS is a very minimal distro -- but configuring the perfect machine will take a series of blog posts!

These steps have been adapted from the [official documentation][coreos-install-docs].

## Prerequisites

- ensure your target machine has a way of booting from a device you're not installing to (an extra disk; a live USB; or, my favorite, a DVD)
- ensure your target machine has internet access, most easily accomplished with a wired connection
- ensure your target disk has at least 8GB of space available for the operating system
- ensure you have a keyboard to attach to your target machine (only for a single short command, I promise)

## Steps

- create and boot a [live image of CoreOS][coreos-iso] (any Linux distro works if you download the standalone [coreos-install script][coreos-install-script])

We can use `dd` to copy, bit for bit, a CoreOS image to disk (replace `of=...` with your target disk). **note**: `dd` is a destructive operation, always double-check the target device with `lsblk` before running this command.

```shell
$ sudo dd if=/path/to/coreos.iso of=/dev/disk/by-label/MYUSBSTICK oflags=sync status=progress
355958784 bytes (356 MB, 339 MiB) copied, 2 s, 178 MB/s
915401+0 records in
915400+0 records out
468684800 bytes (469 MB, 447 MiB) copied, 2.63301 s, 178 MB/s
```

Insert and boot your installation media. If all is well you should be met with a prompt (and a lot of systemd-boot messages).

- set up your ssh key to simplify command entry (keyboard required)

A CoreOS live image runs a copy of sshd; ssh-ing into it is simply a matter of configuring your authorized keys. The easiest way to do that is to pull your keys from Github or Gitlab, assuming they're configured.

Run on the target machine:

```shell
# using github
$ wget -O ~/.ssh/authorized_keys github.com/wmedlar.keys
# using gitlab
$ wget -O ~/.ssh/authorized_keys gitlab.com/wmedlar.keys
```

You should now be able to ssh into your live image. **note**: we pass in the extra options `StrictHostKeyChecking=no` and `UserKnownHostsFile=/dev/null` to avoid persisting the host's public key, it will change after installation and we don't want to have to muck around in the known hosts file to get ssh to work without issue.

Run on the host machine:

```shell
$ ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null core@$MACHINE_IP 'echo hello core'
Warning: Permanently added '$MACHINE_IP' (ECDSA) to the list of known hosts.
hello core
```

- install the config transpiler on the host machine

[`ct`] is CoreOS' "Config Transpiler", used to convert a human-readable config into one readable by CoreOS' low-level, first-boot configuration tool [ignition]. Follow [CoreOS' steps for installing a `ct` binary][ct-installation-binary], or just install from brew (`brew install coreos-ct`).

- configure a config (for transpiling with `ct`)

I've included a copy of my own [containerlinux.yaml][/containerlinux.yaml], although this will probably take quite a bit of tweaking to work with your system. Alternatively you can use the bare-minimum config below that simply sets up a user `core` that you can log in as with your default ssh key.

Run on the host machine:

```shell
$ cat <<EOF > containerlinux.yaml
passwd:
  users:
  - name: core
    ssh_authorized_keys:
    - "$(cat ~/.ssh/id_rsa.pub)"
EOF
```

Check out the [specification][ct-specs] for a full list of available settings, and some [examples][ct-examples] to see them in action.

- render an ignition config

Our file has to be converted to the ignition-readable format before we can actually use it. We can render an ignition.json and copy it to our target device in a single step.

Run on the host machine:

```shell
$ ct < containerlinux.yaml | ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null core@$MACHINE_IP 'cat > ignition.json'
```

`ct` is a fairly smart tool and will catch some errors during conversion, but it's always good to give your config a quick review before continuing.

- install CoreOS

With an ignition config in hand we can finally install CoreOS to disk, using the handy `coreos-install` utility. **note**: `coreos-install`, like `dd`, is a potentially destructive operation, be sure to double-check your target device with `lsblk` before running this command.

A breakdown of important options:
- `-d /dev/sdX` disk (not partition) to install CoreOS to, confirm this with `lsblk`
- `-i ignition.json` path to the ignition config we rendered in the last step
- `-C beta` (optional) specify a [release channel][coreos-releases], one of [stable, beta, alpha], can be changed post-install

Run on the target machine:

```shell
$ sudo coreos-install -d /dev/sdX -i ignition.json # -C beta (optional)
Current version of CoreOS Container Linux beta is 2023.1.0
Downloading the signature for https://beta.release.core-os.net/amd64-usr/2023.1.0/coreos_production_image.bin.bz2...
2019-02-07 06:04:21 URL:https://beta.release.core-os.net/amd64-usr/2023.1.0/coreos_production_image.bin.bz2.sig [566/566] -> "/tmp/coreos-install.3Rhayhn25Y/coreos_production_image.bin.bz2.sig" [1]
Downloading, writing and verifying coreos_production_image.bin.bz2...
2019-02-07 06:05:20 URL:https://beta.release.core-os.net/amd64-usr/2023.1.0/coreos_production_image.bin.bz2 [403038329/403038329] -> "-" [1]
gpg: Signature made Mon Jan 28 06:31:02 2019 UTC
gpg:                using RSA key 4D7241B14AA47290515D6A8D7FB32ABC0638EB2F
gpg: key 50E0885593D2DCB4 marked as ultimately trusted
gpg: checking the trustdb
gpg: marginals needed: 3  completes needed: 1  trust model: pgp
gpg: depth: 0  valid:   1  signed:   0  trust: 0-, 0q, 0n, 0m, 0f, 1u
gpg: Good signature from "CoreOS Buildbot (Offical Builds) <buildbot@coreos.com>" [ultimate]
blockdev: ioctl error on BLKRRPART: Device or resource busy
Failed to reread partitions on /dev/sdX
Installing Ignition config ignition.json...
Success! CoreOS Container Linux beta 2023.1.0 is installed on /dev/sdX
```

- reboot to CoreOS

The hart parts are over and the end is in sight! Reboot your target machine, remove any installation media, and cross your fingers that all goes well.

```shell
$ sudo reboot
Connection to $MACHINE_IP closed by remote host.
Connection to $MACHINE_IP closed.
```

Give ignition a couple moments to run (longer if you're formatting a few large disks), then try to ssh in again. If the installation was successful you should be met with, well, pretty much the same prompt as the live image.

Run on the host machine:

```shell
$ ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null core@$MACHINE_IP
Warning: Permanently added '$MACHINE_IP' (ECDSA) to the list of known hosts.
Container Linux by CoreOS beta (2023.1.0)
core@localhost ~ $
```

If you're happy with your setup you can drop the `StrictHostKeyChecking=no` and `UserKnownHostsFile=/dev/null` options. But if, like me, you've got several dozens more installs until then, you can save yourself much future frustration by setting them in your ssh config.

Run on the host machine:

```shell
$ cat <<EOF >> ~/.ssh/config
Host $MACHINE_IP
    StrictHostKeyChecking   no
    UserKnownHostsFile      /dev/null
EOF
```

That's all! If you ran into any trouble along the way let me know in [an issue], but otherwise I hope you enjoy your new CoreOS box.

Check back in a few weeks to see how far I've come getting a Kubernetes cluster running!

[coreos-install-docs]: https://coreos.com/os/docs/latest/installing-to-disk.html
[coreos-install-script]: https://raw.githubusercontent.com/coreos/init/master/bin/coreos-install
[coreos-iso]: https://coreos.com/os/docs/latest/booting-with-iso.html
[coreos-releases]: https://coreos.com/releases/
[ct]: https://coreos.com/os/docs/latest/overview-of-ct.html
[ct-examples]: https://coreos.com/os/docs/latest/clc-examples.html
[ct-installation-binary]: https://github.com/coreos/container-linux-config-transpiler#prebuilt-binaries
[ct-specs]: https://coreos.com/os/docs/latest/configuration.html
[github-issue]: https://github.com/wmedlar/corebernetes/issues/new
[ignition]: https://coreos.com/ignition/docs/latest/what-is-ignition.html
