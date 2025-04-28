FROM python:3.11-slim

# Variável de ambiente para habilitar a autoinstrumentação
ENV OTEL_PYTHON_AUTO_INSTRUMENTATION_ENABLED=true

WORKDIR /app

# Instalar dependências
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Instalar também os pacotes de auto-instrumentação
RUN pip install --no-cache-dir opentelemetry-distro opentelemetry-instrumentation

COPY app app

# Comando ajustado para iniciar o app usando o OpenTelemetry
CMD ["opentelemetry-instrument", "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]

