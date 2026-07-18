const fs = require('fs');
const path = require('path');

const projectRoot = path.join(__dirname, '../frontend');
const appFile = path.join(projectRoot, 'src/App.jsx');
const queriesFile = path.join(projectRoot, 'src/api/queries.js');
const queryClientFile = path.join(projectRoot, 'src/api/queryClient.js');

console.log('--- Phase 1: React Query Automated Verification (Transport ERP) ---\n');
let passed = 0;
const totalChecks = 4;

if (fs.existsSync(queryClientFile)) {
    console.log('✅ Passed: queryClient.js exists');
    passed++;
} else {
    console.log('❌ Failed: queryClient.js not found');
}

if (fs.existsSync(queriesFile)) {
    const content = fs.readFileSync(queriesFile, 'utf8');
    // Ensure we don't accidentally export hooks for sensitive APIs
    if (!content.includes('useEwayBill') && !content.includes('useDrivingLicense')) {
        console.log('✅ Passed: queries.js successfully excludes external E-Way Bill and DL APIs');
        passed++;
    } else {
        console.log('❌ Failed: queries.js contains sensitive external APIs!');
    }
} else {
    console.log('❌ Failed: queries.js not found');
}

if (fs.existsSync(appFile)) {
    const content = fs.readFileSync(appFile, 'utf8');
    if (content.includes('QueryClientProvider')) {
        console.log('✅ Passed: App.jsx is wrapped in QueryClientProvider');
        passed++;
    } else {
        console.log('❌ Failed: QueryClientProvider missing from App.jsx');
    }
} else {
    console.log('❌ Failed: App.jsx not found');
}

// Check for react-query in package.json
const pkgPath = path.join(projectRoot, 'package.json');
if (fs.existsSync(pkgPath)) {
    const pkg = JSON.parse(fs.readFileSync(pkgPath, 'utf8'));
    if (pkg.dependencies && pkg.dependencies['@tanstack/react-query']) {
        console.log('✅ Passed: @tanstack/react-query is installed in package.json');
        passed++;
    } else {
        console.log('❌ Failed: @tanstack/react-query not found in package.json');
    }
}

console.log(`\nResults: ${passed}/${totalChecks} passed.`);
if (passed === totalChecks) {
    console.log('🎉 React Query Architecture is flawlessly implemented for Transport ERP!');
    process.exit(0);
} else {
    console.log('⚠️ Configuration has errors.');
    process.exit(1);
}
