{ pkgs, ... }: {
  programs.helix = {
    enable = true;
	defaultEditor = true;

    settings = {
      theme = "onedark";

      editor = {
        soft-wrap.enable = true;
        true-color = true;
        color-modes = true;

        whitespace = {
          render.tab = "all";
          characters.tab = "→";
        };
      };
	};

    languages = {
		language = [
			{
			name = "typescript";
			language-servers = [ "typescript-language-server" ];
			}
			{
			name = "rust";
			language-servers = [ "rust-analyzer" ];
			}
			{
			name = "c";
			language-servers = [ "clangd" ];
			}
			{
			name = "cpp";
			language-servers = [ "clangd" ];
			}
			{
			name = "nix";
			auto-format = true;
			formatter = {
				command = "alejandra";
				args = [ "-q" ];  # quiet mode
			};
			}
		];
	  };
    };
}

#   # Optional: ensure LSP servers exist
# 	  home.packages = with pkgs; [
# 	    helix
# 	    nodePackages.typescript-language-server
# 	    rust-analyzer
# 	    #clang-tools
# 	  ];

