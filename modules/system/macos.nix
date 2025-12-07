{ pkgs, ... }: {
	imports = [ ../dev/c.nix ../dev/rust.nix ../dev/ts.nix ];

	home.packages = with pkgs; [
		pnpm
    	docker

		tokei
    	eza
  		fd
		jq
		fzf

		ffmpeg
		imagemagick
		rename
		ripgrep

		darwin.trash

		anki
		brave
		the-unarchiver
		#avidemux
		google-chrome
		obsidian
		#ghostty-bin
	];

	programs.zsh.shellAliases = {
		dbox = "cd $DBOX";

		re = "home-manager switch --flake ~/.config/home-manager#mac";

		hide = "chflags hidden";
    	unhide = "chflags nohidden";
    	rm = "echo \"☠️ $YELLOW DANGEROUS CMD: using trash instread!$RESET\" && trash";
	};
}
