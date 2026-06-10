export const API_BASE = import.meta.env?.VITE_API_URL || 'http://localhost:5005/api';

const getHeaders = () => {
  const token = localStorage.getItem('erp_token');
  const headers = { 'Bypass-Tunnel-Reminder': 'true' };
  if (token) {
    headers['Authorization'] = `Bearer ${token}`;
  }
  return headers;
};

const handleResponse = async (res) => {
  if (res.status === 401 || res.status === 403) {
    localStorage.removeItem('erp_token');
    localStorage.removeItem('erp_role');
    window.location.reload();
    throw new Error('Session expired. Please log in again.');
  }
  const data = await res.json();
  if (!res.ok) throw new Error(data.error || 'Network response was not ok');
  return data;
};

export const api = {
  // Generic CRUD
  get: async (endpoint) => {
    const res = await fetch(`${API_BASE}${endpoint}`, {
      headers: getHeaders()
    });
    return handleResponse(res);
  },
  post: async (endpoint, payload) => {
    const res = await fetch(`${API_BASE}${endpoint}`, {
      method: 'POST',
      headers: { 
        'Content-Type': 'application/json',
        ...getHeaders()
      },
      body: JSON.stringify(payload),
    });
    return handleResponse(res);
  },
  put: async (endpoint, payload) => {
    const res = await fetch(`${API_BASE}${endpoint}`, {
      method: 'PUT',
      headers: { 
        'Content-Type': 'application/json',
        ...getHeaders()
      },
      body: JSON.stringify(payload),
    });
    return handleResponse(res);
  },
  delete: async (endpoint) => {
    const res = await fetch(`${API_BASE}${endpoint}`, { 
      method: 'DELETE',
      headers: { ...getHeaders(), 'Bypass-Tunnel-Reminder': 'true' }
    });
    return handleResponse(res);
  },

  // Third Party APIs via Backend
  verifyGST: async (gstNo) => {
    const res = await fetch(`${API_BASE}/appyflow-gst/${gstNo}`, {
      headers: { ...getHeaders(), 'Bypass-Tunnel-Reminder': 'true' }
    });
    const data = await res.json();
    if (!res.ok) throw new Error(data.error || 'Invalid GST');
    return data;
  },
  verifyPincode: async (pincode) => {
    const res = await fetch(`https://api.postalpincode.in/pincode/${pincode}`);
    const data = await res.json();
    if (data[0].Status === 'Error') throw new Error('Invalid Pincode');
    return data[0].PostOffice;
  }
};
