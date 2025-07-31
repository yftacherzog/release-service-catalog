#!/usr/bin/env bash
set -eux

# mocks to be injected into task step scripts

function skopeo() {
  echo Mock skopeo called with: $* >&2
  echo $* >> $(params.dataDir)/mock_skopeo.txt

  # Mock skopeo inspect --retry-times 3 --no-tags --raw for different image types
  if [[ "$*" == "inspect --retry-times 3 --no-tags --raw docker://quay.io/test/squid:latest" ]] || [[ "$*" =~ "inspect --retry-times 3 --no-tags --raw docker://quay.io/yftacherzog-konflux/user-ns2/squid:latest" ]]; then
    # Regular container image
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
    return
  fi

  if [[ "$*" == "inspect --retry-times 3 --no-tags --raw docker://quay.io/test/squid-helm:latest" ]] || [[ "$*" =~ "inspect --retry-times 3 --no-tags --raw docker://quay.io/yftacherzog-konflux/user-ns2/squid-helm:latest" ]]; then
    # Helm chart image (should be filtered out)
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
    return
  fi

  if [[ "$*" == "inspect --retry-times 3 --no-tags --raw docker://quay.io/test/squid-tester:latest" ]] || [[ "$*" =~ "inspect --retry-times 3 --no-tags --raw docker://quay.io/yftacherzog-konflux/user-ns2/squid-tester:latest" ]]; then
    # Another regular container image
    echo '{
      "schemaVersion": 2,
      "mediaType": "application/vnd.oci.image.manifest.v1+json",
      "config": {
        "mediaType": "application/vnd.oci.image.config.v1+json",
        "digest": "sha256:9876543210fedcba1234567890abcdef",
        "size": 8765
      },
      "layers": [
        {
          "mediaType": "application/vnd.oci.image.layer.v1.tar+gzip",
          "digest": "sha256:fedcba0987654321abcdef1234567890",
          "size": 12345678
        },
        {
          "mediaType": "application/vnd.oci.image.layer.v1.tar+gzip",
          "digest": "sha256:abcdef1234567890fedcba0987654321",
          "size": 9876543
        }
      ],
      "annotations": {
        "org.opencontainers.image.base.digest": "sha256:1edf0af866a852908484f6995278d1ecb7de0790852d37637e378822f82ac94b",
        "org.opencontainers.image.base.name": "registry.access.redhat.com/ubi10/ubi-minimal@sha256:ce6e336ca4c1b153e84719f9a123b9b94118dd83194e10da18137d1c571017fe"
      }
    }'
    return
  fi

  # Default case for any other image
  if [[ "$*" =~ inspect.*--raw ]]; then
    echo '{
      "schemaVersion": 2,
      "mediaType": "application/vnd.oci.image.manifest.v1+json",
      "config": {
        "mediaType": "application/vnd.oci.image.config.v1+json",
        "digest": "sha256:default1234567890abcdef",
        "size": 5000
      },
      "layers": [
        {
          "mediaType": "application/vnd.oci.image.layer.v1.tar+gzip",
          "digest": "sha256:defaultabcdef1234567890",
          "size": 15000000
        }
      ],
      "annotations": {
        "org.opencontainers.image.base.digest": "sha256:1edf0af866a852908484f6995278d1ecb7de0790852d37637e378822f82ac94b",
        "org.opencontainers.image.base.name": "registry.access.redhat.com/ubi10/ubi-minimal@sha256:ce6e336ca4c1b153e84719f9a123b9b94118dd83194e10da18137d1c571017fe"
      }
    }'
    return
  fi

  echo Error: Unexpected skopeo call: $*
  exit 1
} 
