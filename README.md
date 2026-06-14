# nix-embedded-static-binaries

Statically-linked binaries for embedded devices, cross-compiled with Nix.

Usable on ~any Linux machine, with no dependencies.

## Why

I needed statically-linked MIPS binaries with soft-float for a Realtek
RTL838x switch, but couldn't find many pre-built.

This repo uses Nix to address that: reproducible builds with full
provenance, trivial static linking, and cross-compilation
reusing nixpkgs' existing build infra.

## Tools

busybox, curl, dropbear, dtach, ethtool, socat, tcpdump

I've added packages as I've needed them, but feel to add any ~small
binaries. To find package names, search
https://search.nixos.org/packages, then file a PR that modifies
`default.nix`.

## Architectures

I've added architectures as I've needed, but feel free to file a PR
to add one, by adding an arch to the `archs` attrset in `default.nix`.

| Attribute | Notes |
|-----------|-------|
| `x86_64` | For local testing and CI |
| `mips-sf` | Big-endian MIPS32r2, soft-float (Realtek RTL838x) |
| `armv7l-hf` | ARMv7 hard-float (Netgear RN102) |

## Download

Pre-built tarballs are attached to [releases](https://github.com/tomfitzhenry/nix-embedded-static-binaries/releases).

## Build

```console
$ nix-build -A tools.x86_64
$ file -L result/bin/busybox
result/bin/busybox: ELF 64-bit LSB executable, x86-64, version 1 (SYSV), statically linked, BuildID[sha1]=0d2d99e74f33e0bae58fcd2c018bb00905914aae, not stripped
```
