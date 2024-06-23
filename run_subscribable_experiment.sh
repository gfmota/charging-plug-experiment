NUMBER_OF_ANALYZERS=${1:-1}

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
COMPOSE_FILE="$SCRIPT_DIR/charging-plug-gateway/docker-compose.yml"

echo "Running subscribable experiment with $NUMBER_OF_ANALYZERS analyzers at the same time"

docker-compose -f $COMPOSE_FILE up -d

cd charging-plug-gateway
git checkout subscribable-gateway
git pull
mkdir ../log
> ../log/subscribable-gateway.log
./gradlew bootRun >> ../log/subscribable-gateway.log &
PID1=$!
docker-compose up -d

cd ../charging-plug-data-analyzer
export NUMBER_OF_CLIENTS=$NUMBER_OF_ANALYZERS
git checkout subscribable-analyzer
git pull
> ../log/subscribable-data-analyzer.log
./gradlew bootRun >> ../log/subscribable-data-analyzer.log &
PID2=$!

cd ..

# Function to stop both applications on exit
function cleanup {
  echo "Stopping applications..."
  kill $PID1
  kill $PID2
  docker-compose -f $COMPOSE_FILE down
  echo "PATH,URI,EVENT_TYPE" > $SCRIPT_DIR/charging-plug-gateway/localStorage.csv
}

# Trap the EXIT signal to ensure cleanup is done
trap cleanup EXIT

# Wait for both applications to finish
wait $PID1
wait $PID2