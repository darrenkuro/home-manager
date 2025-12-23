<h1 align="center">Home manager</h1>

<p align="center">
    <img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License"/>
    <img src="https://img.shields.io/badge/status-maintained-brightgreen" alt="Status">
    <img src="https://img.shields.io/badge/date-Dec%208%2C%202025-ff6984?style=flat-square&logo=Cachet&logoColor=white" alt="Date"/>
</p>

> My personal flake.nix for home manager.

./modules/apps/vscode.nix

```
. ~/.nix-profile/etc/profile.d/nix.sh
```

---

## Notes

- You cannot define the same attribute twice in a single Nix file, that is a Nix language thing. But same attribute in different files tend to merge (barring some exceptions?) and that is a home-manager thing.
- On MacOS: /etc/zshenv -> user zshenv -> /etc/zprofile (This is where Apple handle PATH) -> user zprofile -> (/etc/zshrc_Apple_Terminal) -> /etc/zshrc -> user zshrc -> /etc/zlogin -> user zlogin.
- GUI apps highly dependent on the env and the kind of rendering it uses; on 42 machines, GLX lib is dead on rootless it seems, only X11 and GTK4 working; DO NOT TRY OPENGL! Too much work.

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
