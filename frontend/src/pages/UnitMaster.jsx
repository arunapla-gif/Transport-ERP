import React, { useState, useEffect } from 'react';
import { api } from '../api';
import { Settings, Plus, Search, Trash2, Edit2, AlertCircle } from 'lucide-react';

export default function UnitMaster() {
  const [units, setUnits] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [search, setSearch] = useState('');

  const [isModalOpen, setIsModalOpen] = useState(false);
  const [editingId, setEditingId] = useState(null);
  
  const [formData, setFormData] = useState({
    category: 'Cases',
    description: '',
    code: '',
    color: 'slate',
    hsn: '',
    goodsDesc: ''
  });

  const categories = ['Cases', 'Cartons', 'Bundles', 'Boxes', 'Drums', 'Other'];
  const colors = [
    { name: 'slate', label: 'Gray' },
    { name: 'emerald', label: 'Green' },
    { name: 'amber', label: 'Yellow' },
    { name: 'rose', label: 'Red' },
    { name: 'blue', label: 'Blue' },
    { name: 'indigo', label: 'Indigo' }
  ];

  useEffect(() => {
    fetchUnits();
  }, []);

  const fetchUnits = async () => {
    try {
      setLoading(true);
      const data = await api.get('/units');
      setUnits(data);
    } catch (err) {
      setError('Failed to fetch units.');
    } finally {
      setLoading(false);
    }
  };

  const handleSave = async (e) => {
    e.preventDefault();
    try {
      if (editingId) {
        await api.put(`/units/${editingId}`, formData);
      } else {
        await api.post('/units', formData);
      }
      setIsModalOpen(false);
      fetchUnits();
    } catch (err) {
      setError(err.error || 'Failed to save unit.');
    }
  };

  const handleDelete = async (id) => {
    if (!window.confirm('Are you sure you want to delete this unit?')) return;
    try {
      await api.delete(`/units/${id}`);
      fetchUnits();
    } catch (err) {
      setError('Failed to delete unit.');
    }
  };

  const openModal = (unit = null) => {
    setError('');
    if (unit) {
      setEditingId(unit.id);
      setFormData({
        category: unit.category,
        description: unit.description,
        code: unit.code,
        color: unit.color,
        hsn: unit.hsn || '',
        goodsDesc: unit.goodsDesc || ''
      });
    } else {
      setEditingId(null);
      setFormData({
        category: 'Cases',
        description: '',
        code: '',
        color: 'slate',
        hsn: '',
        goodsDesc: ''
      });
    }
    setIsModalOpen(true);
  };

  const filteredUnits = units.filter(u => 
    u.category.toLowerCase().includes(search.toLowerCase()) || 
    u.description.toLowerCase().includes(search.toLowerCase()) ||
    u.code.toLowerCase().includes(search.toLowerCase())
  );

  return (
    <div className="p-4 md:p-8 max-w-5xl mx-auto">
      <div className="flex flex-col md:flex-row justify-between items-start md:items-center mb-6 gap-4">
        <div>
          <h1 className="text-2xl font-bold text-slate-800 flex items-center gap-2">
            <Settings className="text-indigo-600" />
            Unit Master
          </h1>
          <p className="text-slate-500 text-sm mt-1">Manage physical categories and descriptions for goods.</p>
        </div>
        <button onClick={() => openModal()} className="bg-indigo-600 hover:bg-indigo-700 text-white px-4 py-2 rounded-lg font-medium flex items-center gap-2 transition-colors">
          <Plus size={18} /> Add New Unit
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
              placeholder="Search units..." 
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="w-full pl-10 pr-4 py-2 border border-slate-200 rounded-lg focus:outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500"
            />
          </div>
        </div>

        {loading ? (
          <div className="p-8 text-center text-slate-500">Loading units...</div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-left border-collapse">
              <thead>
                <tr className="bg-slate-50 text-slate-500 text-xs uppercase tracking-wider border-b border-slate-200">
                  <th className="p-4 font-bold">Category</th>
                  <th className="p-4 font-bold">Description</th>
                  <th className="p-4 font-bold">Short Code</th>
                  <th className="p-4 font-bold">Default HSN</th>
                  <th className="p-4 font-bold">Default Goods</th>
                  <th className="p-4 font-bold text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {filteredUnits.length === 0 ? (
                  <tr><td colSpan="4" className="p-8 text-center text-slate-500">No units found.</td></tr>
                ) : (
                  filteredUnits.map(unit => (
                    <tr key={unit.id} className="hover:bg-slate-50/50">
                      <td className="p-4 font-medium text-slate-700">{unit.category}</td>
                      <td className="p-4 text-slate-800">{unit.description}</td>
                      <td className="p-4">
                        <span className={`bg-${unit.color}-100 text-${unit.color}-700 border border-${unit.color}-200 px-2 py-0.5 rounded text-xs font-bold`}>
                          {unit.code}
                        </span>
                      </td>
                      <td className="p-4 text-slate-600 font-mono text-sm">{unit.hsn || '-'}</td>
                      <td className="p-4 text-slate-600 text-sm">{unit.goodsDesc || '-'}</td>
                      <td className="p-4 text-right">
                        <div className="flex justify-end gap-2">
                          <button onClick={() => openModal(unit)} className="p-1.5 text-slate-400 hover:text-indigo-600 hover:bg-indigo-50 rounded"><Edit2 size={16} /></button>
                          <button onClick={() => handleDelete(unit.id)} className="p-1.5 text-slate-400 hover:text-rose-600 hover:bg-rose-50 rounded"><Trash2 size={16} /></button>
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
              <h2 className="font-bold text-slate-800 text-lg">{editingId ? 'Edit Unit' : 'Add New Unit'}</h2>
              <button onClick={() => setIsModalOpen(false)} className="text-slate-400 hover:text-slate-600">&times;</button>
            </div>
            
            <form onSubmit={handleSave} className="p-4 space-y-4">
              <div>
                <label className="block text-xs font-bold text-slate-600 uppercase mb-1">Category</label>
                <select 
                  className="w-full p-2.5 border border-slate-200 rounded-lg focus:outline-none focus:border-indigo-500"
                  value={formData.category}
                  onChange={e => setFormData({...formData, category: e.target.value})}
                  required
                >
                  {categories.map(c => <option key={c} value={c}>{c}</option>)}
                </select>
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-600 uppercase mb-1">Description</label>
                <input 
                  type="text" 
                  className="w-full p-2.5 border border-slate-200 rounded-lg focus:outline-none focus:border-indigo-500"
                  value={formData.description}
                  onChange={e => setFormData({...formData, description: e.target.value})}
                  placeholder="e.g. Cases of Fireworks"
                  required
                />
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-xs font-bold text-slate-600 uppercase mb-1">Short Code</label>
                  <input 
                    type="text" 
                    className="w-full p-2.5 border border-slate-200 rounded-lg focus:outline-none focus:border-indigo-500 uppercase"
                    value={formData.code}
                    onChange={e => setFormData({...formData, code: e.target.value.toUpperCase()})}
                    placeholder="e.g. C/S"
                    required
                  />
                </div>
                <div>
                  <label className="block text-xs font-bold text-slate-600 uppercase mb-1">Badge Color</label>
                  <select 
                    className="w-full p-2.5 border border-slate-200 rounded-lg focus:outline-none focus:border-indigo-500"
                    value={formData.color}
                    onChange={e => setFormData({...formData, color: e.target.value})}
                    required
                  >
                    {colors.map(c => <option key={c.name} value={c.name}>{c.label}</option>)}
                  </select>
                </div>
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-xs font-bold text-slate-600 uppercase mb-1">Default HSN</label>
                  <input 
                    type="text" 
                    className="w-full p-2.5 border border-slate-200 rounded-lg focus:outline-none focus:border-indigo-500"
                    value={formData.hsn}
                    onChange={e => setFormData({...formData, hsn: e.target.value})}
                    placeholder="e.g. 36041000"
                  />
                </div>
                <div>
                  <label className="block text-xs font-bold text-slate-600 uppercase mb-1">Default Goods Desc</label>
                  <input 
                    type="text" 
                    className="w-full p-2.5 border border-slate-200 rounded-lg focus:outline-none focus:border-indigo-500"
                    value={formData.goodsDesc}
                    onChange={e => setFormData({...formData, goodsDesc: e.target.value})}
                    placeholder="e.g. FIREWORKS"
                  />
                </div>
              </div>

              <div className="flex gap-3 pt-4 border-t border-slate-100">
                <button type="button" onClick={() => setIsModalOpen(false)} className="flex-1 px-4 py-2 border border-slate-200 text-slate-600 rounded-lg font-medium hover:bg-slate-50">Cancel</button>
                <button type="submit" className="flex-1 px-4 py-2 bg-indigo-600 text-white rounded-lg font-medium hover:bg-indigo-700">Save Unit</button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
