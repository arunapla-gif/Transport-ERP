import React, { useEffect, useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { api } from '../api';

export default function GcPrint() {
  const { id } = useParams();
  const navigate = useNavigate();
  const [gcs, setGcs] = useState([]);
  const [error, setError] = useState('');

  // Extract copies from URL or default to CONSIGNOR COPY
  const queryParams = new URLSearchParams(window.location.search);
  const copiesParam = queryParams.get('copies');
  const selectedCopies = copiesParam ? copiesParam.split(',') : ['CONSIGNOR COPY'];

  useEffect(() => {
    const fetchGc = async () => {
      try {
        const gcData = await api.get(`/gcs/${id}`); 
        const gcArray = Array.isArray(gcData) ? gcData : [gcData];
        setGcs(gcArray);
        setTimeout(() => {
          window.print();
        }, 500);
      } catch (err) {
        setError('Failed to load GC for printing.');
      }
    };
    fetchGc();
  }, [id]);

  if (error) return <div className="p-10 text-rose-500 font-bold">{error}</div>;
  if (gcs.length === 0) return <div className="p-10 text-slate-500">Loading document...</div>;

  return (
    <div className="bg-slate-200 min-h-screen flex flex-col items-center justify-start print:bg-white print:min-h-0 print:block">
      <style type="text/css">
        {`
          @media print {
            @page {
              size: A5 landscape;
            }
          }
        `}
      </style>

      {gcs.flatMap((gc, index) => {
        const isAp = gc.gcNumber?.startsWith('AP-');
        const companyName = isAp ? 'A.P. ROADLINES' : 'THE BELL LORRY AGENCIES';
        const companyTamil = isAp ? 'ஸ்ரீ அய்யனார் துணை' : 'ஸ்ரீ திருச்செந்தூர் முருகன் துணை';
        const companyLogo = isAp ? 'AP' : 'BL';
        const gstNo = isAp ? '33XXXXX0000X1Z1' : '33AGKPK2374D1ZN';
        const address = isAp ? 'SIVAKASI' : '359, THIRUTHAGAL ROAD, SIVAKASI-626123';
        const phone = isAp ? '9876543210' : '221253';
        const copies = selectedCopies;

        return copies.map((copyType, copyIndex) => {
          const isLastTotalItem = index === gcs.length - 1 && copyIndex === copies.length - 1;
          const totalArticles = gc.goods?.reduce((sum, g) => sum + (parseInt(g.articles) || parseInt(g.articleCount) || 0), 0) || 0;
          const totalFreight = (parseFloat(gc.freightTotal || 0)).toFixed(2); 

          const paddedGoods = [...(gc.goods || [])];
          while (paddedGoods.length < 3) paddedGoods.push(null);
          const displayGoods = paddedGoods.slice(0, 3);

          if (copyType === 'CONSIGNEE COPY') {
            return (
              <div 
                key={`${gc.id}-${copyIndex}`} 
                className={`w-full flex justify-center print:p-0 ${!isLastTotalItem ? 'print:break-after-page mb-8 print:mb-0' : ''}`}
              >
                <div style={{ width: '210mm', height: '148.5mm' }} className="bg-white text-slate-900 font-sans p-2 relative box-border mx-auto print:border-none border border-slate-300 shadow-sm overflow-hidden flex flex-col">
                  
                  {/* --- SUPER HEADER --- */}
                  <div className="flex justify-between items-end font-bold mb-1.5 px-1 border-b-[2px] border-slate-900 pb-1.5 shrink-0">
                    <div className="flex items-center gap-2 w-[60%]">
                       <div className="w-[50px] h-[50px] bg-white border-[2px] border-slate-900 text-slate-900 flex items-center justify-center font-bold text-[28px] rounded-lg shadow-sm shrink-0">
                         {companyLogo}
                       </div>
                       <div className="flex flex-col justify-center overflow-hidden">
                         <div className="text-[10px] font-bold text-slate-600 mb-0">{companyTamil}</div>
                         <h1 className="text-[22px] font-black tracking-tight text-blue-800 uppercase leading-none mb-0.5 truncate">{companyName}</h1>
                         <div className="text-[11px] text-slate-700 font-semibold tracking-wide">
                           {address} | Ph: {phone}
                         </div>
                       </div>
                    </div>
                    <div className="w-[40%] text-right flex flex-col justify-end items-end h-[50px]">
                      <div className="text-[16px] font-black tracking-widest text-slate-900 mb-0.5">LORRY RECEIPT</div>
                      <div className="border border-slate-400 text-slate-800 px-2 py-0.5 rounded text-[10px] font-black uppercase tracking-wider mb-1.5">{copyType}</div>
                      <div className="flex gap-4 text-[14px] mt-1 bg-slate-100 p-1.5 rounded-lg border border-slate-200">
                        <div><span className="text-slate-500 font-bold text-[11px] block leading-none">GC No</span> <span className="font-black text-[18px] tracking-tight">{gc.gcNumber}</span></div>
                        <div className="border-l border-slate-300 pl-3"><span className="text-slate-500 font-bold text-[11px] block leading-none">Date</span> <span className="font-black text-[14px] leading-tight">{gc.date ? new Date(gc.date).toLocaleDateString('en-GB').replace(/\//g, '-') : '-'}</span></div>
                      </div>
                    </div>
                  </div>

                  {/* Route & GST Box */}
                  <div className="flex bg-white rounded p-1 mb-1.5 border border-slate-300 items-center shrink-0">
                    <div className="w-1/3 flex flex-col px-2">
                       <span className="text-[9px] text-slate-500 font-bold uppercase mb-0">Origin</span>
                       <span className="text-[14px] font-black uppercase leading-tight">{companyAddressCity(isAp)}</span>
                    </div>
                    <div className="w-1/3 flex justify-center text-slate-400">
                       <svg className="w-5 h-5" fill="none" stroke="currentColor" strokeWidth="2.5" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" d="M17 8l4 4m0 0l-4 4m4-4H3"></path></svg>
                    </div>
                    <div className="w-1/3 flex flex-col px-2 text-right">
                       <span className="text-[9px] text-slate-500 font-bold uppercase mb-0">Destination</span>
                       <span className="text-[14px] font-black uppercase leading-tight">{gc.consignee?.city || '-'}</span>
                    </div>
                  </div>

                  {/* Parties: Consignor & Consignee */}
                  <div className="flex gap-2 mb-1.5 shrink-0">
                    <div className="flex-1 border border-slate-300 rounded-lg p-1.5 bg-white relative overflow-hidden flex flex-col">
                       <div className="text-[9px] font-black text-slate-500 uppercase tracking-wider mb-0.5">Consignor</div>
                       <div className="font-black text-[13px] uppercase leading-tight mb-0.5">{gc.consignor?.name || '-'}</div>
                       <div className="text-[10px] text-slate-700 font-semibold uppercase leading-snug flex-grow">
                         {gc.consignor?.address || ''}<br/>
                         {gc.consignor?.city || ''}
                       </div>
                       <div className="mt-1 text-[10px] bg-white px-1.5 py-0.5 rounded font-mono font-bold text-slate-800 border border-slate-300 inline-block self-start">GSTIN: {gc.consignor?.gstin || '-'}</div>
                    </div>
                    
                    <div className="flex-1 border border-slate-300 rounded-lg p-1.5 bg-white relative overflow-hidden flex flex-col">
                       <div className="text-[9px] font-black text-slate-500 uppercase tracking-wider mb-0.5">Consignee</div>
                       <div className="font-black text-[13px] uppercase leading-tight mb-0.5">
                         {gc.consignee?.name || '-'}
                         {gc.consignee?.legalName && gc.consignee.legalName.trim().toLowerCase() !== (gc.consignee?.name || '').trim().toLowerCase() && (
                           <div className="text-[9px] text-slate-500 font-bold mt-0.5 leading-none">({gc.consignee.legalName})</div>
                         )}
                       </div>
                       <div className="text-[10px] text-slate-700 font-semibold uppercase leading-snug flex-grow">
                         {gc.consignee?.address || ''}<br/>
                         {gc.consignee?.city || ''}
                       </div>
                       <div className="mt-1 text-[10px] bg-white px-1.5 py-0.5 rounded font-mono font-bold text-slate-800 border border-slate-300 inline-block self-start">GSTIN: {gc.consignee?.gstin || '-'}</div>
                    </div>
                  </div>

                  {/* Main Data Section (Goods & Freight Split) */}
                  <div className="flex gap-2 mb-1.5 flex-grow overflow-hidden">
                    {/* Goods Table (Left 65%) */}
                    <div className="w-[65%] border border-slate-300 rounded-lg overflow-hidden flex flex-col bg-white">
                      <table className="w-full text-left flex-grow flex flex-col">
                        <thead className="border-b border-slate-300 bg-slate-50 shrink-0">
                          <tr className="text-[10px] text-slate-800 font-black uppercase tracking-wide flex w-full">
                            <th className="p-1 w-[25%] border-r border-slate-300 text-center">Articles</th>
                            <th className="p-1 pl-2 w-[75%]">Description of Goods</th>
                          </tr>
                        </thead>
                        <tbody className="flex-grow flex flex-col">
                          {displayGoods.map((g, i) => (
                            <tr key={i} className="flex w-full flex-1">
                              <td className="p-1.5 border-r border-slate-300 text-center w-[25%] font-black text-[18px] flex flex-col justify-center">
                                {g ? (g.articles || g.articleCount) : ''}
                              </td>
                              <td className="p-2 uppercase font-bold text-[13px] text-slate-900 w-[75%] flex flex-col justify-center">
                                {g ? g.units : ''}
                              </td>
                            </tr>
                          ))}
                        </tbody>
                      </table>
                    </div>

                     {/* Freight Area (Right 35%) */}
                     <div className="w-[35%] bg-white border border-slate-300 rounded-lg overflow-hidden flex flex-col">
                        <div className="bg-slate-50 border-b border-slate-300 text-slate-900 text-center py-1 font-black tracking-widest uppercase text-[10px] shrink-0">
                          Freight Details
                        </div>
                       <div className="p-2 flex flex-col gap-1 flex-grow justify-center font-bold text-[11px]">
                         <div className="flex justify-between items-center border-b border-slate-100 pb-1">
                           <span className="text-slate-500 uppercase">Fixed</span>
                           <span className="text-[13px]">{gc.freightRate || '0.00'}</span>
                         </div>
                         <div className="flex justify-between items-center border-b border-slate-100 pb-1">
                           <span className="text-slate-500 uppercase">Advance</span>
                           <span className="text-[13px]">{gc.advancePaid || '0.00'}</span>
                         </div>
                         <div className="flex justify-between items-center border-b border-slate-100 pb-1">
                           <span className="text-slate-500 uppercase">Balance</span>
                           <span className="text-[13px]">{gc.balanceFreight || '0.00'}</span>
                         </div>
                         <div className="flex justify-between items-center pt-1 mt-auto">
                           <span className="text-slate-900 uppercase font-black text-[12px]">Total</span>
                           <span className="text-[16px] font-black text-slate-900 border border-slate-300 bg-white px-1.5 py-0 rounded">{totalFreight}</span>
                         </div>
                       </div>
                    </div>
                  </div>

                  {/* Footer Data & Signature */}
                  <div className="flex justify-between items-end border border-slate-300 rounded-lg bg-white p-1.5 shrink-0">
                    <div className="grid grid-cols-2 gap-x-4 gap-y-1 text-[10px] w-[60%]">
                       <div className="flex justify-between border-b border-slate-100 pb-0.5">
                         <span className="font-bold text-slate-500 uppercase">Inv No:</span> <span className="font-black text-slate-800">{gc.invoiceNumber || '-'}</span>
                       </div>
                       <div className="flex justify-between border-b border-slate-100 pb-0.5">
                         <span className="font-bold text-slate-500 uppercase">Inv Date:</span> <span className="font-black text-slate-800">{gc.invoiceDate ? new Date(gc.invoiceDate).toLocaleDateString('en-GB') : '-'}</span>
                       </div>
                       <div className="flex justify-between border-b border-slate-100 pb-0.5">
                         <span className="font-bold text-slate-500 uppercase">Value:</span> <span className="font-black text-slate-800">₹{gc.invoiceValue ? parseFloat(gc.invoiceValue).toFixed(2) : '-'}</span>
                       </div>
                       <div className="flex justify-between border-b border-slate-100 pb-0.5">
                         <span className="font-bold text-slate-500 uppercase">Lorry No:</span> <span className="font-black text-slate-800 uppercase">{gc.vehicle?.vehicleNumber || '-'}</span>
                       </div>
                    </div>
                    
                    <div className="w-[40%] text-center flex flex-col justify-end h-[45px] pl-2">
                       <div className="text-[10px] font-black uppercase text-slate-700 leading-tight">For {companyName}</div>
                       <div className="text-[9px] font-bold text-slate-400 border-t border-slate-300 pt-0.5 mt-auto">Authorized Signatory</div>
                    </div>
                  </div>

                  {/* Bottom Note */}
                  <div className="mt-1 flex justify-between items-center text-[8px] font-bold text-slate-500 uppercase tracking-wider shrink-0">
                    <span className="w-[50%]">Note: We are not responsible for fire, theft, leakage, damage & breakage. | Subject to Sivakasi Jurisdiction.</span>
                    <span className="font-black text-slate-900 border-[2px] border-slate-900 px-2 py-0.5 rounded-lg text-[13px] tracking-widest bg-slate-100 leading-none">RCM PAYABLE BY CONSIGNEE</span>
                  </div>
                </div>
              </div>
            );
          }

          // ===== CLASSIC LAYOUT (For Consignor Copy, etc) =====
          return (
            <div 
              key={`${gc.id}-${copyIndex}`} 
              className={`w-full flex justify-center print:p-0 ${!isLastTotalItem ? 'print:break-after-page mb-8 print:mb-0' : ''}`}
            >
              <div style={{ width: '210mm', height: '148.5mm' }} className="bg-white text-black font-sans text-xs p-4 relative box-border mx-auto print:p-2 print:border-none border border-black overflow-hidden">
                
                {/* --- SUPER HEADER --- */}
                <div className="flex justify-between items-end font-bold mb-1 px-1">
                  <div className="w-1/3"></div>
                  <div className="text-center w-1/3 text-[14px]">GOODS CONSIGNMENT NOTE</div>
                  <div className="text-right w-1/3 text-[12px]">({copyType})</div>
                </div>

                {/* --- MAIN BORDER WRAPPER --- */}
                <div className="border border-black">
                  
                  {/* --- ROW 1: HEADER LOGO AND COMPANY --- */}
                  <div className="flex border-b border-black p-2 items-center">
                    <div className="w-[20%] flex justify-center items-center">
                       <div className="relative font-serif font-bold text-[55px] leading-none italic tracking-tighter text-blue-900 flex items-center pr-4">
                         <span className="z-10 bg-white px-1">B</span>
                         <span className="text-[40px] ml-[-4px] mt-2 z-10 bg-white px-1">L</span>
                         <div className="absolute top-1/2 left-0 w-[120%] h-[3px] bg-blue-900 rounded-full rotate-[-25deg]"></div>
                         <div className="absolute top-[40%] left-[-10%] w-[130%] h-[3px] bg-blue-900 rounded-full rotate-[-25deg]"></div>
                         <div className="absolute w-16 h-16 border-l-[4px] border-t-[4px] border-blue-900 rounded-tl-full top-[-5px] left-[-15px]"></div>
                       </div>
                    </div>
                    <div className="w-[80%] text-center leading-tight pr-10">
                       <div className="text-[10px] font-bold mb-0.5">{companyTamil}</div>
                       <div className="text-[26px] font-black text-blue-600 tracking-wide uppercase mb-0.5">{companyName}</div>
                       <div className="text-[12px] font-bold">{address}</div>
                       <div className="text-[12px] font-bold">GST-{gstNo} Ph: {phone}</div>
                    </div>
                  </div>

                  {/* --- ROW 2: CONSIGNOR, CONSIGNEE, GC NO --- */}
                  <div className="flex border-b border-black">
                    <div className="w-[35%] border-r border-black p-1.5 align-top flex flex-col min-h-[70px]">
                       <div className="font-bold text-[11px] mb-1">Consignor:</div>
                       <div className="text-[10px] uppercase">{gc.consignor?.name || ''}</div>
                       <div className="text-[10px] uppercase leading-tight mt-0.5">{gc.consignor?.address || ''}</div>
                       <div className="text-[10px] uppercase">{gc.consignor?.city || ''}</div>
                    </div>
                    <div className="w-[45%] border-r border-black p-1.5 align-top flex flex-col relative">
                       <div className="font-bold text-[11px] mb-1">Consignee :</div>
                       <div className="text-[10px] uppercase">
                         {gc.consignee?.name || ''}
                         {gc.consignee?.legalName && gc.consignee.legalName.trim().toLowerCase() !== (gc.consignee?.name || '').trim().toLowerCase() && (
                           <div className="text-[8px] text-slate-600 mt-0.5 font-bold">({gc.consignee.legalName})</div>
                         )}
                       </div>
                       <div className="text-[10px] uppercase mt-0.5">{gc.consignee?.city || ''}</div>
                       <div className="text-[10px] mt-0.5">Contact : {gc.consignee?.phone || ''}</div>
                       <div className="absolute top-6 right-2 text-[10px] font-bold">{gc.consignee?.gstin || ''}</div>
                    </div>
                    <div className="w-[20%] p-1.5 flex flex-col gap-2">
                       <div className="flex gap-1 text-[12px]">
                         <span className="font-bold">GC No :</span>
                         <span className="font-bold">{gc.gcNumber}</span>
                       </div>
                       <div className="flex gap-1 text-[12px]">
                         <span>Date :</span>
                         <span className="font-bold">{gc.date ? new Date(gc.date).toLocaleDateString('en-GB').replace(/\//g, '-') : ''}</span>
                       </div>
                    </div>
                  </div>

                  {/* --- ROW 3: FROM / TO --- */}
                  <div className="flex border-b border-black font-bold text-[12px]">
                    <div className="w-[50%] border-r border-black p-1.5">
                       From :Sivakasi
                    </div>
                    <div className="w-[50%] p-1.5 uppercase">
                       To :{gc.consignee?.city || ''}
                    </div>
                  </div>

                  {/* --- ROW 4: TABLE --- */}
                  <div className="flex min-h-[140px]">
                    
                        {/* QTY & DESC COLUMNS */}
                    <div className="w-[55%] flex flex-col border-r border-black">
                      <div className="flex border-b border-black">
                        <div className="w-[30%] p-1 text-center font-bold text-[11px] border-r border-black">No of Articles</div>
                        <div className="w-[70%] p-1 text-center font-bold text-[11px]">Description</div>
                      </div>
                      <div className="flex-grow flex flex-col">
                        {displayGoods.map((g, i) => (
                          <div key={i} className="flex flex-1 items-center">
                            <div className="w-[30%] text-[14px] font-black uppercase text-center border-r border-black h-full flex flex-col justify-center">
                              {g ? (g.articles || g.articleCount) : ''}
                            </div>
                            <div className="w-[70%] text-[12px] font-bold uppercase pl-2 h-full flex flex-col justify-center">
                              {g ? g.units : ''} {g?.weight ? `(${g.weight} kg)` : ''}
                            </div>
                          </div>
                        ))}
                      </div>
                    </div>

                    {/* RATE COLUMN */}
                    <div className="w-[10%] border-r border-black flex flex-col">
                       <div className="border-b border-black p-1 text-center font-bold text-[11px]">Rate</div>
                       <div className="flex-grow flex flex-col">
                          {displayGoods.map((g, i) => (
                            <div key={i} className="flex-1 text-center text-[11px] flex flex-col justify-center">
                              {g ? (g.rate || '0.00') : ''}
                            </div>
                          ))}
                       </div>
                    </div>

                    {/* FREIGHT COLUMN */}
                    <div className="w-[35%] flex flex-col">
                       <div className="border-b border-black flex">
                         <div className="w-[60%] border-r border-black p-1 pl-2 text-[11px] font-bold">Freight fixed</div>
                         <div className="w-[40%] p-1 text-right pr-2 text-[11px]"></div>
                       </div>
                       <div className="border-b border-black flex">
                         <div className="w-[60%] border-r border-black p-1 pl-2 text-[11px]">Advance paid</div>
                         <div className="w-[40%] p-1 text-right pr-2 text-[11px]"></div>
                       </div>
                       <div className="border-b border-black flex">
                         <div className="w-[60%] border-r border-black p-1 pl-2 text-[11px]">Balance topay</div>
                         <div className="w-[40%] p-1 text-right pr-2 text-[11px]"></div>
                       </div>
                       <div className="flex-grow border-b border-black flex">
                         <div className="w-[60%] border-r border-black"></div>
                         <div className="w-[40%]"></div>
                       </div>
                       <div className="flex">
                         <div className="w-[60%] border-r border-black p-1 pl-2 text-[11px] font-bold">Total To pay</div>
                         <div className="w-[40%] p-1 text-right pr-2 text-[11px]"></div>
                       </div>
                    </div>
                  </div>

                  {/* --- ROW 5: NOTE --- */}
                  <div className="border-b border-black p-1 flex justify-between items-center font-bold text-[10px]">
                     <span>Note : WE ARE NOT RESPONSIBLE FOR FIRE, THEFT, LEAKAGE, DAMAGE & BREAKAGE</span>
                     <span className="font-black text-[13px] border-2 border-black px-2 py-0.5 leading-none">RCM PAYABLE BY CONSIGNEE</span>
                  </div>

                  {/* --- ROW 6: FOOTER DATA --- */}
                  <div className="flex">
                    <div className="w-[65%] border-r border-black p-2 flex flex-col gap-1.5 text-[11px] font-bold">
                       <div className="grid grid-cols-[80px_1fr]">
                         <span>Bill No</span><span>: {gc.invoiceNumber || ''}</span>
                       </div>
                       <div className="grid grid-cols-[80px_1fr]">
                         <span>Bill Date</span><span>: {gc.invoiceDate ? new Date(gc.invoiceDate).toLocaleDateString('en-GB').replace(/\//g, '-') : ''}</span>
                       </div>
                       <div className="grid grid-cols-[80px_1fr]">
                         <span>Goods value</span><span>: {gc.invoiceValue ? parseFloat(gc.invoiceValue).toFixed(2) : ''}</span>
                       </div>
                       <div className="grid grid-cols-[80px_1fr]">
                         <span>Lorry No</span><span>: {gc.vehicle?.vehicleNumber || ''}</span>
                       </div>
                    </div>
                    <div className="w-[35%] p-2 flex flex-col justify-between font-bold text-[11px] relative">
                       <div className="text-right mt-1">For {companyName === 'A.P. ROADLINES' ? 'A.P. Roadlines' : 'The Bell Lorry Agencies'}</div>
                       <div className="text-right mt-12 mb-1">Authorized signature</div>
                    </div>
                  </div>
                </div>

                {/* --- ABSOLUTE BOTTOM --- */}
                <div className="flex justify-between text-[10px] font-bold mt-1">
                  <span>Subject to Sivakasi juristiction</span>
                  <span className="text-gray-500 font-normal">www.jellysoftwares.com</span>
                </div>

              </div>
            </div>
          );
        });
      })}

      {/* Action buttons (hidden on print) */}
      <button 
        onClick={() => navigate(-1)}
        className="fixed top-4 left-4 bg-slate-800 text-white px-5 py-2.5 rounded-lg font-bold shadow-lg print:hidden hover:bg-slate-700 transition-colors"
      >
        ← Back
      </button>

      <button 
        onClick={() => window.print()}
        className="fixed top-4 right-4 bg-indigo-600 text-white px-5 py-2.5 rounded-lg font-bold shadow-lg print:hidden hover:bg-indigo-500 transition-colors flex items-center gap-2"
      >
        🖨️ Print Receipt
      </button>

    </div>
  );
}

function companyAddressCity(isAp) {
  return isAp ? 'Sivakasi' : 'Sivakasi';
}
