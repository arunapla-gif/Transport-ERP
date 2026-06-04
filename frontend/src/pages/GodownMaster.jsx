import React, { useState, useEffect, useRef } from 'react';
import { api } from '../api';
import toast from 'react-hot-toast';
import { Plus, Save, Trash2, Edit2, Package, Search } from 'lucide-react';
import { Card } from '../components/ui/Card';

const DenseInput = ({ label, className = "", ...props }) => (
  <div className={`flex flex-col group ${className}`}>
    {label && <label className="text-[10px] font-bold text-slate-500 uppercase tracking-wider mb-1 transition-colors group-focus-within:text-indigo-600">{label}</label>}
    <input 
      className="h-9 px-3 border border-slate-200 rounded-lg bg-slate-50/50 text-sm font-semibold text-slate-800 focus:outline-none focus:border-indigo-500 focus:ring-2 focus:ring-indigo-500/20 hover:border-slate-300 transition-all shadow-sm" 
      {...props} 
    />
  </div>
);

export default function GodownMaster() {
  const [godowns, setGodowns] = useState([]);
  const [loading, setLoading] = useState(false);
  const [search, setSearch] = useState('');
  
  const [editingId, setEditingId] = useState(null);
  const [formData, setFormData] = useState({ name: '' });
  const formRef = useRef(null);

  useEffect(() => {
    fetchGodowns();
  }, []);

  const fetchGodowns = async () => {
    try {
      const data = await api.get('/godowns');
      setGodowns(data);
    } catch (err) {
      toast.error('Failed to fetch Godowns');
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!formData.name.trim()) {
      toast.error("Godown name is required");
      return;
    }

    try {
      setLoading(true);
      if (editingId) {
        await api.put(`/godowns/${editingId}`, formData);
        toast.success('Godown updated successfully');
      } else {
        await api.post('/godowns', formData);
        toast.success('Godown added successfully');
      }
      setFormData({ name: '' });
      setEditingId(null);
      fetchGodowns();
    } catch (err) {
      toast.error(err.error || err.message || 'Failed to save Godown');
    } finally {
      setLoading(false);
    }
  };

  const handleEdit = (godown) => {
    setEditingId(godown.id);
    setFormData({ name: godown.name });
    window.scrollTo({ top: 0, behavior: 'smooth' });
    if (formRef.current) {
      formRef.current.querySelector('input').focus();
    }
  };

  const handleDelete = async (id) => {
    if (!window.confirm('Are you sure you want to delete this Godown?')) return;
    try {
      await api.delete(`/godowns/${id}`);
      toast.success('Godown deleted successfully');
      fetchGodowns();
    } catch (err) {
      toast.error('Failed to delete Godown. It might be used in GCs.');
    }
  };

  const handleCancel = () => {
    setEditingId(null);
    setFormData({ name: '' });
  };

  const filteredGodowns = godowns.filter(g => 
    g.name?.toLowerCase().includes(search.toLowerCase())
  );

  return (
    <div className="max-w-4xl mx-auto space-y-6 pb-12" style={{ fontFamily: '"Inter", system-ui, sans-serif' }}>
      
      {/* Form Card */}
      <Card className="p-6 bg-white shadow-xl shadow-slate-200/40 border-slate-200 rounded-2xl relative overflow-hidden">
        <div className="absolute top-0 right-0 p-8 opacity-5 pointer-events-none">
          <Package size={120} />
        </div>
        
        <div className="flex items-center gap-3 mb-6 relative z-10">
          <div className="w-10 h-10 rounded-xl bg-indigo-50 flex items-center justify-center text-indigo-600 shadow-inner border border-indigo-100">
            <Package size={20} />
          </div>
          <div>
            <h2 className="text-xl font-black text-slate-800 tracking-tight">Godown Master</h2>
            <p className="text-xs font-semibold text-slate-500">Manage storage locations and godowns</p>
          </div>
        </div>

        <form ref={formRef} onSubmit={handleSubmit} className="relative z-10">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4 items-end">
            <DenseInput 
              label="Godown Name *"
              placeholder="e.g. Sivakasi Main Godown"
              value={formData.name}
              onChange={e => setFormData({...formData, name: e.target.value.toUpperCase()})}
              required
            />
            
            <div className="flex gap-2 h-9">
              {editingId && (
                <button 
                  type="button" 
                  onClick={handleCancel}
                  className="px-4 border border-slate-200 text-slate-600 rounded-lg font-bold text-xs hover:bg-slate-50 transition-colors"
                >
                  Cancel
                </button>
              )}
              <button 
                type="submit" 
                disabled={loading}
                className="flex-1 bg-indigo-600 hover:bg-indigo-700 text-white rounded-lg font-bold text-xs shadow-md transition-all active:scale-95 flex items-center justify-center gap-2 disabled:opacity-70"
              >
                {editingId ? <Edit2 size={14} /> : <Plus size={14} />}
                {editingId ? 'Update Godown' : 'Add Godown'}
              </button>
            </div>
          </div>
        </form>
      </Card>

      {/* List Card */}
      <Card className="bg-white shadow-xl shadow-slate-200/40 border-slate-200 rounded-2xl overflow-hidden">
        <div className="p-4 border-b border-slate-100 flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4 bg-slate-50/50">
          <h3 className="font-bold text-slate-700 flex items-center gap-2">
            Godown List <span className="px-2 py-0.5 bg-indigo-100 text-indigo-700 rounded-full text-[10px]">{filteredGodowns.length}</span>
          </h3>
          <div className="relative w-full sm:w-64">
            <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
            <input 
              type="text" 
              placeholder="Search godowns..." 
              value={search}
              onChange={e => setSearch(e.target.value)}
              className="w-full h-8 pl-9 pr-3 text-sm bg-white border border-slate-200 rounded-lg focus:outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500"
            />
          </div>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full text-left border-collapse">
            <thead>
              <tr className="bg-white text-[10px] font-bold text-slate-400 uppercase tracking-wider border-b border-slate-100">
                <th className="p-4 w-16">ID</th>
                <th className="p-4">Godown Name</th>
                <th className="p-4 text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="text-sm font-semibold text-slate-700 divide-y divide-slate-50">
              {filteredGodowns.length === 0 ? (
                <tr>
                  <td colSpan="3" className="p-8 text-center text-slate-400">
                    No godowns found.
                  </td>
                </tr>
              ) : (
                filteredGodowns.map((godown) => (
                  <tr key={godown.id} className="hover:bg-slate-50/80 transition-colors group">
                    <td className="p-4 text-slate-400">#{godown.id}</td>
                    <td className="p-4 text-indigo-900 font-bold">{godown.name}</td>
                    <td className="p-4">
                      <div className="flex justify-end gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
                        <button onClick={() => handleEdit(godown)} className="p-1.5 text-slate-400 hover:text-indigo-600 hover:bg-indigo-50 rounded-md transition-colors">
                          <Edit2 size={14} />
                        </button>
                        <button onClick={() => handleDelete(godown.id)} className="p-1.5 text-slate-400 hover:text-rose-600 hover:bg-rose-50 rounded-md transition-colors">
                          <Trash2 size={14} />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </Card>
    </div>
  );
}
