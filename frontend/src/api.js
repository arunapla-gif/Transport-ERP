import { toast } from 'react-hot-toast';

export const API_BASE = import.meta.env?.VITE_API_URL || 'http://127.0.0.1:5005/api';

const getHeaders = () => {
  const token = localStorage.getItem('erp_token');
  const activeBranch = localStorage.getItem('activeBranch') || 'MAIN';
  const headers = { 
    'Bypass-Tunnel-Reminder': 'true',
    'x-branch-id': activeBranch
  };
  if (token) {
    headers['Authorization'] = `Bearer ${token}`;
  }
  return headers;
};

// Global interceptor for cold starts and system status
const fetchWithWakeupIndicator = async (url, options) => {
  const dispatchDbStatus = (status) => window.dispatchEvent(new CustomEvent('erp-db-status', { detail: status }));
  
  // If the request takes longer than 1.2 seconds, we assume Neon is waking up from sleep.
  const sleepTimer = setTimeout(() => {
    dispatchDbStatus('waking');
  }, 1200);

  // Add a hard timeout of 15 seconds to prevent hanging on dead Wi-Fi
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), 15000);
  const finalOptions = { ...options, signal: controller.signal };

  try {
    const res = await fetch(url, finalOptions);
    clearTimeout(timeoutId);
    clearTimeout(sleepTimer);
    
    if (res.ok) {
      dispatchDbStatus('ready');
    } else {
      dispatchDbStatus('idle'); // Non-fatal API error (like 401), just return to idle
    }
    
    return res;
  } catch (error) {
    clearTimeout(timeoutId);
    clearTimeout(sleepTimer);
    
    dispatchDbStatus('error');
    
    // Critical network failures still trigger a loud Toast pop-up
    if (error.name === 'AbortError') {
      toast.error('Connection Timed Out. Please check your internet.', { id: 'db-wakeup', duration: 4000 });
    } else {
      toast.error('Network Error. Please check your internet.', { id: 'db-wakeup', duration: 4000 });
    }
    
    throw error;
  }
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
    const res = await fetchWithWakeupIndicator(`${API_BASE}${endpoint}`, {
      method: 'GET',
      headers: getHeaders(),
      cache: 'no-store'
    });
    return handleResponse(res);
  },
  post: async (endpoint, payload) => {
    const res = await fetchWithWakeupIndicator(`${API_BASE}${endpoint}`, {
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
    const res = await fetchWithWakeupIndicator(`${API_BASE}${endpoint}`, {
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
    const res = await fetchWithWakeupIndicator(`${API_BASE}${endpoint}`, { 
      method: 'DELETE',
      headers: { ...getHeaders(), 'Bypass-Tunnel-Reminder': 'true' }
    });
    return handleResponse(res);
  },

  // Third Party APIs via Backend
  verifyGST: async (gstNo) => {
    const res = await fetchWithWakeupIndicator(`${API_BASE}/appyflow-gst/${gstNo}`, {
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
