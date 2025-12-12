{ pkgs, ... }:
{
  home.packages = with pkgs; [
    nodejs_latest # provides node + npm
    # prettierd # Prettier daemon (fast formatter) => VS Code unhappy
    typescript # tsc compiler
    nodePackages.typescript-language-server # LSP for both JS + TS
  ];

  xdg.configFile.".config/prettier/config.json".text = ''
    {
      "printWidth": 100,
      "tabWidth": 4,
      "useTabs": false,
      "semi": true,
      "singleQuote": true,
      "trailingComma": "es5",
      "bracketSpacing": true,
      "arrowParens": "avoid"
    }
  '';

  home.sessionVariables = {
    PRETTIERD_DEFAULT_CONFIG = "$XDG_CONFIG_HOME/prettier/config.json";
  };

  programs.vscode.profiles.deafult.userSettings = {

    "prettier.prettierPath" = "${pkgs.nodePackages.prettier}/lib/node_modules/prettier";
    "prettier.resolveGlobalModules" = false;

    "[javascript]" = {
      "editor.defaultFormatter" = "esbenp.prettier-vscode";
    };
    "[typescript]" = {
      "editor.defaultFormatter" = "esbenp.prettier-vscode";
    };

    "[json]" = {
      "editor.defaultFormatter" = "esbenp.prettier-vscode";
    };
    # # 🧹 General Prettier behavior
    # "prettier.requireConfig" = false; # allow default Prettier rules if no config file
    # "prettier.useEditorConfig" = true;
    # "prettier.printWidth" = 100;
    # "prettier.singleQuote" = true;
    # "prettier.trailingComma" = "es5";
    # "prettier.tabWidth" = 2;

    # "eslint.enable" = true;
    # "eslint.alwaysShowStatus" = true;
    # "eslint.validate" = [
    #   "javascript"
    #   "javascriptreact"
    #   "typescript"
    #   "typescriptreact"
    # ];

  };
}
