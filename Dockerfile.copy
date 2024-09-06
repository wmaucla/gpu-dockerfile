
# Ubuntu 22.04 is latest LTS version
ARG ARCH=x86_64
ARG UBUNTU_VERSION=22.04
ARG POETRY_VERSION=1.7.1
ARG PYTHON_VERSION=3.11.9
ARG PIPX_VERSION=1.2.0
ARG MAMBA_VERSION=23.3.1-1
ARG CUDA_VERSION=12.6.1
# Tensorflow
# ARG CUDA_IMAGE_TYPE=devel
# Pytorch
ARG CUDA_IMAGE_TYPE=runtime
ARG CUDNN_VERSION=8
ARG CONDA_DIR=/opt/conda
ARG CONDA_ENV=app

#####################
# Download Pipx Layer
#####################
FROM ubuntu:${UBUNTU_VERSION} as pipx-base
ARG PIPX_VERSION

WORKDIR /tmp

# Install deps
RUN apt-get update && \
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  curl \
  ca-certificates

# Download Pipx
RUN curl -fsSL -O https://github.com/pypa/pipx/releases/download/${PIPX_VERSION}/pipx.pyz

##################
# Mamba Layer
##################
FROM condaforge/mambaforge:${MAMBA_VERSION} as installer-base
ARG CONDA_DIR
ARG CONDA_ENV
ARG PYTHON_VERSION

RUN mamba create -n "${CONDA_ENV}" \
  && mamba install -y -n "${CONDA_ENV}" -c conda-forge "python=${PYTHON_VERSION}" \
  cython \
  # Instances are Intel-CPU machines, so add extra optimizations
  mkl \
  mkl-include \
  # Below 2 are included in miniconda base, but not mamba so need to install
  conda-content-trust \
  charset-normalizer \
  # Verify Python is installed
  && python --version \
  # Clean conda dependencies
  && mamba clean -afy \
  # Clean unnecessary compiled python artifacts
  && find ${CONDA_DIR} -follow -type f -name '*.a' -delete \
  && find ${CONDA_DIR} -follow -type f -name '*.pyc' -delete \
  && find ${CONDA_DIR} -follow -type d -name '__pycache__' -delete

##################
# Base Layer
##################
# FROM nvidia/cuda:${CUDA_VERSION}-cudnn${CUDNN_VERSION}-${CUDA_IMAGE_TYPE}-ubuntu${UBUNTU_VERSION} as base
FROM nvidia/cuda:${CUDA_VERSION}-${CUDA_IMAGE_TYPE}-ubuntu${UBUNTU_VERSION} as base
ARG POETRY_VERSION
ARG CONDA_DIR
ARG CONDA_ENV

# Set locale
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# Recommended for running python apps in containers
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1

# Pipx Configuration
ENV PIPX_BIN_DIR=/usr/local/bin
ENV PIPX_HOME=/opt/pipx

# Set Default Poetry Environment Variables
ENV POETRY_VIRTUALENVS_IN_PROJECT=1
ENV POETRY_VIRTUALENVS_CREATE=1
ENV POETRY_MAX_INSTALL_WORKERS=10
# remove when https://github.com/python-poetry/poetry/issues/9185 is fixed
ENV POETRY_SOLVER_LAZY_WHEEL=false

# Install base deps
RUN apt-get update && \
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ca-certificates && \
  rm -rf /var/lib/apt/lists/*

# Grab Conda and set env path
COPY --from=installer-base ${CONDA_DIR}/envs/${CONDA_ENV} ${CONDA_DIR}/envs/${CONDA_ENV}
ENV PATH=${CONDA_DIR}/envs/${CONDA_ENV}/bin:$PATH

# Grab pipx zipapp
COPY --from=pipx-base /tmp/pipx.pyz /tmp/pipx.pyz

# Download pipx and install poetry
RUN mkdir --parents ${PIPX_HOME} \
  && python /tmp/pipx.pyz install pipx \
  && rm /tmp/pipx.pyz \
  && pipx install poetry=="${POETRY_VERSION}" \
  && poetry --version

# ================================================================
# Builder Image
# adds python project files
# ================================================================
FROM base as prod
ARG PROJECT_NAME=ml-gpu-test

WORKDIR /opt/${PROJECT_NAME}
# ENV VIRTUAL_ENV=/opt/${PROJECT_NAME}/venv

COPY pyproject.toml .
COPY poetry.lock .

RUN poetry install

COPY ltr.py .