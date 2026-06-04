import React, { useState, useEffect } from 'react';
import { api } from '../api';
import toast from 'react-hot-toast';
import { Building2, Search, Save, Edit2, Trash2, CheckCircle2 } from 'lucide-react';

const Input = ({ label, className = "", ...props }) => (
  <div className={`flex flex-col ${className}`}>
    <label className="text-xs font-bold text-slate-500 uppercase tracking-wider mb-1">{label}</label>
    <input 
      className={`h-10 px-3 bg-white border border-slate-200 rounded-lg text-sm font-semibold text-slate-800 placeholder-slate-400 focus:outline-none focus:border-indigo-500 focus:ring-2 focus:ring-indigo-500/20 transition-all ${props.readOnly ? 'bg-slate-50 text-slate-500 cursor-not-allowed' : 'hover:border-slate-300'}`}
      {...props}
    />
  </div>
);

export default function CompanyMaster() {
  const [companies, setCompanies] = useState([]);
  const [loading, setLoading] = useState(false);
  
  const [searchGstin, setSearchGstin] = useState('');
  const [isSearchingGst, setIsSearchingGst] = useState(false);

  const [formData, setFormData] = useState({
    id: null,
    gstin: '',
    tradeName: '',
    legalName: '',
    address: '',
    city: '',
    district: '',
    state: '',
    pincode: '',
    phone: '',
    email: '',
    status: 'Active'
  });

  useEffect(() => {
    fetchCompanies();
  }, []);

  const fetchCompanies = async () => {
    try {
      const data = await api.get('/companies');
      setCompanies(data || []);
    } catch (err) {
      console.error('Failed to fetch companies', err);
    }
  };

  const handleSearchGst = async () => {
    if (!searchGstin.trim() || searchGstin.length !== 15) {
      toast.error('Please enter a valid 15-digit GSTIN');
      return;
    }
    
    try {
      setIsSearchingGst(true);
      
      const response = await api.get(`/gst-search/${searchGstin.trim()}`);
      
      setFormData({
        id: null,
        gstin: response.gstin,
        tradeName: response.tradeName,
        legalName: response.legalName,
        address: response.address,
        city: response.city,
        district: response.district || '',
        state: response.state,
        pincode: response.pincode,
        phone: '',
        email: '',
        status: response.status || 'Active'
      });
      
      toast.success('GST Details Fetched Successfully!');
    } catch (err) {
      toast.error(err.error || err.message || 'Failed to fetch GST details');
    } finally {
      setIsSearchingGst(false);
    }
  };

  const handleSave = async (e) => {
    e.preventDefault();
    if (!formData.gstin || !formData.tradeName) {
      toast.error('GSTIN and Trade Name are required');
      return;
    }

    try {
      setLoading(true);
      
      if (formData.id) {
        await api.put(`/companies/${formData.id}`, formData);
        toast.success('Company updated successfully!');
      } else {
        await api.post('/companies', formData);
        toast.success('Company added successfully!');
      }
      
      resetForm();
      fetchCompanies();
    } catch (err) {
      toast.error(err.error || err.message || 'Failed to save company');
    } finally {
      setLoading(false);
    }
  };

  const handleEdit = (company) => {
    setFormData(company);
    setSearchGstin(company.gstin);
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  const handleDelete = async (id) => {
    if (!window.confirm('Are you sure you want to delete this company?')) return;
    try {
      await api.delete(`/companies/${id}`);
      fetchCompanies();
      toast.success('Company deleted successfully');
    } catch (err) {
      toast.error('Failed to delete company');
    }
  };

  const resetForm = () => {
    setFormData({
      id: null,
      gstin: '',
      tradeName: '',
      legalName: '',
      address: '',
      city: '',
      district: '',
      state: '',
      pincode: '',
      phone: '',
      email: '',
      status: 'Active'
    });
    setSearchGstin('');
  };

  return (
    <div className="space-y-6 max-w-[1200px] mx-auto pb-10" style={{ fontFamily: '"Inter", system-ui, sans-serif' }}>
      
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div className="bg-indigo-100 text-indigo-700 p-2.5 rounded-xl">
            <Building2 size={24} />
          </div>
          <div>
            <h1 className="text-2xl font-black text-slate-800 tracking-tight">Company Master</h1>
            <p className="text-sm font-medium text-slate-500">Manage your own Transport Companies and Billing Entities (AP, BELL, etc.)</p>
          </div>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
        
        {/* LEFT FORM */}
        <div className="col-span-1 lg:col-span-5 space-y-4">
          
          {/* GST Search Box */}
          <div className="bg-white rounded-2xl shadow-sm border border-slate-200 p-5 relative overflow-hidden">
            <div className="absolute top-0 left-0 w-full h-1 bg-gradient-to-r from-indigo-500 to-purple-500"></div>
            <h3 className="font-bold text-slate-800 mb-3 flex items-center gap-2">
              <Search size={16} className="text-indigo-500"/> Search Government Database
            </h3>
            <div className="flex gap-2">
              <Input 
                placeholder="Enter 15-digit GSTIN" 
                value={searchGstin}
                onChange={e => setSearchGstin(e.target.value.toUpperCase())}
                className="flex-1 [&>input]:font-black [&>input]:tracking-widest"
              />
              <button 
                type="button"
                onClick={handleSearchGst}
                disabled={isSearchingGst}
                className="h-10 px-5 bg-indigo-600 hover:bg-indigo-700 text-white font-bold rounded-lg transition-all active:scale-95 disabled:bg-slate-300 disabled:cursor-not-allowed flex items-center gap-2"
              >
                {isSearchingGst ? 'Fetching...' : 'Fetch'}
              </button>
            </div>
            <p className="text-[10px] font-medium text-slate-400 mt-2">Fetches Legal Name, Address, and Status directly from NIC/WhiteBooks.</p>
          </div>

          {/* Form Fields */}
          <form onSubmit={handleSave} className="bg-white rounded-2xl shadow-sm border border-slate-200 p-5 space-y-4">
            <div className="grid grid-cols-1 gap-4">
              <Input label="Trade Name" value={formData.tradeName} onChange={e => setFormData({...formData, tradeName: e.target.value})} className="[&>input]:bg-indigo-50/50 [&>input]:font-black [&>input]:text-indigo-900" />
              <Input label="Legal Name" value={formData.legalName} onChange={e => setFormData({...formData, legalName: e.target.value})} />
              <Input label="GSTIN" value={formData.gstin} onChange={e => setFormData({...formData, gstin: e.target.value})} readOnly={!!formData.id} />
              
              <div className="grid grid-cols-2 gap-4">
                <Input label="City" value={formData.city} onChange={e => setFormData({...formData, city: e.target.value})} />
                <Input label="District" value={formData.district} onChange={e => setFormData({...formData, district: e.target.value})} />
              </div>
              <div className="grid grid-cols-2 gap-4">
                <Input label="State" value={formData.state} onChange={e => setFormData({...formData, state: e.target.value})} />
                <Input label="Pincode" value={formData.pincode} onChange={e => setFormData({...formData, pincode: e.target.value})} />
              </div>
              <Input label="Address" value={formData.address} onChange={e => setFormData({...formData, address: e.target.value})} />
              
              <div className="grid grid-cols-2 gap-4">
                <Input label="Phone (Optional)" value={formData.phone} onChange={e => setFormData({...formData, phone: e.target.value})} />
                <Input label="Email (Optional)" value={formData.email} onChange={e => setFormData({...formData, email: e.target.value})} />
              </div>
            </div>

            <div className="flex gap-3 pt-4 border-t border-slate-100">
              <button type="button" onClick={resetForm} className="h-10 px-5 bg-white border border-slate-200 text-slate-600 font-bold rounded-lg hover:bg-slate-50 transition-all flex-1">
                Clear
              </button>
              <button type="submit" disabled={loading} className="h-10 px-5 bg-slate-900 hover:bg-slate-800 text-white font-bold rounded-lg transition-all flex-[2] flex items-center justify-center gap-2">
                <Save size={16} /> {formData.id ? 'Update Company' : 'Save Company'}
              </button>
            </div>
          </form>
        </div>

        {/* RIGHT TABLE */}
        <div className="col-span-1 lg:col-span-7">
          <div className="bg-white rounded-2xl shadow-sm border border-slate-200 overflow-hidden">
            <div className="p-4 border-b border-slate-100 bg-slate-50/50">
              <h3 className="font-bold text-slate-800">Saved Companies ({companies.length})</h3>
            </div>
            <div className="overflow-x-auto">
              <table className="w-full text-left border-collapse">
                <thead>
                  <tr className="bg-slate-50/80 text-[10px] font-extrabold text-slate-500 uppercase tracking-wider border-b border-slate-200">
                    <th className="p-4">Trade Name</th>
                    <th className="p-4">GSTIN</th>
                    <th className="p-4">City</th>
                    <th className="p-4 text-center">Actions</th>
                  </tr>
                </thead>
                <tbody className="text-sm font-semibold text-slate-700 divide-y divide-slate-100">
                  {companies.length === 0 ? (
                    <tr>
                      <td colSpan="4" className="p-8 text-center text-slate-400">No companies saved yet.</td>
                    </tr>
                  ) : (
                    companies.map(comp => (
                      <tr key={comp.id} className="hover:bg-slate-50 transition-colors">
                        <td className="p-4 font-bold text-slate-900">{comp.tradeName}</td>
                        <td className="p-4 font-mono text-xs">{comp.gstin}</td>
                        <td className="p-4">{comp.city}</td>
                        <td className="p-4 flex items-center justify-center gap-2">
                          <button onClick={() => handleEdit(comp)} className="p-2 text-slate-400 hover:text-indigo-600 hover:bg-indigo-50 rounded-lg transition-all">
                            <Edit2 size={16} />
                          </button>
                          <button onClick={() => handleDelete(comp.id)} className="p-2 text-slate-400 hover:text-rose-600 hover:bg-rose-50 rounded-lg transition-all">
                            <Trash2 size={16} />
                          </button>
                        </td>
                      </tr>
                    ))
                  )}
                </tbody>
              </table>
            </div>
          </div>
        </div>

      </div>
    </div>
  );
}
