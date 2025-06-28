# Use a base image with bash and curl
FROM ubuntu:22.04

# Install dependencies
RUN apt update && apt install -y curl bash git sudo

# Copy and run your setup script
RUN curl -sSL https://raw.githubusercontent.com/NIRAVDEV/panel/main/panel.sh -o panel.sh && \
    chmod +x panel.sh && \
    bash panel.sh

# Default port for your panel (adjust if needed)
EXPOSE 8080

# Start your panel (replace with actual command, e.g., `npm run start`)
CMD ["bash"]
