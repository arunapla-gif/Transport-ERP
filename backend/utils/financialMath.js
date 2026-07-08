/**
 * Calculates the GC Freight balance safely.
 * @param {number|string} fixed - The fixed freight amount.
 * @param {number|string} advance - The advance amount already paid.
 * @returns {object} { fixed, advance, balance }
 */
const calculateGcFreight = (fixed, advance) => {
  const f = Math.max(0, parseFloat(fixed) || 0); // Freight cannot be negative
  const a = Math.max(0, parseFloat(advance) || 0); // Advance cannot be negative
  
  const balance = f - a;

  return {
    fixed: f,
    advance: a,
    balance: balance // Can be negative if advance > fixed (overpayment)
  };
};

/**
 * Calculates the Net Settlement for a Driver Trip.
 * @param {number|string} lorryHire - The total lorry hire agreed.
 * @param {number|string} advances - The sum of all advances given to the driver.
 * @param {number|string} fastagDeduction - Any tolls deducted.
 * @param {number|string} unloadingCharges - Unloading charges paid by driver.
 * @param {number|string} driverBata - Driver allowance.
 * @returns {object} { hire, totalDeductions, totalAdditions, netSettlement }
 */
const calculateTripSettlement = (lorryHire, advances, fastagDeduction, unloadingCharges, driverBata) => {
  const hire = Math.max(0, parseFloat(lorryHire) || 0);
  const adv = Math.max(0, parseFloat(advances) || 0);
  const toll = Math.max(0, parseFloat(fastagDeduction) || 0);
  const unload = Math.max(0, parseFloat(unloadingCharges) || 0);
  const bata = Math.max(0, parseFloat(driverBata) || 0);

  const totalDeductions = adv + toll;
  const totalAdditions = unload + bata;
  
  // Net Settlement = (Hire + Additions) - Deductions
  const netSettlement = (hire + totalAdditions) - totalDeductions;

  return {
    hire,
    totalDeductions,
    totalAdditions,
    netSettlement
  };
};

module.exports = {
  calculateGcFreight,
  calculateTripSettlement
};
