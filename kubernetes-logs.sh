#!/bin/bash

# Define color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

namespace=default
keyword=""

# Parse options with getopts
while getopts "n:k:" opt; do
  case $opt in
    n)
      namespace=$OPTARG
      ;;
    k)
      keyword=$OPTARG
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done

# Fetch the list of pod names, filtered by keyword if provided
if [ -z "$keyword" ]; then
    pods=($(kubectl get pods -n "$namespace" -o jsonpath='{.items[*].metadata.name}'))
else
    pods=($(kubectl get pods -n "$namespace" -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | grep "$keyword"))
fi

# Check if any pods exist
total_pods=${#pods[@]}
if [ $total_pods -eq 0 ]; then
    echo "No pods found in $namespace namespace matching '$keyword'"
    exit 0
fi

# Function to handle cleanup on exit
cleanup() {
    kill 0  # Kill all background jobs in the current shell
    exit
}

# Trap SIGINT (Ctrl+C)
trap cleanup SIGINT

# Iterate over each pod
for pod in "${pods[@]}"; do
    echo -e "${BLUE}Pod: $pod${NC}"  # Color the pod name

    # Get container names for each pod
    containers=($(kubectl get pod "$pod" -n "$namespace" -o jsonpath='{.spec.containers[*].name}'))

    # Iterate through containers in the current pod
    for container in "${containers[@]}"; do
        echo -e "  ${GREEN}Container: $container${NC}"  # Color the container name
        
        # Follow logs in the background and include pod name in the log output
        kubectl logs -f "$pod" -n "$namespace" -c "$container" | while read -r log_line; do
            printf "[%b%s%b] - %s\n" "$GREEN" "$pod" "$NC" "$log_line"
        done &
    done
done

# Wait for all background jobs to finish
wait
