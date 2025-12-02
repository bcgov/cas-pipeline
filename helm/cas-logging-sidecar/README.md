# CAS Logging Sidecar

This library chart is a template used to deploy a logging sidecar to a pod. The sidecar utilizes Fluent Bit and LogRotate to capture logs from a container within OpenShift and write them to ElasticSearch. The chart includes a service account, role, and role binding that are used to grant the service account access to the logs.

See [https://github.com/bcgov/cas-efk](https://github.com/bcgov/cas-efk) for more information about the EFK stack the logs are sent to.

## Usage

0. Add the library chart to your project. This can be done by adding the following to your `Chart.yaml` file:

    ```yaml
    dependencies:
      - name: cas-logging-sidecar
        repository: https://bcgov.github.io/cas-pipeline/
        version: 0.1.0
    ```

1. You will need determine the following parameters and add them into your values.yaml file (These will be under the `cas-logging-sidecar` or whatever you named the subchart in your file):

    ```yaml
      host: ~
      index: ~
      prefix: ~
      tag: ~
      logName: ~
    ```

    > *Note*: These parameters are used in the configmaps for Fluent Bit and Logrotate.

2. Associate the service account from the chart with the pod's template.

    ```text
    spec.template.spec.serviceAccountName: {{ .Release.Name }}-pod-logger
    ```

3. `{{- include }}` the sidecar container and volumes into your deployment file. This must be passed the following paramters: `.podToSidecar`, `.containerToSidecar`, `.logName`, `.tag`. This is done using a dict in the include statement, for example:

    ```text
    spec.template.spec.containers:
    {{- include "cas-logging-sidecar.containers" (dict 
        "containerToSidecar" "cas-cif-frontend"
        "logName" .Values.logName
        "host" "elasticsearch.abc123-namespace.svc.cluster.local") | nindent 8 }}

    spec.template.spec.volumes:
    {{- include "cas-logging-sidecar.volumes" (dict
      "releaseName" "cas-cif"
      ) | nindent 8 }}
    ```

    > *Note*: You can use `.Values.abc` if you want to use the values from your values.yaml file.
    > If the value comes from the dependency chart, such as the host, you will need to use `(index .Values "cas-logging-sidecar" "host")`. This is due to this dependency chart using hyphens in the name.

### Example use

```text
# templates/cas-frontend-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cas-frontend
spec:
  template:
    spec:
      serviceAccountName: {{ .Release.Name }}-pod-logger
      containers:
        - name: cas-frontend
          image: cas-frontend:latest
          ports:
            - containerPort: 80
        {{- include "cas-logging-sidecar.containers" (dict 
            "containerToSidecar" .Spec.Template.Spec.Containers.0.Name
            "logName" .Values.logName
            "host" (index .Values "cas-logging-sidecar" "host")  ) | nindent 8 }}
      volumes:
        {{- include "cas-logging-sidecar.volumes" . | nindent 8 }}
```

## Inputs

### `_logging-sidecar.yaml` Parameters list

| Parameter | Description | Example |
| --- | --- | --- |
| `"containerToSidecar"` | The container that the sidecar should log for. | `"cas-cif-frontend"` |
| `"logName"` | The name for the output logfile. **NOTE**: This must match the logname used in `values.yaml`. | `.Values.logName` |

### `values.yaml` list

| Value | Usage location | Description                                                                                                                                           | Example                                        |
| --- | --- |-------------------------------------------------------------------------------------------------------------------------------------------------------|------------------------------------------------|
| `logName` | `fluent-bit-configmap.yaml`, `logrotate-configmap.yaml` | The name for the output logfile.                                                                                                                      | `cif-frontend-log`                             |
| `host` | `fluent-bit-configmap.yaml` | ElasticSearch host to send logs to.                                                                                                                   | `elasticsearch.abc123-tools.svc.cluster.local` |
| `index` | `fluent-bit-configmap.yaml` | Index name.                                                                                                                                           | `cif-logs`                                     |
| `prefix` | `fluent-bit-configmap.yaml` | The index name is composed using a prefix and the date. The last string appended belongs to the date when the data is being generated.                | `cif-logs`                                     |
| `tag` | `fluent-bit-configmap.yaml` | Tag name associated to all records coming from this plugin.                                                                                           | `oc-cif`                                       |
| `appName`  | `fluent-bit` container                   | The name of the application that is being logged. Added to the Elastic index name to make it easier to search for logs. **Note:** Must be lowercase only. | `frontend` or `test-app-name`                                 |

## Fluent Bit Configuration

### Storage and Buffering Settings

The Fluent Bit configuration includes several storage parameters that are critical for reliable log delivery and preventing data loss:

| Parameter | Value | Purpose |
| --- | --- | --- |
| `Flush` | `5` | Sends data to Elasticsearch every 5 seconds, creating larger but less frequent batches to balance throughput and reduce overhead. |
| `storage.type` | `filesystem` | Persists chunks to disk instead of memory, preventing log loss on container restarts |
| `storage.path` | `/var/log/flb-storage/` | Directory where buffered chunks are stored |
| `storage.sync` | `normal` | Balanced approach for syncing data to disk (performance vs safety) |
| `storage.checksum` | `off` | Disabled for better performance in sidecar containers |
| `storage.max_chunks_up` | `128` | Limits chunks in memory (~256MB max) to prevent memory exhaustion |
| `storage.backlog.mem_limit` | `5M` | Additional safety net to cap backlog memory usage. |

**Why these matter:**
- **Prevents buffer overflow errors**: Increasing the `Flush` setting to 5 seconds reduces the HTTP request rate but means larger batches; combined with storage limits this helps avoid client buffer overflow while keeping memory bounded.
- **Data durability**: Filesystem storage ensures logs aren't lost if Elasticsearch is slow or the container restarts
- **Memory protection**: Limits prevent the sidecar from consuming excessive memory and impacting the main application
- **Backpressure handling**: When limits are reached, Fluent Bit pauses log reading rather than crashing

These settings favour data durability and predictable memory usage for the sidecar.

### Input: tail (container log capture)

The sidecar uses the `tail` plugin to read logs written by LogRotate. Important settings:

- `Path`: `/var/log/{{ .Values.logName }}.log` — the logfile produced by the container (set via the chart `logName` value).
- `Tag`: `{{ .Values.tag }}` — record tag used for matching in filters/outputs.
- `Mem_Buf_Limit`: `5MB` — per-file memory buffer for the tail input.
- `DB`: `/var/log/flb_kube.db` — sqlite DB used to track file offsets.
- `Refresh_Interval`: `10` — how often to check the filesystem for new files/changes.
- `Rotate_Wait`: `5` — wait time in seconds for rotated files to be released.
- `Ignore_Older`: `24h` — ignore files older than 24 hours.
- `Read_from_head`: `true` — start reading from the start of files when the DB is missing.
- `Multiline.parser`: `multiline` — reference to the multiline parser defined in `parsers.conf`.
- `Buffer_Chunk_Size`: `256KB` — input buffer chunk size used by the tail plugin.
- `Buffer_Max_Size`: `512KB` — maximum buffer size per file for the tail input.

These values were chosen to balance throughput and memory footprint in sidecar deployments.

### Filters

Two filters are applied to records before sending them to Elasticsearch:

- `lua` filter — runs the `add_timestamp.lua` script (mounted at `/fluent-bit/scripts/add_timestamp.lua`) to add a UTC `timestamp` field to records that lack one.
- `modify` filter — renames `timestamp` to `@timestamp` so Elasticsearch/Logstash style time keys are populated for indexing.

### Elasticsearch Output

The chart configures the `es` output plugin with the following notable options (most values are injected via chart values or environment variables):

- `Host`: `{{ .Values.host }}` and `Port`: `9200` — Elasticsearch endpoint (host supplied by values).
- `http_user` / `http_passwd`: provided via environment variables `${FLUENT_ELASTICSEARCH_USER}` and `${FLUENT_ELASTICSEARCH_PASSWORD}` (mounted from the chart's `fluentbit-credentials` secret).
- `Index`: `{{ .Values.index }}` — base index name.
- `Logstash_Prefix`: `{{ .Values.prefix }}-${FLUENT_APP_NAME}` — final index name is composed of the prefix and the application name provided at deploy time.
- `Logstash_Format`: `On` and `Logstash_DateFormat`: `%Y.%m.%d` — use Logstash-style index names with a date suffix.
- `Time_Key`: `@timestamp` — use the `@timestamp` field for event time (populated by the lua script / rename filter).
- `Retry_Limit`: `False` — retry indefinitely (subject to other buffering limits).
- `Buffer_Size`: `4MB` — memory buffer for the Elasticsearch output plugin to improve throughput.
- `tls`: `Off` — TLS is disabled by default in this chart; ensure your ES endpoint security is compatible with this setting or update the chart values.


These output settings are tuned to avoid HTTP client buffer overflow and to preserve log timestamps for correct indexing.
