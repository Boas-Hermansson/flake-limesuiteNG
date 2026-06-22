{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = { self, nixpkgs}:
  let 
    system = "x86_64-linux"; 
    pkgs = import nixpkgs { inherit system; };

    build = kernel: 
    let
      modDirVersion = kernel.modDirVersion; 
    in

    pkgs.stdenv.mkDerivation {
      name = "limesuiteNG";

      src = pkgs.fetchFromGitHub {
        owner = "myriadrf";
        repo = "LimeSuiteNG";
        rev = "133c4d9";
        hash = "sha256-1YimUZ4k+PQTC4jJ829NNVR1eZRbb5hWldGWmXQfyTs=";
      };

      preConfigure = ''
      substituteInPlace drivers/linux/limepcie/CMakeLists.txt src/CMakeLists.txt \
      --replace-fail 'include(GetGitRevisionDescription)' ' ' \
      --replace-fail 'get_git_head_revision(GITREFSPEC GITHASH)' 'set(GITHASH "133c4d9")'
      

      export KMODROOT="$NIX_BUILD_TOP/lib/modules"

      mkdir -p "$KMODROOT"/${modDirVersion}

      export KERNEL_LOCATION="${kernel.dev}"
      export KERNEL_VERSION="${modDirVersion}"

      for dir in source build ; do 
        if [ -e "${kernel.dev}/lib/modules/${modDirVersion}/$dir" ]; then
          ln -s  "${kernel.dev}/lib/modules/${modDirVersion}/$dir" "$KMODROOT/${modDirVersion}/$dir"
        fi
      done
 
      substituteInPlace drivers/linux/limepcie/cmake/add_kernel_module.cmake \
      --replace-fail "/lib/modules" "$KMODROOT"

      
      rm cmake/GetGitRevisionDescription.cmake
      '';

      nativeBuildInputs = with pkgs; [
        cmake
        gnumake
        kernel
        python3
      ] ++ kernel.moduleBuildDependencies;

      buildInputs = with pkgs; [
        glew
        soapysdr
        libusb1
        wxwidgets_3_3
      ];
      cmakeFlags = [
        "-DUDEV_RULES_INSTALL_PATH=${placeholder "out"}/lib/udev/rules.d"
        "-DUDEV_RULES_RELOAD_ON_INSTALL=OFF"
        "-DCMAKE_INSTALL_PREFIX=$out"
      ]; 


      installPhase = ''
        runHook preInstall

        mkdir -p $out/bin
          
        for output in $(ls bin); do
          if [ -f "bin/$output" ]; then
            cp "bin/$output" "$out/bin/"
          fi 
        done 

        mkdir -p "$out/lib/modules/${modDirVersion}/extra"
        cp drivers/linux/limepcie/limepcie-0.1.10/limepcie.ko "$out/lib/modules/${modDirVersion}/extra/" 

        mkdir -p $out/lib/udev/rules.d

        make -C udev-rules install

        cp src/liblimesuiteng.so.0.3-1 $out/lib/liblimesuiteng.so.0.3-1
        runHook postInstall
      '';


      postInstall = ''
        for bin in $(ls $out/bin); do
          patchelf --add-rpath "$out/lib" "$out/bin/$bin"
          patchelf --allowed-rpath-prefixes "$NIX_STORE:$out/lib" --shrink-rpath "$out/bin/$bin"
        done
      '';
    };

  in
    {
    packages.x86_64-linux = {
    default = build pkgs.linuxPackages.kernel;
    latest  = build pkgs.linuxPackages_latest.kernel;
    };
  };
}
