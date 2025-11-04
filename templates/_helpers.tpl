{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "wxd-dev-edition-chat.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "wxd-dev-edition-chat.fullname" -}}
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
{{- define "wxd-dev-edition-chat.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "wxd-dev-edition-chat.labels" -}}
helm.sh/chart: {{ include "wxd-dev-edition-chat.chart" . }}
{{ include "wxd-dev-edition-chat.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "wxd-dev-edition-chat.selectorLabels" -}}
app.kubernetes.io/name: {{ include "wxd-dev-edition-chat.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Base64 decode a value
*/}}
{{- define "wxd-dev-edition-chat.base64Decode" -}}
{{- $value := index . 0 -}}
{{- $b64dec := index . 1 | default false -}}
{{- if $b64dec -}}
{{- $value | b64dec -}}
{{- else -}}
{{- $value -}}
{{- end -}}
{{- end -}}

{{/*
Base64 encode a value
*/}}
{{- define "wxd-dev-edition-chat.base64Encode" -}}
{{- $value := index . 0 -}}
{{- $b64enc := index . 1 | default false -}}
{{- if $b64enc -}}
{{- $value | b64enc -}}
{{- else -}}
{{- $value -}}
{{- end -}}
{{- end -}}