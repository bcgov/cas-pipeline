# CAS Logging Sidecar using Vector (Sidecar Collector and Namespace Gateway)

> [!WARNING]
> This documentation is for chart version `0.7.0` and newer. `0.7.0` changes from FluentBit to Vector, introducing a major shift, changing the usage pattern from _sidecars_ to _sidecars plus gateway_. Please see the [documentation for the branch tagged `0.6.0`](https://github.com/bcgov/cas-pipeline/tree/cas-logging-sidecar-0.6.0/helm/cas-logging-sidecar) for older versions.

This chart is a combination of a template used to deploy a logging sidecar to a pod and a gateway in a namespace to aggregate logs from multiple pods before sending them to Elasticsearch.
The sidecar utilizes Vector to capture logs from logs `tee`d to a file from the application container's stdout, with Logrotate is used to ensure the logfile is rotated and does not grow forever. The gateway then receives logs from the sidecar, enriches them with any needed metadata (timestamps), filters unneeded log info (e.g. heartbeats) and sends them to Elasticsearch.

See [https://github.com/bcgov/cas-efk](https://github.com/bcgov/cas-efk) for more information about the EFK stack the logs are sent to.

## Usage

1. Add the library chart to your project. This can be done by adding the following to your `Chart.yaml` file:

   ```yaml
   dependencies:
     - name: cas-logging-sidecar
       repository: https://bcgov.github.io/cas-pipeline/
       version: 0.7.0
   ```

1. You will need to determine the following parameters and add them into your values.yaml file (These will be under the `cas-logging-sidecar` or whatever you named the subchart in your file):

   ```yaml
   host: ~
   prefix: ~
   tag: ~
   ```

   > [!NOTE]
   > These parameters are used in the configmaps for Vector's sidecar collector and namespace gateway.

   > [!TIP]
   > There are additional values parameters for configuring the sidecar's Vector collector and LogRotate, primarily their resource requests and limits. See the defaults under `collector` and `logRotate` in the `values.yaml` file for more details.
   >
   > Further values under `vector` in the `values.yaml` file are for configuring the Vector aggregator gateway. These defaults should work for most instances.

1. The sidecar to collect the logs from an application pod's logfile is templated into three main pieces:
   1. Volumes to hold the logs and configsMaps: `{{- include "vector-collector.loggingVolumes" . }}`
   1. A volumeMount to mount the log storage to the application: `{{- include "vector-collector.applicationVolumeMounts" . }}`, which also mounts to the sidecar containers. Logs are to be written to `/var/log/app/app.log`.
   1. initContainers to run the sidecar containers: `{{- include "vector-collector.container" (dict "Values" .Values "appName" "APPLICATION_NAME") | nindent 8 }}`. These use `initContainer[].restartPolicy: Always` [to run as a sidecar](https://kubernetes.io/docs/concepts/workloads/pods/sidecar-containers/)

   > [!NOTE]
   > The `appName` parameter is used to create the index named in Elasticsearch. The name format used is `{{ .Values.prefix }}-{{ app_name }}-%Y.%m`. Unlike previous versions of this chart, it is the only parameter required in the templates.
   >
   > E.g. `prefix=cas-prod-logs` + `appName=backend` + (`%Y.%m` is the current year and month) = `cas-prod-logs-backend-26-09`.

   > [!IMPORTANT]
   > In order to use the sidecar, an application pod must output its logs to a file (`/var/log/app/app.log` by default). For OpenShift, the logs should _also_ be output to the console (`STDERR`/`STDOUT`). Some applications, like DjangoNinja + Gunicorn or the CrunchyDB PostgreSQL Operator can be configured to output logs to both console and a file. Some, like Next.js, output logs only to the console. See [Logging Simultaneously to Console and File](#logging-simultaneously-to-console-and-file) for more templates and examples.

### Logging Simultaneously to Console and File

The sidecar tails a log file before sending it along. Below are some instructions on how to configure certain frameworks and applications to output logs to both the console (for OpenShift) and a file (for the sidecar).

#### `tee` output

_This way is not recommended for production use_. It can cause issues with `PID1` due to a separate process being spawned to handle the `tee` pipe. You can `| tee -a /var/log/app/app.log` on the command run in your deployment template to output logs to both console and file.

> [!TIP]
> There is a partial template available to use `{{- include "vector-collector.tee" . }}` that sets up a `tee` pipe to split logs between a file and stdout.

#### DjangoNinja run by Gunicorn

Gunicorn and Django-Ninja can output logs directly to a file, meaning `tee` is not needed for this setup. If Gunicorn is used, it can capture Django's console output and feed it into a single log file, rather than each having its own log file.

> [!NOTE]
> Uses [WatchedFileHandler](https://docs.python.org/3/library/logging.handlers.html#watchedfilehandler), as it supports the external `logrotate` managing the log file rotation.

##### Gunicorn's `gunicorn.conf.py`

Gunicorn will pull configuration from a `gunicorn.conf.py` file in the same directory that it's run in. Create or update this file with the following content to add log file output to the defaults. See [Gunicorn's logging documentation](https://gunicorn.org/reference/settings/#logging) for more details.

```python
# gunicorn.conf.py
capture_output = True  # Capture stdout/stderr from Django

logconfig_dict = {
    "version": 1,
    "root": {"level": "INFO", "handlers": ["console", "logfile"]},
    "handlers": {
        "console": {
            "class": "logging.StreamHandler",
            "formatter": "generic",
            "stream": "ext://sys.stdout",
        },
        "logfile": {
            "class": "logging.handlers.WatchedFileHandler",
            "formatter": "generic",
            "args": ("/var/log/app/app.log",),
        },
    },
}
```

##### Django's `settings.py`

If not capturing Django's logs with Gunicorn, in Django's `settings.py` add the `handlers` logging configuration to be consistent with the `handlers.console` settings. Then add to the `loggers` config to use the `file` handler. See Django's [logging](https://docs.djangoproject.com/en/6.0/topics/logging/#examples) and [handlers](https://docs.djangoproject.com/en/6.0/ref/logging/#handlers) documentation.

```python
# Django's settings.py
LOGGING = {
    # version, format, defaults, etc...
    "handlers": {
        "file": {
            "class": "logging.handlers.WatchedFileHandler",
            "filename": "/var/log/app/django.log",
        }
    },
    "loggers": {
        "django": {
            "handlers": ["file"],
        }
    },
}
```

#### kube-log-runner

Some applications _only_ output to console. We can wrap them in Kubernete's `kube-log-runner` to capture their output and split them to console and file. Unlike `tee`, this handles SIGTERM/SIGKILL and process pruning. `kube-log-runner` also works with many distroless and hardened images that don't include a shell.

Basic kube logger:
https://dl.k8s.io/v1.29.0/bin/linux/amd64/kube-log-runner /usr/local/bin/kube-log-runner
Add links to https://kubernetes.io/docs/concepts/cluster-administration/system-logs/ when talking about `kube-log-runner`.

1. Add the `kube-log-runner` binary to your Dockerfile: `https://dl.k8s.io/{version}/bin/linux/amd64/kube-log-runner /usr/local/bin/kube-log-runner`, where `{version}` is the Kubernetes version you are using. For OpenShift 4.18, use `v1.31.0` (use `oc version` while logged in to see the Kubernetes Version). If using multi-stage builds, do this in the "builder" stage, and copy it to the final image.
1. Mark the `kube-log-runner` binary as executable: `RUN chmod +x /usr/local/bin/kube-log-runner`
1. Use `kube-log-runner` as your `ENTRYPOINT`. To output logs to console and to the expected file, use the `-also-stdout` and `-log-file=/var/log/app/app.log` options. **Important:** `kube-log-runner` uses single dash (`-`) for its options!
1. Use `CMD` to specify your application command. `kube-log-runner` will wrap this in the same way `dumb-init` does.

> [!TIP]
> For more information on `kube-log-runner`, see the [klogs documentation](https://kubernetes.io/docs/concepts/cluster-administration/system-logs/) and the [kube-log-runner repo](https://github.com/kubernetes/kubernetes/blob/master/staging/src/k8s.io/component-base/logs/kube-log-runner/README.md)

##### NextJS

```Dockerfile
# 1. Download kube-log-runner. If using multi-stage builds, do this in the the "builder" equivalent stage.
# v1.31.0 matches Kubernetes version used in OpenShift v4.18.
ENV KUBE_VERSION=v1.31.0
ENV KUBE_ARCH=amd64

ADD https://dl.k8s.io/${KUBE_VERSION}/bin/linux/${KUBE_ARCH}/kube-log-runner /usr/local/bin/kube-log-runner
# 2. Make the kube-log-runner binary executable.
RUN chmod +x /usr/local/bin/kube-log-runner

COPY --from=builder /usr/local/bin/kube-log-runner /usr/local/bin/kube-log-runner

# 3. Use `kube-log-runner` as the `ENTRYPOINT`.
ENTRYPOINT ["/usr/local/bin/kube-log-runner", "-also-stdout", "-log-file=/var/log/app/app.log"]

# 4. Use `CMD` to specify the default command to run, which `kube-log-runner` wraps.
CMD ["node", "server.js"]
```

### Example use

Using an image with the `kube-log-runner` method above.

```text
# templates/cas-frontend-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cas-frontend
spec:
  template:
    spec:
      containers:
        - name: cas-frontend
          image: kube-log-runner--cas-frontend:latest
          ports:
            - containerPort: 80
          volumeMounts:
            {{- include "vector-collector.applicationVolumeMounts" . | nindent 12 }} # REQUIRED
      initContainers:
        {{- include "vector-collector.container" (dict "Values" .Values "appName" "cas-frontend") | nindent 8 }} # REQUIRED
      volumes:
        {{- include "vector-collector.loggingVolumes" . | nindent 8 }} # REQUIRED
```

#### Deployable Test Application

This is a self-contained test application that uses the logging sidecar.

```yaml
kind: Deployment
apiVersion: apps/v1
metadata:
  name: test-log-generator
  namespace: {{ .Release.Namespace }}
  labels:
    app-name: test-log-generator
    helm.sh/chart: {{ .Chart.Name | quote }}
    app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
    app.kubernetes.io/managed-by: {{ .Release.Service | quote }}
spec:
  replicas: 1
  template:
    spec:
      containers:
        - name: testgenerator
          image: "busybox:latest"
          command:
            - /bin/sh
            - "-c"
            - |
              {
                echo "=== Starting Log Generator Test Loop ==="
                while true; do
                  echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] This is a standard STDOUT log message for testing Elastic forwarding."
                  sleep 3

                  echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] This is a synthetic error log message!"
                  sleep 5
                done
              }
              {{- include "vector-collector.tee" . | nindent 14 }} # Log to file and console
          resources:
            limits:
              cpu: 50m
              memory: 32Mi
            requests:
              cpu: 10m
              memory: 16Mi
          imagePullPolicy: Always
          volumeMounts:
            {{- include "vector-collector.applicationVolumeMounts" . | nindent 12 }} # REQUIRED
      initContainers:
        {{- include "vector-collector.container" (dict "Values" .Values "appName" "testgenerator") | nindent 8 }}  # REQUIRED
      volumes:
        {{- include "vector-collector.loggingVolumes" . | nindent 8 }} # REQUIRED
```

## Inputs

### `_collector-sidecar.tpl`/`vector-collector.container` parameters list

| Parameter | Description                                      | Example              |
| --------- | ------------------------------------------------ | -------------------- |
| `"app"`   | The name of the application, as sent to Elastic. | `"cas-cif-frontend"` |

> [!NOTE]
> The name format used is `{{ .Values.prefix }}-{{ app_name }}-%Y.%m`. Unlike previous versions of this chart, it is the only parameter required in the templates.
>
> E.g. `prefix=cas-prod-logs` + `appName=backend` + (`%Y.%m` is the current year and month) = `cas-prod-logs-backend-26-09`.

### `values.yaml` list

#### Required values

| Value    | Usage location              | Description                                                                                                                            | Example                                        |
| -------- | --------------------------- | -------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------- |
| `host`   | `fluent-bit-configmap.yaml` | ElasticSearch host to send logs to.                                                                                                    | `elasticsearch.abc123-tools.svc.cluster.local` |
| `prefix` | `fluent-bit-configmap.yaml` | The index name is composed using a prefix and the date. The last string appended belongs to the date when the data is being generated. | `cif-logs`                                     |
| `tag`    | `fluent-bit-configmap.yaml` | Tag name associated to all records coming from this plugin.                                                                            | `oc-cif`                                       |


#### `collector`, `logRotate`, `vector`(gateway) values

These are set to sensible defaults. The `collector` simply forwards logs to the aggregator and it is very efficient at doing so. Resources are set to "safe" amounts, but could likely be tuned lower for pods with less log output.

For `logRotate`, it can also be kept very small, and only runs every 300 seconds (5 minutes). This rotation time is part of the run command in the logRotate sidecar container.

The `vector` values cover those specific to the aggregator gateway. Our Elastic instance's details are added as volume secrets to the pods and used by `aggregator-configmap.yaml`.

##### Further documentation

- [LogRotate documentation](https://github.com/logrotate/logrotate)
- [Vector documentation for resource allocation](https://vector.dev/docs/setup/going-to-prod/sizing/)
- `gateway` takes its defaults from the [source chart's `value.yaml`](https://github.com/vectordotdev/helm-charts/blob/develop/charts/vector/values.yaml) using `role: "Aggregator"`.
- [All helm value options for the Vector helm chart](https://github.com/vectordotdev/helm-charts/tree/develop/charts/vector#all-configuration-options).

## Configmaps

### Vector Sidecar

`templates/agent/agent-configmap.yaml`

#### Vector (Agent) Collector

`data>vector.yaml`

The collector is configured as a Vector Agent to source from a log file at `/var/log/app/app.log` (as well as `app.log.*` to handle rotated logs). It is able to understand and keep track of files that are rotated by the `logRotate` container so no data is lost. It uses a pattern to handle multiline output from NextJS. It adds additional information from the environment (the app name) to the metadata, which is then sent to the Vector Gateway.

#### Log Rotate

`data>logrotate.conf`

LogRotate handles rotating log files when they get large. It is configured to rotate when the file reaches 25 megabytes, by copying to a new file, then removing existing data from the existing file (which Vector can handle). It keeps 5 copies of old logs, compressing old logs after a certain amount of time.

### Vector (Aggregator) Gateway

`templates/aggregator/aggregator-configmap.yaml`:`data.'vector-aggregator.yaml'`

The gateway is configured as a Vector Aggregator to source from other Vector instances (the collector agents), add a timestamp (if missing), then send to our common ElasticSearch instance (credentials and some config coming from secrets).

Additional configmaps could be added to the `vector.existingConfigMaps` array in the `values.yaml`. See the [multiple file configuration documentation in Vector](https://vector.dev/docs/reference/configuration/#multiple-files)

#### Elasticsearch Output

The aggregator config map configures the ElasticSearch sink with the following notable options (most values are injected via chart values or environment variables):

- `enpoints`: `{{ .Values.host }}` and `Port`: `9200` — Elasticsearch endpoint (host supplied by values).
- `auth.{user,password}`: provided via volume mounted secrets (from `values.vector.secret.backend_env`). They are mounted from a pre-deployed secret in OpenShift, named `elastic-credentials`, with the keys `username` and `password`.
- `Index`: Index written to in Elastic. Takes a single prefix from `.Values.prefix`, appends a per application `app_name` from parameters supplied to each collector, then postfixes with `%Y.%m` date.
  > [!IMPORTANT]
  > As of `0.6.0`, the `Logstash_DateFormat` is set to `%Y.%m` to avoid daily index rotation. Daily rotation created [oversharding issues in our Elasticsearch cluster](https://www.elastic.co/docs/deploy-manage/production-guidance/optimize-performance/size-shards).
- `buffer.{max_size,type}`: memory buffer for the Elasticsearch sink to improve throughput.

These output settings are tuned to avoid HTTP client buffer overflow and to preserve log timestamps for correct indexing.
