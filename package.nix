{ pkgs, bash-logger }:

let
  monitor-detector-script = builtins.readFile ./monitor-detector.sh;
in
pkgs.writeShellApplication {
  name = "monitor-detector";
  text = monitor-detector-script;
  runtimeInputs = [
    bash-logger
    pkgs.jq
    pkgs.bash
  ];
}
