const mongoose = require('mongoose');

const ImageSchema = new mongoose.Schema({
  imageUrl: { type: String, required: true },
  timestamp: { type: Date, default: Date.now },
  viewed: { type: Boolean, default: false }
});

module.exports = mongoose.model('Image', ImageSchema);
 