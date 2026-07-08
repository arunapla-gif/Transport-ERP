const express = require('express');
const cors = require('cors');
const multer = require('multer');
const fs = require('fs');
const path = require('path');
const os = require('os');
const { print } = require('pdf-to-printer');
const unixPrint = require('unix-print');

const app = express();
const PORT = 8181;

// Setup CORS
app.use(cors());

// Setup file upload handling (saving to a temp directory)
const upload = multer({ dest: os.tmpdir() });

console.log('--- TRANSPORT ERP LOCAL PRINT AGENT ---');
console.log(`Operating System detected: ${os.type()} (${os.platform()})`);

app.post('/print', upload.single('pdf'), async (req, res) => {
  if (!req.file) {
    return res.status(400).json({ success: false, message: 'No PDF file provided.' });
  }

  const filePath = req.file.path;
  const fileName = req.file.originalname || 'document.pdf';
  // Give the file a .pdf extension temporarily for printers to recognize it
  const tempPdfPath = path.join(os.tmpdir(), `temp_print_${Date.now()}.pdf`);
  
  try {
    // Rename/move file to have .pdf extension
    fs.renameSync(filePath, tempPdfPath);
    console.log(`\n[${new Date().toLocaleTimeString()}] Received Print Request: ${fileName}`);
    console.log(`Sending to default hardware printer...`);

    const platform = os.platform();

    if (platform === 'win32') {
      // Windows Printing
      await print(tempPdfPath);
      console.log('✅ Print job sent successfully (Windows).');
    } else if (platform === 'darwin' || platform === 'linux') {
      // Mac / Linux Printing
      await unixPrint.print(tempPdfPath);
      console.log('✅ Print job sent successfully (Mac/Linux).');
    } else {
      throw new Error(`Unsupported OS: ${platform}`);
    }

    res.json({ success: true, message: 'Print job sent successfully!' });

  } catch (error) {
    console.error('❌ Failed to print:', error);
    res.status(500).json({ success: false, message: error.message });
  } finally {
    // Clean up temp file after 10 seconds
    setTimeout(() => {
      if (fs.existsSync(tempPdfPath)) {
        fs.unlinkSync(tempPdfPath);
      }
    }, 10000);
  }
});

app.get('/status', (req, res) => {
  res.json({ status: 'online', os: os.platform() });
});

app.listen(PORT, () => {
  console.log(`\n🚀 Print Agent is running on http://localhost:${PORT}`);
  console.log(`Keep this window open in the background to enable silent printing from the ERP.\n`);
});
