const express = require('express');
const { connectToNetwork, checkNetworkConfig, channelName } = require('../utils/fabric');

const router = express.Router();

// Get network information
router.get('/info', async (req, res) => {
  try {
    const { gateway } = await connectToNetwork('admin');

    // Get the network
    const network = await gateway.getNetwork(channelName);

    // Get basic network information
    const networkInfo = {
      channelName: channelName,
      gatewayConnected: true
    };

    // Disconnect from the gateway
    await gateway.disconnect();

    res.json(networkInfo);
  } catch (error) {
    console.error(`Failed to get network info: ${error}`);
    res.status(500).json({
      error: error.message,
      channelName: channelName,
      gatewayConnected: false
    });
  }
});

// Get installed chaincodes
router.get('/chaincodes', async (req, res) => {
  try {
    const { gateway } = await connectToNetwork('admin');

    // Return a basic chaincode list
    // In a production environment, you would query the actual list
    const chaincodes = [
      { id: 'basic', name: 'basic', version: '1.0', description: 'Basic Asset Transfer' }
    ];

    // Disconnect from the gateway
    await gateway.disconnect();

    res.json(chaincodes);
  } catch (error) {
    console.error(`Failed to get chaincodes: ${error}`);
    res.status(500).json({ error: error.message });
  }
});

// Health check endpoint
router.get('/health', async (req, res) => {
  try {
    // First check if network configuration is valid
    const configCheck = await checkNetworkConfig();
    if (!configCheck.success) {
      return res.status(503).json({
        status: 'error',
        message: configCheck.message,
        timestamp: new Date().toISOString()
      });
    }

    // Try to connect to the network
    const { gateway } = await connectToNetwork('admin');

    // Get the network
    await gateway.getNetwork(channelName);

    // If we got here, the connection is working
    await gateway.disconnect();

    res.json({
      status: 'ok',
      message: 'Successfully connected to the Fabric network',
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    console.error(`Health check failed: ${error}`);
    res.status(503).json({
      status: 'error',
      message: 'Failed to connect to the Fabric network',
      error: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

module.exports = router;
