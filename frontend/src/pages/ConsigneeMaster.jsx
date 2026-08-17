import { useState, useEffect, useRef } from 'react';
import { api } from '../api';
import toast from 'react-hot-toast';
import { useKeyboardFlow } from '../hooks/useKeyboardFlow';
import { Edit2, Trash2, MapPin, Save, Search } from 'lucide-react';
import { Button } from '../components/ui/Button';

import { useLocation } from 'react-router-dom';
import ConsigneeForm, { GlassCard } from '../components/masters/ConsigneeForm';
import ConsigneeTable from '../components/masters/ConsigneeTable';

const stateNameToCode = {
  "jammu and kashmir": "01", "himachal pradesh": "02", "punjab": "03", "chandigarh": "04",
  "uttarakhand": "05", "haryana": "06", "delhi": "07", "rajasthan": "08", "uttar pradesh": "09",
  "bihar": "10", "sikkim": "11", "arunachal pradesh": "12", "nagaland": "13", "manipur": "14",
  "mizoram": "15", "tripura": "16", "meghalaya": "17", "assam": "18", "west bengal": "19",
  "jharkhand": "20", "odisha": "21", "chhattisgarh": "22", "madhya pradesh": "23",
  "gujarat": "24", "daman and diu": "25", "dadra and nagar haveli and daman and diu": "26",
  "maharashtra": "27", "andhra pradesh": "28", "karnataka": "29", "goa": "30",
  "lakshadweep": "31", "kerala": "32", "tamil nadu": "33", "puducherry": "34",
  "andaman and nicobar islands": "35", "telangana": "36", "ladakh": "38"
};

