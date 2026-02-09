# performance metric merging service
# handles -march= / -mtune= architecture-specific distribution

FROM python:3.13-slim

RUN apt-get update                             \
&&  apt-get install -y --no-install-recommends \
    binutils                                   \
    gcc                                        \
    g++                                        \
    git                                        \
    libc6-dev                                  \
    llvm                                       \
&&  rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir \
    cython                     \
    fastapi                    \
    python-multipart           \
    setuptools                 \
    uvicorn

COPY . /app
WORKDIR /app
ENV SETUPTOOLS_SCM_PRETEND_VERSION_FOR_IA=0.0.0

ENV PYTHONPATH="/app"
RUN pip install --no-cache-dir .

ENTRYPOINT ["python", "-u", "-m", "performance_metric_merging_service"]
