const express = require('express');
const cors = require('cors');
const path = require('path');
const morgan = require('morgan');
const dotenv = require('dotenv');
const fs = require('fs');

// Load environment variables
dotenv.config();

// Import routes
const assetsRouter = require('./routes/assets');
const networkRouter = require('./routes/network');

const app = express();
// Try a different port if the default one is in use
const DEFAULT_PORT = process.env.PORT || 3000;
let PORT = DEFAULT_PORT;

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(morgan('dev'));
app.use(express.static(path.join(__dirname, 'public')));

// Routes
app.use('/api/assets', assetsRouter);
app.use('/api/network', networkRouter);

// Serve index.html for the root path
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// Start the server with port fallback logic
const server = app.listen(PORT, () => {
  console.log(`Server running on http://localhost:${PORT}`);
}).on('error', (err) => {
  if (err.code === 'EADDRINUSE') {
    // Try the next port
    PORT = DEFAULT_PORT + 1;
    console.log(`Port ${DEFAULT_PORT} is busy, trying port ${PORT}...`);
    server.close();

    // Try an alternative port
    app.listen(PORT, () => {
      console.log(`Server running on http://localhost:${PORT}`);
    }).on('error', (err) => {
      if (err.code === 'EADDRINUSE') {
        // Try one more port
        PORT = DEFAULT_PORT + 2;
        console.log(`Port ${DEFAULT_PORT + 1} is also busy, trying port ${PORT}...`);

        app.listen(PORT, () => {
          console.log(`Server running on http://localhost:${PORT}`);
        }).on('error', () => {
          console.error(`Failed to start server: All attempted ports are in use`);
        });
      }
    });
  }
});

module.exports = app;
