{
	theme = "onedark";
	editor = {
		soft-wrap = {
			enable = true;
		};
		true-color = true;
		color-modes = true;
		whitespace = {
			render = {
				tab = "all";
			};
			characters = {
				tab = "→";
			};
		};
	};
}{
	language = [ {
		name = "typescript";
		language-servers = [ "typescript-language-server" ];
	} {
		name = "rust";
		language-servers = [ "rust-analyzer" ];
	} {
		name = "c";
		language-servers = [ "clangd" ];
	} {
		name = "cpp";
		language-servers = [ "clangd" ];
	} ];
}