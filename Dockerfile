# Use Node.js LTS base image
FROM node:18

WORKDIR /app

# Copy package files and install dependencies
COPY package*.json ./
RUN npm install --force

COPY . .

EXPOSE 5000

# Start the server
CMD ["npm", "start"]
