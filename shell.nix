{ pkgs ? import <nixpkgs> {} }:

let
  # Define the list of packages
  packages = with pkgs; [
    nodejs_22
    coreutils  # For `echo`
  ];
in
pkgs.mkShell {
  buildInputs = packages;

  shellHook = ''
    echo "Installed packages:"
    # Dynamically printing the list of installed packages
    ${pkgs.coreutils}/bin/echo "${builtins.concatStringsSep "\n" (map (p: "- ${p.name}") packages)}"

    echo 'Running "npm start"...'
    exec npm start
  '';
}

