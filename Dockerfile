# Use a lightweight Python Linux environment
FROM python:3.10-slim

# Copy the modern, blazing-fast uv package manager from Astral's official container
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

# Install system dependencies needed for Camelot, OpenCV, and general compiling
RUN apt-get update && apt-get install -y \
    ghostscript \
    libgl1 \
    libglib2.0-0 \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Hugging Face requires apps to run as a non-root user for security
RUN useradd -m -u 1000 user
USER user
ENV PATH="/home/user/.local/bin:$PATH"

# Set the working directory
WORKDIR /app

# Copy your files into the container
COPY --chown=user . /app

# Make the startup script executable and ensure Unix line endings
RUN sed -i -e 's/\r$//' start.sh && chmod +x start.sh

# Install Python packages using uv for 10x-100x faster layer caching & resolution
RUN uv pip install --system --no-cache -r requirements.txt --extra-index-url https://download.pytorch.org/whl/cpu

# Create the uploads folder just in case
RUN mkdir -p uploads

# Expose the Hugging Face port
EXPOSE 7860

# Run the startup script!
CMD ["./start.sh"]
