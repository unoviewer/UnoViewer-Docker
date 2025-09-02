# See https://aka.ms/customizecontainer to learn how to customize your debug container and how Visual Studio uses this Dockerfile to build your images for faster debugging.

# This stage is used when running from VS in fast mode (Default for Debug configuration)
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS base
USER $APP_UID
WORKDIR /app
EXPOSE 8080

# FONT
USER root
RUN apt-get update && apt-get --fix-broken install -y \
	wget \
	dpkg \
	cabextract \
	xfonts-utils \
	fontconfig \
	libfontconfig1 \
	libc6-dev \
	libfreetype6

RUN wget http://ftp.de.debian.org/debian/pool/contrib/m/msttcorefonts/ttf-mscorefonts-installer_3.8_all.deb 
RUN dpkg -i ttf-mscorefonts-installer_3.8_all.deb

RUN echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true | debconf-set-selections
RUN apt-get install ttf-mscorefonts-installer

# refresh system font cache
RUN fc-cache -f -s -v

# This stage is used to build the service project
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
ARG BUILD_CONFIGURATION=Release
WORKDIR /src
COPY ["UnoViewer-Docker.csproj", "."]
RUN dotnet restore "./UnoViewer-Docker.csproj"

# COPY REF DLLs
COPY ["REFERENCE_DLL/Uno.Files.Options.Net.Standard.2.0.dll", "."]
COPY ["REFERENCE_DLL/Uno.Files.Extensions.Net.Standard.2.0.dll", "."]
COPY ["REFERENCE_DLL/Uno.Files.Viewer.Net.Standard.2.0.dll", "."]

COPY . .
WORKDIR "/src/."
RUN dotnet build "./UnoViewer-Docker.csproj" -c $BUILD_CONFIGURATION -o /app/build

# This stage is used to publish the service project to be copied to the final stage
FROM build AS publish
ARG BUILD_CONFIGURATION=Release
RUN dotnet publish "./UnoViewer-Docker.csproj" -c $BUILD_CONFIGURATION -o /app/publish /p:UseAppHost=false

# This stage is used in production or when running from VS in regular mode (Default when not using the Debug configuration)
FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "UnoViewer-Docker.dll"]