FROM mcr.microsoft.com/devcontainers/python:3.12-bookworm

# Configure npm to use Microsoft CFS-protected internal feed
ENV npm_config_registry=https://packagefeedproxy.microsoft.io/npm/
RUN echo "registry=https://packagefeedproxy.microsoft.io/npm/" > /etc/npmrc

# Configure pip to use the Microsoft CFS-protected internal feed
ENV PIP_INDEX_URL=https://packagefeedproxy.microsoft.io/pypi/simple
ENV UV_DEFAULT_INDEX=https://packagefeedproxy.microsoft.io/pypi/simple
ENV UV_SYSTEM_CERTS=true

RUN pipx install uv==0.12.18
