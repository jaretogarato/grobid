FROM openjdk:17-jdk-slim AS builder

USER root

# Install necessary tools
RUN apt-get update && \
    apt-get -y upgrade && \
    apt-get -y --no-install-recommends install unzip curl

WORKDIR /opt/grobid-source

# Copy build files first
COPY gradle/ ./gradle/
COPY gradlew ./
COPY gradle.properties ./
COPY build.gradle ./
COPY settings.gradle ./

# Make gradlew executable
RUN chmod +x ./gradlew

# Copy source directories
COPY grobid-home/ ./grobid-home/
COPY grobid-core/ ./grobid-core/
COPY grobid-service/ ./grobid-service/
COPY grobid-trainer/ ./grobid-trainer/

# Build the service jar
RUN ./gradlew clean :grobid-service:shadowJar --no-daemon --info --stacktrace

# Runtime stage
FROM openjdk:17-slim

RUN apt-get update && \
    apt-get -y upgrade && \
    apt-get -y --no-install-recommends install libxml2 libfontconfig curl && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /opt/grobid

# Copy the jar and grobid-home
COPY --from=builder /opt/grobid-source/grobid-service/build/libs/grobid-service-*-onejar.jar /opt/grobid/grobid-service.jar
COPY --from=builder /opt/grobid-source/grobid-home /opt/grobid/grobid-home

# Environment setup
ENV GROBID_HOME=/opt/grobid/grobid-home
ENV PORT=8070
ENV JAVA_OPTS="-Xmx2g"

# Create startup script with debug output
RUN echo '#!/bin/sh\n\
echo "Starting GROBID service..."\n\
echo "GROBID_HOME=$GROBID_HOME"\n\
echo "PORT=$PORT"\n\
echo "Java version:"\n\
java -version\n\
echo "Starting Java application..."\n\
java $JAVA_OPTS -jar /opt/grobid/grobid-service.jar server /opt/grobid/grobid-home/config/grobid.yaml\n'\
> /opt/grobid/start.sh && chmod +x /opt/grobid/start.sh

EXPOSE 8070

# The command that will run
CMD ["/opt/grobid/start.sh"]

### Docker GROBID image

### See https://grobid.readthedocs.io/en/latest/Grobid-docker/

## -------------------
## Build builder image
## -------------------
#	FROM openjdk:17-jdk-slim AS builder

#	USER root

#	# Install necessary tools
#	RUN apt-get update && \
#			apt-get -y upgrade && \
#			apt-get -y --no-install-recommends install unzip

#	WORKDIR /opt/grobid-source

#	# Gradle and build configurations
#	COPY gradle/ ./gradle/
#	COPY gradlew ./
#	COPY gradle.properties ./
#	COPY build.gradle ./
#	COPY settings.gradle ./

#	# Source files
#	COPY grobid-home/ ./grobid-home/
#	COPY grobid-core/ ./grobid-core/
#	COPY grobid-service/ ./grobid-service/
#	COPY grobid-trainer/ ./grobid-trainer/

#	# Build the project
#	RUN ./gradlew clean assemble --no-daemon --info --stacktrace

#	# Debug: Confirm that the JAR file is in place
#	RUN find ./grobid-service/build/libs/

#	# Copy the JAR file explicitly
#	COPY grobid-service/build/libs/grobid-service-0.8.2-SNAPSHOT-onejar.jar app.jar
#	RUN ls -lh app.jar && \
#    jar tf app.jar | grep META-INF/MANIFEST.MF && \
#    jar xf app.jar META-INF/MANIFEST.MF && \
#    cat META-INF/MANIFEST.MF

#	# Clean up unnecessary files
#	RUN rm -rf grobid-home/pdf2xml
#	RUN rm -rf grobid-home/pdfalto/lin-32
#	RUN rm -rf grobid-home/pdfalto/mac-64
#	RUN rm -rf grobid-home/pdfalto/mac_arm-64
#	RUN rm -rf grobid-home/pdfalto/win-*
#	RUN rm -rf grobid-home/lib/lin-32
#	RUN rm -rf grobid-home/lib/win-*
#	RUN rm -rf grobid-home/lib/mac-64

#	# Remove unused models
#	RUN rm -rf grobid-home/models/*-BidLSTM_CRF*

#	# Set environment variables
#	ENV GROBID_SERVICE_OPTS="-Djava.library.path=grobid-home/lib/lin-64:grobid-home/lib/lin-64/jep"

#	# -------------------
#	# Build runtime image
#	# -------------------
#	FROM openjdk:17-slim

#	# Install runtime dependencies
#	RUN apt-get update && \
#			apt-get -y upgrade && \
#			apt-get -y --no-install-recommends install libxml2 libfontconfig && \
#			rm -rf /var/lib/apt/lists/*

#	# Add Tini for process management
#	ENV TINI_VERSION=v0.19.0
#	ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /tini
#	RUN chmod +x /tini

#	# Set entry point using Tini
#	ENTRYPOINT ["/tini", "-s", "--", "java", "-Dserver.port=8070", "-jar", "app.jar"]

#	WORKDIR /opt/grobid

#	# Copy the built files from the builder stage
#	COPY --from=builder /opt/grobid-source .

#	# Expose the application port
#	EXPOSE 8070

#	# Set environment variables for runtime
#	ENV GROBID_SERVICE_OPTS="-Djava.library.path=grobid-home/lib/lin-64:grobid-home/lib/lin-64/jep --add-opens java.base/java.lang=ALL-UNNAMED --add-opens java.base/sun.nio.ch=ALL-UNNAMED --add-opens java.base/java.io=ALL-UNNAMED"

#	# Set the default command to start the GROBID service
#	CMD ["./grobid-service/bin/grobid-service"]

#	# Optional metadata
#	ARG GROBID_VERSION

#	LABEL \
#			authors="The contributors" \
#			org.label-schema.name="GROBID" \
#			org.label-schema.description="Image with GROBID service" \
#			org.label-schema.url="https://github.com/kermitt2/grobid" \
#			org.label-schema.version=${GROBID_VERSION}
