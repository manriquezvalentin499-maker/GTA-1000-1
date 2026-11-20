FROM debian:bookworm-slim
ARG GODOT_VERSION=4.6.3
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl unzip libgl1 libfontconfig1 libx11-6 libxcursor1 libxinerama1 libxi6 libxrandr2 libasound2 && rm -rf /var/lib/apt/lists/*
RUN curl -fsSL "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip" -o /tmp/godot.zip \
    && unzip -p /tmp/godot.zip "Godot_v${GODOT_VERSION}-stable_linux.x86_64" > /usr/local/bin/godot \
    && chmod 0755 /usr/local/bin/godot && rm /tmp/godot.zip
WORKDIR /game
COPY project.godot ./
COPY online.gd server.gd ./scripts/
COPY Server.tscn ./scenes/
ENV PORT=10000
EXPOSE 10000
CMD ["godot", "--headless", "--path", "/game"]