export default function ConsigneeMaster() {
  const location = useLocation();
  const query = new URLSearchParams(location.search);
  const branch = query.get('branch') || 'MAIN';

  const [consignees, setConsignees] = useState([]);
  const [formData, setFormData] = useState({
    id: null, name: '', address: '', city: '', district: '', state: '', stateCode: '', pincode: '', gstin: '', phone: '', email: '', group: '', addresses: [], parentId: ''
  });
  const [loading, setLoading] = useState(false);
  const [searchTerm, setSearchTerm] = useState('');
  const [activeTab, setActiveTab] = useState('API_ONLY');

  useKeyboardFlow({
    onSave: (e) => handleSave(e || { preventDefault: () => {} })
  });

  const [page, setPage] = useState(1);
  const [hasMore, setHasMore] = useState(true);
  const [totalRecords, setTotalRecords] = useState(0);
  const desktopObserverRef = useRef(null);
  const mobileObserverRef = useRef(null);

  const [debouncedSearch, setDebouncedSearch] = useState('');
  useEffect(() => {
    const timer = setTimeout(() => setDebouncedSearch(searchTerm), 400);
    return () => clearTimeout(timer);
  }, [searchTerm]);

  useEffect(() => {
    setPage(1);
    setConsignees([]);
    setHasMore(true);
  }, [debouncedSearch, branch]);

  const fetchConsignees = async (pageNum = page) => {
    try {
      setLoading(true);
      const url = `/consignees?branch=${branch}&page=${pageNum}&limit=50&q=${encodeURIComponent(debouncedSearch)}`;
      const res = await api.get(url);
      
      if (res.data) {
         setConsignees(prev => {
            if (pageNum === 1) return res.data;
            const existingIds = new Set(prev.map(p => p.id));
            const newItems = res.data.filter(d => !existingIds.has(d.id));
            return [...prev, ...newItems];
         });
         setHasMore(res.hasMore);
         setTotalRecords(res.total);
      } else {
         setConsignees(res); // legacy fallback
         setHasMore(false);
      }
    } catch (err) {
      toast.error('Failed to fetch data.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchConsignees(page);
  }, [page, debouncedSearch, branch]);

  useEffect(() => {
    const observer = new IntersectionObserver(
      entries => {
        const isIntersecting = entries.some(entry => entry.isIntersecting);
        if (isIntersecting && hasMore && !loading) {
          setPage(prev => prev + 1);
        }
      },
      { threshold: 0, rootMargin: '1500px' }
    );
    if (desktopObserverRef.current) observer.observe(desktopObserverRef.current);
    if (mobileObserverRef.current) observer.observe(mobileObserverRef.current);
    return () => observer.disconnect();
  }, [hasMore, loading]);

  const updateConsigneeName = async (id, newName) => {
    try {
      await api.put(`/consignees/${id}`, { name: newName });
      toast.success('Primary name updated!');
      fetchConsignees();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Failed to update name');
    }
  };

  const handleVerifyGST = async () => {
    if (!formData.gstin) return toast.error('Please enter a GSTIN to verify');
    setLoading(true);
    
    try {
      const data = await api.verifyGST(formData.gstin);
      const info = data.taxpayerInfo;
      if (!info) throw new Error('Invalid GSTIN details');
      const addr = info.pradr?.addr || {};
      
      const companyName = info.tradeNam || info.lgnm || '';
      
      const cleanAddressParts = (parts) => {
        let joined = parts.filter(Boolean).join(', ');
        if (!companyName) return joined;
        
        try {
          const cleanName = companyName.replace(/[^a-zA-Z0-9 ]/g, '').trim();
          if (cleanName) {
            const regexPattern = cleanName.split(/\s+/).join('\\s*[^a-zA-Z0-9]*\\s*');
            const regex = new RegExp('^' + regexPattern + '\\s*[^a-zA-Z0-9]*\\s*', 'i');
            joined = joined.replace(regex, '');
          }
        } catch {
          // Fallback if regex fails
        }
        
        return joined;
      };

      const additionalAddresses = (info.adadr || []).map(a => {
        const adr = a.addr || {};
        return {
          address: cleanAddressParts([adr.bno, adr.bnm, adr.st, adr.flno]),
          city: adr.loc || adr.city || '',
          district: adr.dst || '',
          state: adr.stcd || '',
          pincode: adr.pncd || adr.pincode || ''
        };
      });

      setFormData(prev => {
        const rawState = addr.stcd || '';
        let mappedStateCode = prev.stateCode;
        if (rawState) {
          const normalized = rawState.trim().toLowerCase();
          if (stateNameToCode[normalized]) {
            mappedStateCode = stateNameToCode[normalized];
          }
        }

        return {
          ...prev,
          name: companyName || prev.name,
          legalName: info.lgnm || prev.legalName,
          address: cleanAddressParts([addr.bno, addr.bnm, addr.st, addr.flno]) || prev.address,
          city: addr.loc || addr.city || prev.city,
          district: addr.dst || prev.district,
          state: rawState || prev.state,
          stateCode: mappedStateCode || rawState,
          pincode: addr.pncd || addr.pincode || prev.pincode,
          addresses: additionalAddresses
        };
      });
      toast.success('GST verified and details auto-filled!');
    } catch (err) {
      toast.error(err.message || 'Failed to verify GSTIN');
    } finally {
      setLoading(false);
    }
  };

  const handleSave = async (e) => {
    e.preventDefault();
    if (!formData.name.trim()) return toast.error('Consignee Name is required');
    setLoading(true);
    try {
      const dataToCreate = { ...formData };
      delete dataToCreate.id;
      const payload = { ...dataToCreate, migrationType: 'GST_VERIFIED', branch, parentId: formData.parentId || null };
      if (formData.id) {
        await api.put(`/consignees/${formData.id}`, { ...payload, id: formData.id });
        toast.success('Updated successfully');
      } else {
        await api.post('/consignees', payload);
        toast.success('Added successfully');
      }
      setFormData({ id: null, name: '', address: '', city: '', district: '', state: '', stateCode: '', pincode: '', gstin: '', phone: '', email: '', group: '', addresses: [], parentId: '' });
      fetchConsignees(1);
    } catch (err) {
      toast.error(err.response?.data?.error || 'Operation failed');
    } finally {
      setLoading(false);
    }
  };

  const handleEdit = (consignee) => {
    setFormData({
      id: consignee.id,
      name: consignee.name || '', legalName: consignee.legalName || '', address: consignee.address || '', city: consignee.city || '', 
      district: consignee.district || '', state: consignee.state || '', stateCode: consignee.stateCode || '', pincode: consignee.pincode || '', 
      gstin: consignee.gstin || '', phone: consignee.phone || '', email: consignee.email || '', group: consignee.group || '', 
      addresses: consignee.addresses || [], parentId: consignee.parentId || ''
    });
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  const handleDelete = async (id) => {
    if (!window.confirm('Are you sure you want to archive this record?')) return;
    try {
      await api.delete(`/consignees/${id}`);
      fetchConsignees();
      toast.success('Record archived');
    } catch {
      toast.error('Failed to archive record');
    }
  };

  const handleRestore = async (id) => {
    try {
      await api.put(`/consignees/${id}/restore`);
      fetchConsignees();
      toast.success('Record restored successfully');
    } catch {
      toast.error('Failed to restore record');
    }
  };

  const apiOnlyCount = consignees.filter(c => !c.migrationType || c.migrationType === 'API_ONLY' || c.migrationType === 'MANUAL' || c.migrationType === 'EWB_LITE' || c.migrationType === 'GST_VERIFIED').length;
  const oldDataCount = consignees.filter(c => c.migrationType === 'OLD_DATA_ONLY').length;
  const retailPhoneCount = consignees.filter(c => c.migrationType === 'RETAIL_WITH_PHONE').length;
  const retailNoPhoneCount = consignees.filter(c => c.migrationType === 'RETAIL_NO_PHONE').length;

  const filteredConsignees = consignees.filter(c => {
    const matchesSearch = c.name.toLowerCase().includes(searchTerm.toLowerCase()) || 
      (c.gstin && c.gstin.toLowerCase().includes(searchTerm.toLowerCase())) ||
      (c.city && c.city.toLowerCase().includes(searchTerm.toLowerCase()));
      
    if (activeTab === 'API_ONLY') return matchesSearch && (!c.migrationType || c.migrationType === 'API_ONLY' || c.migrationType === 'MANUAL' || c.migrationType === 'EWB_LITE' || c.migrationType === 'GST_VERIFIED');
    if (activeTab === 'OLD_DATA_ONLY') return matchesSearch && c.migrationType === 'OLD_DATA_ONLY';
    if (activeTab === 'RETAIL_WITH_PHONE') return matchesSearch && c.migrationType === 'RETAIL_WITH_PHONE';
    if (activeTab === 'RETAIL_NO_PHONE') return matchesSearch && c.migrationType === 'RETAIL_NO_PHONE';
    return false;
  });

  return (
    <div className="space-y-4 max-w-[1200px] mx-auto pb-10" style={{ fontFamily: '"Inter", system-ui, sans-serif' }}>
      
      {/* HEADER CARD */}
      <GlassCard className="!p-4">
        <div className="flex items-center gap-3">
          <div className="bg-emerald-50 text-emerald-600 p-2 rounded-xl shadow-inner border border-emerald-100/50">
            <MapPin size={20} />
          </div>
          <div>
            <h2 className="font-bold text-lg text-slate-800 tracking-tight">Consignee Master</h2>
            <p className="text-xs font-medium text-slate-500">Manage consignee profiles, delivery addresses, and GSTIN details.</p>
          </div>
        </div>
      </GlassCard>

      {/* FORM CARD */}
      <ConsigneeForm 
        formData={formData}
        setFormData={setFormData}
        consignees={consignees}
        handleVerifyGST={handleVerifyGST}
        handleSave={handleSave}
        loading={loading}
      />

      {/* LIST CARD */}
      <ConsigneeTable 
        consignees={consignees}
        loading={loading}
        hasMore={hasMore}
        searchTerm={searchTerm}
        setSearchTerm={setSearchTerm}
        activeTab={activeTab}
        setActiveTab={setActiveTab}
        desktopObserverRef={desktopObserverRef}
        mobileObserverRef={mobileObserverRef}
        updateConsigneeName={updateConsigneeName}
        handleEdit={handleEdit}
        handleDelete={handleDelete}
        handleRestore={handleRestore}
      />
    </div>
  );
}
