import React, { useState, useEffect } from 'react';
import { api } from '../api';
import { Settings, Plus, Search, Trash2, Edit2, AlertCircle } from 'lucide-react';
import toast from 'react-hot-toast';

export default function HSNMaster() {
  const [hsnList, setHsnList] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [search, setSearch] = useState('');

  const [isModalOpen, setIsModalOpen] = useState(false);
  
  const [formData, setFormData] = useState({
    hsnCode: '',
    description: '',
    gstRate: 18
  });

  useEffect(() => {
    fetchHSNList();
  }, []);

  const fetchHSNList = async () => {
    try {
      setLoading(true);
      const data = await api.get('/hsn');
      setHsnList(Array.isArray(data) ? data : []);
    } catch (err) {
      setError('Failed to fetch HSN records.');
    } finally {
      setLoading(false);
    }
  };

  const handleSave = async (e) => {
    e.preventDefault();
    try {
      await api.post('/hsn', formData);
      toast.success('HSN Code saved successfully');
      setIsModalOpen(false);
      fetchHSNList();
    } catch (err) {
      setError(err.error || 'Failed to save HSN.');
      toast.error('Failed to save HSN');
    }
  };

  const handleDelete = async (id) => {
    // Note: The backend route doesn't exist for delete yet, so let's just show an alert or add the route if needed.
    toast.error("Delete not supported yet for HSN. Please edit instead.");
  };

  const openModal = (hsnItem = null) => {
    setError('');
    if (hsnItem) {
      setFormData({
        hsnCode: hsnItem.hsnCode,
        description: hsnItem.description || '',
        gstRate: hsnItem.gstRate || 18
      });
    } else {
      setFormData({
        hsnCode: '',
        description: '',
        gstRate: 18
      });
    }
    setIsModalOpen(true);
  };

  const filteredList = hsnList.filter(h => 
    (h.hsnCode || '').toLowerCase().includes(search.toLowerCase()) || 
    (h.description || '').toLowerCase().includes(search.toLowerCase())
  );

  return (
    <div className="p-4 md:p-8 max-w-5xl mx-auto">
      <div className="flex flex-col md:flex-row justify-between items-start md:items-center mb-6 gap-4">
        <div>
          <h1 className="text-2xl font-bold text-slate-800 flex items-center gap-2">
            <Settings className="text-indigo-600" />
            HSN Tax Master
          </h1>
          <p className="text-slate-500 text-sm mt-1">Manage HSN Codes and GST Rates for accurate E-Way Bill generation.</p>
        </div>
        <button onClick={() => openModal()} className="bg-indigo-600 hover:bg-indigo-700 text-white px-4 py-2 rounded-lg font-medium flex items-center gap-2 transition-colors">
          <Plus size={18} /> Add New HSN
        </button>
      </div>

      {error && (
        <div className="bg-rose-50 border border-rose-200 text-rose-700 px-4 py-3 rounded-lg mb-6 flex items-center gap-2">
          <AlertCircle size={18} /> {error}
        </div>
      )}

      <div className="bg-white rounded-xl shadow-sm border border-slate-200 overflow-hidden">
        <div className="p-4 border-b border-slate-200 bg-slate-50/50">
          <div className="relative max-w-sm">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" size={18} />
            <input 
              type="text" 
              placeholder="Search HSN or Description..." 
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="w-full pl-10 pr-4 py-2 border border-slate-200 rounded-lg focus:outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500"
            />
          </div>
        </div>

        {loading ? (
          <div className="p-8 text-center text-slate-500">Loading HSN codes...</div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-left border-collapse">
              <thead>
                <tr className="bg-slate-50 text-slate-500 text-xs uppercase tracking-wider border-b border-slate-200">
                  <th className="p-4 font-bold">HSN Code</th>
                  <th className="p-4 font-bold">Description</th>
                  <th className="p-4 font-bold">GST Rate (%)</th>
                  <th className="p-4 font-bold text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {filteredList.length === 0 ? (
                  <tr><td colSpan="4" className="p-8 text-center text-slate-500">No HSN records found.</td></tr>
                ) : (
                  filteredList.map(item => (
                    <tr key={item.id} className="hover:bg-slate-50/50">
                      <td className="p-4 font-bold text-indigo-700 font-mono">{item.hsnCode}</td>
                      <td className="p-4 text-slate-800">{item.description || '-'}</td>
                      <td className="p-4">
                        <span className="bg-emerald-100 text-emerald-800 border border-emerald-200 px-2.5 py-1 rounded-full text-xs font-bold">
                          {item.gstRate}%
                        </span>
                      </td>
                      <td className="p-4 text-right">
                        <div className="flex justify-end gap-2">
                          <button onClick={() => openModal(item)} className="p-1.5 text-slate-400 hover:text-indigo-600 hover:bg-indigo-50 rounded"><Edit2 size={16} /></button>
                          <button onClick={() => handleDelete(item.id)} className="p-1.5 text-slate-400 hover:text-rose-600 hover:bg-rose-50 rounded"><Trash2 size={16} /></button>
                        </div>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {isModalOpen && (
        <div className="fixed inset-0 bg-slate-900/50 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-xl shadow-xl w-full max-w-md overflow-hidden">
            <div className="p-4 border-b border-slate-200 bg-slate-50 flex justify-between items-center">
              <h2 className="font-bold text-slate-800 text-lg">Manage HSN Code</h2>
              <button onClick={() => setIsModalOpen(false)} className="text-slate-400 hover:text-slate-600">&times;</button>
            </div>
            
            <form onSubmit={handleSave} className="p-4 space-y-4">
              <div>
                <label className="block text-xs font-bold text-slate-600 uppercase mb-1">HSN Code</label>
                <input 
                  type="text" 
                  className="w-full p-2.5 border border-slate-200 rounded-lg focus:outline-none focus:border-indigo-500 font-mono"
                  value={formData.hsnCode}
                  onChange={e => setFormData({...formData, hsnCode: e.target.value.replace(/[^0-9]/g, '')})}
                  placeholder="e.g. 3604"
                  required
                />
                <p className="text-[10px] text-slate-400 mt-1">Numbers only. Enter exact 4, 6, or 8 digit code.</p>
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-600 uppercase mb-1">Goods Description</label>
                <input 
                  type="text" 
                  className="w-full p-2.5 border border-slate-200 rounded-lg focus:outline-none focus:border-indigo-500"
                  value={formData.description}
                  onChange={e => setFormData({...formData, description: e.target.value})}
                  placeholder="e.g. Fireworks and Crackers"
                  required
                />
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-600 uppercase mb-1">Total GST Rate (%)</label>
                <div className="relative">
                  <input 
                    type="number" 
                    step="0.1"
                    className="w-full p-2.5 border border-slate-200 rounded-lg focus:outline-none focus:border-indigo-500 font-bold text-slate-800"
                    value={formData.gstRate}
                    onChange={e => setFormData({...formData, gstRate: parseFloat(e.target.value) || 0})}
                    placeholder="e.g. 18"
                    required
                  />
                  <span className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 font-bold">%</span>
                </div>
              </div>

              <div className="flex gap-3 pt-4 border-t border-slate-100">
                <button type="button" onClick={() => setIsModalOpen(false)} className="flex-1 px-4 py-2 border border-slate-200 text-slate-600 rounded-lg font-medium hover:bg-slate-50">Cancel</button>
                <button type="submit" className="flex-1 px-4 py-2 bg-indigo-600 text-white rounded-lg font-medium hover:bg-indigo-700">Save HSN</button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
