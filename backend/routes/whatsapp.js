const express = require('express');
const axios = require('axios');
const router = express.Router();

// META CLOUD API CONFIGURATION
// These will eventually live in your .env file
const WA_PHONE_NUMBER_ID = process.env.WA_PHONE_NUMBER_ID; 
const WA_ACCESS_TOKEN = process.env.WA_ACCESS_TOKEN;

// Route to send a WhatsApp Message using Meta API
router.post('/send', async (req, res) => {
  try {
    const { phone, templateName, variables } = req.body;

    // Remove any + or spaces from the phone number
    const cleanPhone = phone.replace(/[^0-9]/g, '');

    const url = `https://graph.facebook.com/v19.0/${WA_PHONE_NUMBER_ID}/messages`;
    
    // Standard payload for sending a template message via Meta Cloud API
    const payload = {
      messaging_product: "whatsapp",
      to: cleanPhone,
      type: "template",
      template: {
        name: templateName, // The name of the template approved in Meta (e.g., 'gc_generated')
        language: { code: "en" }, // Language code of your template
        components: [
          {
            type: "body",
            parameters: variables // Array of variables: [{ type: "text", text: "GC-1001" }, ...]
          }
        ]
      }
    };

    const response = await axios.post(url, payload, {
      headers: { 
        'Authorization': `Bearer ${WA_ACCESS_TOKEN}`,
        'Content-Type': 'application/json'
      }
    });

    res.json({ success: true, data: response.data });

  } catch (error) {
    console.error('WhatsApp API Error:', error.response?.data || error.message);
    res.status(500).json({ 
      success: false, 
      message: 'Failed to send WhatsApp message',
      error: error.response?.data || error.message 
    });
  }
});

module.exports = router;
