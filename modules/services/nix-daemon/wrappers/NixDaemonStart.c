/* NixDaemonStart — Mach-O replacement for the shell script at /usr/local/bin/.
 * Waits for the nix-daemon binary to appear, then execs into it.
 * Must be codesigned (Apple Development) so BTM can resolve Team Identifier
 * and honor AssociatedBundleIdentifiers in the LaunchDaemon plist.
 */
#include <unistd.h>
#include <sys/wait.h>

int main(void) {
    pid_t pid = fork();
    if (pid == 0) {
        char *args[] = {"/bin/wait4path",
            "/nix/var/nix/profiles/default/bin/nix-daemon", NULL};
        execv(args[0], args);
        _exit(1);
    }
    int status;
    waitpid(pid, &status, 0);
    if (!WIFEXITED(status) || WEXITSTATUS(status) != 0) return 1;

    char *args[] = {"nix-daemon", NULL};
    execv("/nix/var/nix/profiles/default/bin/nix-daemon", args);
    return 1;
}
