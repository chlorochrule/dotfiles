{ config, lib, ... }:
let
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
  linkDotfile = path: config.lib.file.mkOutOfStoreSymlink "${dotfiles}/${path}";

  # ~/.claude/<name>/ を「共通(home/claude/<name>) + このホスト固有
  # (./claude/<name>、存在すれば)」をファイル単位でマージして構成する。
  # 同名ファイルがあればホスト固有側を優先する。
  # 新規ファイル追加時は(ディレクトリ全体シンボリックリンクと違い)rebuildが必要。
  claudeDirNames = [ "commands" "skills" "agents" "hooks" ];

  readDirIfExists = path: if builtins.pathExists path then builtins.readDir path else { };

  entriesFor = name:
    let
      commonPath = ../../home/claude + "/${name}";
      hostPath = ./claude + "/${name}";
      commonRel = "home/claude/${name}";
      hostRel = "hosts/MacBookPro-minami/claude/${name}";
      toEntries = relDir: files:
        lib.mapAttrs' (fname: _:
          lib.nameValuePair ".claude/${name}/${fname}" { source = linkDotfile "${relDir}/${fname}"; }
        ) files;
    in
    (toEntries commonRel (readDirIfExists commonPath))
    // (toEntries hostRel (readDirIfExists hostPath));
in
{
  programs.git.settings.user = {
    name = "Naoto Minami";
    email = "minami.polly@gmail.com";
  };

  home.file = lib.foldl' (acc: name: acc // (entriesFor name)) { } claudeDirNames // {
    ".claude/settings.json".source =
      linkDotfile "hosts/MacBookPro-minami/claude-settings.json";
  };
}
