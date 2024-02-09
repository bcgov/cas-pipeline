{{/*
Expand the name of the chart.
*/}}
{{- define "terraform-job.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "terraform-job.fullname" -}}
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
{{- define "terraform-job.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "terraform-job.labels" -}}
helm.sh/chart: {{ include "terraform-job.chart" . }}
{{ include "terraform-job.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "terraform-job.selectorLabels" -}}
app.kubernetes.io/name: {{ include "terraform-job.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "terraform-job.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "terraform-job.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Creates an list of files with thier base64 values from a given directory
*/}}
{{- define "terraform-job." -}}
{{- range $path, $data := .Files.Glob "{{ .Values.terraform.moduleDirectory }}/**.tf" }}
{{ $path | base | indent 2 }}: >-
{{- $data | toString | b64enc | nindent 4 }}
{{ end }}
{{ end }}