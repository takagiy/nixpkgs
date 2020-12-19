{ config, lib, pkgs, ... }:

with lib;

let

  cfg = config.services.slurm;
  # configuration file can be generated by http://slurm.schedmd.com/configurator.html

  defaultUser = "slurm";

  configFile = pkgs.writeTextDir "slurm.conf"
    ''
      ClusterName=${cfg.clusterName}
      StateSaveLocation=${cfg.stateSaveLocation}
      SlurmUser=${cfg.user}
      ${optionalString (cfg.controlMachine != null) ''controlMachine=${cfg.controlMachine}''}
      ${optionalString (cfg.controlAddr != null) ''controlAddr=${cfg.controlAddr}''}
      ${toString (map (x: "NodeName=${x}\n") cfg.nodeName)}
      ${toString (map (x: "PartitionName=${x}\n") cfg.partitionName)}
      PlugStackConfig=${plugStackConfig}/plugstack.conf
      ProctrackType=${cfg.procTrackType}
      ${cfg.extraConfig}
    '';

  plugStackConfig = pkgs.writeTextDir "plugstack.conf"
    ''
      ${optionalString cfg.enableSrunX11 ''optional ${pkgs.slurm-spank-x11}/lib/x11.so''}
      ${cfg.extraPlugstackConfig}
    '';

  cgroupConfig = pkgs.writeTextDir "cgroup.conf"
   ''
     ${cfg.extraCgroupConfig}
   '';

  slurmdbdConf = pkgs.writeText "slurmdbd.conf"
   ''
     DbdHost=${cfg.dbdserver.dbdHost}
     SlurmUser=${cfg.user}
     StorageType=accounting_storage/mysql
     StorageUser=${cfg.dbdserver.storageUser}
     ${cfg.dbdserver.extraConfig}
   '';

  # slurm expects some additional config files to be
  # in the same directory as slurm.conf
  etcSlurm = pkgs.symlinkJoin {
    name = "etc-slurm";
    paths = [ configFile cgroupConfig plugStackConfig ] ++ cfg.extraConfigPaths;
  };
in

