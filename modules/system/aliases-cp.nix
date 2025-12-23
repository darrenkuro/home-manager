{ tag, ... }:
let
  copyCmd =
    if tag == "mac" then
      "pbcopy"
    else
      "xclip -selection clipboard";
  badge = s: "printf '%s' '${s}' | ${copyCmd}";
in
{
  programs.zsh.shellAliases = {
    readme = "cat $HM/templates/README.md | ${copyCmd}";
    gig = "cat $HM/templates/.gitignore | ${copyCmd}";

    ijs = badge "![JavaScript](https://img.shields.io/badge/-JavaScript-f7df1e?style=flat-square&logo=JavaScript&logoColor=black)";
    its = badge "![TypeScript](https://img.shields.io/badge/-TypeScript-3178c6?style=flat-square&logo=TypeScript&logoColor=white)";
    ic  = badge "![C](https://img.shields.io/badge/-C-A8B9CC?style=flat-square&logo=C&logoColor=black)";
    icpp = badge "![C++](https://img.shields.io/badge/-C++-00599C?style=flat-square&logo=C%2B%2B&logoColor=white)";
    irust = badge "![Rust](https://img.shields.io/badge/-Rust-000000?style=flat-square&logo=rust&logoColor=white)";
    ipy = badge "![Python](https://img.shields.io/badge/-Python-3776AB?style=flat-square&logo=Python&logoColor=white)";
    inix = badge "![Nix](https://img.shields.io/badge/-Nix-3f3f3f?style=flat-square&logo=nixos&logoColor=white)";
    itw = badge "![TailwindCSS](https://img.shields.io/badge/-TailwindCSS-06B6D4?style=flat-square&logo=tailwindcss&logoColor=white)";
    idocker = badge "![Docker](https://img.shields.io/badge/-Docker-2496ED?style=flat-square&logo=Docker&logoColor=white)";
    iesbuild = badge "![esbuild](https://img.shields.io/badge/-esbuild-FFCF00?style=flat-square&logo=esbuild&logoColor=black)";
    izod = badge "![Zod](https://img.shields.io/badge/-Zod-3C2A4D?style=flat-square&logo=zod&logoColor=white)";
    imake = badge "![Make](https://img.shields.io/badge/-Make-000000?style=flat-square&logo=gnu&logoColor=white)";

  };
}
