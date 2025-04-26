# First stage: build the Dart Frog server
FROM dart:stable AS build

WORKDIR /app

# Copy all source files into the container
COPY . .

# Install dependencies
RUN dart pub get

# Generate server entrypoint
RUN dart pub global activate dart_frog_cli && \
    dart_frog build

# Compile the Dart Frog server to native executable
RUN dart compile exe build/bin/server.dart -o bin/server

# Second stage: create minimal runtime image
FROM scratch

# Copy Dart runtime and compiled server from build stage
COPY --from=build /runtime/ /
COPY --from=build /app/bin/server /app/bin/

# Expose port used by Dart Frog
EXPOSE 8080

# Run the compiled server
CMD ["/app/bin/server"]
