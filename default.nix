let
  nativePkgs = import <nixpkgs> {};

  archs = {
    x86_64 = {
      config = "x86_64-unknown-linux-musl";
    };
    mips-sf = {
      config = "mips-unknown-linux-musl";
      gcc = {
        arch = "mips32r2";
        abi = "32";
        float = "soft";
      };
    };
    armv7l-hf = {
      config = "armv7l-unknown-linux-musleabihf";
    };
  };

  mkCrossPkgs = crossSystem: import <nixpkgs> {
    inherit crossSystem;
    overlays = [
      (self: super: {
        # libssh2's configure.ac tests for atomics without -static,
        # so the test misses that libatomic is unreachable under
        # static linking on MIPS (no hardware atomics).
        libssh2 = super.libssh2.overrideAttrs (oldAttrs:
          let
            oldFlags = oldAttrs.NIX_CFLAGS_LINK or oldAttrs.env.NIX_CFLAGS_LINK or "";
          in {
            NIX_CFLAGS_LINK = oldFlags + " -latomic";
            env = builtins.removeAttrs (oldAttrs.env or {}) ["NIX_CFLAGS_LINK"];
          }
        );
      })
    ];
  };

  mkTools = name: crossSystem:
    let pkgs = mkCrossPkgs crossSystem;
    in pkgs.pkgsStatic.buildEnv {
      name = "${name}-static-tools";
      paths = with pkgs.pkgsStatic; [
        # Disable 200+ applet symlinks (cat -> busybox, etc).  The
        # applets still work: `busybox cat`.
        (busybox.override {
          enableAppletSymlinks = false;
          extraConfig = "CONFIG_FLASHCP y\n";
        })
        curlMinimal
        dropbear
        dtach
        ethtool
        socat
        tcpdump
      ];
    };

  mkTarball = name: crossSystem:
    nativePkgs.runCommand "${name}.tar.gz" {
      nativeBuildInputs = [ nativePkgs.gnutar ];
    } ''
      tar -chzf "$out" --transform "s|^bin|${name}|" -C "${mkTools name crossSystem}" bin
    '';

  mkCheck = name: crossSystem:
    let
      qemuName = {
        "x86_64-unknown-linux-musl" = null;
        "mips-unknown-linux-musl" = "mips";
        "armv7l-unknown-linux-musleabihf" = "arm";
      }.${crossSystem.config};
      runner = if qemuName == null
        then ""
        else "${nativePkgs.qemu}/bin/qemu-${qemuName}";
    in nativePkgs.runCommand "${name}-check" {
      nativeBuildInputs = [ nativePkgs.gnutar ];
    } ''
      mkdir -p tmp
      tar -xzf ${mkTarball name crossSystem} -C tmp
      expected=e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
      hash=$(printf "" | ${runner} tmp/${name}/busybox sha256sum | awk '{print $1}')
      [ "$hash" = "$expected" ] || { echo "FAIL: $hash != $expected"; exit 1; }
      touch $out
    '';

  tools = builtins.mapAttrs mkTools archs;
  tarball = builtins.mapAttrs mkTarball archs;
  check = builtins.mapAttrs mkCheck archs;
in
  {
    inherit tools tarball check;
    tarballs = nativePkgs.linkFarm "tarballs" (
      map (name: { name = "${name}.tar.gz"; path = tarball.${name}; }) (builtins.attrNames archs));
    checks = nativePkgs.linkFarm "checks" (
      map (name: { name = "${name}"; path = check.${name}; }) (builtins.attrNames archs));
  }
