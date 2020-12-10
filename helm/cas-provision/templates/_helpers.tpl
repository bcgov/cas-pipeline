{{/*
Expand the name of the chart.
*/}}
{{- define "cas-provision.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "cas-provision.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "cas-provision.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "cas-provision.labels" -}}
helm.sh/chart: {{ include "cas-provision.chart" . }}
{{ include "cas-provision.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "cas-provision.selectorLabels" -}}
app.kubernetes.io/name: {{ include "cas-provision.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "cas-provision.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "cas-provision.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Formats the dockerhub secret value
*/}}
{{- define "dockerconfigjson" }}
{{- printf "{\"auths\":{\"%s\":{\"username\":\"%s\",\"password\":\"%s\", \"auth\":\"%s\"}}}" .Values.docker.registry .Values.docker.username .Values.docker.password (printf "%s:%s" .Values.docker.username .Values.docker.password | b64enc) | b64enc }}
{{- end }}


{{/*
Gets the suffix of the namespace.
*/}}
{{- define "namespaceSuffix" }}
{{- (split "-" .Release.Namespace)._1 | trim -}}
{{- end }}

{{/*
Gets the prefix of the namespace.
*/}}
{{- define "namespacePrefix" }}
{{- (split "-" .Release.Namespace)._0 | trim -}}
{{- end }}
