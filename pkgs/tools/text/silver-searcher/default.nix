{lib, stdenv, fetchFromGitHub, autoreconfHook, pkg-config, pcre, zlib, lzma}:

stdenv.mkDerivation rec {
  pname = "silver-searcher";
  version = "2.2.0";

  src = fetchFromGitHub {
    owner = "ggreer";
    repo = "the_silver_searcher";
    rev = version;
    sha256 = "0cyazh7a66pgcabijd27xnk1alhsccywivv6yihw378dqxb22i1p";
  };

  patches = [ ./bash-completion.patch ];

  NIX_LDFLAGS = lib.optionalString stdenv.isLinux "-lgcc_s";

  nativeBuildInputs = [ autoreconfHook pkg-config ];
  buildInputs = [ pcre zlib lzma ];

  meta = with lib; {
    homepage = "https://github.com/ggreer/the_silver_searcher/";
    description = "A code-searching tool similar to ack, but faster";
    maintainers = with maintainers; [ madjar ];
    platforms = platforms.all;
    license = licenses.asl20;
  };
}
