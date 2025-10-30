#!/usr/bin/env node

/**
 * Standalone script to trigger ROI update manually
 * Usage: node trigger-roi-update.js
 * Or via npm: npm run update-roi
 */

require('dotenv').config();
const axios = require('axios');

const BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:3000';

async function triggerRoiUpdate() {
  console.log('🔄 Triggering manual ROI update...');
  console.log(`   Backend URL: ${BACKEND_URL}`);
  
  try {
    const response = await axios.post(`${BACKEND_URL}/api/admin/update-roi`, {}, {
      timeout: 120000, // 2 minutes timeout
    });
    
    if (response.status === 200) {
      console.log('✅ ROI update completed successfully!');
      console.log(response.data);
    } else {
      console.error('❌ ROI update failed:', response.status);
      process.exit(1);
    }
  } catch (error) {
    console.error('❌ Error triggering ROI update:');
    if (error.response) {
      console.error(`   Status: ${error.response.status}`);
      console.error(`   Data:`, error.response.data);
    } else if (error.request) {
      console.error('   No response received from backend');
      console.error('   Make sure backend is running at:', BACKEND_URL);
    } else {
      console.error('   Error:', error.message);
    }
    process.exit(1);
  }
}

// Run the update
triggerRoiUpdate()
  .then(() => {
    console.log('\n✅ Done!');
    process.exit(0);
  })
  .catch((error) => {
    console.error('\n❌ Fatal error:', error);
    process.exit(1);
  });
