#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Define variables
ECR_REGISTRY="public.ecr.aws/r6u4x6s4"
REPOSITORY_NAME="honeypot"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
REGION="ap-southeast-1"

# Function to build and push an image
build_and_push() {
    local app_file=$1
    local version=$2

    echo "Building multi-architecture Docker image for $app_file..."
    docker buildx create --use --name multi-arch-builder --platform linux/amd64,linux/arm64 || true
    docker buildx use multi-arch-builder
    
    # Build and push for amd64
    docker buildx build --platform linux/amd64 \
        -t $ECR_REGISTRY/$REPOSITORY_NAME:$version-amd64-$TIMESTAMP \
        -t $ECR_REGISTRY/$REPOSITORY_NAME:$version-amd64-latest \
        --build-arg APP_FILE=$app_file \
        --push .

    # Build and push for arm64
    docker buildx build --platform linux/arm64 \
        -t $ECR_REGISTRY/$REPOSITORY_NAME:$version-arm64-$TIMESTAMP \
        -t $ECR_REGISTRY/$REPOSITORY_NAME:$version-arm64-latest \
        --build-arg APP_FILE=$app_file \
        --push .

    echo "Images for $app_file pushed to ECR with tags:"
    echo "  $version-amd64-$TIMESTAMP, $version-amd64-latest"
    echo "  $version-arm64-$TIMESTAMP, $version-arm64-latest"
}

# Authenticate Docker to ECR
echo "Authenticating Docker to ECR..."
aws ecr-public get-login-password --region us-east-1 | docker login --username AWS --password-stdin public.ecr.aws/r6u4x6s4

# Build and push app.py as v1
build_and_push "app.py" "v1"

# Build and push app2.py as v2
build_and_push "app2.py" "v2"

echo "Multi-architecture deployment complete. Timestamp: $TIMESTAMP"
