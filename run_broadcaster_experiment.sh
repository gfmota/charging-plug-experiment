NUMBER_OF_ANALYZERS=${1:-1}

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
COMPOSE_FILE="$SCRIPT_DIR/charging-plug-gateway/docker-compose.yml"

echo "Running broadcaster experiment with $NUMBER_OF_ANALYZERS analyzers at the same time"

cd charging-plug-gateway
git checkout broadcaster-gateway-new-feature
git pull
mkdir ../log
> ../log/broadcaster-gateway.log
./gradlew bootRun >> ../log/broadcaster-gateway.log &
PID1=$!

docker-compose -f $COMPOSE_FILE up -d --build

cd ../charging-plug-data-analyzer
export NUMBER_OF_CLIENTS=$NUMBER_OF_ANALYZERS
git checkout broadcaster-analyzer
git pull
> ../log/broadcaster-data-analyzer.log
sleep 60
./gradlew bootRun >> ../log/broadcaster-data-analyzer.log &
PID2=$!

cd ..

# Function to stop both applications on exit
function cleanup {
  echo "Stopping applications..."
  kill $PID1
  kill $PID2
  docker-compose -f $COMPOSE_FILE down
  cd $SCRIPT_DIR/charging-plug-gateway
  git restore localStorage.csv
}

# Trap the EXIT signal to ensure cleanup is done
trap cleanup EXIT

# Wait for both applications to finish
wait $PID1
wait $PID2