{{/*
════════════════════════════════════════════════════════════
MediMesh — Helm Chart Helper Templates
════════════════════════════════════════════════════════════
*/}}

{{/*
Chart name
*/}}
{{- define "medimesh.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Fully qualified app name
*/}}
{{- define "medimesh.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- printf "%s" $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
Chart label
*/}}
{{- define "medimesh.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "medimesh.labels" -}}
helm.sh/chart: {{ include "medimesh.chart" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
MongoDB connection string builder
*/}}
{{- define "medimesh.mongoUri" -}}
{{- $mongodb := .Values.mongodb -}}
{{- $replicas := int $mongodb.replicas -}}
{{- $hosts := list -}}
{{- range $i := until $replicas -}}
{{- $hosts = append $hosts (printf "%s-%d.%s:%d" $mongodb.name $i $mongodb.name (int $mongodb.containerPort)) -}}
{{- end -}}
mongodb://{{ join "," $hosts }}/{{ .dbName }}?replicaSet={{ $mongodb.replicaSetName }}
{{- end }}
