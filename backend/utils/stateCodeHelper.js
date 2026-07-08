const stateNameToCode = {
  "jammu and kashmir": "01",
  "himachal pradesh": "02",
  "punjab": "03",
  "chandigarh": "04",
  "uttarakhand": "05",
  "haryana": "06",
  "delhi": "07",
  "rajasthan": "08",
  "uttar pradesh": "09",
  "bihar": "10",
  "sikkim": "11",
  "arunachal pradesh": "12",
  "nagaland": "13",
  "manipur": "14",
  "mizoram": "15",
  "tripura": "16",
  "meghalaya": "17",
  "assam": "18",
  "west bengal": "19",
  "jharkhand": "20",
  "odisha": "21",
  "chhattisgarh": "22",
  "madhya pradesh": "23",
  "gujarat": "24",
  "daman and diu": "25",
  "dadra and nagar haveli and daman and diu": "26",
  "maharashtra": "27",
  "andhra pradesh": "28", // Note: 37 is also used for old AP, but EWB usually maps current to 37/28
  "karnataka": "29",
  "goa": "30",
  "lakshadweep": "31",
  "kerala": "32",
  "tamil nadu": "33",
  "puducherry": "34",
  "andaman and nicobar islands": "35",
  "telangana": "36",
  "andhra pradesh (new)": "37",
  "ladakh": "38",
  "other territory": "97",
  "other country": "99"
};

/**
 * Resolves the final state code using a strict hierarchy.
 * @param {string} gstin - The GSTIN of the party (if available).
 * @param {string} stateName - The state name string (e.g., "Tamil Nadu").
 * @param {string|number} savedStateCode - The stateCode saved in the DB (e.g., "33" or "Tamil Nadu").
 * @returns {number|null} The resolved numeric state code, or null if it cannot be determined.
 */
function resolveStateCode(gstin, stateName, savedStateCode) {
  let finalCode = null;

  // 1. Try to get it from the GSTIN (Most reliable source of truth)
  if (gstin && gstin.length >= 2) {
    const gstinPrefix = gstin.substring(0, 2);
    if (!isNaN(gstinPrefix)) {
      finalCode = parseInt(gstinPrefix, 10);
    }
  }

  // 2. Try to get it from the savedStateCode (if it's already a number)
  if (finalCode === null && savedStateCode) {
    const parsed = parseInt(savedStateCode, 10);
    if (!isNaN(parsed) && parsed > 0 && parsed < 100) {
      finalCode = parsed;
    }
  }

  // 3. Try to get it by translating the state name (if it was saved as a string, or passed explicitly)
  if (finalCode === null) {
    // If the savedStateCode is actually a string like "Tamil Nadu", check it.
    let nameToLookup = "";
    if (typeof savedStateCode === 'string' && isNaN(parseInt(savedStateCode, 10))) {
      nameToLookup = savedStateCode;
    } else if (stateName) {
      nameToLookup = stateName;
    }

    if (nameToLookup) {
      const normalizedName = nameToLookup.trim().toLowerCase();
      if (stateNameToCode[normalizedName]) {
        finalCode = parseInt(stateNameToCode[normalizedName], 10);
      }
    }
  }

  return finalCode;
}

module.exports = {
  stateNameToCode,
  resolveStateCode
};
