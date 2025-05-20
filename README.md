# IoT Security System

A comprehensive IoT-based security monitoring system that captures images from IoT devices, stores them securely in the cloud, and sends real-time notifications to connected mobile devices.

## Project Overview

This project consists of two main components:

1. **Backend Server**: Node.js/Express application that handles image uploads, storage, and push notifications
2. **Mobile App**: Flutter-based mobile application for viewing captured images and receiving real-time alerts

The system is designed for home security, allowing users to monitor their premises remotely through captured images from IoT devices like Raspberry Pi cameras or ESP32-CAM modules.

## Features

### Backend Features

- Secure image upload and cloud storage using Cloudinary
- Push notifications using Firebase Cloud Messaging
- MongoDB database for storing image metadata and device information
- RESTful API endpoints for image retrieval and device management
- Real-time notification delivery when new security images are captured
- Containerized deployment with Docker support

### Frontend Features

- Real-time notifications when new security images are detected
- Image gallery to view all captured security images
- Image zoom and detailed view capabilities
- Background notification processing
- Secure device registration with the backend
- Persistent settings and preferences
- Responsive UI design for various device sizes

## Technology Stack

### Backend
- **Node.js & Express.js**: Server framework
- **MongoDB**: Database for storing image metadata and device tokens
- **Firebase Cloud Messaging**: For sending push notifications
- **Cloudinary**: Cloud storage for captured images
- **Multer**: Handling multipart/form-data for image uploads
- **Docker**: Containerization for easy deployment

### Frontend
- **Flutter**: Cross-platform mobile app framework
- **Dart**: Programming language for Flutter
- **Firebase Messaging**: For receiving push notifications
- **Flutter Local Notifications**: For displaying notifications
- **HTTP Package**: For API communication
- **Cached Network Image**: For efficient image loading and caching
- **Photo View**: For image zooming capabilities
- **Shared Preferences**: For local storage of settings
- **Workmanager**: For background tasks
- **Shimmer**: For loading animations

## Setup Instructions

### Backend Setup

1. Navigate to the backend directory:
   ```bash
   cd backend
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Set up environment variables in `.env`:
   ```env
   CLOUDINARY_CLOUD_NAME=your_cloud_name
   CLOUDINARY_API_KEY=your_api_key
   CLOUDINARY_API_SECRET=your_api_secret
   MONGODB_URI=your_mongodb_uri
   PORT=3000 # or your preferred port
   ```

4. Add your Firebase service account key file as `firebase-service-account.json` in the backend directory

5. Start the server:
   ```bash
   npm start
   ```

## Docker Setup

The backend service can be easily deployed using Docker:

1. Navigate to the backend directory:
   ```bash
   cd backend
   ```

2. Build the Docker image:
   ```bash
   docker build -t iot-security-backend .
   ```

3. Run the Docker container:
   ```bash
   docker run -p 5000:5000 --env-file .env iot-security-backend
   ```
   
   This command:
   - Maps port 5000 of the container to port 5000 on your host machine
   - Uses environment variables from your local `.env` file

4. Access the API at `http://localhost:5000`

### Docker Environment

- The Docker container is based on Node.js 18
- Exposes port 5000 by default
- Requires the same environment variables as the non-Docker setup

### Frontend Setup

1. Navigate to the frontend directory:
   ```bash
   cd frontend
   ```

2. Install Flutter dependencies:
   ```bash
   flutter pub get
   ```

3. Configure the backend API URL in the app:
   - Open `lib/main.dart` or your configuration file
   - Update the API endpoint to your backend server address

4. Set up Firebase:
   - Add your `google-services.json` to the Android app directory
   - Configure Firebase messaging in your Flutter app

5. Run the app:
   ```bash
   flutter run
   ```

## Environment Configuration

### Backend Environment Variables

Create a `.env` file in the backend directory with the following variables:

| Variable | Description | Required for Docker |
|----------|-------------|-------------------|
| CLOUDINARY_CLOUD_NAME | Your Cloudinary cloud name | Yes |
| CLOUDINARY_API_KEY | Cloudinary API key | Yes |
| CLOUDINARY_API_SECRET | Cloudinary API secret | Yes |
| MONGODB_URI | MongoDB connection string | Yes |
| PORT | Server port (default: 3000 for local, 5000 for Docker) | Yes |

**Note on PORT configuration:**

- For local development without Docker, the default port is 3000
- For Docker deployments, the container exposes port 5000 by default
- If you modify the PORT in your Docker environment, make sure to update your `docker run` command accordingly

### Using Environment Variables with Docker

You can pass environment variables to the Docker container in several ways:

1. Using an env file:
   ```bash
   docker run -p 5000:5000 --env-file .env iot-security-backend
   ```

2. Directly in the command:
   ```bash
   docker run -p 5000:5000 -e MONGODB_URI=mongodb://uri -e PORT=5000 iot-security-backend
   ```

### Frontend Configuration

Update the API base URL in your Flutter app to point to your deployed backend server.

## API Endpoints

### Image Management
- `POST /upload` - Upload a new security image
- `GET /upload/latest` - Get the latest uploaded image
- `GET /upload/all` - Get all images (limited to 15)

### Device Registration
- `POST /upload/register-device` - Register a mobile device for push notifications

## Deployment

### Backend Deployment
The backend includes a Dockerfile for containerized deployment. You can deploy it using:

```bash
cd backend
docker build -t iot-security-backend .
docker run -p 5000:5000 --env-file .env iot-security-backend
```

For production deployment:

1. Configure appropriate environment variables for your production environment
2. Consider using Docker Compose for orchestrating the backend with other services:

```yaml
# docker-compose.yml
version: '3'
services:
  backend:
    build: ./backend
    ports:
      - "5000:5000"
    environment:
      - MONGODB_URI=your_production_mongodb_uri
      - CLOUDINARY_CLOUD_NAME=your_cloud_name
      - CLOUDINARY_API_KEY=your_api_key
      - CLOUDINARY_API_SECRET=your_api_secret
      - PORT=5000
    restart: always
```

3. Start the services:
   ```bash
   docker-compose up -d
   ```

### Mobile App Deployment
Build the Flutter app for release:

```bash
cd frontend
flutter build apk --release
# or
flutter build ios --release
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Author

Krish

---

For any questions or issues, please open an issue on the GitHub repository.
