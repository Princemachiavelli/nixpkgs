import ../make-test-python.nix (
  {
    pkgs,
    lib,
    version ? 4,
    proto ? "tcp",
    systemdInit ? true,
    ...
  }:

  # TCP only supported for NSFv4
  assert (version == 4) -> proto == "tcp";

  let

    client =
      { config, lib, ... }:
      {
        virtualisation.fileSystems = {
          "/" = lib.mkForce {
            fsType = "tmpfs";
            options = [ "mode=0755" ];
          };
          "/nix/.ro-store" = {
            device = "server:/nix/store";
            fsType = "nfs";
            # NFS mount options optimized for Nix store.
            options = [
              "ro"
              "vers=${toString version}"
              "actimeo=3600"
              "noacl"
              "nocto"
              "nolock"
              "nosuid"
              "port=2049"
              "proto=${proto}" # mount.nfs: Failed to find 'tcp' protocol
              #"_netdev"
            ];
            neededForBoot = true;
          };
          "/nix/.rw-store" = {
            fsType = "tmpfs";
            options = [ "mode=0755" ];
            neededForBoot = true;
          };
          "/nix/store" = {
            overlay = {
              lowerdir = [ "/nix/.ro-store" ];
              upperdir = "/nix/.rw-store/store";
              workdir = "/nix/.rw-store/work";
            };
          };
        };
        boot.initrd.systemd.enable = systemdInit;
        boot.initrd.systemd.network.enable = systemdInit;
        boot.initrd.systemd.network.networks = config.systemd.network.networks;
        boot.initrd.kernelModules = [
          "nfs"
          "nfsv4"
        ];

        boot.initrd.network.enable = !systemdInit;
        systemd.network.networks."10-eth" = lib.mkIf systemdInit {
          matchConfig = {
            Name = "eth1";
          };
          networkConfig = {
            Address = "${(lib.head config.networking.interfaces.eth1.ipv4.addresses).address}/24";
          };
        };

        networking.firewall.enable = false;
        virtualisation.mountHostNixStore = false;
        boot.kernelParams = lib.mkForce [
          "console=ttyS0"
          "console=tty0"
          #"panic=1"
          #"boot.panic_on_fail"
          "clocksource=acpi_pm"
          "root=fstab"
          "loglevel=7"
          "net.ifnames=0"
          "boot.trace"
          #"boot.shell_on_fail"
          #"boot.debug1devices"
          "ip=${(lib.head config.networking.interfaces.eth1.ipv4.addresses).address}:::255.255.255.0::eth1:none"
        ];
        boot.initrd.systemd.emergencyAccess = true;
        boot.initrd.network.udhcpc.enable = false;
        boot.initrd.network.flushBeforeStage2 = false;
      };
  in
  {
    name = "nfs-nix-store";
    meta = with pkgs.lib.maintainers; {
      maintainers = [ ];
    };

    nodes = {
      client1 = client;

      server =
        { nodes, ... }:
        {
          services.nfs.server.enable = true;
          services.nfs.server.exports = ''
            /nix/store 192.168.1.0/255.255.255.0(ro,insecure,no_subtree_check,fsid=1)
          '';
          services.nfs.server.createMountPoints = true;
          services.nfs.settings.nfsd = {
            vers3 = true;
            vers4 = true;
            "vers4.2" = true;
            udp = "y";
            tcp = "y";
          };
          networking.firewall.enable = false; # FIXME: figure out what ports need to be allowed
          virtualisation.useNixStoreImage = true;
          virtualisation.additionalPaths = [ nodes.client1.system.build.toplevel ];

          users.users.root = {
            initialPassword = "anduril1";
            hashedPasswordFile = lib.mkForce null;
          };
        };
    };

    testScript = ''
      server.wait_for_unit("nfs-server")
      server.succeed("systemctl start network-online.target")
      server.wait_for_unit("network-online.target")

      server.succeed("rpcinfo  | egrep -q '${proto}.*nfs'")
      ${lib.optionalString (version == 4) ''
      server.succeed("netstat -tulnp | egrep -q 'tcp.*2049'")
      ''}
      ${lib.optionalString (version == 3) ''
      server.succeed("netstat -tulnp | egrep -q 'udp.*2049'")
      ''}

      start_all()

      client1.succeed("mount | grep -q 'vers=${toString version}'")
    '';
  }
)
