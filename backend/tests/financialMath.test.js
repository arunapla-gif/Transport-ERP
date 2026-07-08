const { calculateGcFreight, calculateTripSettlement } = require('../utils/financialMath');

describe('GC Freight Calculations', () => {
  it('should calculate balance correctly with valid numbers', () => {
    const result = calculateGcFreight(1000, 200);
    expect(result.fixed).toBe(1000);
    expect(result.advance).toBe(200);
    expect(result.balance).toBe(800);
  });

  it('should parse string numbers correctly', () => {
    const result = calculateGcFreight("1500.50", "500");
    expect(result.fixed).toBe(1500.5);
    expect(result.advance).toBe(500);
    expect(result.balance).toBe(1000.5);
  });

  it('should fallback to 0 for invalid string inputs', () => {
    const result = calculateGcFreight("abc", "def");
    expect(result.fixed).toBe(0);
    expect(result.advance).toBe(0);
    expect(result.balance).toBe(0);
  });

  it('should handle undefined or null inputs', () => {
    const result = calculateGcFreight(null, undefined);
    expect(result.fixed).toBe(0);
    expect(result.advance).toBe(0);
    expect(result.balance).toBe(0);
  });

  it('should calculate negative balance if advance exceeds fixed freight', () => {
    const result = calculateGcFreight(500, 600);
    expect(result.balance).toBe(-100);
  });

  it('should floor negative inputs to 0', () => {
    const result = calculateGcFreight(-500, -100);
    expect(result.fixed).toBe(0);
    expect(result.advance).toBe(0);
    expect(result.balance).toBe(0);
  });
});

describe('Trip Settlement Calculations', () => {
  it('should correctly calculate net settlement', () => {
    // Hire: 10000, Advances: 2000, FASTag: 500, Unloading: 300, Bata: 1000
    // Deductions: 2500
    // Additions: 1300
    // Net: 10000 + 1300 - 2500 = 8800
    const result = calculateTripSettlement(10000, 2000, 500, 300, 1000);
    expect(result.hire).toBe(10000);
    expect(result.totalDeductions).toBe(2500);
    expect(result.totalAdditions).toBe(1300);
    expect(result.netSettlement).toBe(8800);
  });

  it('should handle missing fields gracefully', () => {
    // Only hire provided
    const result = calculateTripSettlement(10000, null, undefined, "", "abc");
    expect(result.totalDeductions).toBe(0);
    expect(result.totalAdditions).toBe(0);
    expect(result.netSettlement).toBe(10000);
  });

  it('should allow negative net settlement if deductions exceed hire + additions', () => {
    // Hire: 5000, Advance: 6000
    const result = calculateTripSettlement(5000, 6000, 0, 0, 0);
    expect(result.netSettlement).toBe(-1000);
  });

  it('should ignore negative inputs and treat them as 0', () => {
    const result = calculateTripSettlement(-10000, -2000, -500, -300, -1000);
    expect(result.hire).toBe(0);
    expect(result.totalDeductions).toBe(0);
    expect(result.totalAdditions).toBe(0);
    expect(result.netSettlement).toBe(0);
  });
});
