
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
EXCLUDE_FILE="$SCRIPT_DIR/.exclude-list.txt"
mv wxd-dev-edition-chart watsonx.data-developer-edition-installer  || true
tar --disable-copyfile -cvf watsonx.data-developer-edition-installer.tar --exclude-vcs --exclude "$EXCLUDE_FILE" watsonx.data-developer-edition-installer
