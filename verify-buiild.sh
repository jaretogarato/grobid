#!/bin/bash

echo "Cleaning previous builds..."
./gradlew clean

echo "Building project..."
./gradlew :grobid-service:shadowJar --info

echo "Checking generated JAR..."
JAR_FILE=$(find grobid-service/build/libs/ -name "*-onejar.jar")
if [ -f "$JAR_FILE" ]; then
    echo "Found JAR: $JAR_FILE"
    echo "Checking manifest..."
    jar tvf "$JAR_FILE" | grep MANIFEST
    echo "Extracting and displaying manifest..."
    jar xf "$JAR_FILE" META-INF/MANIFEST.MF
    cat META-INF/MANIFEST.MF
else
    echo "ERROR: JAR file not found!"
    exit 1
fi