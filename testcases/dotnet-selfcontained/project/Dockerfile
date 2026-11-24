# A self-contained app needs only the native libraries the runtime links against, which runtime-deps provides.
FROM mcr.microsoft.com/dotnet/runtime-deps:6.0
COPY bin/publish /app
USER 10001
ENTRYPOINT ["/app/LegacyApp"]
