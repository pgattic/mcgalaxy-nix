{
  lib,
  stdenvNoCC,
  makeWrapper,
  mono,
  msbuild,
  libgdiplus,
  src,
}:

stdenvNoCC.mkDerivation {
  pname = "mcgalaxy-gui";
  version = "0.0.0-${src.shortRev or "source"}";

  inherit src;

  nativeBuildInputs = [
    makeWrapper
    msbuild
  ];

  buildPhase = ''
    runHook preBuild
    msbuild GUI/MCGalaxyGUI.csproj /p:Configuration=Release
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/lib/mcgalaxy-gui" "$out/bin"
    cp -r bin/Release/. "$out/lib/mcgalaxy-gui/"

    makeWrapper ${lib.getExe mono} "$out/bin/mcgalaxy-gui" \
      --add-flags "$out/lib/mcgalaxy-gui/MCGalaxy.exe" \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ libgdiplus ]}

    runHook postInstall
  '';

  meta = {
    description = "Graphical MCGalaxy ClassiCube server";
    homepage = "https://github.com/ClassiCube/MCGalaxy";
    license = with lib.licenses; [
      gpl3Only
      ecl20
    ];
    mainProgram = "mcgalaxy-gui";
  };
}
