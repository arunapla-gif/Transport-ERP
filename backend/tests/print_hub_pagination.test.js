const assert = require('assert');

// Simple test runner for the API endpoints handling Print Hub Pagination
async function runTests() {
  const BASE_URL = 'http://localhost:5005/api'; // Backend runs on 5005
  
  console.log('🧪 Starting Automated API Pagination Tests for Print Hub...\n');

  try {
    // ----------------------------------------------------
    // Test 1: GC Pagination (GET /gcs?page=1&limit=5)
    // ----------------------------------------------------
    console.log('Test 1: Fetching GCs with limit=5');
    const gcRes = await fetch(`${BASE_URL}/gcs?page=1&limit=5`);
    const gcData = await gcRes.json();
    
    // Assertions
    assert(gcRes.ok, `Expected 200 OK, got ${gcRes.status}`);
    assert(Array.isArray(gcData.data), 'Expected data to be an array');
    assert(gcData.data.length <= 5, `Expected <= 5 items, got ${gcData.data.length}`);
    assert(typeof gcData.total === 'number', 'Expected total count to be a number');
    assert(typeof gcData.totalPages === 'number', 'Expected totalPages to be a number');
    
    console.log(`✅ GC Pagination passed! (Returned ${gcData.data.length} records, Total: ${gcData.total}, Pages: ${gcData.totalPages})`);
    
    // ----------------------------------------------------
    // Test 2: GDM Pagination (GET /gdms?page=1&limit=5)
    // ----------------------------------------------------
    console.log('\nTest 2: Fetching GDMs with limit=5');
    const gdmRes = await fetch(`${BASE_URL}/gdms?page=1&limit=5`);
    const gdmData = await gdmRes.json();
    
    // Assertions
    assert(gdmRes.ok, `Expected 200 OK, got ${gdmRes.status}`);
    assert(Array.isArray(gdmData.data), 'Expected data to be an array');
    assert(gdmData.data.length <= 5, `Expected <= 5 items, got ${gdmData.data.length}`);
    assert(typeof gdmData.total === 'number', 'Expected total count to be a number');
    assert(typeof gdmData.totalPages === 'number', 'Expected totalPages to be a number');
    
    console.log(`✅ GDM Pagination passed! (Returned ${gdmData.data.length} records, Total: ${gdmData.total}, Pages: ${gdmData.totalPages})`);

    console.log('\n🎉 All Automated Pagination Tests Passed Successfully!');
  } catch (error) {
    console.error('\n❌ Test Failed:', error.message);
    process.exit(1);
  }
}

runTests();
