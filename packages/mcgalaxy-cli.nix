{
  lib,
  dotnetCorePackages,
  buildDotnetModule,
  sqlite,
  src,
}:

buildDotnetModule {
  pname = "mcgalaxy-cli";
  version = "0.0.0-${src.shortRev or "source"}";

  inherit src;

  projectFile = "CLI/MCGalaxyCLI_standalone6.csproj";
  executables = [ ];
  nugetDeps = null;

  dotnet-sdk = dotnetCorePackages.sdk_8_0;
  dotnet-runtime = dotnetCorePackages.runtime_8_0;
  runtimeDeps = [ sqlite ];

  postPatch = ''
    substituteInPlace CLI/MCGalaxyCLI_standalone6.csproj \
      --replace-fail "<TargetFramework>net6.0</TargetFramework>" "<TargetFramework>net8.0</TargetFramework>"
    substituteInPlace MCGalaxy/MCGalaxy_standalone.csproj \
      --replace-fail "<TargetFramework>net6.0</TargetFramework>" "<TargetFramework>net8.0</TargetFramework>"
  '';

  postInstall = ''
    mkdir -p "$out/bin"
    makeWrapper ${dotnetCorePackages.runtime_8_0}/bin/dotnet "$out/bin/mcgalaxy-cli" \
      --add-flags "$out/lib/mcgalaxy-cli/MCGalaxyCLI_standalone6.dll" \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ sqlite ]}
  '';

  meta = {
    description = "Command-line MCGalaxy ClassiCube server";
    homepage = "https://github.com/ClassiCube/MCGalaxy";
    license = with lib.licenses; [
      gpl3Only
      ecl20
    ];
    mainProgram = "mcgalaxy-cli";
  };
}
