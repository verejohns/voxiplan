let
  pkgs = import <nixpkgs> {};
  stdenv = pkgs.stdenv;

  ruby = pkgs.ruby_2_4;
  rubygems = (pkgs.rubygems.override { ruby = ruby; });

in stdenv.mkDerivation rec {
  name = "mortgages";
  buildInputs = [
    ruby
    pkgs.libxml2
    pkgs.libxslt
    pkgs.zlib
    pkgs.bzip2
    pkgs.openssl
    pkgs.mysql
    pkgs.postgresql
    pkgs.pkgconfig
    pkgs.nodejs-9_x
    pkgs.docker
  ];

  shellHook = ''
    export PKG_CONFIG_PATH=${pkgs.libxml2}/lib/pkgconfig:${pkgs.libxslt}/lib/pkgconfig:${pkgs.zlib}/lib/pkgconfig:${pkgs.mysql}/lib/pkgconfig:${pkgs.imagemagickBig}/lib/pkgconfig
    export C_INCLUDE_PATH=${pkgs.libmysql}/include/mysql

    mkdir -p tmp/nix-gems
    export GEM_HOME=$PWD/tmp/nix-gems
    export GEM_PATH=$GEM_HOME
    export PATH=$GEM_HOME/bin:$PATH
  '';

}
