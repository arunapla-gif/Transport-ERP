import React, { useEffect, useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { api } from '../api';

export default function GdmPrint() {
  const { id } = useParams();
  const navigate = useNavigate();
  const [gdms, setGdms] = useState([]);
  const [error, setError] = useState('');

  useEffect(() => {
    const fetchGdm = async () => {
      try {
        const data = await api.get(`/gdms/${id}`); 
        const gdmArray = Array.isArray(data) ? data : [data];
        setGdms(gdmArray);
        setTimeout(() => {
          window.print();
        }, 500);
      } catch (err) {
        setError('Failed to load GDM for printing.');
      }
    };
    fetchGdm();
  }, [id]);

  if (error) return <div className="p-10 text-rose-500 font-bold">{error}</div>;
  if (gdms.length === 0) return <div className="p-10 text-slate-500">Loading document...</div>;

  return (
    <div className="bg-slate-200 min-h-screen flex flex-col items-center justify-start print:bg-white print:min-h-0 print:block">
      {gdms.map((gdm, index) => {
        const totalArticles = gdm.gcs?.reduce((sum, gc) => {
          const gcArts = gc.goods?.reduce((s, g) => s + (g.articleCount || 0), 0) || 0;
          return sum + gcArts;
        }, 0) || 0;

        return (
          <div key={gdm.id} className={`w-full flex justify-center p-4 print:p-0 ${index !== gdms.length - 1 ? 'print:break-after-page mb-8 print:mb-0' : ''}`}>
            {/* Container dimensions strictly A4 Portrait (210mm x 297mm) */}
            <div 
              className="w-[210mm] min-h-[297mm] bg-white text-black shadow-lg print:shadow-none font-mono text-[11px] p-6 flex flex-col justify-start relative"
              style={{ boxSizing: 'border-box' }}
            >
        
        {/* Header / Branding Block */}
        <div className="flex justify-between items-center mb-1 text-[10px] font-bold">
          <span>TIN : 33BBBBB0000B1Z1</span>
          <span>CELL : 9876543210</span>
        </div>
        
        <div className="text-center block text-sm font-bold mb-2">
          ஸ்ரீ கணேச துணை (Sri Ganesa Thunai)
        </div>

        <div className="flex items-center border-t-2 border-b-2 border-black py-3 mb-2">
          <div className="h-20 w-20 border-[3px] border-black rounded-full flex items-center justify-center font-black text-2xl ml-4">
            BL
          </div>
          <div className="flex-1 text-center pr-12">
            <h1 className="text-[32px] font-black tracking-widest font-serif leading-none mb-1">
              BELL LOGISTICS
            </h1>
            <p className="text-[11px] font-bold uppercase">123 Logistics Park, Transport Road, Sivakasi - 626123</p>
          </div>
        </div>

        {/* Metadata Block 1 */}
        <div className="grid grid-cols-4 divide-x divide-black border-2 border-black border-b-0 text-[11px] font-bold">
          <div className="flex gap-2 p-1.5"><span className="w-8">No:</span> <span className="font-black">{gdm.gdmNumber}</span></div>
          <div className="flex gap-2 p-1.5"><span className="w-10">Date:</span> <span className="font-black">{new Date(gdm.date).toLocaleDateString('en-GB')}</span></div>
          <div className="flex gap-2 p-1.5"><span className="w-10">Time:</span> <span className="font-black">{gdm.time}</span></div>
          <div className="flex gap-2 p-1.5"><span className="w-14">Vehicle:</span> <span className="font-black truncate">{gdm.vehicle?.vehicleNumber || gdm.vehicleNumber}</span></div>
        </div>

        {/* Metadata Block 2 (Lorry No Header) */}
        <div className="text-center text-xl font-black border-2 border-black border-b-0 py-1.5 uppercase tracking-widest bg-gray-50/50">
          LORRY NO: {gdm.vehicle?.vehicleNumber || gdm.vehicleNumber}
        </div>

        {/* Metadata Block 3 (Parties & Driver) */}
        <div className="grid grid-cols-[4.5fr_2.75fr_2.75fr] divide-x divide-black border-2 border-black border-b-0 text-[10px] min-h-[75px] font-bold">
          <div className="p-2 flex flex-col">
            <span className="underline mb-1">To:</span>
            <span className="font-black text-sm uppercase">{gdm.destination || 'N/A'}</span>
          </div>
          <div className="p-2 flex flex-col gap-1">
            <span className="underline mb-0.5">Owner:</span>
            <span className="uppercase">{gdm.vehicle?.ownerName || '-'}</span>
          </div>
          <div className="p-2 flex flex-col gap-1">
            <span className="underline mb-0.5">Driver:</span>
            <span className="uppercase">{gdm.vehicle?.driverName || '-'}</span>
            <span>Ph: {gdm.vehicle?.driverPhone || '-'}</span>
          </div>
        </div>

        {/* Main GC Table */}
        <div className="border-2 border-black border-b-0 flex-1">
          <table className="w-full text-left border-collapse text-[10px] font-bold">
            <thead>
              <tr className="border-b-2 border-black bg-gray-50/50">
                <th className="px-2 py-1.5 border-r border-black w-[10%] text-center">GC.NO</th>
                <th className="px-2 py-1.5 border-r border-black w-[40%]">CONSIGNOR</th>
                <th className="px-2 py-1.5 border-r border-black w-[35%]">CONSIGNEE NAME</th>
                <th className="px-2 py-1.5 border-r border-black w-[10%] text-center">DESPATCH</th>
                <th className="px-2 py-1.5 w-[5%] text-center leading-tight">FREIGHT<br/>TO-PAY</th>
              </tr>
            </thead>
            <tbody>
              {gdm.gcs?.map((gc, index) => {
                const arts = gc.goods?.reduce((s, g) => s + (g.articleCount || 0), 0) || 0;
                return (
                  <tr key={gc.id} className="border-b border-black last:border-b-0">
                    <td className="px-2 py-1 border-r border-black text-center">{gc.gcNumber.replace('BELL-', '').replace('AP-', '')}</td>
                    <td className="px-2 py-1 border-r border-black uppercase truncate max-w-[200px]">{gc.consignor?.name}</td>
                    <td className="px-2 py-1 border-r border-black uppercase truncate max-w-[180px]">{gc.consignee?.name}</td>
                    <td className="px-2 py-1 border-r border-black text-center">{arts}</td>
                    <td className="px-2 py-1 text-right">{gc.freightTotal || '-'}</td>
                  </tr>
                );
              })}
              
              {/* Padding rows if few GCs exist to maintain layout height */}
              {Array.from({ length: Math.max(0, 20 - (gdm.gcs?.length || 0)) }).map((_, i) => (
                <tr key={`empty-${i}`} className="border-b border-black last:border-b-0 h-[22px]">
                  <td className="border-r border-black"></td>
                  <td className="border-r border-black"></td>
                  <td className="border-r border-black"></td>
                  <td className="border-r border-black"></td>
                  <td></td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        {/* Table Footer / Total Row */}
        <div className="grid grid-cols-[85%_10%_5%] border-2 border-black border-t-0 font-bold text-[11px]">
          <div className="border-r border-black px-2 py-1.5 text-right font-black tracking-widest uppercase">
            TOTAL
          </div>
          <div className="border-r border-black px-2 py-1.5 text-center font-black">
            {totalArticles}
          </div>
          <div className="px-2 py-1.5 text-right">
            {gdm.gcs?.reduce((sum, gc) => sum + (parseFloat(gc.freightTotal) || 0), 0) || ''}
          </div>
        </div>
        
        {/* Signatures */}
        <div className="flex justify-between items-end mt-8 text-[11px] font-bold px-4">
          <div className="text-center">
            <div className="mb-8"></div>
            <span>Driver Signature</span>
          </div>
          <div className="text-center">
            <div className="mb-8"></div>
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
