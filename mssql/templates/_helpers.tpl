{{/*
Expand the name of the chart.
*/}}
{{- define "mssql.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "mssql.fullname" -}}
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
{{- define "mssql.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "mssql.labels" -}}
helm.sh/chart: {{ include "mssql.chart" . }}
{{ include "mssql.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "mssql.selectorLabels" -}}
app.kubernetes.io/name: {{ include "mssql.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "mssql.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "mssql.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Determine the correct external-secrets API version based on cluster capabilities
*/}}
{{- define "mssql.externalSecretsApiVersion" -}}
{{- if and .Capabilities .Capabilities.APIVersions -}}
{{- if .Capabilities.APIVersions.Has "external-secrets.io/v1" -}}
external-secrets.io/v1
{{- else if .Capabilities.APIVersions.Has "external-secrets.io/v1beta1" -}}
external-secrets.io/v1beta1
{{- else -}}
external-secrets.io/v1
{{- end -}}
{{- else -}}
{{- if and .Values .Values.externalSecretsApiVersion -}}
{{- .Values.externalSecretsApiVersion -}}
{{- else -}}
external-secrets.io/v1
{{- end -}}
{{- end -}}
{{- end }}
