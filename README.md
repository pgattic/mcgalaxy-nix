# mcgalaxy-nix

Source-built Nix packages and a NixOS module for
[MCGalaxy](https://github.com/ClassiCube/MCGalaxy), the ClassiCube server.

## Packages

This flake exposes:

- `packages.${system}.mcgalaxy-cli`
- `packages.${system}.mcgalaxy-gui`
- `apps.${system}.cli`
- `apps.${system}.gui`

The CLI package builds upstream's standalone CLI project from source and patches
it to target .NET 8. The GUI package builds upstream's WinForms project from
source with Mono/MSBuild and wraps it with Mono.

## NixOS Module

```nix
{
  imports = [ inputs.mcgalaxy-nix.nixosModules.default ];

  services.mcgalaxy = {
    enable = true;
    openFirewall = true;

    settings = {
      "server-name" = "[MCGalaxy] NixOS";
      motd = "Welcome";
      port = 25565;
      public = false;
      "verify-names" = true;
      "server-owner" = "your-classicube-name";
    };

    textFiles."rules.txt" = [
      "Be respectful."
      "No griefing."
    ];
  };
}
```

MCGalaxy expects mutable state beside its config files. The module therefore
copies declaratively generated files into `/var/lib/mcgalaxy` during activation
instead of pointing the server at immutable store paths.

This module can directly render MCGalaxy's file-backed configuration formats:

- `properties/server.properties`
- `properties/ranks.properties`
- `properties/command.properties`
- `properties/place.properties`
- `properties/delete.properties`
- additional `properties/*.properties` files via `propertyFiles`
- `text/*` files via `textFiles`
- arbitrary managed files via `extraFiles`

Runtime state such as maps, logs, player databases, block databases, backups,
and generated plugin DLLs remains mutable in the service state directory.
