{{/*
Expand the name of the chart.
*/}}
{{- define "netflow-pipeline.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "netflow-pipeline.fullname" -}}
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
{{- define "netflow-pipeline.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "netflow-pipeline.labels" -}}
helm.sh/chart: {{ include "netflow-pipeline.chart" . }}
{{ include "netflow-pipeline.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "netflow-pipeline.selectorLabels" -}}
app.kubernetes.io/name: {{ include "netflow-pipeline.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "netflow-pipeline.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "netflow-pipeline.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
GoFlow2 specific helpers
*/}}
{{- define "netflow-pipeline.goflow2.fullname" -}}
{{- printf "%s-%s" (include "netflow-pipeline.fullname" .) "goflow2" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "netflow-pipeline.goflow2.labels" -}}
{{ include "netflow-pipeline.labels" . }}
app.kubernetes.io/component: goflow2
{{- end }}

{{- define "netflow-pipeline.goflow2.selectorLabels" -}}
{{ include "netflow-pipeline.selectorLabels" . }}
app.kubernetes.io/component: goflow2
{{- end }}

{{/*
Kafka specific helpers
*/}}
{{- define "netflow-pipeline.kafka.fullname" -}}
{{- printf "%s-%s" (include "netflow-pipeline.fullname" .) "kafka" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "netflow-pipeline.kafka.labels" -}}
{{ include "netflow-pipeline.labels" . }}
app.kubernetes.io/component: kafka
{{- end }}

{{- define "netflow-pipeline.kafka.selectorLabels" -}}
{{ include "netflow-pipeline.selectorLabels" . }}
app.kubernetes.io/component: kafka
{{- end }}

{{/*
Zookeeper specific helpers
*/}}
{{- define "netflow-pipeline.zookeeper.fullname" -}}
{{- printf "%s-%s" (include "netflow-pipeline.fullname" .) "zookeeper" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "netflow-pipeline.zookeeper.labels" -}}
{{ include "netflow-pipeline.labels" . }}
app.kubernetes.io/component: zookeeper
{{- end }}

{{- define "netflow-pipeline.zookeeper.selectorLabels" -}}
{{ include "netflow-pipeline.selectorLabels" . }}
app.kubernetes.io/component: zookeeper
{{- end }}

{{/*
ClickHouse specific helpers
*/}}
{{- define "netflow-pipeline.clickhouse.fullname" -}}
{{- printf "%s-%s" (include "netflow-pipeline.fullname" .) "clickhouse" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "netflow-pipeline.clickhouse.labels" -}}
{{ include "netflow-pipeline.labels" . }}
app.kubernetes.io/component: clickhouse
{{- end }}

{{- define "netflow-pipeline.clickhouse.selectorLabels" -}}
{{ include "netflow-pipeline.selectorLabels" . }}
app.kubernetes.io/component: clickhouse
{{- end }}

{{/*
Grafana specific helpers
*/}}
{{- define "netflow-pipeline.grafana.fullname" -}}
{{- printf "%s-%s" (include "netflow-pipeline.fullname" .) "grafana" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "netflow-pipeline.grafana.labels" -}}
{{ include "netflow-pipeline.labels" . }}
app.kubernetes.io/component: grafana
{{- end }}

{{- define "netflow-pipeline.grafana.selectorLabels" -}}
{{ include "netflow-pipeline.selectorLabels" . }}
app.kubernetes.io/component: grafana
{{- end }}