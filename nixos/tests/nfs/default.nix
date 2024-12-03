{
  version ? 4,
  system ? builtins.currentSystem,
  pkgs ? import ../../.. { inherit system; },
}:
{
  simple = import ./simple.nix { inherit version system pkgs; };
}
// pkgs.lib.optionalAttrs (version == 4) {
  # TODO: Test kerberos + nfsv3
  kerberos = import ./kerberos.nix { inherit version system pkgs; };
  boot-systemd-tcp = import ./boot.nix { inherit pkgs version; proto = "tcp"; };
  boot-legacy-tcp = import ./boot.nix { inherit pkgs version; systemdInit = false; proto = "tcp"; };
  # NFSv4 is much simpler to support in the initrd
  # [ 4.410850] mount[173]: /nix/store/lnsigv83sx8xbaw62vpb7zxhvs1p7a3m-nfs-utils-2.7.1/bin/start-statd: line 11: flock: command not found
  # [ 4.416152] mount[174]: Failed to start rpc-statd.service: Unit rpc-statd.service not found.
} // pkgs.lib.optionalAttrs (version == 3) {
  boot-systemd-tcp = import ./boot.nix { inherit pkgs version; proto = "tcp"; };
  boot-legacy-tcp = import ./boot.nix { inherit pkgs version; systemdInit = false; proto = "tcp"; };
  boot-systemd-udp = import ./boot.nix { inherit pkgs version; proto = "udp"; };
  boot-legacy-udp = import ./boot.nix { inherit pkgs version; systemdInit = false; proto = "udp"; };
}
