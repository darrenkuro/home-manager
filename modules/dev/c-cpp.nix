{pkgs, ...}: {
  home.packages = with pkgs; [
    llvmPackages_20.clang-tools
  ];
}
