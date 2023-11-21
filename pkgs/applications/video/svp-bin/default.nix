{ stdenv
, buildFHSEnv
, fetchurl
, ffmpeg
, glibc
, gnome
, lib
, libmediainfo
, libsForQt5
, libusb1
, lsof
, mpv-unwrapped
, ocl-icd
, p7zip
, patchelf
, vapoursynth
, wrapMpv
, writeText
, xdg-utils
, xorg
, ...
}:
let
  mpvForSVP =
    wrapMpv
      (mpv-unwrapped.override {
        vapoursynthSupport = true;
      })
      {
        extraMakeWrapperArgs = [
          "--prefix"
          "LD_LIBRARY_PATH"
          ":"
          "/run/opengl-driver/lib"
        ];
      };

  libraries = [
    ffmpeg.bin
    glibc
    gnome.zenity
    libmediainfo
    libsForQt5.qtbase
    libsForQt5.qtdeclarative
    libsForQt5.qtscript
    libsForQt5.qtsvg
    libusb1
    lsof
    mpvForSVP
    ocl-icd
    stdenv.cc.cc.lib
    vapoursynth
    xdg-utils
    xorg.libX11
  ];

  svp-dist = stdenv.mkDerivation rec {
    pname = "svp-dist";
    version = "4.5.210-2";
    src = fetchurl {
      url = "https://www.svp-team.com/files/svp4-linux.${version}.tar.bz2";
      sha256 = "sha256-dY9uQ9jzTHiN2XSnOrXtHD11IIJW6t9BUzGGQFfZ+yg=";
    };

    nativeBuildInputs = [ p7zip patchelf ];
    dontFixup = true;

    unpackPhase = ''
      tar xf ${src}
    '';

    buildPhase = ''
      mkdir installer
      LANG=C grep --only-matching --byte-offset --binary --text  $'7z\xBC\xAF\x27\x1C' "svp4-linux-64.run" |
        cut -f1 -d: |
        while read ofs; do dd if="svp4-linux-64.run" bs=1M iflag=skip_bytes status=none skip=$ofs of="installer/bin-$ofs.7z"; done
    '';

    installPhase = ''
      mkdir -p $out/opt
      for f in "installer/"*.7z; do
        7z -bd -bb0 -y x -o"$out/opt/" "$f" || true
      done

      for SIZE in 32 48 64 128; do
        mkdir -p "$out/share/icons/hicolor/''${SIZE}x''${SIZE}/apps"
        mv "$out/opt/svp-manager4-''${SIZE}.png" "$out/share/icons/hicolor/''${SIZE}x''${SIZE}/apps/svp-manager4.png"
      done
      rm -f $out/opt/{add,remove}-menuitem.sh
    '';
  };

  fhs = buildFHSEnv {
    name = "SVPManager";
    targetPkgs = pkgs: libraries;
    runScript = "${svp-dist}/opt/SVPManager";
    unshareUser = false;
    unshareIpc = false;
    unsharePid = false;
    unshareNet = false;
    unshareUts = false;
    unshareCgroup = false;
  };

  desktopFile = writeText "svp-manager4.desktop" ''
    [Desktop Entry]
    Version=1.0
    Encoding=UTF-8
    Name=SVP 4 Linux
    GenericName=Real time frame interpolation
    Type=Application
    Categories=Multimedia;AudioVideo;Player;Video;
    MimeType=video/x-msvideo;video/x-matroska;video/webm;video/mpeg;video/mp4;
    Terminal=false
    StartupNotify=true
    Exec=${fhs}/bin/SVPManager %f
    Icon=svp-manager4.png
  '';
in
stdenv.mkDerivation {
  pname = "svp-bin";
  inherit (svp-dist) version;
  phases = [ "installPhase" ];
  installPhase = ''
    mkdir -p $out/bin $out/share/applications
    ln -s ${fhs}/bin/SVPManager $out/bin/SVPManager
    ln -s ${desktopFile} $out/share/applications/svp-manager4.desktop
    ln -s ${svp-dist}/share/icons $out/share/icons
  '';

  meta = with lib; {
    description = "SmoothVideo Project 4 (SVP4)";
    homepage = "https://www.svp-team.com/wiki/SVP:Linux";
    platforms = [ "x86_64-linux" ];
    license = licenses.unfree;
    maintainers = with lib.maintainers; [ xddxdd ];
  };
}
