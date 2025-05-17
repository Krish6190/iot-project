const express = require('express');
const multer = require('multer');
const cloudinary = require('cloudinary').v2;
const { CloudinaryStorage } = require('multer-storage-cloudinary');
const Image = require('../models/Image');
const admin = require('../config/firebase');
const router = express.Router();

// Cloudinary config
cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
  api_key: process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET
});

// Multer + Cloudinary storage
const storage = new CloudinaryStorage({
  cloudinary,
  params: {
    allowed_formats: ['jpg', 'jpeg', 'png'],
  },
});

const upload = multer({ storage });

const DeviceToken = require('../models/DeviceToken');

// Register device token
router.post('/register-device', async (req, res) => {
  try {
    const { token } = req.body;
    if (!token) {
      return res.status(400).json({ message: 'Token is required' });
    }

    await DeviceToken.findOneAndUpdate(
      { token },
      { token },
      { upsert: true, new: true }
    );

    res.status(200).json({ message: 'Device registered successfully' });
  } catch (error) {
    console.error('Error registering device:', error);
    res.status(500).json({ message: 'Server error' });
  }
});
// POST /upload - Save image to Cloudinary and MongoDB
router.post('/', upload.single('image'), async (req, res) => {
  try {
    const result = req.file;

    const newImage = new Image({
      imageUrl: result.path
    });

    const savedImage = await newImage.save();

    // Send push notification to all registered devices
    const tokens = await DeviceToken.find().select('token');
    const deviceTokens = tokens.map(t => t.token);

    if (deviceTokens.length > 0) {
      const message = {
        notification: {
          title: 'New Image Captured',
          body: 'A new image has been captured and uploaded'
        },
        data: {
          imageUrl: savedImage.imageUrl,
          timestamp: savedImage.timestamp.toString()
        },
        tokens: deviceTokens
      };

      try {
        await admin.messaging().sendMulticast(message);
        console.log('Notification sent successfully');
      } catch (error) {
        console.error('Error sending notification:', error);
      }
    }
    res.status(201).json(savedImage);

  } catch (error) {
    console.error('Upload error:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// GET /upload/latest - Get latest image
router.get('/latest', async (req, res) => {
  try {
    const latestImage = await Image.findOne().sort({ timestamp: -1 });
    if (!latestImage) return res.status(404).json({ message: 'No image found' });
    
    res.json({
      imageUrl: latestImage.imageUrl,
      timestamp: latestImage.timestamp
    });

  } catch (error) {
    console.error('Error fetching latest image:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// GET /upload/all - Get up to 15 images
router.get('/all', async (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 100;
    const images = await Image.find()
      .sort({ timestamp: -1 })
      .limit(limit);

    if (!images.length) return res.status(404).json({ message: 'No images found' });
    res.json(images);

  } catch (error) {
    console.error('Error fetching images:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router;
