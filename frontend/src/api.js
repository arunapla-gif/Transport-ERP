const API_BASE = 'http://localhost:5005/api';

export const api = {
  // Generic CRUD
  get: async (endpoint) => {
    const res = await fetch(`${API_BASE}${endpoint}`, {
      headers: { 'Bypass-Tunnel-Reminder': 'true' }
    });
    const data = await res.json();
    if (!res.ok) throw new Error(data.error || 'Network response was not ok');
    return data;
  },
  post: async (endpoint, payload) => {
    const res = await fetch(`${API_BASE}${endpoint}`, {
      method: 'POST',
      headers: { 
        'Content-Type': 'application/json',
        'Bypass-Tunnel-Reminder': 'true'
      },
      body: JSON.stringify(payload),
    });
    const data = await res.json();
    if (!res.ok) throw new Error(data.error || 'Network response was not ok');
    return data;
  },
  put: async (endpoint, payload) => {
    const res = await fetch(`${API_BASE}${endpoint}`, {
      method: 'PUT',
      headers: { 
        'Content-Type': 'application/json',
        'Bypass-Tunnel-Reminder': 'true'
      },
      body: JSON.stringify(payload),
    });
    const data = await res.json();
    if (!res.ok) throw new Error(data.error || 'Network response was not ok');
    return data;
  },
  delete: async (endpoint) => {
    const res = await fetch(`${API_BASE}${endpoint}`, { 
      method: 'DELETE',
      headers: { 'Bypass-Tunnel-Reminder': 'true' }
    });
    const data = await res.json();
    if (!res.ok) throw new Error(data.error || 'Network response was not ok');
    return data;
  },

  // Third Party APIs
  verifyGST: async (gstNo) => {
    // Using the same API from Crackers ERP
    const res = await fetch(`https://appyflow.in/api/verifyGST?gstNo=${gstNo}&key_secret=7eWP3WelRNexYGJ172L3Hb8JNrY2`);
    const data = await res.json();
    if (data.error) throw new Error(data.message || 'Invalid GST');
    return data;
  },
  verifyPincode: async (pincode) => {
    const res = await fetch(`https://api.postalpincode.in/pincode/${pincode}`);
    const data = await res.json();
    if (data[0].Status === 'Error') throw new Error('Invalid Pincode');
    return data[0].PostOffice;
  }
};
