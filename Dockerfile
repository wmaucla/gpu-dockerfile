##################
# Global Defaults
##################

# Ubuntu 22.04 is latest LTS version
ARG PROJECT_NAME=

ARG UBUNTU_VERSION=22.04
ARG ARCH=x86_64
ARG POETRY_VERSION=1.8.3
ARG PYTHON_VERSION=3.11.9
ARG CUDA_VERSION=12.6.1
# Tensorflow
# ARG CUDA_IMAGE_TYPE=devel
# Pytorch
ARG CUDA_IMAGE_TYPE=runtime
# ARG CUDNN_VERSION=8
ARG UV_PYTHON_INSTALL_DIR=/opt/python

# required on all stages..e.g. CAs and timezones should never be stale
ARG SYS_PACKAGES="ca-certificates tzdata"
ARG APP_PACKAGES=""

##################
# Base Layer
##################
FROM nvidia/cuda:${CUDA_VERSION}-${CUDA_IMAGE_TYPE}-ubuntu${UBUNTU_VERSION} as base
# FROM nvidia/cuda:12.6.1-runtime-ubuntu22.04 as base
ARG SYS_PACKAGES
ARG APP_PACKAGES
ARG UV_PYTHON_INSTALL_DIR

ENV UV_PYTHON_INSTALL_DIR=${UV_PYTHON_INSTALL_DIR}

# Set locale
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# Recommended for running python apps in containers
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1

# Set Default Poetry Environment Variables
ENV POETRY_VIRTUALENVS_IN_PROJECT=1
ENV POETRY_VIRTUALENVS_CREATE=1
ENV POETRY_MAX_INSTALL_WORKERS=$(nproc)
# remove when https://github.com/python-poetry/poetry/issues/9185 is fixed
ENV POETRY_SOLVER_LAZY_WHEEL=false

# Install base deps
RUN apt-get update && \
  apt-get install -y --no-install-recommends \
  ${SYS_PACKAGES} \
  ${APP_PACKAGES} && \
  rm -rf /var/lib/apt/lists/*

# ================================================================
# Builder Image
# - Install Python dependencies
# ================================================================
FROM base as builder
ARG PROJECT_NAME
ARG PYTHON_VERSION
ARG POETRY_VERSION

ENV PROJECT_HOME=/opt/${PROJECT_NAME}

# Necessary to run commands from the correct (UV venv) path
ENV VIRTUAL_ENV=${PROJECT_HOME}/.venv
ENV PATH="${VIRTUAL_ENV}/bin:$PATH"

WORKDIR ${PROJECT_HOME}

# Install Python and Setup virtural env
COPY --from=ghcr.io/astral-sh/uv:latest /uv /bin/uv
RUN uv venv --python "${PYTHON_VERSION}" && \
  uv pip install "poetry==${POETRY_VERSION}" && \
  python --version && \
  poetry --version

# separate caching layer for deps
COPY pyproject.toml poetry.lock ./
RUN poetry install --only main --no-root

# caching layer for root
# copy package files
# COPY src src/
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
# Install deps
RUN poetry install --only main
# Need to install GPU specific package (just use what is installed for CPU)
# Needs to support same Cuda version listed at the top of the file (Cuda 11.8)
# RUN uv pip install --no-cache-dir \
#  torchvision=="$(poetry show torchvision | grep "version" | cut -d ":" -f2 | awk '{$1=$1};1')+cu118" \
#  torch=="$(poetry show torch | grep "version" | cut -d ":" -f2 | awk '{$1=$1};1')+cu118" \
#  --index-url https://download.pytorch.org/whl/cu118

# ================================================================
# Prod Image
# only module and venv related files
# ================================================================
FROM base as prod
ARG PROJECT_NAME
ARG UV_PYTHON_INSTALL_DIR

ENV PROJECT_HOME=/opt/${PROJECT_NAME}
ENV VIRTUAL_ENV=${PROJECT_HOME}/.venv
# prefix the venv bin to the path
ENV PATH="${VIRTUAL_ENV}/bin:$PATH"

WORKDIR ${PROJECT_HOME}

COPY --from=builder ${UV_PYTHON_INSTALL_DIR} ${UV_PYTHON_INSTALL_DIR}/
COPY --from=builder ${VIRTUAL_ENV} ${VIRTUAL_ENV}/
# COPY --from=builder "${PROJECT_HOME}/src" "${PROJECT_HOME}/src/"

COPY ltr.py .

# /bin/bash -c ${VIRTUAL_ENV}/bin/activate && exec \$@\ -- python ltr.py