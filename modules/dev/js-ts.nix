{ pkgs, ... }:
{
  home.packages = with pkgs; [
    nodejs_latest # provides node + npm
    prettierd # Prettier daemon (fast formatter)
    typescript # tsc compiler
    nodePackages.typescript-language-server # LSP for both JS + TS
  ];

  programs.helix.languages = {
    language = [
      {
        name = "javascript";
        language-server = {
          command = "typescript-language-server";
          args = [ "--stdio" ];
        };
        auto-format = true;
        formatter = {
          command = "prettierd";
          args = [ "--stdin-filepath" ];
        };
      }
      {
        name = "typescript";
        language-server = {
          command = "typescript-language-server";
          args = [ "--stdio" ];
        };
        auto-format = true;
        formatter = {
          command = "prettierd";
          args = [ "--stdin-filepath" ];
        };
      }
    ];
  };

  programs.vscode = {
    profiles.default = {
      extensions = with pkgs.vscode-extensions; [
        esbenp.prettier-vscode # Prettier formatter
        dbaeumer.vscode-eslint # ESLint
      ];

      userSettings = {
        # 🧠 Enable format-on-save for JS + TS
        "[javascript]" = {
          "editor.defaultFormatter" = "esbenp.prettier-vscode";
          "editor.formatOnSave" = true;
        };
        "[typescript]" = {
          "editor.defaultFormatter" = "esbenp.prettier-vscode";
          "editor.formatOnSave" = true;
        };

        # 🧹 General Prettier behavior
        "prettier.requireConfig" = false; # allow default Prettier rules if no config file
        "prettier.useEditorConfig" = true;
        "prettier.printWidth" = 100;
        "prettier.singleQuote" = true;
        "prettier.trailingComma" = "es5";
        "prettier.tabWidth" = 2;

        # 🚨 ESLint integration (optional)
        "eslint.enable" = true;
        "eslint.alwaysShowStatus" = true;
        "eslint.validate" = [
          "javascript"
          "javascriptreact"
          "typescript"
          "typescriptreact"
        ];

        "typescript.updateImportsOnFileMove.enabled" = "always";
        "javascript.updateImportsOnFileMove.enabled" = "always";
      };
    };
  };
}
