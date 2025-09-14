{ pkgs, bash-logger }:

let
  monitor-detector-scriptContent = builtins.readFile ./monitor-detector.sh;
  bash-logger-scriptPath = bash-logger.passthru.scriptPath;
in
pkgs.writeShellApplication {
  name = "monitor-detector";
  text = ''
    #!/usr/bin/env bash
    export BASH_LOGGER_SH=${bash-logger-scriptPath}

    ${monitor-detector-scriptContent}
  '';
  runtimeInputs = [
    pkgs.jq
    pkgs.bash
  ];
}
