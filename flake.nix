{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = { self, nixpkgs}:
  let 
    system = "x86_64-linux"; 
    pkgs = import nixpkgs { inherit system; };

    build = kernel: pkgs.stdenv.mkDerivation {
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
      
      substituteInPlace drivers/linux/limepcie/cmake/add_kernel_module.cmake \
      --replace-fail '/lib/modules/' '${kernel}/lib/modules/'


      rm cmake/GetGitRevisionDescription.cmake
      '';

      nativeBuildInputs = with pkgs; [
        cmake
        gnumake
        kernel
      ];

      buildInputs = with pkgs; [
        glew
        soapysdr
        libusb1
        wxwidgets_3_3
      ];
  
      installPhase = ''
        mkdir $out -p 
        make
        make install
      '';
    };


  in
    {
    packages.x86_64-linux = {
    #default = build pkgs.linuxPackages.kernel.dev;
    default = build pkgs.linuxPackages_latest.kernel.dev;
    };
  };
}
