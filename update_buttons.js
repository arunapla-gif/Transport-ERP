const fs = require('fs');
const path = require('path');

const filesToUpdate = [
  'PrintHub.jsx', 'CewbPrint.jsx', 'GcPrint.jsx', 'GdmPrint.jsx', 'CombinedGdmPrint.jsx',
  'ConsigneeMaster.jsx', 'ConsignorMaster.jsx', 'UnitMaster.jsx', 'HSNMaster.jsx',
  'Reports.jsx', 'GovtCompliance.jsx', 'TripSettlement.jsx', 'GodownPlanner.jsx',
  'TechnologyUsage.jsx', 'SystemBoot.jsx', 'AdminDashboard.jsx', 'LegacyRapidEntry.jsx',
  'RemoteScanner.jsx', 'Login.jsx', 'LegacyViewer.jsx', 'QrDemo.jsx', 'WarehouseStatement.jsx'
];

const basePath = path.join(__dirname, 'frontend/src/pages');

filesToUpdate.forEach(filename => {
  const filepath = path.join(basePath, filename);
  if (!fs.existsSync(filepath)) {
    console.log(`Skip ${filename} (not found)`);
    return;
  }
  
  let content = fs.readFileSync(filepath, 'utf8');
  let original = content;

  // 1. Check if we need to add the import
  if (content.includes('<button') && !content.includes('import { Button }')) {
    // find the last import line
    const importRegex = /import .* from .*\n/g;
    let match;
    let lastImportIndex = 0;
    while ((match = importRegex.exec(content)) !== null) {
      lastImportIndex = match.index + match[0].length;
    }
    
    if (lastImportIndex > 0) {
      content = content.slice(0, lastImportIndex) + "import { Button } from '../components/ui/Button';\n" + content.slice(lastImportIndex);
    }
  }

  // 2. Replace <button tags
  content = content.replace(/<button /g, '<Button variant="custom" ');
  content = content.replace(/<button\n/g, '<Button variant="custom"\n');
  content = content.replace(/<button\r\n/g, '<Button variant="custom"\r\n');
  content = content.replace(/<button>/g, '<Button variant="custom">');
  
  // 3. Replace closing tags
  content = content.replace(/<\/button>/g, '</Button>');

  if (content !== original) {
    fs.writeFileSync(filepath, content, 'utf8');
    console.log(`Updated ${filename}`);
  }
});
