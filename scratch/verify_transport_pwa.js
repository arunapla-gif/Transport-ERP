const fs = require('fs');
const path = require('path');

const projectRoot = path.join(__dirname, '../frontend');
const viteConfigPath = path.join(projectRoot, 'vite.config.js');
const publicDir = path.join(projectRoot, 'public');
const pkgPath = path.join(projectRoot, 'package.json');

console.log('--- Phase 2: PWA Automated Verification (Transport ERP) ---\n');
let passed = 0;
let totalChecks = 3;

// Check 1: Vite config has PWA plugin
if (fs.existsSync(viteConfigPath)) {
  const content = fs.readFileSync(viteConfigPath, 'utf8');
  if (content.includes('VitePWA') && content.includes('manifest')) {
    console.log('✅ Passed: vite.config.js is configured with VitePWA and manifest');
    passed++;
  } else {
    console.log('❌ Failed: VitePWA missing from vite.config.js');
  }
}

// Check 2: Icons exist in public folder
const requiredIcons = ['pwa-192x192.png', 'pwa-512x512.png', 'apple-touch-icon.png', 'masked-icon.svg'];
let iconsExist = true;
requiredIcons.forEach(icon => {
  if (!fs.existsSync(path.join(publicDir, icon))) {
    iconsExist = false;
    console.log(`❌ Failed: Missing icon ${icon} in public folder`);
  }
});
if (iconsExist) {
  console.log('✅ Passed: All required PWA icons exist in public directory');
  passed++;
}

// Check 3: Check package.json for vite-plugin-pwa
if (fs.existsSync(pkgPath)) {
    const pkg = JSON.parse(fs.readFileSync(pkgPath, 'utf8'));
    if (pkg.devDependencies && pkg.devDependencies['vite-plugin-pwa']) {
        console.log('✅ Passed: vite-plugin-pwa is installed in package.json');
        passed++;
    } else {
        console.log('❌ Failed: vite-plugin-pwa not found in package.json');
    }
}

console.log(`\nResults: ${passed}/${totalChecks} passed.`);
if (passed === totalChecks) {
  console.log('🎉 PWA Architecture perfectly configured for Transport ERP!');
  process.exit(0);
} else {
  console.log('⚠️ PWA Configuration has errors.');
  process.exit(1);
}
