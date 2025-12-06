{ pkgs, tag, paths...}:
{
    home.username = if tag == "mac" then "darrenlu" else "dlu";
    home.homeDirectory = if tag == "mac" then "/Users/darrenlu" else "/user/dlu";
	home.stateVersion = "25.11";

	programs.home-manager.enable = true;
	programs.zsh.enable = true;
	programs.bash.enable = true;

	imports = [
		${paths.sys}/aliases.nix
		${paths.sys}/env.nix

		${paths.apps}/starship.nix
		${paths.apps}/git.nix
		${paths.apps}/tmux.nix

		(if tag == "mac" then ${paths.sys}/macos.nix else ${paths.sys}/linux-ft.nix)
	];
}
