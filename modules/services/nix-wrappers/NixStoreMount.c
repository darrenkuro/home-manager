/* NixStoreMount — Mach-O replacement for the shell script at /usr/local/bin/.
 * Unlocks and mounts the encrypted APFS Nix store volume.
 * UUID is baked in at build time via -DNIX_VOLUME_UUID="...".
 * Must be codesigned (Apple Development) so BTM can resolve Team Identifier
 * and honor AssociatedBundleIdentifiers in the LaunchDaemon plist.
 */
#include <unistd.h>
#include <sys/wait.h>

#ifndef NIX_VOLUME_UUID
#error "NIX_VOLUME_UUID must be defined at compile time"
#endif

int main(void) {
    int pipefd[2];
    if (pipe(pipefd) == -1) return 1;

    pid_t pid = fork();
    if (pid == 0) {
        /* Child: get passphrase from keychain, write to pipe */
        close(pipefd[0]);
        dup2(pipefd[1], STDOUT_FILENO);
        close(pipefd[1]);
        char *args[] = {"/usr/bin/security", "find-generic-password",
            "-s", NIX_VOLUME_UUID, "-w", NULL};
        execv(args[0], args);
        _exit(1);
    }

    /* Parent: pipe passphrase to diskutil */
    close(pipefd[1]);
    dup2(pipefd[0], STDIN_FILENO);
    close(pipefd[0]);
    waitpid(pid, NULL, 0);

    char *args[] = {"/usr/sbin/diskutil", "apfs", "unlockVolume",
        NIX_VOLUME_UUID, "-mountpoint", "/nix", "-stdinpassphrase", NULL};
    execv(args[0], args);
    return 1;
}
