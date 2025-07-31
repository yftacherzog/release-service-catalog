#!/usr/bin/env bash

# Mock functions for prepare-and-push-helm-chart task tests

function skopeo() {
  # Only log to stderr for non-inspect operations (since inspect captures stderr)
  if [[ ! "$*" =~ inspect ]]; then
    echo Mock skopeo called with: $* >&2
  fi
  echo $* >> $(params.dataDir)/mock_skopeo.txt

  # Mock skopeo inspect for different image types
  if [[ "$*" =~ inspect.*docker://quay.io/test/squid:latest ]]; then
    # Mock regular OCI image
    echo '{
      "schemaVersion": 2,
      "mediaType": "application/vnd.oci.image.manifest.v1+json",
      "config": {
        "mediaType": "application/vnd.oci.image.config.v1+json",
        "digest": "sha256:014a1d8d502d6f775923f689a56074f993559090ae99c28f55eb2fc639e89b3f",
        "size": 10262
      },
      "layers": [
        {
          "mediaType": "application/vnd.oci.image.layer.v1.tar+gzip",
          "digest": "sha256:72355baa025c37463b476b55f0288533fe0db1fe776d89f2ed489976ef541031",
          "size": 33479504
        },
        {
          "mediaType": "application/vnd.oci.image.layer.v1.tar+gzip",
          "digest": "sha256:b3c38cd805f1678614d3c224fd7f46bfd4454568aa17b9a6d8724943750e3ced",
          "size": 36960349
        }
      ],
      "annotations": {
        "org.opencontainers.image.base.digest": "sha256:1edf0af866a852908484f6995278d1ecb7de0790852d37637e378822f82ac94b",
        "org.opencontainers.image.base.name": "registry.access.redhat.com/ubi10/ubi-minimal@sha256:ce6e336ca4c1b153e84719f9a123b9b94118dd83194e10da18137d1c571017fe"
      }
    }'
  elif [[ "$*" =~ inspect.*docker://quay.io/test/squid-helm:latest ]]; then
    # Mock Helm chart OCI artifact
    echo '{
      "schemaVersion": 2,
      "config": {
        "mediaType": "application/vnd.cncf.helm.config.v1+json",
        "digest": "sha256:5dfa6e9be2aca92ba72453dc36f0accd01dad88c0620631a9d87d96036b43e93",
        "size": 491
      },
      "layers": [
        {
          "mediaType": "application/vnd.cncf.helm.chart.content.v1.tar+gzip",
          "digest": "sha256:ec06d0d2530665d70ef96c05db15e4d2b5d932175a8568da62ace1afa0e2c931",
          "size": 266128
        }
      ],
      "annotations": {
        "org.opencontainers.image.created": "2025-07-24T13:14:52Z",
        "org.opencontainers.image.description": "A Helm chart for deploying a Squid proxy server.",
        "org.opencontainers.image.title": "squid-helm",
        "org.opencontainers.image.version": "0.1.134+f2fccb1-on-pr"
      }
    }'
  elif [[ "$*" =~ inspect.*docker://quay.io/test/squid-tester:latest ]]; then
    # Mock another regular OCI image
    echo '{
      "schemaVersion": 2,
      "mediaType": "application/vnd.oci.image.manifest.v1+json",
      "config": {
        "mediaType": "application/vnd.oci.image.config.v1+json",
        "digest": "sha256:abc123def456789012345678901234567890123456789012345678901234567890",
        "size": 8192
      },
      "layers": [
        {
          "mediaType": "application/vnd.oci.image.layer.v1.tar+gzip",
          "digest": "sha256:def456abc789012345678901234567890123456789012345678901234567890123",
          "size": 12345678
        }
      ],
      "annotations": {
        "org.opencontainers.image.title": "squid-tester"
      }
    }'

  # Mock skopeo copy for Helm chart extraction
  elif [[ "$*" =~ copy.*docker://quay.io/test/squid-helm:latest.*dir: ]]; then
    # Extract destination directory from command
    dest_dir=$(echo "$*" | sed -n 's/.*dir:\([^ ]*\).*/\1/p')

    if [ -n "$dest_dir" ]; then
      echo "  Mock: Creating chart directory structure at $dest_dir" >&2
      mkdir -p "$dest_dir"

      # Create a mock chart tarball
      chart_content_dir=$(mktemp -d)

      # Create mock Helm chart files
      mkdir -p "$chart_content_dir/squid-helm"
      cat > "$chart_content_dir/squid-helm/Chart.yaml" << 'EOF'
apiVersion: v2
name: squid-helm
description: A Helm chart for deploying a Squid proxy server.
type: application
version: 0.1.134
appVersion: "1.0"
EOF

      cat > "$chart_content_dir/squid-helm/values.yaml" << 'EOF'
# Default values for squid-helm
image:
  repository: quay.io/yftacherzog-konflux/user-ns2/squid
  tag: "latest"
  pullPolicy: IfNotPresent

sidecar:
  image:
    repository: quay.io/yftacherzog-konflux/user-ns2/squid-helper
    tag: "v1.0.0"

dependencies:
  - name: external-service
    image: quay.io/yftacherzog-konflux/user-ns2/external-service:latest

replicaCount: 1

service:
  type: ClusterIP
  port: 3128
EOF

      mkdir -p "$chart_content_dir/squid-helm/templates"
      cat > "$chart_content_dir/squid-helm/templates/deployment.yaml" << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "squid-helm.fullname" . }}
  labels:
    {{- include "squid-helm.labels" . | nindent 4 }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      {{- include "squid-helm.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "squid-helm.selectorLabels" . | nindent 8 }}
    spec:
      containers:
        - name: squid
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - name: http
              containerPort: 3128
              protocol: TCP
        - name: sidecar
          image: "{{ .Values.sidecar.image.repository }}:{{ .Values.sidecar.image.tag }}"
          imagePullPolicy: IfNotPresent
        # Example of hardcoded image reference that should be updated
        - name: init-container
          image: quay.io/yftacherzog-konflux/user-ns2/init-helper:v1.0.0
          command: ["sh", "-c", "echo 'Initializing...'"]
EOF

      cat > "$chart_content_dir/squid-helm/templates/_helpers.tpl" << 'EOF'
{{- define "squid-helm.fullname" -}}
{{- .Chart.Name -}}
{{- end }}
EOF

      # Create the tarball that represents the chart content layer
      chart_tarball="$dest_dir/ec06d0d2530665d70ef96c05db15e4d2b5d932175a8568da62ace1afa0e2c931"
      tar -czf "$chart_tarball" -C "$chart_content_dir" .

      # Clean up temporary content directory
      rm -rf "$chart_content_dir"

      echo "  Mock: Created chart tarball at $chart_tarball" >&2
      return 0
    else
      echo "  Mock: Failed to extract destination directory" >&2
      return 1
    fi

  # Handle skopeo copy operations for pushing (dir to docker://)
  elif [[ "$*" =~ copy.*dir:.*docker:// ]]; then
    # Extract destination for push operations
    dest=$(echo "$*" | grep -o 'docker://[^ ]*' | tail -1)
    echo "Mock: Successfully pushed to $dest" >&2
    return 0

  else
    echo "Mock skopeo: No specific mock for: $*" >&2
    return 1
  fi
}

# Mock commands for testing

# Mock helm command
helm() {
  if [[ "$1" == "package" ]]; then
    # Mock helm package
    local chart_dir="$2"
    local output_dir=""

    # Parse arguments to find output directory
    for ((i=3; i<=$#; i++)); do
      if [[ "${!i}" == "-d" ]]; then
        ((i++))
        output_dir="${!i}"
        break
      fi
    done

    if [ -z "$output_dir" ]; then
      output_dir="."
    fi

    # Create a mock chart package
    local chart_name="squid-helm"
    if [ -f "$chart_dir/Chart.yaml" ]; then
      chart_name=$(grep "^name:" "$chart_dir/Chart.yaml" | awk '{print $2}' || echo "squid-helm")
    fi

    local chart_version="1.0.0"
    if [ -f "$chart_dir/Chart.yaml" ]; then
      chart_version=$(grep "^version:" "$chart_dir/Chart.yaml" | awk '{print $2}' || echo "1.0.0")
    fi

    local package_file="$output_dir/${chart_name}-${chart_version}.tgz"

    echo "Mock: Packaging chart from $chart_dir" >&2
    echo "Mock: Creating package $package_file" >&2

    # Create a mock tgz file
    mkdir -p "$output_dir"
    echo "Mock Helm chart package" > "$package_file"

    return 0

  elif [[ "$1" == "push" ]]; then
    # Mock helm push
    local package_file="$2"
    local registry="$3"

    echo "Mock: Pushing $package_file to $registry" >&2
    echo "Mock: Successfully pushed chart" >&2

    return 0
  else
    echo "Mock helm: Unknown command $1" >&2
    return 1
  fi
}

# Export the function so it's available in subshells
export -f skopeo
export -f helm
export -f date
