# The whole image is the one static binary: no shell, no package manager, no operating-system packages.
FROM scratch
COPY bin/app /app
USER 10001
ENTRYPOINT ["/app"]
