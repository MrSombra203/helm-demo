{{/*
Return the chart name, allowing a shorter release name when configured.
*/}}
{{- define "helm-demo.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Return a stable resource name, respecting Kubernetes' 63-character limit.
*/}}
{{- define "helm-demo.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Common labels for all chart resources.
*/}}
{{- define "helm-demo.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
{{ include "helm-demo.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/*
Labels used by the Deployment selector and its Pods.
*/}}
{{- define "helm-demo.selectorLabels" -}}
app.kubernetes.io/name: {{ include "helm-demo.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
