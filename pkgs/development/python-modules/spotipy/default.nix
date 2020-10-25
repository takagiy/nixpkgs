{ stdenv, buildPythonPackage, fetchPypi, requests, six, mock }:

buildPythonPackage rec {
  pname = "spotipy";
  version = "2.16.1";

  src = fetchPypi {
    inherit pname version;
    sha256 = "4564a6b05959deb82acc96a3fe6883db1ad9f8c73b7ff3b9f1f44db43feba0b8";
  };

  propagatedBuildInputs = [ requests six ];
  checkInputs = [ mock ];

  preConfigure = ''
    substituteInPlace setup.py \
      --replace "mock==2.0.0" "mock"
  '';

  pythonImportsCheck = [ "spotipy" ];

  meta = with stdenv.lib; {
    homepage = "https://spotipy.readthedocs.org/";
    description = "A light weight Python library for the Spotify Web API";
    license = licenses.mit;
    maintainers = [ maintainers.rvolosatovs ];
  };
}
