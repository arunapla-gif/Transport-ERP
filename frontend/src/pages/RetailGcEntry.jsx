import React, { useState } from 'react';
import { api } from '../api';
import { AsyncSearchableSelect } from '../components/ui/AsyncSearchableSelect';
import { DenseInput, GlassCard } from '../components/ui/DensePrimitives';
import { Button } from '../components/ui/Button';
import { Save, AlertCircle, CheckCircle, Plus, Search, Loader2, X } from 'lucide-react';

const SmartCustomerSelect = ({ 
  label, 
  endpoint, 
  value, 
  onChange, 
  onCityFetched,
  selectedObj,
  onClear,
  contactPhone,
  onContactPhoneChange
}) => {
  const [mode, setMode] = useState('search'); // 'search' or 'create'
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  
  const [formData, setFormData] = useState({
    name: '',
    phone: '',
    city: '',
    gstin: '',
    isURD: false
  });

  const handleVerifyGST = async () => {
    if (!formData.gstin) return setError('Enter GSTIN to verify');
    setLoading(true);
    setError('');
    try {
      const data = await api.verifyGST(formData.gstin);
      const info = data.taxpayerInfo;
      if (!info) throw new Error('Invalid GSTIN details');
      
      const addr = info.pradr?.addr || {};
      const companyName = info.tradeNam || info.lgnm || '';
      
      setFormData(prev => ({
        ...prev,
        name: companyName,
        city: addr.loc || addr.city || ''
      }));
    } catch (err) {
      setError(err.message || 'Failed to verify GSTIN');
    } finally {
      setLoading(false);
    }
  };

  const handleCreate = async () => {
    setError('');
    if (!formData.name) return setError('Name is required');
    if (!formData.phone) return setError('Phone Number is required');
    
    setLoading(true);
    try {
      const branch = localStorage.getItem('activeBranch') || 'MAIN';
      const payload = {
        name: formData.name,
        phone: formData.phone,
        city: formData.city,
        gstin: formData.isURD ? 'URP' : formData.gstin,
        migrationType: 'RETAIL_WITH_PHONE',
        branch
      };
      
      const res = await api.post(endpoint, payload);
      const newId = res.id;
      
      // Auto-select the newly created customer
      onChange(
        { value: newId, label: `${formData.name}` }, 
        { ...payload, id: newId }
      );
      
      if (onCityFetched) onCityFetched(formData.city);
      
      setMode('search');
    } catch (err) {
      setError(err.response?.data?.error || err.message || 'Failed to create customer');
    } finally {
      setLoading(false);
    }
  };

  if (selectedObj) {
    return (
      <div className="bg-white border-2 border-indigo-100 rounded-xl p-3 shadow-sm relative group transition-all hover:border-indigo-200">
        <button 
          onClick={onClear} 
          className="absolute top-2 right-2 p-1.5 bg-slate-100 text-slate-400 hover:text-rose-500 hover:bg-rose-50 rounded-full transition-colors"
          title="Change Customer"
        >
          <X size={14} />
        </button>
        <div className="flex flex-col gap-0.5 pr-8">
          <span className="font-bold text-slate-800">{selectedObj.name}</span>
          <div className="flex items-center gap-2 text-[10px] text-slate-500 font-medium">
            {selectedObj.city && <span>🏙️ {selectedObj.city}</span>}
            {selectedObj.gstin && selectedObj.gstin !== 'URP' && <span>📝 {selectedObj.gstin}</span>}
            {(!selectedObj.gstin || selectedObj.gstin === 'URP') && <span>📝 No GST</span>}
          </div>
        </div>
        <div className="mt-3 pt-3 border-t border-indigo-50">
          <label className="text-[10px] font-bold text-slate-500 uppercase tracking-wider mb-1 flex items-center justify-between">
            <span>Contact Phone <span className="text-slate-400 lowercase normal-case">(for this parcel)</span></span>
            {!contactPhone && <span className="text-rose-500">Required *</span>}
          </label>
          <input
            type="text"
            className={`w-full h-8 px-2.5 text-sm border rounded-lg outline-none transition-all ${!contactPhone ? 'border-rose-300 focus:border-rose-500 focus:ring-1 focus:ring-rose-500 bg-rose-50/30' : 'border-slate-200 focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500'}`}
            placeholder="Enter driver/walk-in phone..."
            value={contactPhone}
            onChange={e => onContactPhoneChange(e.target.value)}
          />
        </div>
      </div>
    );
  }

  if (mode === 'search') {
    return (
      <div className="space-y-2">
        <label className="text-[11px] font-bold text-slate-500 uppercase tracking-wider mb-1 block">{label} (Search Name/Phone)</label>
        <div className="flex gap-2">
          <div className="flex-1">
            <AsyncSearchableSelect
              fetchOptions={async (q) => {
                if (!q) return [];
                const res = await api.get(`${endpoint}/search?q=${encodeURIComponent(q)}&branch=${localStorage.getItem('activeBranch') || 'MAIN'}`);
                return res.map(item => ({
                  value: item.id,
                  label: item.name,
                  ...item
                }));
              }}
              placeholder={`Search ${label}...`}
              value={value}
              onChange={(val, fullObj) => {
                onChange(val, fullObj);
                if (onCityFetched && fullObj?.city) onCityFetched(fullObj.city);
              }}
              formatOptionLabel={(opt) => (
                <div className="flex flex-col">
                  <span className="font-bold">{opt.name}</span>
                  <span className="text-[10px] text-slate-500">{opt.phone || 'No Phone'} • {opt.city || 'No City'}</span>
                </div>
              )}
            />
          </div>
          <Button variant="secondary" onClick={() => setMode('create')} className="px-3 flex-shrink-0 bg-slate-100 hover:bg-slate-200" title="Add New Customer">
            <Plus size={16} />
          </Button>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-3 p-3 bg-slate-50/80 border border-slate-200 rounded-xl relative">
      <div className="flex justify-between items-center border-b border-slate-200 pb-2 mb-1">
        <h4 className="text-xs font-bold text-slate-700">Add New {label}</h4>
        <button onClick={() => setMode('search')} className="text-[10px] font-bold text-slate-400 hover:text-slate-600 uppercase tracking-wider">Cancel</button>
      </div>
      
      {error && <div className="text-[10px] text-rose-500 font-bold px-1">{error}</div>}

      <div className="space-y-3">
        <div className="flex flex-col gap-1">
          <div className="flex justify-between items-center px-1">
            <label className="text-[10px] font-bold text-slate-500 uppercase tracking-wider">GSTIN (Optional)</label>
            <label className="flex items-center gap-1 cursor-pointer">
              <input type="checkbox" checked={formData.isURD} onChange={e => setFormData(p => ({ ...p, isURD: e.target.checked, gstin: '' }))} className="w-3 h-3 text-emerald-600 rounded" />
              <span className="text-[9px] font-bold text-slate-600">Unregistered</span>
            </label>
          </div>
          <div className="flex gap-2">
            <input 
              className={`flex-1 h-9 px-2.5 border border-slate-200 rounded-lg text-sm uppercase ${formData.isURD ? 'bg-slate-100 text-slate-400' : 'bg-white'}`}
              value={formData.gstin}
              onChange={e => setFormData(p => ({ ...p, gstin: e.target.value.toUpperCase() }))}
              disabled={formData.isURD}
              placeholder="e.g. 27AADCB2230M1Z2"
            />
            <Button variant="secondary" onClick={handleVerifyGST} disabled={loading || formData.isURD || !formData.gstin} className="px-3 h-9 text-xs">
              Verify
            </Button>
          </div>
        </div>
        
        <DenseInput label="Name *" value={formData.name} onChange={e => setFormData(p => ({ ...p, name: e.target.value }))} className="[&>input]:bg-white" />
        <div className="flex gap-2">
          <DenseInput label="Phone *" value={formData.phone} onChange={e => setFormData(p => ({ ...p, phone: e.target.value }))} className="flex-1 [&>input]:bg-white" />
          <DenseInput label="City" value={formData.city} onChange={e => setFormData(p => ({ ...p, city: e.target.value }))} className="flex-1 [&>input]:bg-white" />
        </div>
        
        <Button variant="primary" onClick={handleCreate} disabled={loading} className="w-full h-9 text-xs bg-slate-800 hover:bg-slate-900 mt-2">
          {loading ? <Loader2 className="w-4 h-4 animate-spin mx-auto" /> : `Create & Select ${label}`}
        </Button>
      </div>
    </div>
  );
};

export default function RetailGcEntry() {
  const branch = localStorage.getItem('activeBranch') || 'MAIN';
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');

  const [formData, setFormData] = useState({
    consignorId: '',
    senderContactPhone: '',
    consigneeId: '',
    receiverContactPhone: '',
    articles: '',
    freightType: 'To Pay',
    freightTotal: '',
    destinationCity: '',
    godown: '1'
  });

  const [selectedSender, setSelectedSender] = useState(null);
  const [selectedReceiver, setSelectedReceiver] = useState(null);

  const handleSave = async (e) => {
    e.preventDefault();
    setError('');
    
    if (!formData.consignorId) return setError("Please select a Sender (Consignor)");
    if (!formData.consigneeId) return setError("Please select a Receiver (Consignee)");
    if (!formData.senderContactPhone) return setError("Sender contact phone is required for this parcel");
    if (!formData.receiverContactPhone) return setError("Receiver contact phone is required for this parcel");
    if (!formData.articles) return setError("Number of articles is required");
    if (!formData.freightTotal) return setError("Freight amount is required");
    
    setLoading(true);
    
    try {
      const payload = {
        gcNumber: `RET-${Date.now().toString().slice(-6)}`,
        branch,
        financialYear: '2026-2027',
        type: 'RETAIL',
        date: new Date().toISOString().split('T')[0],
        time: new Date().toTimeString().split(' ')[0].substring(0, 5),
        status: 'Created',
        godown: formData.godown,
        
        consignorId: parseInt(formData.consignorId),
        consigneeId: parseInt(formData.consigneeId),
        senderContactPhone: formData.senderContactPhone,
        receiverContactPhone: formData.receiverContactPhone,
        
        freightType: formData.freightType,
        freightTotal: parseFloat(formData.freightTotal) || 0,
        freightRate: 0,
        advancePaid: 0,
        balanceFreight: parseFloat(formData.freightTotal) || 0,
        freightFixed: 'Yes',
        
        actualWeight: 'FIXED',
        invoiceValue: 0,
        
        goods: [{
          articles: parseInt(formData.articles),
          units: 'Parcels',
          description: 'Retail Goods',
          weight: 10,
          rate: 0,
          amount: parseFloat(formData.freightTotal) || 0
        }]
      };

      await api.post('/gcs', payload);
      setSuccess('Retail Bill created successfully!');
      
      setFormData({
        consignorId: '', senderContactPhone: '', consigneeId: '', receiverContactPhone: '', articles: '', freightType: 'To Pay', freightTotal: '', destinationCity: '', godown: '1'
      });
      setSelectedSender(null);
      setSelectedReceiver(null);
      // A small hack to force re-render of SmartCustomerSelects (clearing their selected value visual)
      window.scrollTo({ top: 0, behavior: 'smooth' });
      setTimeout(() => setSuccess(''), 3000);
    } catch (err) {
      setError(err.response?.data?.error || err.message || 'Failed to save Retail GC');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="max-w-4xl mx-auto space-y-4">
      <div className="flex items-center justify-between">
        <h1 className="text-xl md:text-2xl font-black text-slate-800 tracking-tight flex items-center gap-2">
          Retail Quick Bill
          <span className="bg-emerald-100 text-emerald-800 text-[10px] px-2 py-0.5 rounded-full uppercase tracking-wider font-bold">Fast Lane</span>
        </h1>
      </div>

      {error && (
        <div className="bg-rose-50 text-rose-600 p-3 rounded-lg flex items-center gap-2 text-sm font-bold border border-rose-200">
          <AlertCircle size={16} /> {error}
        </div>
      )}

      {success && (
        <div className="bg-emerald-50 text-emerald-600 p-3 rounded-lg flex items-center gap-2 text-sm font-bold border border-emerald-200">
          <CheckCircle size={16} /> {success}
        </div>
      )}

      <GlassCard className="!p-6 space-y-6">
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div className="space-y-4">
            <h3 className="font-bold text-sm text-slate-800 border-b pb-2">Sender (From)</h3>
            <SmartCustomerSelect 
              label="Sender"
              endpoint="/consignors"
              value={formData.consignorId}
              onChange={(val, fullObj) => {
                setFormData(p => ({ ...p, consignorId: val?.value || '', senderContactPhone: fullObj?.phone || '' }));
                setSelectedSender(fullObj || null);
              }}
              selectedObj={selectedSender}
              onClear={() => {
                setFormData(p => ({ ...p, consignorId: '', senderContactPhone: '' }));
                setSelectedSender(null);
              }}
              contactPhone={formData.senderContactPhone}
              onContactPhoneChange={(val) => setFormData(p => ({ ...p, senderContactPhone: val }))}
            />
          </div>

          <div className="space-y-4">
            <h3 className="font-bold text-sm text-slate-800 border-b pb-2">Receiver (To)</h3>
            <SmartCustomerSelect 
              label="Receiver"
              endpoint="/consignees"
              value={formData.consigneeId}
              onChange={(val, fullObj) => {
                setFormData(p => ({ ...p, consigneeId: val?.value || '', destinationCity: fullObj?.city || p.destinationCity, receiverContactPhone: fullObj?.phone || '' }));
                setSelectedReceiver(fullObj || null);
              }}
              onCityFetched={(city) => setFormData(p => ({ ...p, destinationCity: city || p.destinationCity }))}
              selectedObj={selectedReceiver}
              onClear={() => {
                setFormData(p => ({ ...p, consigneeId: '', receiverContactPhone: '' }));
                setSelectedReceiver(null);
              }}
              contactPhone={formData.receiverContactPhone}
              onContactPhoneChange={(val) => setFormData(p => ({ ...p, receiverContactPhone: val }))}
            />
            
            <DenseInput 
              label="Destination City" 
              value={formData.destinationCity} 
              readOnly 
              className="bg-slate-50"
            />
          </div>
        </div>
        
        <div className="border-t border-slate-100 my-4" />

        <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
          <DenseInput 
            label="No. of Articles *" 
            type="number" 
            value={formData.articles} 
            onChange={e => setFormData(p => ({ ...p, articles: e.target.value }))} 
            className="[&>input]:text-lg [&>input]:font-bold"
          />
          
          <div className="flex flex-col group">
            <label className="text-[11px] font-bold text-slate-500 uppercase tracking-wider mb-1">Freight Type</label>
            <select 
              className="w-full h-12 px-3 border border-slate-200 rounded-xl bg-white text-sm font-bold text-slate-800 focus:outline-none focus:border-emerald-500 focus:ring-2 focus:ring-emerald-500/20"
              value={formData.freightType}
              onChange={e => setFormData(p => ({ ...p, freightType: e.target.value }))}
            >
              <option value="To Pay">To Pay</option>
              <option value="Paid">Paid</option>
              <option value="Billed">Billed</option>
            </select>
          </div>

          <DenseInput 
            label="Freight Amount (₹) *" 
            type="number" 
            value={formData.freightTotal} 
            onChange={e => setFormData(p => ({ ...p, freightTotal: e.target.value }))} 
            className="md:col-span-2 [&>input]:text-xl [&>input]:font-black [&>input]:text-emerald-700"
          />
        </div>
        
        <div className="flex justify-end pt-4">
          <Button 
            variant="primary" 
            onClick={handleSave} 
            disabled={loading} 
            className="h-14 px-10 text-lg flex items-center gap-2 bg-emerald-600 hover:bg-emerald-700"
          >
            <Save size={20} /> {loading ? 'Saving...' : 'Generate Quick Bill'}
          </Button>
        </div>
      </GlassCard>
    </div>
  );
}