{

  ###### interface

  meta.maintainers = [ maintainers.markuskowa ];

  options = {

    services.slurm = {

      server = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = ''
            Whether to enable the slurm control daemon.
            Note that the standard authentication method is "munge".
            The "munge" service needs to be provided with a password file in order for
            slurm to work properly (see <literal>services.munge.password</literal>).
          '';
        };
      };

      dbdserver = {
        enable = mkEnableOption "SlurmDBD service";

        dbdHost = mkOption {
          type = types.str;
          default = config.networking.hostName;
          description = ''
            Hostname of the machine where <literal>slurmdbd</literal>
            is running (i.e. name returned by <literal>hostname -s</literal>).
          '';
        };

        storageUser = mkOption {
          type = types.str;
          default = cfg.user;
          description = ''
            Database user name.
          '';
        };

        storagePassFile = mkOption {
          type = with types; nullOr str;
          default = null;
          description = ''
            Path to file with database password. The content of this will be used to
            create the password for the <literal>StoragePass</literal> option.
          '';
        };

        extraConfig = mkOption {
          type = types.lines;
          default = "";
          description = ''
            Extra configuration for <literal>slurmdbd.conf</literal> See also:
            <citerefentry><refentrytitle>slurmdbd.conf</refentrytitle>
            <manvolnum>8</manvolnum></citerefentry>.
          '';
        };
      };

      client = {
        enable = mkEnableOption "slurm client daemon";
      };

      enableStools = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Whether to provide a slurm.conf file.
          Enable this option if you do not run a slurm daemon on this host
          (i.e. <literal>server.enable</literal> and <literal>client.enable</literal> are <literal>false</literal>)
          but you still want to run slurm commands from this host.
        '';
      };

      package = mkOption {
        type = types.package;
        default = pkgs.slurm.override { enableX11 = ! cfg.enableSrunX11; };
        defaultText = "pkgs.slurm";
        example = literalExample "pkgs.slurm-full";
        description = ''
          The package to use for slurm binaries.
        '';
      };

      controlMachine = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = null;
        description = ''
          The short hostname of the machine where SLURM control functions are
          executed (i.e. the name returned by the command "hostname -s", use "tux001"
          rather than "tux001.my.com").
        '';
      };

      controlAddr = mkOption {
        type = types.nullOr types.str;
        default = cfg.controlMachine;
        example = null;
        description = ''
          Name that ControlMachine should be referred to in establishing a
          communications path.
        '';
      };

      clusterName = mkOption {
        type = types.str;
        default = "default";
        example = "myCluster";
        description = ''
          Necessary to distinguish accounting records in a multi-cluster environment.
        '';
      };

      nodeName = mkOption {
        type = types.listOf types.str;
        default = [];
        example = literalExample ''[ "linux[1-32] CPUs=1 State=UNKNOWN" ];'';
        description = ''
          Name that SLURM uses to refer to a node (or base partition for BlueGene
          systems). Typically this would be the string that "/bin/hostname -s"
          returns. Note that now you have to write node's parameters after the name.
        '';
      };

      partitionName = mkOption {
        type = types.listOf types.str;
        default = [];
        example = literalExample ''[ "debug Nodes=linux[1-32] Default=YES MaxTime=INFINITE State=UP" ];'';
        description = ''
          Name by which the partition may be referenced. Note that now you have
          to write the partition's parameters after the name.
        '';
      };

      enableSrunX11 = mkOption {
        default = false;
        type = types.bool;
        description = ''
          If enabled srun will accept the option "--x11" to allow for X11 forwarding
          from within an interactive session or a batch job. This activates the
          slurm-spank-x11 module. Note that this option also enables
          <option>services.openssh.forwardX11</option> on the client.

          This option requires slurm to be compiled without native X11 support.
          The default behavior is to re-compile the slurm package with native X11
          support disabled if this option is set to true.

          To use the native X11 support add <literal>PrologFlags=X11</literal> in <option>extraConfig</option>.
          Note that this method will only work RSA SSH host keys.
        '';
      };

      procTrackType = mkOption {
        type = types.str;
        default = "proctrack/linuxproc";
        description = ''
          Plugin to be used for process tracking on a job step basis.
          The slurmd daemon uses this mechanism to identify all processes
          which are children of processes it spawns for a user job step.
        '';
      };

      stateSaveLocation = mkOption {
        type = types.str;
        default = "/var/spool/slurmctld";
        description = ''
          Directory into which the Slurm controller, slurmctld, saves its state.
        '';
      };

      user = mkOption {
        type = types.str;
        default = defaultUser;
        description = ''
          Set this option when you want to run the slurmctld daemon
          as something else than the default slurm user "slurm".
          Note that the UID of this user needs to be the same
          on all nodes.
        '';
      };

      extraConfig = mkOption {
        default = "";
        type = types.lines;
        description = ''
          Extra configuration options that will be added verbatim at
          the end of the slurm configuration file.
        '';
      };

      extraPlugstackConfig = mkOption {
        default = "";
        type = types.lines;
        description = ''
          Extra configuration that will be added to the end of <literal>plugstack.conf</literal>.
        '';
      };

      extraCgroupConfig = mkOption {
        default = "";
        type = types.lines;
        description = ''
          Extra configuration for <literal>cgroup.conf</literal>. This file is
          used when <literal>procTrackType=proctrack/cgroup</literal>.
        '';
      };

      extraConfigPaths = mkOption {
        type = with types; listOf path;
        default = [];
        description = ''
          Slurm expects config files for plugins in the same path
          as <literal>slurm.conf</literal>. Add extra nix store
          paths that should be merged into same directory as
          <literal>slurm.conf</literal>.
        '';
      };


    };

  };

  imports = [
    (mkRemovedOptionModule [ "services" "slurm" "dbdserver" "storagePass" ] ''
      This option has been removed so that the database password is not exposed via the nix store.
      Use services.slurm.dbdserver.storagePassFile to provide the database password.
    '')
    (mkRemovedOptionModule [ "services" "slurm" "dbdserver" "configFile" ] ''
      This option has been removed. Use services.slurm.dbdserver.storagePassFile
      and services.slurm.dbdserver.extraConfig instead.
    '')
  ];

  ###### implementation

  config =
    let
      wrappedSlurm = pkgs.stdenv.mkDerivation {
        name = "wrappedSlurm";

        builder = pkgs.writeText "builder.sh" ''
          source $stdenv/setup
          mkdir -p $out/bin
          find  ${getBin cfg.package}/bin -type f -executable | while read EXE
          do
            exename="$(basename $EXE)"
            wrappername="$out/bin/$exename"
            cat > "$wrappername" <<EOT
          #!/bin/sh
          if [ -z "$SLURM_CONF" ]
          then
            SLURM_CONF="${etcSlurm}/slurm.conf" "$EXE" "\$@"
          else
            "$EXE" "\$0"
          fi
          EOT
            chmod +x "$wrappername"
          done

          mkdir -p $out/share
          ln -s ${getBin cfg.package}/share/man $out/share/man
        '';
      };

  in mkIf ( cfg.enableStools ||
            cfg.client.enable ||
            cfg.server.enable ||
            cfg.dbdserver.enable ) {

    environment.systemPackages = [ wrappedSlurm ];

    services.munge.enable = mkDefault true;

    # use a static uid as default to ensure it is the same on all nodes
    users.users.slurm = mkIf (cfg.user == defaultUser) {
      name = defaultUser;
      group = "slurm";
      uid = config.ids.uids.slurm;
    };

    users.groups.slurm.gid = config.ids.uids.slurm;

    systemd.services.slurmd = mkIf (cfg.client.enable) {
      path = with pkgs; [ wrappedSlurm coreutils ]
        ++ lib.optional cfg.enableSrunX11 slurm-spank-x11;

      wantedBy = [ "multi-user.target" ];
      after = [ "systemd-tmpfiles-clean.service" ];

      serviceConfig = {
        Type = "forking";
        KillMode = "process";
        ExecStart = "${wrappedSlurm}/bin/slurmd";
        PIDFile = "/run/slurmd.pid";
        ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
        LimitMEMLOCK = "infinity";
      };

      preStart = ''
        mkdir -p /var/spool
      '';
    };

    services.openssh.forwardX11 = mkIf cfg.client.enable (mkDefault true);

    systemd.services.slurmctld = mkIf (cfg.server.enable) {
      path = with pkgs; [ wrappedSlurm munge coreutils ]
        ++ lib.optional cfg.enableSrunX11 slurm-spank-x11;

      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" "munged.service" ];
      requires = [ "munged.service" ];

      serviceConfig = {
        Type = "forking";
        ExecStart = "${wrappedSlurm}/bin/slurmctld";
        PIDFile = "/run/slurmctld.pid";
        ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
      };

      preStart = ''
        mkdir -p ${cfg.stateSaveLocation}
        chown -R ${cfg.user}:slurm ${cfg.stateSaveLocation}
      '';
    };

    systemd.services.slurmdbd = let
      # slurm strips the last component off the path
      configPath = "$RUNTIME_DIRECTORY/slurmdbd.conf";
    in mkIf (cfg.dbdserver.enable) {
      path = with pkgs; [ wrappedSlurm munge coreutils ];

      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" "munged.service" "mysql.service" ];
      requires = [ "munged.service" "mysql.service" ];

      preStart = ''
        cp ${slurmdbdConf} ${configPath}
        chmod 600 ${configPath}
        chown ${cfg.user} ${configPath}
        ${optionalString (cfg.dbdserver.storagePassFile != null) ''
          echo "StoragePass=$(cat ${cfg.dbdserver.storagePassFile})" \
            >> ${configPath}
        ''}
      '';

      script = ''
        export SLURM_CONF=${configPath}
        exec ${cfg.package}/bin/slurmdbd -D
      '';

      serviceConfig = {
        RuntimeDirectory = "slurmdbd";
        Type = "simple";
        PIDFile = "/run/slurmdbd.pid";
        ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
      };
    };

  };

}
