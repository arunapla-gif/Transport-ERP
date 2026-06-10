const express = require('express');
const router = express.Router();

router.get('/:gstNo', async (req, res) => {
  try {
    const { gstNo } = req.params;
    const keySecret = process.env.APPYFLOW_KEY_SECRET || '7eWP3WelRNexYGJ172L3Hb8JNrY2';
    
    const response = await fetch(`https://appyflow.in/api/verifyGST?gstNo=${gstNo}&key_secret=${keySecret}`);
    const data = await response.json();
    
    if (data.error) {
      return res.status(400).json(data);
    }
    
    res.json(data);
  } catch (error) {
    res.status(500).json({ error: error.message || 'Failed to verify GST' });
  }
});

module.exports = router;
