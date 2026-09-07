self:
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.mcgalaxy;

  valueType =
    with lib.types;
    oneOf [
      bool
      int
      float
      str
      (listOf str)
      (listOf int)
      (listOf bool)
      path
    ];

  boolString = value: if value then "true" else "false";

  renderValue =
    value:
    if lib.isBool value then
      boolString value
    else if lib.isList value then
      lib.concatMapStringsSep "," renderValue value
    else
      toString value;

  renderProperties =
    attrs:
    lib.concatStringsSep "\n" (lib.mapAttrsToList (name: value: "${name} = ${renderValue value}") attrs)
    + "\n";

  renderItemPerm =
    name: perm:
    let
      minRank = toString (perm.minRank or 0);
      disallowed = lib.concatMapStringsSep "," toString (perm.disallowed or [ ]);
      allowed = lib.concatMapStringsSep "," toString (perm.allowed or [ ]);
    in
    "${name} : ${minRank} : ${disallowed} : ${allowed}";

  renderRank =
    name: rank:
    let
      body = removeAttrs rank [ "members" ];
    in
    lib.concatStringsSep "\n" (
      [ "RankName = ${name}" ] ++ lib.mapAttrsToList (key: value: "${key} = ${renderValue value}") body
    );

  managedFiles = {
    "properties/server.properties" = pkgs.writeText "mcgalaxy-server.properties" (
      renderProperties cfg.settings
    );
  }
  // lib.optionalAttrs (cfg.ranks != { }) {
    "properties/ranks.properties" = pkgs.writeText "mcgalaxy-ranks.properties" (
      "#Version 3\n" + lib.concatStringsSep "\n\n" (lib.mapAttrsToList renderRank cfg.ranks) + "\n"
    );
  }
  // lib.optionalAttrs (cfg.commandPermissions != { }) {
    "properties/command.properties" = pkgs.writeText "mcgalaxy-command.properties" (
      lib.concatStringsSep "\n" (lib.mapAttrsToList renderItemPerm cfg.commandPermissions) + "\n"
    );
  }
  // lib.optionalAttrs (cfg.placePermissions != { }) {
    "properties/place.properties" = pkgs.writeText "mcgalaxy-place.properties" (
      lib.concatStringsSep "\n" (lib.mapAttrsToList renderItemPerm cfg.placePermissions) + "\n"
    );
  }
  // lib.optionalAttrs (cfg.deletePermissions != { }) {
    "properties/delete.properties" = pkgs.writeText "mcgalaxy-delete.properties" (
      lib.concatStringsSep "\n" (lib.mapAttrsToList renderItemPerm cfg.deletePermissions) + "\n"
    );
  }
  // lib.mapAttrs' (
    name: value:
    lib.nameValuePair "properties/${name}.properties" (
      pkgs.writeText "mcgalaxy-${name}.properties" (renderProperties value)
    )
  ) cfg.propertyFiles
  // lib.mapAttrs' (
    name: lines:
    lib.nameValuePair "text/${name}" (
      pkgs.writeText "mcgalaxy-${baseNameOf name}" (lib.concatStringsSep "\n" lines + "\n")
    )
  ) cfg.textFiles
  // cfg.extraFiles;

  installManagedFile = target: source: ''
    install -D -m ${cfg.fileMode} -o ${cfg.user} -g ${cfg.group} ${source} ${lib.escapeShellArg cfg.dataDir}/${lib.escapeShellArg target}
  '';
