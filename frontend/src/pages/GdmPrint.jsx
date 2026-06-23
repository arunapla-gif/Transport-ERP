import React, { useEffect, useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { api } from '../api';

export default function GdmPrint() {
  const { id } = useParams();
  const navigate = useNavigate();
  const [gdms, setGdms] = useState([]);
  const [error, setError] = useState('');
  const [allUnitOptions, setAllUnitOptions] = useState([]);

  useEffect(() => {
    const fetchData = async () => {
      try {
        const [gdmData, unitsRes] = await Promise.all([
          api.get(`/gdms/${id}`),
          api.get('/units').catch(() => [])
        ]);
        
        if (unitsRes && unitsRes.length > 0) {
          setAllUnitOptions(unitsRes.map(u => ({
            label: u.description,
            code: u.code,
            category: u.category
          })));
        }

        const gdmArray = Array.isArray(gdmData) ? gdmData : [gdmData];
        setGdms(gdmArray);
        setTimeout(() => {
          window.print();
        }, 500);
      } catch (err) {
        setError('Failed to load GDM for printing.');
      }
    };
    fetchData();
  }, [id]);

  if (error) return <div className="p-10 text-rose-500 font-bold">{error}</div>;
  if (gdms.length === 0) return <div className="p-10 text-slate-500">Loading document...</div>;

  return (
    <div className="bg-slate-200 min-h-screen flex flex-col items-center justify-start print:bg-white print:min-h-0 print:block">
      {gdms.map((gdm, index) => {
        let globalCases = 0, globalCartons = 0, globalBundles = 0;
        gdm.gcs?.forEach(gc => {
          gc.goods?.forEach(g => {
             const c = parseInt(g.articleCount) || 0;
             const unitStr = (g.units || '').toLowerCase().trim();
             const match = allUnitOptions.find(o => 
               (o.label || '').toLowerCase().trim() === unitStr || 
               (o.code || '').toLowerCase().trim() === unitStr ||
               (o.category || '').toLowerCase().trim() === unitStr
             );
             const cat = match ? (match.category || '').toLowerCase() : null;
             
             if (cat === 'cases') globalCases += c;
             else if (cat === 'cartons') globalCartons += c;
             else if (cat === 'bundles') globalBundles += c;
             else globalCases += c;
          });
        });
        let globalStr = [];
        if (globalCases > 0) globalStr.push(`${globalCases} c/s`);
        if (globalCartons > 0) globalStr.push(`${globalCartons} c/n`);
        if (globalBundles > 0) globalStr.push(`${globalBundles} bdl/s`);
        const totalArticlesDisplay = globalStr.length > 0 ? globalStr.join(' + ') : '0';

        return (
          <div key={gdm.id} className={`w-full flex justify-center p-4 print:p-0 ${index !== gdms.length - 1 ? 'print:break-after-page mb-8 print:mb-0' : ''}`}>
            {/* Container dimensions strictly A4 Portrait (210mm x 297mm) */}
            <div 
              className="w-[210mm] min-h-[297mm] bg-white text-slate-900 shadow-lg print:shadow-none font-sans text-[11px] p-6 flex flex-col justify-start relative"
              style={{ boxSizing: 'border-box', fontFamily: '"Inter", "Helvetica Neue", Helvetica, sans-serif' }}
              style={{ boxSizing: 'border-box' }}
            >
        
        {/* 1. Header / Branding Block */}
        <div className="flex justify-between items-start border-b-2 border-slate-800 pb-4 mb-4">
          <div className="flex items-center gap-4">
            <div className="h-16 w-16 border-[3px] border-slate-800 rounded-full flex items-center justify-center font-black text-2xl tracking-tighter">
              BL
            </div>
            <div>
              <div className="text-[10px] font-bold text-slate-500 mb-1">ஸ்ரீ கணேச துணை</div>
              <h1 className="text-3xl font-black tracking-wider font-serif leading-none text-slate-900 mb-1">
                BELL LOGISTICS
              </h1>
              <p className="text-[10px] font-bold text-slate-600 uppercase tracking-widest">
                123 Logistics Park, Transport Road, Sivakasi - 626123
              </p>
            </div>
          </div>
          <div className="text-right text-[10px] font-bold text-slate-600 flex flex-col gap-1">
            <div className="bg-slate-100 px-3 py-1 border border-slate-300 rounded-md">
              <span className="text-slate-400">TIN:</span> <span className="text-slate-800">33BBBBB0000B1Z1</span>
            </div>
            <div className="bg-slate-100 px-3 py-1 border border-slate-300 rounded-md">
              <span className="text-slate-400">CELL:</span> <span className="text-slate-800">9876543210</span>
            </div>
          </div>
        </div>

        {/* 2. Document Meta Grid */}
        <div className="grid grid-cols-3 gap-4 mb-4">
          {/* Lorry & Document details */}
          <div className="col-span-1 border border-slate-400 rounded-md p-2 flex flex-col gap-2">
            <div className="flex justify-between border-b border-slate-200 pb-1">
              <span className="text-[9px] text-slate-500 uppercase font-bold">GDM No</span>
              <span className="text-xs font-black text-slate-900">{gdm.gdmNumber}</span>
            </div>
            <div className="flex justify-between border-b border-slate-200 pb-1">
              <span className="text-[9px] text-slate-500 uppercase font-bold">Date / Time</span>
              <span className="text-[10px] font-bold text-slate-900">{new Date(gdm.date).toLocaleDateString('en-GB')} - {gdm.time}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-[9px] text-slate-500 uppercase font-bold">Lorry No</span>
              <span className="text-sm font-black text-slate-900">{gdm.vehicle?.vehicleNumber || gdm.vehicleNumber}</span>
            </div>
          </div>

          {/* CEWB Block (High Emphasis) */}
          <div className="col-span-1 border-2 border-slate-800 rounded-md p-3 flex flex-col justify-center items-center bg-slate-50">
            <span className="text-[10px] text-slate-500 uppercase font-bold tracking-widest mb-1">Master CEWB Number</span>
            <span className="text-lg font-black text-indigo-700 tracking-wider">{gdm.cewbNumber || 'PENDING'}</span>
          </div>

          {/* Parties Block */}
          <div className="col-span-1 border border-slate-400 rounded-md p-2 flex flex-col gap-2">
             <div className="flex flex-col border-b border-slate-200 pb-1">
              <span className="text-[9px] text-slate-500 uppercase font-bold">Destination</span>
              <span className="text-xs font-black text-slate-900 truncate">{gdm.destination || 'N/A'}</span>
            </div>
            <div className="flex flex-col">
              <span className="text-[9px] text-slate-500 uppercase font-bold">Driver Info</span>
              <span className="text-[10px] font-bold text-slate-900 truncate">{gdm.vehicle?.driverName || '-'} (Ph: {gdm.vehicle?.driverPhone || '-'})</span>
            </div>
          </div>
        </div>

        {/* 3. Main Goods Table */}
        <div className="border border-slate-800 flex-1 flex flex-col mb-4 rounded-md overflow-hidden">
          <table className="w-full text-left border-collapse text-[10px]">
            <thead>
              <tr className="bg-slate-800 text-white">
                <th rowSpan="2" className="px-3 py-2 border-r border-slate-600 w-[15%] align-middle font-bold tracking-wider">GC.NO / EWB</th>
                <th rowSpan="2" className="px-3 py-2 border-r border-slate-600 w-[28%] align-middle font-bold tracking-wider">CONSIGNOR</th>
                <th rowSpan="2" className="px-3 py-2 border-r border-slate-600 w-[28%] align-middle font-bold tracking-wider">CONSIGNEE</th>
                <th colSpan="3" className="px-3 py-1 border-r border-slate-600 text-center border-b border-slate-600 font-bold tracking-wider">ARTICLES</th>
                <th rowSpan="2" className="px-3 py-2 w-[10%] text-right align-middle font-bold tracking-wider">FREIGHT</th>
              </tr>
              <tr className="bg-slate-700 text-slate-200 text-center text-[9px]">
                <th className="py-1 border-r border-slate-600 w-[6%] font-semibold">C/S</th>
                <th className="py-1 border-r border-slate-600 w-[6%] font-semibold">C/N</th>
                <th className="py-1 border-r border-slate-600 w-[6%] font-semibold">BDL/S</th>
              </tr>
            </thead>
            <tbody>
              {gdm.gcs?.map((gc, index) => {
                let rowCases = 0, rowCartons = 0, rowBundles = 0;
                gc.goods?.forEach(g => {
                   const c = parseInt(g.articleCount) || 0;
                   const unitStr = (g.units || '').toLowerCase().trim();
                   const match = allUnitOptions.find(o => 
                     (o.label || '').toLowerCase().trim() === unitStr || 
                     (o.code || '').toLowerCase().trim() === unitStr ||
                     (o.category || '').toLowerCase().trim() === unitStr
                   );
                   const cat = match ? (match.category || '').toLowerCase() : null;
                   
                   if (cat === 'cases') rowCases += c;
                   else if (cat === 'cartons') rowCartons += c;
                   else if (cat === 'bundles') rowBundles += c;
                   else rowCases += c;
                });
                return (
                  <tr key={gc.id} className="border-b border-slate-300 last:border-b-0 align-middle hover:bg-slate-50">
                    <td className="px-3 py-2 border-r border-slate-300 text-center">
                      <div className="font-bold text-slate-900 text-[11px]">{gc.gcNumber.replace('BELL-', '').replace('AP-', '')}</div>
                      {gc.privateMark && <div className="text-[8px] font-medium text-slate-500 tracking-tight mt-0.5 font-mono">{gc.privateMark}</div>}
                    </td>
                    <td className="px-3 py-2 border-r border-slate-300 uppercase truncate max-w-[150px] font-bold text-slate-700">{gc.consignor?.name}</td>
                    <td className="px-3 py-2 border-r border-slate-300 uppercase truncate max-w-[150px] font-bold text-slate-700">{gc.consignee?.name}</td>
                    <td className="px-1 py-2 border-r border-slate-300 text-center font-black text-slate-900">{rowCases > 0 ? rowCases : '-'}</td>
                    <td className="px-1 py-2 border-r border-slate-300 text-center font-black text-slate-900">{rowCartons > 0 ? rowCartons : '-'}</td>
                    <td className="px-1 py-2 border-r border-slate-300 text-center font-black text-slate-900">{rowBundles > 0 ? rowBundles : '-'}</td>
                    <td className="px-3 py-2 text-right font-bold text-slate-900">{gc.freightTotal || '-'}</td>
                  </tr>
                );
              })}
              
              {/* Padding rows */}
              {Array.from({ length: Math.max(0, 15 - (gdm.gcs?.length || 0)) }).map((_, i) => (
                <tr key={`empty-${i}`} className="border-b border-slate-200 last:border-b-0 h-[32px]">
                  <td className="border-r border-slate-200"></td><td className="border-r border-slate-200"></td><td className="border-r border-slate-200"></td>
                  <td className="border-r border-slate-200"></td><td className="border-r border-slate-200"></td><td className="border-r border-slate-200"></td>
                  <td></td>
                </tr>
              ))}
              
              {/* Total Row */}
              <tr className="border-t-2 border-slate-800 bg-slate-100 text-[11px]">
                <td colSpan="3" className="px-3 py-3 border-r border-slate-800 text-right tracking-widest uppercase font-black text-slate-800">TOTAL</td>
                <td className="px-1 py-3 border-r border-slate-800 text-center font-black text-[12px]">{globalCases > 0 ? globalCases : '-'}</td>
                <td className="px-1 py-3 border-r border-slate-800 text-center font-black text-[12px]">{globalCartons > 0 ? globalCartons : '-'}</td>
                <td className="px-1 py-3 border-r border-slate-800 text-center font-black text-[12px]">{globalBundles > 0 ? globalBundles : '-'}</td>
                <td className="px-3 py-3 text-right font-black text-[12px]">{gdm.gcs?.reduce((sum, gc) => sum + (parseFloat(gc.freightTotal) || 0), 0) || '-'}</td>
              </tr>
            </tbody>
          </table>
        </div>
        
        {/* Signatures */}
        <div className="flex justify-between items-end mt-4 text-[10px] font-bold px-8 text-slate-600 uppercase tracking-widest">
          <div className="text-center">
            <div className="w-32 border-b border-slate-400 mb-2"></div>
            <span>Driver Signature</span>
          </div>
          <div className="text-center">
            <div className="w-32 border-b border-slate-400 mb-2"></div>
            <span>For BELL LOGISTICS</span>
          </div>
        </div>

        </div>
      </div>
    );
  })}

      {/* Action buttons (hidden on print) */}
      <button 
        onClick={() => navigate(-1)}
        className="fixed top-4 left-4 bg-slate-800 text-white px-4 py-2 rounded-lg font-bold shadow-lg print:hidden hover:bg-slate-700"
      >
        ← Back
      </button>

      <button 
        onClick={() => window.print()}
        className="fixed top-4 right-4 bg-indigo-600 text-white px-4 py-2 rounded-lg font-bold shadow-lg print:hidden hover:bg-indigo-500"
      >
        🖨️ Print GDM
      </button>

    </div>
  );
}
