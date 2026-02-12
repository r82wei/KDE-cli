docker buildx create \
  --name KDEBuilder \
  --driver docker-container \
  --platform linux/amd64,linux/arm64,linux/386 \
  --use

docker buildx inspect KDEBuilder --bootstrap

docker buildx ls