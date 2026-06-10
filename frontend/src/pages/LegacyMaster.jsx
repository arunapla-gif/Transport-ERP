import React, { useState, useEffect } from 'react';
import * as XLSX from 'xlsx';
import { api } from '../api';

const LegacyMaster = () => {
  const [data, setData] = useState([]);
  const [loading, setLoading] = useState(false);
  const [errorMsg, setErrorMsg] = useState(null);
  const [uploading, setUploading] = useState(false);
  const [partyType, setPartyType] = useState('CONSIGNOR'); // 'CONSIGNOR' or 'CONSIGNEE'

  useEffect(() => {
    fetchData();
  }, []);

  const fetchData = async () => {
    try {
      setLoading(true);
      setErrorMsg(null);
      const data = await api.get('/legacy-master');
      setData(data);
    } catch (err) {
      console.error(err);
      setErrorMsg(err.message || 'Unknown error');
      // alert('Failed to fetch staging data'); // Disabled alert to prevent spam
    } finally {
      setLoading(false);
    }
  };

  const handleFileUpload = (e) => {
    const file = e.target.files[0];
    if (!file) return;

    setUploading(true);
    const reader = new FileReader();
    reader.onload = async (evt) => {
      try {
        const bstr = evt.target.result;
        const wb = XLSX.read(bstr, { type: 'binary' });
        const wsname = wb.SheetNames[0];
        const ws = wb.Sheets[wsname];
        const rawData = XLSX.utils.sheet_to_json(ws);
        
        await api.post('/legacy-master/upload', { rows: rawData, partyType });
        alert('Data uploaded successfully to Staging');
        fetchData();
      } catch (err) {
        console.error(err);
        alert('Upload failed');
      } finally {
        setUploading(false);
      }
    };
    reader.readAsBinaryString(file);
  };

  const fetchApiForRecord = async (id) => {
    try {
      const updatedRecord = await api.post(`/legacy-master/fetch-api/${id}`);
      // Update local state
      setData(prev => prev.map(item => item.id === id ? updatedRecord : item));
    } catch (err) {
      console.error(err);
      alert('API Fetch failed for this record');
      fetchData(); // Refresh to get FAILED status
    }
  };

  const fetchAllPending = async () => {
    const pendingWithGstin = data.filter(d => 
      (d.status === 'PENDING' || d.status === 'FAILED_FETCH') && 
      d.oldGstin && 
      d.oldGstin.trim().length === 15
    );
    
    if (pendingWithGstin.length === 0) {
      return alert('No pending or failed records with valid GSTIN found.');
    }

    if (!window.confirm(`Found ${pendingWithGstin.length} pending/failed records with GSTIN. Start fetching?`)) return;

    for (let i = 0; i < pendingWithGstin.length; i++) {
      const record = pendingWithGstin[i];
      // Optional: Add artificial delay if needed to avoid rate limits
      await new Promise(r => setTimeout(r, 1000));
      await fetchApiForRecord(record.id);
    }
    alert('Batch fetch complete!');
  };

  const approveRecord = async (id, useApiData, mergeTradeName) => {
    try {
      await api.post(`/legacy-master/approve/${id}`, { useApiData, mergeTradeName });
      setData(prev => prev.map(item => item.id === id ? { ...item, status: 'APPROVED' } : item));
    } catch (err) {
      console.error(err);
      alert('Failed to approve and migrate record');
    }
  };

  const massMigrateReady = async () => {
    const readyRecords = data.filter(d => d.partyType === partyType && d.status === 'READY');
    if (readyRecords.length === 0) {
      return alert('No READY records found to migrate. Please fetch them first.');
    }
    
    if (!window.confirm(`Are you sure you want to MASS MIGRATE ${readyRecords.length} records into your live master? This will merge the API name with your Excel name.`)) return;

    let successCount = 0;
    for (const record of readyRecords) {
      try {
        await api.post(`/legacy-master/approve/${record.id}`, { useApiData: true, mergeTradeName: true });
        setData(prev => prev.map(item => item.id === record.id ? { ...item, status: 'APPROVED' } : item));
        successCount++;
      } catch (err) {
        console.error(`Failed to mass migrate ${record.id}`);
      }
    }
    alert(`Mass Migration complete! Successfully migrated ${successCount}/${readyRecords.length} records.`);
  };

  return (
    <div className="p-6">
      <div className="flex justify-between items-center mb-6">
        <h1 className="text-2xl font-bold text-gray-800">Legacy Master Staging</h1>
        <div className="flex space-x-4">
          <select 
            value={partyType} 
            onChange={(e) => setPartyType(e.target.value)}
            className="border p-2 rounded"
          >
            <option value="CONSIGNOR">Consignors (Book2)</option>
            <option value="CONSIGNEE">Consignees (Book1)</option>
          </select>
          <div className="relative">
            <input 
              type="file" 
              accept=".xlsx, .xls" 
              onChange={handleFileUpload}
              className="absolute inset-0 w-full h-full opacity-0 cursor-pointer"
            />
            <button className="bg-blue-600 text-white px-4 py-2 rounded shadow hover:bg-blue-700">
              {uploading ? 'Uploading...' : 'Upload Excel'}
            </button>
          </div>
          <button 
            onClick={fetchAllPending}
            className="bg-green-600 text-white px-4 py-2 rounded shadow hover:bg-green-700 font-bold"
          >
            Batch Fetch API
          </button>
          
          <button 
            onClick={massMigrateReady}
            className="bg-indigo-600 text-white px-4 py-2 rounded shadow hover:bg-indigo-700 font-bold"
          >
            Migrate All READY to Live
          </button>
        </div>
      </div>

      {loading ? (
        <p>Loading staging data...</p>
      ) : (
        <div className="bg-white shadow rounded-lg overflow-x-auto">
          <table className="min-w-full divide-y divide-gray-200 text-sm">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-4 py-3 text-left font-medium text-gray-500">Status</th>
                <th className="px-4 py-3 text-left font-medium text-gray-500">Old Data (Excel)</th>
                <th className="px-4 py-3 text-left font-medium text-gray-500">New Data (API)</th>
                <th className="px-4 py-3 text-left font-medium text-gray-500">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200">
              {data.filter(d => d.partyType === partyType).map(row => (
                <tr key={row.id} className={row.status === 'APPROVED' ? 'bg-green-50' : 'bg-white'}>
                  <td className="px-4 py-4">
                    <span className={`px-2 py-1 rounded text-xs font-semibold ${
                      row.status === 'APPROVED' ? 'bg-green-100 text-green-800' :
                      row.status === 'FAILED_FETCH' ? 'bg-red-100 text-red-800' :
                      row.status === 'PENDING' && row.apiName ? 'bg-blue-100 text-blue-800' :
                      'bg-gray-100 text-gray-800'
                    }`}>
                      {row.status === 'PENDING' && row.apiName ? 'READY' : row.status}
                    </span>
                    {row.provider && <div className="text-xs text-gray-500 mt-1">via {row.provider}</div>}
                  </td>
                  
                  {/* OLD DATA */}
                  <td className="px-4 py-4">
                    <div className="font-medium text-gray-900">{row.oldName || '-'}</div>
                    <div className="text-gray-500 text-xs break-all">{row.oldGstin || 'No GSTIN'}</div>
                    <div className="text-gray-500 text-xs mt-1">
                      {row.oldAddress} {row.oldCity}
                    </div>
                    {row.oldPhone && <div className="text-blue-600 text-xs mt-1">📞 {row.oldPhone}</div>}
                  </td>
                  
                  {/* NEW DATA */}
                  <td className="px-4 py-4 border-l">
                    {row.apiName ? (
                      <>
                        <div className="font-medium text-blue-900">{row.apiName}</div>
                        {row.apiLegalName && row.apiLegalName !== row.apiName && (
                          <div className="text-xs text-indigo-700 font-medium mt-1">Legal: {row.apiLegalName}</div>
                        )}
                        {Array.isArray(row.apiTradeNames) && row.apiTradeNames.length > 0 && row.apiTradeNames[0] !== row.apiName && (
                          <div className="text-xs text-indigo-700 font-medium mt-0.5">Trade: {row.apiTradeNames.join(', ')}</div>
                        )}
                        <div className="text-gray-600 text-xs mt-1">
                          {row.apiAddress}, {row.apiCity}, {row.apiState} {row.apiPincode}
                        </div>
                        {Array.isArray(row.apiAddresses) && row.apiAddresses.length > 0 && (
                          <div className="text-xs text-amber-600 font-medium mt-1 bg-amber-50 inline-block px-1.5 py-0.5 rounded border border-amber-200">
                            +{row.apiAddresses.length} Additional Addresses
                          </div>
                        )}
                      </>
                    ) : (
                      <span className="text-gray-400 italic">Not fetched</span>
                    )}
                  </td>
                  
                  {/* ACTIONS */}
                  <td className="px-4 py-4">
                    {row.status !== 'APPROVED' && (
                      <div className="space-y-2">
                        {(!row.apiName && row.oldGstin?.trim().length === 15) && (
                          <button 
                            onClick={() => fetchApiForRecord(row.id)}
                            className="w-full text-xs bg-indigo-100 text-indigo-700 px-2 py-1 rounded hover:bg-indigo-200 transition"
                          >
                            Fetch API
                          </button>
                        )}
                        
                        {row.apiName && (
                          <>
                            <button 
                              onClick={() => approveRecord(row.id, true, false)}
                              className="w-full text-xs bg-green-100 text-green-700 px-2 py-1 rounded hover:bg-green-200 transition"
                            >
                              Approve (Use API Data)
                            </button>
                            <button 
                              onClick={() => approveRecord(row.id, true, true)}
                              className="w-full text-xs bg-emerald-100 text-emerald-700 px-2 py-1 rounded hover:bg-emerald-200 transition"
                            >
                              Approve (Merge Name)
                            </button>
                          </>
                        )}
                        
                        <button 
                          onClick={() => approveRecord(row.id, false, false)}
                          className="w-full text-xs bg-gray-100 text-gray-700 px-2 py-1 rounded hover:bg-gray-200 transition"
                        >
                          Approve (Keep Old Data)
                        </button>
                      </div>
                    )}
                  </td>
                </tr>
              ))}
              {data.filter(d => d.partyType === partyType).length === 0 && (
                <tr>
                  <td colSpan="4" className="text-center py-8 text-gray-500">
                    <div className="text-lg font-bold mb-2">No {partyType} records found in Staging.</div>
                    
                    {errorMsg && (
                      <div className="mt-4 mb-4 p-4 bg-red-100 text-red-700 rounded-lg inline-block border border-red-300">
                        <strong className="block mb-1">Backend Connection Error:</strong>
                        <span className="font-mono text-sm">{errorMsg}</span>
                      </div>
                    )}
                    
                    <div className="text-sm">If you expect data here, the backend fetch might have failed. Please use the "Upload Excel" button above.</div>
                    <div className="mt-4 text-xs bg-gray-100 inline-block p-2 rounded">Total records in database: {data.length || 0}</div>
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
};

export default LegacyMaster;
