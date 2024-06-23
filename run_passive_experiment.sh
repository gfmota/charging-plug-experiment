NUMBER_OF_ANALYZERS=${1:-1}

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
COMPOSE_FILE="$SCRIPT_DIR/charging-plug-gateway/docker-compose.yml"

echo "Running passive experiment with $NUMBER_OF_ANALYZERS analyzers at the same time"

docker-compose -f $COMPOSE_FILE up -d

cd charging-plug-gateway
git checkout passive-gateway
git pull
mkdir ../log
> ../log/passive-gateway.log
./gradlew bootRun >> ../log/passive-gateway.log &
PID1=$!
docker-compose up -d

cd ../charging-plug-data-analyzer
export NUMBER_OF_REQUESTS=$NUMBER_OF_ANALYZERS
git checkout active-analyzer
git pull
> ../log/active-data-analyzer.log
./gradlew bootRun >> ../log/active-data-analyzer.log &
PID2=$!

# Function to stop both applications on exit
function cleanup {
  echo "Stopping applications..."
  kill $PID1
  kill $PID2
  docker-compose -f $COMPOSE_FILE down
}

# Trap the EXIT signal to ensure cleanup is done
trap cleanup EXIT

# Wait for both applications to finish
wait $PID1
wait $PID2