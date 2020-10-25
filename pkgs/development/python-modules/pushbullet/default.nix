{ lib, buildPythonPackage, fetchPypi
, requests, websocket_client, python_magic
, pytest, mock }:

buildPythonPackage rec {
  pname = "pushbullet.py";
  version = "0.11.2";

  src = fetchPypi {
    inherit pname version;
    sha256 = "caeed2788141695aaf6e443131f97fc855f56cebfd7fb9eb1c53498bf00c76cc";
  };

  propagatedBuildInputs = [ requests websocket_client python_magic ];

  checkInputs = [ pytest mock ];

  checkPhase = ''
    PUSHBULLET_API_KEY="" py.test -k "not test_e2e and not test_auth"
  '';

  meta = with lib; {
    description = "A simple python client for pushbullet.com";
    homepage = "https://github.com/randomchars/pushbullet.py";
    license = licenses.mit;
  };
}
