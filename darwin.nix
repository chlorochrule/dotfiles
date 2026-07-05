{ pkgs, username, ... }: {
  system.stateVersion = 6;
  system.primaryUser = username;

  nix.settings.experimental-features = "nix-command flakes";

  environment.systemPackages = [ pkgs.vim ];
}
