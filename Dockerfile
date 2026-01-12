FROM node:18-bullseye

# Set working directory
WORKDIR /app

# Copy package info dulu
COPY package*.json ./

# Install SEMUA dependencies (hapus --production agar lebih aman)
RUN npm install

# Copy sisa file
COPY . .

# Set Environment Variable
ENV PORT=3000
ENV NODE_ENV=production

# Buka Port
EXPOSE 3000

# Jalankan server
CMD ["node", "server.js"]
