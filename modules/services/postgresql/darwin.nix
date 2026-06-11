# PostgreSQL — system half: postgresql.conf, BTM wrappers, launchd agents.
# The user half (package, initdb, env vars, aliases) is ./home.nix.
# Shared facts (paths, port, package) come from ./spec.nix.
#
# Toggle: comment out this module's import in the root darwin.nix
# (and ./home.nix's import in the root home.nix), then `sure`.
{ lib, pkgs, ... }: let
    homeDir = "/Users/darrenlu";
    btm = import ../../../lib/launchd-btm.nix { inherit lib pkgs; };
    pg = import ./spec.nix { inherit pkgs; home = homeDir; };

    pgConf = pkgs.writeText "postgresql.conf" ''
    listen_addresses = 'localhost'
    port = ${pg.port}
    unix_socket_directories = '${pg.socket}'
    max_connections = 50
    shared_buffers = 256MB
    work_mem = 16MB
    effective_cache_size = 1GB
    logging_collector = on
    log_directory = '${pg.logDir}'
    log_filename = 'postgresql-%a.log'
    log_rotation_age = 1d
    log_rotation_size = 0
    log_truncate_on_rotation = on
    log_min_duration_statement = 1000
    shared_preload_libraries = 'vector'
    lc_messages = 'C'
  '';

    postgresServerWrapper = btm.mkWrapper {
        name = "PostgresServer";
        runtimeInputs = [ pg.pkg ];
        text = ''
      exec postgres \
        -D "${pg.dataDir}" \
        -c "config_file=${pgConf}" \
        -c "hba_file=${./pg_hba.conf}" \
        -k "${pg.socket}"
    '';
    };

    postgresBackupWrapper = btm.mkWrapper {
        name = "PostgresBackup";
        runtimeInputs = [ pg.pkg ];
        excludeShellChecks = [ "SC2043" ];
        text = ''
      export PG_SOCKET="${pg.socket}" PG_PORT="${pg.port}"
      export PG_LOG_DIR="${pg.logDir}" PG_BACKUP_DIR="${pg.backupDir}"
      ${builtins.readFile ./backup.sh}
    '';
    };
in
{
    launchd.user.agents.postgresql-server = {
        serviceConfig = {
            Label = "org.postgresql.server";
            ProgramArguments = [ "${btm.stubDir}/Postgres.app/Contents/MacOS/PostgresServer" ];
            RunAtLoad = true;
            KeepAlive = true;
            ThrottleInterval = 10;
            StandardOutPath = "${pg.logDir}/launchd-stdout.log";
            StandardErrorPath = "${pg.logDir}/launchd-stderr.log";
            EnvironmentVariables = { HOME = homeDir; PGDATA = pg.dataDir; };
        };
    };

    launchd.user.agents.postgresql-backup = {
        serviceConfig = {
            Label = "org.postgresql.backup";
            ProgramArguments = [ "${btm.stubDir}/Postgres.app/Contents/MacOS/PostgresBackup" ];
            StartCalendarInterval = [ { Hour = 3; Minute = 0; } ];
            StandardOutPath = "${pg.logDir}/backup-stdout.log";
            StandardErrorPath = "${pg.logDir}/backup-stderr.log";
            EnvironmentVariables = { HOME = homeDir; };
        };
    };

    # BTM stub install + AssociatedBundleIdentifiers patching for this service.
    # Appends to the root postActivation (types.lines — contributions concatenate).
    system.activationScripts.postActivation.text = btm.mkStubInstall {
        name = "Postgres";
        app = ./Postgres.app;
        wrappers = [
            { drv = postgresServerWrapper; bin = "PostgresServer"; }
            { drv = postgresBackupWrapper; bin = "PostgresBackup"; }
        ];
        agents = [ "org.postgresql.server" "org.postgresql.backup" ];
    };
}