in
{
  options.services.mcgalaxy = {
    enable = lib.mkEnableOption "MCGalaxy ClassiCube server";

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.mcgalaxy-cli;
      defaultText = lib.literalExpression "mcgalaxy-nix.packages.\${system}.mcgalaxy-cli";
      description = "MCGalaxy CLI package to run.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "mcgalaxy";
      description = "User account the server runs as.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "mcgalaxy";
      description = "Group account the server runs as.";
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/mcgalaxy";
      description = "Writable MCGalaxy server state directory.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open the configured TCP server port in the firewall.";
    };

    fileMode = lib.mkOption {
      type = lib.types.str;
      default = "0640";
      description = "Mode used for declaratively managed files copied into the state directory.";
    };

    settings = lib.mkOption {
      type = lib.types.attrsOf valueType;
      default = { };
      example = {
        "server-name" = "[MCGalaxy] NixOS";
        motd = "Welcome";
        port = 25565;
        public = false;
        "verify-names" = true;
        "server-owner" = "example";
      };
      description = "Direct contents of properties/server.properties.";
    };

    ranks = lib.mkOption {
      type = lib.types.attrsOf (lib.types.attrsOf valueType);
      default = { };
      description = "Rank definitions rendered to properties/ranks.properties.";
    };

    rankMembers = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf lib.types.str);
      default = { };
      description = "Managed rank member files by rank permission, for example { \"120\" = [ \"ownerName\" ]; }.";
    };

    commandPermissions = lib.mkOption {
      type = lib.types.attrsOf lib.types.attrs;
      default = { };
      description = "Command permissions rendered as Name : LowestRank : Disallowed : Allowed.";
    };

    placePermissions = lib.mkOption {
      type = lib.types.attrsOf lib.types.attrs;
      default = { };
      description = "Block placement permissions keyed by block id.";
    };

    deletePermissions = lib.mkOption {
      type = lib.types.attrsOf lib.types.attrs;
      default = { };
      description = "Block deletion permissions keyed by block id.";
    };

    propertyFiles = lib.mkOption {
      type = lib.types.attrsOf (lib.types.attrsOf valueType);
      default = { };
      example = {
        zombiesurvival = {
          "start-on-server-start" = false;
          maps = [
            "zombie1"
            "zombie2"
          ];
        };
      };
      description = "Additional properties/*.properties files, without the .properties suffix.";
    };

    textFiles = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf lib.types.str);
      default = { };
      example = {
        "rules.txt" = [
          "Be respectful."
          "No griefing."
        ];
      };
      description = "Text files rendered under the text/ directory.";
    };

    extraFiles = lib.mkOption {
      type = lib.types.attrsOf lib.types.path;
      default = { };
      description = "Additional files copied into the state directory. Keys are relative paths.";
    };

    extraServiceConfig = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Extra systemd serviceConfig attributes.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.settings ? port;
        message = "services.mcgalaxy.settings.port must be set so the service and firewall agree.";
      }
    ];

    users.users.${cfg.user} = {
      isSystemUser = true;
      inherit (cfg) group;
      home = cfg.dataDir;
      createHome = true;
    };

    users.groups.${cfg.group} = { };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 ${cfg.user} ${cfg.group} - -"
      "d ${cfg.dataDir}/properties 0750 ${cfg.user} ${cfg.group} - -"
      "d ${cfg.dataDir}/text 0750 ${cfg.user} ${cfg.group} - -"
      "d ${cfg.dataDir}/ranks 0750 ${cfg.user} ${cfg.group} - -"
    ];

    system.activationScripts.mcgalaxy-managed-files = {
      deps = [
        "users"
        "groups"
      ];
      text =
        lib.concatStringsSep "\n" (lib.mapAttrsToList installManagedFile managedFiles)
        + "\n"
        + lib.concatStringsSep "\n" (
          lib.mapAttrsToList (perm: members: ''
            install -D -m ${cfg.fileMode} -o ${cfg.user} -g ${cfg.group} ${
              pkgs.writeText "mcgalaxy-${perm}_rank.txt" (lib.concatStringsSep "\n" members + "\n")
            } ${lib.escapeShellArg cfg.dataDir}/ranks/${lib.escapeShellArg "${perm}_rank.txt"}
          '') cfg.rankMembers
        );
    };

    systemd.services.mcgalaxy = {
      description = "MCGalaxy ClassiCube server";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = cfg.dataDir;
        ExecStart = "${lib.getExe cfg.package}";
        Restart = "on-failure";
        RestartSec = 5;
      }
      // cfg.extraServiceConfig;
    };

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [
      cfg.settings.port
    ];
  };
}
