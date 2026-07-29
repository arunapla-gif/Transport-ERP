import React, { useState, useEffect, useCallback } from 'react';
import { api } from '../api';
import toast from 'react-hot-toast';
import { useKeyboardFlow } from '../hooks/useKeyboardFlow';
import { Edit2, Trash2, Save, Search, User, FileCheck, Phone, CreditCard } from 'lucide-react';
import { Button } from '../components/ui/Button';

// Premium Dense Primitives
const DenseInput = ({ label, className = "", ...props }) => (
  <div className={`flex flex-col group ${className}`}>
    {label && <label className="text-[10px] font-bold text-slate-500 uppercase tracking-wider mb-0.5 transition-colors group-focus-within:text-emerald-600">{label}</label>}
    <input 
      className="w-full h-9 px-2.5 border border-slate-200 rounded-lg bg-white/50 text-sm font-medium text-slate-800 placeholder-slate-400 focus:outline-none focus:border-emerald-500 focus:ring-2 focus:ring-emerald-500/20 hover:border-slate-300 transition-all shadow-[inset_0_1px_2px_rgba(0,0,0,0.02)]" 
      {...props} 
    />
  </div>
);

const DenseSelect = ({ label, options, className = "", ...props }) => (
  <div className={`flex flex-col group ${className}`}>
    {label && <label className="text-[10px] font-bold text-slate-500 uppercase tracking-wider mb-0.5 transition-colors group-focus-within:text-emerald-600">{label}</label>}
    <select 
      className="w-full h-9 px-2.5 border border-slate-200 rounded-lg bg-white/50 text-sm font-medium text-slate-800 focus:outline-none focus:border-emerald-500 focus:ring-2 focus:ring-emerald-500/20 hover:border-slate-300 transition-all appearance-none cursor-pointer shadow-[inset_0_1px_2px_rgba(0,0,0,0.02)]" 
      {...props}
    >
      {options.map((opt, i) => (
        <option key={i} value={opt.value !== undefined ? opt.value : opt}>{opt.label || opt}</option>
      ))}
    </select>
  </div>
);

const GlassCard = ({ children, className = "" }) => (
  <div className={`bg-white/80 backdrop-blur-2xl border border-white/60 rounded-xl p-4 shadow-[0_4px_20px_rgb(16,185,129,0.04)] relative overflow-hidden transition-all duration-300 hover:shadow-[0_4px_20px_rgb(16,185,129,0.06)] ${className}`}>
    <div className="absolute top-0 left-0 right-0 h-[1px] bg-gradient-to-r from-transparent via-white to-transparent opacity-80" />
    {children}
  </div>
);

