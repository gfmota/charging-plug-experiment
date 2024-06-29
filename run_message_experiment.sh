NUMBER_OF_ANALYZERS=${1:-1}

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
COMPOSE_FILE="$SCRIPT_DIR/charging-plug-gateway/docker-compose.yml"

echo "Running message based experiment with $NUMBER_OF_ANALYZERS analyzers at the same time"

cd charging-plug-gateway
git checkout message-gateway
git pull
cd rabbitmq_config
python3 definitions_generator.py $NUMBER_OF_ANALYZERS
cd ..
mkdir ../log
> ../log/message-gateway.log
./gradlew bootRun >> ../log/message-gateway.log &
PID1=$!

docker-compose -f $COMPOSE_FILE up -d --build

cd ../charging-plug-data-analyzer
export NUMBER_OF_CONSUMERS=$NUMBER_OF_ANALYZERS
git checkout message-based-analyzer
git pull
> ../log/message-data-analyzer.log
./gradlew bootRun >> ../log/message-data-analyzer.log &
PID2=$!

# Function to stop both applications on exit
function cleanup {
  echo "Stopping applications..."
  kill $PID1
  kill $PID2
  docker-compose -f $COMPOSE_FILE down
  cd $SCRIPT_DIR/charging-plug-gateway
  git restore rabbitmq_config/definitions.json
}

# Trap the EXIT signal to ensure cleanup is done
trap cleanup EXIT

# Wait for both applications to finish
wait $PID1
wait $PID2