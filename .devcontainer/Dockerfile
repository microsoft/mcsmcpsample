FROM mcr.microsoft.com/devcontainers/python:3.12-bookworm

# Configure npm to use Microsoft CFS-protected internal feed
ENV npm_config_registry=https://packagefeedproxy.microsoft.io/npm/
RUN echo "registry=https://packagefeedproxy.microsoft.io/npm/" > /etc/npmrc

# Configure pip to use the Microsoft CFS-protected internal feed
ENV PIP_INDEX_URL=https://packagefeedproxy.microsoft.io/pypi/simple
ENV UV_DEFAULT_INDEX=https://packagefeedproxy.microsoft.io/pypi/simple
ENV UV_SYSTEM_CERTS=true

# Configure NuGet to use the Microsoft CFS-protected internal feed
RUN mkdir -p /home/vscode/.nuget/NuGet \
	&& printf '%s\n' \
		'<?xml version="1.0" encoding="utf-8"?>' \
		'<configuration>' \
		'  <packageSources>' \
		'    <clear />' \
		'    <add key="MicrosoftPackageFeedProxy" value="https://packagefeedproxy.microsoft.io/nuget/v3/index.json" protocolVersion="3" />' \
		'  </packageSources>' \
		'</configuration>' \
		> /home/vscode/.nuget/NuGet/NuGet.Config \
	&& chown -R vscode:vscode /home/vscode/.nuget

ENV PATH=/home/vscode/.dotnet/tools:${PATH}

RUN pipx install uv==0.12.18