export default function DriverMaster() {
  const [drivers, setDrivers] = useState([]);
  const [formData, setFormData] = useState({
    id: null, licenseNumber: '', name: '', phone: '', dob: '', bloodGroup: '', rto: '', status: 'Active', validityNt: '', validityTr: ''
  });
  const [loading, setLoading] = useState(false);
  const [searchTerm, setSearchTerm] = useState('');

  const handleSave = useCallback(async (e) => {
    if (e && e.preventDefault) e.preventDefault();
    if (!formData.name) return toast.error("Driver Name is required");
    if (!formData.licenseNumber) return toast.error("License Number is required");
    
    setLoading(true);
    try {
      if (formData.id) {
        await api.put(`/drivers/${formData.id}`, formData);
        toast.success('Driver updated successfully');
      } else {
        const { id, ...dataToCreate } = formData;
        await api.post('/drivers', dataToCreate);
        toast.success('Driver created successfully');
      }
      setFormData({ 
        id: null, licenseNumber: '', name: '', phone: '', dob: '', bloodGroup: '', rto: '', status: 'Active', validityNt: '', validityTr: '' 
      });
      fetchDrivers();
    } catch (err) {
      toast.error('Failed to save record: ' + (err.error || err.message || 'Unknown error'));
    } finally {
      setLoading(false);
    }
  }, [formData]);

  useKeyboardFlow({
    onSave: handleSave
  });

  useEffect(() => {
    fetchDrivers();
  }, []);

  const fetchDrivers = async () => {
    try {
      const data = await api.get('/drivers');
      setDrivers(data || []);
    } catch (err) {
      toast.error('Failed to fetch data.');
    }
  };

  const handleEdit = (driver) => {
    setFormData({
      id: driver.id,
      licenseNumber: driver.licenseNumber || '',
      name: driver.name || '',
      phone: driver.phone || '',
      dob: driver.dob || '',
      bloodGroup: driver.bloodGroup || '',
      rto: driver.rto || '',
      status: driver.status || 'Active',
      validityNt: driver.validityNt || '',
      validityTr: driver.validityTr || ''
    });
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  const handleDelete = async (id) => {
    if (!window.confirm('Are you sure you want to delete this driver?')) return;
    try {
      await api.delete(`/drivers/${id}`);
      fetchDrivers();
      toast.success('Driver deleted');
    } catch (err) {
      toast.error('Failed to delete driver');
    }
  };

  const filteredDrivers = drivers.filter(d => 
    (d.name && d.name.toLowerCase().includes(searchTerm.toLowerCase())) || 
    (d.licenseNumber && d.licenseNumber.toLowerCase().includes(searchTerm.toLowerCase())) ||
    (d.phone && d.phone.toLowerCase().includes(searchTerm.toLowerCase()))
  );

  return (
    <div className="space-y-4 max-w-[1200px] mx-auto pb-10" style={{ fontFamily: '"Inter", system-ui, sans-serif' }}>
      
      {/* HEADER CARD */}
      <GlassCard className="!p-4">
        <div className="flex items-center gap-3">
          <div className="bg-emerald-50 text-emerald-600 p-2 rounded-xl shadow-inner border border-emerald-100/50">
            <User size={20} />
          </div>
          <div>
            <h2 className="font-bold text-lg text-slate-800 tracking-tight">Driver Master</h2>
            <p className="text-xs font-medium text-slate-500">Manage drivers, contact details, and license validity.</p>
          </div>
        </div>
      </GlassCard>

      {/* TOP-DOWN STACKED LAYOUT FOR FORMS */}
      <div className="flex flex-col gap-6">
        <div className="space-y-4">
          <GlassCard>
            <div className="flex items-center gap-2 mb-4 border-b border-slate-100 pb-2">
              <CreditCard size={16} className="text-emerald-600" />
              <h3 className="font-bold text-sm text-slate-800">Driver Identity</h3>
            </div>
            <div className="grid grid-cols-1 md:grid-cols-4 gap-x-6 gap-y-4">
              <DenseInput 
                label="License Number *" 
                value={formData.licenseNumber} 
                onChange={e => setFormData({...formData, licenseNumber: e.target.value.toUpperCase()})} 
                className="md:col-span-2 [&>input]:font-bold [&>input]:text-emerald-900 [&>input]:uppercase" 
              />
              <DenseInput label="Driver Name *" value={formData.name} onChange={e => setFormData({...formData, name: e.target.value})} className="md:col-span-2" />
              
              <div className="md:col-span-4 grid grid-cols-1 md:grid-cols-5 gap-x-6 gap-y-4 pt-2 border-t border-slate-100 mt-2">
                <DenseInput label="Phone Number" value={formData.phone} onChange={e => setFormData({...formData, phone: e.target.value})} />
                <DenseInput label="Date of Birth" placeholder="DD/MM/YYYY" value={formData.dob} onChange={e => setFormData({...formData, dob: e.target.value})} />
                <DenseInput label="Blood Group" placeholder="e.g. O+" value={formData.bloodGroup} onChange={e => setFormData({...formData, bloodGroup: e.target.value})} />
                <DenseInput label="RTO" placeholder="e.g. TN67" value={formData.rto} onChange={e => setFormData({...formData, rto: e.target.value})} />
                <DenseSelect label="Status" options={['Active', 'Inactive', 'Blacklisted']} value={formData.status} onChange={e => setFormData({...formData, status: e.target.value})} />
              </div>

              <div className="md:col-span-4 grid grid-cols-1 md:grid-cols-2 gap-x-6 gap-y-4 pt-2 border-t border-slate-100 mt-2">
                <DenseInput label="Validity (Non-Transport)" placeholder="DD/MM/YYYY" value={formData.validityNt} onChange={e => setFormData({...formData, validityNt: e.target.value})} />
                <DenseInput label="Validity (Transport)" placeholder="DD/MM/YYYY" value={formData.validityTr} onChange={e => setFormData({...formData, validityTr: e.target.value})} />
              </div>
            </div>
          </GlassCard>
        </div>

        {/* ACTION BUTTONS */}
        <GlassCard>
            <div className="flex items-center justify-end gap-3 py-2">
              <Button variant="secondary" type="button" onClick={() => {
                setFormData({ id: null, licenseNumber: '', name: '', phone: '', dob: '', bloodGroup: '', rto: '', status: 'Active', validityNt: '', validityTr: '' });
              }} className="h-10 px-6 text-xs">
                Clear Form
              </Button>
              <Button variant="success" type="button" onClick={handleSave} disabled={loading} className="h-10 px-8 flex items-center justify-center min-w-[180px] gap-2">
                <Save size={16} className={loading ? 'animate-pulse' : ''} /> {formData.id ? 'Update Record' : 'Save Driver Record'}
              </Button>
            </div>
        </GlassCard>
      </div>

      {/* LIST CARD */}
      <GlassCard className="!p-0">
        <div className="p-4 border-b border-slate-100 flex justify-between items-center bg-slate-50/50">
          <h3 className="font-bold text-sm text-slate-800">Saved Drivers <span className="text-slate-400 font-medium ml-1">({drivers.length})</span></h3>
          <div className="relative">
            <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
            <input 
              type="text" 
              placeholder="Search driver or license..." 
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="h-8 pl-9 pr-3 w-64 border border-slate-200 rounded-lg bg-white text-xs focus:outline-none focus:border-emerald-500 focus:ring-2 focus:ring-emerald-500/20"
            />
          </div>
        </div>
        <div className="overflow-x-auto max-h-[400px] overflow-y-auto custom-scrollbar">
          <table className="w-full text-sm text-left">
            <thead className="text-xs text-slate-500 bg-slate-50/80 sticky top-0 backdrop-blur-md z-10 border-b border-slate-200">
              <tr>
                <th className="px-4 py-3 font-bold uppercase tracking-wider w-12 text-center">S.No</th>
                <th className="px-4 py-3 font-bold uppercase tracking-wider">License No</th>
                <th className="px-4 py-3 font-bold uppercase tracking-wider">Name & Phone</th>
                <th className="px-4 py-3 font-bold uppercase tracking-wider">Validities</th>
                <th className="px-4 py-3 font-bold uppercase tracking-wider">Status</th>
                <th className="px-4 py-3 font-bold uppercase tracking-wider text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {filteredDrivers.length > 0 ? filteredDrivers.map((d, index) => (
                <tr key={d.id} className="hover:bg-slate-50/50 transition-colors group">
                  <td className="px-4 py-3 font-bold text-slate-400 text-center">{index + 1}</td>
                  <td className="px-4 py-3 font-bold text-emerald-700">
                    <div className="flex items-center gap-2">
                       <CreditCard size={14} className="text-emerald-500 opacity-50" />
                       {d.licenseNumber}
                    </div>
                  </td>
                  <td className="px-4 py-3 text-slate-600">
                    <div className="font-bold text-slate-800">{d.name}</div>
                    {d.phone && <div className="text-[10px] flex items-center gap-1 text-slate-500 mt-0.5"><Phone size={10}/> {d.phone}</div>}
                  </td>
                  <td className="px-4 py-3 text-slate-600">
                    {d.validityNt && <div className="text-[10px] text-slate-500 uppercase font-bold tracking-wider mb-0.5">NT: {d.validityNt}</div>}
                    {d.validityTr && <div className="text-[10px] text-slate-500 uppercase font-bold tracking-wider">TR: {d.validityTr}</div>}
                    {(!d.validityNt && !d.validityTr) && <span className="text-slate-400">-</span>}
                  </td>
                  <td className="px-4 py-3">
                    <span className={`text-[10px] px-2 py-0.5 rounded font-black uppercase tracking-wider ${d.status === 'Active' ? 'bg-emerald-100 text-emerald-700' : d.status === 'Blacklisted' ? 'bg-rose-100 text-rose-700' : 'bg-slate-200 text-slate-600'}`}>{d.status || 'Active'}</span>
                  </td>
                  <td className="px-4 py-3">
                    <div className="flex justify-end gap-2 opacity-0 group-hover:opacity-100 transition-opacity">
                      <Button variant="icon" onClick={() => handleEdit(d)}><Edit2 size={14} /></Button>
                      <Button variant="iconDanger" onClick={() => handleDelete(d.id)}><Trash2 size={14} /></Button>
                    </div>
                  </td>
                </tr>
              )) : (
                <tr>
                  <td colSpan="6" className="px-4 py-8 text-center text-slate-500 text-sm">No drivers found.</td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </GlassCard>
    </div>
  );
}
