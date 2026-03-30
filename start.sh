#!/bin/sh
echo "Starting Metabase..."
# Use the port provided by Render
java -jar metabase.jar --port $PORT