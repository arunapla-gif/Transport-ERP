const fs = require('fs');
const path = require('path');

const projectRoot = path.join(__dirname, '../frontend');
const reportsFile = path.join(projectRoot, 'src/pages/Reports.jsx');

console.log('--- Phase 3: Virtualization Automated Verification (Transport ERP) ---\n');

if (fs.existsSync(reportsFile)) {
  const content = fs.readFileSync(reportsFile, 'utf8');
  
  const checks = [
    { name: 'Import react-window (FixedSizeList)', regex: /import \{.*FixedSizeList.*\} from 'react-window'/ },
    { name: 'Import AutoSizer', regex: /import AutoSizer from 'react-virtualized-auto-sizer'/ },
    { name: 'Implementation of <AutoSizer>', regex: /<AutoSizer>/ },
    { name: 'Implementation of <List> (FixedSizeList)', regex: /<List/ },
    { name: 'Removal of legacy <table> elements', regex: /<table/, expectMissing: true },
    { name: 'Dynamic inline style applied to rows', regex: /style=\{\{.*?style/ }
  ];

  let passed = 0;
  checks.forEach(check => {
    const found = check.regex.test(content);
    if (check.expectMissing ? !found : found) {
      console.log(`✅ Passed: ${check.name}`);
      passed++;
    } else {
      console.log(`❌ Failed: ${check.name}`);
    }
  });

  console.log(`\nResults: ${passed}/${checks.length} passed.`);
  if (passed === checks.length) {
    console.log('🎉 Virtualization Architecture flawlessly configured for Transport ERP Reports!');
    process.exit(0);
  } else {
    console.log('⚠️ Virtualization Configuration has errors.');
    process.exit(1);
  }
} else {
  console.log('❌ Failed: Reports.jsx not found');
  process.exit(1);
}
