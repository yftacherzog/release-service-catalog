# Filter Snapshot Task

This task filters components from a snapshot based on `skopeo inspect` results. It uses the metadata returned by `skopeo inspect` to determine which components should be removed from the snapshot.

## Overview

The `filter-snapshot` task examines each component in a snapshot using `skopeo inspect --raw` and applies filter criteria to determine which components should be removed. This is useful for filtering out specific types of artifacts (like Helm charts) from snapshots before they proceed to downstream processing.

## Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `snapshotPath` | string | Yes | - | Path to the snapshot JSON file to filter |
| `filters` | string | No | `"[]"` | JSON array of filter criteria |
| `dataPath` | string | Yes | - | Path to the data JSON file (for consistency) |
| `ociStorage` | string | No | `"empty"` | OCI repository for trusted artifacts |
| `ociArtifactExpiresAfter` | string | No | `"1d"` | Expiration for trusted artifacts |
| `trustedArtifactsDebug` | string | No | `""` | Enable debug logging for trusted artifacts |
| `orasOptions` | string | No | `""` | Options for oras commands |
| `sourceDataArtifact` | string | No | `""` | Location of trusted artifacts |
| `dataDir` | string | No | `$(workspaces.data.path)` | Data directory location |
| `taskGitUrl` | string | Yes | - | Git URL for task repository |
| `taskGitRevision` | string | Yes | - | Git revision for task repository |

## Results

| Result | Type | Description |
|--------|------|-------------|
| `includedSnapshotPath` | string | Path to the filtered snapshot file |
| `sourceDataArtifact` | string | Produced trusted data artifact |

## Filter Configuration

The `filters` parameter accepts a JSON array of filter objects. Each filter object has a `type` field that determines the filtering logic:

### Filter Types

#### 1. `helm` - Filter Helm Charts
Filters components based on Helm chart title and version from annotations.

```json
{
  "type": "helm",
  "title": "squid-helm",
  "version": "0.1.134+f2fccb1-on-pr"
}
```

- `title` (required): The Helm chart title from `org.opencontainers.image.title` annotation
- `version` (optional): The Helm chart version from `org.opencontainers.image.version` annotation

#### 2. `mediaType` - Filter by Media Type
Filters components based on the config mediaType.

```json
{
  "type": "mediaType",
  "value": "application/vnd.cncf.helm.config.v1+json"
}
```

- `value` (required): The mediaType to match against

#### 3. `annotation` - Filter by Annotation
Filters components based on specific annotations.

```json
{
  "type": "annotation",
  "key": "org.opencontainers.image.title",
  "value": "squid-helm"
}
```

- `key` (required): The annotation key to check
- `value` (required): The annotation value to match

## Usage Examples

### Filter out Helm Charts

```yaml
- name: filter-snapshot
  taskRef:
    name: filter-snapshot
  params:
    - name: snapshotPath
      value: "snapshot.json"
    - name: filters
      value: |
        [
          {
            "type": "mediaType",
            "value": "application/vnd.cncf.helm.config.v1+json"
          }
        ]
```

### Filter out Specific Helm Chart

```yaml
- name: filter-snapshot
  taskRef:
    name: filter-snapshot
  params:
    - name: snapshotPath
      value: "snapshot.json"
    - name: filters
      value: |
        [
          {
            "type": "helm",
            "title": "squid-helm",
            "version": "0.1.134+f2fccb1-on-pr"
          }
        ]
```

### Multiple Filters

```yaml
- name: filter-snapshot
  taskRef:
    name: filter-snapshot
  params:
    - name: snapshotPath
      value: "snapshot.json"
    - name: filters
      value: |
        [
          {
            "type": "mediaType",
            "value": "application/vnd.cncf.helm.config.v1+json"
          },
          {
            "type": "annotation",
            "key": "org.opencontainers.image.description",
            "value": "Test image"
          }
        ]
```

## Pipeline Integration

To integrate this task into the `push-to-external-registry` pipeline:

1. Add the task after `reduce-snapshot` and before `apply-mapping`
2. Update the `apply-mapping` task to use the filtered snapshot
3. Add a pipeline parameter for filters

### Example Pipeline Integration

```yaml
# Add to pipeline params
- name: snapshotFilters
  type: string
  description: JSON array of filter criteria to apply to snapshot components
  default: "[]"

# Add the filter-snapshot task
- name: filter-snapshot
  taskRef:
    resolver: "git"
    params:
      - name: url
        value: $(params.taskGitUrl)
      - name: revision
        value: $(params.taskGitRevision)
      - name: pathInRepo
        value: tasks/managed/filter-snapshot/filter-snapshot.yaml
  params:
    - name: snapshotPath
      value: "$(tasks.collect-data.results.snapshotSpec)"
    - name: filters
      value: $(params.snapshotFilters)
    - name: dataPath
      value: "$(tasks.collect-data.results.data)"
    - name: ociStorage
      value: $(params.ociStorage)
    - name: sourceDataArtifact
      value: "$(tasks.reduce-snapshot.results.sourceDataArtifact)"
    - name: dataDir
      value: $(params.dataDir)
    - name: trustedArtifactsDebug
      value: "$(params.trustedArtifactsDebug)"
    - name: taskGitUrl
      value: "$(params.taskGitUrl)"
    - name: taskGitRevision
      value: "$(params.taskGitRevision)"
  workspaces:
    - name: data
      workspace: release-workspace
  runAfter:
    - reduce-snapshot

# Update apply-mapping to use filtered snapshot
- name: apply-mapping
  # ... existing params ...
  params:
    - name: snapshotPath
      value: "$(tasks.filter-snapshot.results.includedSnapshotPath)"
    # ... other params ...
  runAfter:
    - filter-snapshot
```

## Error Handling

- If `skopeo inspect` fails for a component, the component is kept (not filtered out)
- If no filters are provided, the original snapshot is returned unchanged
- If all components are filtered out, an empty components array is returned
- The task fails if the snapshot file is not found

## Testing

The task includes test files in the `tests/` directory:

- `test-filter-snapshot.yaml` - Tests with actual skopeo inspect calls
- `test-filter-snapshot-simple.yaml` - Tests with mocked results

Run tests using the Tekton CLI:

```bash
tkn pipeline start test-filter-snapshot-simple \
  --param ociStorage="your-oci-storage" \
  --workspace name=tests-workspace,volumeClaimTemplateFile=workspace-template.yaml
``` 
