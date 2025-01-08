# CAS Logging Sidecar

This library chart is a template used to deploy a logging sidecar to a pod. The sidecar utilizes Fluent Bit and LogRotate to capture logs from a container within OpenShift and write them to ElasticSearch. The chart includes a service account, role, and role binding that are used to grant the service account access to the logs.

## Usage

1. You will need determine the following parameters and add them into your values.yaml file (These will be under the `cas-logging-sidecar` or whatever you named the subchart in your file):

```yaml
  host: ~
  index: ~
  prefix: ~
  tag: ~
  logName: ~
```

> *Note*: These parameters are used in the configmap for Fluent Bit and Logrotate.

2. `{{- include }}` the sidecar container and volumes into your deployment file. This must be passed the following paramters: `.podToSidecar`, `.containerToSidecar`, `.logName`, `.tag`. This is done using a dict in the include statement, for example:

```yaml
spec.template.spec.containers:
{{- include "cas-logging-sidecar.containers" (dict 
    "containerToSidecar" "cas-cif-frontend"
    "logName" .Values.logName) | nindent 8 }}

spec.template.spec.volumes:
{{- include "cas-logging-sidecar.volumes" . | nindent 8 }}
```

> *Note*: You can use `.Values.abc` if you want to use the values from your values.yaml file.

3. There is no 3.

## `_logging-sidecar.yaml` Parameters list

| Parameter | Description | Example |
| --- | --- | --- |
| `"containerToSidecar"` | The container that the sidecar should log for. | `"cas-cif-frontend"` |
| `"logName"` | The name for the output logfile. **NOTE**: This must match the logname used in `values.yaml`. | `.Values.logName` |

## values.yaml list

| Value | Usage location | Description | Example |
| --- | --- | --- | --- |
| `logName` | `fluent-bit-configmap.yaml`, `logrotate-configmap.yaml` | The name for the output logfile. | `cif-frontend-log` |
| `host` | `fluent-bit-configmap.yaml` | ElasticSearch host to send logs to. | `elasticsearch.abc123-tools.svc.cluster.local` |
| `index` | `fluent-bit-configmap.yaml` | Index name. | `cif-logs` |
| `prefix` | `fluent-bit-configmap.yaml` | The index name is composed using a prefix and the date. The last string appended belongs to the date when the data is being generated. | `cif-logs` |
| `tag` | `fluent-bit-configmap.yaml` | Tag name associated to all records coming from this plugin. | `oc-cif` |


## Example use

```yaml
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
          image: cas-frontend:latest
          ports:
            - containerPort: 80
        {{- include "cas-logging-sidecar.containers" (dict 
            "containerToSidecar" .Spec.Template.Spec.Containers.0.Name
            "logName" .Values.logName
            "tag" "cas-frontend" ) | nindent 8 }}
      volumes:
        {{- include "cas-logging-sidecar.volumes" . | nindent 8 }}
```
