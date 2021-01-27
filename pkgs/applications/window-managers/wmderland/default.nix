{ lib, stdenv, fetchFromGitHub, cmake, libX11, xorgproto }:

stdenv.mkDerivation {
  pname = "wmderland";
  version = "unstable-2020-07-17";

  src = fetchFromGitHub {
    owner = "aesophor";
    repo = "wmderland";
    rev = "a40a3505dd735b401d937203ab6d8d1978307d72";
    sha256 = "0npmlnybblp82mfpinjbz7dhwqgpdqc1s63wc1zs8mlcs19pdh98";
  };

  nativeBuildInputs = [
    cmake
  ];

  cmakeBuildType = "MinSizeRel";

  patches = ./0001-remove-flto.patch;

  buildInputs = [
    libX11
    xorgproto
  ];

  meta = {
    description = "Modern and minimal X11 tiling window manager";
    homepage = "https://github.com/aesophor/wmderland";
    license = lib.licenses.mit;
    platforms = libX11.meta.platforms;
    maintainers = with lib.maintainers; [ takagiy ];
  };
}
