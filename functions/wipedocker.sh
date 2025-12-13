
# Completely purge docker to produce a fresh environment

function wipedocker()
{
    # Check if docker is running
    if ! docker info >/dev/null 2>&1; then
        printf "$RED ❌ Docker daemon is not running. Aborting.\n$RESET"
        return 1
    fi

    printf "$CYAN 🛑 Stopping all running containers...\n$RESET"
    docker stop $(docker ps -aq) 2>/dev/null

    printf "$YELLOW 🗑️ Removing all containers...\n$RESET"
    docker rm $(docker ps -aq) 2>/dev/null

    printf "$YELLOW 🧼 Removing all images...\n$RESET"
    docker rmi -f $(docker images -q) 2>/dev/null

    printf "$YELLOW 📦 Removing all volumes...\n$RESET"
    docker volume rm $(docker volume ls -q) 2>/dev/null

    printf "$YELLOW 🌐 Removing all networks...\n$RESET"
    docker network rm $(docker network ls -q | grep -v "bridge\|host\|none") 2>/dev/null

    printf "$RED 🔥 Pruning the system...\n$RESET"
    docker system prune -a --volumes -f

    printf "$GREEN ✅ Docker has been completely wiped!\n$RESET"
}
