# Check runner compatibility
echo "::group::metrics docker image setup"
echo "GitHub action: $metrics_ACTION ($metrics_ACTION_PATH)"
cd $metrics_ACTION_PATH
for DEPENDENCY in docker jq; do
  if ! which $DEPENDENCY > /dev/null 2>&1; then
    echo "::error::\"$DEPENDENCY\" is not installed on current runner but is needed to run metrics"
    MISSING_DEPENDENCIES=1
  fi
done
if [[ $MISSING_DEPENDENCIES == "1" ]]; then
  echo "Runner compatibility: missing dependencies"
  exit 1
else
  echo "Runner compatibility: compatible"
fi

# Create environment file from inputs and GitHub variables
touch .env
for INPUT in $(echo $INPUTS | jq -r 'to_entries|map("INPUT_\(.key|ascii_upcase)=\(.value|@uri)")|.[]'); do
  echo $INPUT >> .env
done
env | grep -E '^(GITHUB|ACTIONS|CI|TZ)' >> .env
echo "Environment variables: loaded"

# Renders output folder
metrics_RENDERS="/metrics_renders"
sudo mkdir -p $metrics_RENDERS
echo "Renders output folder: $metrics_RENDERS"

# Source repository (picked from action name)
metrics_SOURCE=$(echo $metrics_ACTION | sed -E 's/metrics.*?$//g' | sed -E 's/_//g')
echo "Source: $metrics_SOURCE"

# Version (picked from package.json)
metrics_VERSION=$(grep -Po '(?<="version": ").*(?=")' package.json)
echo "Version: $metrics_VERSION"

# Image tag (extracted from version or from env)
metrics_TAG=v$(echo $metrics_VERSION | sed -r 's/^([0-9]+[.][0-9]+).*/\1/')
echo "Image tag: $metrics_TAG"

# Image name
# Official action
if [[ $metrics_SOURCE == "siosios" ]]; then
  # Use registry with pre-built images
  if [[ ! $metrics_USE_PREBUILT_IMAGE =~ ^([Ff]alse|[Oo]ff|[Nn]o|0)$ ]]; then
    # Is released version
    set +e
    metrics_IS_RELEASED=$(expr $(expr match $metrics_VERSION .*-beta) == 0)
    set -e
    echo "Is released version: $metrics_IS_RELEASED"
    if [[ "$metrics_IS_RELEASED" -eq "0" ]]; then
      metrics_TAG="$metrics_TAG-beta"
      echo "Image tag (updated): $metrics_TAG"
    fi
    metrics_IMAGE=ghcr.io/siosios/metrics:$metrics_TAG
    echo "Using pre-built version $metrics_TAG, will pull docker image from GitHub registry"
    if ! docker image pull $metrics_IMAGE; then
      echo "Failed to fetch docker image from GitHub registry, will rebuild it locally"
      metrics_IMAGE=metrics:$metrics_VERSION
    fi
  # Rebuild image
  else
    echo "Using an unreleased version ($metrics_VERSION)"
    metrics_IMAGE=metrics:$metrics_VERSION
  fi
# Forked action
else
  echo "Using a forked version"
  metrics_IMAGE=metrics:forked-$metrics_VERSION
fi
echo "Image name: $metrics_IMAGE"

# Build image if necessary
set +e
docker image inspect $metrics_IMAGE
metrics_IMAGE_NEEDS_BUILD="$?"
set -e
if [[ "$metrics_IMAGE_NEEDS_BUILD" -gt "0" ]]; then
  echo "Image $metrics_IMAGE is not present locally, rebuilding it from Dockerfile"
  docker build -t $metrics_IMAGE .
else
  echo "Image $metrics_IMAGE is present locally"
fi
echo "::endgroup::"

# Run docker image with current environment
docker run --init --rm --volume $GITHUB_EVENT_PATH:$GITHUB_EVENT_PATH --volume $metrics_RENDERS:/renders --env-file .env $metrics_IMAGE
rm .env