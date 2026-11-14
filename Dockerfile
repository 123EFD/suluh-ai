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

# Install Python packages using uv as root before switching user (ensures write permissions and layer caching)
WORKDIR /app
COPY requirements.txt /app/requirements.txt
RUN uv pip install --system --no-cache -r /app/requirements.txt --extra-index-url https://download.pytorch.org/whl/cpu

# Hugging Face requires apps to run as a non-root user for security
RUN useradd -m -u 1000 user
ENV HOME=/home/user \
    PATH=/home/user/.local/bin:$PATH

# Copy files and set ownership
COPY --chown=user:user . /app
RUN sed -i -e 's/\r$//' /app/start.sh && chmod +x /app/start.sh
RUN mkdir -p /app/uploads && chown -R user:user /app/uploads

USER user

# Expose the Hugging Face port
EXPOSE 7860

# Run the startup script!
CMD ["./start.sh"]
